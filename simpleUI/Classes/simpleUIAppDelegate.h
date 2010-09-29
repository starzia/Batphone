//
//  simpleUIAppDelegate.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Fingerprinter.h"

@interface simpleUIAppDelegate : NSObject <UIApplicationDelegate> {
	// data members
    UIWindow *window;
	UILabel  *label;
	UIButton *button;
	Fingerprinter fp;
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIButton *button;

// member functions
-(void) printFingerprint: (Fingerprint*) fingerprint;
-(void) test;
-(void) buttonHandler:(id)sender;

@end

