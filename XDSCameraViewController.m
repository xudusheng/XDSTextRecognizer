//
//  XDSCameraViewController.m
//  XDSTextRecognizer
//
//  Created by zhengda on 7/14/15.
//  Copyright (c) 2015 zhengda. All rights reserved.
//

#import "XDSCameraViewController.h"

@interface XDSCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>{
    BOOL _canRecognize;
}
@property (strong, nonatomic)AVCaptureSession *session;
@property (strong, nonatomic)AVCaptureVideoPreviewLayer * previewLayer;
@property (strong, nonatomic)G8Tesseract * tesseract;
@property (strong, nonatomic)UIImage * scanImage;
@property (weak, nonatomic) IBOutlet UIView *scanView;
@property (weak, nonatomic) IBOutlet UILabel *scanResultLabel;


@end

@implementation XDSCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCaptureSession];
    [self setupTesseract];
}
- (void)setupTesseract{
    self.tesseract = [[G8Tesseract alloc]init];
    self.tesseract.language = @"eng";
    self.tesseract.engineMode = G8OCREngineModeTesseractCubeCombined;
    self.tesseract.pageSegmentationMode = G8PageSegmentationModeAuto;
    self.tesseract.maximumRecognitionTime = 60.0;
}
// Create and configure a capture session and start it running
- (void)setupCaptureSession {
    NSError *error = nil;
    // Create the session
    self.session = [[AVCaptureSession alloc] init];
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
//    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [self.session addInput:input];
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [self.session addOutput:output];
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    // Specify the pixel format
    output.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
//    output.minFrameDuration = CMTimeMake(1, 15);
    // Start the session running to start the flow of data
    [self.session startRunning];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]init];
    self.previewLayer.session = self.session;
    self.previewLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
}


// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // Create a UIImage from the sample buffer data
    if (!_canRecognize) {
        @autoreleasepool {
            // perform memory intensive task here;
            UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
            CGFloat ratio_x = image.size.width/self.view.frame.size.height;
            CGFloat ratio_y = image.size.height/self.view.frame.size.width;
            CGRect frame = self.scanView.frame;
            CGRect scanImageFrame = CGRectZero;
            frame.origin.x = self.view.frame.size.width/2-100;
            frame.origin.y = 150;
            scanImageFrame.origin.x = frame.origin.y * ratio_x;
            scanImageFrame.origin.y = frame.origin.x * ratio_y;
            scanImageFrame.size.width = frame.size.height * ratio_x;
            scanImageFrame.size.height = frame.size.width * ratio_x;
            UIImage * scanImage=[UIImage imageWithCGImage:CGImageCreateWithImageInRect([image CGImage], scanImageFrame) scale:1 orientation:UIImageOrientationRight];
            dispatch_sync(dispatch_get_main_queue(), ^{

            });
            _canRecognize = YES;
            [self performImageRecognition:[self scaleImage:scanImage maxDimension:640]];
        }


//        self.scanImage = [UIImage imageNamed:@"available.jpg"];
//        [self performImageRecognition:[self scaleImage:image maxDimension:640]];

    }
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // Release the Quartz image
    CGImageRelease(quartzImage);

    imageBuffer = nil;
    baseAddress = nil;
    context = nil;
    colorSpace = nil;
    quartzImage = nil;
    return image;
}


- (void)performImageRecognition:(UIImage *)image{
    self.tesseract.image = [image g8_blackAndWhite];
    if ([self.tesseract recognize]) {
        _canRecognize = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.scanResultLabel.text = self.tesseract.recognizedText;
        });
        sleep(1);
        NSLog(@"result = %@", self.tesseract.recognizedText);
//        [G8Tesseract clearCache];
    }
}


- (UIImage *)scaleImage:(UIImage *)image maxDimension:(CGFloat)maxDimension{
    CGSize scaledSize = CGSizeMake(maxDimension, maxDimension);
    CGFloat scaleFactor;
    if (image.size.width > image.size.height) {
        scaleFactor = image.size.height / image.size.width;
        scaledSize.width = maxDimension;
        scaledSize.height = scaledSize.width * scaleFactor;
    } else {
        scaleFactor = image.size.width / image.size.height;
        scaledSize.height = maxDimension;
        scaledSize.width = scaledSize.height * scaleFactor;
    }
    UIGraphicsBeginImageContext(scaledSize);
    [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
    UIImage * scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
