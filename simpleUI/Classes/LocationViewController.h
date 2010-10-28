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
}
@property (nonatomic, retain) AppDelegate* app;

@end
