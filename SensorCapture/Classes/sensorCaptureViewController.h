//
//  SensorCaptureViewController.h
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SensorManager.hpp"

@interface SensorCaptureViewController : UIViewController {
	SensorManager* sensorManager;
}

@property (nonatomic,retain) SensorManager* sensorManager;

@end

