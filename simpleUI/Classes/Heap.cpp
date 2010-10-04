/*
 *  Heap.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/3/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Heap.h"

Heap::Heap(unsigned int size, float* initialVals, 
	       bool isMaxHeap, unsigned int* indexToPosition ) : 
  size(size), vals(initialVals), isMaxHeap(isMaxHeap), 
  indexToPosition(indexToPosition) {
	this->positionToIndex = new unsigned int[size];
	// record the reverse mapping
    for( int i=0; i<size; i++ ){		  
	    this->positionToIndex[ indexToPosition[i] ] = i;  
	}
}

Heap::~Heap(){
	delete this->positionToIndex;
}

void Heap::replace( unsigned int index, float val ){
	unsigned int pos = indexToPosition[index];
	vals[pos] = val;
	correct( pos );
}

void Heap::correct( unsigned int position ){
	siftUp( position );
	siftDown( position );
}

// binary heap index arithmetic
#define PARENT(x) = ((x-1)/2)
#define LEFTCHILD(x) = ((2*x)+1)
#define RIGHTCHILD(x) = ((2*x)+2)

void Heap::siftUp( unsigned int position ){
	unsigned int parent_pos = PARENT(position);
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
	for( unsigned int child = (2*position)+1; child<=(2*position+2); child++ ){
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
	unsigned int idx1 = positionToIndex[pos1];
	unsigned int idx2 = positionToIndex[pos2];
    float val1 = vals[pos1];
    float val2 = vals[pos2];
	
	// now swap
	vals[pos2] = val1;
	vals[pos1] = val2;
	positionToIndex[pos1] = idx2;
	positionToIndex[pos2] = idx1;
	indexToPosition[idx1] = pos2;
	indexToPosition[idx2] = pos1;
}