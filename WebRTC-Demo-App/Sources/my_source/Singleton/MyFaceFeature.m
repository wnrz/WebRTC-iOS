//
//  MyFaceFeature.m
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/2.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#import "MyFaceFeature.h"
#import <UIKit/UIKit.h>
#import <GPUImage/GPUImage.h>
#import "GPUImageBeautifyFilter.h"
#import "OpenGlHelper.h"

@import CoreImage;

typedef NS_ENUM(NSInteger , PHOTOS_EXIF_ENUM) {
    PHOTOS_EXIF_0ROW_TOP_0COL_LEFT          = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT         = 2, //   2  =  0th row is at the top, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
    PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
    PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
};

@implementation MyFaceFeature{
    AVCaptureDeviceInput *deviceinput;
    NSMutableDictionary * filters;
    GPUImageMovie *gpumovie;
    GPUImageBeautifyFilter *beautyFilter;
    GPUImageFilterGroup *filterGroup;
    CIDetector *faceDetector;
    size_t width;
    size_t height;
    
}
@synthesize metadataOutput;
//@synthesize captureSession;
@synthesize faceBounds;
@synthesize ciContext;
@synthesize coreImageFilter;

+ (MyFaceFeature *)share{
    //使用单一线程，解决网络同步请求的问题
    static MyFaceFeature* shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[MyFaceFeature alloc] init];
        [shareInstance initData];
    });
    return shareInstance;
}

-(void)initData{
    [self initGPUImage];
    [self initCIImage];
    [self initDevice];
    [self initFaceDetector];
}

- (void)initGPUImage{
    filters = [NSMutableDictionary dictionary];
    gpumovie = [[GPUImageMovie alloc] initWithAsset:nil]; // 初始化內部資料結構
    beautyFilter = [[GPUImageBeautifyFilter alloc]init];
    [gpumovie addTarget:beautyFilter];
}

- (void)initCIImage{
    self.ciContext = [CIContext contextWithOptions:nil];
    self.faceBounds = [NSMutableArray new];
    //    self.captureSession = [AVCaptureSession new];
    self.coreImageFilter = [CIFilter filterWithName:@"CIGaussianBlur"]; // CIMaskedVariableBlur CIColorMonochrome CIGaussianBlur
}

- (void)initDevice{
    self.currentCameraPosition = AVCaptureDevicePositionFront;
    NSError *error;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    deviceinput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (!deviceinput) {
        NSLog(@"%@", [error localizedDescription]);
    }
    [self.captureSession addInput:deviceinput];
    //    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    sessionQueue = dispatch_queue_create("com.example.camera.capture_session", DISPATCH_QUEUE_SERIAL);
    self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    //    [metadataOutput setRectOfInterest:CGRectMake(0.13,0.15,0.5,0.7)];//设定扫描区域
    [metadataOutput setMetadataObjectsDelegate:self queue:sessionQueue];
}

- (void)setCurrentCameraPosition:(AVCaptureDevicePosition)currentCameraPosition{
    _currentCameraPosition = currentCameraPosition;
}

- (void)initFaceDetector {
    // Detector 的配置初始化：
    NSDictionary *detectorOptions = @{CIDetectorAccuracy:CIDetectorAccuracyLow,
                                      CIDetectorTracking:@(YES)};
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (void)setCaptureSession:(AVCaptureSession *)captureSession{
    _captureSession = captureSession;
    if ([self.captureSession canAddOutput:metadataOutput]){
        if (deviceinput) {
            [self.captureSession addInput:deviceinput];
        }
        [self.captureSession addOutput:metadataOutput];
        NSArray *types = @[AVMetadataObjectTypeFace];
        [metadataOutput setMetadataObjectTypes:types];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    NSMutableArray *tmpArray = [[NSMutableArray alloc] init];
    for (AVMetadataObject *metadataObject in metadataObjects) {
        if (metadataObject.type == AVMetadataObjectTypeFace){
            //            NSLog(@"didOutputMetadataObjects");
            AVMetadataFaceObject *faceObject = (AVMetadataFaceObject *)metadataObject;
            NSValue *value = [NSValue valueWithCGRect:[faceObject bounds]];
            [tmpArray addObject:value];
        }
    }
    faceBounds = tmpArray;
}

- (CVPixelBufferRef)renderByCIImage:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferRetain(pixelBuffer);
    
    CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                             CVPixelBufferGetHeight(pixelBuffer));
    // (1)
    CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
    // (2)
    CIImage *filterImage = [CIImage imageWithColor:[CIColor colorWithRed:0
                                                                   green:0
                                                                    blue:1
                                                                   alpha:1]];
    // (3)
    image = [filterImage imageByCompositingOverImage:image];
    
    // (4)
    CVPixelBufferRef output = [self createPixelBufferWithSize:size buffer:pixelBuffer];
    //    [[MyFaceFeature share].ciContext render:image toCVPixelBuffer:output];
    
    CVPixelBufferRelease(pixelBuffer);
    return output;
}

-(CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size buffer:(CVPixelBufferRef)pixelBuffer{
    const void *keys[] = {
        kCVPixelBufferOpenGLESCompatibilityKey,
        kCVPixelBufferIOSurfacePropertiesKey,
    };
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSDictionary dictionary])
    };
    
    OSType bufferPixelFormat = kCVPixelFormatType_32BGRA;
    
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, 2, NULL, NULL);
    
    CVPixelBufferRef pixelBuffer2 = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault,
                        size.width,
                        size.height,
                        bufferPixelFormat,
                        optionsDictionary,
                        &pixelBuffer2);
    
    CFRelease(optionsDictionary);
    
    return pixelBuffer2;
}

- (CVPixelBufferRef)sampleBufferHandle:(CMSampleBufferRef)sampleBuffer complete:(void(^)(CVPixelBufferRef pixelBuffer))callback
{
    
    CVPixelBufferRef pixelBuffer2 = [[OpenGlHelper share] TextureFromSampleBuffer:sampleBuffer];
    callback(pixelBuffer2);
    return pixelBuffer2;
    
    
    
    
    __weak typeof(self) weakSelf = self;
    __strong typeof(weakSelf) strongSelf = weakSelf;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    pixelBuffer = [[OpenGlHelper share] TextureFromBuffer:pixelBuffer width:CVPixelBufferGetWidth(pixelBuffer) height:CVPixelBufferGetHeight(pixelBuffer)];
    callback(pixelBuffer);
    return pixelBuffer;
    CIImage *inputImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];

//    NSArray *faces = [self processFaceFeaturesWithPicBuffer:NULL pixelBuffer:NULL image:inputImage faceDetector:faceDetector cameraPosition:self.currentCameraPosition];
    if (faceBounds.count > 0){
//        CIFaceFeature *feature = faces[0];
        //            CVPixelBufferLockBaseAddress(pixelBuffer,0);
        //            void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
        strongSelf->width = CVPixelBufferGetWidth(pixelBuffer);
        strongSelf->height = CVPixelBufferGetHeight(pixelBuffer);
        
        
        CIImage *img = [[CIImage alloc] init];
        for (int i = 0 ; i < faceBounds.count ; i++){
            NSValue *value = strongSelf.faceBounds[i];
            CGRect frame = [value CGRectValue];
            double bl = 1.2;
            if (_currentCameraPosition == AVCaptureDevicePositionBack){
                frame = CGRectMake((frame.origin.x) * strongSelf->width, (1-frame.origin.y - bl * frame.size.height) * strongSelf->height, 1.2 * bl * frame.size.width * strongSelf->width, bl * frame.size.height * strongSelf->height);
            }else{
                frame = CGRectMake((1-frame.origin.x - bl * frame.size.width) * strongSelf->width, (1-frame.origin.y - bl * frame.size.height) * strongSelf->height, 1.2 * bl * frame.size.width * strongSelf->width, bl * frame.size.height * strongSelf->height);
            }
            
            CIImage *imagePartToBlur = [inputImage imageByCroppingToRect:frame];
            img =[img imageByCompositingOverImage:imagePartToBlur];
        }
        [strongSelf->coreImageFilter setValue:img forKey:kCIInputImageKey];
        
        //    CIImage *mask = [CIImage imageWithColor:[CIColor blueColor]] ;
        //    [coreImageFilter setValue:mask forKey:@"inputMask"];
        
        [strongSelf->coreImageFilter setValue:[NSNumber numberWithFloat:50] forKey: @"inputRadius"];
        
        CIImage *outputImage = [strongSelf->coreImageFilter outputImage];
        
        CIImage * newImageWithBlurredPart = [outputImage imageByCompositingOverImage:inputImage];
        
        [self.ciContext render:newImageWithBlurredPart toCVPixelBuffer:pixelBuffer];
        
    }
    
    
    //    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    //    NSDictionary *options = [NSDictionary dictionaryWithObject:(__bridge id)rgbColorSpace forKey:kCIImageColorSpace];
    //    CIImage *outputImage = [CIImage imageWithCVPixelBuffer:sampleBuffer options:options];
    //    CGImageRef imageRef = [ciContext createCGImage:outputImage fromRect:CGRectMake(0, 0, width, height)];
    
    //    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    //    CGContextRef context = CGBitmapContextCreate(pxdata, width, height,8, CVPixelBufferGetBytesPerRow(pixelBuffer),rgbColorSpace,(CGBitmapInfo)kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //    CGContextDrawImage(context, CGRectMake(110, 110, 1000, 2000), image.CGImage);
    //    CGColorSpaceRelease(rgbColorSpace);
    //    CGContextRelease(context);
    //        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    //    UIGraphicsEndImageContext();
    
    callback(pixelBuffer);
    return pixelBuffer;
}

/*
 通过gpuimage滤镜进行遮挡
 //void (^)(GPUImageOutput *, CMTime)
 - (void)sampleBufferHandle2:(CMSampleBufferRef)sampleBuffer complete:(void(^)(CVPixelBufferRef pixelBuffer))callback
 {
 
 //    NSArray *faces = [self processFaceFeaturesWithPicBuffer:sampleBuffer pixelBuffer:NULL faceDetector:faceDetector cameraPosition:self.currentCameraPosition];
 
 CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
 if (width == 0){
 width = CVPixelBufferGetWidth(pixelBuffer);
 height = CVPixelBufferGetHeight(pixelBuffer);
 }
 
 NSArray *faces = faceBounds;
 //    [self removeFaceMask];
 if (filterGroup != nil){
 [filterGroup removeAllTargets];
 [gpumovie removeTarget:filterGroup];
 filterGroup = nil;
 }
 filterGroup = [[GPUImageFilterGroup alloc] init];
 [gpumovie addTarget:filterGroup];
 NSMutableDictionary *tmp = [NSMutableDictionary new];
 [beautyFilter removeAllTargets];
 if (faces.count > 0){
 GPUImageBeautifyFilter *first;
 GPUImageBeautifyFilter *last;
 for(int i = 0 ; i < faces.count ; i++){
 NSValue *v = faces[i];
 CGRect frame = [v CGRectValue];
 double bl = 1.2;
 frame = CGRectMake((1-frame.origin.x - bl * frame.size.width) * width, frame.origin.y * height, 1.2 * bl * frame.size.width * width, bl * frame.size.height * height);
 //            NSLog(@"%@", NSStringFromCGRect(frame));
 NSString *key = [NSString stringWithFormat:@"%i,%i,%i,%i",(int)frame.origin.x,(int)frame.origin.y,(int)frame.size.width,(int)frame.size.height];
 GPUImageBeautifyFilter *filter = filters[key];
 if (filter == nil){
 filter = [[GPUImageBeautifyFilter alloc]init];
 tmp[key] = filter;
 }
 [filter updateMask:frame];
 if (i == 0){
 first = filter;
 }
 if (i > 0){
 [last addTarget:filter];
 }
 last = filter;
 [filterGroup addFilter:filter];
 }
 [filterGroup setInitialFilters:@[first]];
 [filterGroup setTerminalFilter:last];
 /*
 [faces enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
 //            [self updateFaceMask:[self faceRect:obj]];
 NSValue *v = obj;
 CGRect frame = [v CGRectValue];
 double bl = 1.2;
 frame = CGRectMake((1-frame.origin.x - bl * frame.size.width) * width, frame.origin.y * height, 1.2 * bl * frame.size.width * width, bl * frame.size.height * height);
 //            NSLog(@"%@", NSStringFromCGRect(frame));
 NSString *key = [NSString stringWithFormat:@"%i,%i,%i,%i",(int)frame.origin.x,(int)frame.origin.y,(int)frame.size.width,(int)frame.size.height];
 GPUImageBeautifyFilter *filter = filters[key];
 if (filter == nil){
 filter = [[GPUImageBeautifyFilter alloc]init];
 tmp[key] = filter;
 }
 [filter updateMask:frame];
 [beautyFilter addTarget:filter];
 }];
 * /
 [filters removeAllObjects];
 filters = tmp;
 
 //        NSLog(@"%i , %i",filters.count , beautyFilter.targets.count);
 }else{
 callback(pixelBuffer);
 return;
 }
 //    [self setFaceRectWithFilter];
 [gpumovie processMovieFrame:sampleBuffer]; // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange 可能需要檢查
 [filterGroup setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
 GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
 glFinish();
 CVPixelBufferRef bufferRef = [imageFramebuffer getRenderTarget];
 //            CMSampleBufferRef newSampleBuffer = NULL;
 //            CMFormatDescriptionRef outputFormatDescription = NULL;
 //            CMVideoFormatDescriptionCreateForImageBuffer( kCFAllocatorDefault, bufferRef, &outputFormatDescription );
 //            OSStatus err = CMSampleBufferCreateForImageBuffer( kCFAllocatorDefault, bufferRef, true, NULL, NULL, outputFormatDescription, &timingInfo, &newSampleBuffer );
 if(bufferRef && callback != nil) {
 callback(bufferRef);
 }
 }];
 
 }
 */

- (void)coreImageHandle:(CVPixelBufferRef)pixelBuffer complete:(void(^)(CVPixelBufferRef pixelBuffer))callback
{
    callback(pixelBuffer);
    return;
    
    /*
     NSArray *faces = [self processFaceFeaturesWithPicBuffer:NULL pixelBuffer:pixelBuffer faceDetector:faceDetector cameraPosition:self.currentCameraPosition];
     [self removeFaceMask];
     if (faces.count > 0){
     [faces enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
     [self updateFaceMask:[self faceRect:obj]];
     }];
     }else{
     callback(pixelBuffer);
     return;
     }
     
     [beautyFilter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
     GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
     glFinish();
     CVPixelBufferRef bufferRef = [imageFramebuffer getRenderTarget];
     callback(bufferRef);
     }];
     */
    
    //    CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
    
    //    if (faceBounds.count > 0){
    //        CIImage *inputImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    //
    //        NSValue *v = faceBounds[0];
    //        CGRect rect = [v CGRectValue];
    //        CIImage *imagePartToBlur = [inputImage imageByCroppingToRect:rect];
    //        [coreImageFilter setValue:imagePartToBlur forKey:kCIInputImageKey];
    //
    //        //    CIImage *mask = [CIImage imageWithColor:[CIColor blueColor]] ;
    //        //    [coreImageFilter setValue:mask forKey:@"inputMask"];
    //        //    // 指定模糊值  默认为10, 范围为0-100
    //        [coreImageFilter setValue:[NSNumber numberWithFloat:50] forKey: @"inputRadius"];
    //
    //        CIImage *outputImage = [coreImageFilter outputImage];
    //        //    elapsedTime = CFAbsoluteTimeGetCurrent() - startTime;
    //        //        NSLog(@"Core Image frame time: %f", elapsedTime * 1000.0);
    //        CIImage * newImageWithBlurredPart = [outputImage imageByCompositingOverImage:inputImage];
    //        [self.ciContext render:newImageWithBlurredPart toCVPixelBuffer:pixelBuffer];
    //    }
    
    /*
     [self setFaceRectWithFilter];
     [beautyFilter outputTextureOptions];
     */
    
    //    return pixelBuffer;
}

- (void)sendVideoSampleBuffer:(CVPixelBufferRef)bufferRef time:(CMSampleTimingInfo)timingInfo  {
    CMSampleBufferRef newSampleBuffer = NULL;
    CMFormatDescriptionRef outputFormatDescription = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer( kCFAllocatorDefault, bufferRef, &outputFormatDescription );
    OSStatus err = CMSampleBufferCreateForImageBuffer( kCFAllocatorDefault, bufferRef, true, NULL, NULL, outputFormatDescription, &timingInfo, &newSampleBuffer );
    if(newSampleBuffer) {
        //          [[SDK sharedSDK].netCallManager sendVideoSampleBuffer:newSampleBuffer];
    }else {
        NSString *exceptionReason = [NSString stringWithFormat:@"sample buffer create failed (%i)", (int)err];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:exceptionReason userInfo:nil];
    }
}

- (CGRect)faceRect:(CIFeature*)feature {
    CGRect faceRect = feature.bounds;
    
    //    CGFloat temp = faceRect.size.width;
    //    temp = faceRect.origin.x;
    //    faceRect.origin.x = faceRect.origin.y;
    //    faceRect.origin.y = temp;
    return faceRect;
}

- (NSArray<CIFeature *> *)processFaceFeaturesWithPicBuffer:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                     image:(CIImage *)image
                                              faceDetector:(CIDetector *)faceDetector
                                            cameraPosition:(AVCaptureDevicePosition)currentCameraPosition {
    
    CIImage *convertedImage;
    if (image != nil){
        convertedImage = image;
    }else {
        if (pixelBuffer == NULL){
            pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        }
        CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
        
        //从帧中获取到的图片相对镜头下看到的会向左旋转90度，所以后续坐标的转换要注意。
        convertedImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
        if (attachments) {
            CFRelease(attachments);
        }
    }
    
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    BOOL isUsingFrontFacingCamera = currentCameraPosition != AVCaptureDevicePositionBack;
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:
            if (isUsingFrontFacingCamera) {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            }else {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            }
            break;
        case UIDeviceOrientationLandscapeRight:
            if (isUsingFrontFacingCamera) {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            }else {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            }
            break;
        default:
            if (isUsingFrontFacingCamera) {
                exifOrientation = 8;
            }else {
                exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP; //值为6。确定初始化原点坐标的位置，坐标原点为右上。其中横的为y，竖的为x，表示真实想要显示图片需要顺时针旋转90度
            }
            break;
    }
    //exifOrientation的值用于确定图片的方向
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    return [faceDetector featuresInImage:convertedImage options:imageOptions];
}
@end

