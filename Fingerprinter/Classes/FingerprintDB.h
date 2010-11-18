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
class FingerprintDB{
public:
	FingerprintDB( unsigned int fpLength );
	~FingerprintDB();
	
	/* Query the DB for a list of closest-matching rooms 
	 * returns the number of matches.
	 * NOTE: later versions of this function will require other context info, eg. the last-observed GPS location. */
	unsigned int queryMatches( QueryResult & result, /* the output */
							   const float observation[],  /* observed Fingerprint we want to match */
							   const unsigned int numMatches, /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
							   const CLLocation* location=NULL, /* optional estimate of the current GPS location */
							   const DistanceMetric distance=DistanceMetricAcoustic ); /* use acoustic or physical distance		

	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
	unsigned int insertFingerprint( const float observation[], /* the new Fingerprint */
								    const NSString* building,  /* name of building */
								    const NSString* room,      /* name for the new room */
								    const CLLocation* location=NULL ); /* optional estimate of the observation's GPS location */
	
	/* Query the DB for a list of names of all buildings.  Names are pushed onto result */
	bool getAllBuildings( vector<NSString*> & result );

	/* Query the DB for a list of names of all rooms in a certain building.  Names are pushed onto result. */
	bool getRoomsInBuilding( vector<NSString*> & result, /* output */
							 const NSString* building);        /* input */

	/* Query the DB for all fingerprints from a certain room. */
	bool getEntriesFrom( vector<DBEntry> & result, /* the output */
						 const NSString* building,
						 const NSString* room );
	
	/* Save database to a file */
	bool save();
	
	/* load database from a file.  Returns false if file doesn't exist. */
	bool load();
	bool loadFromString( NSString* content );
	
	/* clear database, including persistent store */
	void clear();
	
	/* delete all database entries for the given room */
	void deleteRoom( const NSString* building, const NSString* room );
	
	/* get filename for persistent storage */
	NSString* getDBFilename();	

	static const float neighborhoodRadius; // the maximum distance of a fingerprint returned from a query when DistanceMetricCombined is used.
private:
	/* calculates the distance between two Fingerprints */
	float signal_distance( const float A[], const float B[] );
	// distance using linear combination of signal and physical (GPS) distance
	// note that this metric is not symmetrical, ie dist(a,b)!=dist(b,a)
	float combined_distance(float A[], const CLLocation* locA,
							const float B[], const CLLocation* locB );
	
	void makeRandomFingerprint( float outBuf[] );

	/* appends a string description of the database entry, used for persistent storage */
	void appendEntryString( NSMutableString* outputBuffer, const DBEntry & entry );
	
	unsigned int len; // length of the Fingerprint vectors
	std::vector<DBEntry> entries;
	int maxUid; // the highest uid in the database.  This is used to assign new uids
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	float* buf2 __attribute__ ((aligned (16)));
	float* buf3 __attribute__ ((aligned (16)));
};