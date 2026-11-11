#import "TGCallVideoNative.h"

#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoFrame.h"

#import <QuartzCore/QuartzCore.h>

#if !defined(ONEGRAM_ARMV6)
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CoreVideo.h>
#endif

#include <pthread.h>
#include <string.h>
#include <syslog.h>
#include <vector>

@interface TGCallVideoRenderer : NSObject

@property (nonatomic, copy) void (^firstFrameRendered)(void);
@property (nonatomic, copy) void (^videoSizeChanged)(CGSize size);

- (instancetype)initWithView:(UIView *)view;
- (void)enqueueFrame:(const tgcalls::VideoFrame &)frame;
- (void)layoutWithBounds:(CGRect)bounds scale:(CGFloat)scale;
- (void)setFillsBounds:(bool)fillsBounds mirrored:(bool)mirrored;
- (void)setPaused:(bool)paused;
- (void)reset;
- (void)invalidate;

@end

namespace {

class TGCallVideoViewSink : public tgcalls::VideoFrameSink {
public:
    explicit TGCallVideoViewSink(TGCallVideoRenderer *renderer) : _renderer(renderer) {
    }

    void onVideoFrame(const tgcalls::VideoFrame &frame) override {
        [_renderer enqueueFrame:frame];
    }

private:
    TGCallVideoRenderer *_renderer;
};

}

#if !defined(ONEGRAM_ARMV6)

namespace {

void DisplayedTexcoords(int rotation, bool mirrored, float *coordinates) {
    static const float kRotation0[8] = { 0.0f, 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f };
    static const float kRotation90[8] = { 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f };
    static const float kRotation180[8] = { 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f };
    static const float kRotation270[8] = { 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f, 1.0f };
    const float *source = kRotation0;
    if (rotation == 90)
        source = kRotation90;
    else if (rotation == 180)
        source = kRotation180;
    else if (rotation == 270)
        source = kRotation270;
    if (!mirrored)
    {
        memcpy(coordinates, source, sizeof(float) * 8);
        return;
    }
    const int order[4] = { 1, 0, 3, 2 };
    for (int i = 0; i < 4; i++)
    {
        coordinates[i * 2] = source[order[i] * 2];
        coordinates[i * 2 + 1] = source[order[i] * 2 + 1];
    }
}

const char *kVertexShader =
    "attribute vec2 position;\n"
    "attribute vec2 texcoord;\n"
    "varying vec2 v_texcoord;\n"
    "void main() {\n"
    "    gl_Position = vec4(position, 0.0, 1.0);\n"
    "    v_texcoord = texcoord;\n"
    "}\n";

const char *kBiPlanarShader =
    "precision mediump float;\n"
    "varying vec2 v_texcoord;\n"
    "uniform sampler2D s_y;\n"
    "uniform sampler2D s_uv;\n"
    "uniform float u_offset;\n"
    "uniform float u_scale;\n"
    "void main() {\n"
    "    float y = (texture2D(s_y, v_texcoord).r - u_offset) * u_scale;\n"
    "    vec2 uv = texture2D(s_uv, v_texcoord).ra - vec2(0.5, 0.5);\n"
    "    gl_FragColor = vec4(y + 1.596 * uv.y, y - 0.392 * uv.x - 0.813 * uv.y, y + 2.017 * uv.x, 1.0);\n"
    "}\n";

const char *kPlanarShader =
    "precision mediump float;\n"
    "varying vec2 v_texcoord;\n"
    "uniform sampler2D s_y;\n"
    "uniform sampler2D s_u;\n"
    "uniform sampler2D s_v;\n"
    "void main() {\n"
    "    float y = (texture2D(s_y, v_texcoord).r - 0.0625) * 1.164;\n"
    "    float u = texture2D(s_u, v_texcoord).r - 0.5;\n"
    "    float v = texture2D(s_v, v_texcoord).r - 0.5;\n"
    "    gl_FragColor = vec4(y + 1.596 * v, y - 0.392 * u - 0.813 * v, y + 2.017 * u, 1.0);\n"
    "}\n";

GLuint CompileShader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, 0);
    glCompileShader(shader);
    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint LinkProgram(const char *fragmentSource) {
    GLuint vertex = CompileShader(GL_VERTEX_SHADER, kVertexShader);
    GLuint fragment = CompileShader(GL_FRAGMENT_SHADER, fragmentSource);
    if (vertex == 0 || fragment == 0) {
        if (vertex != 0) glDeleteShader(vertex);
        if (fragment != 0) glDeleteShader(fragment);
        return 0;
    }
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glBindAttribLocation(program, 0, "position");
    glBindAttribLocation(program, 1, "texcoord");
    glLinkProgram(program);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == 0) {
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

}

@implementation TGCallVideoRenderer
{
    __unsafe_unretained UIView *_view;
    CAEAGLLayer *_layer;
    dispatch_queue_t _queue;
    EAGLContext *_context;
    CVOpenGLESTextureCacheRef _textureCache;
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLint _drawableWidth;
    GLint _drawableHeight;
    bool _drawableDirty;
    GLuint _biPlanarProgram;
    GLuint _planarProgram;
    GLint _biPlanarOffset;
    GLint _biPlanarScale;
    GLuint _planarTextures[3];
    int _planarWidth;
    int _planarHeight;
    bool _planarBiPlanar;
    std::vector<uint8_t> _scratch;

    pthread_mutex_t _mutex;
    tgcalls::VideoFrame _pending;
    bool _hasPending;
    bool _scheduled;
    bool _paused;
    bool _invalidated;
    bool _fillsBounds;
    bool _mirrored;
    bool _renderedFirstFrame;
    CGSize _lastVideoSize;
    tgcalls::VideoFrame _lastFrame;
    bool _hasLastFrame;
}

- (instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self != nil)
    {
        _view = view;
        _layer = (CAEAGLLayer *)view.layer;
        _layer.opaque = true;
        _layer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking: @false, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8 };
        _queue = dispatch_queue_create("org.onegram.call.video.render", DISPATCH_QUEUE_SERIAL);
        pthread_mutex_init(&_mutex, NULL);
        _fillsBounds = true;
        _drawableDirty = true;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
}

- (bool)prepareContext
{
    if (_context != nil)
        return [EAGLContext setCurrentContext:_context];
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (_context == nil || ![EAGLContext setCurrentContext:_context])
    {
        _context = nil;
        return false;
    }
    _biPlanarProgram = LinkProgram(kBiPlanarShader);
    _planarProgram = LinkProgram(kPlanarShader);
    if (_biPlanarProgram != 0)
    {
        glUseProgram(_biPlanarProgram);
        glUniform1i(glGetUniformLocation(_biPlanarProgram, "s_y"), 0);
        glUniform1i(glGetUniformLocation(_biPlanarProgram, "s_uv"), 1);
        _biPlanarOffset = glGetUniformLocation(_biPlanarProgram, "u_offset");
        _biPlanarScale = glGetUniformLocation(_biPlanarProgram, "u_scale");
    }
    if (_planarProgram != 0)
    {
        glUseProgram(_planarProgram);
        glUniform1i(glGetUniformLocation(_planarProgram, "s_y"), 0);
        glUniform1i(glGetUniformLocation(_planarProgram, "s_u"), 1);
        glUniform1i(glGetUniformLocation(_planarProgram, "s_v"), 2);
    }
    glGenTextures(3, _planarTextures);
    for (int i = 0; i < 3; i++)
    {
        glBindTexture(GL_TEXTURE_2D, _planarTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (OGCompatTextureCacheAvailable())
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    _drawableDirty = true;
    syslog(LOG_NOTICE, "IOS6MEDIA render.context view=%p biplanar=%u planar=%u cache=%d", (__bridge void *)_view, _biPlanarProgram, _planarProgram, _textureCache != NULL ? 1 : 0);
    return true;
}

- (bool)prepareDrawable
{
    if (!_drawableDirty)
        return _drawableWidth > 0 && _drawableHeight > 0;
    _drawableDirty = false;
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    if (![_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_layer])
    {
        _drawableWidth = 0;
        _drawableHeight = 0;
        syslog(LOG_ERR, "IOS6MEDIA render.drawable.failed view=%p", (__bridge void *)_view);
        return false;
    }
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_drawableWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_drawableHeight);
    const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    syslog(LOG_NOTICE, "IOS6MEDIA render.drawable view=%p size=%dx%d status=%x", (__bridge void *)_view, _drawableWidth, _drawableHeight, status);
    return status == GL_FRAMEBUFFER_COMPLETE && _drawableWidth > 0 && _drawableHeight > 0;
}

- (void)enqueueFrame:(const tgcalls::VideoFrame &)frame
{
    if (!frame.buffer)
        return;
    bool schedule = false;
    pthread_mutex_lock(&_mutex);
    if (!_invalidated)
    {
        _pending = frame;
        _hasPending = true;
        if (!_scheduled && !_paused)
        {
            _scheduled = true;
            schedule = true;
        }
    }
    pthread_mutex_unlock(&_mutex);
    if (schedule)
    {
        dispatch_async(_queue, ^
        {
            [self renderPending];
        });
    }
}

- (void)renderPending
{
    tgcalls::VideoFrame frame;
    bool fills = true;
    bool mirrored = false;
    pthread_mutex_lock(&_mutex);
    _scheduled = false;
    if (_invalidated || _paused || !_hasPending)
    {
        pthread_mutex_unlock(&_mutex);
        return;
    }
    frame = _pending;
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    fills = _fillsBounds;
    mirrored = _mirrored;
    pthread_mutex_unlock(&_mutex);
    [self drawFrame:frame fills:fills mirrored:mirrored != frame.mirrored];
}

- (void)redrawLastFrame
{
    if (!_hasLastFrame)
        return;
    bool fills = true;
    bool mirrored = false;
    pthread_mutex_lock(&_mutex);
    fills = _fillsBounds;
    mirrored = _mirrored;
    const bool paused = _paused || _invalidated;
    pthread_mutex_unlock(&_mutex);
    if (!paused)
        [self drawFrame:_lastFrame fills:fills mirrored:mirrored != _lastFrame.mirrored];
}

- (void)useBiPlanarProgramForFormat:(OSType)format
{
    const bool fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    glUseProgram(_biPlanarProgram);
    glUniform1f(_biPlanarOffset, fullRange ? 0.0f : 0.0625f);
    glUniform1f(_biPlanarScale, fullRange ? 1.0f : 1.164f);
}

- (void)uploadPlane:(const uint8_t *)data stride:(size_t)stride width:(int)width height:(int)height bytesPerPixel:(int)bytesPerPixel format:(GLenum)format unit:(int)unit resize:(bool)resize
{
    glActiveTexture(GL_TEXTURE0 + unit);
    glBindTexture(GL_TEXTURE_2D, _planarTextures[unit]);
    const size_t rowBytes = (size_t)width * (size_t)bytesPerPixel;
    const uint8_t *source = data;
    if (stride != rowBytes)
    {
        _scratch.resize(rowBytes * (size_t)height);
        for (int row = 0; row < height; row++)
            memcpy(&_scratch[(size_t)row * rowBytes], data + (size_t)row * stride, rowBytes);
        source = &_scratch[0];
    }
    if (resize)
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, source);
    else
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, format, GL_UNSIGNED_BYTE, source);
}

- (bool)uploadNativeFrame:(const tgcalls::VideoFrame &)frame
{
    if (_biPlanarProgram == 0)
        return false;
    CVPixelBufferRef pixelBuffer = static_cast<tgcalls::NativeVideoBuffer *>(frame.buffer.get())->pixelBuffer();
    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2 || CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess)
        return false;
    const int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    const bool resize = width != _planarWidth || height != _planarHeight || !_planarBiPlanar;
    _planarWidth = width;
    _planarHeight = height;
    _planarBiPlanar = true;
    [self uploadPlane:(const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) stride:CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) width:width height:height bytesPerPixel:1 format:GL_LUMINANCE unit:0 resize:resize];
    [self uploadPlane:(const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) stride:CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) width:(width + 1) / 2 height:(height + 1) / 2 bytesPerPixel:2 format:GL_LUMINANCE_ALPHA unit:1 resize:resize];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    [self useBiPlanarProgramForFormat:CVPixelBufferGetPixelFormatType(pixelBuffer)];
    return true;
}

- (bool)bindNativeFrame:(const tgcalls::VideoFrame &)frame textures:(CVOpenGLESTextureRef *)textures
{
    if (_biPlanarProgram == 0)
        return false;
    if (_textureCache == NULL)
        return [self uploadNativeFrame:frame];
    CVPixelBufferRef pixelBuffer = static_cast<tgcalls::NativeVideoBuffer *>(frame.buffer.get())->pixelBuffer();
    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2)
        return false;
    const int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    glActiveTexture(GL_TEXTURE0);
    if (CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, width, height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &textures[0]) != kCVReturnSuccess)
        return false;
    glBindTexture(CVOpenGLESTextureGetTarget(textures[0]), CVOpenGLESTextureGetName(textures[0]));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glActiveTexture(GL_TEXTURE1);
    if (CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, (width + 1) / 2, (height + 1) / 2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &textures[1]) != kCVReturnSuccess)
        return false;
    glBindTexture(CVOpenGLESTextureGetTarget(textures[1]), CVOpenGLESTextureGetName(textures[1]));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    [self useBiPlanarProgramForFormat:CVPixelBufferGetPixelFormatType(pixelBuffer)];
    return true;
}

- (bool)bindPlanarFrame:(const tgcalls::VideoFrame &)frame
{
    if (_planarProgram == 0)
        return false;
    const tgcalls::I420Buffer *buffer = static_cast<const tgcalls::I420Buffer *>(frame.buffer.get());
    const int width = buffer->width();
    const int height = buffer->height();
    const bool resize = width != _planarWidth || height != _planarHeight || _planarBiPlanar;
    _planarWidth = width;
    _planarHeight = height;
    _planarBiPlanar = false;
    [self uploadPlane:buffer->dataY() stride:(size_t)buffer->strideY() width:width height:height bytesPerPixel:1 format:GL_LUMINANCE unit:0 resize:resize];
    [self uploadPlane:buffer->dataU() stride:(size_t)buffer->strideUV() width:(width + 1) / 2 height:(height + 1) / 2 bytesPerPixel:1 format:GL_LUMINANCE unit:1 resize:resize];
    [self uploadPlane:buffer->dataV() stride:(size_t)buffer->strideUV() width:(width + 1) / 2 height:(height + 1) / 2 bytesPerPixel:1 format:GL_LUMINANCE unit:2 resize:resize];
    glUseProgram(_planarProgram);
    return true;
}

- (void)drawFrame:(const tgcalls::VideoFrame &)frame fills:(bool)fills mirrored:(bool)mirrored
{
    if (![self prepareContext] || ![self prepareDrawable])
        return;
    CVOpenGLESTextureRef textures[2] = { NULL, NULL };
    bool bound = false;
    if (frame.buffer->type() == tgcalls::VideoFrameBufferType::Native)
        bound = [self bindNativeFrame:frame textures:textures];
    else
        bound = [self bindPlanarFrame:frame];
    if (bound)
    {
        const int rotation = ((frame.rotation % 360) + 360) % 360;
        const bool swapped = rotation == 90 || rotation == 270;
        const float displayWidth = (float)(swapped ? frame.buffer->height() : frame.buffer->width());
        const float displayHeight = (float)(swapped ? frame.buffer->width() : frame.buffer->height());
        const float scaleX = (float)_drawableWidth / displayWidth;
        const float scaleY = (float)_drawableHeight / displayHeight;
        const float scale = fills ? MAX(scaleX, scaleY) : MIN(scaleX, scaleY);
        const float extentX = displayWidth * scale / (float)_drawableWidth;
        const float extentY = displayHeight * scale / (float)_drawableHeight;
        const GLfloat positions[8] = { -extentX, -extentY, extentX, -extentY, -extentX, extentY, extentX, extentY };
        GLfloat texcoords[8];
        DisplayedTexcoords(rotation, mirrored, texcoords);
        glViewport(0, 0, _drawableWidth, _drawableHeight);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, positions);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, texcoords);
        glEnableVertexAttribArray(1);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        [_context presentRenderbuffer:GL_RENDERBUFFER];
        _lastFrame = frame;
        _hasLastFrame = true;
        [self notifyDisplayedSize:CGSizeMake(displayWidth, displayHeight)];
    }
    for (int i = 0; i < 2; i++)
    {
        if (textures[i] != NULL)
            CFRelease(textures[i]);
    }
    if (_textureCache != NULL)
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

- (void)notifyDisplayedSize:(CGSize)size
{
    const bool first = !_renderedFirstFrame;
    if (first)
        syslog(LOG_NOTICE, "IOS6MEDIA render.first view=%p video=%dx%d drawable=%dx%d error=%x", (__bridge void *)_view, (int)size.width, (int)size.height, _drawableWidth, _drawableHeight, glGetError());
    _renderedFirstFrame = true;
    const bool changed = !CGSizeEqualToSize(size, _lastVideoSize);
    _lastVideoSize = size;
    if (!first && !changed)
        return;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (changed && self.videoSizeChanged != nil)
            self.videoSizeChanged(size);
        if (first && self.firstFrameRendered != nil)
            self.firstFrameRendered();
    });
}

- (void)layoutWithBounds:(CGRect)__unused bounds scale:(CGFloat)__unused scale
{
    dispatch_async(_queue, ^
    {
        _drawableDirty = true;
        [self redrawLastFrame];
    });
}

- (void)setFillsBounds:(bool)fillsBounds mirrored:(bool)mirrored
{
    pthread_mutex_lock(&_mutex);
    _fillsBounds = fillsBounds;
    _mirrored = mirrored;
    pthread_mutex_unlock(&_mutex);
    dispatch_async(_queue, ^
    {
        [self redrawLastFrame];
    });
}

- (void)setPaused:(bool)paused
{
    pthread_mutex_lock(&_mutex);
    _paused = paused;
    pthread_mutex_unlock(&_mutex);
    if (paused)
    {
        dispatch_sync(_queue, ^
        {
            if (_context != nil && [EAGLContext setCurrentContext:_context])
                glFinish();
        });
    }
}

- (void)reset
{
    pthread_mutex_lock(&_mutex);
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    pthread_mutex_unlock(&_mutex);
    dispatch_async(_queue, ^
    {
        _lastFrame = tgcalls::VideoFrame();
        _hasLastFrame = false;
        _renderedFirstFrame = false;
        _lastVideoSize = CGSizeZero;
    });
}

- (void)invalidate
{
    pthread_mutex_lock(&_mutex);
    _invalidated = true;
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    pthread_mutex_unlock(&_mutex);
    EAGLContext *context = _context;
    CVOpenGLESTextureCacheRef textureCache = _textureCache;
    GLuint framebuffer = _framebuffer;
    GLuint renderbuffer = _renderbuffer;
    GLuint biPlanarProgram = _biPlanarProgram;
    GLuint planarProgram = _planarProgram;
    GLuint texture0 = _planarTextures[0];
    GLuint texture1 = _planarTextures[1];
    GLuint texture2 = _planarTextures[2];
    dispatch_async(_queue, ^
    {
        _lastFrame = tgcalls::VideoFrame();
        _hasLastFrame = false;
        if (context == nil || ![EAGLContext setCurrentContext:context])
            return;
        GLuint textures[3] = { texture0, texture1, texture2 };
        glDeleteTextures(3, textures);
        glDeleteFramebuffers(1, &framebuffer);
        glDeleteRenderbuffers(1, &renderbuffer);
        if (biPlanarProgram != 0)
            glDeleteProgram(biPlanarProgram);
        if (planarProgram != 0)
            glDeleteProgram(planarProgram);
        if (textureCache != NULL)
            CFRelease(textureCache);
        [EAGLContext setCurrentContext:nil];
    });
    _context = nil;
    _textureCache = NULL;
}

@end

#else

namespace {

struct ColorTables {
    int32_t y[256];
    int32_t rv[256];
    int32_t gu[256];
    int32_t gv[256];
    int32_t bu[256];
    uint8_t clip[1024];

    ColorTables() {
        for (int i = 0; i < 256; i++) {
            y[i] = 298 * (i - 16) + 128;
            rv[i] = 409 * (i - 128);
            gu[i] = -100 * (i - 128);
            gv[i] = -208 * (i - 128);
            bu[i] = 516 * (i - 128);
        }
        for (int i = 0; i < 1024; i++) {
            const int value = i - 384;
            clip[i] = (uint8_t)(value < 0 ? 0 : (value > 255 ? 255 : value));
        }
    }
};

const ColorTables &Tables() {
    static ColorTables *tables = new ColorTables();
    return *tables;
}

inline uint32_t Pixel(const uint8_t *clip, int32_t luma, int32_t red, int32_t green, int32_t blue) {
    const uint32_t r = clip[(luma + red) >> 8];
    const uint32_t g = clip[(luma + green) >> 8];
    const uint32_t b = clip[(luma + blue) >> 8];
    return 0xFF000000U | (r << 16) | (g << 8) | b;
}

void ConvertI420ToBGRA(const tgcalls::I420Buffer &buffer, uint32_t *target) {
    const ColorTables &t = Tables();
    const uint8_t *clip = t.clip + 384;
    const int width = buffer.width();
    const int height = buffer.height();
    for (int row = 0; row < height; row += 2) {
        const uint8_t *y0 = buffer.dataY() + (size_t)row * (size_t)buffer.strideY();
        const uint8_t *y1 = row + 1 < height ? y0 + buffer.strideY() : y0;
        const uint8_t *u = buffer.dataU() + (size_t)(row / 2) * (size_t)buffer.strideUV();
        const uint8_t *v = buffer.dataV() + (size_t)(row / 2) * (size_t)buffer.strideUV();
        uint32_t *out0 = target + (size_t)row * (size_t)width;
        uint32_t *out1 = row + 1 < height ? out0 + width : out0;
        for (int column = 0; column < width; column += 2) {
            const uint8_t cu = u[column / 2];
            const uint8_t cv = v[column / 2];
            const int32_t red = t.rv[cv];
            const int32_t green = t.gu[cu] + t.gv[cv];
            const int32_t blue = t.bu[cu];
            out0[column] = Pixel(clip, t.y[y0[column]], red, green, blue);
            out1[column] = Pixel(clip, t.y[y1[column]], red, green, blue);
            if (column + 1 < width) {
                out0[column + 1] = Pixel(clip, t.y[y0[column + 1]], red, green, blue);
                out1[column + 1] = Pixel(clip, t.y[y1[column + 1]], red, green, blue);
            }
        }
    }
}

void ReleaseBitmap(void *, const void *data, size_t) {
    free(const_cast<void *>(data));
}

}

@implementation TGCallVideoRenderer
{
    __unsafe_unretained UIView *_view;
    CALayer *_contentLayer;
    dispatch_queue_t _queue;
    pthread_mutex_t _mutex;
    tgcalls::VideoFrame _pending;
    bool _hasPending;
    bool _scheduled;
    bool _paused;
    bool _invalidated;
    bool _fillsBounds;
    bool _mirrored;
    bool _renderedFirstFrame;
    CGSize _lastVideoSize;
    int _rotation;
    bool _frameMirrored;
}

- (instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self != nil)
    {
        _view = view;
        _contentLayer = [[CALayer alloc] init];
        _contentLayer.contentsGravity = kCAGravityResizeAspectFill;
        [view.layer addSublayer:_contentLayer];
        view.layer.masksToBounds = true;
        _queue = dispatch_queue_create("org.onegram.call.video.render", DISPATCH_QUEUE_SERIAL);
        pthread_mutex_init(&_mutex, NULL);
        _fillsBounds = true;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
}

- (void)enqueueFrame:(const tgcalls::VideoFrame &)frame
{
    if (!frame.buffer || frame.buffer->type() != tgcalls::VideoFrameBufferType::I420)
        return;
    bool schedule = false;
    pthread_mutex_lock(&_mutex);
    if (!_invalidated)
    {
        _pending = frame;
        _hasPending = true;
        if (!_scheduled && !_paused)
        {
            _scheduled = true;
            schedule = true;
        }
    }
    pthread_mutex_unlock(&_mutex);
    if (schedule)
    {
        dispatch_async(_queue, ^
        {
            [self convertPending];
        });
    }
}

- (void)convertPending
{
    tgcalls::VideoFrame frame;
    pthread_mutex_lock(&_mutex);
    _scheduled = false;
    if (_invalidated || _paused || !_hasPending)
    {
        pthread_mutex_unlock(&_mutex);
        return;
    }
    frame = _pending;
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    pthread_mutex_unlock(&_mutex);

    const tgcalls::I420Buffer &buffer = *static_cast<const tgcalls::I420Buffer *>(frame.buffer.get());
    const int width = buffer.width();
    const int height = buffer.height();
    const size_t size = (size_t)width * (size_t)height * 4;
    uint32_t *pixels = (uint32_t *)malloc(size);
    if (pixels == NULL)
        return;
    ConvertI420ToBGRA(buffer, pixels);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, size, &ReleaseBitmap);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(width, height, 8, 32, (size_t)width * 4, colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (image == NULL)
        return;
    const int rotation = ((frame.rotation % 360) + 360) % 360;
    const bool swapped = rotation == 90 || rotation == 270;
    const CGSize displayed = CGSizeMake(swapped ? height : width, swapped ? width : height);
    const bool frameMirrored = frame.mirrored;
    id contents = (__bridge_transfer id)image;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_invalidated)
            return;
        [CATransaction begin];
        [CATransaction setDisableActions:true];
        _contentLayer.contents = contents;
        _rotation = rotation;
        _frameMirrored = frameMirrored;
        [self applyGeometry];
        [CATransaction commit];
        const bool first = !_renderedFirstFrame;
        _renderedFirstFrame = true;
        if (!CGSizeEqualToSize(displayed, _lastVideoSize))
        {
            _lastVideoSize = displayed;
            if (self.videoSizeChanged != nil)
                self.videoSizeChanged(displayed);
        }
        if (first && self.firstFrameRendered != nil)
            self.firstFrameRendered();
    });
}

- (void)applyGeometry
{
    const CGRect bounds = _view.bounds;
    const bool swapped = _rotation == 90 || _rotation == 270;
    _contentLayer.contentsGravity = _fillsBounds ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
    _contentLayer.bounds = CGRectMake(0.0f, 0.0f, swapped ? bounds.size.height : bounds.size.width, swapped ? bounds.size.width : bounds.size.height);
    _contentLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    CGAffineTransform transform = CGAffineTransformMakeRotation((CGFloat)(_rotation * M_PI / 180.0));
    if (_mirrored != _frameMirrored)
        transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
    _contentLayer.affineTransform = transform;
}

- (void)layoutWithBounds:(CGRect)__unused bounds scale:(CGFloat)__unused scale
{
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    [self applyGeometry];
    [CATransaction commit];
}

- (void)setFillsBounds:(bool)fillsBounds mirrored:(bool)mirrored
{
    _fillsBounds = fillsBounds;
    _mirrored = mirrored;
    [self applyGeometry];
}

- (void)setPaused:(bool)paused
{
    pthread_mutex_lock(&_mutex);
    _paused = paused;
    pthread_mutex_unlock(&_mutex);
}

- (void)reset
{
    pthread_mutex_lock(&_mutex);
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    pthread_mutex_unlock(&_mutex);
    _contentLayer.contents = nil;
    _renderedFirstFrame = false;
    _lastVideoSize = CGSizeZero;
}

- (void)invalidate
{
    pthread_mutex_lock(&_mutex);
    _invalidated = true;
    _pending = tgcalls::VideoFrame();
    _hasPending = false;
    pthread_mutex_unlock(&_mutex);
}

@end

#endif

@interface TGCallVideoView ()
{
    TGCallVideoRenderer *_renderer;
    std::shared_ptr<tgcalls::VideoFrameSink> _sink;
    id _resignObserver;
    id _activeObserver;
}
@end

@implementation TGCallVideoView

#if !defined(ONEGRAM_ARMV6)
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}
#endif

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor blackColor];
        self.opaque = true;
#if !defined(ONEGRAM_ARMV6)
        self.contentScaleFactor = [UIScreen mainScreen].scale;
#endif
        _fillsBounds = true;
        _renderer = [[TGCallVideoRenderer alloc] initWithView:self];
        _sink.reset(new TGCallVideoViewSink(_renderer));
        __weak TGCallVideoView *weakSelf = self;
        _renderer.firstFrameRendered = ^
        {
            __strong TGCallVideoView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.firstFrameRendered != nil)
                strongSelf.firstFrameRendered();
        };
        _renderer.videoSizeChanged = ^(CGSize size)
        {
            __strong TGCallVideoView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_videoSize = size;
            if (strongSelf.videoSizeChanged != nil)
                strongSelf.videoSizeChanged(size);
        };
        TGCallVideoRenderer *renderer = _renderer;
        _resignObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            [renderer setPaused:true];
        }];
        _activeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            [renderer setPaused:false];
        }];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_resignObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_activeObserver];
    [_renderer invalidate];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
#if !defined(ONEGRAM_ARMV6)
    [_renderer layoutWithBounds:self.bounds scale:self.contentScaleFactor];
#else
    [_renderer layoutWithBounds:self.bounds scale:1.0f];
#endif
}

- (void)setFillsBounds:(bool)fillsBounds
{
    _fillsBounds = fillsBounds;
    [_renderer setFillsBounds:_fillsBounds mirrored:_mirrored];
}

- (void)setMirrored:(bool)mirrored
{
    _mirrored = mirrored;
    [_renderer setFillsBounds:_fillsBounds mirrored:_mirrored];
}

- (void)resetFrames
{
    _videoSize = CGSizeZero;
    [_renderer reset];
}

- (std::shared_ptr<tgcalls::VideoFrameSink>)frameSink
{
    return _sink;
}

@end
