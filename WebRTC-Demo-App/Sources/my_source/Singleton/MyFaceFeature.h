//
//  MyFaceFeature.h
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/2.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import CoreImage;

@interface MyFaceFeature : NSObject<AVCaptureMetadataOutputObjectsDelegate>{
    dispatch_queue_t sessionQueue;
}

@property(nonatomic,strong)AVCaptureMetadataOutput *metadataOutput;
@property(nonatomic,strong)AVCaptureSession *captureSession;
@property(nonatomic,strong)NSMutableArray *faceBounds;
@property(nonatomic,strong)CIContext *ciContext;
@property(nonatomic,strong)CIFilter *coreImageFilter;
@property(nonatomic,assign)AVCaptureDevicePosition currentCameraPosition;

+(MyFaceFeature *)share;
- (void)setCaptureSession:(AVCaptureSession *)captureSession;
- (CVPixelBufferRef)renderByCIImage:(CVPixelBufferRef)pixelBuffer;
- (void)coreImageHandle:(CVPixelBufferRef)pixelBuffer complete:(void(^)(CVPixelBufferRef pixelBuffer))callback;
- (CVPixelBufferRef)sampleBufferHandle:(CMSampleBufferRef)sampleBuffer complete:(void(^)(CVPixelBufferRef pixelBuffer))callback;

@end
