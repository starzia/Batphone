/*
 *  Fingerprinter.cpp
 *
 *  Created by Stephen Tarzia on 9/23/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Fingerprinter.h"

#include <stdlib.h> // for random()
using namespace std;

// DUMMY IMPLEMENTATION
const unsigned int Fingerprinter::fpLength = 128;

Fingerprinter::Fingerprinter(){}	

Fingerprint* Fingerprinter::recordFingerprint(){
	return this->makeRandomFingerprint();
}

QueryResult* Fingerprinter::queryMatches( Fingerprint* observation, unsigned int numMatches ){
	QueryResult* qr = new QueryResult(numMatches);
	float confidence = 1.0;
	for( int i=0; i<numMatches; i++ ){
		(*qr)[i].uid = (random()%100);
		confidence -= (random()%100)/1000.0;
		if( confidence < 0 ) confidence = 0;
		(*qr)[i].confidence = confidence;
	}
	return qr;
}

string Fingerprinter::queryName( unsigned int uid ){
	char name[7];
	sprintf( name, "room%d", (int)(random()%100) );
	return string(name);
}

Fingerprint* Fingerprinter::queryFingerprint( unsigned int uid ){
	return this->makeRandomFingerprint();
}

unsigned int Fingerprinter::insertFingerprint( Fingerprint* observation, string name ){
	return random()%100;
}

/* Destructor.  Cleans up. */
Fingerprinter::~Fingerprinter(){}

Fingerprint* Fingerprinter::makeRandomFingerprint(){
	Fingerprint* fp = new Fingerprint(Fingerprinter::fpLength);
	(*fp)[0] = 0.0;
	for( int i=1; i<Fingerprinter::fpLength; ++i ){
		(*fp)[i] = (*fp)[i-1] + (random()%9) - 4;
	}
	return fp;
}