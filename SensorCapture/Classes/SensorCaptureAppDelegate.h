//
//  SensorCaptureAppDelegate.h
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SensorCaptureViewController;

@interface SensorCaptureAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    SensorCaptureViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet SensorCaptureViewController *viewController;

@end

