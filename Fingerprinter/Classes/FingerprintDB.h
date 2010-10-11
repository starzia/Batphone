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

// Database entry
typedef struct{
	unsigned int uid;
	long long timestamp;
	NSString* name;
	float* fingerprint;
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
							   unsigned int numMatches ); /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
	
	/* Query the DB for a given room's name. */
	NSString* queryName( unsigned int uid );
	
	/* Query the DB for a given room's Fingerprint.
	 * outputFingerprint should be a float[] of length fingerPrinter::fpLength, to be filled by this function
	 * Returns true if uid matched a fingerprint in the DB. */
	bool queryFingerprint( unsigned int uid, float outputFingerprint[] );
	
	/* Add a given Fingerprint to the DB.  We do this when the returned matches are poor (or if there are no matches).
	 * @return the uid for the new room. */
	unsigned int insertFingerprint( const float observation[], /* the new Fingerprint */
								    NSString* name );      /* name for the new room */
	
	/* Save database to a file */
	bool save( NSString* filename );
	
	/* load database from a file.  Returns false if file doesn't exist. */
	bool load( NSString* filename );
	
private:
	/* calculates the distance between two Fingerprints */
	float distance( const float A[], const float B[] );
	void makeRandomFingerprint( float outBuf[] );
	
	unsigned int len; // length of the Fingerprint vectors
	std::vector<DBEntry> entries;
	// buffers for intermediate values, so that we don't have to allocate in functions.
	float* buf1 __attribute__ ((aligned (16))); // aligned for SIMD
	float* buf2 __attribute__ ((aligned (16)));
	float* buf3 __attribute__ ((aligned (16)));
};