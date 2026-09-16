#import "TGAudioWaveformView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGPresentation.h"

@interface TGAudioWaveformContentView : UIView

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) TGAudioWaveform *waveform;
@property (nonatomic) CGFloat peakHeight;

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

        if (_waveform == nil) {
            for (int i = 0; i < numSamples; i++)
                heights[i] = 3.0f;
        } else {
            uint16_t *samples = (uint16_t *)_waveform.samples.bytes;
            int maxReadSamples = (int)_waveform.samples.length / 2;
            uint16_t maxSample = 1;
            for (int i = 0; i < maxReadSamples; i++) {
                if (maxSample < samples[i])
                    maxSample = samples[i];
            }
            CGFloat peaks[numSamples];
            memset(peaks, 0, sizeof(CGFloat) * numSamples);
            for (int i = 0; i < maxReadSamples; i++) {
                int index = MIN(numSamples - 1, i * numSamples / MAX(1, maxReadSamples));
                if (peaks[index] < samples[i])
                    peaks[index] = samples[i];
            }
            for (int i = 0; i < numSamples; i++) {
                CGFloat normalized = MIN(1.0f, peaks[i] / (CGFloat)maxSample);
                heights[i] = 3.0f + CGRound(normalized * 8.0f);
            }
        }

        UIColor *topColor = _color != nil ? _color : UIColorRGB(0xa3a3a3);
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 2.0f), 1.0f, UIColorRGBA(0x000000, 0.10f).CGColor);
        CGContextSetFillColorWithColor(context, topColor.CGColor);
        for (int i = 0; i < numSamples; i++) {
            CGFloat x = i * (sampleWidth + distance);
            CGFloat h = MIN(baseline, heights[i]);
            CGFloat y = baseline - h;
            CGFloat radius = sampleWidth / 2.0f;
            CGContextFillRect(context, CGRectMake(x, y + radius, sampleWidth, MAX(0.0f, h - sampleWidth)));
            CGContextFillEllipseInRect(context, CGRectMake(x, y, sampleWidth, sampleWidth));
            CGContextFillEllipseInRect(context, CGRectMake(x, baseline - sampleWidth, sampleWidth, sampleWidth));
        }
        CGContextRestoreGState(context);

        CGContextSaveGState(context);
        CGContextBeginPath(context);
        for (int i = 0; i < numSamples; i++) {
            CGFloat x = i * (sampleWidth + distance);
            CGFloat h = MIN(11.0f, heights[i]);
            CGFloat radius = sampleWidth / 2.0f;
            CGContextAddRect(context, CGRectMake(x, baseline, sampleWidth, MAX(0.0f, h - radius)));
            CGContextAddEllipseInRect(context, CGRectMake(x, baseline + MAX(0.0f, h - sampleWidth), sampleWidth, sampleWidth));
        }
        CGContextClip(context);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            0.443f, 0.443f, 0.443f, 1.0f,
            0.443f, 0.443f, 0.443f, 0.0f
        };
        CGFloat locations[] = {0.0f, 0.8278f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, baseline), CGPointMake(0.0f, MIN(size.height, baseline + 13.0f)), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
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
            //averageSample += ABS(samples[i]);
            if (maxSample < samples[i]) {
                maxSample = samples[i];
            }
        }
        //averageSample /= maxReadSamples;
        
        //CGFloat scale = averageSample * 1.9f;
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
