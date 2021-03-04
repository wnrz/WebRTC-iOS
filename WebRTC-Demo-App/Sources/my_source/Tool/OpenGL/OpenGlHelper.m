//
//  OpenGlHelper.m
//  WebRTC-Demo
//
//  Created by 王宁 on 2021/3/3.
//  Copyright © 2021 Stas Seldin. All rights reserved.
//


#import "OpenGlHelper.h"

//kCVPixelFormatType_420YpCbCr8BiPlanarFullRange yuv420f/v
char fsh1[] = "varying highp vec2 textureCoordinate;\
precision mediump float;\
uniform sampler2D SamplerY;\
uniform sampler2D SamplerUV;\
uniform mat3 colorConversionMatrix;\
void main()\
{\
mediump vec3 yuv;\
lowp vec3 rgb;\
yuv.x = (texture2D(SamplerY, textureCoordinate).r);\
yuv.yz = (texture2D(SamplerUV, textureCoordinate).ra - vec2(0.5, 0.5));\
rgb = colorConversionMatrix * yuv;\
gl_FragColor = vec4(rgb,1);\
}";

//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange yuv420f/v
char fsh4[] = "varying highp vec2 textureCoordinate;\
precision mediump float;\
uniform sampler2D SamplerY;\
uniform sampler2D SamplerUV;\
uniform mat3 colorConversionMatrix;\
void main()\
{\
mediump vec3 yuv;\
lowp vec3 rgb;\
yuv.x = (texture2D(SamplerY, textureCoordinate).r - (16.0 / 255.0));\
yuv.yz = (texture2D(SamplerUV, textureCoordinate).ra - vec2(0.5, 0.5));\
rgb = colorConversionMatrix * yuv;\
gl_FragColor = vec4(rgb,1);\
}";
@implementation OpenGlHelper{
    CVOpenGLESTextureCacheRef _textureCache;
    CVEAGLContext _context;
    CVOpenGLESTextureRef _cvTextureOrigin;
    CVOpenGLESTextureRef _cvlumaTexture;
    CVOpenGLESTextureRef _cvchromaTexture;
    int subImageHeight;
    int subImageWidth;
    GLubyte subImage[50][50][4];
}


+ (OpenGlHelper *)share{
    //使用单一线程，解决网络同步请求的问题
    static OpenGlHelper* shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[OpenGlHelper alloc] init];
        [shareInstance initData];
    });
    return shareInstance;
}

-(void)initData{
    subImageHeight = 50;
    subImageWidth = 50;
    for (int i = 0; i < subImageHeight; i++) {
        for (int j = 0; j < subImageWidth; j++) {
            subImage[i][j][0] = (GLubyte) 0;
            subImage[i][j][1] = (GLubyte) 0;
            subImage[i][j][2] = (GLubyte) 255;
            subImage[i][j][3] = (GLubyte) 255;
        }
    }
    _context = [[EAGLContext alloc] initWithAPI:(kEAGLRenderingAPIOpenGLES3)];
    CVReturn result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
    if (result != kCVReturnSuccess) {
        NSLog(@"CVOpenGLESTextureCacheCreate fail %d",result);
    }
}

- (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size {
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
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault,
                        size.width,
                        size.height,
                        bufferPixelFormat,
                        optionsDictionary,
                        &pixelBuffer);
    
    CFRelease(optionsDictionary);
    
    return pixelBuffer;
}

- (CVPixelBufferRef)TextureFromBuffer:(CVPixelBufferRef)pixelBuffer width:(double)width height:(double)height{
    OSType t = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (t == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || t == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange){
        return [self YUV_TextureFromBuffer:pixelBuffer width:width height:height];
    }else{
        return [self BGRA_TextureFromBuffer:pixelBuffer width:width height:height];
    }
}

- (CVPixelBufferRef)TextureFromSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width =CVPixelBufferGetWidth(imageBuffer);
    size_t height =CVPixelBufferGetHeight(imageBuffer);
    NSData *data = [self convertVideoSmapleBufferToYuvData:sampleBuffer];
    CVPixelBufferRef res2 = [self createCVPixelBufferRefFromNV12buffer:(Byte *)[data bytes] width:width height:height];
    return res2;
    
    
    
    
    
    // 获取采集的数据
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    CMTime pts =CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime duration =CMSampleBufferGetDuration(sampleBuffer);


    void *imageAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);//YYYYYYYY
    size_t row0=CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);


    void *imageAddress1=CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);//UVUVUVUV
    size_t row1=CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);


//    size_t width =CVPixelBufferGetWidth(imageBuffer);
//    size_t height =CVPixelBufferGetHeight(imageBuffer);


    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    size_t a=width*height;
    //开始将NV12转换成YUV420
    uint8_t *yuv420Data=(uint8_t*)malloc(a*1.5);


    for (int i=0; i<height; ++i) {
        memcpy(yuv420Data+i*width, imageAddress+i*row0, width);
    }


    uint8_t *UV=imageAddress1;
    uint8_t *U=yuv420Data+a;
    uint8_t *V=U+a/4;
    for (int i=0; i<0.5*height; i++) {
        for (int j=0; j<0.5*width; j++) {

            //printf("%d\n",j<<1);
            *(U++)=UV[j<<1];
            *(V++)=UV[(j<<1)+1];
        }
        UV+=row1;
    }
    //这里根据自己的情况对YUV420数据进行处理

//    [self rendeYUVData:yuv420Data];
    //...........
    //最后记得释放哦
    CVPixelBufferRef res = [self createCVPixelBufferRefFromNV12buffer:yuv420Data width:width height:height];
    free(yuv420Data);
    return res;
}

// AWVideoEncoder.m文件
-(NSData *) convertVideoSmapleBufferToYuvData:(CMSampleBufferRef) videoSample{
    // 获取yuv数据
    // 通过CMSampleBufferGetImageBuffer方法，获得CVImageBufferRef。
    // 这里面就包含了yuv420(NV12)数据的指针
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoSample);

    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(pixelBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //yuv中的y所占字节数
    size_t y_size = pixelWidth * pixelHeight;
    //yuv中的uv所占的字节数
    size_t uv_size = y_size / 2;

    uint8_t *yuv_frame = malloc(uv_size + y_size);

    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(yuv_frame, y_frame, y_size);

    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(yuv_frame + y_size, uv_frame, uv_size);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    //返回数据
    return [NSData dataWithBytesNoCopy:yuv_frame length:y_size + uv_size];
}

-(CVPixelBufferRef)createCVPixelBufferRefFromNV12buffer:(unsigned char *)buffer width:(int)w height:(int)h {
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          w,
                                          h,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // Here y_ch0 is Y-Plane of YUV(NV12) data.
    unsigned char *y_ch0 = buffer;
    memcpy(yDestPlane, y_ch0, w * h);
    unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    unsigned char *y_ch1 = buffer + w * h;
    memcpy(uvDestPlane, y_ch1, w * h/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    
    return pixelBuffer;
}

//
//-(void)clearRenderBuffer {
//
//    //清除缓存
//    glClearColor(0.0, 0.0, 0.0, 1.0);
//    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
//}
//
//#pragma mark 渲染数据
//-(void)rendeYUVData:(unsigned char*)yuv420data {
//
//    //清除缓存
//    [self clearRenderBuffer];
//
//    //
//    float x,y;
//    float wRatio = (float)m_nViewW/m_nVideoW;
//    float hRatio = (float)m_nViewH/m_nVideoH;
//    float minRatio = wRatio<hRatio ? wRatio : hRatio;
//    y = m_nVideoH * minRatio/m_nViewH;
//    x = m_nVideoW * minRatio/m_nViewW;
//
//    float vertexPoints[] ={
//        -x, -y,  0.0f,  1.0f,
//         x, -y,  1.0f,  1.0f,
//        -x,  y,  0.0f,  0.0f,
//         x,  y,  1.0f,  0.0f,
//    };
//    glBufferData(GL_ARRAY_BUFFER, 4 * 4 * sizeof(float), vertexPoints, GL_STATIC_DRAW);
//
//    glActiveTexture(GL_TEXTURE0);
//    glBindTexture(GL_TEXTURE_2D, id_y);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, m_nVideoW, m_nVideoH, 0, GL_RED, GL_UNSIGNED_BYTE, yuv420data);
//    glUniform1i(textureUniformY, 0);
//
//    glActiveTexture(GL_TEXTURE1);
//    glBindTexture(GL_TEXTURE_2D, id_u);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, m_nVideoW / 2, m_nVideoH / 2, 0, GL_RED, GL_UNSIGNED_BYTE, (char*)yuv420data + m_nVideoW*m_nVideoH);
//    glUniform1i(textureUniformU, 1);
//
//    glActiveTexture(GL_TEXTURE2);
//    glBindTexture(GL_TEXTURE_2D, id_v);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, m_nVideoW / 2, m_nVideoH / 2, 0, GL_RED, GL_UNSIGNED_BYTE, (char*)yuv420data + m_nVideoW*m_nVideoH * 5 / 4);
//    glUniform1i(textureUniformV, 2);
//
//    // Draw stuff
//    glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
//    //∫glCheckError();
//}

- (CVPixelBufferRef)BGRA_TextureFromBuffer:(CVPixelBufferRef)pixelBuffer width:(double)width height:(double)height{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CVReturn cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                  _textureCache,
                                                                  pixelBuffer,
                                                                  NULL,
                                                                  GL_TEXTURE_2D,
                                                                  GL_RGBA,
                                                                  width,
                                                                  height,
                                                                  GL_BGRA,
                                                                  GL_UNSIGNED_BYTE,
                                                                  0,
                                                                  &_cvTextureOrigin);
    
    if (!_cvTextureOrigin || kCVReturnSuccess != cvRet) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        return pixelBuffer;
    }
    
    GLuint _textureOriginInput = CVOpenGLESTextureGetName(_cvTextureOrigin);
    glBindTexture(GL_TEXTURE_2D , _textureOriginInput);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    //    CFRelease(pixelBufferTexture);
    
    if (_cvlumaTexture != NULL) {
        CFRelease(_cvTextureOrigin);
    }
    return pixelBuffer;
}

- (CVPixelBufferRef)YUV_TextureFromBuffer:(CVPixelBufferRef)pixelBuffer width:(double)width height:(double)height{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //Y-plane
    glActiveTexture(GL_TEXTURE0);
    CVReturn cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                  _textureCache,
                                                                  pixelBuffer,
                                                                  NULL,
                                                                  GL_TEXTURE_2D,
                                                                  GL_LUMINANCE,
                                                                  width,
                                                                  height,
                                                                  GL_LUMINANCE,
                                                                  GL_UNSIGNED_BYTE,
                                                                  0,
                                                                  &_cvlumaTexture);
    if (!_cvlumaTexture || kCVReturnSuccess != cvRet) {
        
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        return pixelBuffer;
    }
//    glReadPixels(<#GLint x#>, <#GLint y#>, <#GLsizei width#>, <#GLsizei height#>, <#GLenum format#>, <#GLenum type#>, <#GLvoid *pixels#>)
    GLuint _textureLuma = CVOpenGLESTextureGetName(_cvlumaTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(_cvlumaTexture), _textureLuma);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    
    
    
    glTexSubImage2D(GL_TEXTURE_2D, 0, 12, 12,
    subImageWidth, subImageHeight,
    GL_RGBA,GL_UNSIGNED_BYTE, subImage);

    if (_cvlumaTexture != NULL) {
        CFRelease(_cvlumaTexture);
        _cvlumaTexture = NULL;
    }
    
    // UV-plane.
    glActiveTexture(GL_TEXTURE0);
    cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _textureCache,
                                                         pixelBuffer,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_LUMINANCE_ALPHA,
                                                         width / 2,
                                                         height / 2,
                                                         GL_LUMINANCE_ALPHA,
                                                         GL_UNSIGNED_BYTE,
                                                         1,
                                                         &_cvchromaTexture);
    if (!_cvchromaTexture || kCVReturnSuccess != cvRet) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        return pixelBuffer;
    }
    
    GLuint _textureChroma = CVOpenGLESTextureGetName(_cvchromaTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(_cvchromaTexture), _textureChroma);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glViewport(0, 0,500,500);

    glBindTexture(GL_TEXTURE_2D, 0);
    
    
    glTexSubImage2D(GL_TEXTURE_2D, 0, 12, 12,
    subImageWidth, subImageHeight,
    GL_RGBA,GL_UNSIGNED_BYTE, subImage);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    //    CFRelease(pixelBufferTexture);
    if (_cvchromaTexture != NULL) {
        CFRelease(_cvchromaTexture);
        _cvchromaTexture = NULL;
    }
    return pixelBuffer;
}


@end
