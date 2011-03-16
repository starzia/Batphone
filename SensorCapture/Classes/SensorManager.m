//
//  SensorManager.m
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SensorManager.h"


@implementation SensorManager
@synthesize storagePath;
@synthesize session;
@synthesize videoInput;
@synthesize stillImageOutput;
@synthesize stillTimer;
@synthesize audioTimer;
@synthesize recorder;


-(void)stopAudio{
	if( self.recorder != nil ){
		[self.recorder stop];
		//[self.recorder release];
	}
	
}


-(void)restartAudio{
	// build filename
	NSDate *now = [NSDate date];
	NSString *wavFile = [NSString stringWithFormat:@"%@/%.2f.wav",
						 self.storagePath,[now timeIntervalSince1970]];
	NSURL *wavFileURL = [NSURL fileURLWithPath:wavFile];
	
	NSDictionary *recordSettings = [NSDictionary 
									dictionaryWithObjectsAndKeys:
									[NSNumber numberWithInt:kAudioFormatLinearPCM], 
									AVFormatIDKey,
									[NSNumber numberWithInt: 16], 
									AVLinearPCMBitDepthKey,
									[NSNumber numberWithInt: 1], 
									AVNumberOfChannelsKey,
									[NSNumber numberWithFloat:44100.0], 
									AVSampleRateKey,
									nil];

	AVAudioRecorder* audioRecorder = [[AVAudioRecorder alloc] initWithURL:wavFileURL
																 settings:recordSettings
																	error:nil];
	[audioRecorder prepareToRecord];
	
	// stop previous recorder, if any
	[self stopAudio];
	
	// start new recorder
	[audioRecorder record];
	NSLog(@"started recording to: %@", wavFile);
	self.recorder = audioRecorder;
	[audioRecorder release];
}


-(id)initWithStoragePath:(NSString*)path{
	self = [super init];
	if( self != nil ){
		self.storagePath = path;
		self.recorder = nil;
		
		// SET UP VIDEO DEVICE.  See code in AVCamDemo for dealing w/ device conection and disconnection
		// find the correct video device
		AVCaptureDevice* camera;
		NSArray *devices = [AVCaptureDevice devices];
		for (AVCaptureDevice *device in devices) {
			if ([device hasMediaType:AVMediaTypeVideo]) {
				if ([device position] == AVCaptureDevicePositionBack) {
					camera = device;
				}
			}
		}
		NSLog(@"using camera: %@", [camera localizedName] );
		
		// Init the device inputs
		AVCaptureDeviceInput *tVideoInput = [[[AVCaptureDeviceInput alloc] 
											 initWithDevice:camera
													  error:nil] autorelease];
		[self setVideoInput:tVideoInput]; // stash this for later use if we need to switch cameras
				
		// Setup the default file outputs
		AVCaptureStillImageOutput *tStillImageOutput = [[[AVCaptureStillImageOutput alloc] init] autorelease];
		NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
										AVVideoCodecJPEG, AVVideoCodecKey,
										nil];
		[tStillImageOutput setOutputSettings:outputSettings];
		[outputSettings release];
		[self setStillImageOutput:tStillImageOutput];
				
		// Setup and start the capture session
		AVCaptureSession *tSession = [[AVCaptureSession alloc] init];
		[tSession beginConfiguration];
    	
		if ([tSession canAddInput:videoInput]) {
			[tSession addInput:videoInput];
		}
		if ([tSession canAddOutput:stillImageOutput]) {
			[tSession addOutput:stillImageOutput];
		}
		
		[tSession setSessionPreset:AVCaptureSessionPreset640x480];
		[tSession commitConfiguration];
		
		[tSession startRunning];
		
		[self setSession:tSession];
		[tSession release];

		// SET TIMER FOR STILLS
		self.stillTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
														   target:self
														 selector:@selector(captureStillImage)
														 userInfo:nil
														  repeats:YES];
		
		// SET TIMER FOR AUDIO
		[self restartAudio]; // get started immediately
		self.audioTimer = [NSTimer scheduledTimerWithTimeInterval:60
														   target:self
														 selector:@selector(restartAudio)
														 userInfo:nil
														  repeats:YES];
	}
	return self;	
}

+(AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType 
								 fromConnections:(NSArray *)connections;{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return [[connection retain] autorelease];
			}
		}
	}
	return nil;
}

- (void) captureStillImage{
    AVCaptureConnection *videoConnection = [SensorManager 
											connectionWithMediaType:AVMediaTypeVideo 
													fromConnections:[[self stillImageOutput] connections]];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                             if (imageDataSampleBuffer != NULL) {
                                                                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
																 
																 // build filename
																 NSDate *now = [NSDate date];
																 NSString *jpgFile = [NSString stringWithFormat:@"%@/%.2f.jpg",
																					  self.storagePath,[now timeIntervalSince1970]];
																 NSLog(@"wrote to file: %@",jpgFile);
																 [imageData writeToFile:jpgFile atomically:YES];
																 
                                                             } else if (error) {
                                                                 NSLog(@"still image capture error");
                                                             }
                                                         }];
}

-(void)dealloc{
	[self stopAudio];
	[super dealloc];
}

@end
