//
//  plotView.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <vector>

@interface PlotView : UIView {
    float* data; // the data to plot
	unsigned int length; // the length of data array
	// y axis range for plot:
	CGFloat minY;
	CGFloat maxY;
	CGFloat* lineColor; // RGB array
}

@property (nonatomic) float* data;
@property (nonatomic) unsigned int length;
@property (nonatomic) CGFloat minY;
@property (nonatomic) CGFloat maxY;
@property (nonatomic) CGFloat* lineColor;

// set the y axis range of the plot
-(void)setYRange_min: (CGFloat)Ymin  max:(CGFloat)Ymax;
// automatically set the range based on the values in the vector
-(void)autoRange;
-(id)initWith_Frame:(CGRect)frame;
-(void)setVector: (float*)data length:(unsigned int)len;

@end
