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

#include <iostream>
#include <fstream>

using std::vector;
using std::pair;
using std::make_pair;
using std::min;
using std::sort;


const NSString* DBFilename = @"db.txt";
const float FingerprintDB::neighborhoodRadius = 20; // meters


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
		[entries[i].location release];
	}
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


unsigned int FingerprintDB::queryMatches( QueryResult & result, 
										  const float observation[],  
										  unsigned int numMatches,
										  const CLLocation* location,
										  const DistanceMetric distanceMetric ){
	// TODO: range query using GPSLocation
	
	// calculate distances to all entries in DB
	pair<float,int> distances[entries.size()]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<entries.size(); ++i ){
		// if using acoustic or combined criterion then acoustic distance is primary sorting key
		if( distanceMetric == DistanceMetricAcoustic ){
			distances[i] = make_pair( signal_distance( observation, entries[i].fingerprint ), i );
		}else if( distanceMetric == DistanceMetricPhysical ){ // use physical distance
			distances[i] = make_pair( [location distanceFromLocation:entries[i].location], i );			
		}else{ // distanceMetric == DistanceMetricCombined
			distances[i] = make_pair( combined_distance( entries[i].fingerprint, 
						entries[i].location, observation, location ), i );			
		}
	}
	// sort distances
	sort(distances+0, distances+entries.size(), smaller_by_first );
	int k=0;
	for( unsigned int i=0; i<entries.size(); ++i ){
		// add only rooms which are not already represented in results
		DBEntry* e = &entries[distances[i].second];
		bool unique=true;
		for( int j=0; j<result.size(); j++ ){
			if( [result[j].entry.building isEqualToString:e->building] && 
			    [result[j].entry.room isEqualToString:e->room] ){
				unique=false;
				break;
			}
		}
		if(unique){
			Match m;
			m.entry = entries[distances[i].second];
			m.confidence = -(distances[i].first); //TODO: scale between 0 and 1
			m.distance = distances[i].first;
			result.push_back( m );
			if( ++k >= numMatches ){
				return k;
			}
		}
	}
	return k;
}


unsigned int FingerprintDB::insertFingerprint( const float observation[],
											   const NSString* newBuilding,
											   const NSString* newRoom,
											   const CLLocation* location){
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
	newEntry.location = [[location copy] retain];
	memcpy( newEntry.fingerprint, observation, sizeof(float)*len );
	
	// add it to the DB
	entries.push_back( newEntry );
	
	// save new line in DB file
	{
		// prepare the entry string
		NSMutableString *content = [[NSMutableString alloc] init];
		appendEntryString( content, newEntry );
		
		// open database file for appending
		NSString* filename = [this->getDBFilename() retain];
		std::ofstream dbFile;
		dbFile.open([filename UTF8String], std::ios::out | std::ios::app);
		dbFile << [content UTF8String]; // append the new entry
		dbFile.close();
		[filename release];
		[content release];
	}
	
	return newEntry.uid;
}


float FingerprintDB::signal_distance( const float A[], const float B[] ){
	// vector subtraction
	vDSP_vsub( A, 1, B, 1, buf1, 1, len );
	
	// square vector elements
	vDSP_vsq( buf1, 1, buf1, 1, len );

	// sum vector elements
	float result;
	vDSP_sve( buf1, 1, &result, len );
	
	return sqrt(result);
}


float FingerprintDB::combined_distance( float A[], const CLLocation* locA,
									    const float B[], const CLLocation* locB ){
	float sigDist = this->signal_distance( A, B );
	float physDist = [locA distanceFromLocation:locB];
	// constants for linear combination
	const float K=0.75; // metric combination factor
	// we also use the min/max expected distance between tags from same room
	// these constants were determined experimentally
	const float maxPhysDist=93; 
	const float minPhysDist=0;
	// find the normalization constant for acoustic distances
	//  As shortcut, just use 0 and 3*min(A)
	float minSigDist=0;
	float maxSigDist;
	vDSP_minv( A, 1, &maxSigDist, len );
	maxSigDist *= 3;

	return K * (sigDist-minSigDist)/(maxSigDist-minSigDist) +
			(1-K) * (physDist-minPhysDist)/(maxPhysDist-minPhysDist);
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


void FingerprintDB::appendEntryString( NSMutableString* outputBuffer, 
									   const DBEntry & entry ){
	[outputBuffer appendFormat:@"%d\t%lld\t", 
	 entry.uid,
	 entry.timestamp];
	[outputBuffer appendFormat:@"%.7f\t%.7f\t%.2f\t%.2f\t%.2f\t", /* 7 digit decimals should give ~1cm precision */
	 entry.location.coordinate.latitude,
	 entry.location.coordinate.longitude,
	 entry.location.altitude,
	 entry.location.horizontalAccuracy,
	 entry.location.verticalAccuracy];
	[outputBuffer appendFormat:@"%@\t", entry.building ];
	[outputBuffer appendFormat:@"%@", entry.room ];
	// add each element of fingerprint
	for( int j=0; j<len; j++ ){
		// we don't want "nan" in the database file, so replace it with 0
		if( entry.fingerprint[j] != entry.fingerprint[j] /* test for NaN */ ){
			[outputBuffer appendFormat:@"\t0" ];
		}else{
			[outputBuffer appendFormat:@"\t%.4g", entry.fingerprint[j] ];
		}
	}
	// newline at end
	[outputBuffer appendString:@"\n"];	
}


bool FingerprintDB::save(){
	// create content - four lines of text
	NSMutableString *content = [[NSMutableString alloc] init];

	// loop through DB entries, appending to string
	for( int i=0; i<entries.size(); i++ ){
		appendEntryString( content, entries[i] );
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
	bool loadedDefault = false;
	NSString* filename;
	if( [[NSFileManager defaultManager] fileExistsAtPath:this->getDBFilename()] ){
		filename = [this->getDBFilename() retain];
	}else{
		// if there is no db.txt in the documents folder, then load the 
		// default database from the resources bundle
		filename = [[[NSBundle mainBundle] pathForResource:@"database" 
													ofType:@"txt"] retain];
		loadedDefault = true;
	}
	
	// read contents of file
	NSString *content = [[NSString alloc] initWithContentsOfFile:filename
													usedEncoding:nil
														   error:nil];
	[filename release];
	
	// fill DB with content
	bool loadSuccess = loadFromString( content );
	[content release];
	// save entire database to file if we loaded the default DB from the app bundle
	if( loadedDefault && loadSuccess ) this->save();
	return loadSuccess;
	// TODO file access error handling
}


bool FingerprintDB::loadFromString( NSString* content ){
	NSScanner *scanner = [NSScanner scannerWithString:content];
	while( ![scanner isAtEnd] ){
		DBEntry newEntry;
		int theUid;
		[scanner scanInt:&theUid];
		newEntry.uid = theUid;
		[scanner scanLongLong:&newEntry.timestamp];
		double latitude, longitude, altitude, horiz_accuracy, vert_accuracy;
		[scanner scanDouble:&latitude];
		[scanner scanDouble:&longitude];
		[scanner scanDouble:&altitude];
		[scanner scanDouble:&horiz_accuracy];
		[scanner scanDouble:&vert_accuracy];
		newEntry.location = [[CLLocation alloc] 
							 initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) 
							 altitude:altitude horizontalAccuracy:horiz_accuracy
							 verticalAccuracy:vert_accuracy timestamp:0];
		[newEntry.location retain];

		 [scanner scanUpToString:@"\t" intoString:&(newEntry.building)];
		[newEntry.building retain];
		[scanner scanUpToString:@"\t" intoString:&(newEntry.room)];
		[newEntry.room retain];
		
		// load remainder of line
		//  we do this so that any junk at end of line (eg if fingerprint is too long)
		//  won't throw off the scanner alignment
		NSString* remainder;
		[scanner scanUpToString:@"\n" intoString:&remainder];
		NSScanner *floatScanner = [NSScanner scannerWithString:remainder];

		// load fingerprint from remainder
		newEntry.fingerprint = new float[len];
		for( int j=0; j<len; j++ ){
			[floatScanner scanFloat:&(newEntry.fingerprint[j]) ];
		}
		
		// add it to the DB
		entries.push_back( newEntry );
		// update maxUID
		if( theUid > this->maxUid ) this->maxUid = newEntry.uid;
	}
    NSLog(@"loaded %d database entries", entries.size());
	return true; // TODO: handle improper file format errors and return false
}


void FingerprintDB::clear(){
	// clear database
	for( int i=entries.size()-1; i>=0; --i ){
		delete[] entries[i].fingerprint;
		[entries[i].building release];
		[entries[i].room release];
		[entries[i].location release];
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

void FingerprintDB::deleteRoom( const NSString* building, const NSString* room ){
	bool didSomething = false;
	for( int i=0; i<entries.size(); i++ ){
		if( [entries[i].building isEqualToString:building] && 
		    [entries[i].room isEqualToString:room] ){
			entries.erase(entries.begin()+i); // erase this entry
			i--; // decrement i because vector just contracted
			didSomething = true;
		}
	}
	// if DB was modified then resave it
	if(didSomething){
		save();
	}
	
}
