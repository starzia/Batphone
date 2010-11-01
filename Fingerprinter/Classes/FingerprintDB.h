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

using std::vector;

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
	unsigned int uid;
	long long timestamp;
	NSString* building;
	NSString* room;
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
							   const GPSLocation location=NULL_GPS ); /* optional estimate of the current GPS location */
							  		
	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
	unsigned int insertFingerprint( const float observation[], /* the new Fingerprint */
								    const NSString* building,  /* name of building */
								    const NSString* room,      /* name for the new room */
								    const GPSLocation location=NULL_GPS ); /* optional estimate of the observation's GPS location */
	
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
	
	/* clear database, including persistent store */
	void clear();
	
private:
	/* calculates the distance between two Fingerprints */
	float distance( const float A[], const float B[] );
	void makeRandomFingerprint( float outBuf[] );
	/* get filename for persistent storage */
	NSString* getDBFilename();
	
	unsigned int len; // length of the Fingerprint vectors
	std::vector<DBEntry> entries;
	int maxUid; // the highest uid in the database.  This is used to assign new uids
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	float* buf2 __attribute__ ((aligned (16)));
	float* buf3 __attribute__ ((aligned (16)));
};