#import "TGFlatControls.h"

#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

static const CGFloat TGFlatSwitchWidth = 51.0f;
static const CGFloat TGFlatSwitchHeight = 31.0f;
static const CGFloat TGFlatSwitchThumbInset = 2.0f;
static const CGFloat TGFlatSwitchThumbSide = 27.0f;
static const CGFloat TGFlatSwitchPressedThumbWidth = 33.0f;
static const CGFloat TGFlatSwitchBorderWidth = 1.5f;
static const CGFloat TGFlatThumbShadowPadding = 4.0f;
static const NSTimeInterval TGFlatSwitchAnimationDuration = 0.25;

static UIImage *TGFlatThumbImage(CGFloat side)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    NSNumber *key = @((int)lroundf((float)side));
    UIImage *cached = cache[key];
    if (cached != nil)
        return cached;

    CGFloat padding = TGFlatThumbShadowPadding;
    CGSize size = CGSizeMake(side + padding * 2.0f, side + padding * 2.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect thumbRect = CGRectMake(padding, padding, side, side);

    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.5f), 3.0f, UIColorRGBA(0x000000, 0.28f).CGColor);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(context, thumbRect);
    CGContextRestoreGState(context);

    CGContextSetStrokeColorWithColor(context, UIColorRGBA(0x000000, 0.06f).CGColor);
    CGContextSetLineWidth(context, 0.5f);
    CGContextStrokeEllipseInRect(context, CGRectInset(thumbRect, 0.25f, 0.25f));

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    image = [image stretchableImageWithLeftCapWidth:(NSInteger)(padding + CGFloor(side / 2.0f)) topCapHeight:0];
    if (image != nil)
        cache[key] = image;
    return image;
}

static UIImage *TGFlatTrackImage(UIColor *color)
{
    CGFloat height = 2.0f;
    CGSize size = CGSizeMake(height * 2.0f + 1.0f, height);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, height, height));
    CGContextFillEllipseInRect(context, CGRectMake(size.width - height, 0.0f, height, height));
    CGContextFillRect(context, CGRectMake(height / 2.0f, 0.0f, size.width - height, height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image stretchableImageWithLeftCapWidth:(NSInteger)height topCapHeight:0];
}

bool TGFlatControlsEnabled(void)
{
    return iosMajorVersion() < 7 && TGCurrentInterfaceStyle() == 0;
}

UIControl<TGSwitchControl> *TGSwitchControlCreate(void)
{
    if (TGFlatControlsEnabled())
        return [[TGFlatSwitch alloc] init];
    return [[UISwitch alloc] init];
}

void TGFlatControlsApplySliderStyle(UISlider *slider, UIColor *accentColor, UIColor *trackColor)
{
    UIImage *thumbImage = TGFlatThumbImage(28.0f);
    [slider setThumbImage:thumbImage forState:UIControlStateNormal];
    [slider setThumbImage:thumbImage forState:UIControlStateHighlighted];
    [slider setMinimumTrackImage:TGFlatTrackImage(accentColor ?: UIColorRGB(0x007ee5)) forState:UIControlStateNormal];
    [slider setMaximumTrackImage:TGFlatTrackImage(trackColor ?: UIColorRGB(0xb7b7b7)) forState:UIControlStateNormal];
}

@implementation UISwitch (TGSwitchControl)

@dynamic on;

- (bool)setSwitchOnColor:(UIColor *)onColor offColor:(UIColor *)offColor
{
    return OGPlatformSetSwitchColors(self, onColor, offColor);
}

@end

@interface TGFlatSwitch ()
{
    CALayer *_trackLayer;
    UIImageView *_thumbView;
    UIColor *_onColor;
    UIColor *_offColor;
    bool _pressed;
    bool _dragging;
    bool _pendingOn;
    CGFloat _touchStartX;
}

@end

@implementation TGFlatSwitch

@synthesize on = _on;

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, TGFlatSwitchWidth, TGFlatSwitchHeight)];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.isAccessibilityElement = true;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _onColor = UIColorRGB(0x4cd964);
        _offColor = UIColorRGB(0xe5e5ea);

        _trackLayer = [[CALayer alloc] init];
        _trackLayer.frame = CGRectMake(0.0f, 0.0f, TGFlatSwitchWidth, TGFlatSwitchHeight);
        _trackLayer.cornerRadius = TGFlatSwitchHeight / 2.0f;
        _trackLayer.borderWidth = TGFlatSwitchBorderWidth;
        [self.layer addSublayer:_trackLayer];

        _thumbView = [[UIImageView alloc] initWithImage:TGFlatThumbImage(TGFlatSwitchThumbSide)];
        _thumbView.userInteractionEnabled = false;
        [self addSubview:_thumbView];

        [self updateAppearanceAnimated:false];
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:CGRectMake(frame.origin.x, frame.origin.y, TGFlatSwitchWidth, TGFlatSwitchHeight)];
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    return CGSizeMake(TGFlatSwitchWidth, TGFlatSwitchHeight);
}

- (void)setOn:(BOOL)on
{
    [self setOn:on animated:false];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated
{
    _on = on;
    [self updateAppearanceAnimated:animated];
}

- (bool)setSwitchOnColor:(UIColor *)onColor offColor:(UIColor *)offColor
{
    _onColor = onColor ?: UIColorRGB(0x4cd964);
    _offColor = offColor ?: UIColorRGB(0xe5e5ea);
    [self updateAppearanceAnimated:false];
    return true;
}

- (NSString *)accessibilityValue
{
    return _on ? @"1" : @"0";
}

- (bool)displaysOn
{
    return _dragging ? _pendingOn : _on;
}

- (CGRect)thumbFrame
{
    CGFloat width = _pressed ? TGFlatSwitchPressedThumbWidth : TGFlatSwitchThumbSide;
    CGFloat x = [self displaysOn] ? TGFlatSwitchWidth - TGFlatSwitchThumbInset - width : TGFlatSwitchThumbInset;
    return CGRectMake(x - TGFlatThumbShadowPadding, TGFlatSwitchThumbInset - TGFlatThumbShadowPadding, width + TGFlatThumbShadowPadding * 2.0f, TGFlatSwitchThumbSide + TGFlatThumbShadowPadding * 2.0f);
}

- (void)updateAppearanceAnimated:(bool)animated
{
    bool displaysOn = [self displaysOn];
    UIColor *borderColor = displaysOn ? _onColor : _offColor;
    UIColor *fillColor = displaysOn ? _onColor : (_pressed ? _offColor : [UIColor clearColor]);

    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    [CATransaction setAnimationDuration:TGFlatSwitchAnimationDuration];
    _trackLayer.borderColor = borderColor.CGColor;
    _trackLayer.backgroundColor = fillColor.CGColor;
    [CATransaction commit];

    CGRect thumbFrame = [self thumbFrame];
    if (animated)
    {
        [UIView animateWithDuration:TGFlatSwitchAnimationDuration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^
        {
            _thumbView.frame = thumbFrame;
        } completion:nil];
    }
    else
    {
        _thumbView.frame = thumbFrame;
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)__unused event
{
    _pressed = true;
    _dragging = false;
    _pendingOn = _on;
    _touchStartX = [touch locationInView:self].x;
    [self updateAppearanceAnimated:true];
    return true;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)__unused event
{
    CGFloat x = [touch locationInView:self].x;
    if (!_dragging && ABS(x - _touchStartX) > 6.0f)
        _dragging = true;
    if (_dragging)
    {
        bool pendingOn = x >= TGFlatSwitchWidth / 2.0f;
        if (pendingOn != _pendingOn)
        {
            _pendingOn = pendingOn;
            [self updateAppearanceAnimated:true];
        }
    }
    return true;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)__unused event
{
    bool inside = CGRectContainsPoint(CGRectInset(self.bounds, -24.0f, -24.0f), [touch locationInView:self]);
    bool newOn = _dragging ? _pendingOn : (inside ? !_on : _on);
    _pressed = false;
    _dragging = false;
    bool changed = newOn != (bool)_on;
    _on = newOn;
    [self updateAppearanceAnimated:true];
    if (changed)
        [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)cancelTrackingWithEvent:(UIEvent *)__unused event
{
    _pressed = false;
    _dragging = false;
    [self updateAppearanceAnimated:true];
}

@end
