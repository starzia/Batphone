//
//  plotView.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//Vec

#import "plotView.h"
#include <algorithm> //for min_element, max_element
#import "CoreGraphics/CGContext.h"

@implementation PlotView

@synthesize data, length;
@synthesize minY, maxY;
@synthesize lineColor;

- (id)initWith_Frame:(CGRect)frame{
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
		//self.backgroundColor = [UIColor whiteColor];
		//self.opaque = YES;
		self.opaque = NO;
		self.clearsContextBeforeDrawing = YES;

		// TODO: automatically set range
		[self setYRange_min:-1 max:1];
		self.data = NULL;
		
		[self setNeedsDisplay]; // make it redraw
	}
	self.lineColor = new CGFloat[4];
	self.lineColor[0] = 0.0; //R
	self.lineColor[1] = 0.0; //G
	self.lineColor[2] = 0.0; //B
	self.lineColor[3] = 1.0; //alpha
	
	// enable clicks
	self.userInteractionEnabled = YES;
	
    return self;
}

// to handle clicks
-(BOOL) canBecomeFirstResponder{ return YES; }
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
	[self autoRange];
}

-(void) setVector: (float*)dataPtr length:(unsigned int)len{
	self.length = len;
	self.data = dataPtr;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
	// do nothing is fingerprinter is not ready
	if( !self.data || self.length == 0 ) return;
    
	// Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();

	// zoom out, if necessary
	float min_val = *std::min_element(self.data, self.data+self.length ); 
	float max_val = *std::max_element(self.data, self.data+self.length );
	if( min_val < self.minY ){
		[self setYRange_min:min_val max:self.maxY];
	}
	if( max_val > self.maxY ){
		[self setYRange_min:self.minY max:max_val];
	}
	
	// Get boundary information for this view, so that drawing can be scaled
	CGFloat X = self.bounds.size.width;
	CGFloat Y = self.bounds.size.height;

	// Drawing lines with the appropriate color
	CGContextSetStrokeColor(context, (CGFloat*)self.lineColor);

	CGFloat plot_range = self.maxY - self.minY;
	CGFloat xStep = X/(self.length-1);
	CGFloat yStep = Y/plot_range;
	
	if( self.length > 0 && isfinite(data[0]) ){ // data will be -Inf if audio permission is not yet granted
		// start off the line at the left side
		CGContextMoveToPoint(context, 0, Y - (self.data[0]-self.minY) * yStep);
		for( int i=1; i<self.length; ++i ){ // starting w/2nd data point
			CGContextAddLineToPoint(context, i * xStep, Y - (self.data[i]-self.minY) * yStep);	
			CGContextMoveToPoint(context, i * xStep, Y - (self.data[i]-self.minY) * yStep);	
			//printf("line %f %f %f\n", data[i], i * xStep, Y - (self.data[i]-self.minY) * yStep);
		}
		CGContextSetLineWidth(context, 0.5);
		CGContextStrokePath(context);
	}
	[self setNeedsDisplay]; // make it redraw
}

-(void) setYRange_min:(CGFloat)newMinY  max:(CGFloat)newMaxY {
	self.minY = newMinY;
	self.maxY = newMaxY;
	[self setNeedsDisplay]; // make it redraw
}

-(void) autoRange{
	// update view range
	float min_val = *std::min_element(self.data, self.data+self.length ); 
	float max_val = *std::max_element(self.data, self.data+self.length );
	[self setYRange_min:min_val max:max_val];	
}

- (void)dealloc {
    [super dealloc];
}


@end
