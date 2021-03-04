//
//  OpenGlHelper.h
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/3.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreImage;
@import OpenGLES;
@import CoreVideo;
@import CoreMedia;

NS_ASSUME_NONNULL_BEGIN

@interface OpenGlHelper : NSObject

+(OpenGlHelper *)share;

+(CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size;
- (CVPixelBufferRef)TextureFromBuffer:(CVPixelBufferRef)pixelBuffer width:(double)width height:(double)height;
- (CVPixelBufferRef)TextureFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
