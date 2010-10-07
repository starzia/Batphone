/*
 *  tester.c
 *  Fingerprinter
 *
 *  Created by Stephen Tarzia on 9/23/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 * Compile this on the command line using "make"
 */


#import "Fingerprinter.h"
#import <iostream>
#include <unistd.h>

using namespace std;

void printFingerprint( Fingerprint fingerprint ){
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << fingerprint[i] << ' ';
	}
	cout << endl;
}

int main(){
	Fingerprinter fp;
	// start recording fingerprints
	fp.startRecording();
	cout << "Wait ten seconds to gather enough data for a fingerprint" << endl;
	sleep(11);
	
	// get the latest fingerprint 
	Fingerprint observed = new float[Fingerprinter::fpLength];
	// getFingerprint fills in the passed array
	fp.getFingerprint(observed);

	cout << "Newly observed fingerprint:" <<endl;
	printFingerprint(observed);
	
	
	// query for a list of matches
	cout << endl << "DB Matches:" <<endl;
	int NUM_MATCHES = 3;
	QueryResult* qr = fp.queryMatches( observed, NUM_MATCHES );
	for( int i=0; i<NUM_MATCHES; i++ ){
		cout << "match #" << i << '\t'
		     << "uid=" << (*qr)[i].uid << '\t' 
		     << "name=" << fp.queryName( (*qr)[i].uid ) << '\t' 
		     << "confidence=" << (*qr)[i].confidence << '\t'
		     << "fingerprint= ";
		// query fingerprint saves the query result in observed
		fp.queryFingerprint( (*qr)[i].uid, observed );
		printFingerprint( observed );
	}
	
	// assuming that we were not satisfied with any of the results, add this as a new room
	fp.insertFingerprint( observed, string( "newRoom" ) );
						 
	delete[] observed;
	delete qr;
}
