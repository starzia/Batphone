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

@implementation FingerprintDB;

@synthesize len;
@synthesize cache;
@synthesize buf1;
@synthesize receivedData;

-(void)	initWithFPLength:(unsigned int) fpLength{
	len = fpLength;
	buf1 = new float[fpLength];
	[self loadCache];
}


-(void)dealloc{
	delete[] buf1;
	
	// clear database
	for( unsigned int i=0; i<cache.size(); ++i ){
		delete[] cache[i].fingerprint;
		[cache[i].name release];
		[cache[i].uuid release];
	}
	[super dealloc];
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


-(unsigned int) queryMatches:(QueryResult&)result 
				 observation:(const float[])observation 
				  numMatches:(unsigned int)numMatches 
					location:(GPSLocation)location{
	// TODO: range query using GPSLocation
	unsigned int resultSize = min(numMatches, (unsigned int)cache.size() );
	
	// calculate distances to all entries in DB
	pair<float,int>* distances = new pair<float,int>[cache.size()]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<cache.size(); ++i ){
		distances[i] = make_pair( [self distanceFrom:observation to:cache[i].fingerprint], i );
	}
	// sort distances (partial sort b/c we are interested only in first numMatches)
	partial_sort(distances+0, distances+resultSize, distances+cache.size(), smaller_by_first );
	for( unsigned int i=0; i<resultSize; ++i ){
		Match m;
		m.entry = cache[distances[i].second];
		m.confidence = -(distances[i].first); //TODO: scale between 0 and 1
		result.push_back( m );
	}
	delete distances;
	return resultSize;
}


-(NSString*) insertFingerprint:(const float[])observation
						  name:(NSString*)newName      
					  location:(GPSLocation)location{
	// create new DB entry
	DBEntry newEntry;
	NSDate *now = [NSDate date];
	newEntry.timestamp = [now timeIntervalSince1970];
	newEntry.name = newName;
	[newEntry.name retain];
	newEntry.fingerprint = new float[len];
	newEntry.location = location;
	memcpy( newEntry.fingerprint, observation, sizeof(float)*len );
	newEntry.uuid = [[NSString alloc] initWithFormat:@"-1"]; // TODO generate UUID
	
	// send the request to the remote database
	[self addToRemoteDB:newEntry];

	// add it to the cache DB
	cache.push_back( newEntry );
	
	return newEntry.uuid;
}


-(void) addToRemoteDB:(DBEntry&)newEntry{
	NSMutableString *post = [[NSMutableString alloc] init];
	[post appendFormat:@"type=insert&fingerprint_length=%d",len];
	[post appendFormat:@"&fingerprint=%f",newEntry.fingerprint[0]];
	for( int i=1; i<len; i++ ){
		[post appendFormat:@"_%f",newEntry.fingerprint[i]];
	}
	if( newEntry.location.latitude != NAN ){
		[post appendFormat:@"&latitude=%f&longitude=%f&altitude=%f",
		 newEntry.location.latitude, newEntry.location.longitude, newEntry.location.altitude ];
	}
	[post appendFormat:@"&user_id=Steve"];
	[post appendFormat:@"&building=NULL"];
	[post appendFormat:@"&room_name=%@",newEntry.name];
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	
	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
	
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setURL:[NSURL URLWithString:@"http://stevetarzia.com/cgi-bin/fingerprint/cgi.php"]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; // don't use request cache
    
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (theConnection) {
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData alloc] initWithLength:0];
	} else {
		// Inform the user that the connection failed.
	}
}


-(float)distanceFrom:(const float [])A to:(const float [])B{
	// vector subtraction
	vDSP_vsub( A, 1, B, 1, buf1, 1, len );
	
	// square vector elements
	vDSP_vsq( buf1, 1, buf1, 1, len );

	// sum vector elements
	float result;
	vDSP_sve( buf1, 1, &result, len );
	
	return sqrt(result);
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


-(bool) saveCache{
       // create content - four lines of text
       NSMutableString *content = [[NSMutableString alloc] init];

       // loop through DB cache, appending to string
       for( int i=0; i<cache.size(); i++ ){
               [content appendFormat:@"%s\t%lld\t", 
                cache[i].uuid,
                cache[i].timestamp];
               [content appendFormat:@"%.7f\t%.7f\t%.7f\t", /* 7 digit decimals should give ~1cm precision */
                cache[i].location.latitude,
                cache[i].location.longitude,
                cache[i].location.altitude ];
               [content appendFormat:@"%@", cache[i].name ];
               // add each element of fingerprint
               for( int j=0; j<len; j++ ){
                       [content appendFormat:@"\t%f", cache[i].fingerprint[j] ];
               }
               // newline at end
               [content appendString:@"\n"];
       }
       // save content to the file
       [content writeToFile:[self getDBFilename] 
                         atomically:YES 
                               encoding:NSStringEncodingConversionAllowLossy 
                                  error:nil];
//  NSLog(@"SAVED:\n%@\n", content);
       [content release];
       return true;
       // TODO file access error handling
}

																  
-(bool) loadCache{
    // test that DB file exists
    if( ![[NSFileManager defaultManager] fileExistsAtPath:[self getDBFilename]] ){
        return false;
	}
	
    // read contents of file
    NSString *content = [[NSString alloc] initWithContentsOfFile:[self getDBFilename]
													usedEncoding:nil
														   error:nil];
    NSLog(@"LOADED:\n%@\n", content);
	// fill DB with content
	NSScanner *scanner = [NSScanner scannerWithString:content];
	while( ![scanner isAtEnd] ){
		DBEntry newEntry;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]
								intoString:&(newEntry.uuid)];
		[newEntry.uuid retain];
		[scanner scanLongLong:&newEntry.timestamp];
		[scanner scanDouble:&newEntry.location.latitude];
		[scanner scanDouble:&newEntry.location.longitude];
		[scanner scanDouble:&newEntry.location.altitude];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]
								intoString:&(newEntry.name)];
		[newEntry.name retain];
		 
		// load fingerprint
		newEntry.fingerprint = new float[len];
		for( int j=0; j<len; j++ ){
			[scanner scanFloat:&(newEntry.fingerprint[j]) ];
		}               
		// add it to the DB
		cache.push_back( newEntry );
	}               
	[content release];
	return true;
	// TODO file access error handling
}
		

-(void) clearCache{
	// clear database
	for( int i=cache.size()-1; i>=0; --i ){
		delete[] cache[i].fingerprint;
		[cache[i].name release];
		[cache[i].name release];
		cache.pop_back();
	}

	// erase the persistent store
	[[NSFileManager defaultManager] removeItemAtPath:[self getDBFilename]
											   error:nil];
}

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


- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    NSLog(@"Succeeded! Received %d bytes of data",[receivedData length]);
	
    // release the connection, and the data object
    [connection release];
    [receivedData release];
}


- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error{
    // release the connection, and the data object
    [connection release];	
    // receivedData is declared as a method instance elsewhere
	[receivedData release];
	
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription] );
}

@end