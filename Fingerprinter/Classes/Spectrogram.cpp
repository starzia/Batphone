/*
 *  Spectrogram.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/2/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Spectrogram.h"
#include <algorithm> // for nth_element
#include <vector>
#include <time.h>
using std::vector;

#define PERCENTILE (0.05)
#define THREAD_SAFE false

Spectrogram::Spectrogram(unsigned int freq_bins, unsigned int time_bins): 
freqBins(freq_bins), timeBins(time_bins){
	this->enableLogging = false;

	// allocate data sliding windows	
	slidingWindows = new SlidingWindow*[freq_bins];
	for( unsigned int i=0; i<freq_bins; i++ ){
		slidingWindows[i] = new SlidingWindow( time_bins, PERCENTILE, 0.0f );
	}
}

Spectrogram::~Spectrogram(){
	for( unsigned int i=0; i<freqBins; i++ ){
		delete slidingWindows[i];
	}
	delete[] slidingWindows;
	disableLogging(); // to close log file
}

void Spectrogram::update(float* s){
	if(THREAD_SAFE) pthread_mutex_lock( &lock );
	// copy into sliding windows
	for( unsigned int i=0; i<this->freqBins; i++ ){
		slidingWindows[i]->update( s[i] );
	}
	
	// log value, if required
	if( enableLogging ){
		time_t currentTime;
		time( &currentTime );
		logFile << currentTime << '\t';
		for( unsigned int i=0; i<this->freqBins; i++ ){
			logFile << s[i] << '\t';
		}
		logFile << '\n';
	}
	
	if(THREAD_SAFE) pthread_mutex_unlock( &lock );
}

void Spectrogram::getSummary(float* outBuf){
	// just retrieve the 5th percentile values from the sliding windows
	if(THREAD_SAFE) pthread_mutex_lock( &lock );
    // iterate through frequency bins
	for( unsigned int i=0; i<this->freqBins; i++ ){
		outBuf[i] = slidingWindows[i]->getVal();
	}
	if(THREAD_SAFE) pthread_mutex_unlock( &lock );
}

void Spectrogram::enableLoggingToFilename( const char* logFilename ){
	if( !enableLogging ){
		logFile.open( logFilename );
		if( !logFile.fail() ){
			enableLogging = true;
		}
	}
}

void Spectrogram::disableLogging(){
	if( enableLogging ){
		logFile.close();
		enableLogging = false;
	}
}