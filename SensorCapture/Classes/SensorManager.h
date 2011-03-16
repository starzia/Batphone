//
//  SensorManager.h
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@interface SensorManager : NSObject {
	NSString* storagePath;
	
	AVCaptureSession *session;
    AVCaptureDeviceInput *videoInput;
    AVCaptureStillImageOutput *stillImageOutput;
	NSTimer* stillTimer;
	NSTimer* audioTimer;
	AVAudioRecorder* recorder;
}

@property (nonatomic,retain) NSString* storagePath;

@property (nonatomic,retain) AVCaptureSession *session;
@property (nonatomic,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,retain) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,retain) NSTimer* stillTimer;
@property (nonatomic,retain) NSTimer* audioTimer;
@property (nonatomic,retain) AVAudioRecorder* recorder;

-(id)initWithStoragePath:(NSString*)path;

@end
