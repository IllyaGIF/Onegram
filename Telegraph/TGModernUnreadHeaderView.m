#import "TGModernUnreadHeaderView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static UIImage *OGCompatUnreadHeaderGlossImage(void)
{
    static UIImage *glossImage = nil;
    static dispatch_once_t glossToken;
    dispatch_once(&glossToken, ^
    {
        const CGFloat width = 2.0f;
        const CGFloat height = 25.0f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), false, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        if (ctx != NULL)
        {
            CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
            NSArray *stops = @[(id)UIColorRGB(0xf8fafc).CGColor, (id)UIColorRGB(0xdce2e8).CGColor, (id)UIColorRGB(0xaeb8c2).CGColor];
            const CGFloat positions[3] = {0.0f, 0.48f, 1.0f};
            CGGradientRef ramp = CGGradientCreateWithColors(rgb, (__bridge CFArrayRef)stops, positions);
            CGContextDrawLinearGradient(ctx, ramp, CGPointZero, CGPointMake(0.0f, height), 0);
            CGGradientRelease(ramp);
            CGColorSpaceRelease(rgb);
        }

        struct { CGFloat y; int rgb; CGFloat alpha; } lines[] = {
            { 0.0f, 0xffffff, 0.9f },
            { height - 1.0f, 0x7d8995, 1.0f },
            { height - 2.0f, 0xffffff, 0.35f }
        };
        for (size_t i = 0; i < sizeof(lines) / sizeof(lines[0]); i++)
        {
            CGContextSetFillColorWithColor(ctx, UIColorRGBA(lines[i].rgb, lines[i].alpha).CGColor);
            CGContextFillRect(ctx, CGRectMake(0.0f, lines[i].y, width, 1.0f));
        }

        glossImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return glossImage;
}

static void OGCompatUnreadHeaderStyleViews(UIImageView *backgroundView, UILabel *label, TGPresentation *presentation)
{
    if ([TGPresentation classicThemeStyle])
    {
        backgroundView.image = OGCompatUnreadHeaderGlossImage();
        label.textColor = UIColorRGB(0x43576b);
        label.font = TGBoldSystemFontOfSize(13.0f);
        label.shadowColor = UIColorRGBA(0xffffff, 0.9f);
        label.shadowOffset = CGSizeMake(0.0f, 1.0f);
    }
    else
    {
        backgroundView.image = presentation.images.chatUnreadBackground;
        label.textColor = presentation.pallete.chatUnreadTextColor;
        label.font = TGSystemFontOfSize(13.0f);
        label.shadowColor = [UIColor clearColor];
        label.shadowOffset = CGSizeZero;
    }
}

static OGConversationAppearance *TGBrandedUnreadHeaderAppearance(void)
{
    if (![TGPresentation brandedIOS6Style])
        return nil;
    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    return appearance.unreadHeaderSurfaceStyle != nil ? appearance : nil;
}

static CGRect TGBrandedUnreadHeaderBackgroundFrame(OGConversationAppearance *appearance, CGSize containerSize)
{
    CGFloat inset = appearance.backgroundCardHorizontalInset;
    return CGRectMake(inset, (containerSize.height - appearance.unreadHeaderHeight) / 2.0f, MAX(0.0f, containerSize.width - inset * 2.0f), appearance.unreadHeaderHeight);
}

static CGFloat TGBrandedUnreadHeaderTextY(OGConversationAppearance *appearance, CGSize containerSize, CGFloat textHeight)
{
    CGRect backgroundFrame = TGBrandedUnreadHeaderBackgroundFrame(appearance, containerSize);
    return CGFloor(backgroundFrame.origin.y + (backgroundFrame.size.height - textHeight) / 2.0f + appearance.unreadHeaderTextVerticalOffset);
}

@interface TGModernUnreadHeaderView ()
{
    UIImageView *_backgroundView;
    UILabel *_labelView;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGModernUnreadHeaderView

+ (void)drawHeaderForContainerWidth:(CGFloat)containerWidth inContext:(CGContextRef)context andBindBackgroundToContainer:(UIView *)backgroundContainer atPosition:(CGPoint)position presentation:(TGPresentation *)presentation
{
    OGConversationAppearance *brandedAppearance = TGBrandedUnreadHeaderAppearance();
    if (brandedAppearance != nil)
    {
        CGSize brandedContainerSize = CGSizeMake(containerWidth, 31.0f);
        CGRect brandedBackgroundFrame = TGBrandedUnreadHeaderBackgroundFrame(brandedAppearance, brandedContainerSize);
        UIImageView *brandedBackgroundView = [[UIImageView alloc] initWithImage:[TGPresentation brandedIOS6UnreadHeaderImageForWidth:brandedBackgroundFrame.size.width]];
        brandedBackgroundView.frame = CGRectOffset(brandedBackgroundFrame, position.x, position.y);
        [backgroundContainer addSubview:brandedBackgroundView];

        NSString *brandedText = TGLocalized(@"Conversation.UnreadMessages");
        CGSize brandedTextSize = [brandedText sizeWithFont:brandedAppearance.unreadHeaderFont];
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, brandedAppearance.unreadHeaderTextShadowOffset, 0.5f, brandedAppearance.unreadHeaderTextShadowColor.CGColor);
        CGContextSetFillColorWithColor(context, brandedAppearance.unreadHeaderTextColor.CGColor);
        [brandedText drawAtPoint:CGPointMake(CGFloor((containerWidth - brandedTextSize.width) / 2.0f), TGBrandedUnreadHeaderTextY(brandedAppearance, brandedContainerSize, brandedTextSize.height)) withFont:brandedAppearance.unreadHeaderFont];
        CGContextRestoreGState(context);
        return;
    }

    bool glossy = [TGPresentation classicThemeStyle];
    UIImageView *stripView = [[UIImageView alloc] initWithImage:glossy ? OGCompatUnreadHeaderGlossImage() : presentation.images.chatUnreadBackground];
    stripView.frame = CGRectOffset(CGRectMake(0.0f, 3.0f, containerWidth, 25.0f), position.x, position.y);
    [backgroundContainer addSubview:stripView];

    NSString *text = TGLocalized(@"Conversation.UnreadMessages");
    UIFont *textFont = glossy ? TGBoldSystemFontOfSize(13.0f) : TGSystemFontOfSize(13.0f);
    UIColor *textColor = glossy ? UIColorRGB(0x43576b) : presentation.pallete.chatUnreadTextColor;
    CGSize textSize = [text sizeWithFont:textFont];

    CGContextSaveGState(context);
    if (glossy)
        CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, UIColorRGBA(0xffffff, 0.9f).CGColor);
    CGContextSetFillColorWithColor(context, textColor.CGColor);
    [text drawAtPoint:CGPointMake(CGFloor((containerWidth - textSize.width) / 2) + 1, 7.0f + TGRetinaPixel) withFont:textFont];
    CGContextRestoreGState(context);
}

- (id)initWithFrame:(CGRect)frame presentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.viewIdentifier = @"_unread";
        
        _backgroundView = [[UIImageView alloc] init];
        [self addSubview:_backgroundView];
        
        _labelView = [[UILabel alloc] init];
        _labelView.backgroundColor = [UIColor clearColor];
        OGCompatUnreadHeaderStyleViews(_backgroundView, _labelView, presentation);
        _labelView.text = TGLocalized(@"Conversation.UnreadMessages");
        _labelView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
        [_labelView sizeToFit];
        [self addSubview:_labelView];

        [self applyBrandedStyle];
    }
    return self;
}

- (void)applyBrandedStyle
{
    OGConversationAppearance *appearance = TGBrandedUnreadHeaderAppearance();
    if (appearance == nil)
        return;
    _backgroundView.image = nil;
    _labelView.textColor = appearance.unreadHeaderTextColor;
    _labelView.font = appearance.unreadHeaderFont;
    _labelView.shadowColor = appearance.unreadHeaderTextShadowColor;
    _labelView.shadowOffset = appearance.unreadHeaderTextShadowOffset;
    [_labelView sizeToFit];
    [self setNeedsLayout];
}
- (void)setPresentation:(TGPresentation *)presentation
{
    OGCompatUnreadHeaderStyleViews(_backgroundView, _labelView, presentation);
    [_labelView sizeToFit];
    [self applyBrandedStyle];
}

- (void)willBecomeRecycled
{
}

- (void)updateAssets
{
}

- (void)layoutSubviews
{
    OGConversationAppearance *brandedAppearance = TGBrandedUnreadHeaderAppearance();
    if (brandedAppearance != nil)
    {
        CGRect backgroundFrame = TGBrandedUnreadHeaderBackgroundFrame(brandedAppearance, self.frame.size);
        if (_backgroundView.image == nil || ABS(_backgroundView.image.size.width - backgroundFrame.size.width) > FLT_EPSILON)
            _backgroundView.image = [TGPresentation brandedIOS6UnreadHeaderImageForWidth:backgroundFrame.size.width];
        _backgroundView.frame = backgroundFrame;
        CGRect brandedLabelFrame = _labelView.frame;
        brandedLabelFrame.origin = CGPointMake(CGFloor((self.frame.size.width - brandedLabelFrame.size.width) / 2.0f), self.frame.size.height - TGBrandedUnreadHeaderTextY(brandedAppearance, self.frame.size, brandedLabelFrame.size.height) - brandedLabelFrame.size.height);
        _labelView.frame = brandedLabelFrame;
        return;
    }

    _backgroundView.frame = CGRectMake(0.0f, 3.0f, self.frame.size.width, 25.0f);
    CGRect labelFrame = _labelView.frame;
    labelFrame.origin = CGPointMake(CGFloor((self.frame.size.width - labelFrame.size.width) / 2.0f), 7.0f + TGRetinaPixel);
    _labelView.frame = labelFrame;
}

@end
