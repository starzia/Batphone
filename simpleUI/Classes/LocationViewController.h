//
//  LocationViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface LocationViewController : UIViewController {
	AppDelegate *app;
	NSString* room;
	NSString* building;
}
@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) NSString* room;
@property (nonatomic, retain) NSString* building;

@end
