#import "TGAudioWaveformView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSurfaceRenderer.h"
#import "../OnegramUI/Core/OGSurfaceStyle.h"
#import "../OnegramPlatform/OGPlatformVersion.h"

static CGFloat TGVoiceWaveformSampleHeight(const uint16_t *samples, NSUInteger sampleCount, NSUInteger barIndex, NSUInteger barCount, CGFloat peak)
{
    if (samples == NULL || sampleCount == 0 || barCount == 0)
        return 3.0f;

    CGFloat start = (CGFloat)barIndex * sampleCount / barCount;
    CGFloat end = (CGFloat)(barIndex + 1) * sampleCount / barCount;
    CGFloat sum = 0.0f;
    for (NSUInteger index = (NSUInteger)CGFloor(start); index < sampleCount && index < (NSUInteger)ceil(end); index++)
    {
        CGFloat weight = MIN(end, (CGFloat)index + 1.0f) - MAX(start, (CGFloat)index);
        sum += samples[index] * MAX(0.0f, weight);
    }
    CGFloat normalized = MAX(0.0f, MIN(1.0f, sum / (end - start) / MAX(1.0f, peak)));
    return CGFloor((3.0f + normalized * 8.0f) * 2.0f + 0.5f) / 2.0f;
}

static const CGFloat TGAudioWaveformBarShadowPadding = 3.0f;

static UIImage *TGAudioWaveformShadowedBarImage(OGTheme *theme, OGSurfaceStyle *style, CGSize barSize)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 128;
    });

    CGFloat scale = OGPlatformScreenScale();
    NSString *key = [[NSString alloc] initWithFormat:@"%@|%.2f|%.2f|%.1f", [style renderIdentity], barSize.width, barSize.height, scale];
    UIImage *image = [cache objectForKey:key];
    if (image != nil)
        return image;

    UIImage *barImage = [theme.surfaceRenderer imageWithStyle:style size:barSize bodyFrame:CGRectMake(0.0f, 0.0f, barSize.width, barSize.height)];
    if (barImage == nil)
        return nil;

    CGFloat padding = TGAudioWaveformBarShadowPadding;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(barImage.size.width + padding * 2.0f, barImage.size.height + padding * 2.0f), false, scale);
    CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), CGSizeMake(0.0f, 2.0f), 1.0f, UIColorRGBA(0x000000, 0.10f).CGColor);
    [barImage drawAtPoint:CGPointMake(padding, padding)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image != nil)
        [cache setObject:image forKey:key];
    return image;
}

@interface TGAudioWaveformContentView : UIView

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) TGAudioWaveform *waveform;
@property (nonatomic) CGFloat peakHeight;
@property (nonatomic) BOOL foreground;

@end

@implementation TGAudioWaveformContentView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [self setNeedsDisplay];
}

- (void)setWaveform:(TGAudioWaveform *)waveform {
    if (TGObjectCompare(_waveform, waveform)) {
        return;
    }
    
    _waveform = waveform;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect {
    if ([TGPresentation brandedIOS6Style]) {
        CGSize size = self.bounds.size;
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGFloat sampleWidth = 3.0f;
        CGFloat distance = 1.0f;
        CGFloat baseline = MIN(11.0f, size.height);
        int numSamples = MAX(1, (int)CGFloor((size.width + distance) / (sampleWidth + distance)));
        CGFloat heights[numSamples];
        memset(heights, 0, sizeof(CGFloat) * numSamples);

        const uint16_t *samples = (const uint16_t *)_waveform.samples.bytes;
        NSUInteger sampleCount = _waveform.samples.length / sizeof(uint16_t);
        for (int i = 0; i < numSamples; i++)
            heights[i] = TGVoiceWaveformSampleHeight(samples, sampleCount, (NSUInteger)i, (NSUInteger)numSamples, _waveform.peak);

        OGTheme *theme = [OGTheme brandedTheme];
        OGConversationAppearance *appearance = theme.conversationAppearance;
        OGSurfaceStyle *barStyle = _foreground ? appearance.voiceWaveformPlayedBarSurfaceStyle : appearance.voiceWaveformBarSurfaceStyle;
        for (int i = 0; i < numSamples; i++) {
            CGFloat x = i * (sampleWidth + distance);
            CGFloat h = MIN(baseline, heights[i]);
            CGFloat y = baseline - h;
            UIImage *barImage = TGAudioWaveformShadowedBarImage(theme, barStyle, CGSizeMake(sampleWidth, h));
            [barImage drawAtPoint:CGPointMake(x - TGAudioWaveformBarShadowPadding, y - TGAudioWaveformBarShadowPadding)];
        }

        OGSurfaceStyle *reflectionStyle = appearance.voiceWaveformPlayedBarSurfaceStyle;
        CGContextSaveGState(context);
        CGContextBeginTransparencyLayer(context, NULL);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 0.0f, baseline * 2.0f);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        for (int i = 0; i < numSamples; i++) {
            CGFloat x = i * (sampleWidth + distance);
            CGFloat h = MIN(baseline, heights[i]);
            CGSize barSize = CGSizeMake(sampleWidth, h);
            UIImage *barImage = [theme.surfaceRenderer imageWithStyle:reflectionStyle size:barSize bodyFrame:CGRectMake(0.0f, 0.0f, barSize.width, barSize.height)];
            [barImage drawAtPoint:CGPointMake(x, baseline - h)];
        }
        CGContextRestoreGState(context);
        CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            1.0f, 1.0f, 1.0f, 1.0f,
            1.0f, 1.0f, 1.0f, 0.0f
        };
        CGFloat locations[] = {0.0f, 0.8278f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, baseline), CGPointMake(0.0f, MIN(size.height, baseline + 13.0f)), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        CGContextEndTransparencyLayer(context);
        CGContextRestoreGState(context);
        return;
    }

    CGFloat sampleWidth = 2.0f;
    CGFloat halfSampleWidth = 1.0f;
    CGFloat distance = 1.0f;
    
    CGSize size = self.bounds.size;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, _color.CGColor);
    
    if (_waveform == nil) {
        CGContextFillRect(context, CGRectMake(halfSampleWidth, size.height - sampleWidth, size.width - sampleWidth, sampleWidth));
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, size.height - sampleWidth, sampleWidth, sampleWidth));
        CGContextFillEllipseInRect(context, CGRectMake(size.width - sampleWidth, size.height - sampleWidth, sampleWidth, sampleWidth));
    } else {
        
        uint16_t *samples = (uint16_t *)_waveform.samples.bytes;
        int maxReadSamples = (int)_waveform.samples.length / 2;
        
        uint16_t maxSample = 0;
        for (int i = 0; i < maxReadSamples; i++) {
            if (maxSample < samples[i]) {
                maxSample = samples[i];
            }
        }
        
        CGFloat scale = maxSample;
        if (scale < 1.0f) {
            scale = 1.0f;
        }
        int numSamples = (int)CGFloor(self.frame.size.width / (sampleWidth + distance));
        
        int16_t adjustedSamples[numSamples];
        memset(adjustedSamples, 0, numSamples * 2);
        for (int i = 0; i < maxReadSamples; i++) {
            int index = i * numSamples / maxReadSamples;
            int16_t sample = samples[i];
            if (sample < 0) {
                sample = -sample;
            }
            
            if (adjustedSamples[index] < sample) {
                adjustedSamples[index] = sample;
            }
        }
        
        for (int i = 0; i < numSamples; i++) {
            CGFloat offset = i * (sampleWidth + distance);
            
            int16_t peakSample = adjustedSamples[i];
            
            CGFloat sampleHeight = peakSample * _peakHeight / scale;
            if (ABS(sampleHeight) > _peakHeight) {
                if (sampleHeight < 0) {
                    sampleHeight = _peakHeight;
                } else {
                    sampleHeight = _peakHeight;
                }
            }
            
            CGFloat adjustedSampleHeight = sampleHeight - sampleWidth;
            if (adjustedSampleHeight <= sampleWidth + FLT_EPSILON) {
                CGContextFillEllipseInRect(context, CGRectMake(offset, size.height - sampleWidth, sampleWidth, sampleWidth));
                CGContextFillRect(context, CGRectMake(offset, size.height - halfSampleWidth, sampleWidth, halfSampleWidth));
            } else {
                CGRect adjustedRect = CGRectMake(offset, size.height - adjustedSampleHeight, sampleWidth, adjustedSampleHeight);
                CGContextFillRect(context, adjustedRect);
                CGContextFillEllipseInRect(context, CGRectMake(adjustedRect.origin.x, adjustedRect.origin.y - halfSampleWidth, sampleWidth, sampleWidth));
                CGContextFillEllipseInRect(context, CGRectMake(adjustedRect.origin.x, adjustedRect.origin.y + adjustedRect.size.height - halfSampleWidth, sampleWidth, sampleWidth));
            }
        }
    }

}

@end

@interface TGAudioWaveformView () {
    TGAudioWaveformContentView *_backgroundView;
    UIView *_foregroundClippingView;
    TGAudioWaveformContentView *_foregroundView;
}

@end

@implementation TGAudioWaveformView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _backgroundView = [[TGAudioWaveformContentView alloc] initWithFrame:self.bounds];
        _foregroundView = [[TGAudioWaveformContentView alloc] initWithFrame:self.bounds];
        _foregroundView.foreground = YES;
        _foregroundClippingView = [[UIView alloc] initWithFrame:self.bounds];
        _foregroundClippingView.clipsToBounds = true;
        [self addSubview:_backgroundView];
        [_foregroundClippingView addSubview:_foregroundView];
        [self addSubview:_foregroundClippingView];
        _peakHeight = 12.0f;
        _backgroundView.peakHeight = _peakHeight;
        _foregroundView.peakHeight = _peakHeight;
    }
    return self;
}

- (void)setPeakHeight:(CGFloat)peakHeight {
    _peakHeight = peakHeight;
    _backgroundView.peakHeight = _peakHeight;
    _foregroundView.peakHeight = _peakHeight;
}

- (UIView *)backgroundView {
    return _backgroundView;
}

- (UIView *)foregroundView {
    return _foregroundView;
}

- (UIView *)foregroundClippingView {
    return _foregroundClippingView;
}

- (void)setForegroundColor:(UIColor *)foregroundColor backgroundColor:(UIColor *)backgroundColor {
    _foregroundView.color = foregroundColor;
    _backgroundView.color = backgroundColor;
}

- (void)setWaveform:(TGAudioWaveform *)waveform {
    [_backgroundView setWaveform:waveform];
    [_foregroundView setWaveform:waveform];
}

- (void)layoutSubviews {
}

@end
