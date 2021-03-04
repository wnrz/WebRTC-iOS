//
//  RTCCameraVideoCapturer+Face.m
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/2.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#import "RTCCameraVideoCapturer+Face.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "MyFaceFeature.h"
#import "OpenGlHelper.h"
@import OpenGLES;
@import WebRTC;
@import CoreFoundation;

@implementation RTCCameraVideoCapturer (Face)

+ (void)load {
    [RTCCameraVideoCapturer swizzleInstanceMethodWithClass:[self class] originalSel:@selector(captureOutput:didOutputSampleBuffer:fromConnection:) replacementSel:@selector(swizzle_captureOutput:didOutputSampleBuffer:fromConnection:)];
    [RTCCameraVideoCapturer swizzleInstanceMethodWithClass:[self class] originalSel:@selector(setupCaptureSession:) replacementSel:@selector(swizzle_setupCaptureSession:)];
}


+ (void)swizzleInstanceMethodWithClass:(Class)clazz originalSel:(SEL)original replacementSel:(SEL)replacement {
    Method originalMethod = class_getInstanceMethod(clazz, original);// Note that this function searches superclasses for implementations, whereas class_copyMethodList does not!!如果子类没有实现该方法则返回的是父类的方法
    Method replacementMethod = class_getInstanceMethod(clazz, replacement);
    if (class_addMethod(clazz, original, method_getImplementation(replacementMethod), method_getTypeEncoding(replacementMethod))) {
        class_replaceMethod(clazz, replacement, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, replacementMethod);
    }
}

- (void)extracted:(AVCaptureConnection *)connection sampleBuffer:(CMSampleBufferRef)sampleBuffer timeStampNs:(int64_t)timeStampNs {
    [[MyFaceFeature share] sampleBufferHandle:sampleBuffer complete:^(CVPixelBufferRef pixelBuffer) {
        if (pixelBuffer == nil) {
            return;
        }
        
        RTCVideoRotation _rotation = 90;
#if TARGET_OS_IPHONE
        // Default to portrait orientation on iPhone.
        BOOL usingFrontCamera = NO;
        // Check the image's EXIF for the camera the image came from as the image could have been
        // delayed as we set alwaysDiscardsLateVideoFrames to NO.
        AVCaptureDevicePosition cameraPosition = [MyFaceFeature share].currentCameraPosition;
        //    [self devicePositionForSampleBuffer:sampleBuffer];
        if (cameraPosition != AVCaptureDevicePositionUnspecified) {
            usingFrontCamera = AVCaptureDevicePositionFront == cameraPosition;
        } else {
            AVCaptureDeviceInput *deviceInput =
            (AVCaptureDeviceInput *)((AVCaptureInputPort *)connection.inputPorts.firstObject).input;
            usingFrontCamera = AVCaptureDevicePositionFront == deviceInput.device.position;
        }
        switch ([[UIDevice currentDevice] orientation]) {
            case UIDeviceOrientationPortrait:
                _rotation = 90;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                _rotation = 270;
                break;
            case UIDeviceOrientationLandscapeLeft:
                _rotation = usingFrontCamera ? 180 : 0;
                break;
            case UIDeviceOrientationLandscapeRight:
                _rotation = usingFrontCamera ? 0 : 180;
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            case UIDeviceOrientationUnknown:
                // Ignore.
                break;
        }
#else
        // No rotation on Mac.
        _rotation = 0;
#endif
        if ([MyFaceFeature share].currentCameraPosition == AVCaptureDevicePositionFront && [connection isVideoMirroringSupported]){
            _rotation = _rotation + 180;
            connection.videoMirrored = YES;
        }else if ([MyFaceFeature share].currentCameraPosition != AVCaptureDevicePositionFront){
            connection.videoMirrored = NO;
            
        }
        RTC_OBJC_TYPE(RTCCVPixelBuffer) *rtcPixelBuffer =
        [[RTC_OBJC_TYPE(RTCCVPixelBuffer) alloc] initWithPixelBuffer:pixelBuffer];
        CVBufferRelease(pixelBuffer);

        RTC_OBJC_TYPE(RTCVideoFrame) *videoFrame =
        [[RTC_OBJC_TYPE(RTCVideoFrame) alloc] initWithBuffer:rtcPixelBuffer
                                                    rotation:_rotation
                                                 timeStampNs:timeStampNs];
        [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
        
    }];
}

- (void)swizzle_captureOutput:(AVCaptureOutput *)captureOutput
        didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
               fromConnection:(AVCaptureConnection *)connection {
    
    
   if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
       !CMSampleBufferDataIsReady(sampleBuffer)) {
       return;
   }
    int64_t timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) *
    1000000000;
    /*
     [[MyFaceFeature share] sampleBufferHandle:sampleBuffer complete:^(CMSampleBufferRef sampleBuffer2) {
     [self swizzle_captureOutput:captureOutput didOutputSampleBuffer:sampleBuffer2 fromConnection:connection];
     }];
     return;
     */
    [self extracted:connection sampleBuffer:sampleBuffer timeStampNs:timeStampNs];
    
    
    
    
    //    CMVideoFormatDescriptionRef videoInfo = CMSampleBufferGetFormatDescription(sampleBuffer);
    //    CMSampleTimingInfo timing = kCMTimingInfoInvalid;
    //    CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing);
    //    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //    if (pixelBuffer == nil) {
    //      return;
    //    }
    //
    //    CVPixelBufferRef pixelBuffer2 = [[MyFaceFeature share] renderByCIImage:pixelBuffer];
    ////    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer2, YES, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    //    CVPixelBufferRelease(pixelBuffer2);
    //    CFRelease(videoInfo);
    
}

- (BOOL)swizzle_setupCaptureSession:(AVCaptureSession *)captureSession{
    BOOL res = [self swizzle_setupCaptureSession:captureSession];
    [[MyFaceFeature share] setCaptureSession:captureSession];
    return res;
}


//- (AVCaptureDevicePosition)devicePositionForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
//  // Check the image's EXIF for the camera the image came from.
//  AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionUnspecified;
//  CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(
//      kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
//  if (attachments) {
//    int size = CFDictionaryGetCount(attachments);
//    if (size > 0) {
//      CFDictionaryRef cfExifDictVal = nil;
//      if (CFDictionaryGetValueIfPresent(
//              attachments, (const void *)CFSTR("{Exif}"), (const void **)&cfExifDictVal)) {
//        CFStringRef cfLensModelStrVal;
//        if (CFDictionaryGetValueIfPresent(cfExifDictVal,
//                                          (const void *)CFSTR("LensModel"),
//                                          (const void **)&cfLensModelStrVal)) {
//          if (CFStringContainsString(cfLensModelStrVal, CFSTR("front"))) {
//            cameraPosition = AVCaptureDevicePositionFront;
//          } else if (CFStringContainsString(cfLensModelStrVal, CFSTR("back"))) {
//            cameraPosition = AVCaptureDevicePositionBack;
//          }
//        }
//      }
//    }
//    CFRelease(attachments);
//  }
//  return cameraPosition;
//}
@end






