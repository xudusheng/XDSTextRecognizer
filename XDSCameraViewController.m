//
//  XDSCameraViewController.m
//  XDSTextRecognizer
//
//  Created by zhengda on 7/14/15.
//  Copyright (c) 2015 zhengda. All rights reserved.
//

#import "XDSCameraViewController.h"

@interface XDSCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic)AVCaptureSession *session;
@property (strong, nonatomic)AVCaptureVideoPreviewLayer * previewLayer;
@property (strong, nonatomic)UIImage * scanImage;
@property (weak, nonatomic) IBOutlet UIView *scanView;
@property (weak, nonatomic) IBOutlet UIImageView *scanImageView;
@property (weak, nonatomic) IBOutlet UIImageView *scanResultImageView;

@end

@implementation XDSCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self performSelector:@selector(setupCaptureSession) withObject:nil afterDelay:2];
//    [self setupCaptureSession];
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
    if (!self.scanImage) {
//        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
//        self.scanImage = image;
        self.scanImage = [UIImage imageNamed:@"available.jpg"];
        [self performImageRecognition:self.scanImage];

//        dispatch_sync(dispatch_get_main_queue(), ^{
//            UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
//            image = [UIImage imageWithCGImage:image.CGImage scale:.1 orientation:UIImageOrientationRight];
//            NSLog(@"image = %@", NSStringFromCGSize(image.size));
//            self.scanImage = [UIImage imageWithCGImage:CGImageCreateWithImageInRect(image.CGImage, self.scanView.frame)];
//            self.scanResultImageView.image = self.scanImage;
//            NSLog(@"smallImage = %@ = %@", NSStringFromCGSize(self.scanImage.size), self.scanImage);
//            self.scanImageView.image = image;
//            [self performImageRecognition:self.scanImage];
//        });
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
    return (image);
}


- (void)performImageRecognition:(UIImage *)image{
    G8Tesseract * tesseract = [[G8Tesseract alloc]init];
    tesseract.language = @"eng";
    tesseract.engineMode = G8OCREngineModeTesseractCubeCombined;
    tesseract.pageSegmentationMode = G8PageSegmentationModeAuto;
    tesseract.maximumRecognitionTime = 60.0;
    tesseract.image = [image g8_blackAndWhite];
    if ([tesseract recognize]) {
        self.scanImage = nil;
        
        NSLog(@"result = %@", tesseract.recognizedText);
    }else{
        self.scanImage = nil;
        NSLog(@"recognize failed!");
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
