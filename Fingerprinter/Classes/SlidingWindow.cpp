/*
 *  SlidingWindow.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/4/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "SlidingWindow.h"
#include <cmath>

SlidingWindow::SlidingWindow( unsigned int size, float percentile, float initVal ):
size(size), percentile(percentile){
	maxHeapSize = ceil( (percentile)*size );
    minHeapSize = floor( (1-percentile)*size );
    maxHeap = new Heap( this->maxHeapSize, initVal, true );
    minHeap = new Heap( this->minHeapSize, initVal, false );
	indexTail = 0;
	index = new unsigned int[size];
    isInMaxHeap = new bool[size];
	maxKeySpaceToGlobal = new unsigned int[maxHeapSize];
	minKeySpaceToGlobal = new unsigned int[minHeapSize];
    for(int i=0; i<maxHeapSize; i++ ){
		isInMaxHeap[i] = true;
		index[i] = i;
		maxKeySpaceToGlobal[i] = i;
    }
    for(int i=0; i<minHeapSize; i++ ){
		isInMaxHeap[maxHeapSize+i] = false;
		index[maxHeapSize+i] = i;
		minKeySpaceToGlobal[i] = maxHeapSize+i;
    }
}


SlidingWindow::~SlidingWindow(){
	delete[] index;
	delete[] isInMaxHeap;
	delete maxHeap;
	delete minHeap;
	delete[] maxKeySpaceToGlobal;
	delete[] minKeySpaceToGlobal;
}


float SlidingWindow::getVal(){
	return maxHeap->rootVal();
}


void SlidingWindow::update( float newVal ){
	// determine which heaps will be manipulated
	Heap* destination; // where the new value will be going
	unsigned int* dest_spaceMap;
	if( newVal > maxHeap->rootVal() ){
		destination = minHeap;
		dest_spaceMap = minKeySpaceToGlobal;
	}else{
		destination = maxHeap;
		dest_spaceMap = maxKeySpaceToGlobal;
	}
	Heap* source; // where old value will be removed from
	unsigned int* src_spaceMap;
	if( isInMaxHeap[indexTail] ){
		source = maxHeap;
		src_spaceMap = maxKeySpaceToGlobal;
	}else{
		source = minHeap;
		src_spaceMap = minKeySpaceToGlobal;
	}
	
	// in the simple case, we are removing from and adding to the same heap 
	if( source == destination ){
		source->replace( index[indexTail], newVal );
	}
	// otherwise we have to move the root of the destination to the source
	// so that they maintain the same size
	else{
		// retrieve the destination root
		unsigned int oldRootHeapKey = destination->rootKey();
		unsigned int oldRootKey = dest_spaceMap[ oldRootHeapKey ];
		float oldRootVal = destination->rootVal();
				
		// replace expired item in source with old root from destination
		index[oldRootKey] = index[indexTail]; // old root points to vacancy
		src_spaceMap[ index[oldRootKey] ] = oldRootKey;  //update reverse mapping
		isInMaxHeap[ oldRootKey ] = ( source == maxHeap ); // update heap flag
		source->replace( index[oldRootKey], oldRootVal ); //update heap
		
		// replace destination root with new val
		index[indexTail] = oldRootHeapKey; // new val now points to root's place
		dest_spaceMap[ oldRootHeapKey ] = indexTail; // update reverse mapping
		isInMaxHeap[ indexTail ] = ( destination == maxHeap ); // update heap flag
		destination->replace( oldRootHeapKey, newVal ); //update heap
	}

	// increment queue tail
	indexTail = (indexTail+1) % size;
}