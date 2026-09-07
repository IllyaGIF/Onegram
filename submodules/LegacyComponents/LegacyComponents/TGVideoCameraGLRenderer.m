#import "TGVideoCameraGLRenderer.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/glext.h>
#import <stdlib.h>
#import <string.h>
#import <math.h>

#import "TGPaintShader.h"
#import "LegacyComponentsInternal.h"

static bool TGVideoCameraGLSupportsBGRAUpload(void)
{
    const GLubyte *extensions = glGetString(GL_EXTENSIONS);
    if (extensions == NULL)
        return false;

    const char *value = (const char *)extensions;
    return strstr(value, "GL_APPLE_texture_format_BGRA8888") != NULL || strstr(value, "GL_EXT_texture_format_BGRA8888") != NULL || strstr(value, "GL_IMG_texture_format_BGRA8888") != NULL;
}

@interface TGVideoCameraGLRenderer ()
{
	EAGLContext *_context;
	CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureCacheRef _prevTextureCache;
	CVOpenGLESTextureCacheRef _renderTextureCache;
	CVPixelBufferPoolRef _bufferPool;
	CFDictionaryRef _bufferPoolAuxAttributes;
	CMFormatDescriptionRef _outputFormatDescription;
    
    CVPixelBufferRef _previousPixelBuffer;
    
    TGPaintShader *_shader;
	GLint _frameUniform;
    GLint _previousFrameUniform;
    GLint _opacityUniform;
    GLint _aspectRatioUniform;
    GLint _noMirrorUniform;
	GLuint _offscreenBufferHandle;
    GLuint _legacySourceTexture;
    GLuint _legacyPreviousTexture;
    GLuint _legacyRenderTexture;
    GLsizei _legacySourceWidth;
    GLsizei _legacySourceHeight;
    GLsizei _legacyPreviousWidth;
    GLsizei _legacyPreviousHeight;
    bool _legacyReadBGRA;
    bool _legacyUploadBGRA;
    
    CGFloat _aspectRatio;
    float _textureVertices[8];
}

- (bool)initializeLegacyCPUBuffersWithOutputSize:(CGSize)outputSize retainedBufferCountHint:(size_t)retainedBufferCountHint;
- (bool)drawLegacyPixelBuffer:(CVPixelBufferRef)pixelBuffer inContext:(CGContextRef)destinationContext size:(CGSize)destinationSize alpha:(CGFloat)alpha;
- (CVPixelBufferRef)copyLegacyCPURenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

@implementation TGVideoCameraGLRenderer

- (instancetype)init
{
	self = [super init];
	if ( self )
	{
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!_context)
			return nil;
	}
	return self;
}

- (void)dealloc
{
	[self deleteBuffers];
}

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint
{
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription);
    CGFloat minSide = MIN(dimensions.width, dimensions.height);
    CGFloat maxSide = MAX(dimensions.width, dimensions.height);
    CGSize outputSize = CGSizeMake(minSide, minSide);
    
    _aspectRatio = minSide / maxSide;
    [self updateTextureVertices];
    
	[self deleteBuffers];
    if (iosMajorVersion() < 5)
        [self initializeLegacyCPUBuffersWithOutputSize:CGSizeMake(240.0f, 240.0f) retainedBufferCountHint:outputRetainedBufferCountHint];
    else
        [self initializeBuffersWithOutputSize:outputSize retainedBufferCountHint:outputRetainedBufferCountHint];
}

- (void)setOrientation:(AVCaptureVideoOrientation)orientation
{
    _orientation = orientation;
    [self updateTextureVertices];
}

- (void)setMirror:(bool)mirror
{
    _mirror = mirror;
    [self updateTextureVertices];
}

- (void)updateTextureVertices
{
    GLfloat centerOffset = (GLfloat)((1.0f - _aspectRatio) / 2.0f);
    
    switch (_orientation)
    {
        case AVCaptureVideoOrientationPortrait:
            if (!_mirror)
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 0.0f;
            }
            else
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 1.0f;
            }
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            if (!_mirror)
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 0.0f;
            }
            else
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 1.0f;
            }
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            if (!_mirror)
            {
                _textureVertices[0] = centerOffset;
                _textureVertices[1] = 0.0f;
                _textureVertices[2] = (1.0f - centerOffset);
                _textureVertices[3] = 0.0f;
                _textureVertices[4] = centerOffset;
                _textureVertices[5] = 1.0f;
                _textureVertices[6] = (1.0f - centerOffset);
                _textureVertices[7] = 1.0f;
            }
            else
            {
                _textureVertices[0] = (1.0f - centerOffset);
                _textureVertices[1] = 1.0f;
                _textureVertices[2] = centerOffset;
                _textureVertices[3] = 1.0f;
                _textureVertices[4] = (1.0f - centerOffset);
                _textureVertices[5] = 0.0f;
                _textureVertices[6] = centerOffset;
                _textureVertices[7] = 0.0f;
            }
            break;
            
        default:
            break;
    }
}

- (void)reset
{
	[self deleteBuffers];
}

- (bool)hasPreviousPixelbuffer
{
    return _previousPixelBuffer != NULL;
}

- (void)setPreviousPixelBuffer:(CVPixelBufferRef)previousPixelBuffer
{
    if (_previousPixelBuffer != NULL)
    {
        CFRelease(_previousPixelBuffer);
        _previousPixelBuffer = NULL;
    }
    
    _previousPixelBuffer = previousPixelBuffer;
    if (_previousPixelBuffer != NULL)
        CFRetain(_previousPixelBuffer);
}


- (bool)initializeLegacyCPUBuffersWithOutputSize:(CGSize)outputSize retainedBufferCountHint:(size_t)retainedBufferCountHint
{
    size_t bufferCount = MAX((size_t)4, MIN((size_t)8, retainedBufferCountHint));
    _bufferPool = [TGVideoCameraGLRenderer createPixelBufferPoolWithWidth:(int32_t)outputSize.width height:(int32_t)outputSize.height pixelFormat:kCVPixelFormatType_32BGRA maxBufferCount:(int32_t)bufferCount];

    CVPixelBufferRef testPixelBuffer = NULL;
    CVReturn result = _bufferPool != NULL ? CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _bufferPool, &testPixelBuffer) : kCVReturnError;
    if (result != kCVReturnSuccess || testPixelBuffer == NULL)
        result = CVPixelBufferCreate(kCFAllocatorDefault, (size_t)outputSize.width, (size_t)outputSize.height, kCVPixelFormatType_32BGRA, NULL, &testPixelBuffer);
    if (result != kCVReturnSuccess || testPixelBuffer == NULL)
    {
        [self deleteBuffers];
        return false;
    }

    CMFormatDescriptionRef outputFormatDescription = NULL;
    OSStatus formatResult = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, testPixelBuffer, &outputFormatDescription);
    CFRelease(testPixelBuffer);
    if (formatResult != noErr || outputFormatDescription == NULL)
    {
        [self deleteBuffers];
        return false;
    }

    _outputFormatDescription = outputFormatDescription;
    return true;
}

- (bool)drawLegacyPixelBuffer:(CVPixelBufferRef)pixelBuffer inContext:(CGContextRef)destinationContext size:(CGSize)destinationSize alpha:(CGFloat)alpha
{
    if (pixelBuffer == NULL || destinationContext == NULL)
        return false;

    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess)
        return false;

    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef sourceContext = NULL;
    CGImageRef sourceImage = NULL;
    CGImageRef croppedImage = NULL;
    bool success = false;

    if (baseAddress != NULL && colorSpace != NULL)
    {
        sourceContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        if (sourceContext != NULL)
        {
            sourceImage = CGBitmapContextCreateImage(sourceContext);
            if (sourceImage != NULL)
            {
                size_t side = MIN(width, height);
                CGRect cropRect = CGRectMake((CGFloat)(width - side) / 2.0f, (CGFloat)(height - side) / 2.0f, (CGFloat)side, (CGFloat)side);
                croppedImage = CGImageCreateWithImageInRect(sourceImage, cropRect);
                if (croppedImage != NULL)
                {
                    CGContextSaveGState(destinationContext);
                    CGContextSetAlpha(destinationContext, alpha);
                    CGContextTranslateCTM(destinationContext, destinationSize.width / 2.0f, destinationSize.height / 2.0f);
                    if (_mirror)
                        CGContextScaleCTM(destinationContext, -1.0f, 1.0f);

                    switch (_orientation)
                    {
                        case AVCaptureVideoOrientationPortraitUpsideDown:
                            CGContextRotateCTM(destinationContext, (CGFloat)M_PI);
                            break;
                        case AVCaptureVideoOrientationLandscapeLeft:
                            CGContextRotateCTM(destinationContext, (CGFloat)-M_PI_2);
                            break;
                        case AVCaptureVideoOrientationLandscapeRight:
                            CGContextRotateCTM(destinationContext, (CGFloat)M_PI_2);
                            break;
                        default:
                            break;
                    }

                    CGContextTranslateCTM(destinationContext, -destinationSize.width / 2.0f, -destinationSize.height / 2.0f);
                    CGContextDrawImage(destinationContext, CGRectMake(0.0f, 0.0f, destinationSize.width, destinationSize.height), croppedImage);
                    CGContextRestoreGState(destinationContext);
                    success = true;
                }
            }
        }
    }

    if (croppedImage != NULL)
        CGImageRelease(croppedImage);
    if (sourceImage != NULL)
        CGImageRelease(sourceImage);
    if (sourceContext != NULL)
        CGContextRelease(sourceContext);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return success;
}

- (CVPixelBufferRef)copyLegacyCPURenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (_bufferPool == NULL || _outputFormatDescription == NULL || pixelBuffer == NULL)
        return NULL;

    CVPixelBufferRef destinationPixelBuffer = NULL;
    CVReturn result = _bufferPool != NULL ? CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _bufferPool, &destinationPixelBuffer) : kCVReturnError;
    if (result != kCVReturnSuccess || destinationPixelBuffer == NULL)
    {
        destinationPixelBuffer = NULL;
        result = CVPixelBufferCreate(kCFAllocatorDefault, 240, 240, kCVPixelFormatType_32BGRA, NULL, &destinationPixelBuffer);
    }
    if (result != kCVReturnSuccess || destinationPixelBuffer == NULL)
        return NULL;

    if (CVPixelBufferLockBaseAddress(destinationPixelBuffer, 0) != kCVReturnSuccess)
    {
        CFRelease(destinationPixelBuffer);
        return NULL;
    }

    void *baseAddress = CVPixelBufferGetBaseAddress(destinationPixelBuffer);
    size_t width = CVPixelBufferGetWidth(destinationPixelBuffer);
    size_t height = CVPixelBufferGetHeight(destinationPixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(destinationPixelBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = NULL;
    bool success = false;

    if (baseAddress != NULL && colorSpace != NULL)
    {
        context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        if (context != NULL)
        {
            CGRect bounds = CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height);
            success = [self drawLegacyPixelBuffer:pixelBuffer inContext:context size:bounds.size alpha:1.0f];
            if (success && _previousPixelBuffer != NULL && _opacity > FLT_EPSILON)
            {
                CGFloat previousAlpha = MAX(0.0f, MIN(1.0f, _opacity));
                success = [self drawLegacyPixelBuffer:_previousPixelBuffer inContext:context size:bounds.size alpha:previousAlpha];
            }
        }
    }

    if (context != NULL)
        CGContextRelease(context);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(destinationPixelBuffer, 0);

    if (!success)
    {
        CFRelease(destinationPixelBuffer);
        destinationPixelBuffer = NULL;
    }

    return destinationPixelBuffer;
}

- (bool)_uploadPixelBuffer:(CVPixelBufferRef)pixelBuffer toTexture:(GLuint)texture width:(GLsizei *)textureWidth height:(GLsizei *)textureHeight
{
    if (pixelBuffer == NULL || texture == 0)
        return false;

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    const uint8_t *baseAddress = (const uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t packedBytesPerRow = width * 4;
    uint8_t *packed = NULL;
    const void *pixels = baseAddress;

    if (bytesPerRow != packedBytesPerRow || !_legacyUploadBGRA)
    {
        packed = malloc(packedBytesPerRow * height);
        if (packed == NULL)
        {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            return false;
        }

        for (size_t y = 0; y < height; y++)
            memcpy(packed + y * packedBytesPerRow, baseAddress + y * bytesPerRow, packedBytesPerRow);

        if (!_legacyUploadBGRA)
        {
            size_t pixelCount = width * height;
            for (size_t i = 0; i < pixelCount; i++)
            {
                uint8_t value = packed[i * 4];
                packed[i * 4] = packed[i * 4 + 2];
                packed[i * 4 + 2] = value;
            }
        }
        pixels = packed;
    }

    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

    while (glGetError() != GL_NO_ERROR)
    {
    }

    if (*textureWidth != (GLsizei)width || *textureHeight != (GLsizei)height)
    {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, _legacyUploadBGRA ? GL_BGRA : GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        *textureWidth = (GLsizei)width;
        *textureHeight = (GLsizei)height;
    }
    else
    {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLsizei)width, (GLsizei)height, _legacyUploadBGRA ? GL_BGRA : GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    }

    GLenum error = glGetError();
    glBindTexture(GL_TEXTURE_2D, 0);

    if (packed != NULL)
        free(packed);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return error == GL_NO_ERROR;
}

- (CVPixelBufferRef)_copyLegacyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (_offscreenBufferHandle == 0 || _legacyRenderTexture == 0 || _bufferPool == NULL || pixelBuffer == NULL)
        return NULL;

    const CMVideoDimensions dstDimensions = CMVideoFormatDescriptionGetDimensions(_outputFormatDescription);
    EAGLContext *oldContext = [EAGLContext currentContext];
    if (oldContext != _context)
    {
        if (![EAGLContext setCurrentContext:_context])
            return NULL;
    }

    CVPixelBufferRef dstPixelBuffer = NULL;
    bool success = false;
    CVReturn err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &dstPixelBuffer);
    if (err != kCVReturnSuccess || dstPixelBuffer == NULL)
        goto bail;

    if (![self _uploadPixelBuffer:pixelBuffer toTexture:_legacySourceTexture width:&_legacySourceWidth height:&_legacySourceHeight])
        goto bail;

    GLuint previousTexture = _legacySourceTexture;
    if (_previousPixelBuffer != NULL)
    {
        if (![self _uploadPixelBuffer:_previousPixelBuffer toTexture:_legacyPreviousTexture width:&_legacyPreviousWidth height:&_legacyPreviousHeight])
            goto bail;
        previousTexture = _legacyPreviousTexture;
    }

    static const GLfloat squareVertices[] =
    {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _legacyRenderTexture, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        goto bail;

    glViewport(0, 0, dstDimensions.width, dstDimensions.height);
    glUseProgram(_shader.program);

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _legacySourceTexture);
    glUniform1i(_frameUniform, 1);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, previousTexture);
    glUniform1i(_previousFrameUniform, 2);

    glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, _textureVertices);
    glEnableVertexAttribArray(1);

    glUniform1f(_opacityUniform, (GLfloat)_opacity);
    glUniform1f(_aspectRatioUniform, (GLfloat)(1.0f / _aspectRatio));
    glUniform1f(_noMirrorUniform, (GLfloat)(_mirror ? 1 : -1));

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    CVPixelBufferLockBaseAddress(dstPixelBuffer, 0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(dstPixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(dstPixelBuffer);
    size_t packedBytesPerRow = (size_t)dstDimensions.width * 4;
    uint8_t *readTarget = baseAddress;
    uint8_t *packed = NULL;

    if (bytesPerRow != packedBytesPerRow)
    {
        packed = malloc(packedBytesPerRow * (size_t)dstDimensions.height);
        if (packed == NULL)
        {
            CVPixelBufferUnlockBaseAddress(dstPixelBuffer, 0);
            goto bail;
        }
        readTarget = packed;
    }

    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    while (glGetError() != GL_NO_ERROR)
    {
    }
    glReadPixels(0, 0, dstDimensions.width, dstDimensions.height, _legacyReadBGRA ? GL_BGRA : GL_RGBA, GL_UNSIGNED_BYTE, readTarget);
    GLenum readError = glGetError();

    if (readError == GL_NO_ERROR && !_legacyReadBGRA)
    {
        size_t pixelCount = (size_t)dstDimensions.width * (size_t)dstDimensions.height;
        for (size_t i = 0; i < pixelCount; i++)
        {
            uint8_t value = readTarget[i * 4];
            readTarget[i * 4] = readTarget[i * 4 + 2];
            readTarget[i * 4 + 2] = value;
        }
    }

    if (readError == GL_NO_ERROR && packed != NULL)
    {
        for (size_t y = 0; y < (size_t)dstDimensions.height; y++)
            memcpy(baseAddress + y * bytesPerRow, packed + y * packedBytesPerRow, packedBytesPerRow);
    }

    if (packed != NULL)
        free(packed);

    CVPixelBufferUnlockBaseAddress(dstPixelBuffer, 0);

    if (readError != GL_NO_ERROR)
        goto bail;

    success = true;

bail:
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0);
    glActiveTexture(GL_TEXTURE0);

    if (!success && dstPixelBuffer != NULL)
    {
        CFRelease(dstPixelBuffer);
        dstPixelBuffer = NULL;
    }

    if (oldContext != _context)
        [EAGLContext setCurrentContext:oldContext];

    return dstPixelBuffer;
}

- (CVPixelBufferRef)copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (iosMajorVersion() < 5)
        return [self copyLegacyCPURenderedPixelBuffer:pixelBuffer];

	static const GLfloat squareVertices[] =
    {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		-1.0f,  1.0f,
		1.0f,  1.0f,
	};
	
	if (_offscreenBufferHandle == 0)
		return NULL;
	
	if (pixelBuffer == NULL)
		return NULL;
	
	const CMVideoDimensions srcDimensions = { (int32_t)CVPixelBufferGetWidth(pixelBuffer), (int32_t)CVPixelBufferGetHeight(pixelBuffer) };
	const CMVideoDimensions dstDimensions = CMVideoFormatDescriptionGetDimensions(_outputFormatDescription);
		
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return NULL;
	}
	
	CVReturn err = noErr;
	CVOpenGLESTextureRef srcTexture = NULL;
    CVOpenGLESTextureRef prevTexture = NULL;
	CVOpenGLESTextureRef dstTexture = NULL;
	CVPixelBufferRef dstPixelBuffer = NULL;
	
	err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, srcDimensions.width, srcDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &srcTexture);
    
	if (!srcTexture || err)
		goto bail;
    
    bool hasPreviousTexture = false;
    if (_previousPixelBuffer != NULL)
    {
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _prevTextureCache, _previousPixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, srcDimensions.width, srcDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &prevTexture);
        
        if (!prevTexture || err)
            goto bail;
        
        hasPreviousTexture = true;
    }
    
	err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &dstPixelBuffer);
	if (err == kCVReturnWouldExceedAllocationThreshold)
    {
		CVOpenGLESTextureCacheFlush(_renderTextureCache, 0);
		err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &dstPixelBuffer);
	}
    
	if (err)
		goto bail;

	err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _renderTextureCache, dstPixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, dstDimensions.width, dstDimensions.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &dstTexture);
	
	if (!dstTexture || err)
		goto bail;
	
	glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
	glViewport(0, 0, dstDimensions.width, dstDimensions.height);
	glUseProgram(_shader.program);
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(CVOpenGLESTextureGetTarget(dstTexture), CVOpenGLESTextureGetName(dstTexture));
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(dstTexture), CVOpenGLESTextureGetName(dstTexture), 0);
	
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(CVOpenGLESTextureGetTarget(srcTexture), CVOpenGLESTextureGetName(srcTexture));
	glUniform1i(_frameUniform, 1);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if (hasPreviousTexture)
    {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(CVOpenGLESTextureGetTarget(prevTexture), CVOpenGLESTextureGetName(prevTexture));
        glUniform1i(_previousFrameUniform, 2);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
	
	glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, _textureVertices);
	glEnableVertexAttribArray(1);
    
    glUniform1f(_opacityUniform, (GLfloat)_opacity);
    glUniform1f(_aspectRatioUniform, (GLfloat)(1.0f / _aspectRatio));
    glUniform1f(_noMirrorUniform, (GLfloat)(_mirror ? 1 : -1));
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glBindTexture(CVOpenGLESTextureGetTarget(srcTexture), 0);
    if (hasPreviousTexture)
        glBindTexture(CVOpenGLESTextureGetTarget(prevTexture), 0);
	glBindTexture(CVOpenGLESTextureGetTarget(dstTexture), 0);
	
	glFlush();
	
bail:
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
	
	if (srcTexture)
		CFRelease(srcTexture);
    
    if (prevTexture)
        CFRelease(prevTexture);
	
	if (dstTexture)
		CFRelease(dstTexture);
	
	return dstPixelBuffer;
}

- (CMFormatDescriptionRef)outputFormatDescription
{
	return _outputFormatDescription;
}

- (bool)initializeBuffersWithOutputSize:(CGSize)outputSize retainedBufferCountHint:(size_t)clientRetainedBufferCountHint
{
	bool success = true;
	
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return false;
	}
	
	glDisable(GL_DEPTH_TEST);
	
	glGenFramebuffers(1, &_offscreenBufferHandle);
	glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
	
    CVReturn err = kCVReturnSuccess;
    if (iosMajorVersion() >= 5)
    {
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
        if (err)
        {
            success = false;
            goto bail;
        }

        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_prevTextureCache);
        if (err)
        {
            success = false;
            goto bail;
        }

        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_renderTextureCache);
        if (err)
        {
            success = false;
            goto bail;
        }
    }
    else
    {
        glGenTextures(1, &_legacySourceTexture);
        glGenTextures(1, &_legacyPreviousTexture);
        glGenTextures(1, &_legacyRenderTexture);
        if (_legacySourceTexture == 0 || _legacyPreviousTexture == 0 || _legacyRenderTexture == 0)
        {
            success = false;
            goto bail;
        }

        glBindTexture(GL_TEXTURE_2D, _legacyRenderTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)outputSize.width, (GLsizei)outputSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _legacyRenderTexture, 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            success = false;
            goto bail;
        }

        const GLubyte *extensions = glGetString(GL_EXTENSIONS);
        _legacyReadBGRA = extensions != NULL && strstr((const char *)extensions, "GL_EXT_read_format_bgra") != NULL;
        _legacyUploadBGRA = TGVideoCameraGLSupportsBGRAUpload();
    }

    _shader = [[TGPaintShader alloc] initWithVertexShader:@"VideoMessage" fragmentShader:@"VideoMessage" attributes:@[ @"inPosition", @"inTexcoord" ] uniforms:@[ @"texture", @"previousTexture", @"opacity", @"aspectRatio", @"noMirror" ]];
    
    _frameUniform = [_shader uniformForKey:@"texture"];
    _previousFrameUniform = [_shader uniformForKey:@"previousTexture"];
    _opacityUniform = [_shader uniformForKey:@"opacity"];
    _aspectRatioUniform = [_shader uniformForKey:@"aspectRatio"];
    _noMirrorUniform = [_shader uniformForKey:@"noMirror"];
    
	size_t maxRetainedBufferCount = clientRetainedBufferCountHint + 1;
    _bufferPool = [TGVideoCameraGLRenderer createPixelBufferPoolWithWidth:(int32_t)outputSize.width height:(int32_t)outputSize.height pixelFormat:kCVPixelFormatType_32BGRA maxBufferCount:(int32_t)maxRetainedBufferCount];
    
	if (!_bufferPool)
    {
		success = NO;
		goto bail;
	}
	
    _bufferPoolAuxAttributes = [TGVideoCameraGLRenderer createPixelBufferPoolAuxAttribute:(int32_t)maxRetainedBufferCount];
    [TGVideoCameraGLRenderer preallocatePixelBuffersInPool:_bufferPool auxAttributes:_bufferPoolAuxAttributes];
	
	CMFormatDescriptionRef outputFormatDescription = NULL;
	CVPixelBufferRef testPixelBuffer = NULL;
	CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferPoolAuxAttributes, &testPixelBuffer);
	if (!testPixelBuffer)
    {
		success = false;
		goto bail;
	}
	CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, testPixelBuffer, &outputFormatDescription);
	_outputFormatDescription = outputFormatDescription;
	CFRelease( testPixelBuffer );
	
bail:
	if (!success)
		[self deleteBuffers];
	
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
	
	return success;
}

- (void)deleteBuffers
{
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return;
	}
    
	if (_offscreenBufferHandle)
    {
		glDeleteFramebuffers(1, &_offscreenBufferHandle);
		_offscreenBufferHandle = 0;
	}
	
    if (_shader)
    {
        [_shader cleanResources];
        _shader = nil;
	}
    
	if (_textureCache)
    {
		CFRelease(_textureCache);
		_textureCache = 0;
	}
    
    if (_prevTextureCache)
    {
        CFRelease(_prevTextureCache);
        _prevTextureCache = 0;
    }
    
	if (_renderTextureCache)
    {
		CFRelease(_renderTextureCache);
		_renderTextureCache = 0;
	}

    if (_legacySourceTexture)
    {
        glDeleteTextures(1, &_legacySourceTexture);
        _legacySourceTexture = 0;
    }

    if (_legacyPreviousTexture)
    {
        glDeleteTextures(1, &_legacyPreviousTexture);
        _legacyPreviousTexture = 0;
    }

    if (_legacyRenderTexture)
    {
        glDeleteTextures(1, &_legacyRenderTexture);
        _legacyRenderTexture = 0;
    }

    _legacySourceWidth = 0;
    _legacySourceHeight = 0;
    _legacyPreviousWidth = 0;
    _legacyPreviousHeight = 0;
    _legacyReadBGRA = false;
    _legacyUploadBGRA = false;
    
	if (_bufferPool)
    {
		CFRelease(_bufferPool);
		_bufferPool = NULL;
	}
    
	if (_bufferPoolAuxAttributes)
    {
		CFRelease(_bufferPoolAuxAttributes);
		_bufferPoolAuxAttributes = NULL;
	}
    
	if (_outputFormatDescription)
    {
		CFRelease(_outputFormatDescription);
		_outputFormatDescription = NULL;
	}
    
	if (oldContext != _context)
        [EAGLContext setCurrentContext:oldContext];
}

+ (CVPixelBufferPoolRef)createPixelBufferPoolWithWidth:(int32_t)width height:(int32_t)height pixelFormat:(FourCharCode)pixelFormat maxBufferCount:(int32_t) maxBufferCount
{
	CVPixelBufferPoolRef outputPool = NULL;
	
    NSDictionary *sourcePixelBufferOptions = nil;
    if (iosMajorVersion() >= 5)
    {
        sourcePixelBufferOptions = @
        {
            (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat),
            (id)kCVPixelBufferWidthKey : @(width),
            (id)kCVPixelBufferHeightKey : @(height),
            (id)kCVPixelFormatOpenGLESCompatibility : @true,
            (id)kCVPixelBufferIOSurfacePropertiesKey : @{ }
        };
    }
    else
    {
        sourcePixelBufferOptions = @
        {
            (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat),
            (id)kCVPixelBufferWidthKey : @(width),
            (id)kCVPixelBufferHeightKey : @(height)
        };
    }
	
    NSDictionary *pixelBufferPoolOptions = @{ (id)kCVPixelBufferPoolMinimumBufferCountKey : @(maxBufferCount) };
	CVPixelBufferPoolCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)pixelBufferPoolOptions, (__bridge CFDictionaryRef)sourcePixelBufferOptions, &outputPool);
	
	return outputPool;
}

+ (CFDictionaryRef)createPixelBufferPoolAuxAttribute:(int32_t)maxBufferCount
{
	return CFBridgingRetain( @{ (id)kCVPixelBufferPoolAllocationThresholdKey : @(maxBufferCount) } );
}

+ (void)preallocatePixelBuffersInPool:(CVPixelBufferPoolRef)pool auxAttributes:(CFDictionaryRef)auxAttributes
{
	NSMutableArray *pixelBuffers = [[NSMutableArray alloc] init];
    
	while (true)
	{
		CVPixelBufferRef pixelBuffer = NULL;
		OSStatus err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer);
		
		if (err == kCVReturnWouldExceedAllocationThreshold)
			break;
		
		[pixelBuffers addObject:CFBridgingRelease(pixelBuffer)];
	}
    
	[pixelBuffers removeAllObjects];
}

@end
