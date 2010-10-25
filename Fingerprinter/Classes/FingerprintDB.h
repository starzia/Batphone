/*
 *  FingerprintDB.h
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/7/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#import <vector>
#import <string>
#import <Foundation/Foundation.h>

// GPS location
typedef struct{
	double latitude;
	double longitude;
	double altitude;
} GPSLocation;
// NULL GPSLocation for cases when GPS location is unavailable
static const GPSLocation NULL_GPS = {NAN, NAN, NAN};

// Database entry
typedef struct{
	NSString* uuid;
	long long timestamp;
	NSString* name;
	float* fingerprint;
	GPSLocation location; // estimated GPS location of this observed fingerprint
} DBEntry;

/* Candidates room matches are returned when querying the DB */
typedef struct {
	DBEntry entry;    /* the candidate room */
	float confidence; /* confidence level between 0-1 indicating how good of a match it is, 1 is closest */
} Match;

/* Query result is a list of matches.  These are sorted by descending confidence level */
typedef std::vector<Match> QueryResult;


// Database class
@interface FingerprintDB : NSObject{
	unsigned int len; // length of the Fingerprint vectors
	std::vector<DBEntry> cache; // a list of recently seen fingerprints from the remote database
	
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	// for HTTP
	NSMutableData* receivedData;
};

@property (nonatomic) unsigned int len;
@property std::vector<DBEntry> cache;
@property (nonatomic) float* buf1;
@property (retain) NSMutableData* receivedData;

-(void)	initWithFPLength:(unsigned int) fpLength;
	
	/* Query the DB for a list of closest-matching rooms 
	 * returns the number of matches.
	 * NOTE: later versions of this function will require other context info, eg. the last-observed GPS location. */
-(unsigned int) queryMatches:(QueryResult&)result /* the output */
				 observation:(const float[])observation  /* observed Fingerprint we want to match */
				  numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
					location:(GPSLocation)location; /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */

	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
-(NSString*) insertFingerprint:(const float[])observation /* the new Fingerprint */
						  name:(NSString*)name      /* name for the new room */
					  location:(GPSLocation)location; /* optional estimate of the observation's GPS location; if unneeded, set to NULL_GPS */
	
	/* load cache from file.  Returns false if there is some error. */
-(bool) loadCache;
-(bool) saveCache;
-(void) clearCache;

#pragma mark private methods
	
	/* calculates the distance between two Fingerprints */
-(float) distanceFrom:(const float[])A to:(const float[])B;
-(void) makeRandomFingerprint:(float[])outBuf;

/* get filename for persistent storage */
-(NSString*) getDBFilename;

/* starts network transaction to add a given entry to the remote database */
-(void) addToRemoteDB:(DBEntry&)newEntry;

@end;