/*
 *  Heap.h
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/3/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */

class Heap{
public:
	/**
	 * @param size - This is a constant size heap!
	 * @param initialVals - values to initialize in the heap
	 * @param isMaxHeap - it can be a max or min heap
	 * @param indexToPosition - In this array we will keep track of the position of each
	 *    element in the heap.  This allows elements to be removed from the heap
	 *    by specifying their position.  In other words this array maps an index
	 *    (the global identifier of a value) to a position in the heap. 
	 */
	Heap(unsigned int size, 
		 float* initialVals, 
		 bool isMaxHeap,    
		 unsigned int* indexToPosition );
	/* replace an element listed at index with a new value.  Note that the new
	 * value will retain the same listing in the index. */
	void replace( unsigned int index, float val );	
	~Heap();
private:
	/* Call correct after moving a new value into a certain index.
	 * Correct() sifts the value up or down as needed to maintain the heap property */
	void correct( unsigned int position );
	/* sift value at position up tree, if needed to maintain heap property */
	void siftUp( unsigned int position );
	/* sift value at position down tree, if needed to maintain heap property */
	void siftDown( unsigned int position );
	/* swap contents of two positions */
	void swap( unsigned int pos1, unsigned int pos2 );
	
	/* members */
	float* vals;
	/* the following maintain the mapping back and forth between indices and positions */
	unsigned int* indexToPosition;
	unsigned int* positionToIndex;
	unsigned int size;
	bool isMaxHeap; // if false, then it is a minHeap

};