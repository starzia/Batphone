/*
 *  Heap.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/3/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Heap.h"

Heap::Heap(unsigned int size, float initialVals, bool isMaxHeap ) : 
size(size), isMaxHeap(isMaxHeap) {
	vals = new float[size];
	positionToKey = new unsigned int[size];
	keyToPosition = new unsigned int[size];
    // initialize the values and the forward and reverse mappings
    for( unsigned int i=0; i<size; i++ ){	
		vals[i] = initialVals;
	    positionToKey[i] = i;  
	    keyToPosition[i] = i;  
	}
}

Heap::~Heap(){
	delete[] vals;
	delete[] positionToKey;
	delete[] keyToPosition;
}

void Heap::replace( unsigned int index, float val ){
	unsigned int pos = keyToPosition[index];
	vals[pos] = val;
	correct( pos );
}

float Heap::rootVal(){
	return vals[0];
}

unsigned int Heap::rootKey(){
	return positionToKey[0];
}

void Heap::correct( unsigned int position ){
	siftUp( position );
	siftDown( position );
}

// binary heap index arithmetic
#define PARENT(x) (((int)x-1)/2)
#define LEFTCHILD(x) ((2*x)+1)
#define RIGHTCHILD(x) ((2*x)+2)

void Heap::siftUp( unsigned int position ){
	int parent_pos = PARENT(position);
	if( parent_pos < 0 ) return; // already at top
	bool doSwap = false;
	if( isMaxHeap ){
		// parent should be larger
		if( vals[parent_pos] < vals[position] ){
			doSwap = true;
		}
	}else{
		// parent should be smaller
		if( vals[parent_pos] > vals[position] ){
			doSwap = true;
		}
	}
	if( doSwap ){
		swap( position, parent_pos );
		siftUp(parent_pos);
	}
}

void Heap::siftDown( unsigned int position ){
	for( unsigned int child = LEFTCHILD(position); child<=RIGHTCHILD(position); child++ ){
		if( child >= size ) return;  // already at bottom;
		bool doSwap = false;
		if( isMaxHeap ){
			// child should be smaller
			if( vals[child] > vals[position] ){
				doSwap = true;
			}
		}else{
			// child should be larger
			if( vals[child] < vals[position] ){
				doSwap = true;
			}
		}
		if( doSwap ){
			swap( position, child );
			siftDown(child);
		}
	}
}

void Heap::swap( unsigned int pos1, unsigned int pos2 ){
    /* maintain the position <-> index mappings */
	
	// record current state
	unsigned int key1 = positionToKey[pos1];
	unsigned int key2 = positionToKey[pos2];
    float val1 = vals[pos1];
    float val2 = vals[pos2];
	
	// now swap
	vals[pos2] = val1;
	vals[pos1] = val2;
	positionToKey[pos1] = key2;
	positionToKey[pos2] = key1;
	keyToPosition[key1] = pos2;
	keyToPosition[key2] = pos1;
}