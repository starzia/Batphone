/*
 *  Spectrogram.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/2/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Spectrogram.h"
#import <Accelerate/Accelerate.h> // for vector operations
#include <algorithm> // for nth_element
#include <vector>
using std::vector;

#define PERCENTILE (0.05)

Spectrogram::Spectrogram(unsigned int freq_bins, unsigned int time_bins): 
freqBins(freq_bins), timeBins(time_bins){
	// allocate data sliding windows	
	slidingWindows = new SlidingWindow*[freq_bins];
	for( int i=0; i<freq_bins; i++ ){
		slidingWindows[i] = new SlidingWindow( time_bins, PERCENTILE, 0.0f );
	}
}

Spectrogram::~Spectrogram(){
	for( int i=0; i<freqBins; i++ ){
		delete slidingWindows[i];
	}
	delete[] slidingWindows;
}

void Spectrogram::update(float* s){
	// copy into sliding windows
	for( int i=0; i<this->freqBins; i++ ){
		slidingWindows[i]->update( s[i] );
	}
}

void Spectrogram::getSummary(float* outBuf){
	// just retrieve the 5th percentile values from the sliding windows

    // iterate through frequency bins
	for( int i=0; i<this->freqBins; i++ ){
		outBuf[i] = slidingWindows[i]->getVal();
	}
	
}