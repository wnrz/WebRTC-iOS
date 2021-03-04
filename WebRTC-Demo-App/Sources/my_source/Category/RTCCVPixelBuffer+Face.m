//
//  RTCCVPixelBuffer+RTCCVPixelBuffer_Face.m
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/2.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#import "RTCCVPixelBuffer+Face.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "MyFaceFeature.h"
@import OpenGLES;
@import WebRTC;


@implementation RTCCVPixelBuffer (Face)

+ (void)load {
    [RTCCVPixelBuffer swizzleInstanceMethodWithClass:[self class] originalSel:
     @selector(initWithPixelBuffer:) replacementSel:
     @selector(initSwizzleWithPixelBuffer:)];
    [RTCCVPixelBuffer swizzleInstanceMethodWithClass:[self class] originalSel:
     @selector(initWithPixelBuffer:adaptedWidth:adaptedHeight:cropWidth:cropHeight:cropX:cropY:) replacementSel:
     @selector(initSwizzleWithPixelBuffer:adaptedWidth:adaptedHeight:cropWidth:cropHeight:cropX:cropY:)];
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

- (instancetype)initSwizzleWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
//    CVPixelBufferRef pixelBuffer2 = [self renderByCIImage:pixelBuffer];

//    id res = [self initSwizzleWithPixelBuffer: [[MyFaceFeature share] coreImageHandle:pixelBuffer complete:nil]];
    id res = [self initSwizzleWithPixelBuffer:pixelBuffer];

    return res;
}

- (instancetype)initSwizzleWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                              adaptedWidth:(int)adaptedWidth
                             adaptedHeight:(int)adaptedHeight
                                 cropWidth:(int)cropWidth
                                cropHeight:(int)cropHeight
                                     cropX:(int)cropX
                                     cropY:(int)cropY {
    return [self initSwizzleWithPixelBuffer:pixelBuffer adaptedWidth:adaptedWidth adaptedHeight:adaptedHeight cropWidth:cropWidth cropHeight:cropHeight cropX:cropX cropY:cropY];
}



@end






