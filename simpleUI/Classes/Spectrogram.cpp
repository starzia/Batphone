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

Spectrogram::Spectrogram(unsigned int freq_bins, unsigned int time_bins): 
  freqBins(freq_bins), timeBins(time_bins){
	// allocate data array	
    this->data = new float[freq_bins*time_bins];
	// set to zeros
    vDSP_vclr( this->data, 1, this->freqBins * this->timeBins );
	// set tail pointer
	this->tailIndex = 0;
}

Spectrogram::~Spectrogram(){
	delete this->data;
}

void Spectrogram::update(float* s){
	// TODO: use vector op like:
	//vDSP_zvmov( this->data[this->tailIndex], this->freqBins, s, 1, this->timeBins );

	// copy over data array
	for( int i=0; i<this->freqBins; i++ ){
		this->data[this->tailIndex + i * this->timeBins] = s[i];
	}
	// update tail pointer
	this->tailIndex = (this->tailIndex+1)%this->timeBins;
}

void Spectrogram::getSummary(float* outBuf){
	// find index of 5th percentile value in sorted list of time bins
	int p5_idx = floor( 0.05 * this->timeBins );
	
    // iterate through frequency bins
	for( int i=0; i<this->freqBins; i++ ){
		// make a copy of the data to select from (b/c it does an in-place quickselect)
		vector<float> selectVec( data+(i*timeBins), data+((i+1)*timeBins) ); 
	    std::nth_element( selectVec.begin(), selectVec.begin()+p5_idx, selectVec.end() );
		outBuf[i] = selectVec[ p5_idx ];
	}
	
}