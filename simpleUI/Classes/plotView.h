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
    std::vector<float> data; // the data to plot
	// y axis range for plot:
	float minY;
	float maxY;
}

@property std::vector<float> data;
@property float minY;
@property float maxY;

// set the y axis range of the plot
-(void)setYRange_min: (float)Ymin  max:(float)Ymax;

@end
