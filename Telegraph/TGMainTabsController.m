#import "TGMainTabsController.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <QuartzCore/QuartzCore.h>

#import "TGAppDelegate.h"
#import "TGCommon.h"
#import "TGDebugController.h"

#import "TGPresentation.h"

#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGTabBarAppearance.h"
#import "../OnegramUI/Core/OGSurfaceStyle.h"
#import "../OnegramUI/Core/OGSurfaceRenderer.h"
#import "../OnegramUI/Core/OGAssets.h"

static NSString *const TGMainTabsContactsIconName = @"tabbar-contacts";
static NSString *const TGMainTabsCallsIconName = @"tabbar-calls";
static NSString *const TGMainTabsChatsIconName = @"tabbar-chats";
static NSString *const TGMainTabsSettingsIconName = @"tabbar-settings";

static UIImage *TGMainTabsBrandedIOS6Icon(NSString *name, UIImage *fallbackTemplate, bool selected)
{
    OGTheme *theme = [OGTheme brandedTheme];
    UIImage *iconTemplate = [theme.assets imageNamed:name inDirectory:@"ios6style"];
    if (iconTemplate == nil)
        iconTemplate = fallbackTemplate;
    if (iconTemplate == nil)
        return nil;

    OGTabBarAppearance *appearance = theme.tabBarAppearance;
    NSArray *colors = selected ? appearance.selectedIconGradientColors : appearance.iconGradientColors;
    NSArray *locations = selected ? appearance.selectedIconGradientLocations : appearance.iconGradientLocations;
    NSArray *shadows = selected ? appearance.selectedIconShadows : appearance.iconShadows;
    return [theme.surfaceRenderer iconImageWithTemplate:iconTemplate gradientColors:colors locations:locations shadows:shadows outsets:[appearance iconOutsets]];
}

static void TGMainTabsApplyTabLabelStyle(UILabel *label, TGPresentation *presentation)
{
    if ([TGPresentation brandedIOS6Style])
    {
        OGTabBarAppearance *appearance = [OGTheme brandedTheme].tabBarAppearance;
        label.textColor = appearance.titleColor;
        label.highlightedTextColor = appearance.titleColor;
        if (OGPlatformLayerSupportsShadow(label.layer))
        {
            label.shadowColor = [UIColor clearColor];
            label.shadowOffset = CGSizeZero;
            OGPlatformSetLayerShadow(label.layer, appearance.titleShadowColor, 1.0f, appearance.titleShadowRadius, appearance.titleShadowOffset);
        }
        else
        {
            label.shadowColor = appearance.titleShadowColor;
            label.shadowOffset = appearance.titleShadowOffset;
        }
        return;
    }

    OGPlatformSetLayerShadow(label.layer, nil, 0.0f, 0.0f, CGSizeZero);

    label.textColor = [TGPresentation classicIOS6Style] ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? presentation.pallete.tabTextColor : UIColorRGB(0xc7c9cb)) : presentation.pallete.tabTextColor;
    label.highlightedTextColor = [TGPresentation classicIOS6Style] ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? presentation.pallete.tabActiveIconColor : UIColorRGB(0xffffff)) : presentation.pallete.tabActiveIconColor;
    label.shadowColor = [TGPresentation classicIOS6Style] ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? UIColorRGBA(0x000000, presentation.pallete.isDark ? 0.85f : 0.2f) : UIColorRGBA(0x000000, 0.85f)) : [UIColor clearColor];
    label.shadowOffset = [TGPresentation classicIOS6Style] ? CGSizeMake(0.0f, -1.0f) : CGSizeZero;
}

static UIFont *TGMainTabsTabLabelFont(bool landscape)
{
    if (landscape)
        return [TGPresentation classicIOS6Style] ? TGBoldSystemFontOfSize(12.0f) : TGSystemFontOfSize(12.0f);
    if ([TGPresentation brandedIOS6Style])
        return [OGTheme brandedTheme].tabBarAppearance.titleFont;
    if ([TGPresentation classicIOS6Style])
        return TGBoldSystemFontOfSize(TGIsPad() ? 11.0f : 10.0f);
    return TGMediumSystemFontOfSize(TGIsPad() ? 11.0f : 10.0f);
}

static UIImage *TGMainTabsClassicIOS6Image(NSString *name)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString *resourceName = scale > 1.5f ? [name stringByAppendingString:@"@2x"] : name;
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && scale > 1.5f && image.CGImage != NULL)
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
    return image;
}

static UIImage *TGMainTabsClassicIOS6ResizableImageWithHorizontalCap(NSString *name, CGFloat capWidth)
{
    UIImage *image = TGMainTabsClassicIOS6Image(name);
    if (image == nil)
        return nil;

    if ([image respondsToSelector:@selector(resizableImageWithCapInsets:)])
        return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, capWidth, 0.0f, capWidth)];

    NSInteger leftCapWidth = (NSInteger)floor(capWidth);
    if ((CGFloat)(leftCapWidth * 2 + 1) > image.size.width)
        leftCapWidth = MAX(0, (NSInteger)floor((image.size.width - 1.0f) / 2.0f));

    return [image stretchableImageWithLeftCapWidth:leftCapWidth topCapHeight:0];
}

static UIImage *TGMainTabsClassicIOS6ResizableImage(NSString *name)
{
    return TGMainTabsClassicIOS6ResizableImageWithHorizontalCap(name, 1.0f);
}

static UIColor *TGMainTabsClassicSelectedColor(TGPresentation *presentation)
{
    if ([TGPresentation classicIOS6Style] && presentation.pallete.isDark)
        return UIColorRGB(0x2b78c5);
    return presentation.pallete.tabActiveIconColor;
}

static NSInteger const TGMainTabsClassicIOS4TitleTag = 0x49365454;

static void TGMainTabsConfigureClassicIOS4TitleLabel(UILabel *label, NSString *title, TGPresentation *presentation)
{
    if (presentation == nil)
        presentation = TGPresentation.current;

    label.backgroundColor = [UIColor clearColor];
    label.font = TGBoldSystemFontOfSize(17.0f);
    label.text = title;
    if ([TGPresentation classicIOS6Style])
    {
        label.textColor = [UIColor whiteColor];
        label.shadowColor = presentation.pallete.isDark ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f);
        label.shadowOffset = CGSizeMake(0.0f, -1.0f);
    }
    else
    {
        UIColor *titleColor = presentation.pallete.navigationTitleColor;
        label.textColor = titleColor != nil ? titleColor : [UIColor blackColor];
        label.shadowColor = [UIColor clearColor];
        label.shadowOffset = CGSizeZero;
    }
    [label sizeToFit];
}

@protocol TGTabBarDelegate <NSObject>

- (void)tabBarSelectedItem:(int)index;
- (void)tabBarLongPressedItem:(int)index;

@end


@interface TGTabBarBadge : UIView
{
    UIImageView *_backgroundView;
    UILabel *_label;
}

@property (nonatomic, strong) UIImage *image;

@end

@implementation TGTabBarBadge

- (instancetype)initWithPresentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:CGRectMake(0, 0, 20.0f, 20.0f)];
    if (self != nil)
    {
        self.hidden = true;
        self.userInteractionEnabled = false;
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
        _backgroundView = [[UIImageView alloc] init];
        [self addSubview:_backgroundView];
        
        _label = [[UILabel alloc] init];
        _label.text = @"1";
        [_label sizeToFit];
        _label.text = nil;
        _label.backgroundColor = [UIColor clearColor];
        _label.font = TGSystemFontOfSize(13);
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
        
        [self setPresentation:presentation];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    if ([TGPresentation brandedIOS6Style])
    {
        _backgroundView.image = [TGPresentation brandedIOS6BadgeImage];
        OGPlatformApplyViewShadow(_backgroundView, [UIColor blackColor], 0.80f, 1.5f, CGSizeMake(0.0f, 2.0f));
        UIFont *badgeFont = TGBoldSystemFontOfSize(11.0f);
        _label.font = badgeFont != nil ? badgeFont : TGBoldSystemFontOfSize(11.0f);
        _label.textColor = [UIColor whiteColor];
        _label.shadowColor = [UIColor clearColor];
        _label.shadowOffset = CGSizeZero;
    }
    else if ([TGPresentation classicIOS6Style])
    {
        UIImage *badgeImage = TGMainTabsClassicIOS6ResizableImageWithHorizontalCap(@"TabBarBadge", 10.0f);
        UIColor *badgeColor = presentation.pallete.isDark ? TGMainTabsClassicSelectedColor(presentation) : presentation.pallete.tabBadgeColor;
        _backgroundView.image = [TGPresentation classicIOS6ThemedImage:badgeImage tintColor:badgeColor alpha:presentation.pallete.isDark ? 0.95f : 0.5f];
        OGPlatformApplyViewShadow(_backgroundView, nil, 0.0f, 0.0f, CGSizeZero);
        _label.font = TGBoldSystemFontOfSize(12.0f);
        _label.textColor = presentation.pallete.isDark ? [UIColor whiteColor] : (presentation.pallete.tabBadgeTextColor ?: [UIColor whiteColor]);
        _label.shadowColor = [TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? UIColorRGBA(0x000000, presentation.pallete.isDark ? 0.7f : 0.25f) : UIColorRGBA(0x000000, 0.85f);
        _label.shadowOffset = CGSizeMake(0.0f, -1.0f);
    }
    else
    {
        _backgroundView.image = presentation.images.tabBarBadgeImage;
        OGPlatformApplyViewShadow(_backgroundView, nil, 0.0f, 0.0f, CGSizeZero);
        _label.font = TGSystemFontOfSize(13.0f);
        _label.textColor = presentation.pallete.tabBadgeTextColor;
        _label.shadowColor = [UIColor clearColor];
        _label.shadowOffset = CGSizeZero;
    }
}

- (void)setCount:(int)count
{
    if (count <= 0)
    {
        self.hidden = true;
    }
    else
    {
        NSString *text = nil;
        
        if ([TGPresentation brandedIOS6Style])
        {
            text = [TGPresentation brandedIOS6BadgeTextForCount:count];
        }
        else if (TGIsLocaleArabic())
        {
            text = [TGStringUtils stringWithLocalizedNumber:count];
        }
        else
        {
            if (count < 1000)
                text = [[NSString alloc] initWithFormat:@"%d", count];
            else if (count < 1000000)
                text = [[NSString alloc] initWithFormat:@"%dK", count / 1000];
            else
                text = [[NSString alloc] initWithFormat:@"%dM", count / 1000000];
        }
        
        _label.text = text;
        [_label sizeToFit];
        self.hidden = false;
        
        CGRect frame = _backgroundView.frame;
        CGFloat textWidth = CGCeil(_label.frame.size.width);
        if ([TGPresentation brandedIOS6Style])
        {
            frame.size.width = MAX(18.0f, textWidth + 10.0f);
            frame.size.height = 18.0f;
            frame.origin.y = 0.0f;
        }
        else
        {
            frame.size.width = count < 10 ? 20.0f : MAX(20.0f, textWidth + 10.0f + TGScreenPixel * 2.0f);
            frame.size.height = 20.0f;
            frame.origin.y = -1.0f;
        }
        frame.origin.x = _backgroundView.superview.frame.size.width - frame.size.width - 1.0f;
        _backgroundView.frame = frame;
        if ([TGPresentation brandedIOS6Style])
            _backgroundView.image = [TGPresentation brandedIOS6BadgeImageForWidth:frame.size.width];
        
        CGRect labelFrame = _label.frame;
        labelFrame.origin.x = frame.origin.x;
        labelFrame.origin.y = [TGPresentation brandedIOS6Style] ? frame.origin.y : ([TGPresentation classicIOS6Style] ? 0.0f : 1.0f);
        labelFrame.size.width = frame.size.width;
        if ([TGPresentation brandedIOS6Style])
        {
            labelFrame.origin.y = frame.origin.y;
            labelFrame.size.height = frame.size.height;
        }
        _label.frame = labelFrame;
    }
}

@end

@interface TGTabBarButton : UIView
{
    UILabel *_label;
    TGPresentation *_presentation;
    UIImage *_classicSelectedImage;
    CAGradientLayer *_classicSelectionLayer;
}

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, assign, getter=isSelected) bool selected;
@property (nonatomic, assign) bool landscape;
@property (nonatomic, assign) CGFloat contentCenterX;
@property (nonatomic, strong) OGTabBarLayout *brandedLayout;

- (void)setClassicSelectedImage:(UIImage *)image;
- (void)setTitle:(NSString *)title;

@end

@implementation TGTabBarButton

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title presentation:(TGPresentation *)presentation
{
    self = [super init];
    if (self != nil)
    {
        CFAbsoluteTime detailStart = CFAbsoluteTimeGetCurrent();
        _presentation = presentation;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityLabel = title;

        detailStart = CFAbsoluteTimeGetCurrent();
        _imageView = [[UIImageView alloc] initWithImage:image];
        [self addSubview:_imageView];

        detailStart = CFAbsoluteTimeGetCurrent();
        _label = [[UILabel alloc] init];
        detailStart = CFAbsoluteTimeGetCurrent();
        _label.backgroundColor = [UIColor clearColor];
        TGMainTabsApplyTabLabelStyle(_label, presentation);
        detailStart = CFAbsoluteTimeGetCurrent();
        _label.font = TGMainTabsTabLabelFont(false);
        detailStart = CFAbsoluteTimeGetCurrent();
        _label.text = title;
        _label.textAlignment = NSTextAlignmentLeft;
        [_label sizeToFit];
        [self addSubview:_label];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    self.accessibilityLabel = title;
    _label.text = title;
    [_label sizeToFit];
    [self setNeedsLayout];
}

- (void)setImage:(UIImage *)image presentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    _imageView.image = image;
    if (_imageView.highlighted)
    {
        _imageView.highlightedImage = _classicSelectedImage != nil ? _classicSelectedImage : TGTintedImage(image, [TGPresentation classicIOS6Style] ? TGMainTabsClassicSelectedColor(presentation) : presentation.pallete.tabActiveIconColor);
        _imageView.highlighted = false;
        _imageView.highlighted = true;
    }
    else
        _imageView.highlightedImage = nil;
    
    TGMainTabsApplyTabLabelStyle(_label, presentation);
    _label.font = TGMainTabsTabLabelFont(_landscape);
    [_label sizeToFit];
    [self setNeedsLayout];
}

- (void)setClassicSelectedImage:(UIImage *)image
{
    _classicSelectedImage = image;
    if (_classicSelectedImage != nil && _classicSelectionLayer == nil && ![TGPresentation brandedIOS6Style])
    {
        _classicSelectionLayer = [CAGradientLayer layer];
        UIImage *selectionImage = TGMainTabsClassicIOS6ResizableImage(@"TabBarSelected");
        selectionImage = [TGPresentation classicIOS6ThemedImage:selectionImage tintColor:([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? _presentation.pallete.selectionColor : nil) alpha:0.75f];
        _classicSelectionLayer.contents = (id)selectionImage.CGImage;
        OGPlatformSetLayerContentsScale(_classicSelectionLayer, selectionImage.scale);
        _classicSelectionLayer.contentsGravity = kCAGravityResize;
        [self.layer insertSublayer:_classicSelectionLayer atIndex:0];
    }
    _classicSelectionLayer.hidden = _classicSelectedImage == nil || !_selected || [TGPresentation brandedIOS6Style];
    _imageView.highlightedImage = _selected ? (_classicSelectedImage != nil ? _classicSelectedImage : TGTintedImage(_imageView.image, [TGPresentation classicIOS6Style] ? TGMainTabsClassicSelectedColor(_presentation) : _presentation.pallete.tabActiveIconColor)) : nil;
}

- (void)setSelected:(bool)selected
{
    _selected = selected;
    _classicSelectionLayer.hidden = _classicSelectedImage == nil || !selected || [TGPresentation brandedIOS6Style];
    if (_imageView.highlightedImage == nil && selected)
        _imageView.highlightedImage = _classicSelectedImage != nil ? _classicSelectedImage : TGTintedImage(_imageView.image, [TGPresentation classicIOS6Style] ? TGMainTabsClassicSelectedColor(_presentation) : _presentation.pallete.tabActiveIconColor);
    _imageView.highlighted = selected;
    _label.highlighted = selected;
}

- (void)setContentCenterX:(CGFloat)contentCenterX
{
    if (ABS(_contentCenterX - contentCenterX) > FLT_EPSILON)
    {
        _contentCenterX = contentCenterX;
        [self setNeedsLayout];
    }
}

- (void)setBrandedLayout:(OGTabBarLayout *)brandedLayout
{
    if (_brandedLayout != brandedLayout)
    {
        _brandedLayout = brandedLayout;
        [self setNeedsLayout];
    }
}

- (void)layoutBrandedPortrait
{
    OGTabBarAppearance *appearance = [OGTheme brandedTheme].tabBarAppearance;
    OGTabBarLayout *layout = _brandedLayout != nil ? _brandedLayout : [appearance layoutForItemCount:0];
    UIEdgeInsets outsets = [appearance iconOutsets];
    _imageView.transform = CGAffineTransformIdentity;
    CGSize imageSize = _imageView.image.size;
    CGFloat glyphWidth = imageSize.width - outsets.left - outsets.right;
    _imageView.frame = CGRectMake(CGRound(_contentCenterX - glyphWidth / 2.0f) - outsets.left, layout.iconTopInset - outsets.top, imageSize.width, imageSize.height);

    if (_label.font != appearance.titleFont)
    {
        _label.font = appearance.titleFont;
        [_label sizeToFit];
    }
    CGFloat labelWidth = MIN(CGCeil(_label.frame.size.width), self.frame.size.width);
    _label.frame = CGRectMake(CGRound(_contentCenterX - labelWidth / 2.0f), self.frame.size.height - layout.titleBottomInset - layout.titleHeight, labelWidth, layout.titleHeight);
}

- (void)layoutSubviews
{
    if (_classicSelectionLayer != nil)
        _classicSelectionLayer.frame = self.bounds;

    if ([TGPresentation brandedIOS6Style] && !_landscape)
    {
        [self layoutBrandedPortrait];
        return;
    }

    CGFloat imageVerticalOffset = [self iconVerticalOffset];
    if ([TGPresentation brandedIOS6Style])
        imageVerticalOffset += (32.0f - _imageView.bounds.size.height) / 2.0f;

    _imageView.frame = CGRectMake(floor((self.frame.size.width - _imageView.frame.size.width) / 2), imageVerticalOffset, _imageView.frame.size.width, _imageView.frame.size.height);
    
    _imageView.center = CGPointMake(self.frame.size.width / 2, imageVerticalOffset + _imageView.bounds.size.height / 2.0f);
    
    if (_landscape)
    {
        _label.font = TGMainTabsTabLabelFont(true);
        if (CGAffineTransformIsIdentity(_imageView.transform))
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                _imageView.transform = CGAffineTransformMakeScale(0.6667f, 0.6667f);
            }];
            [_label sizeToFit];
        }
        
        CGFloat width = CGCeil(_imageView.frame.size.width + 6.0f + _label.frame.size.width);
        _imageView.center = CGPointMake((self.frame.size.width - width) / 2.0f + _imageView.frame.size.width / 2.0f, _imageView.bounds.size.height / 2.0f + 1.0f);
    
        _label.frame = CGRectMake(round(((self.frame.size.width - width) / 2.0f) + _imageView.frame.size.width + 6.0f), 9.0f, _label.frame.size.width, _label.frame.size.height);
    }
    else
    {
        _label.font = TGMainTabsTabLabelFont(false);
        if (!CGAffineTransformIsIdentity(_imageView.transform))
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                _imageView.transform = CGAffineTransformIdentity;
            }];
            
            [_label sizeToFit];
        }
        _imageView.center = CGPointMake(self.frame.size.width / 2, imageVerticalOffset + _imageView.bounds.size.height / 2.0f);
        _label.frame = CGRectMake(round((self.frame.size.width - _label.frame.size.width) / 2.0f), [self labelVerticalOffset], _label.frame.size.width, _label.frame.size.height);
    }
}

- (void)setLandscape:(bool)landscape
{
    if (_landscape != landscape)
    {
        _landscape = landscape;
        [self setNeedsLayout];
    }
}

- (CGFloat)iconVerticalOffset
{
    static CGFloat offset = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (!TGIsPad())
            offset = 4;
        else
            offset = 5 + TGRetinaPixel;
    });
    return offset;
}

- (CGFloat)labelVerticalOffset
{
    static CGFloat offset = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (!TGIsPad())
            offset = 35 - TGScreenPixel;
        else
            offset = 36;
    });
    return offset;
}

@end


@interface TGTabBar : UIView <UIGestureRecognizerDelegate>
{
    bool _skipNextLayout;
    
    NSNumber *_unreadArrowUp;
    int _callsCount;
    int _messagesCount;
    UIImageView *_classicIOS6BackgroundView;
    NSString *_brandedBackgroundKey;
}

@property (nonatomic, weak) id<TGTabBarDelegate> tabDelegate;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *stripeView;

@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, strong) TGTabBarButton *contactsButton;
@property (nonatomic, strong) TGTabBarButton *callsButton;
@property (nonatomic, strong) TGTabBarButton *chatsButton;
@property (nonatomic, strong) TGTabBarButton *settingsButton;
@property (nonatomic, assign) bool callsHidden;
@property (nonatomic, assign) bool contactsHidden;

@property (nonatomic, strong) TGTabBarBadge *callsBadge;
@property (nonatomic, strong) TGTabBarBadge *messagesBadge;

@property (nonatomic, assign) UIEdgeInsets safeAreaInset;
@property (nonatomic, assign) bool landscape;

@property (nonatomic) int selectedIndex;


@property (nonatomic, strong) TGPresentation *presentation;
@end

@implementation TGTabBar

- (void)startupLocalizationUpdated:(NSNotification *)notification
{
    (void)notification;
    [_contactsButton setTitle:TGStartupLocalized(@"Contacts.TabTitle")];
    [_callsButton setTitle:TGStartupLocalized(@"Calls.TabTitle")];
    [_chatsButton setTitle:TGStartupLocalized(@"DialogList.TabTitle")];
    [_settingsButton setTitle:TGStartupLocalized(@"Settings.TabTitle")];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGStartupLocalizationUpdatedNotification object:nil];
}

- (instancetype)initWithFrame:(CGRect)frame presentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        CFAbsoluteTime phaseStart = CFAbsoluteTimeGetCurrent();
        self.multipleTouchEnabled = false;
        self.exclusiveTouch = true;
        
        _presentation = presentation;
        
        _backgroundView = [[UIView alloc] init];
        if ([TGPresentation classicIOS6Style])
        {
            _backgroundView.backgroundColor = [UIColor clearColor];
            UIImage *backgroundImage = [TGPresentation brandedIOS6Style] ? nil : [TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6ResizableImage(@"TabBarBackground") tintColor:presentation.pallete.barBackgroundColor alpha:0.85f];
            _classicIOS6BackgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
            [_backgroundView addSubview:_classicIOS6BackgroundView];
        }
        else
            _backgroundView.backgroundColor = presentation.pallete.barBackgroundColor;
        _backgroundView.frame = self.bounds;
        [self addSubview:_backgroundView];
        
        _stripeView = [[UIView alloc] init];
        _stripeView.backgroundColor = [TGPresentation classicIOS6Style] ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? presentation.pallete.barSeparatorColor : UIColorRGB(0xa4a8ac)) : presentation.pallete.barSeparatorColor;
        _stripeView.hidden = [TGPresentation brandedIOS6Style];
        [self addSubview:_stripeView];
        
        _tabButtons = [[NSMutableArray alloc] init];
        phaseStart = CFAbsoluteTimeGetCurrent();
        
        UIImage *contactsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsContactsIconName, presentation.images.tabBarContactsIcon, false) : presentation.images.tabBarContactsIcon;
        UIImage *callsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsCallsIconName, presentation.images.tabBarCallsIcon, false) : presentation.images.tabBarCallsIcon;
        UIImage *chatsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsChatsIconName, presentation.images.tabBarChatsIcon, false) : presentation.images.tabBarChatsIcon;
        UIImage *settingsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsSettingsIconName, presentation.images.tabBarSettingsIcon, false) : presentation.images.tabBarSettingsIcon;
        phaseStart = CFAbsoluteTimeGetCurrent();

        CFAbsoluteTime buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        bool constrainedStartupLocalization = OGPlatformUsesConstrainedBackgroundExecution();
        NSString *contactsTitle = constrainedStartupLocalization ? TGStartupLocalized(@"Contacts.TabTitle") : TGLocalized(@"Contacts.TabTitle");
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        NSString *chatsTitle = constrainedStartupLocalization ? TGStartupLocalized(@"DialogList.TabTitle") : TGLocalized(@"DialogList.TabTitle");
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        NSString *settingsTitle = constrainedStartupLocalization ? TGStartupLocalized(@"Settings.TabTitle") : TGLocalized(@"Settings.TabTitle");
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        NSString *callsTitle = constrainedStartupLocalization ? TGStartupLocalized(@"Calls.TabTitle") : TGLocalized(@"Calls.TabTitle");

        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        _contactsButton = [[TGTabBarButton alloc] initWithImage:contactsImage title:contactsTitle presentation:presentation];
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        _chatsButton = [[TGTabBarButton alloc] initWithImage:chatsImage title:chatsTitle presentation:presentation];
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        _settingsButton = [[TGTabBarButton alloc] initWithImage:settingsImage title:settingsTitle presentation:presentation];
        buttonPhaseStart = CFAbsoluteTimeGetCurrent();
        _callsButton = [[TGTabBarButton alloc] initWithImage:callsImage title:callsTitle presentation:presentation];
        phaseStart = CFAbsoluteTimeGetCurrent();
        if ([TGPresentation classicIOS6Style])
        {
            if ([TGPresentation brandedIOS6Style])
            {
                [_contactsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsContactsIconName, presentation.images.tabBarContactsIcon, true)];
                [_callsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsCallsIconName, presentation.images.tabBarCallsIcon, true)];
                [_chatsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsChatsIconName, presentation.images.tabBarChatsIcon, true)];
                [_settingsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsSettingsIconName, presentation.images.tabBarSettingsIcon, true)];
            }
            else
            {
                [_contactsButton setClassicSelectedImage:[TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconContacts_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f]];
                [_chatsButton setClassicSelectedImage:[TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconMessages_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f]];
                [_settingsButton setClassicSelectedImage:[TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconSettings_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f]];
            }
        }
        phaseStart = CFAbsoluteTimeGetCurrent();
        _callsHidden = true;
        _callsButton.hidden = true;
        _callsButton.alpha = 0.0f;
        
        [_tabButtons addObject:_contactsButton];
        [_tabButtons addObject:_callsButton];
        [_tabButtons addObject:_chatsButton];
        [_tabButtons addObject:_settingsButton];
        
        for (TGTabBarButton *button in _tabButtons)
        {
            button.userInteractionEnabled = true;
            [self addSubview:button];
            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            [button addGestureRecognizer:tapGestureRecognizer];
        }
        
        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPressGestureRecognizer.minimumPressDuration = 0.25;
        longPressGestureRecognizer.allowableMovement = 10.0f;
        longPressGestureRecognizer.delegate = self;
        [_chatsButton addGestureRecognizer:longPressGestureRecognizer];
        if (OGPlatformUsesConstrainedBackgroundExecution())
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startupLocalizationUpdated:) name:TGStartupLocalizationUpdatedNotification object:nil];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;

    if ([TGPresentation classicIOS6Style])
    {
        if (_classicIOS6BackgroundView == nil)
        {
            UIImage *backgroundImage = TGMainTabsClassicIOS6ResizableImage(@"TabBarBackground");
            backgroundImage = [TGPresentation classicIOS6ThemedImage:backgroundImage tintColor:presentation.pallete.barBackgroundColor alpha:0.85f];
            _classicIOS6BackgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
            [_backgroundView addSubview:_classicIOS6BackgroundView];
        }
        _classicIOS6BackgroundView.hidden = false;
        _backgroundView.backgroundColor = [UIColor clearColor];
        if (![TGPresentation brandedIOS6Style])
            _callsHidden = true;
        _callsButton.alpha = _callsHidden ? 0.0f : 1.0f;
        _callsButton.hidden = _callsHidden;
        _brandedBackgroundKey = nil;
        if ([TGPresentation brandedIOS6Style])
        {
            _classicIOS6BackgroundView.image = nil;
            _stripeView.hidden = true;
            [self setNeedsLayout];
        }
        else
        {
            _classicIOS6BackgroundView.image = [TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6ResizableImage(@"TabBarBackground") tintColor:presentation.pallete.barBackgroundColor alpha:0.85f];
            _stripeView.hidden = false;
            _stripeView.backgroundColor = [TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? presentation.pallete.barSeparatorColor : UIColorRGB(0xa4a8ac);
        }
    }
    else
    {
        _classicIOS6BackgroundView.hidden = true;
        _backgroundView.backgroundColor = presentation.pallete.barBackgroundColor;
        _stripeView.hidden = false;
        _stripeView.backgroundColor = presentation.pallete.barSeparatorColor;
    }

    UIImage *contactsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsContactsIconName, presentation.images.tabBarContactsIcon, false) : presentation.images.tabBarContactsIcon;
    UIImage *callsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsCallsIconName, presentation.images.tabBarCallsIcon, false) : presentation.images.tabBarCallsIcon;
    UIImage *chatsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsChatsIconName, presentation.images.tabBarChatsIcon, false) : presentation.images.tabBarChatsIcon;
    UIImage *settingsImage = [TGPresentation brandedIOS6Style] ? TGMainTabsBrandedIOS6Icon(TGMainTabsSettingsIconName, presentation.images.tabBarSettingsIcon, false) : presentation.images.tabBarSettingsIcon;

    if ([TGPresentation brandedIOS6Style])
    {
        [_contactsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsContactsIconName, presentation.images.tabBarContactsIcon, true)];
        [_callsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsCallsIconName, presentation.images.tabBarCallsIcon, true)];
        [_chatsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsChatsIconName, presentation.images.tabBarChatsIcon, true)];
        [_settingsButton setClassicSelectedImage:TGMainTabsBrandedIOS6Icon(TGMainTabsSettingsIconName, presentation.images.tabBarSettingsIcon, true)];
    }
    else
    {
        [_contactsButton setClassicSelectedImage:[TGPresentation classicIOS6Style] ? [TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconContacts_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f] : nil];
        [_callsButton setClassicSelectedImage:nil];
        [_chatsButton setClassicSelectedImage:[TGPresentation classicIOS6Style] ? [TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconMessages_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f] : nil];
        [_settingsButton setClassicSelectedImage:[TGPresentation classicIOS6Style] ? [TGPresentation classicIOS6ThemedImage:TGMainTabsClassicIOS6Image(@"TabIconSettings_Highlighted") tintColor:TGMainTabsClassicSelectedColor(presentation) alpha:0.6f] : nil];
    }

    [_contactsButton setImage:contactsImage presentation:presentation];
    [_chatsButton setImage:chatsImage presentation:presentation];
    [_settingsButton setImage:settingsImage presentation:presentation];
    [_callsButton setImage:callsImage presentation:presentation];
    
    [_messagesBadge setPresentation:presentation];
    [_callsBadge setPresentation:presentation];
}

- (CGFloat)sideIconOffsetForWidth:(CGFloat)width
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        return 0.0f;
    if (width < 320.0f + FLT_EPSILON)
        return 0.0f;
    
    return CGFloor(width / 21.5f);
}

- (bool)isTabButtonHidden:(TGTabBarButton *)button
{
    if (button == _callsButton)
        return _callsHidden;
    if (button == _contactsButton)
        return _contactsHidden;
    return false;
}

- (NSArray *)visibleTabButtons
{
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:_tabButtons.count];
    for (TGTabBarButton *button in _tabButtons)
    {
        if (![self isTabButtonHidden:button])
            [buttons addObject:button];
    }
    return buttons;
}

- (void)updateVisibilityOfTabButton:(TGTabBarButton *)button animated:(bool)animated
{
    bool hidden = [self isTabButtonHidden:button];
    if (animated)
    {
        button.hidden = false;
        if (!hidden)
            button.alpha = 0.0f;
        
        [UIView animateWithDuration:0.2 animations:^
        {
            button.alpha = hidden ? 0.0f : 1.0f;
        }];
        
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionLayoutSubviews animations:^
        {
            [self layoutButtons];
        } completion:^(__unused BOOL finished)
        {
            _skipNextLayout = false;
            button.hidden = [self isTabButtonHidden:button];
        }];
        
        _skipNextLayout = true;
    }
    else
    {
        button.alpha = hidden ? 0.0f : 1.0f;
        button.hidden = hidden;
        [self setNeedsLayout];
    }
}

- (void)setCallsTabHidden:(bool)hidden animated:(bool)animated
{
    if (_callsHidden == hidden)
        return;
    
    _callsHidden = hidden;
    [self updateVisibilityOfTabButton:_callsButton animated:animated];
}

- (void)setContactsTabHidden:(bool)hidden animated:(bool)animated
{
    if (_contactsHidden == hidden)
        return;
    
    _contactsHidden = hidden;
    [self updateVisibilityOfTabButton:_contactsButton animated:animated];
}

- (void)setSelectedIndex:(int)selectedIndex
{
    _selectedIndex = selectedIndex;
    
    [_tabButtons enumerateObjectsUsingBlock:^(TGTabBarButton *button, NSUInteger index, __unused BOOL *stop)
    {
        [button setSelected:((int)index == selectedIndex)];
    }];
    
    [self updateArrow];
    [self updateBrandedBackground];
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded)
        return;
    NSUInteger index = [_tabButtons indexOfObject:gestureRecognizer.view];
    if (index == NSNotFound || index >= _tabButtons.count)
        return;
    TGTabBarButton *button = [_tabButtons objectAtIndex:index];
    if (button.hidden || button.alpha < 0.01f)
        return;
    [self setSelectedIndex:(int)index];
    __strong id<TGTabBarDelegate> delegate = _tabDelegate;
    [delegate tabBarSelectedItem:(int)index];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        __strong id<TGTabBarDelegate> delegate = _tabDelegate;
        [delegate tabBarLongPressedItem:2];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    if (gestureRecognizer.view == self)
        return true;
    else
        return _selectedIndex == 2;
}

- (void)setMissedCallsCount:(int)callsCount
{
    if (callsCount <= 0 && _callsBadge == nil)
        return;
    
    if (_callsBadge == nil)
    {
        _callsBadge = [[TGTabBarBadge alloc] initWithPresentation:_presentation];
        [_callsButton addSubview:_callsBadge];
        
        [self setNeedsLayout];
    }
    
    _callsCount = callsCount;
    [self updateCounts];
}

- (void)setUnreadCount:(int)unreadCount
{
    if (unreadCount <= 0 && _messagesBadge == nil)
        return;
    
    if (_messagesBadge == nil)
    {
        _messagesBadge = [[TGTabBarBadge alloc] initWithPresentation:_presentation];
        [_tabButtons[2] addSubview:_messagesBadge];
        
        [self setNeedsLayout];
    }
    
    _messagesCount = unreadCount;
    [self updateCounts];
    [self updateArrow];
}

- (void)setUnreadArrowUp:(NSNumber *)arrowUp
{
    _unreadArrowUp = arrowUp;
    [self updateArrow];
}

- (void)updateArrow
{
    if ([TGPresentation brandedIOS6Style])
    {
        [_chatsButton setImage:TGMainTabsBrandedIOS6Icon(TGMainTabsChatsIconName, self.presentation.images.tabBarChatsIcon, false) presentation:self.presentation];
        return;
    }

    if (_selectedIndex == 2 && _unreadArrowUp != nil)
    {
        if (_unreadArrowUp.boolValue)
            [_chatsButton setImage:self.presentation.images.tabBarChatsUpIcon presentation:self.presentation];
        else
            [_chatsButton setImage:self.presentation.images.tabBarChatsDownIcon presentation:self.presentation];
    }
    else
    {
        [_chatsButton setImage:self.presentation.images.tabBarChatsIcon presentation:self.presentation];
    }
}

- (void)updateCounts
{
    [_callsBadge setCount:_callsCount];
    [_messagesBadge setCount:MAX(0, _messagesCount - _callsCount)];
}

- (void)layoutButtons
{    
    CGSize viewSize = self.frame.size;
    
    CGFloat width = viewSize.width - self.safeAreaInset.left - self.safeAreaInset.right;
    CGFloat height = [TGTabBar tabBarHeight:_landscape];
    
    NSArray *visibleButtons = [self visibleTabButtons];
    NSUInteger buttonsCount = MAX((NSUInteger)1, visibleButtons.count);
    CGFloat buttonWidth = CGFloor(width / (CGFloat)buttonsCount);
    bool brandedPortrait = [TGPresentation brandedIOS6Style] && !self.landscape;
    OGTabBarLayout *brandedLayout = brandedPortrait ? [[OGTheme brandedTheme].tabBarAppearance layoutForItemCount:buttonsCount] : nil;
    
    __block NSUInteger slot = 0;
    [_tabButtons enumerateObjectsUsingBlock:^(TGTabBarButton *button, NSUInteger index, __unused BOOL *stop)
    {
        NSUInteger buttonSlot = MIN(slot, buttonsCount - 1);
        if (![self isTabButtonHidden:button])
            slot++;
        
        CGFloat x = self.safeAreaInset.left + buttonSlot * buttonWidth;
        CGFloat maxX = buttonSlot + 1 == buttonsCount ? self.safeAreaInset.left + width : x + buttonWidth;
        
        button.landscape = self.landscape;
        button.brandedLayout = brandedLayout;
        button.frame = CGRectMake(x, 0, maxX - x, height);
        button.contentCenterX = CGFloor((maxX - x) / 2.0f);
        
        TGTabBarBadge *badge = nil;
        if (index == 1)
            badge = _callsBadge;
        else if (index == 2)
            badge = _messagesBadge;
        
        if (badge != nil)
        {
            if (self.landscape)
            {
                [button layoutSubviews];
                badge.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
                badge.center = CGPointMake(button.imageView.center.x + 10.0f, 10.0f);
            }
            else
            {
                badge.transform = CGAffineTransformIdentity;
                CGRect badgeFrame = badge.frame;
                badgeFrame.origin.x = button.contentCenterX + 6.0f + (_callsHidden ? 0 : TGRetinaPixel);
                badgeFrame.origin.y = 2 - button.frame.origin.y;
                badge.frame = badgeFrame;
            }
        }
    }];
    
    [self updateBrandedBackground];
}

- (void)updateBrandedBackground
{
    if (![TGPresentation brandedIOS6Style] || _classicIOS6BackgroundView == nil)
        return;
    
    CGSize viewSize = self.bounds.size;
    if (viewSize.width < 1.0f || viewSize.height < 1.0f)
        return;
    
    NSArray *visibleButtons = [self visibleTabButtons];
    TGTabBarButton *selectedButton = _selectedIndex >= 0 && _selectedIndex < (int)_tabButtons.count ? _tabButtons[_selectedIndex] : nil;
    NSUInteger selectedSegment = selectedButton == nil ? NSNotFound : [visibleButtons indexOfObject:selectedButton];
    
    NSMutableArray *segmentFrames = [[NSMutableArray alloc] initWithCapacity:visibleButtons.count];
    NSMutableString *key = [[NSMutableString alloc] initWithFormat:@"%.1f,%.1f,%d", viewSize.width, viewSize.height, selectedSegment == NSNotFound ? -1 : (int)selectedSegment];
    [visibleButtons enumerateObjectsUsingBlock:^(TGTabBarButton *button, NSUInteger index, __unused BOOL *stop)
    {
        CGFloat minX = index == 0 ? 0.0f : CGRectGetMinX(button.frame);
        CGFloat maxX = index + 1 == visibleButtons.count ? viewSize.width : CGRectGetMaxX(button.frame);
        [segmentFrames addObject:[NSValue valueWithCGRect:CGRectMake(minX, 0.0f, maxX - minX, viewSize.height)]];
        [key appendFormat:@"|%.1f,%.1f", minX, maxX];
    }];
    
    if ([_brandedBackgroundKey isEqualToString:key])
        return;
    
    _brandedBackgroundKey = key;
    _classicIOS6BackgroundView.image = [TGPresentation brandedIOS6TabBarBackgroundImageForSize:viewSize segmentFrames:segmentFrames selectedIndex:selectedSegment == NSNotFound ? -1 : (NSInteger)selectedSegment];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.frame.size;
    
    _backgroundView.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);
    if (_classicIOS6BackgroundView != nil)
        _classicIOS6BackgroundView.frame = _backgroundView.bounds;
    CGFloat stripeHeight = TGScreenPixel;
    _stripeView.frame = CGRectMake(0, [TGPresentation classicIOS6Style] ? 0.0f : -stripeHeight, viewSize.width, stripeHeight);
    
    [self layoutButtons];
}

+ (CGFloat)tabBarHeight:(bool)landscape
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return iosMajorVersion() >= 11 ? (landscape ? 32.0f : 49.0f) : 49.0f;
    else
        return 56.0f;
}

@end

#pragma mark -

@interface TGMainTabsController () <UITabBarControllerDelegate, TGTabBarDelegate>
{
    int _missedCallsCount;
    int _unreadCount;
    bool _callsHidden;
    bool _contactsHidden;
    NSTimeInterval _lastSameIndexTapTime;
    int _tapsInSuccession;
    
    bool _initialized;
    
    CGFloat _keyboardHeight;
    bool _ignoreKeyboardFrameChange;
    
    id<SDisposable> _presentationDisposable;
    TGPresentation *_presentation;
    bool _startupSingleControllerMode;
    NSUInteger _startupLogicalIndex;
    NSArray *(^_startupPrepareControllers)(void);
}

@property (nonatomic, strong) TGTabBar *customTabBar;

- (void)layoutCustomTabBar;
- (void)layoutSelectedContentUnderTabBar;
- (void)_updateNavigationItemOverride:(NSUInteger)selectedIndex;

@end

@implementation TGMainTabsController

- (instancetype)initWithPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.delegate = self;
        _callsHidden = true;
        
        if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)])
            [self setAutomaticallyAdjustsScrollViewInsets:false];
        
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:nil style:UIBarButtonItemStylePlain target:nil action:nil];
        self.navigationItem.backBarButtonItem.possibleTitles = [NSSet setWithObject:(OGPlatformUsesConstrainedBackgroundExecution() ? TGStartupLocalized(@"Common.Back") : TGLocalized(@"Common.Back"))];
    }
    return self;
}

- (void)setStartupViewController:(UIViewController *)viewController logicalIndex:(NSUInteger)logicalIndex prepareControllers:(NSArray *(^)(void))prepareControllers
{
    if (viewController == nil)
        return;

    _startupSingleControllerMode = true;
    _startupLogicalIndex = logicalIndex;
    _startupPrepareControllers = [prepareControllers copy];
    CFAbsoluteTime phaseStart = CFAbsoluteTimeGetCurrent();
    [super setViewControllers:@[viewController] animated:false];
    phaseStart = CFAbsoluteTimeGetCurrent();
    [self _updateNavigationItemOverride:0];
    if (_customTabBar != nil)
        [_customTabBar setSelectedIndex:(int)logicalIndex];
}

- (bool)prepareStartupControllersForLogicalIndex:(NSUInteger)logicalIndex
{
    if (!_startupSingleControllerMode)
        return true;
    if (logicalIndex == _startupLogicalIndex)
        return true;

    NSArray *controllers = _startupPrepareControllers == nil ? nil : _startupPrepareControllers();
    if (controllers.count <= logicalIndex || controllers.count <= _startupLogicalIndex)
        return false;

    NSUInteger startupLogicalIndex = _startupLogicalIndex;
    _startupSingleControllerMode = false;
    _startupPrepareControllers = nil;
    [super setViewControllers:controllers animated:false];
    [super setSelectedIndex:startupLogicalIndex];
    [self _updateNavigationItemOverride:startupLogicalIndex];
    [_customTabBar setSelectedIndex:(int)startupLogicalIndex];
    [self layoutSelectedContentUnderTabBar];
    return true;
}

- (NSUInteger)logicalSelectedIndex
{
    return _startupSingleControllerMode ? _startupLogicalIndex : [super selectedIndex];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation];
    CGFloat inset = 0.0f;
    if (iosMajorVersion() >= 11 && safeAreaInset.bottom > FLT_EPSILON)
        inset = safeAreaInset.bottom;

    bool landscape = !TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape(orientation);
    _customTabBar = [[TGTabBar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - [TGTabBar tabBarHeight:landscape] - inset, self.view.frame.size.width, [TGTabBar tabBarHeight:landscape] + inset) presentation:_presentation];
    _customTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _customTabBar.safeAreaInset = safeAreaInset;
    _customTabBar.landscape = landscape;
    _customTabBar.tabDelegate = self;
    [_customTabBar setCallsTabHidden:_callsHidden animated:false];
    [_customTabBar setContactsTabHidden:_contactsHidden animated:false];
    [self.view insertSubview:_customTabBar aboveSubview:self.tabBar];
    
    self.tabBar.hidden = true;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    [_customTabBar setPresentation:presentation];

    if (iosMajorVersion() < 5 && [self.navigationItem.titleView isKindOfClass:[UILabel class]] && self.navigationItem.titleView.tag == TGMainTabsClassicIOS4TitleTag)
        TGMainTabsConfigureClassicIOS4TitleLabel((UILabel *)self.navigationItem.titleView, self.title, presentation);
}

- (void)layoutCustomTabBar
{
    if (_customTabBar == nil)
        return;

    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;

    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation];
    CGFloat inset = 0.0f;
    if (iosMajorVersion() >= 11 && safeAreaInset.bottom > FLT_EPSILON)
        inset = safeAreaInset.bottom;

    bool landscape = !TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape(orientation);
    _customTabBar.safeAreaInset = safeAreaInset;
    _customTabBar.landscape = landscape;
    _customTabBar.frame = CGRectMake(0.0f, self.view.frame.size.height - [TGTabBar tabBarHeight:landscape] - inset, self.view.frame.size.width, [TGTabBar tabBarHeight:landscape] + inset);
    [_customTabBar setNeedsLayout];
    [_customTabBar layoutIfNeeded];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutCustomTabBar];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutSelectedContentUnderTabBar];
}

- (void)layoutSelectedContentUnderTabBar
{
    if (iosMajorVersion() >= 7 || ![self isViewLoaded])
        return;

    UIViewController *selectedViewController = self.selectedViewController;
    if (selectedViewController == nil || ![selectedViewController isViewLoaded])
        return;

    UIView *contentView = selectedViewController.view;
    NSMutableArray *containers = [[NSMutableArray alloc] init];
    for (UIView *view = contentView.superview; view != nil && view != self.view; view = view.superview)
        [containers insertObject:view atIndex:0];
    if (containers.count == 0 || ((UIView *)containers[0]).superview != self.view)
        return;

    UIView *rootContainer = containers[0];
    CGRect rootFrame = rootContainer.frame;
    rootFrame.size.height = MAX(0.0f, self.view.bounds.size.height - rootFrame.origin.y);
    if (!CGRectEqualToRect(rootContainer.frame, rootFrame))
        rootContainer.frame = rootFrame;

    for (UIView *container in containers)
    {
        container.clipsToBounds = false;
        if (container != rootContainer && !CGRectEqualToRect(container.frame, container.superview.bounds))
            container.frame = container.superview.bounds;
    }
    if (!CGRectEqualToRect(contentView.frame, contentView.superview.bounds))
        contentView.frame = contentView.superview.bounds;
}

- (void)setIgnoreKeyboardFrameChange:(bool)ignoreKeyboardFrameChange restoringFocus:(bool)restoringFocus
{
    _ignoreKeyboardFrameChange = ignoreKeyboardFrameChange;
    
    if (!ignoreKeyboardFrameChange && !restoringFocus)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
        {
            [self _updateForKeyboardHeight:_keyboardHeight];
        } completion:nil];
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)newInset
{
    _keyboardHeight = newInset.bottom;
    
    if (_ignoreKeyboardFrameChange)
        return;
    
    [self _updateForKeyboardHeight:_keyboardHeight];
}

- (void)_updateForKeyboardHeight:(CGFloat)keyboardHeight
{
    _customTabBar.frame = CGRectMake(0.0f, self.view.frame.size.height - [TGTabBar tabBarHeight:false] - keyboardHeight, self.view.frame.size.width, [TGTabBar tabBarHeight:false]);
    
    if (self.onControllerInsetUpdated != nil)
        self.onControllerInsetUpdated(keyboardHeight);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (iosMajorVersion() < 6)
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    
    return [TGViewController autorotationAllowed] && (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    return [TGViewController autorotationAllowed];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    if (self.selectedViewController == nil)
        return UIBarStyleDefault;
    else if ([self.selectedViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
        return [(id<TGViewControllerNavigationBarAppearance>)self.selectedViewController requiredNavigationBarStyle];
    else
        return UIBarStyleDefault;
}

- (TGNavigationBarBackgroundVariant)navigationBarBackgroundVariant
{
    UIViewController *selectedViewController = self.selectedViewController;
    if ([selectedViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [selectedViewController respondsToSelector:@selector(navigationBarBackgroundVariant)])
        return [(id<TGViewControllerNavigationBarAppearance>)selectedViewController navigationBarBackgroundVariant];
    return TGNavigationBarBackgroundVariantDefault;
}

- (bool)navigationBarShouldBeHidden
{
    if (self.selectedViewController == nil)
        return false;
    else if ([self.selectedViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
        return [(id<TGViewControllerNavigationBarAppearance>)self.selectedViewController navigationBarShouldBeHidden];
    else
        return false;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.view layoutIfNeeded];
    [self layoutCustomTabBar];
    if (!_initialized)
    {
        _initialized = true;
        if (_startupSingleControllerMode)
        {
            [self _updateNavigationItemOverride:0];
            [_customTabBar setSelectedIndex:(int)_startupLogicalIndex];
        }
        else if (self.viewControllers.count > 2)
            [self setSelectedIndex:2];
    }
    if (self.debugReady != nil)
        self.debugReady();
    [super viewWillAppear:animated];
    [self layoutSelectedContentUnderTabBar];
}

- (BOOL)tabBarController:(UITabBarController *)__unused tabBarController shouldSelectViewController:(UIViewController *)viewController
{
    if (viewController == self.selectedViewController)
        return false;
    
    return true;
}

- (void)tabBarLongPressedItem:(int)index
{
    int selectedLogicalIndex = _startupSingleControllerMode ? (int)_startupLogicalIndex : (int)self.selectedIndex;
    if (selectedLogicalIndex == index)
    {
        if ([self.selectedViewController respondsToSelector:@selector(scrollToTop)])
            [self.selectedViewController performSelector:@selector(scrollToTop)];
    }
}

- (void)tabBarSelectedItem:(int)index
{
    int selectedLogicalIndex = _startupSingleControllerMode ? (int)_startupLogicalIndex : (int)self.selectedIndex;
    if (selectedLogicalIndex != index)
    {
        OGRuntimeCompleteStartupPhase(@"tab");
        if (![self prepareStartupControllersForLogicalIndex:(NSUInteger)index])
            return;

        bool constrained = OGPlatformUsesConstrainedBackgroundExecution();
        if (constrained)
            OGRuntimeBeginInteraction();
        [self tabBarController:self shouldSelectViewController:[self.viewControllers objectAtIndex:index]];
        [self setSelectedIndex:index];
        if (constrained)
        {
            OGPlatformDispatchAfterCurrentMainRunLoop(^
            {
                OGRuntimeEndInteraction();
            });
        }
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([self.selectedViewController respondsToSelector:@selector(scrollToTopRequested)])
            [self.selectedViewController performSelector:@selector(scrollToTopRequested)];
#pragma clang diagnostic pop
    }
    
    if (index == 3) {
        NSTimeInterval t = CACurrentMediaTime();
        if (_lastSameIndexTapTime < DBL_EPSILON || t < _lastSameIndexTapTime + 0.5) {
            _lastSameIndexTapTime = t;
            _tapsInSuccession++;
            if (_tapsInSuccession == 10) {
                _tapsInSuccession = 0;
                _lastSameIndexTapTime = 0.0;
                
                [TGAppDelegateInstance.rootController pushContentController:[[TGDebugController alloc] init]];
            }
        } else {
            _lastSameIndexTapTime = 0.0;
            _tapsInSuccession = 0;
        }
    }
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    if (_startupSingleControllerMode)
    {
        if (selectedIndex == _startupLogicalIndex)
        {
            [self _updateNavigationItemOverride:0];
            [_customTabBar setSelectedIndex:(int)_startupLogicalIndex];
            return;
        }
        if (![self prepareStartupControllersForLogicalIndex:selectedIndex])
            return;
    }

    [super setSelectedIndex:selectedIndex];
    [self _updateNavigationItemOverride:selectedIndex];
    [_customTabBar setSelectedIndex:(int)selectedIndex];
    [self layoutSelectedContentUnderTabBar];
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    NSUInteger logicalSelectedIndex = [self logicalSelectedIndex];
    if (_startupSingleControllerMode && viewControllers.count > 1)
    {
        return;
    }

    [super setViewControllers:viewControllers animated:animated];

    if (logicalSelectedIndex < viewControllers.count)
        [super setSelectedIndex:logicalSelectedIndex];

    [self _updateNavigationItemOverride:logicalSelectedIndex];
    [_customTabBar setSelectedIndex:(int)logicalSelectedIndex];
    [self layoutSelectedContentUnderTabBar];
}

- (void)_updateNavigationItemOverride:(NSUInteger)selectedIndex
{
    int index = -1;
    for (UIViewController *viewController in self.viewControllers)
    {
        index++;
        
        if ([viewController isKindOfClass:[TGViewController class]])
        {
            if (index == (int)selectedIndex)
                [(TGViewController *)viewController setTargetNavigationItem:self.navigationItem titleController:self];
            else
                [(TGViewController *)viewController setTargetNavigationItem:nil titleController:nil];
        }
    }

    if ([self.navigationController isKindOfClass:[TGNavigationController class]] && self.navigationController.topViewController == self)
        [(TGNavigationController *)self.navigationController updateNavigationBarBackgroundForController:self];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];

    if (iosMajorVersion() < 5)
    {
        UILabel *titleLabel = nil;
        if ([self.navigationItem.titleView isKindOfClass:[UILabel class]] && self.navigationItem.titleView.tag == TGMainTabsClassicIOS4TitleTag)
            titleLabel = (UILabel *)self.navigationItem.titleView;
        else if (self.navigationItem.titleView == nil)
        {
            titleLabel = [[UILabel alloc] init];
            titleLabel.tag = TGMainTabsClassicIOS4TitleTag;
            self.navigationItem.titleView = titleLabel;
        }

        if (titleLabel != nil)
            TGMainTabsConfigureClassicIOS4TitleLabel(titleLabel, title, _presentation);
    }
    
    bool constrainedStartup = OGPlatformUsesConstrainedBackgroundExecution();
    NSString *dialogListTitle = constrainedStartup ? TGStartupLocalized(@"DialogList.Title") : TGLocalized(@"DialogList.Title");
    NSString *backTitle = title == nil || ![title isEqualToString:dialogListTitle] ? (constrainedStartup ? TGStartupLocalized(@"Common.Back") : TGLocalized(@"Common.Back")) : title;
    
    if (!TGStringCompare(self.navigationItem.backBarButtonItem.title, backTitle))
        self.navigationItem.backBarButtonItem.title = backTitle;
}

- (void)setCallsHidden:(bool)hidden animated:(bool)animated
{
    if ([TGPresentation classicIOS6Style] && ![TGPresentation brandedIOS6Style])
        hidden = true;
    _callsHidden = hidden;
    [_customTabBar setCallsTabHidden:hidden animated:animated];
}

- (void)setContactsHidden:(bool)hidden animated:(bool)animated
{
    _contactsHidden = hidden;
    [_customTabBar setContactsTabHidden:hidden animated:animated];
    if (hidden && [self logicalSelectedIndex] == 0)
        [self setSelectedIndex:2];
}

- (void)setMissedCallsCount:(int)callsCount
{
    _missedCallsCount = callsCount;
    [_customTabBar setMissedCallsCount:callsCount];
}

- (void)setUnreadArrow:(NSNumber *)up
{
    [_customTabBar setUnreadArrowUp:up];
}

- (void)setUnreadCount:(int)unreadCount
{
    _unreadCount = unreadCount;
    [_customTabBar setUnreadCount:_unreadCount];
}

- (void)localizationUpdated
{
    _customTabBar.tabDelegate = nil;
    [_customTabBar removeFromSuperview];
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation];
    CGFloat inset = 0.0f;
    if (iosMajorVersion() >= 11 && safeAreaInset.bottom > FLT_EPSILON)
        inset = safeAreaInset.bottom;
    
    bool landscape = !TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape(orientation);
    _customTabBar = [[TGTabBar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - [TGTabBar tabBarHeight:landscape] - inset, self.view.frame.size.width, [TGTabBar tabBarHeight:landscape] + inset) presentation:_presentation];
    _customTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _customTabBar.safeAreaInset = safeAreaInset;
    _customTabBar.landscape = landscape;
    _customTabBar.tabDelegate = self;
    [self.view insertSubview:_customTabBar aboveSubview:self.tabBar];
    
    [_customTabBar setSelectedIndex:(int)self.selectedIndex];
    [_customTabBar setCallsTabHidden:_callsHidden animated:false];
    [_customTabBar setContactsTabHidden:_contactsHidden animated:false];
    [_customTabBar setMissedCallsCount:_missedCallsCount];
    [_customTabBar setUnreadCount:_unreadCount];
    
    for (TGViewController *controller in self.viewControllers)
    {
        [controller localizationUpdated];
    }
    
    [_customTabBar layoutSubviews];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:completion];
    [self.navigationController setToolbarHidden:true animated:false];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (!TGAppDelegateInstance.rootController.callStatusBarHidden)
        return UIStatusBarStyleLightContent;
    else {
        if (iosMajorVersion() >= 7) {
            return _presentation.pallete.isDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
        } else {
            return UIStatusBarStyleDefault;
        }
    }
}

- (CGRect)frameForRightmostTab {
    return [(TGTabBarButton *)_customTabBar.tabButtons.lastObject frame];
}

- (UIView *)viewForRightmostTab {
    return _customTabBar.tabButtons.lastObject;
}

@end
