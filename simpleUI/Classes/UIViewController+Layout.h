//
//  UIViewController+Layout.h
//  simpleUI
//
//  Created by Stephen Tarzia on 11/15/14.
//  Copyright (c) 2014 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>

/* functions to help when laying out view in viewcontroller that's inside a UINavigationController */
@interface UIViewController (Layout)

-(BOOL)iOS7orLater;

-(CGFloat)topPadding;

-(CGFloat)viewHeight;

-(CGFloat)keyboardHeight;

@end
