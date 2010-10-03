//
//  plotView.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <vector>

@interface plotView : UIView {
    float* data; // the data to plot
	unsigned int length; // the length of data array
	// y axis range for plot:
	float minY;
	float maxY;
}

@property float* data;
@property unsigned int length;
@property float minY;
@property float maxY;

// set the y axis range of the plot
-(void)setYRange_min: (float)Ymin  max:(float)Ymax;
-(id)initWith_Frame:(CGRect)frame;
-(void)setVector: (float*)data length:(unsigned int)len;

@end
