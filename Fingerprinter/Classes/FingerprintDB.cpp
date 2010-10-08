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

using std::string;
using std::vector;
using std::pair;
using std::make_pair;
using std::min;
using std::partial_sort;

FingerprintDB::FingerprintDB( unsigned int fpLength ): len(fpLength) {
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
	}
}


// comparison used in sort below
bool smaller_by_first( pair<float,int> A, pair<float,int> B ){
	return ( A.first < B.first );
}


unsigned int FingerprintDB::queryMatches( QueryResult & result, 
										  const float observation[],  unsigned int numMatches ){
	unsigned int resultSize = min(numMatches, (unsigned int)entries.size() );
	
	// calculate distances to all entries in DB
	pair<float,int> distances[entries.size()]; // first element of pair is distance, second is index
	for( unsigned int i=0; i<entries.size(); ++i ){
		distances[i] = make_pair( distance( observation, entries[i].fingerprint ), i );
	}
	// sort distances (partial sort b/c we are interested only in first numMatches)
	partial_sort(distances+0, distances+resultSize, distances+entries.size(), smaller_by_first );
	for( unsigned int i=0; i<numMatches; ++i ){
		Match m;
		m.entry = entries[distances[i].second];
		m.confidence = -distances[i].first; //TODO: scale between 0 and 1
		result.push_back( m );
	}
	return resultSize;
}


string FingerprintDB::queryName( unsigned int uid ){
	char name[7];
	sprintf( name, "room%d", (int)(random()%100) );
	return string(name);
}


bool FingerprintDB::queryFingerprint( unsigned int uid, float outputFingerprint[] ){
	this->makeRandomFingerprint( outputFingerprint );
	return true;
}


unsigned int FingerprintDB::insertFingerprint( const float observation[], string name ){
	// create new DB entry
	DBEntry newEntry;
	newEntry.name = name;
	newEntry.uid = entries.size();
	newEntry.fingerprint = new float[len];
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
