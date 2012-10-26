//
//  ViewController.m
//  SwingAccelStats2
//
//  Created by phiat on 10/25/12.
//  Copyright (c) 2012 phiat. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>

#define kTimeDifferenceSinceLastOpenDelta  1.2
#define kUpdateInterval 0.3
#define kZDelta 0.08 

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *photoIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *bgImage;
@property (weak, nonatomic) IBOutlet UISlider *bgAlphaSlider;
@property (weak, nonatomic) IBOutlet UIButton *bgButton;
@property (weak, nonatomic) IBOutlet UILabel *photoCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *labelZ;
@property (weak, nonatomic) IBOutlet UILabel *labelY;
@property (weak, nonatomic) IBOutlet UILabel *labelX;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;

@property  BOOL isPaused;
@property  BOOL isFlashOn;
@property int photoCount;
@property  AVCaptureSession *session;
@property  AVCaptureStillImageOutput *output;
@property  (nonatomic,retain) NSDate *lastTimePhotoTaken;

 
- (IBAction)toggleFlashMode:(id)sender;
- (IBAction)photoButton:(id)sender;
- (IBAction)pauseButton:(id)sender;
- (IBAction)getPhoto;
- (IBAction)bgAlphaSliderChange:(id)sender;

@property (nonatomic, retain) UIAccelerometer *accelerometer;
- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.accelerometer = [UIAccelerometer sharedAccelerometer];
    self.accelerometer.updateInterval = kUpdateInterval;
    self.accelerometer.delegate = self;
    self.isPaused = false;
    self.isFlashOn = false;
    self.lastTimePhotoTaken = [NSDate date];
    [self.flashButton setTitle:@"OFF" forState:UIControlStateNormal];
    self.photoCount = 0;
    self.photoCountLabel.text = @"n: 0";
}

- (NSTimeInterval)timeDifferenceSinceLastOpen {
    if (!self.lastTimePhotoTaken)
        self.lastTimePhotoTaken= [NSDate date];
    NSDate *currentTime = [NSDate date];
    NSTimeInterval timeDifference =  [currentTime timeIntervalSinceDate:self.lastTimePhotoTaken];
    self.lastTimePhotoTaken = currentTime;
    //NSLog([NSString stringWithFormat:@"%f",timeDifference]);
    return timeDifference;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}
- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
    
    double accX = acceleration.x;
    double accY = acceleration.y;
    double accZ = acceleration.z;
    
    self.labelX.text = [[NSString alloc] initWithFormat:@"x: %1.2f", accX];
    self.labelY.text = [[NSString alloc] initWithFormat:@"y: %1.2f", accY ];
    self.labelZ.text = [[NSString alloc] initWithFormat:@"z: %1.2f", accZ ];

    if (accZ < kZDelta && accZ > -kZDelta ){
        [self getPhoto];
    }
}
- (IBAction)toggleFlashMode:(id)sender {
    if (self.isFlashOn){
        self.isFlashOn = false;
        [self.flashButton setTitle:@"OFF" forState:UIControlStateNormal];
        
    }
    else{
        self.isFlashOn = true;
        [self.flashButton setTitle:@"ON" forState:UIControlStateNormal];
    }
    
}

- (IBAction)photoButton:(id)sender {
    [self getPhoto];
}

- (IBAction)pauseButton:(id)sender {
//    NSLog(@"pausing...");
    if (self.isPaused){
        self.accelerometer.delegate = self;
        self.isPaused = false;
    }
    else{
        self.accelerometer.delegate = nil;
        self.isPaused = true;
    }
}
-(IBAction) getPhoto{

	/*  this is using the UIImagePicker interface...
     
   UIImagePickerController * picker = [[UIImagePickerController alloc] init];
	picker.delegate = self;
    
   picker.sourceType = UIImagePickerControllerSourceTypeCamera;

	[self presentViewController:picker animated:YES completion:nil]; */
    
    //
    if ([self timeDifferenceSinceLastOpen] > kTimeDifferenceSinceLastOpenDelta){
    
    AVCaptureDevice *backCamera;
    NSArray *allCameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    // Find the frontal camera.
    for ( int i = 0; i < allCameras.count; i++ ) {
        AVCaptureDevice *camera = [allCameras objectAtIndex:i];
        
        if ( camera.position == AVCaptureDevicePositionBack ) {
            backCamera = camera;
            NSError *error = nil;
            
            // turns on flash
            if ([backCamera lockForConfiguration:&error]){
                if (self.isFlashOn)
                    backCamera.flashMode = AVCaptureFlashModeOn;
                else
                    backCamera.flashMode = AVCaptureFlashModeOff;
                
                [backCamera unlockForConfiguration];
            }

        }
    }
    
    // If we did not find the camera then do not take picture.
    if ( backCamera != nil ) {
        // Start the process of getting a picture.
        self.session = [[AVCaptureSession alloc] init];
        
        // Setup instance of input with back camera and add to session.
        NSError *error;
        AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        
        if ( !error && [self.session canAddInput:input] ) {
            // Add back camera to this session.
            [self.session addInput:input];
            
            // We need to capture still image.
            self.output = [[AVCaptureStillImageOutput alloc] init];
            
            // Captured image. settings.
            [self.output setOutputSettings:
             [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil]];
            
            if ( [self.session canAddOutput:self.output] ) {
                [self.session addOutput:self.output];
                
                AVCaptureConnection *videoConnection = nil;
                for (AVCaptureConnection *connection in self.output.connections) {
                    for (AVCaptureInputPort *port in [connection inputPorts]) {
                        if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                            videoConnection = connection;
                            break;
                        }
                    }
                    if (videoConnection) { break; }
                }
                
                // Finally take the picture
                if ( videoConnection ) {
                    [self.session startRunning];
                    
                    [self.output   captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                        
                        if (imageDataSampleBuffer != NULL) {
                            NSData *imageData = [AVCaptureStillImageOutput
                                                 jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                            UIImage *photo = [[UIImage alloc] initWithData:imageData];
                            UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil);
                            NSLog(@"took photo");
                            [UIView animateWithDuration:0.4 animations:^ {
                                self.photoIndicator.alpha = 1.0;
                            } completion:^(BOOL finished) {
                                self.photoIndicator.alpha = 0.0;
                            
                            }
                             ];
                             
                            self.photoCount += 1;
                            self.photoCountLabel.text = [NSString stringWithFormat:@"n: %i",self.photoCount];
                        }
                        
                    }];
                }
            }
        }
    }
}
}
- (IBAction)bgAlphaSliderChange:(id)sender {
    self.bgImage.alpha = self.bgAlphaSlider.value;
}
@end
