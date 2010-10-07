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
const unsigned int Fingerprinter::fpLength = 128;
const unsigned int Fingerprinter::historyLength = 800;
const float Fingerprinter::bufferSize = 0.01;
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
	float* A;
	DSPSplitComplex compl_buf;	
} CallbackData;



#pragma mark -RIO Render Callback

/* Callback function for audio input.  This function is what actually processes
 * newly-captured audio buffers.
 * TODO: add buffering so that:
 *  A) callback returns immediately after copying data, thus not stalling pipeline
 *  B) if inNumberFrames is small (ie <= fpLength) then we don't produce NaNs
 */
static OSStatus callback( 	 void						*inRefCon, /* the user-specified state data structure */
							 AudioUnitRenderActionFlags *ioActionFlags, 
							 const AudioTimeStamp 		*inTimeStamp, 
							 UInt32 					inBusNumber, 
							 UInt32 					inNumberFrames, 
							 AudioBufferList 			*ioData ){
	// cast our data structure
	CallbackData* cd = (CallbackData*)inRefCon;
	try{
		XThrowIfError( AudioUnitRender(cd->rioUnit, ioActionFlags, inTimeStamp, kInputBus, inNumberFrames, ioData), "Callback: AudioUnitRender" );
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
	// Below, we need twice as many FFT points as the fpLength because of FFT "folding"
	UInt32 log2FFTLength = log2f( 2*Fingerprinter::fpLength );
	
	/*
	// right bitshift sample integers by 8 bits because they are in weird 8.24 format
	// actually, this isn't really necessary.  Floats will just be 256 times bigger
	// TODO: do this with a vector op
	for( int i=0; i<inNumberFrames; i++ ){
		data_ptr[i] >>= 8;
	}
	 */
	
	// convert integers to floats
	vDSP_vflt32( (int*)data_ptr, 1, cd->A, 1, inNumberFrames );

	// set output.  NOTE: if we don't set this to zero we'll get feedback.
	int zero=0;
	vDSP_vfilli( &zero, (int*)data_ptr, 1, inNumberFrames );
	
	// find RMS value (must do this before the in-place FFT)
	float rms;
	vDSP_rmsqv( cd->A, 1, &rms, inNumberFrames );
	///printf( "RMS: %10.0f\tFFT: ", rms );
		
	// take fft 	
	// ctoz and ztoc are needed to convert from "split" and "interleaved" complex formats
	// see vDSP documentation for details.
    vDSP_ctoz((COMPLEX*) cd->A, 2, &(cd->compl_buf), 1, inNumberFrames/2);
	vDSP_fft_zip( cd->fftsetup, &(cd->compl_buf), 1, log2FFTLength, kFFTDirection_Forward );
    ///vDSP_ztoc(&compl_buf, 1, (COMPLEX*) A, 2, inNumberFrames/2); // convert back

	// use vDSP_zaspec to get power spectrum
	vDSP_zaspec( &(cd->compl_buf), cd->A, Fingerprinter::fpLength );

	/*
	for( int i=0; i<Fingerprinter::fpLength; i++ ){
		if( !( A[i] >= 0 ) || ( A[i] <= 0 ) ){
			printf( "NaN at index %d\n", i );
		}
	}
	*/
	
	// convert to dB
	float reference=1.0f;
	vDSP_vdbcon( cd->A, 1, &reference, cd->A, 1, Fingerprinter::fpLength, 1 ); // 1 for power, not amplitude

	if( pthread_mutex_lock( cd->lock ) ) printf( "lock failed!\n" );
	// save in spectrogram
	cd->spectrogram->update( cd->A );
	// update fingerprint from spectrogram summary
	cd->spectrogram->getSummary( cd->fingerprint );
	pthread_mutex_unlock( cd->lock );
	
	return 0;
}	


#pragma mark -Audio Session Interruption Listener
#if TARGET_OS_IPHONE
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
#endif


#pragma mark -Audio Session Property Listener
/*
void propListener(void *                  inClientData,
				  AudioSessionPropertyID  inID,
				  UInt32                  inDataSize,
				  const void *            inData){
	
	CallbackData* cd = (CallbackData*)inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange){
		try {
			// if there was a route change, we need to dispose the current rio unit and create a new one
			XThrowIfError(AudioComponentInstanceDispose(cd->rioUnit), "couldn't dispose remote i/o unit");		
			
			SetupRemoteIO(cd->rioUnit, cd->inputProc, cd->thruFormat);
			
			UInt32 size = sizeof(cd->hwSampleRate);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &cd->hwSampleRate), "couldn't get new sample rate");
			
			XThrowIfError(AudioOutputUnitStart(cd->rioUnit), "couldn't start unit");
			
			if( 0 ){
				// we can adapt for different input as follows
				CFStringRef newRoute;
				size = sizeof(CFStringRef);
				XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute), "couldn't get new audio route");
				if (newRoute){	
					CFShow(newRoute);
					if (CFStringCompare(newRoute, CFSTR("Headset"), NULL) == kCFCompareEqualTo){} // headset plugged in
					else if (CFStringCompare(newRoute, CFSTR("Receiver"), NULL) == kCFCompareEqualTo){} // headset plugged in
					else{}
				}
			}
		} catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		
	}
}
*/

/* Sets up audio.  This is called by Fingerprinter constructor and also whenever
 * audio needs to be reset, eg. when distrupted by some system event or state change.
 */
int Fingerprinter::setupRemoteIO( AURenderCallbackStruct inRenderProc, CAStreamBasicDescription& outFormat){	
	try {		
		// create an output unit, ie a signal SOURCE (from the mic)
		AudioComponentDescription desc;
		desc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
		desc.componentSubType = kAudioUnitSubType_RemoteIO;
#else
		desc.componentSubType = kAudioUnitSubType_HALOutput;
#endif
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
#if !TARGET_OS_IPHONE
		// Select the default input device
		AudioDeviceID inputDeviceID = 0;
		UInt32 theSize = sizeof(AudioDeviceID);
		AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDefaultInputDevice,
												  kAudioObjectPropertyScopeGlobal,
												  kAudioObjectPropertyElementMaster };
		XThrowIfError(AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &theSize, &inputDeviceID ), 
					  "get default device" );
		// Set the current device to the default input unit.
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 
										   kOutputBus, &inputDeviceID, sizeof(AudioDeviceID) ), "set device" );
#endif	
		
		// first, collect all the data pointers the callback function will need
		CallbackData* callbackData = new CallbackData;
		callbackData->rioUnit = this->rioUnit;
		callbackData->spectrogram = &(this->spectrogram);
		callbackData->fingerprint = this->fingerprint;
		UInt32 log2FFTLength = log2f( 2*Fingerprinter::fpLength );
		callbackData->fftsetup = vDSP_create_fftsetup( log2FFTLength, kFFTRadix2 ); // this only needs to be created once
		callbackData->lock = &(this->lock);
		// allocate buffers for signal processing
		unsigned int buf_size = 1<<13; // TODO: assign this more safely
		callbackData->A = new float[buf_size];
		callbackData->compl_buf.realp = new float[buf_size/2];
		callbackData->compl_buf.imagp = new float[buf_size/2];
		
		
		// set the callback fcn
		inRenderProc.inputProc = callback;
		inRenderProc.inputProcRefCon = callbackData;
		XThrowIfError(AudioUnitSetProperty(this->rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 
										   kOutputBus, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");
		
		// Implicitly describe format
        // set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
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
Fingerprinter::Fingerprinter() : spectrogram( Fingerprinter::fpLength, Fingerprinter::historyLength ){
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
#if TARGET_OS_IPHONE
		XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, this->rioUnit), "couldn't initialize audio session");
		XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
		
		UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, 
											  sizeof(audioCategory), &audioCategory), "couldn't set audio category");
		/*
		 XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, this), "couldn't set property listener");	
		 */		
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
		size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, 
											  &size, &hwSampleRate), "couldn't get hw sample rate");
#endif
		// set up Audio Unit
		XThrowIfError(this->setupRemoteIO(inputProc, thruFormat), "couldn't setup remote i/o unit");
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


void Fingerprinter::getFingerprint( Fingerprint outBuf ){
	if( pthread_mutex_lock( &lock ) ) printf( "lock failed!\n" );
	memcpy( outBuf, this->fingerprint, sizeof(float)*Fingerprinter::fpLength );
	pthread_mutex_unlock( &lock );
}


QueryResult* Fingerprinter::queryMatches( Fingerprint observation, unsigned int numMatches ){
	QueryResult* qr = new QueryResult(numMatches);
	float confidence = 1.0;
	for( unsigned int i=0; i<numMatches; i++ ){
		(*qr)[i].uid = (random()%100);
		confidence -= (random()%100)/1000.0;
		if( confidence < 0 ) confidence = 0;
		(*qr)[i].confidence = confidence;
	}
	return qr;
}


string Fingerprinter::queryName( unsigned int uid ){
	char name[7];
	sprintf( name, "room%d", (int)(random()%100) );
	return string(name);
}


bool Fingerprinter::queryFingerprint( unsigned int uid, Fingerprint outBuf ){
	this->makeRandomFingerprint( outBuf );
	return true;
}


unsigned int Fingerprinter::insertFingerprint( Fingerprint observation, string name ){
	return random()%100;
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



// -----------------------------------------------------------------------------
// FINGERPRINTER CLASS: PRIVATE MEMBERS


void Fingerprinter::makeRandomFingerprint( Fingerprint outBuf ){
	outBuf[0] = 0.0;
	for( unsigned int i=1; i<Fingerprinter::fpLength; ++i ){
		outBuf[i] = outBuf[i-1] + (random()%9) - 4;
	}
}


bool Fingerprinter::startRecording(){
	if( !unitIsRunning ){
		UInt32 maxFPS;
		UInt32 size = sizeof(maxFPS);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
	
		XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");
	
		size = sizeof(thruFormat);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
	
		unitIsRunning = TRUE;
	}
	return unitIsRunning;
}

