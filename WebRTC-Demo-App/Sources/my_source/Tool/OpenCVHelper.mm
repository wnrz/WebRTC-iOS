//
//  OpenCVHelper.m
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/3.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//

#include "opencv2/core.hpp"
#include "opencv2/imgproc.hpp"
#include "opencv2/imgcodecs.hpp"
#include "opencv2/highgui.hpp"

#import "OpenCVHelper.h"

using namespace cv;
@implementation OpenCVHelper{
   
}


+ (OpenCVHelper *)share{
    //使用单一线程，解决网络同步请求的问题
    static OpenCVHelper* shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[OpenCVHelper alloc] init];
        [shareInstance initData];
    });
    return shareInstance;
}

-(void)initData{
   
}



@end
