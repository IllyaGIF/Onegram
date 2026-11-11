#import "TGTextMessageBackgroundViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGModernConversationViewContext.h"
#import "TGPresentation.h"

static UIColor *TGPluginBubbleColor(id value)
{
    if (![value isKindOfClass:[NSString class]] || [value length] != 7 || ![value hasPrefix:@"#"])
        return nil;
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[value substringFromIndex:1]];
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd)
        return nil;
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0f green:((rgb >> 8) & 255) / 255.0f blue:(rgb & 255) / 255.0f alpha:1];
}

static UIImage *TGPluginBubbleImage(UIImage *original, NSDictionary *style, bool classic)
{
    NSArray *values = [style[@"gradient"] isKindOfClass:[NSArray class]] ? style[@"gradient"] : nil;
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    for (id value in values)
    {
        UIColor *color = TGPluginBubbleColor(value);
        if (color != nil)
            [colors addObject:(id)color.CGColor];
    }
    UIColor *fill = TGPluginBubbleColor(style[@"color"]);
    if (colors.count < 2 && fill == nil)
        return original;
    UIGraphicsBeginImageContextWithOptions(original.size, false, original.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [original drawAtPoint:CGPointZero];
    CGContextSetBlendMode(context, kCGBlendModeSourceAtop);
    if (colors.count >= 2)
    {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
        CGFloat degrees = [style[@"angle"] respondsToSelector:@selector(doubleValue)] ? [style[@"angle"] doubleValue] : 90.0f;
        CGFloat radians = degrees * (CGFloat)M_PI / 180.0f;
        CGFloat radius = hypotf(original.size.width, original.size.height) * 0.5f;
        CGPoint center = CGPointMake(original.size.width * 0.5f, original.size.height * 0.5f);
        CGPoint direction = CGPointMake(cosf(radians) * radius, sinf(radians) * radius);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(center.x - direction.x, center.y - direction.y), CGPointMake(center.x + direction.x, center.y + direction.y), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
    }
    else
    {
        CGContextSetFillColorWithColor(context, fill.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, original.size.width, original.size.height));
    }
    if (classic)
    {
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        [original drawAtPoint:CGPointZero blendMode:kCGBlendModeNormal alpha:0.28f];
    }
    UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [output resizableImageWithCapInsets:original.capInsets];
}

static NSCache *TGPluginBubbleCache(void)
{
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^
    {
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = 4 * 1024 * 1024;
        cache.countLimit = 96;
    });
    return cache;
}

@interface TGTextMessageBackgroundViewModel ()
{
    TGModernViewContext *_context;
    TGTextMessageBackgroundType _type;
    bool _imageIsValid;
    
    bool _highlighted;
    UIView *_animatingHighligtedView;
    NSDictionary *_pluginBubbleStyle;
    NSString *_pluginBubblePendingKey;
    NSUInteger _pluginBubbleGeneration;
}

@end

@implementation TGTextMessageBackgroundViewModel

- (instancetype)initWithType:(TGTextMessageBackgroundType)type context:(TGModernViewContext *)context
{
    self = [super initWithImage:nil];
    if (self != nil)
    {
        _type = type;
        _context = context;
        _drawsBubble = true;
    }
    return self;
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    _highlighted = false;
    
    if (!_imageIsValid)
    {
        _imageIsValid = true;
        self.image = [self currentImage];
    }
    
    [super bindViewToContainer:container viewStorage:viewStorage];
}

- (void)setPartialMode:(bool)partialMode
{
    if (_partialMode != partialMode)
    {
        bool wasPartial = _partialMode;
        _partialMode = partialMode;
        _imageIsValid = false;
        
        if ([self boundView] != nil)
        {
            UIImageView *boundView = (UIImageView *)[self boundView];
            
            _imageIsValid = !_highlighted;
            UIImage *previousImage = self.image;
            UIImage *newImage = [self currentImage];
            self.image = newImage;
            
            if (previousImage != nil && iosMajorVersion() >= 7)
            {
                UIImageView *overlayImageView = [[UIImageView alloc] initWithFrame:boundView.bounds];
                
                if (!wasPartial)
                {
                    boundView.image = newImage;
                    overlayImageView.image = previousImage;
                }
                else
                {
                    boundView.image = previousImage;
                    overlayImageView.image = newImage;
                    overlayImageView.alpha = 0.0f;
                }
                
                [boundView addSubview:overlayImageView];
                
                [UIView animateWithDuration:0.3 * 0.7 animations:^
                {
                    overlayImageView.alpha = wasPartial ? 1.0f : 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    if (finished && wasPartial)
                        boundView.image = newImage;
                    [overlayImageView removeFromSuperview];
                }];
            }
            else
                [(UIImageView *)[self boundView] setImage:self.image];
        }
    }
}

- (UIImage *)currentImage
{
    if (!_drawsBubble)
        return nil;
    UIImage *newImage = (_voiceMessage && [TGPresentation brandedIOS6Style]) ? [TGPresentation brandedIOS6BubbleImageOutgoing:_type == TGTextMessageBackgroundOutgoing highlighted:_highlighted voice:true] : nil;
    if (newImage == nil && _type == TGTextMessageBackgroundIncoming)
    {
        if (_partialMode)
            newImage = _highlighted ? _context.presentation.images.chatBubbleIncomingPartialHighlightedImage : _context.presentation.images.chatBubbleIncomingPartialImage;
        else
            newImage = _highlighted ? _context.presentation.images.chatBubbleIncomingFullHighlightedImage : _context.presentation.images.chatBubbleIncomingFullImage;
    }
    else if (newImage == nil)
    {
        if (_partialMode)
            newImage = _highlighted ? _context.presentation.images.chatBubbleOutgoingPartialHighlightedImage : _context.presentation.images.chatBubbleOutgoingPartialImage;
        else
            newImage = _highlighted ? _context.presentation.images.chatBubbleOutgoingFullHighlightedImage : _context.presentation.images.chatBubbleOutgoingFullImage;
    }
    
    if (_pluginBubbleStyle == nil || newImage == nil)
        return newImage;
    NSString *key = [NSString stringWithFormat:@"%p:%d:%@", newImage.CGImage, [TGPresentation classicThemeStyle], _pluginBubbleStyle];
    UIImage *cached = [TGPluginBubbleCache() objectForKey:key];
    if (cached != nil)
        return cached;
    if (![_pluginBubblePendingKey isEqualToString:key])
    {
        _pluginBubblePendingKey = key;
        NSUInteger generation = _pluginBubbleGeneration;
        NSDictionary *style = _pluginBubbleStyle;
        bool classic = [TGPresentation classicThemeStyle];
        __weak TGTextMessageBackgroundViewModel *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            UIImage *rendered = TGPluginBubbleImage(newImage, style, classic);
            if (rendered != nil)
                [TGPluginBubbleCache() setObject:rendered forKey:key cost:(NSUInteger)(rendered.size.width * rendered.size.height * rendered.scale * rendered.scale * 4)];
            dispatch_async(dispatch_get_main_queue(), ^
            {
                TGTextMessageBackgroundViewModel *strongSelf = weakSelf;
                if (strongSelf == nil || strongSelf->_pluginBubbleGeneration != generation || ![strongSelf->_pluginBubblePendingKey isEqualToString:key])
                    return;
                strongSelf->_pluginBubblePendingKey = nil;
                strongSelf->_imageIsValid = true;
                strongSelf.image = rendered;
                [(UIImageView *)strongSelf.boundView setImage:rendered];
            });
        });
    }
    return newImage;
}

- (void)setPluginBubbleStyle:(NSDictionary *)style
{
    if ((_pluginBubbleStyle == style) || [_pluginBubbleStyle isEqualToDictionary:style])
        return;
    _pluginBubbleStyle = [style copy];
    _pluginBubbleGeneration++;
    _pluginBubblePendingKey = nil;
    _imageIsValid = true;
    self.image = [self currentImage];
    [(UIImageView *)self.boundView setImage:self.image];
}

- (void)setDrawsBubble:(bool)drawsBubble
{
    if (_drawsBubble != drawsBubble)
    {
        _drawsBubble = drawsBubble;
        [_animatingHighligtedView removeFromSuperview];
        _animatingHighligtedView = nil;
        self.image = [self currentImage];
        _imageIsValid = true;
        ((UIImageView *)self.boundView).image = self.image;
    }
}

- (void)setVoiceMessage:(bool)voiceMessage
{
    if (_voiceMessage != voiceMessage)
    {
        _voiceMessage = voiceMessage;
        _imageIsValid = false;
        if (self.boundView != nil)
        {
            self.image = [self currentImage];
            _imageIsValid = true;
            ((UIImageView *)self.boundView).image = self.image;
        }
    }
}

- (void)setHighlightedIfBound
{
    if ([self boundView] != nil && !_highlighted)
    {
        _highlighted = true;
        
        _imageIsValid = false;
        
        self.image = [self currentImage];
        ((UIImageView *)[self boundView]).image = self.image;
    }
}

- (void)addScaleAnimationToLayer:(CALayer *)layer from:(CGSize)fromScale to:(CGSize)toScale duration:(NSTimeInterval)duration
{;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(fromScale.width, fromScale.height, 1.0f)];
    animation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(toScale.width, toScale.height, 1.0f)];
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.removedOnCompletion = true;
    animation.fillMode = kCAFillModeForwards;
    [layer addAnimation:animation forKey:@"transform"];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    _animatingHighligtedView.frame = frame;
}

- (void)clearHighlight
{
    if (_highlighted)
    {
        _highlighted = false;
        
        if ([self boundView] != nil)
        {
            UIImage *previousImage = self.image;
            
            UIImage *newImage = [self currentImage];
            self.image = newImage;
            _imageIsValid = true;
            
            ((UIImageView *)[self boundView]).image = self.image;
            
            if (previousImage != nil && iosMajorVersion() >= 7)
            {
                [_animatingHighligtedView removeFromSuperview];
                
                UIImageView *overlayImageView = [[UIImageView alloc] initWithFrame:[self boundView].frame];
                overlayImageView.image = previousImage;
                _animatingHighligtedView = overlayImageView;
                
                [[self boundView].superview insertSubview:overlayImageView aboveSubview:[self boundView]];
                
                CGSize frameSize = [self boundView].frame.size;
                [self addScaleAnimationToLayer:[self boundView].layer from:CGSizeMake((frameSize.width - 2.0f) / frameSize.width, (frameSize.height - 2.0f) / frameSize.height) to:CGSizeMake(1.0f, 1.0f) duration:0.2];
                
                __weak TGTextMessageBackgroundViewModel *weakSelf = self;
                [UIView animateWithDuration:0.4 animations:^
                {
                    overlayImageView.alpha = 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    [overlayImageView removeFromSuperview];
                    __strong TGTextMessageBackgroundViewModel *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        if (strongSelf->_animatingHighligtedView == overlayImageView)
                            strongSelf->_animatingHighligtedView = nil;
                    }
                }];
            }
        }
    }
}

@end
