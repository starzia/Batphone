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
#import <CoreLocation/CoreLocation.h> // for CLLocation and physical_distance

using std::vector;

// Database entry
typedef struct{
	unsigned int uid;
	long long timestamp;
	NSString* building;
	NSString* room;
	float* fingerprint;
	CLLocation* location; // estimated GPS location of this observed fingerprint
} DBEntry;

/* Candidates room matches are returned when querying the DB */
typedef struct {
	DBEntry entry;    /* the candidate room */
	float confidence; /* confidence level between 0-1 indicating how good of a match it is, 1 is closest */
	float distance;
} Match;

/* Query result is a list of matches.  These are sorted by descending confidence level */
typedef std::vector<Match> QueryResult;

// types of distance metric used in database queries
typedef enum{
	DistanceMetricAcoustic,
	DistanceMetricPhysical,
	DistanceMetricCombined
} DistanceMetric;


// Database class
@interface FingerprintDB : NSObject {
	unsigned int len; // length of the Fingerprint vectors
	std::vector<DBEntry> cache; // a list of recently seen fingerprints from the remote database
	
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	// for HTTP
	NSMutableData* receivedData;
	unsigned int maxUid;

};

@property (nonatomic) unsigned int len;
@property std::vector<DBEntry> cache;
@property (nonatomic) float* buf1;
@property (retain) NSMutableData* receivedData;
@property unsigned int maxUid;

-(id) initWithFPLength:(unsigned int) fpLength;
	
/* Query the DB for a list of closest-matching rooms 
 * returns the number of matches.
 * NOTE: later versions of this function will require other context info, eg. the last-observed GPS location. */
-(unsigned int) queryMatches:(QueryResult&)result /* the output */
				 observation:(const float[])observation  /* observed Fingerprint we want to match */
				  numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
					location:(CLLocation*)location /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
			  distanceMetric:(DistanceMetric)distance;

	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
-(unsigned int) insertFingerprint:(const float[])observation /* the new Fingerprint */
						 building:(NSString*)building      
							 room:(NSString*)room /* name for the new room */
						 location:(CLLocation*)location; /* optional estimate of the observation's GPS location; if unneeded, set to NULL_GPS */

/* Query the DB for a list of names of all buildings.  Names are pushed onto result */
-(bool) getAllBuildings:(vector<NSString*>&)result;

/* Query the DB for a list of names of all rooms in a certain building.  Names are pushed onto result. */
-(bool) getRooms:(vector<NSString*>&)result /* output */
	  inBuilding:(const NSString*)building;        /* input */

/* Query the DB for all fingerprints from a certain room. */
-(bool) getEntries:(vector<DBEntry>&) result /* the output */
		  fromRoom:(const NSString*)room
		inBuilding:(const NSString*)building;
				  
	
	/* load cache from file.  Returns false if there is some error. */
-(bool) loadCache;
-(bool) loadCacheFromString:( const NSString* )content;
-(bool) saveCache;
-(void) clearCache;
	
/* delete all database entries for the given room */
-(void) deleteRoom:(const NSString*)room
		inBuilding:(const NSString*)building;
	
/* get filename for persistent storage */
-(NSString*) getDBFilename;	

/* calculates the distance between two Fingerprints */
-(float) signalDistanceFrom:(const float[])A to:(const float[])B;
// distance using linear combination of signal and physical (GPS) distance
// note that this metric is not symmetrical, ie dist(a,b)!=dist(b,a)
-(float) combinedDistanceFrom:(float[])A
					  withLoc:(const CLLocation*)locA
						   to:(const float[])B
					  withLoc:(const CLLocation*)locB;

-(void) makeRandomFingerprint:(float[])outBuf;

/* get filename for persistent storage */
-(NSString*) getDBFilename;

/* appends a string description of the database entry, used for persistent storage */
-(void) appendEntry:(const DBEntry&)entry
		   toString:(NSMutableString*)outputBuffer;

@end;
