/*
 *  Heap.cpp
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/3/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

#include "Heap.h"

//#define DEBUG_HEAP
#ifdef DEBUG_HEAP
#include <iostream>
unsigned int debug_heap_update_count = 0;
#endif

Heap::Heap(unsigned int mySize, float initialVals, bool myIsMaxHeap ) : 
size(mySize), isMaxHeap(myIsMaxHeap) {
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
#ifdef DEBUG_HEAP
	// after 100003 updates (a prime number), check for heap property
	if( debug_heap_update_count++ % 100003 == 0){
		if( !debugHeap() ){
			std::cerr << "ERROR in heap!\n";
		}else{
			std::cerr << "heap OK\n";
		}
	}
#endif
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
	int parent_pos;
	
	if( isMaxHeap ){
		// sift up until heap property is satisfied
		while( position > 0 /* if at root, can't siftUp any further */
			   /* should continue sifting up if heap property is not satisfied */
			   && vals[(parent_pos=PARENT(position))] < vals[position] ){
			swap( position, parent_pos );
			position = parent_pos;
		}
	}else{
		while( position > 0 /* if at root, can't siftUp any further */
			   /* should continue sifting up if heap property is not satisfied */
			   && vals[(parent_pos=PARENT(position))] > vals[position] ){
			swap( position, parent_pos );
			position = parent_pos;
		}
	}
}

void Heap::siftDown( unsigned int position ){
	int left_child_pos, right_child_pos;
	
	if( isMaxHeap ){
		// sift down until heap property is satisfied
		while( (left_child_pos=LEFTCHILD(position)) < size ){ // if no left-child, then there is nowhere to move down
			right_child_pos=RIGHTCHILD(position); 
			if( vals[left_child_pos] > vals[position] 
			    || (right_child_pos < size && vals[right_child_pos] > vals[position]) ){ // violated heap property
				if( right_child_pos >= size // if no right child
				    || vals[left_child_pos] > vals[right_child_pos] ){ // or left child is larger
					// swap with left child
					swap( position, left_child_pos );
					position = left_child_pos;
				}else{ 
					// swap with right child
					swap( position, right_child_pos );
					position = right_child_pos;
				}
			}else{
				// if heap property is not violated here, then assume it exists elsewhere
				break;
			}
		}
	}else{
		// sift down until heap property is satisfied
		while( (left_child_pos=LEFTCHILD(position)) < size ){ // if no left-child, then there is nowhere to move down
			right_child_pos=RIGHTCHILD(position); 
			if( vals[left_child_pos] < vals[position] 
			   || (right_child_pos < size && vals[right_child_pos] < vals[position]) ){ // violated heap property
				if( right_child_pos >= size // if no right child
				   || vals[left_child_pos] < vals[right_child_pos] ){ // or left child is larger
					// swap with left child
					swap( position, left_child_pos );
					position = left_child_pos;
				}else{ 
					// swap with right child
					swap( position, right_child_pos );
					position = right_child_pos;
				}
			}else{
				// if heap property is not violated here, then assume it exists elsewhere
				break;
			}
		}
	}
}

inline void Heap::swap( unsigned int pos1, unsigned int pos2 ){
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

#ifdef DEBUG_HEAP
bool Heap::debugHeap(){
	// pop all elements from Heap and made sure that they come out in order
	float buffer[size];
	for( int i=0; i<size; i++ ){
		buffer[i] = rootVal();
		std::cerr << buffer[i] <<'\t';
		if( i>0 ){
			if( ( isMaxHeap && buffer[i] > buffer[i-1] ) 
				|| (!isMaxHeap && buffer[i] < buffer[i-1] ) ){
				return false;
			}
		}
		if( isMaxHeap ){
			vals[0] = -1e20;
		}else{
			vals[0] = 1e20;
		}
		correct(0);
	}
	std::cerr << '\n';
	return true;
}
#endif