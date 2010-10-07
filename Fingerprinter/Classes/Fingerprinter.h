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

/* Candidates room matches are returned when querying the DB */
typedef struct {
	unsigned int uid;          /* numeric identifier for the candidate room */
	float confidence;          /* confidence level between 0-1 indicating how good of a match it is, 1 is closest */
} Match;

/* Query result is a list of matches.  These are sorted by descending confidence level */
typedef std::vector<Match> QueryResult;



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
	
	/* makes a copy of the current fingerprint value at the specified pointer */
	void getFingerprint( Fingerprint outputFingerprint );
	
	/* Query the DB for a list of closest-matching rooms 
	 * NOTE: later versions of this function will require other context info, eg. the last-observed GPS location. */
	QueryResult* queryMatches( Fingerprint observation,  /* observed Fingerprint we want to match */
							   unsigned int numMatches ); /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
							   
	/* Query the DB for a given room's name. */
	std::string queryName( unsigned int uid );

	/* Query the DB for a given room's Fingerprint.  
	 * Returns true if uid matched a fingerprint in the DB. */
	bool queryFingerprint( unsigned int uid, Fingerprint outputFingerprint );
	
	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
	unsigned int insertFingerprint( Fingerprint observation, /* the new Fingerprint */
								    std::string name );            /* name for the new room */
	
	
	/* Destructor.  Cleans up. */
	~Fingerprinter();
	
	static const unsigned int fpLength; /* number of elements in the fingerprint array */
	static const unsigned int historyLength; /* number of time frames in the history (spectrogram) */
	static const float bufferSize; /* audio buffer size in seconds, also the size of time frames above */
	
private:
	void makeRandomFingerprint( Fingerprint outBuf );
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