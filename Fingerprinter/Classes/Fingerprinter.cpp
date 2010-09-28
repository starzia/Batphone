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
#define kOutputBus 0
#define kInputBus 1



// -----------------------------------------------------------------------------
// HELPER FUNCTIONS FOR AUDIO


/* Callback function for audio input.  This function is what actually processes
 * newly-captured audio buffers.
 */
static OSStatus	PerformThru( void						*inRefCon, /* the user-specified state data structure */
							 AudioUnitRenderActionFlags *ioActionFlags, 
							 const AudioTimeStamp 		*inTimeStamp, 
							 UInt32 					inBusNumber, 
							 UInt32 					inNumberFrames, 
							 AudioBufferList 			*ioData ){
	// cast our data structure
	Fingerprinter* THIS = (Fingerprinter*)inRefCon;
	try{
		XThrowIfError( AudioUnitRender(THIS->getAUnit(), ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData), "Callback: AudioUnitRender" );
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
	UInt32 log2FFTLength = 3; //log2f(inNumberFrames);
	FFTSetup fftsetup = vDSP_create_fftsetup( log2FFTLength, kFFTRadix2 );
	// prepare vecotrs for FFT
	DSPSplitComplex compl_buf;
	compl_buf.realp = new float[inNumberFrames];
	compl_buf.imagp = new float[inNumberFrames];
	vDSP_vclr( compl_buf.imagp, 1, inNumberFrames ); // set imaginary part to zero
	for( unsigned int i=0; i<inNumberFrames; ++i ){
		compl_buf.realp[i] = (data_ptr[i]>>8);
	}
	
	// find RMS value
	float rms;
	vDSP_rmsqv( compl_buf.realp, 1, &rms, inNumberFrames );
	printf( "RMS: %10.0f\tFFT: ", rms );
	
	// take fft and convert complex numbers to abs
	vDSP_fft_zip( fftsetup, &compl_buf, 1, log2FFTLength, kFFTDirection_Forward );
	for( int i=0; i<(1<<log2FFTLength); ++i ){
		printf( "%10.0f\t", sqrt(compl_buf.realp[i]*compl_buf.realp[i] + compl_buf.imagp[i]*compl_buf.imagp[i] ) );
	}
	printf( "\n" );
	
	delete compl_buf.realp;
	delete compl_buf.imagp;
	
	/*
	// update display with RMS value
	NSString *rmsLabel = [[NSString alloc] initWithFormat:@"%10.0f", rms];
    THIS->myViewController.label.text = rmsLabel; 
    [rmsLabel release];
	*/
	return 0;
}	


/* Sets up audio.  This is called by Fingerprinter constructor and also whenever
 * audio needs to be reset, eg. when distrupted by some system event or state change.
 */
int setupRemoteIO( Fingerprinter* THIS, AudioUnit& inRemoteIOUnit, 
				  AURenderCallbackStruct inRenderProc, CAStreamBasicDescription& outFormat){	
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
		
		AudioComponent comp = AudioComponentFindNext(NULL, &desc);
		XThrowIfError(AudioComponentInstanceNew(comp, &inRemoteIOUnit), "couldn't open the remote I/O unit");
		
		// enable input on the AU
		UInt32 flag = 1;
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input,
										   kInputBus, &flag, sizeof(flag)), "couldn't enable input on the remote I/O unit");
		// disable output on the AU
		flag = 0;
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output,
										   kOutputBus, &flag, sizeof(flag)), "couldn't disable output on the remote I/O unit");
		
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
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 
										   kInputBus, &inputDeviceID, sizeof(AudioDeviceID) ), "set device" );
#endif	
		
		// set the callback fcn
		inRenderProc.inputProc = PerformThru;
		inRenderProc.inputProcRefCon = THIS;
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 
										   kInputBus, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");
		//XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Output, 
		//								   kInputBus, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");

		
		// Implicitly describe format
        // set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
        outFormat.SetAUCanonical(1 /*numChannels*/, false /*interleaved*/);
		
		/*
		 // Explicitly describe format
		 outFormat.mSampleRate			= 44100.00;
		 outFormat.mFormatID			= kAudioFormatLinearPCM;
		 outFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
		 outFormat.mFramesPerPacket	= 1;
		 outFormat.mChannelsPerFrame	= 1;
		 outFormat.mBitsPerChannel		= 16;
		 outFormat.mBytesPerPacket		= 2;
		 outFormat.mBytesPerFrame		= 2;
		 */
		
		// set input format
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 
										   kOutputBus, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's output client format");
		// set output format
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 
										   kInputBus, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's input client format");
		
		// allocate buffers
		// NOTE that buffers are allocated automatically by default.  see kAudioUnitProperty_ShouldAllocateBuffer
		flag = 1;
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 
									       kInputBus, &flag, sizeof(flag)), "couldn't set allocation strategy" );
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Input, 
									       kInputBus, &flag, sizeof(flag)), "couldn't set allocation strategy" );
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 
									       kOutputBus, &flag, sizeof(flag)), "couldn't set allocation strategy" );
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Input, 
									       kOutputBus, &flag, sizeof(flag)), "couldn't set allocation strategy" );
		
		
		// initialize AU
		XThrowIfError(AudioUnitInitialize(inRemoteIOUnit), "couldn't initialize the remote I/O unit");
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
Fingerprinter::Fingerprinter(){
	try {			
		// Initialize and configure the audio session
#if TARGET_OS_IPHONE
		// TODO: add interruption listener as follows
		//XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, self), "couldn't initialize audio session");
		XThrowIfError(AudioSessionInitialize(NULL, NULL, NULL, NULL /* data struct passed to interruption listener */), "couldn't initialize audio session");
		XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
		
		UInt32 audioCategory = kAudioSessionCategory_RecordAudio;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");

		// TODO: add property listener as follows
		//XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, self), "couldn't set property listener");	
		
		Float32 preferredBufferSize = .005;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");
		
		UInt32 size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &hwSampleRate), "couldn't get hw sample rate");
#endif
		// set up Audio Unit
		XThrowIfError(setupRemoteIO(this, rioUnit, inputProc, thruFormat), "couldn't setup remote i/o unit");
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


Fingerprint* Fingerprinter::recordFingerprint(){
	this->startRecording();
	return this->makeRandomFingerprint();
}


QueryResult* Fingerprinter::queryMatches( Fingerprint* observation, unsigned int numMatches ){
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


Fingerprint* Fingerprinter::queryFingerprint( unsigned int uid ){
	return this->makeRandomFingerprint();
}


unsigned int Fingerprinter::insertFingerprint( Fingerprint* observation, string name ){
	return random()%100;
}


/* Destructor.  Cleans up. */
Fingerprinter::~Fingerprinter(){
	AudioUnitUninitialize(rioUnit);
}


AudioUnit Fingerprinter::getAUnit(){
	return this->rioUnit;
}


// -----------------------------------------------------------------------------
// FINGERPRINTER CLASS: PRIVATE MEMBERS


Fingerprint* Fingerprinter::makeRandomFingerprint(){
	Fingerprint* fp = new Fingerprint(Fingerprinter::fpLength);
	(*fp)[0] = 0.0;
	for( unsigned int i=1; i<Fingerprinter::fpLength; ++i ){
		(*fp)[i] = (*fp)[i-1] + (random()%9) - 4;
	}
	return fp;
}


bool Fingerprinter::startRecording(){
	UInt32 maxFPS;
	UInt32 size = sizeof(maxFPS);
	XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
	
	XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");
	
	size = sizeof(thruFormat);
	XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
	
	unitIsRunning = TRUE;
	return unitIsRunning;
}

