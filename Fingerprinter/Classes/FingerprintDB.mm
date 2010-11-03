/*
 *  FingerprintDB.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/7/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "FingerprintDB.h"
#import <Accelerate/Accelerate.h> // for vector operations and FFT
#include <stdlib.h> // for random()
#import <algorithm> // for partial_sort
#import <utility> // for pair

using std::vector;
using std::pair;
using std::make_pair;
using std::min;
using std::partial_sort;


const NSString* DBFilename = @"db.txt";


FingerprintDB::FingerprintDB( unsigned int fpLength ): len(fpLength), maxUid(-1) {
	buf1 = new float[fpLength];
	buf2 = new float[fpLength];
	buf3 = new float[fpLength];
}


FingerprintDB::~FingerprintDB(){
	delete[] buf1;
	delete[] buf2;
	delete[] buf3;
	
	// clear database
	for( unsigned int i=0; i<entries.size(); ++i ){
		delete[] entries[i].fingerprint;
		[entries[i].building release];
		[entries[i].room release];
	}
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


unsigned int FingerprintDB::queryMatches( QueryResult & result, 
										  const float observation[],  
										  unsigned int numMatches,
										  GPSLocation location ){
	// TODO: range query using GPSLocation
	unsigned int resultSize = min(numMatches, (unsigned int)entries.size() );
	
	// calculate distances to all entries in DB
	pair<float,int>* distances = new pair<float,int>[entries.size()]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<entries.size(); ++i ){
		distances[i] = make_pair( distance( observation, entries[i].fingerprint ), i );
	}
	// sort distances (partial sort b/c we are interested only in first numMatches)
	partial_sort(distances+0, distances+resultSize, distances+entries.size(), smaller_by_first );
	for( unsigned int i=0; i<resultSize; ++i ){
		Match m;
		m.entry = entries[distances[i].second];
		m.confidence = -(distances[i].first); //TODO: scale between 0 and 1
		result.push_back( m );
	}
	delete distances;
	return resultSize;
}


unsigned int FingerprintDB::insertFingerprint( const float observation[],
											   const NSString* newBuilding,
											   const NSString* newRoom,
											   const GPSLocation location){
	// create new DB entry
	DBEntry newEntry;
	NSDate *now = [NSDate date];
	newEntry.timestamp = [now timeIntervalSince1970];
	newEntry.room = newRoom;
	[newEntry.room retain];
	newEntry.building = newBuilding;
	[newEntry.building retain];
	newEntry.uid = ++(this->maxUid); // increment and assign uid
	newEntry.fingerprint = new float[len];
	newEntry.location = location;
	memcpy( newEntry.fingerprint, observation, sizeof(float)*len );
	
	// add it to the DB
	entries.push_back( newEntry );
	return newEntry.uid;
}


float FingerprintDB::distance( const float A[], const float B[] ){
	// vector subtraction
	vDSP_vsub( A, 1, B, 1, buf1, 1, len );
	
	// square vector elements
	vDSP_vsq( buf1, 1, buf1, 1, len );

	// sum vector elements
	float result;
	vDSP_sve( buf1, 1, &result, len );
	
	return sqrt(result);
}


void FingerprintDB::makeRandomFingerprint( float outBuf[] ){
	outBuf[0] = 0.0;
	for( unsigned int i=1; i<len; ++i ){
		outBuf[i] = outBuf[i-1] + (random()%9) - 4;
	}
}


NSString* FingerprintDB::getDBFilename(){
	// get the documents directory:
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	// build the full filename
	return [NSString stringWithFormat:@"%@/%@", documentsDirectory, DBFilename];
}


bool FingerprintDB::save(){
	// create content - four lines of text
	NSMutableString *content = [[NSMutableString alloc] init];

	// loop through DB entries, appending to string
	for( int i=0; i<entries.size(); i++ ){
		[content appendFormat:@"%d\t%lld\t", 
		 entries[i].uid,
		 entries[i].timestamp];
		[content appendFormat:@"%.7f\t%.7f\t%.7f\t", /* 7 digit decimals should give ~1cm precision */
		 entries[i].location.latitude,
		 entries[i].location.longitude,
		 entries[i].location.altitude ];
		[content appendFormat:@"%@\t", entries[i].building ];
		[content appendFormat:@"%@", entries[i].room ];
		// add each element of fingerprint
		for( int j=0; j<len; j++ ){
			[content appendFormat:@"\t%f", entries[i].fingerprint[j] ];
		}
		// newline at end
		[content appendString:@"\n"];
	}
	// save content to the file
	[content writeToFile:this->getDBFilename() 
			  atomically:YES 
				encoding:NSStringEncodingConversionAllowLossy 
				   error:nil];
//  NSLog(@"SAVED:\n%@\n", content);
	[content release];
	return true;
	// TODO file access error handling
}


bool FingerprintDB::load(){
	// test that DB file exists
	NSString* DBFilename;
	if( [[NSFileManager defaultManager] fileExistsAtPath:this->getDBFilename()] ){
		DBFilename = [this->getDBFilename() retain];
	}else{
		// if there is no database.txt in the documents folder, then load the 
		// default database from the resources bundle
		DBFilename = [[[NSBundle mainBundle] pathForResource:@"database" 
													  ofType:@"txt"] retain];
	}
	
	// read contents of file
	NSString *content = [[NSString alloc] initWithContentsOfFile:DBFilename
													usedEncoding:nil
														   error:nil];
	[DBFilename release];
	
    ///NSLog(@"LOADED:\n%@\n", content);
	// fill DB with content
	NSScanner *scanner = [NSScanner scannerWithString:content];
	while( ![scanner isAtEnd] ){
		DBEntry newEntry;
		int theUid;
		[scanner scanInt:&theUid];
		newEntry.uid = theUid;
		[scanner scanLongLong:&newEntry.timestamp];
		[scanner scanDouble:&newEntry.location.latitude];
		[scanner scanDouble:&newEntry.location.longitude];
		[scanner scanDouble:&newEntry.location.altitude];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]
								intoString:&(newEntry.building)];
		[newEntry.building retain];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]
								intoString:&(newEntry.room)];
		[newEntry.room retain];

		// load fingerprint
		newEntry.fingerprint = new float[len];
		for( int j=0; j<len; j++ ){
			[scanner scanFloat:&(newEntry.fingerprint[j]) ];
		}		
		// add it to the DB
		entries.push_back( newEntry );
		// update maxUID
		if( theUid > this->maxUid ) this->maxUid = newEntry.uid;
	}		
	[content release];
	return true;
	// TODO file access error handling
}


void FingerprintDB::clear(){
	// clear database
	for( int i=entries.size()-1; i>=0; --i ){
		delete[] entries[i].fingerprint;
		[entries[i].building release];
		[entries[i].room release];
		entries.pop_back();
	}

	// erase the persistent store
	[[NSFileManager defaultManager] removeItemAtPath:this->getDBFilename()
											   error:nil];
}


bool FingerprintDB::getAllBuildings(vector<NSString*> & result ){
	bool ret = false;
	// TODO: keep a persistent list of buildings so we don't have to do this every time.
	for( int i=0; i<entries.size(); i++ ){
		NSString* currentBuilding = entries[i].building;
		// Note that we are not retaining this string b/c we assume that the 
		// DB entry will not be erased while we are using the results
		bool duplicate = false;
		for( int j=0; j<result.size(); j++ ){
			if( [result[j] isEqualToString:currentBuilding] ) duplicate = true;
		}
		if( !duplicate ){
			result.push_back( currentBuilding );
			ret = true;
		}
	}
	return ret;
}

bool FingerprintDB::getRoomsInBuilding(vector<NSString*> & result, /* output */
									   const NSString* building){        /* input */
	bool ret = false;
	for( int i=0; i<entries.size(); i++ ){
		if( [entries[i].building isEqualToString:building] ){
			NSString* currentRoom = entries[i].room;
			// Note that we are not retaining this string b/c we assume that the 
			// DB entry will not be erased while we are using the results
			bool duplicate = false;
			for( int j=0; j<result.size(); j++ ){
				if( [result[j] isEqualToString:currentRoom] ) duplicate = true;
			}
			if( !duplicate ){
				result.push_back( currentRoom );
				ret = true;
			}
		}
	}
	return ret;
}

bool FingerprintDB::getEntriesFrom(vector<DBEntry> & result, /* the output */
								   const NSString* building,
								   const NSString* room ){
	bool success = false;
	for( int i=0; i<entries.size(); i++ ){
		if( [entries[i].building isEqualToString:building] && 
		    [entries[i].room isEqualToString:room] ){
			result.push_back( entries[i] );
			success = true;
		}
	}
	return success;
}
