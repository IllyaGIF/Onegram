#import "TGDocumentMessageIconView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGMessageImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMessageImageViewOverlayView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "TGPresentation.h"

@interface TGDocumentMessageIconView ()
{
    UILabel *_extensionLabel;
    
    TGModernButton *_buttonView;
    TGMessageImageViewOverlayView *_overlayView;
    UIImageView *_brandedMediaButtonView;
    
    CGFloat _progress;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGDocumentMessageIconView

static UIImage *TGBrandedMediaButtonImage(CGFloat diameter, bool paused)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0.5f, 0.5f, diameter - 1.0f, diameter - 1.0f);
    CGContextSaveGState(context);
    CGContextAddEllipseInRect(context, bounds);
    CGContextClip(context);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {
        0.67f, 0.86f, 1.0f, 1.0f,
        0.19f, 0.69f, 0.96f, 1.0f,
        0.03f, 0.58f, 0.89f, 1.0f
    };
    CGFloat locations[] = {0.0f, 0.48f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 3);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, diameter), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGContextAddEllipseInRect(context, CGRectMake(2.0f, 1.5f, diameter - 4.0f, diameter * 0.53f));
    CGContextClip(context);
    CGColorSpaceRef glossColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat glossComponents[] = {
        1.0f, 1.0f, 1.0f, 0.72f,
        1.0f, 1.0f, 1.0f, 0.10f
    };
    CGFloat glossLocations[] = {0.0f, 1.0f};
    CGGradientRef glossGradient = CGGradientCreateWithColorComponents(glossColorSpace, glossComponents, glossLocations, 2);
    CGContextDrawLinearGradient(context, glossGradient, CGPointMake(0.0f, 1.0f), CGPointMake(0.0f, diameter * 0.53f), 0);
    CGGradientRelease(glossGradient);
    CGColorSpaceRelease(glossColorSpace);
    CGContextRestoreGState(context);

    CGContextSetStrokeColorWithColor(context, UIColorRGBA(0x4d8db8, 0.70f).CGColor);
    CGContextSetLineWidth(context, 1.0f);
    CGContextStrokeEllipseInRect(context, bounds);

    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.5f, UIColorRGBA(0x000000, 0.25f).CGColor);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    if (!paused)
    {
        CGFloat glyphWidth = CGFloor(diameter * 0.30f);
        CGFloat glyphHeight = CGFloor(diameter * 0.40f);
        CGFloat x = CGFloor((diameter - glyphWidth) / 2.0f) + 1.0f;
        CGFloat y = CGFloor((diameter - glyphHeight) / 2.0f);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint(context, x + glyphWidth, y + glyphHeight / 2.0f);
        CGContextAddLineToPoint(context, x, y + glyphHeight);
        CGContextClosePath(context);
        CGContextFillPath(context);
    }
    else
    {
        CGFloat barWidth = MAX(3.0f, CGFloor(diameter * 0.11f));
        CGFloat barHeight = CGFloor(diameter * 0.38f);
        CGFloat gap = MAX(3.0f, CGFloor(diameter * 0.10f));
        CGFloat totalWidth = barWidth * 2.0f + gap;
        CGFloat x = CGFloor((diameter - totalWidth) / 2.0f);
        CGFloat y = CGFloor((diameter - barHeight) / 2.0f);
        CGContextFillRect(context, CGRectMake(x, y, barWidth, barHeight));
        CGContextFillRect(context, CGRectMake(x + barWidth + gap, y, barWidth, barHeight));
    }
    CGContextRestoreGState(context);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)updateBrandedMediaButton
{
    if (![TGPresentation brandedIOS6Style])
        return;

    if (_brandedMediaButtonView == nil)
    {
        _brandedMediaButtonView = [[UIImageView alloc] initWithFrame:_buttonView.frame];
        _brandedMediaButtonView.userInteractionEnabled = false;
        [self addSubview:_brandedMediaButtonView];
    }

    bool brandedMedia = _overlayType == TGMessageImageViewOverlayPlayMedia || _overlayType == TGMessageImageViewOverlayPauseMedia;
    _brandedMediaButtonView.hidden = !brandedMedia;
    _overlayView.hidden = brandedMedia;
    if (!brandedMedia)
        return;

    _brandedMediaButtonView.frame = _buttonView.frame;
    _brandedMediaButtonView.image = TGBrandedMediaButtonImage(MIN(_buttonView.bounds.size.width, _buttonView.bounds.size.height), _overlayType == TGMessageImageViewOverlayPauseMedia);
    [self bringSubviewToFront:_brandedMediaButtonView];
}

static UIImage *highlightImageForDiameter(CGFloat diameter) {
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [[NSMutableDictionary alloc] init];
    });
    UIImage *cachedImage = dict[@((int)diameter)];
    if (cachedImage != nil) {
        return cachedImage;
    } else {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.2f).CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        cachedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (cachedImage != nil) {
            dict[@((int)diameter)] = cachedImage;
        }
        return cachedImage;
    }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _extensionLabel = [[UILabel alloc] init];
        _extensionLabel.backgroundColor = [UIColor clearColor];
        _extensionLabel.opaque = false;
        _extensionLabel.textColor = TGAccentColor();
        _extensionLabel.font = TGSystemFontOfSize(19.0f);
        [self addSubview:_extensionLabel];
        
        _diameter = 44.0f;
        
        _buttonView = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _diameter, _diameter)];
        _buttonView.exclusiveTouch = true;
        _buttonView.modernHighlight = true;
        [_buttonView addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _overlayView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _diameter, _diameter)];
        [_overlayView setRadius:_diameter];
        _overlayView.userInteractionEnabled = false;
        [_buttonView addSubview:_overlayView];
        
        _buttonView.highlightImage = highlightImageForDiameter(_diameter);
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _overlayView.incomingColor = presentation.pallete.chatIncomingButtonColor;
    _overlayView.outgoingColor = [TGPresentation brandedIOS6Style] ? [UIColor whiteColor] : presentation.pallete.chatOutgoingButtonColor;
    _overlayView.incomingIconColor = presentation.pallete.chatIncomingButtonIconColor;
    _overlayView.outgoingIconColor = [TGPresentation brandedIOS6Style] ? UIColorRGB(0x609bd5) : presentation.pallete.chatOutgoingButtonIconColor;
    _extensionLabel.textColor = (!_incoming && [TGPresentation brandedIOS6Style]) ? [UIColor whiteColor] : TGAccentColor();
    [self updateBrandedMediaButton];
}

- (void)willBecomeRecycled
{
}

- (void)setDiameter:(CGFloat)diameter {
    if (ABS(_diameter - diameter) > FLT_EPSILON) {
        _diameter = diameter;
        [_overlayView setRadius:diameter];
        
        _buttonView.highlightImage = highlightImageForDiameter(_diameter);
        
        CGRect frame = self.frame;
        CGRect buttonFrame = _buttonView.frame;
        buttonFrame.size.width = diameter;
        buttonFrame.size.height = diameter;
        buttonFrame.origin = CGPointMake(CGFloor(frame.size.width - buttonFrame.size.width) / 2.0f, CGFloor(frame.size.height - buttonFrame.size.height) / 2.0f);
        if (!CGRectEqualToRect(_buttonView.frame, buttonFrame))
        {
            _buttonView.frame = buttonFrame;
        }
        [self updateBrandedMediaButton];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    _extensionLabel.frame = CGRectMake(CGFloor((frame.size.width - _extensionLabel.bounds.size.width) / 2.0f), CGFloor((frame.size.height - _extensionLabel.bounds.size.height) / 2.0f), _extensionLabel.bounds.size.width, _extensionLabel.bounds.size.height);
    
    CGRect buttonFrame = _buttonView.frame;
    buttonFrame.origin = CGPointMake(CGFloor(frame.size.width - buttonFrame.size.width) / 2.0f, CGFloor(frame.size.height - buttonFrame.size.height) / 2.0f);
    if (!CGRectEqualToRect(_buttonView.frame, buttonFrame))
    {
        _buttonView.frame = buttonFrame;
    }
    [self updateBrandedMediaButton];
}

- (void)setIncoming:(bool)incoming
{
    _incoming = incoming;
    _extensionLabel.textColor = (!incoming && [TGPresentation brandedIOS6Style]) ? [UIColor whiteColor] : TGAccentColor();
    
    [_overlayView setOverlayStyle:incoming ? TGMessageImageViewOverlayStyleIncoming : TGMessageImageViewOverlayStyleOutgoing];
}

- (void)setFileName:(NSString *)fileName
{
    if (!TGStringCompare(_fileName, fileName))
    {
        _fileName = fileName;
        
        _extensionLabel.text = [fileName pathExtension];
        CGSize labelSize = [_extensionLabel sizeThatFits:CGSizeMake(65.0f, 1000.0f)];
        _extensionLabel.frame = CGRectMake(CGFloor((self.frame.size.width - labelSize.width) / 2.0f), CGFloor((self.frame.size.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    }
}

- (void)setOverlayType:(int)overlayType
{
    [self setOverlayType:overlayType animated:false];
}

- (void)setOverlayType:(int)overlayType animated:(bool)animated
{
    if (_overlayType != overlayType)
    {
        _overlayType = overlayType;
        
        switch (_overlayType)
        {
            case TGMessageImageViewOverlayDownload:
            {
                if (_buttonView.superview == nil)
                {
                    [self addSubview:_buttonView];
                }
                
                _buttonView.alpha = 1.0f;
                _extensionLabel.alpha = 0.0f;
                
                [_overlayView setDownload];
                
                break;
            }
            case TGMessageImageViewOverlayPlay:
            {
                if (_buttonView.superview == nil)
                {
                    [self addSubview:_buttonView];
                }
                
                _buttonView.alpha = 1.0f;
                _extensionLabel.alpha = 0.0f;
                
                [_overlayView setPlay];
                
                break;
            }
            case TGMessageImageViewOverlayPlayMedia:
            {
                if (_buttonView.superview == nil)
                {
                    [self addSubview:_buttonView];
                }
                
                _buttonView.alpha = 1.0f;
                _extensionLabel.alpha = 0.0f;
                
                [_overlayView setPlayMedia];
                
                break;
            }
            case TGMessageImageViewOverlayPauseMedia:
            {
                if (_buttonView.superview == nil)
                {
                    [self addSubview:_buttonView];
                }
                
                _buttonView.alpha = 1.0f;
                _extensionLabel.alpha = 0.0f;
                
                [_overlayView setPauseMedia];
                
                break;
            }
            case TGMessageImageViewOverlayProgress:
            {
                if (_buttonView.superview == nil)
                {
                    [self addSubview:_buttonView];
                }
                
                _buttonView.alpha = 1.0f;
                _extensionLabel.alpha = 0.0f;
                
                [_overlayView setProgress:_progress animated:false];
                
                break;
            }
            case TGMessageImageViewOverlayNone:
            default:
            {
                if (_buttonView.superview != nil)
                {
                    if (animated)
                    {
                        [UIView animateWithDuration:0.2 animations:^
                         {
                             _buttonView.alpha = 0.0f;
                             _extensionLabel.alpha = 1.0f;
                         } completion:^(BOOL finished)
                         {
                             if (finished)
                             {
                                 [_buttonView removeFromSuperview];
                             }
                         }];
                    }
                    else
                    {
                        [_buttonView removeFromSuperview];
                        _extensionLabel.alpha = 1.0f;
                    }
                }
                
                break;
            }
        }
    }
    else if (_overlayType == TGMessageImageViewOverlayProgress)
    {
        [_overlayView setProgress:_progress animated:false];
    }
    [self updateBrandedMediaButton];
}

- (void)setProgress:(CGFloat)progress
{
    [self setProgress:progress animated:false];
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated
{
    if (ABS(_progress - progress) > FLT_EPSILON)
    {
        _progress = progress;
        
        if (_overlayType == TGMessageImageViewOverlayProgress)
            [_overlayView setProgress:progress animated:animated];
    }
}

- (void)actionButtonPressed
{
    TGMessageImageViewActionType action = TGMessageImageViewActionDownload;
    
    switch (_overlayType)
    {
        case TGMessageImageViewOverlayDownload:
        {
            action = TGMessageImageViewActionDownload;
            break;
        }
        case TGMessageImageViewOverlayProgress:
        {
            action = TGMessageImageViewActionCancelDownload;
            break;
        }
        case TGMessageImageViewOverlayPlay:
        case TGMessageImageViewOverlayPlayMedia:
        case TGMessageImageViewOverlayPauseMedia:
        {
            action = TGMessageImageViewActionPlay;
            break;
        }
        default:
            break;
    }
    
    id<TGMessageImageViewDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(messageImageViewActionButtonPressed:withAction:)])
        [delegate messageImageViewActionButtonPressed:(TGMessageImageView *)self withAction:action];
}

@end
