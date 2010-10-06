/*
 *  SlidingWindow.h
 *  simpleUI
 *
 *  Created by Stephen Tarzia on 10/4/10.
 *  Copyright 2010 Northwestern University. All rights reserved.
 *
 */
#import "Heap.h"

class SlidingWindow{
public:
	/**   
	 * @param size Initialize a sliding window of a given size.
	 * @param percentile is the percentile value to track.
	 * @param initVal is the initial value to the window with.
	 */
	SlidingWindow( unsigned int size, float percentile, float initVal );
	~SlidingWindow();
	/* return the current $percentile percentile value */
	float getVal();
	/* replaces the oldest value with a new one */
	void update( float newVal ); 
private:
	unsigned int size;
	/* percentile of interest */
	float percentile;

	/* maxHeap tracks the values below percentile of interest */ 
	Heap* maxHeap;
	/* minHeap tracks the values above percentile of interest */
	Heap* minHeap;
	
	unsigned int maxHeapSize;
	unsigned int minHeapSize;
	
	/* index and isInMaxHeap are both time-ordered queues.
	 * isInMaxHeap tells which heap to find element in
	 * index gives the keyname in the respective heap's keyspace for the element
	 */
	unsigned int* index; /* GlobalKeySpaceToHeap */
	bool* isInMaxHeap;
	
	/* the following two arrays map from the heap's keyspace to the global space
	 * used to index index and isInMaxHeap
	 */
	unsigned int* maxKeySpaceToGlobal;
	unsigned int* minKeySpaceToGlobal;

	/* points to the current oldest value */
	unsigned int indexTail;
	
};