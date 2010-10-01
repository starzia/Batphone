//
//  plotView.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "plotView.h"
#include <algorithm> //for min_element, max_element

@implementation plotView

@synthesize fp;
@synthesize minY, maxY;

- (id)initWith_Frame:(CGRect)frame Fingerprinter:(Fingerprinter*)fpPtr {
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
		self.backgroundColor = [UIColor whiteColor];
		self.opaque = YES;
		self.clearsContextBeforeDrawing = YES;

		// TODO: automatically set range
		[self setYRange_min:-1 max:1];
		self.fp = fpPtr;
		
		[self setNeedsDisplay]; // make it redraw
	}
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
	// do nothing is fingerprinter is not ready
	if( !self.fp ) return;
    
	// Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();
		
	// update view range
	float min_val = *std::min_element(self.fp->fingerprint.begin(), self.fp->fingerprint.end() ); 
	float max_val = *std::max_element(self.fp->fingerprint.begin(), self.fp->fingerprint.end() ); 
	[self setYRange_min:min_val max:max_val];
	
	// Get boundary information for this view, so that drawing can be scaled
	float X = self.bounds.size.width;
	float Y = self.bounds.size.height;

	// Drawing lines with a red stroke color
	CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);

	Fingerprint data = self.fp->fingerprint;
	float plot_range = self.maxY - self.minY;
	float xStep = X/(data.size()-1);
	float yStep = Y/plot_range;
	
	if( data.size() > 0 ){
		// start off the line at the left side
		CGContextMoveToPoint(context, 0, Y - (data[0]-self.minY) * yStep);
		for( int i=1; i<data.size(); ++i ){ // starting w/2nd data point
			CGContextAddLineToPoint(context, i * xStep, Y - (data[i]-self.minY) * yStep);	
			//printf("line %f %f %f\n", data[i], i * xStep, Y - (data[i]-self.minY) * yStep);
		}
		CGContextSetLineWidth(context, 2.0);
		CGContextStrokePath(context);
	}
	[self setNeedsDisplay]; // make it redraw
}

-(void) setYRange_min:(float)newMinY  max:(float)newMaxY {
	self.minY = newMinY;
	self.maxY = newMaxY;
	[self setNeedsDisplay]; // make it redraw
}

- (void)dealloc {
    [super dealloc];
}


@end
