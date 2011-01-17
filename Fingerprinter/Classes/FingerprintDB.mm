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

#import "Fingerprinter.h" // for fpLength
@implementation DBEntry;
@synthesize timestamp;
@synthesize uuid;
@synthesize building;
@synthesize room;
@synthesize fingerprint;
@synthesize location;
-(id) init{
	self = [super init];
	fingerprint = new float[Fingerprinter::fpLength];
	memset( fingerprint, 0.0, sizeof(float)*Fingerprinter::fpLength );
	return self;
}
-(void) dealloc{
	delete [] fingerprint;
	[super dealloc];
}
@end

@implementation Match;
@synthesize entry;
@synthesize confidence;
@synthesize distance;
-(id) init{
	self = [super init];
	entry = [[DBEntry alloc] init];
	return self;
}
-(void) dealloc{
	[super dealloc];
}
@end


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
@synthesize httpConnectionData;
@synthesize callbackTarget;
@synthesize callbackSelector;

-(id) initWithFPLength:(unsigned int) fpLength{
	[super init];
	len = fpLength;
	buf1 = new float[fpLength];
	[self loadCache];
	httpConnectionData = [[NSMutableDictionary alloc] initWithObjectsAndKeys:nil];
	/*
	httpConnectionData = CFDictionaryCreateMutable( kCFAllocatorDefault,
											0,
											&kCFTypeDictionaryKeyCallBacks,
											&kCFTypeDictionaryValueCallBacks);
	 */
	 return self;
}


-(void)dealloc{
	delete[] buf1;
	[httpConnectionData release];
	
	// clear database
	[cache release];

	[super dealloc];
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


-(unsigned int) queryCacheForMatches:(NSMutableArray*)result /* the output */
						 observation:(const float[])observation  /* observed Fingerprint we want to match */
						  numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
							location:(CLLocation*)location /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
					  distanceMetric:(DistanceMetric)distanceMetric{
	// calculate distances to all entries in DB cache
	pair<float,int> distances[[cache count]]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<[cache count]; ++i ){
		DBEntry* cacheI = (DBEntry*)[cache objectAtIndex:0];
		// if using acoustic or combined criterion then acoustic distance is primary sorting key
		if( distanceMetric == DistanceMetricAcoustic ){
			distances[i] = make_pair( [self signalDistanceFrom:observation to:cacheI.fingerprint], i );
		}else if( distanceMetric == DistanceMetricPhysical ){ // use physical distance
			distances[i] = make_pair( [location distanceFromLocation:cacheI.location], i );			
		}else{ // distanceMetric == DistanceMetricCombined
			distances[i] = make_pair( [self combinedDistanceFrom:cacheI.fingerprint 
														 withLoc:cacheI.location 
															  to:observation
														 withLoc:location ], i );			
		}
	}
	// sort distances
	sort(distances+0, distances+[cache count], smaller_by_first );
	int k=0;
	for( unsigned int i=0; i<[cache count]; ++i ){
		// add only rooms which are not already represented in results
		DBEntry* e = [cache objectAtIndex:distances[i].second];
		bool unique=true;
		for( Match* oldMatch in result ){
			if( [oldMatch.entry.building isEqualToString:e->building] && 
			    [oldMatch.entry.room isEqualToString:e->room] ){
				unique=false;
				break;
			}
		}
		if(unique){
			Match* m = [[Match alloc] init];
			m.entry = [cache objectAtIndex:distances[i].second];
			m.confidence = -(distances[i].first); //TODO: scale between 0 and 1
			m.distance = distances[i].first;
			[result addObject:m];
			[m release];
			if( ++k >= numMatches ){
				return k;
			}
		}
	}
	return k;
}




-(NSString*) insertFingerprint:(const float[])observation
					  building:(NSString*)newBuilding      
						  room:(NSString*)newRoom /* name for the new room */
					  location:(CLLocation*)location{
	// create new DB entry
	DBEntry* newEntry = [[DBEntry alloc] init];
	NSDate *now = [NSDate date];
	newEntry.timestamp = [now timeIntervalSince1970];
	newEntry.room = newRoom;
	newEntry.building = newBuilding;
	newEntry.fingerprint = new float[len];
	newEntry.location = [location copy];
	memcpy( newEntry.fingerprint, observation, sizeof(float)*len );
	newEntry.uuid = [[NSString alloc] initWithFormat:@"-1"]; // TODO generate UUID
	
	// send the request to the remote database
	[self addToRemoteDB:newEntry];
	
	/* NOTE after transitioning to the remote DB, we can no longer record these 
	   new entries in the cache because we don't have the correct uuid yet.  New
	   entries should be returned in the next query (including the assigned uuid)
	   and at that time they will be added to the cache
	 
	// add it to the cache DB
	[self addToCache:newEntry];
	
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
	 */
	[newEntry autorelease];
	return newEntry.uuid;
}


-(void) httpPostWithString:(NSString*)postExtra
					  type:(NSString*)type
			   observation:(const float[])obs
				  location:(CLLocation*)location{
	// standard post data
	NSMutableString *post = [[NSMutableString alloc] init];
	[post appendFormat:@"type=%@",type];
	[post appendFormat:@"&fingerprint_length=%d",len];
	[post appendFormat:@"&fingerprint=%f",obs[0]];
	for( int i=1; i<len; i++ ){
		[post appendFormat:@"_%f",obs[i]];
	}
	if( location.coordinate.latitude != NAN ){
		[post appendFormat:@"&latitude=%f&longitude=%f&altitude=%f",
		 location.coordinate.latitude, location.coordinate.longitude, location.altitude ];
	}
	[post appendFormat:@"&user_id=Steve"];
	
	// additional request-specific post data
	[post appendFormat:@"%@",postExtra];
	//NSLog(@"%@",post);

	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
	
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setURL:[NSURL URLWithString:@"http://belmont.eecs.northwestern.edu/cgi-bin/fingerprint/interface.py"]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; // don't use request cache
    
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (theConnection) {
		// create record for this connection
		NSMutableDictionary *connectionInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
											   [[NSMutableData alloc] initWithLength:0], @"receivedData", type, @"type",nil];
		[httpConnectionData setObject:connectionInfo forKey:[theConnection description]];
	} else {
		// Inform the user that the connection failed.
	}
}


-(void) addToRemoteDB:(DBEntry*)newEntry{
	NSMutableString *post = [[NSMutableString alloc] init];
	[post appendFormat:@"&building=%@",newEntry.building];
	[post appendFormat:@"&room=%@",newEntry.room];
	
	[self httpPostWithString:post type:@"insert" observation:newEntry.fingerprint location:newEntry.location];
}


-(void) addToCache:(DBEntry*)newEntry{
	// scan cache looking for a duplicate entry
	// TODO: use index tree to speed this up
	bool duplicate = false;
	for( DBEntry* e in cache ){
		if( [e.uuid isEqualToString:newEntry.uuid] ){
			duplicate = true;
			break;
		}
	}
	if( !duplicate ){
		[cache addObject:newEntry];
	}
}


-(void) startQueryWithObservation:(const float[])obs  /* observed Fingerprint we want to match */
					   numMatches:(unsigned int)numMatches /* desired number of results. NOTE: may return fewer if DB is small, possibly zero. */
						 location:(CLLocation*)loc /* optional estimate of the current GPS location; if unneeded, set to NULL_GPS */
				   distanceMetric:(DistanceMetric)distance
					 resultTarget:(id) target
						 selector:(SEL) selector{
	// set up callback
	self.callbackTarget = target;
	self.callbackSelector = selector;
	
	NSMutableString *post = [[NSMutableString alloc] init];
	[post appendFormat:@"&num_matches=%d",numMatches];
	
	[self httpPostWithString:post type:@"select" observation:obs location:loc];	
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


-(void) appendEntry:(const DBEntry*)entry
		   toString:(NSMutableString*)outputBuffer{
	[outputBuffer appendFormat:@"%@\t%lld\t", 
	 entry.uuid,
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
	for( DBEntry* e in cache ){
		[self appendEntry:e toString:content];
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
		DBEntry* newEntry = [[DBEntry alloc] init];
		NSString* tmpStr;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]
								intoString:&tmpStr];
		newEntry.uuid = [NSString stringWithString:tmpStr];
		long long tmpLL;
		[scanner scanLongLong:&tmpLL];
		newEntry.timestamp = tmpLL;
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

		[scanner scanUpToString:@"\t" intoString:&tmpStr];
		newEntry.building = [NSString stringWithString:tmpStr];
		[scanner scanUpToString:@"\t" intoString:&tmpStr];
		newEntry.room = [NSString stringWithString:tmpStr];
		
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
		[cache addObject:newEntry];
		[newEntry release];
	}
    NSLog(@"loaded %d database cache entries", [cache count]);
	return true; // TODO: handle improper file format errors and return false
}
		

-(void) clearCache{
	// clear database
	[cache removeAllObjects];

	// erase the persistent store
	[[NSFileManager defaultManager] removeItemAtPath:[self getDBFilename]
											   error:nil];
}


-(bool) getAllBuildings:(vector<NSString*>&)result{
	bool ret = false;
	// TODO: keep a persistent list of buildings so we don't have to do this every time.
	for( DBEntry* e in cache ){
		NSString* currentBuilding = e.building;
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
	for( DBEntry* e in cache ){
		if( [e.building isEqualToString:building] ){
			NSString* currentRoom = e.room;
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

-(bool) getEntries:(vector<DBEntry*>&) result /* the output */
		  fromRoom:(const NSString*)room
		inBuilding:(const NSString*)building{
	bool success = false;
	for( DBEntry* e in cache ){
		if( [e.building isEqualToString:building] && 
		   [e.room isEqualToString:room] ){
			result.push_back( e );
			success = true;
		}
	}
	return success;
}

-(void) deleteRoom:(const NSString*)room
		inBuilding:(const NSString*)building{
	bool didSomething = false;
	for( DBEntry* e in cache ){
		if( [e.building isEqualToString:building] && 
		   [e.room isEqualToString:room] ){
			[cache removeObject:e];
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

	// retreive reference to data for this connection
	NSMutableDictionary *connectionInfo = [httpConnectionData objectForKey:[connection description]];
    NSMutableData* connectionData = [connectionInfo objectForKey:@"receivedData"];
	
    [connectionData setLength:0];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
	// retreive reference to data for this connection
	NSMutableDictionary *connectionInfo = [httpConnectionData objectForKey:[connection description]];
    NSMutableData* connectionData = [connectionInfo objectForKey:@"receivedData"];
	
	// Append the new data to receivedData.
	[connectionData appendData:data];

	/*
	NSLog(@"Received %d bytes of data",[connectionData length]);  
    NSString *aStr = [[NSString alloc] initWithData:connectionData encoding:NSASCIIStringEncoding];  
    NSLog(@"%@",aStr); 
	[aStr release];
	 */
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
	// retreive reference to data for this connection
	NSMutableDictionary *connectionInfo = [httpConnectionData objectForKey:[connection description]];
    NSMutableData* connectionData = [connectionInfo objectForKey:@"receivedData"];

    // do something with the data
	
	// if this was a select query, then we should do something in response
	if( [(NSString*)[connectionInfo objectForKey:@"type"] isEqualToString:@"select"] ){
		NSMutableArray* matches = [[NSMutableArray alloc] init];
		
		// parse the HTTP response
		NSString *aStr = [[NSString alloc] initWithData:connectionData encoding:NSASCIIStringEncoding];  
		NSScanner *scanner = [NSScanner scannerWithString:aStr];
		if( ![scanner isAtEnd] ){
			
			// scan header
			NSString* remainder;
			[scanner scanUpToString:@"\n" intoString:&remainder];
			NSScanner *scanner2 = [NSScanner scannerWithString:remainder];
			int numMatches;
			[scanner2 scanInt:&numMatches];
			
			// scan each result
			for ( int i=0; i<numMatches; i++ ){
				Match* m = [[Match alloc] init];
				NSString* tmpStr;
				[scanner scanUpToString:@"\t" intoString:&tmpStr];
				m.entry.uuid = [NSString stringWithString:tmpStr];
				float tmpFloat;
				[scanner scanFloat:&tmpFloat];
				m.confidence = tmpFloat;
				[scanner scanUpToString:@"\t" intoString:&tmpStr];
				m.entry.building = [NSString stringWithString:tmpStr];
				[scanner scanUpToString:@"\t" intoString:&tmpStr];
				m.entry.room = [NSString stringWithString:tmpStr ];
				
				double latitude, longitude, altitude;
				[scanner scanDouble:&latitude];
				[scanner scanDouble:&longitude];
				[scanner scanDouble:&altitude];
				m.entry.location = [[CLLocation alloc] 
									 initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) 
									 altitude:altitude horizontalAccuracy:0
									 verticalAccuracy:0 timestamp:0];
				
				//[scanner scanUpToString:@"\n" intoString:nil]; // scan whatever junk remains on line
				// TODO: in future, remote DB should provide fingerprint, for now just leave a blank one
				
				[matches addObject:m];
				
				// add this match to the cache for future reference
				[self addToCache:m.entry];
				
				[m release];
			}
			
		}
		
		// now notify client that matches are ready
		[callbackTarget performSelector:callbackSelector withObject:matches];
		
		[aStr release];
	}
	
	// remove record of this connection
	[httpConnectionData removeObjectForKey:[connection description]];

    // release the connection
    [connection release];
}


- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error{
	// remove record of this connection
	[httpConnectionData removeObjectForKey:[connection description]];

    // release the connection
    [connection release];
	
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription] );
}

@end
