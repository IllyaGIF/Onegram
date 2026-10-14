#import "TGModernUnreadHeaderView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static UIImage *TGClassicIOS6UnreadHeaderBackgroundImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize size = CGSizeMake(2.0f, 25.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();

        NSArray *colors = @[(id)UIColorRGB(0xf8fafc).CGColor, (id)UIColorRGB(0xdce2e8).CGColor, (id)UIColorRGB(0xaeb8c2).CGColor];
        CGFloat locations[] = {0.0f, 0.48f, 1.0f};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        if (context != NULL)
        {
            CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0f, size.height), 0);
        }

        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);

        CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.9f).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, 1.0f));
        CGContextSetFillColorWithColor(context, UIColorRGB(0x7d8995).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, size.height - 1.0f, size.width, 1.0f));
        CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.35f).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, size.height - 2.0f, size.width, 1.0f));

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

static UIColor *TGClassicIOS6UnreadHeaderTextColor(void)
{
    return UIColorRGB(0x43576b);
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

    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    UIImage *backgroundImage = classicIOS6Style ? TGClassicIOS6UnreadHeaderBackgroundImage() : presentation.images.chatUnreadBackground;
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
    CGRect backgroundFrame = CGRectMake(0.0f, 3.0f, containerWidth, 25.0f);
    backgroundImageView.frame = CGRectOffset(backgroundFrame, position.x, position.y);
    [backgroundContainer addSubview:backgroundImageView];
    
    static UIFont *font = nil;
    static UIFont *classicFont = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = TGSystemFontOfSize(13.0f);
        classicFont = TGBoldSystemFontOfSize(13.0f);
    });
    
    NSString *text = TGLocalized(@"Conversation.UnreadMessages");
    UIFont *effectiveFont = classicIOS6Style ? classicFont : font;
    CGSize textSize = [text sizeWithFont:effectiveFont];
    
    CGContextSaveGState(context);
    if (classicIOS6Style)
        CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, UIColorRGBA(0xffffff, 0.9f).CGColor);
    CGContextSetFillColorWithColor(context, (classicIOS6Style ? TGClassicIOS6UnreadHeaderTextColor() : presentation.pallete.chatUnreadTextColor).CGColor);
    CGPoint textOrigin = CGPointMake(CGFloor((containerWidth - textSize.width) / 2) + 1, 7.0f + TGRetinaPixel);
    [text drawAtPoint:textOrigin withFont:effectiveFont];
    CGContextRestoreGState(context);
}

- (id)initWithFrame:(CGRect)frame presentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.viewIdentifier = @"_unread";
        
        bool classicIOS6Style = [TGPresentation classicIOS6Style];
        _backgroundView = [[UIImageView alloc] initWithImage:classicIOS6Style ? TGClassicIOS6UnreadHeaderBackgroundImage() : presentation.images.chatUnreadBackground];
        [self addSubview:_backgroundView];
        
        _labelView = [[UILabel alloc] init];
        _labelView.backgroundColor = [UIColor clearColor];
        _labelView.textColor = classicIOS6Style ? TGClassicIOS6UnreadHeaderTextColor() : presentation.pallete.chatUnreadTextColor;
        _labelView.font = classicIOS6Style ? TGBoldSystemFontOfSize(13.0f) : TGSystemFontOfSize(13.0f);
        _labelView.shadowColor = classicIOS6Style ? UIColorRGBA(0xffffff, 0.9f) : [UIColor clearColor];
        _labelView.shadowOffset = classicIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
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
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    _backgroundView.image = classicIOS6Style ? TGClassicIOS6UnreadHeaderBackgroundImage() : presentation.images.chatUnreadBackground;
    _labelView.textColor = classicIOS6Style ? TGClassicIOS6UnreadHeaderTextColor() : presentation.pallete.chatUnreadTextColor;
    _labelView.font = classicIOS6Style ? TGBoldSystemFontOfSize(13.0f) : TGSystemFontOfSize(13.0f);
    _labelView.shadowColor = classicIOS6Style ? UIColorRGBA(0xffffff, 0.9f) : [UIColor clearColor];
    _labelView.shadowOffset = classicIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
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
