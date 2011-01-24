/*
 *  Fingerprinter.cpp
 *
 *  Created by Stephen Tarzia on 9/23/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Fingerprinter.h"

#include <stdlib.h> // for random()
#include "CAXException.h" // for Core Audio exception handling
#import <Accelerate/Accelerate.h> // for vector operations and FFT
#include <iostream> // for debugging printouts

#import <CoreAudio/CoreAudioTypes.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

#if !TARGET_OS_IPHONE
#import <CoreAudio/AudioHardware.h>
#endif

using namespace std;

// -----------------------------------------------------------------------------
// CONSTANTS
const unsigned int Fingerprinter::sampleRate = 44100;
const unsigned int Fingerprinter::specRes = 1024;
const float        Fingerprinter::windowOffset = 0.025;
const unsigned int Fingerprinter::historyLength = 10 /* second duration */ / Fingerprinter::windowOffset;
const float        Fingerprinter::freqCutoff = 7000.0; // use only the first 7kHz
const unsigned int Fingerprinter::fpLength = Fingerprinter::specRes * Fingerprinter::freqCutoff / 22050.0;
#define kOutputBus 0
#define kInputBus 1



// -----------------------------------------------------------------------------
// HELPER FUNCTIONS FOR AUDIO

typedef struct{
	AudioUnit rioUnit;
	// the following are for RIO listener
	Spectrogram* spectrogram;
	Fingerprint fingerprint;
	FFTSetup fftsetup;
	pthread_mutex_t* lock; // fingerprint lock
	// signal processing buffers
	float* A __attribute__ ((aligned (16))); // scratch // aligned for SIMD
	float* frameBuffer __attribute__ ((aligned (16))); // aligned for SIMD
	int fbIndex; // index of next space to be filled in the frameBuffer
	int startIndex; // index of next window to be analyzed
	unsigned int fbLen; // number of frames (floats) in frameBuffer
	DSPSplitComplex compl_buf;	
} CallbackData;



#pragma mark -RIO Render Callback

/* Callback function for audio input.  This function is what actually processes
 * newly-captured audio buffers.
 * TODO: add buffering so that:
 *  A) callback returns immediately after copying data, thus not stalling pipeline
 *  B) if inNumberFrames is small (ie <= specRes) then we don't produce NaNs
 */
static OSStatus callback( 	 void						*inRefCon, /* the user-specified state data structure */
							 AudioUnitRenderActionFlags *ioActionFlags, 
							 const AudioTimeStamp 		*inTimeStamp, 
							 UInt32 					inBusNumber, 
							 UInt32 					inNumberFrames, 
							 AudioBufferList 			*ioData ){	
	int windowFrames = Fingerprinter::specRes;
	if( inNumberFrames > windowFrames ){
		fprintf(stderr, "Error: buffer is too small.\n");		
	}
	
	// cast our data structure
	CallbackData* cd = (CallbackData*)inRefCon;
	
	try{
		XThrowIfError( AudioUnitRender(cd->rioUnit, ioActionFlags, inTimeStamp, 
									   kInputBus, inNumberFrames, ioData), "Callback: AudioUnitRender" );
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		return 1;
	}
	SInt32 *data_ptr = (SInt32 *)(ioData->mBuffers[0].mData);
	// the samples are 24 bit but padded on the right to give 32 bits.  Hence the right shift
	//printf( "%d  ", data_ptr[0]>>8 );
	
	// setup FFT
	UInt32 log2FFTLength = log2f( Fingerprinter::specRes );
	
	/*
	// right bitshift sample integers by 8 bits because they are in weird 8.24 format
	// actually, this isn't really necessary.  Floats will just be 256 times bigger
	// TODO: do this with a vector op
	for( int i=0; i<inNumberFrames; i++ ){
		data_ptr[i] >>= 8;
	}
	 */

	// If there is no space left in the buffer for the current frame, 
	// left-shift the right-half of the buffer to overwrite the old data.
	// After the new data is added there will be enough data left to
	// build a full window.  Also, there will not be a full window of old data.
	if( cd->fbIndex >= cd->fbLen - inNumberFrames ){
		// left-shift right half of buffer
		memcpy(cd->frameBuffer + cd->fbLen/2, cd->frameBuffer, sizeof(float)*cd->fbLen/2);
		// adjust buffer index to reflect shift
		cd->fbIndex -= cd->fbLen/2;
		cd->startIndex -= cd->fbLen/2;
	}
	
	// convert integers to floats, while copying into frameBuffer
	vDSP_vflt32( (int*)data_ptr, 1, cd->frameBuffer + cd->fbIndex, 1, inNumberFrames );		
	
	
	// increment frame buffer index
	cd->fbIndex += inNumberFrames;
	
	// set output.  NOTE: if we don't set this to zero we'll get audio feedback.
	int zero=0;
	vDSP_vfilli( &zero, (int*)data_ptr, 1, inNumberFrames );
	
	// if we don't yet have sufficient data, just return.
	if( cd->fbIndex < windowFrames ) return 0;

	// generate Hamming window
	float window[Fingerprinter::specRes];
	vDSP_hamm_window( window, Fingerprinter::specRes, 0 ); // create window
	
	// loop over as many overlapping windows as are present in the buffer.
	int stepSize = floor(Fingerprinter::windowOffset * Fingerprinter::sampleRate);
	for( ; cd->startIndex <= cd->fbIndex-windowFrames; cd->startIndex+=stepSize ){
		// copy the window into buffer A, where signal processing will occur
		memcpy( cd->A, cd->frameBuffer+cd->startIndex, sizeof(float)*Fingerprinter::specRes );
		
		// apply Hamming window
		vDSP_vmul(cd->A, 1, window, 1, cd->A, 1, Fingerprinter::specRes); //apply
		
		// take fft 	
		// ctoz and ztoc are needed to convert from "split" and "interleaved" complex formats
		// see vDSP documentation for details.
		vDSP_ctoz((COMPLEX*) cd->A, 2, &(cd->compl_buf), 1, Fingerprinter::specRes);
		vDSP_fft_zip( cd->fftsetup, &(cd->compl_buf), 1, log2FFTLength, kFFTDirection_Forward );
		///vDSP_ztoc(&compl_buf, 1, (COMPLEX*) A, 2, inNumberFrames/2); // convert back
		
		// use vDSP_zaspec to get power spectrum
		vDSP_zaspec( &(cd->compl_buf), cd->A, Fingerprinter::specRes );
		
		// convert to dB
		float reference=1.0f;
		vDSP_vdbcon( cd->A, 1, &reference, cd->A, 1, Fingerprinter::fpLength, 1 ); // 1 for power, not amplitude
		
		if( pthread_mutex_lock( cd->lock ) ) printf( "lock failed!\n" );
		
		// save in spectrogram
		cd->spectrogram->update( cd->A );
		// update fingerprint from spectrogram summary
		cd->spectrogram->getSummary( cd->fingerprint );
		pthread_mutex_unlock( cd->lock );
	}
	
	return 0;
}	


#pragma mark -Audio Session Interruption Listener
void rioInterruptionListener(void *inClientData, UInt32 inInterruption){
	printf("Session interrupted! --- %s ---", inInterruption == kAudioSessionBeginInterruption ? "Begin Interruption" : "End Interruption");
	
	AudioUnit rioUnit = (AudioUnit)inClientData;
	
	if (inInterruption == kAudioSessionEndInterruption) {
		// make sure we are again the active session
		AudioSessionSetActive(true);
		AudioOutputUnitStart(rioUnit);
	}
	
	if (inInterruption == kAudioSessionBeginInterruption) {
		AudioOutputUnitStop(rioUnit);
    }
}


#pragma mark -Audio Session Property Listener
void propListener(void *                  inClientData,
				  AudioSessionPropertyID  inID,
				  UInt32                  inDataSize,
				  const void *            inData){
	
	
	Fingerprinter* THIS = (Fingerprinter*)inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange){
		try {
			// if there was a route change, we need to dispose the current rio unit and create a new one
			XThrowIfError(AudioComponentInstanceDispose(THIS->rioUnit), "couldn't dispose remote i/o unit");		
			
			THIS->setupRemoteIO(THIS->inputProc, THIS->thruFormat);
			
			UInt32 size = sizeof(THIS->hwSampleRate);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, 
												  &size, &THIS->hwSampleRate), "couldn't get new sample rate");
			
			XThrowIfError(AudioOutputUnitStart(THIS->rioUnit), "couldn't start unit");
			
			// we can adapt for different input as follows
			CFStringRef newRoute;
			size = sizeof(CFStringRef);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute), "couldn't get new audio route");
			if (newRoute){	
				CFShow(newRoute);
				if (CFStringCompare(newRoute, CFSTR("Headset"), NULL) == kCFCompareEqualTo){
					printf("headset plugged in");
				} // headset plugged in
				else if (CFStringCompare(newRoute, CFSTR("Receiver"), NULL) == kCFCompareEqualTo){
					printf("headset un-plugged");
				} // headset plugged in
				else{}
			}
		} catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		
	}
}


/* Sets up audio.  This is called by Fingerprinter constructor and also whenever
 * audio needs to be reset, eg. when disrupted by some system event or state change.
 */
int Fingerprinter::setupRemoteIO( AURenderCallbackStruct inRenderProc, CAStreamBasicDescription& outFormat){	
	try {		
		// create an output unit, ie a signal SOURCE (from the mic)
		AudioComponentDescription desc;
		desc.componentType = kAudioUnitType_Output;
		desc.componentSubType = kAudioUnitSubType_RemoteIO;
		desc.componentManufacturer = kAudioUnitManufacturer_Apple;
		desc.componentFlags = 0;
		desc.componentFlagsMask = 0;
		
		// find a component matching the description above
		AudioComponent comp = AudioComponentFindNext(NULL, &desc);
		//if( comp == NULL ) Throw("no matching audio component");
		XThrowIfError(AudioComponentInstanceNew(comp, &(this->rioUnit)), "couldn't open the remote I/O unit");
		
		// enable input on the AU
		UInt32 flag = 1;
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input,
										   kInputBus, &flag, sizeof(flag)), "couldn't enable input on the remote I/O unit");
		/* for some reason the following breaks audio (callback is never called)
		// disable output on the AU
		flag = 0;
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output,
										   kOutputBus, &flag, sizeof(flag)), "couldn't disable output on the HAL unit");
		 */	
		
		// first, collect all the data pointers the callback function will need
		CallbackData* callbackData = new CallbackData;
		callbackData->rioUnit = this->rioUnit;
		callbackData->spectrogram = &(this->spectrogram);
		callbackData->fingerprint = this->fingerprint;
		UInt32 log2FFTLength = log2f( Fingerprinter::specRes );
		callbackData->fftsetup = vDSP_create_fftsetup( log2FFTLength, kFFTRadix2 ); // this only needs to be created once
		callbackData->lock = &(this->lock);
		// allocate buffers for signal processing
		callbackData->A = new float[2*Fingerprinter::specRes];
		unsigned int fbLenCandidate = 2 * ceil(Fingerprinter::windowOffset*Fingerprinter::sampleRate);
		callbackData->fbLen = max(fbLenCandidate,2*Fingerprinter::specRes); // allow twice the space b/c it will be shifted
		callbackData->frameBuffer = new float[callbackData->fbLen];
		callbackData->compl_buf.realp = new float[Fingerprinter::specRes];
		callbackData->compl_buf.imagp = new float[Fingerprinter::specRes];
		callbackData->fbIndex = 0;
		callbackData->startIndex = 0;
		
		
		// set the callback fcn
		inRenderProc.inputProc = callback;
		inRenderProc.inputProcRefCon = callbackData;
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 
										   kOutputBus, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");
		
		// Implicitly describe format
        // set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
		memset(&outFormat, 0, sizeof(AudioStreamBasicDescription)); // clear format
		outFormat.mSampleRate = Fingerprinter::sampleRate;
        outFormat.SetAUCanonical(1 /*numChannels*/, false /*interleaved*/);

		
		// set input format
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 
										   kOutputBus, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's output client format");
		// set output format
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 
										   kInputBus, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's input client format");
		
		// initialize AU
		XThrowIfError(AudioUnitInitialize(this->rioUnit), "couldn't initialize the remote I/O unit");
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		return 1;
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
		return 1;
	}		
	return 0;
}



// -----------------------------------------------------------------------------
// FINGERPRINTER CLASS: PUBLIC MEMBERS


/* Constructor initializes the audio system */
Fingerprinter::Fingerprinter() :
spectrogram( Fingerprinter::fpLength, Fingerprinter::historyLength ){
	// plotter must always have a FP available to plot, so init one here.
	this->fingerprint = new float[Fingerprinter::fpLength];
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		this->fingerprint[i] = 0;
	}
	// initialize fingerprint lock
	if( pthread_mutex_init( &lock, NULL ) ) printf( "mutex init failed!\n" );

	// INITIALIZE AUDIO
	try {			
		// Initialize and configure the audio session
		XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, this->rioUnit), "couldn't initialize audio session");
		XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
		
		// audioCategory really should be ..._RecordAudio, but this setting causes callback to be never called
		UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, 
											  sizeof(audioCategory), &audioCategory), "couldn't set audio category");
		
		 XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, this), "couldn't set property listener");	
		
		/*
		// set audio buffer size
		Float32 preferredBufferSize = Fingerprinter::bufferSize;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, 
											  sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");
		// get the audio buffer size to see whether our request was granted
		UInt32 size = sizeof(preferredBufferSize);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
											  &size, &preferredBufferSize ), "couldn't get i/o buffer duration");
		if( preferredBufferSize < Fingerprinter::bufferSize ){
			fprintf(stderr, "Didn't get preferred audio buffer length of %f seconds, instead got %f seconds.\n",
					Fingerprinter::bufferSize, preferredBufferSize);
		}
		*/
		UInt32 size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, 
											  &size, &hwSampleRate), "couldn't get hw sample rate");
		// set up Audio Unit
		XThrowIfError(this->setupRemoteIO(inputProc, thruFormat), "couldn't setup remote i/o unit");

		// configure audio frames per slice, I don't think that this is necessary
		UInt32 maxFPS;
		size = sizeof(maxFPS);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
		maxFPS = 4096;
		XThrowIfError(AudioUnitSetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, size), "couldn't set the remote I/O unit's max frames per slice");		
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		unitIsRunning = FALSE;
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
		unitIsRunning = FALSE;
	}
}	


bool Fingerprinter::getFingerprint( Fingerprint outBuf ){
	if( this->unitIsRunning ){ // TODO: return false if less then a full window has been recorded.
		if( pthread_mutex_lock( &lock ) ) printf( "lock failed!\n" );
		memcpy( outBuf, this->fingerprint, sizeof(float)*Fingerprinter::fpLength );
		pthread_mutex_unlock( &lock );
		return true;
	}
	else return false;
}



/* Destructor.  Cleans up. */
Fingerprinter::~Fingerprinter(){
	AudioUnitUninitialize(rioUnit);
	AudioComponentInstanceDispose(rioUnit);
	pthread_mutex_destroy(&lock);
	/*
	//TODO: stop audio and clean up callback buffers
	delete[] callbackData->A;
	delete[] callbackData->compl_buf.realp;
	delete[] callbackData->compl_buf.imagp;
	 */
}



bool Fingerprinter::startRecording(){
	if( !unitIsRunning ){
		XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");
	
		// get audio format
		UInt32 size = sizeof(thruFormat);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
	
		unitIsRunning = TRUE;
	}
	return unitIsRunning;
}


bool Fingerprinter::stopRecording(){
	if( unitIsRunning ){
		XThrowIfError(AudioOutputUnitStop(rioUnit), "couldn't stop remote i/o unit");
		unitIsRunning = FALSE;
	}
	return unitIsRunning;
}
