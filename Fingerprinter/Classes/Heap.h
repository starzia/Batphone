/*
 *  Heap.h
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/3/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 * An indexed min/max heap of floats.  Indexing allows the caller to replace
 * specific elements in the heap without knowledge of where the heap may have
 * shifted the element.  This is a fixed-size head.  Elements are initialized
 * to a given value, then individually updated.
 */

class Heap{
public:
	/**
	 * @param size - This is a constant size heap!
	 * @param initialVals - values to initialize in the heap
	 * @param isMaxHeap - it can be a max or min heap
	 */
	Heap(unsigned int size, 
		 float initialVals, 
		 bool isMaxHeap );
	/* replace an element listed at index with a new value.  Note that the new
	 * value will retain the same listing in the index. */
	void replace( unsigned int index, float val );
	/* return value of the min or max, respectively */
	float rootVal();
	/* return index key of the min or max, respectively */
	unsigned int rootKey();
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
	inline void swap( unsigned int pos1, unsigned int pos2 );
	
	/* members */
	float* vals;
	/* The following arrays maintain the mapping back and forth between indices and positions.
	 *   This allows elements to be removed from the heap
	 *   by specifying their position.  In other words this array maps an index
	 *   (the global identifier of a value) to a position in the heap. 
	 */
	unsigned int* keyToPosition;
	unsigned int* positionToKey;
	unsigned int size;
	bool isMaxHeap; // if false, then it is a minHeap

};