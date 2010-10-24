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
const float neighborhoodRadius=20; // meters, the maximum distance of a fingerprint returned from a query when DistanceMetricCombined is used.

@implementation FingerprintDB;

@synthesize len;
@synthesize cache;
@synthesize buf1;
@synthesize receivedData;
@synthesize maxUid;

-(id) initWithFPLength:(unsigned int) fpLength{
	[super init];
	len = fpLength;
	buf1 = new float[fpLength];
	[self loadCache];
	return self;
}


-(void)dealloc{
	delete[] buf1;
	
	// clear database
	for( unsigned int i=0; i<cache.size(); ++i ){
		delete[] cache[i].fingerprint;
		[cache[i].building release];
		[cache[i].room release];
		[cache[i].location release];
	}
	[super dealloc];
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


-(unsigned int) queryMatches:(QueryResult&)result /* the output */
				 observation:(const float[])observation  /* observed Fingerprint we want to match */
				  numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
					location:(CLLocation*)location /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
			  distanceMetric:(DistanceMetric)distanceMetric{
	// calculate distances to all entries in DB cache
	pair<float,int> distances[cache.size()]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<cache.size(); ++i ){
		// if using acoustic or combined criterion then acoustic distance is primary sorting key
		if( distanceMetric == DistanceMetricAcoustic ){
			distances[i] = make_pair( [self signalDistanceFrom:observation to:cache[i].fingerprint ], i );
		}else if( distanceMetric == DistanceMetricPhysical ){ // use physical distance
			distances[i] = make_pair( [location distanceFromLocation:cache[i].location], i );			
		}else{ // distanceMetric == DistanceMetricCombined
			distances[i] = make_pair( [self combinedDistanceFrom:cache[i].fingerprint 
														 withLoc:cache[i].location 
															  to:observation
														 withLoc:location ], i );			
		}
	}
	// sort distances
	sort(distances+0, distances+cache.size(), smaller_by_first );
	int k=0;
	for( unsigned int i=0; i<cache.size(); ++i ){
		// add only rooms which are not already represented in results
		DBEntry* e = &cache[distances[i].second];
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
			m.entry = cache[distances[i].second];
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


-(unsigned int) insertFingerprint:(const float[])observation
						 building:(NSString*)newBuilding      
							 room:(NSString*)newRoom /* name for the new room */
						 location:(CLLocation*)location{
	// create new DB entry
	DBEntry newEntry;
	NSDate *now = [NSDate date];
	newEntry.timestamp = [now timeIntervalSince1970];
	newEntry.room = newRoom;
	[newEntry.room retain];
	newEntry.building = newBuilding;
	[newEntry.building retain];
	newEntry.uid = ++(self.maxUid); // increment and assign uid
	newEntry.fingerprint = new float[len];
	newEntry.location = [[location copy] retain];
	memcpy( newEntry.fingerprint, observation, sizeof(float)*len );
	
	// send the request to the remote database
	{
		NSString *post = @"key1=val1&key2=val2";
		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
		
		NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
		[request setURL:[NSURL URLWithString:@"http://stevetarzia.com/cgi-bin/fingerprint/interface.py"]];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody:postData];
		
		NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:request delegate:self];
		if (theConnection) {
			// Create the NSMutableData to hold the received data.
			// receivedData is an instance variable declared elsewhere.
			receivedData = [[NSMutableData data] retain];
		} else {
			// Inform the user that the connection failed.
		}
		// TODO: assign uid from INSERT return value
		newEntry.uid = -1;
	}
	
	// add it to the cache DB
	cache.push_back( newEntry );
	
	// save new line in DB file
	{
		// prepare the entry string
		NSMutableString *content = [[NSMutableString alloc] init];
		[self appendEntry:newEntry toString:content];
		
		// open database file for appending
		NSString* filename = [[self getDBFilename] retain];
		std::ofstream dbFile;
		dbFile.open([filename UTF8String], std::ios::out | std::ios::app);
		dbFile << [content UTF8String]; // append the new entry
		dbFile.close();
		[filename release];
		[content release];
	}
	
	return newEntry.uid;
}


-(float) signalDistanceFrom:(const float[])A to:(const float[])B{
	// vector subtraction
	vDSP_vsub( A, 1, B, 1, buf1, 1, len );
	
	// square vector elements
	vDSP_vsq( buf1, 1, buf1, 1, len );

	// sum vector elements
	float result;
	vDSP_sve( buf1, 1, &result, len );
	
	return sqrt(result);
}


-(float) combinedDistanceFrom:(float[])A
					  withLoc:(const CLLocation*)locA
						   to:(float[])B
					  withLoc:(const CLLocation*)locB{
	float sigDist = [self signalDistanceFrom:A to:B];
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


-(void) makeRandomFingerprint:(float[])outBuf{
	outBuf[0] = 0.0;
	for( unsigned int i=1; i<len; ++i ){
		outBuf[i] = outBuf[i-1] + (random()%9) - 4;
	}
}


-(NSString*)getDBFilename{
       // get the documents directory:
       NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
       NSString *documentsDirectory = [paths objectAtIndex:0];
       
       // build the full filename
       return [NSString stringWithFormat:@"%@/%@", documentsDirectory, DBFilename];
}


-(void) appendEntry:(const DBEntry&)entry
		   toString:(NSMutableString*)outputBuffer{
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


-(bool) saveCache{
	// create content
	NSMutableString *content = [[NSMutableString alloc] init];

	// loop through DB cache, appending to string
	for( int i=0; i<cache.size(); i++ ){
		[self appendEntry:cache[i] toString:content];
	}
	// save content to the file
	[content writeToFile:[self getDBFilename] 
			  atomically:YES 
				encoding:NSStringEncodingConversionAllowLossy 
				   error:nil];

    [content release];
    return true;
    // TODO file access error handling
}


-(bool) loadCache{
	// test that DB file exists
	bool loadedDefault = false;
	NSString* filename;
	if( [[NSFileManager defaultManager] fileExistsAtPath:[self getDBFilename]] ){
		filename = [[self getDBFilename] retain];
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
    bool loadSuccess = [self loadCacheFromString:content];
	[content release];
	// save entire database to file if we loaded the default DB from the app bundle
	if( loadedDefault && loadSuccess ) [self saveCache];
	return loadSuccess;
	// TODO file access error handling
}


-(bool) loadCacheFromString:( NSString* )content{
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
		cache.push_back( newEntry );
		// update maxUID
		if( theUid > self.maxUid ) self.maxUid = newEntry.uid;
	}
    NSLog(@"loaded %d database cache entries", cache.size());
	return true; // TODO: handle improper file format errors and return false
}
		

-(void) clearCache{
	// clear database
	for( int i=cache.size()-1; i>=0; --i ){
		delete[] cache[i].fingerprint;
		[cache[i].building release];
		[cache[i].room release];
		[cache[i].location release];
		cache.pop_back();
	}

	// erase the persistent store
	[[NSFileManager defaultManager] removeItemAtPath:[self getDBFilename]
											   error:nil];
}


-(bool) getAllBuildings:(vector<NSString*>&)result{
	bool ret = false;
	// TODO: keep a persistent list of buildings so we don't have to do this every time.
	for( int i=0; i<cache.size(); i++ ){
		NSString* currentBuilding = cache[i].building;
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

-(bool) getRooms:(vector<NSString*>&)result /* output */
	  inBuilding:(const NSString*)building{        /* input */
	bool ret = false;
	for( int i=0; i<cache.size(); i++ ){
		if( [cache[i].building isEqualToString:building] ){
			NSString* currentRoom = cache[i].room;
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

-(bool) getEntries:(vector<DBEntry>&) result /* the output */
		  fromRoom:(const NSString*)room
		inBuilding:(const NSString*)building{
	bool success = false;
	for( int i=0; i<cache.size(); i++ ){
		if( [cache[i].building isEqualToString:building] && 
		   [cache[i].room isEqualToString:room] ){
			result.push_back( cache[i] );
			success = true;
		}
	}
	return success;
}

-(void) deleteRoom:(const NSString*)room
		inBuilding:(const NSString*)building{
	bool didSomething = false;
	for( int i=0; i<cache.size(); i++ ){
		if( [cache[i].building isEqualToString:building] && 
		   [cache[i].room isEqualToString:room] ){
			cache.erase(cache.begin()+i); // erase this entry
			i--; // decrement i because vector just contracted
			didSomething = true;
		}
	}
	// if DB was modified then resave it
	if(didSomething){
		[self saveCache];
	}
	
}

#pragma mark -
#pragma mark URLRequestDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
	
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
	
    // receivedData is an instance variable declared elsewhere.
    [receivedData setLength:0];
	NSLog(@"Got HTTP response");
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [receivedData appendData:data];
	
	NSLog(@"Received %d bytes of data",[receivedData length]);  
    NSString *aStr = [[NSString alloc] initWithData:receivedData encoding:NSASCIIStringEncoding];  
    NSLog(@"%@",aStr); 
	[aStr release];
}

@end
