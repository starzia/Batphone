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

#pragma mark -
#pragma mark helper classes
// Database entry
@interface DBEntry : NSObject{
@public
	long long timestamp;
	NSString* uuid;
	NSString* building;
	NSString* room;
	float* fingerprint;
	CLLocation* location; // estimated GPS location of this observed fingerprint
};
@property (nonatomic) long long timestamp;
@property (nonatomic,retain) NSString* uuid;
@property (nonatomic,retain) NSString* building;
@property (nonatomic,retain) NSString* room;
@property (nonatomic) float* fingerprint;
@property (nonatomic,retain) CLLocation* location;
-(NSString*)description;
@end


/* Candidates room matches are returned when querying the DB */
@interface Match : NSObject {
@public
	DBEntry* entry;    /* the candidate room */
	float confidence; /* confidence level between 0-1 indicating how good of a match it is, 1 is closest */
	float distance;
};
@property (nonatomic,retain) DBEntry* entry;
@property (nonatomic) float confidence;
@property (nonatomic) float distance;
@end


// types of distance metric used in database queries
typedef enum{
	DistanceMetricAcoustic,
	DistanceMetricPhysical,
	DistanceMetricCombined
} DistanceMetric;


#pragma mark -
#pragma mark FingerprintDB
/**
 * Represents a fingerprint database, with methods to query for matches.
 * It can use a remote database, but this feature is not currently being used.
 */
@interface FingerprintDB : NSObject{
	unsigned int len; // length of the Fingerprint vectors
	NSMutableArray* cache; // NSMutableArray* of DBEntry* : a list of recently seen fingerprints from the remote database
	bool useRemoteDB; // toggle use of remote (Internet) database vs. just using the local cache
	
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	// for HTTP
	// see http://stackoverflow.com/questions/332276/managing-multiple-asynchronous-nsurlconnection-connections
	NSMutableDictionary* httpConnectionData; // maps connections to their info, which is another dictionary containing the connection type and the NSMutableData
	// for some reason NSMutableDictionary doesn't like using connections directly as keys so we use their string description.
	id  callbackTarget;
	SEL callbackSelector; // callback function for match query results
};

@property (nonatomic) bool useRemoteDB;
@property (nonatomic) unsigned int len;
@property (retain) NSMutableArray* cache;
@property (nonatomic) float* buf1;
@property (retain) NSMutableDictionary* httpConnectionData; 
@property (retain) id callbackTarget;
@property SEL callbackSelector;

-(id) initWithFPLength:(unsigned int) fpLength;
	
/* Starts an asynchronous query.  When result is ready, call [target selector:(NSMutableArray*)result].
   Will use local cache unless useRemoteDB is set to true. */
-(void) startQueryWithObservation:(const float[])observation  /* observed Fingerprint we want to match */
					   numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
						 location:(CLLocation*)location /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
				   distanceMetric:(DistanceMetric)distance
					 resultTarget:(id) target
						 selector:(SEL) selector;

/* Query the DB for a list of closest-matching rooms 
 * returns the number of matches.
 */
-(unsigned int) queryCacheForMatches:(NSMutableArray*)result /* the output */
						 observation:(const float[])observation  /* observed Fingerprint we want to match */
						  numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
							location:(CLLocation*)location /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
					  distanceMetric:(DistanceMetric)distance;

/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
 * @return the uuid string for the new room. */
-(NSString*) insertFingerprint:(const float[])observation /* the new Fingerprint */
					  building:(NSString*)building      
						  room:(NSString*)room /* name for the new room */
					  location:(CLLocation*)location; /* optional estimate of the observation's GPS location; if unneeded, set to NULL_GPS */

/* Query the DB for a list of names of all buildings.  Names are pushed onto result */
-(bool) getAllBuildings:(vector<NSString*>&)result;

/* Query the DB for a list of names of all rooms in a certain building.  Names are pushed onto result. */
-(bool) getRooms:(vector<NSString*>&)result /* output */
	  inBuilding:(const NSString*)building;        /* input */

/* Query the DB for all fingerprints from a certain room. */
-(bool) getEntries:(vector<DBEntry*>&) result /* the output */
		  fromRoom:(const NSString*)room
		inBuilding:(const NSString*)building;
				  
	
	/* load cache from file.  Returns false if there is some error. */
-(bool) loadCache;
-(bool) loadCacheFromString:( const NSString* )content;
-(bool) saveCache;
-(void) clearCache;


#pragma mark private methods
	
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
-(void) appendEntry:(const DBEntry*)entry
		   toString:(NSMutableString*)outputBuffer;

/* starts network transaction to add a given entry to the remote database */
-(void) addToRemoteDB:(DBEntry*)newEntry;

/* adds the passed entry to the local cache, if it is not already present there */
-(void) addToCache:(DBEntry*)newEntry;

@end;
