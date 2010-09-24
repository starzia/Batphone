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

using namespace std;

void printFingerprint( Fingerprint* fingerprint ){
	for( int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << (*fingerprint)[i] << ' ';
	}
	cout << endl;
}

int main(){
	Fingerprinter fp;
	
	// record a new fingerprint using the microphone
	Fingerprint* observed = fp.recordFingerprint();
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
		printFingerprint( fp.queryFingerprint( (*qr)[i].uid ) );
	}
	
	// assuming that we were not satisfied with any of the results, add this as a new room
	fp.insertFingerprint( observed, string( "newRoom" ) );
						 
	delete observed, qr;
}