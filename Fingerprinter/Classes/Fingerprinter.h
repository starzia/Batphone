/*
 *  Fingerprinter.h
 *
 *  Created by Stephen Tarzia on 9/23/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include <vector>
#include <queue>
#include <string>

#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "CAStreamBasicDescription.h"
#include <pthread.h> // for mutex

#import "Spectrogram.h"

// DATA TYPES
/* Fingerprint is a summary of room ambient noise; essentially the power spectrum of the ambient noise */
typedef float* Fingerprint;



/*
 * The Fingerprinter class provides all of the recording, signal processing, and Database functionality for our app
 * NOTE: to simplify this initial interface, all of the calls are blocking.  In other words, when you want a fingerprint
 * you call a function and wait for the result.  In the real system we may want the recording and querying to occur in 
 * a background thread.
 */
class Fingerprinter{
public:
	/* Contructor.  Initializes the database and the sound system. */
	Fingerprinter();
	
	/* start recording */
	bool startRecording();
	bool stopRecording();
	
	/* makes a copy of the current fingerprint value at the specified pointer.
	 * outputFingerprint should be a float[] of length Fingerprinter::fpLength, to be filled by this function 
	 */
	void getFingerprint( Fingerprint outputFingerprint );
	
	/* Destructor.  Cleans up. */
	~Fingerprinter();
	
	static const unsigned int fpLength; /* number of elements in the fingerprint array */
	static const unsigned int historyLength; /* number of time frames in the history (spectrogram) */
	static const float bufferSize; /* audio buffer size in seconds, also the size of time frames above */
	
private:
	int setupRemoteIO( AURenderCallbackStruct inRenderProc, CAStreamBasicDescription& outFormat);
	
	/* private data members */
	Spectrogram			spectrogram;
	Fingerprint			fingerprint;
	pthread_mutex_t		lock; // for mutually exclusive access to fingerprint
	
	AudioUnit					rioUnit;
	bool						unitIsRunning;
	AURenderCallbackStruct		inputProc;
	CAStreamBasicDescription	thruFormat;
	Float64						hwSampleRate;
};