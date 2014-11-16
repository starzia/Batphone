//
//  UIViewController+Layout.m
//  simpleUI
//
//  Created by Stephen Tarzia on 11/15/14.
//  Copyright (c) 2014 Northwestern University. All rights reserved.
//

#import "UIViewController+Layout.h"

@implementation UIViewController (Layout)

static const CGFloat iOS7topPadding = 64;

// add extra padding to the top of the view on iOS >= 7
-(BOOL)iOS7orLater{
    return [[UIDevice currentDevice] systemVersion].floatValue >= 7;
}

-(CGFloat)topPadding{
    return [self iOS7orLater]? iOS7topPadding : 0;
}

-(CGFloat)viewHeight{
    return self.view.frame.size.height -
      ([self iOS7orLater]? iOS7topPadding : self.navigationController.navigationBar.frame.size.height);
}

-(CGFloat)keyboardHeight{
    // TODO: hard-coding this is bad!
    return 216;
}

@end
