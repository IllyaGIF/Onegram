#import "TGVideoCameraGLView.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/glext.h>
#import <stdlib.h>
#import <string.h>
#import <QuartzCore/CAEAGLLayer.h>

#import "TGPaintShader.h"

static bool TGVideoCameraGLViewSupportsBGRAUpload(void)
{
    const GLubyte *extensions = glGetString(GL_EXTENSIONS);
    if (extensions == NULL)
        return false;

    const char *value = (const char *)extensions;
    return strstr(value, "GL_APPLE_texture_format_BGRA8888") != NULL || strstr(value, "GL_EXT_texture_format_BGRA8888") != NULL || strstr(value, "GL_IMG_texture_format_BGRA8888") != NULL;
}

#import "LegacyComponentsInternal.h"
#import <QuartzCore/QuartzCore.h>

@interface TGVideoCameraGLView ()
{
	EAGLContext *_context;
	CVOpenGLESTextureCacheRef _textureCache;
	GLint _width;
	GLint _height;
	GLuint _framebuffer;
	GLuint _colorbuffer;
    GLuint _legacyTexture;
    GLsizei _legacyTextureWidth;
    GLsizei _legacyTextureHeight;
    bool _legacyUploadBGRA;
	
    TGPaintShader *_shader;
	GLint _frame;
}
@end

@implementation TGVideoCameraGLView

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
    if (self != nil)
	{
		if (iosMajorVersion() >= 8)
			self.contentScaleFactor = [UIScreen mainScreen].scale;
		else
			self.contentScaleFactor = [UIScreen mainScreen].scale;
		
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		eaglLayer.opaque = true;
		eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : @false, kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8 };

		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!_context)
			return nil;
	}
	return self;
}

- (bool)initializeBuffers
{
	bool success = YES;
	
	glDisable(GL_DEPTH_TEST);
	
	glGenFramebuffers(1, &_framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	
	glGenRenderbuffers(1, &_colorbuffer );
	glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
	
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorbuffer);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
		success = false;
		goto bail;
	}
	
	
    if (iosMajorVersion() >= 5)
    {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
        if (err)
        {
            success = false;
            goto bail;
        }
    }
    else
    {
        glGenTextures(1, &_legacyTexture);
        if (_legacyTexture == 0)
        {
            success = false;
            goto bail;
        }
        glBindTexture(GL_TEXTURE_2D, _legacyTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);
        _legacyUploadBGRA = TGVideoCameraGLViewSupportsBGRAUpload();
    }
    
    _shader = [[TGPaintShader alloc] initWithVertexShader:@"Passthrough" fragmentShader:@"Passthrough" attributes:@[ @"inPosition", @"inTexcoord" ] uniforms:@[ @"texture" ]];
    
    _frame =  [_shader uniformForKey:@"texture"];
	
bail:
	if ( ! success ) {
		[self reset];
	}
	return success;
}

- (void)reset
{
	EAGLContext *oldContext = [EAGLContext currentContext];
	if (oldContext != _context)
    {
		if (![EAGLContext setCurrentContext:_context])
			return;
	}
    
	if (_framebuffer)
    {
		glDeleteFramebuffers(1, &_framebuffer);
		_framebuffer = 0;
	}
    
	if (_colorbuffer)
    {
		glDeleteRenderbuffers(1, &_colorbuffer);
		_colorbuffer = 0;
	}
    
	if (_shader != nil)
    {
        [_shader cleanResources];
        _shader = nil;
	}
    
	if (_textureCache)
    {
		CFRelease(_textureCache);
		_textureCache = 0;
	}

    if (_legacyTexture)
    {
        glDeleteTextures(1, &_legacyTexture);
        _legacyTexture = 0;
    }

    _legacyTextureWidth = 0;
    _legacyTextureHeight = 0;
    _legacyUploadBGRA = false;
    
	if (oldContext != _context)
		[EAGLContext setCurrentContext:oldContext];
}

- (void)dealloc
{
	[self reset];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    static const GLfloat squareVertices[] =
    {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    if (pixelBuffer == NULL)
        return;

    EAGLContext *oldContext = [EAGLContext currentContext];
    if (oldContext != _context)
    {
        if (![EAGLContext setCurrentContext:_context])
            return;
    }

    if (_framebuffer == 0)
    {
        bool success = [self initializeBuffers];
        if (!success)
        {
            if (oldContext != _context)
                [EAGLContext setCurrentContext:oldContext];
            return;
        }
    }

    size_t frameWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t frameHeight = CVPixelBufferGetHeight(pixelBuffer);
    CVOpenGLESTextureRef texture = NULL;
    GLuint textureName = 0;

    if (iosMajorVersion() >= 5)
    {
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
        if (!texture || err)
        {
            if (oldContext != _context)
                [EAGLContext setCurrentContext:oldContext];
            return;
        }
        textureName = CVOpenGLESTextureGetName(texture);
    }
    else
    {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        size_t packedBytesPerRow = frameWidth * 4;
        const uint8_t *baseAddress = (const uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        uint8_t *packed = NULL;
        const void *pixels = baseAddress;

        if (bytesPerRow != packedBytesPerRow || !_legacyUploadBGRA)
        {
            packed = malloc(packedBytesPerRow * frameHeight);
            if (packed == NULL)
            {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                if (oldContext != _context)
                    [EAGLContext setCurrentContext:oldContext];
                return;
            }
            for (size_t y = 0; y < frameHeight; y++)
                memcpy(packed + y * packedBytesPerRow, baseAddress + y * bytesPerRow, packedBytesPerRow);

            if (!_legacyUploadBGRA)
            {
                size_t pixelCount = frameWidth * frameHeight;
                for (size_t i = 0; i < pixelCount; i++)
                {
                    uint8_t value = packed[i * 4];
                    packed[i * 4] = packed[i * 4 + 2];
                    packed[i * 4 + 2] = value;
                }
            }
            pixels = packed;
        }

        glBindTexture(GL_TEXTURE_2D, _legacyTexture);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
        while (glGetError() != GL_NO_ERROR)
        {
        }
        if (_legacyTextureWidth != (GLsizei)frameWidth || _legacyTextureHeight != (GLsizei)frameHeight)
        {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, 0, _legacyUploadBGRA ? GL_BGRA : GL_RGBA, GL_UNSIGNED_BYTE, pixels);
            _legacyTextureWidth = (GLsizei)frameWidth;
            _legacyTextureHeight = (GLsizei)frameHeight;
        }
        else
        {
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLsizei)frameWidth, (GLsizei)frameHeight, _legacyUploadBGRA ? GL_BGRA : GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        }
        GLenum uploadError = glGetError();
        textureName = _legacyTexture;

        if (packed != NULL)
            free(packed);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        if (uploadError != GL_NO_ERROR)
        {
            glBindTexture(GL_TEXTURE_2D, 0);
            if (oldContext != _context)
                [EAGLContext setCurrentContext:oldContext];
            return;
        }
    }

    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _width, _height);

    glUseProgram(_shader.program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureName);
    glUniform1i(_frame, 0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(0);

    CGSize textureSamplingSize;
    CGSize cropScaleAmount = CGSizeMake(self.bounds.size.width / (CGFloat)frameWidth, self.bounds.size.height / (CGFloat)frameHeight);
    if (cropScaleAmount.height > cropScaleAmount.width)
    {
        textureSamplingSize.width = self.bounds.size.width / (frameWidth * cropScaleAmount.height);
        textureSamplingSize.height = 1.0;
    }
    else
    {
        textureSamplingSize.width = 1.0;
        textureSamplingSize.height = self.bounds.size.height / (frameHeight * cropScaleAmount.width);
    }

    GLfloat passThroughTextureVertices[] =
    {
        (GLfloat)((1.0 - textureSamplingSize.width) / 2.0), (GLfloat)((1.0 + textureSamplingSize.height) / 2.0),
        (GLfloat)((1.0 + textureSamplingSize.width) / 2.0), (GLfloat)((1.0 + textureSamplingSize.height) / 2.0),
        (GLfloat)((1.0 - textureSamplingSize.width) / 2.0), (GLfloat)((1.0 - textureSamplingSize.height) / 2.0),
        (GLfloat)((1.0 + textureSamplingSize.width) / 2.0), (GLfloat)((1.0 - textureSamplingSize.height) / 2.0),
    };

    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, passThroughTextureVertices);
    glEnableVertexAttribArray(1);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];

    glBindTexture(GL_TEXTURE_2D, 0);
    if (texture != NULL)
        CFRelease(texture);

    if (oldContext != _context)
        [EAGLContext setCurrentContext:oldContext];
}

- (void)flushPixelBufferCache
{
	if (_textureCache)
		CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

@end
