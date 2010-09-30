//
//  simpleUIAppDelegate.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Fingerprinter.h"
#import "plotView.h"

@interface simpleUIAppDelegate : NSObject <UIApplicationDelegate> {
	// data members
    UIWindow *window;
	UILabel  *label;
	UIButton *button;
	plotView *plot;
	Fingerprinter fp;
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIButton *button;
@property (nonatomic, retain) plotView *plot;

// member functions
-(void) printFingerprint: (Fingerprint*) fingerprint;
-(void) test;
-(void) buttonHandler:(id)sender;

@end

