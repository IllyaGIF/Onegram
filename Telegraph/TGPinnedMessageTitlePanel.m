#import "TGPinnedMessageTitlePanel.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMenuSheetController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import <QuartzCore/QuartzCore.h>

#import "TGModenConcersationReplyAssociatedPanel.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"
#import "../OnegramUI/Core/OGSurfaceStyle.h"
#import "../OnegramUI/Core/OGMusicPlayerAppearance.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSurfaceRenderer.h"

static UIImage *OGPinnedPanelClassicBackdrop(void)
{
    static UIImage *cachedBackdrop = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize canvas = CGSizeMake(2.0f, 29.0f);
        UIGraphicsBeginImageContextWithOptions(canvas, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();

        CGFloat stops[] = {0.0f, 0.48f, 1.0f};
        NSArray *gradientColors = @[(id)UIColorRGB(0xf8fafc).CGColor, (id)UIColorRGB(0xdce2e8).CGColor, (id)UIColorRGB(0xaeb8c2).CGColor];
        CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(rgbSpace, (__bridge CFArrayRef)gradientColors, stops);
        if (context != NULL)
        {
            CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0f, canvas.height), 0);
        }

        CGGradientRelease(gradient);
        CGColorSpaceRelease(rgbSpace);

        CGFloat lineOffsets[] = {0.0f, canvas.height - 1.0f, canvas.height - 2.0f};
        UIColor *lineColors[] = {UIColorRGBA(0xffffff, 0.9f), UIColorRGB(0x6d7884), UIColorRGBA(0xffffff, 0.35f)};
        for (int lineIndex = 0; lineIndex < 3; lineIndex++)
        {
            CGContextSetFillColorWithColor(context, lineColors[lineIndex].CGColor);
            CGContextFillRect(context, CGRectMake(0.0f, lineOffsets[lineIndex], canvas.width, 1.0f));
        }

        cachedBackdrop = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return cachedBackdrop;
}

static UIImage *OGPinnedPanelThemedBackdrop(UIColor *tint)
{
    return [TGPresentation classicIOS6ThemedImage:OGPinnedPanelClassicBackdrop() tintColor:tint alpha:0.85f];
}

static UIColor *OGPinnedPanelRuleColor(UIColor *paletteColor, UIColor *regularColor)
{
    if (![TGPresentation classicThemeStyle])
        return regularColor;
    return [TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? paletteColor : UIColorRGB(0x6d7884);
}

static UIColor *OGPinnedPanelFillColor(UIColor *regularColor)
{
    return [TGPresentation classicThemeStyle] ? [UIColor clearColor] : regularColor;
}

static UILabel *OGPinnedMenuLabel(UIFont *font, UIColor *textColor)
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.font = font;
    label.textColor = textColor;
    return label;
}

static UILabel *OGPinnedMenuBadgeLabel(NSInteger number, CGFloat minimumScale)
{
    UILabel *label = OGPinnedMenuLabel(TGMediumSystemFontOfSize(12.0f), [UIColor whiteColor]);
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"%d", (int)number];
    label.adjustsFontSizeToFitWidth = true;
    if ([label respondsToSelector:@selector(setMinimumScaleFactor:)])
        OGPlatformSetLabelMinimumScaleFactor(label, minimumScale);
    else
        label.minimumFontSize = label.font.pointSize * minimumScale;
    return label;
}

static UIView *OGPinnedMenuBadgeBackground(CGFloat radius)
{
    UIView *badge = [[UIView alloc] init];
    badge.userInteractionEnabled = false;
    badge.backgroundColor = TGAccentColor();
    badge.layer.cornerRadius = radius;
    return badge;
}

static CGRect OGPinnedMenuRuleFrame(CGRect bounds, CGFloat leadingInset)
{
    return CGRectMake(leadingInset, bounds.size.height - TGScreenPixel, bounds.size.width - leadingInset, TGScreenPixel);
}

@interface OGPinnedChevronView : UIView

@property (nonatomic, strong) UIColor *strokeColor;

@end


@implementation OGPinnedChevronView

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        self.backgroundColor = [UIColor clearColor];
        _strokeColor = UIColorRGB(0xb5b5b5);
    }
    return self;
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint tip[] = {CGPointMake(1.0f, 1.0f), CGPointMake(6.0f, 7.0f), CGPointMake(1.0f, 13.0f)};
    CGContextSetStrokeColorWithColor(context, _strokeColor.CGColor);
    CGContextSetLineWidth(context, 1.5f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextAddLines(context, tip, 3);
    CGContextStrokePath(context);
}

@end


@interface TGPinnedMessagesMenuHeaderItemView ()
{
    UIView *_countBadge;
    UILabel *_headlineLabel;
    UILabel *_countText;
    UIView *_bottomRule;
}

@end


@implementation TGPinnedMessagesMenuHeaderItemView

- (instancetype)initWithMessageCount:(NSUInteger)messageCount
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        NSString *headline = TGLocalized(@"Channel.AdminLogFilter.EventsPinned");
        if ([headline isEqualToString:@"Channel.AdminLogFilter.EventsPinned"])
            headline = TGLocalized(@"Conversation.PinnedMessage");

        _headlineLabel = OGPinnedMenuLabel(TGMediumSystemFontOfSize(17.0f), UIColorRGB(0x222222));
        _headlineLabel.text = headline;
        _headlineLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_headlineLabel];

        _countBadge = OGPinnedMenuBadgeBackground(12.0f);
        [self addSubview:_countBadge];

        _countText = OGPinnedMenuBadgeLabel((NSInteger)messageCount, 0.7f);
        [_countBadge addSubview:_countText];

        _bottomRule = [[UIView alloc] init];
        _bottomRule.backgroundColor = UIColorRGB(0xd9d9d9);
        [self addSubview:_bottomRule];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    static const CGFloat headerHeight = 52.0f;
    return headerHeight;
}

- (bool)requiresDivider
{
    return false;
}

- (void)setDark
{
    _headlineLabel.textColor = [UIColor whiteColor];
    _bottomRule.backgroundColor = UIColorRGB(0x383838);
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _headlineLabel.textColor = pallete.textColor;
    _countBadge.backgroundColor = pallete.accentColor;
    _bottomRule.backgroundColor = pallete.separatorColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect area = self.bounds;
    CGFloat diameter = 24.0f;
    _countBadge.frame = CGRectMake(area.size.width - 16.0f - diameter, 14.0f, diameter, diameter);
    _countBadge.layer.cornerRadius = diameter / 2.0f;
    _countText.frame = _countBadge.bounds;
    _headlineLabel.frame = CGRectMake(16.0f, 0.0f, area.size.width - 16.0f - diameter - 26.0f, area.size.height);
    _bottomRule.frame = OGPinnedMenuRuleFrame(area, 16.0f);
}

@end


@interface TGPinnedMessageMenuItemView ()
{
    UIView *_indexBadge;
    UILabel *_indexText;
    UILabel *_bodyLabel;
    OGPinnedChevronView *_disclosureView;
    UIView *_bottomRule;
}

@end


@implementation TGPinnedMessageMenuItemView

- (instancetype)initWithTitle:(NSString *)title index:(NSUInteger)index action:(void (^)(void))action
{
    self = [super initWithTitle:@"" type:TGMenuSheetButtonTypeDefault action:action];
    if (self != nil)
    {
        _button.titleLabel.adjustsFontSizeToFitWidth = false;
        _button.accessibilityLabel = title;

        _indexBadge = OGPinnedMenuBadgeBackground(14.0f);
        [self addSubview:_indexBadge];

        _indexText = OGPinnedMenuBadgeLabel((int)index + 1, 0.65f);
        [_indexBadge addSubview:_indexText];

        _bodyLabel = OGPinnedMenuLabel(TGSystemFontOfSize(15.5f), UIColorRGB(0x222222));
        _bodyLabel.userInteractionEnabled = false;
        _bodyLabel.numberOfLines = 2;
        _bodyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _bodyLabel.text = title;
        [self addSubview:_bodyLabel];

        _disclosureView = [[OGPinnedChevronView alloc] init];
        [self addSubview:_disclosureView];

        _bottomRule = [[UIView alloc] init];
        _bottomRule.userInteractionEnabled = false;
        _bottomRule.backgroundColor = UIColorRGB(0xd9d9d9);
        [self addSubview:_bottomRule];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    static const CGFloat rowHeight = 64.0f;
    return rowHeight;
}

- (bool)requiresDivider
{
    return false;
}

- (void)setDark
{
    [super setDark];
    _bodyLabel.textColor = [UIColor whiteColor];
    _bottomRule.backgroundColor = UIColorRGB(0x383838);
    _disclosureView.strokeColor = UIColorRGB(0x666666);
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    [super setPallete:pallete];
    _bodyLabel.textColor = pallete.textColor;
    _indexBadge.backgroundColor = pallete.accentColor;
    _bottomRule.backgroundColor = pallete.separatorColor;
    _disclosureView.strokeColor = pallete.secondaryTextColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect area = self.bounds;
    CGFloat diameter = 28.0f;
    _indexBadge.frame = CGRectMake(14.0f, floor((area.size.height - diameter) / 2.0f), diameter, diameter);
    _indexBadge.layer.cornerRadius = diameter / 2.0f;
    _indexText.frame = _indexBadge.bounds;
    _bodyLabel.frame = CGRectMake(54.0f, 8.0f, area.size.width - 54.0f - 34.0f, area.size.height - 16.0f);
    _disclosureView.frame = CGRectMake(area.size.width - 21.0f, floor((area.size.height - 14.0f) / 2.0f), 8.0f, 14.0f);
    _bottomRule.frame = OGPinnedMenuRuleFrame(area, 54.0f);
}

@end

@interface TGPinnedMessageTitlePanel () {
    TGModenConcersationReplyAssociatedPanel *_replyPanel;
    UIView *_bottomRule;
    UIImageView *_classicBackdropView;
    UIView *_brandedBackgroundClipView;
    UIImageView *_brandedBackgroundView;
    UIImageView *_brandedIndicatorView;
    UIImageView *_brandedBubbleView;
    UIImageView *_brandedIconView;
    UILabel *_brandedTextLabel;
    UIButton *_brandedCloseButton;
    UIImageView *_compactChevronView;
    CGSize _brandedBackgroundSize;
    CGFloat _brandedBubbleWidth;
}

@end

@implementation TGPinnedMessageTitlePanel

- (instancetype)initWithMessage:(TGMessage *)message {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, [TGPresentation brandedIOS6PinnedPanelAvailable] ? [TGPresentation brandedIOS6PinnedPanelHeight] : 29.0f)];
    if (self != nil) {
        _message = message;
        self.layer.masksToBounds = true;

        _classicBackdropView = [[UIImageView alloc] initWithImage:OGPinnedPanelThemedBackdrop(TGPresentation.current.pallete.barBackgroundColor)];
        _classicBackdropView.userInteractionEnabled = false;
        _classicBackdropView.hidden = ![TGPresentation classicThemeStyle];
        [self addSubview:_classicBackdropView];
        
        _replyPanel = [[TGModenConcersationReplyAssociatedPanel alloc] initWithMessage:message];
        [_replyPanel setCompactMode:true];
        [_replyPanel setSendAreaWidth:14.0f - TGRetinaPixel attachmentAreaWidth:6.0f];
        _replyPanel.largeDismissButton = true;
        __weak TGPinnedMessageTitlePanel *weakSelf = self;
        _replyPanel.pressed = ^{
            __strong TGPinnedMessageTitlePanel *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_tapped) {
                strongSelf->_tapped();
            }
        };
        _replyPanel.dismiss = ^{
            __strong TGPinnedMessageTitlePanel *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.dismiss) {
                strongSelf.dismiss();
            }
        };
        [self addSubview:_replyPanel];
        self.backgroundColor = OGPinnedPanelFillColor(UIColorRGB(0xf7f7f7));
        
        _bottomRule = [[UIView alloc] init];
        _bottomRule.backgroundColor = OGPinnedPanelRuleColor(TGPresentation.current.pallete.barSeparatorColor, TGSeparatorColor());
        [self addSubview:_bottomRule];

        _brandedBackgroundClipView = [[UIView alloc] init];
        _brandedBackgroundClipView.userInteractionEnabled = false;
        _brandedBackgroundClipView.clipsToBounds = true;
        [self addSubview:_brandedBackgroundClipView];

        _brandedBackgroundView = [[UIImageView alloc] init];
        _brandedBackgroundView.userInteractionEnabled = false;
        [_brandedBackgroundClipView addSubview:_brandedBackgroundView];

        _compactChevronView = [[UIImageView alloc] init];
        _compactChevronView.hidden = true;
        [self addSubview:_compactChevronView];

        _brandedIndicatorView = [[UIImageView alloc] init];
        _brandedIndicatorView.userInteractionEnabled = false;
        [self addSubview:_brandedIndicatorView];

        _brandedBubbleView = [[UIImageView alloc] init];
        _brandedBubbleView.userInteractionEnabled = false;
        [self addSubview:_brandedBubbleView];

        _brandedTextLabel = [[UILabel alloc] init];
        _brandedTextLabel.backgroundColor = [UIColor clearColor];
        _brandedTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _brandedTextLabel.numberOfLines = 1;
        _brandedTextLabel.userInteractionEnabled = false;
        [self addSubview:_brandedTextLabel];

        _brandedIconView = [[UIImageView alloc] init];
        _brandedIconView.userInteractionEnabled = false;
        [self addSubview:_brandedIconView];

        _brandedCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_brandedCloseButton addTarget:self action:@selector(brandedClosePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_brandedCloseButton];

        [self updateBrandedStyle];
        
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
    }
    return self;
}

- (void)setJoinsPreviousHeader:(bool)joinsPreviousHeader
{
    if (_joinsPreviousHeader != joinsPreviousHeader)
    {
        _joinsPreviousHeader = joinsPreviousHeader;
        _brandedBackgroundSize = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)setCompactHeader:(bool)compactHeader
{
    if (_compactHeader != compactHeader)
    {
        _compactHeader = compactHeader;
        [self updateBrandedStyle];
    }
}

- (void)updateBrandedStyle
{
    bool brandedStyle = [TGPresentation brandedIOS6PinnedPanelAvailable];
    _brandedBackgroundView.hidden = !brandedStyle;
    _brandedIndicatorView.hidden = !brandedStyle || _compactHeader;
    _brandedBubbleView.hidden = !brandedStyle || _compactHeader;
    _brandedTextLabel.hidden = !brandedStyle;
    _brandedIconView.hidden = !brandedStyle || _compactHeader;
    _brandedCloseButton.hidden = !brandedStyle || _compactHeader;
    _compactChevronView.hidden = !brandedStyle || !_compactHeader;
    _replyPanel.hidden = brandedStyle;
    _bottomRule.hidden = brandedStyle;
    _brandedBackgroundSize = CGSizeZero;
    _brandedBubbleWidth = 0.0f;
    if (!brandedStyle)
        return;

    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    _classicBackdropView.hidden = true;
    [self setBackgroundColor:[UIColor clearColor]];
    _brandedIndicatorView.image = [TGPresentation brandedIOS6PinnedIndicatorImage];
    _brandedIconView.image = [TGPresentation brandedIOS6PinnedIconImage];
    [_brandedCloseButton setImage:[TGPresentation brandedIOS6PinnedCloseImage] forState:UIControlStateNormal];
    _brandedTextLabel.font = appearance.pinnedTextFont;
    _brandedTextLabel.textColor = appearance.pinnedTextColor;
    _brandedTextLabel.shadowColor = appearance.pinnedTextShadowColor;
    _brandedTextLabel.shadowOffset = appearance.pinnedTextShadowOffset;
    _brandedTextLabel.text = _replyPanel.contentText;

    CGRect frame = self.frame;
    frame.size.height = _compactHeader ? 21.0f : [TGPresentation brandedIOS6PinnedPanelHeight];
    if (_compactHeader)
    {
        OGMusicPlayerAppearance *compactAppearance = [OGMusicPlayerAppearance conversationAppearanceDark:[OGTheme brandedTheme].dark compact:YES];
        _brandedTextLabel.font = compactAppearance.font;
        _brandedTextLabel.textColor = compactAppearance.titleColor;
        _brandedTextLabel.textAlignment = NSTextAlignmentCenter;
        _brandedTextLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
        _brandedTextLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _compactChevronView.image = [compactAppearance imageForGlyph:OGMusicPlayerGlyphChevron];
    }
    else
        _brandedTextLabel.textAlignment = NSTextAlignmentLeft;
    self.frame = frame;
    [self setNeedsLayout];
}

- (void)brandedClosePressed
{
    if (_dismiss)
        _dismiss();
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    BOOL classicLook = [TGPresentation classicThemeStyle];
    _classicBackdropView.hidden = !classicLook;
    if (classicLook)
        _classicBackdropView.image = OGPinnedPanelThemedBackdrop(presentation.pallete.barBackgroundColor);
    self.backgroundColor = OGPinnedPanelFillColor(presentation.pallete.barBackgroundColor);
    _bottomRule.backgroundColor = OGPinnedPanelRuleColor(presentation.pallete.barSeparatorColor, presentation.pallete.barSeparatorColor);
    _replyPanel.pallete = presentation.associatedInputPanelPallete;
    [self updateBrandedStyle];
}

- (void)updateMessage:(TGMessage *)message {
    _message = message;
    [_replyPanel updateMessage:message];
    _brandedTextLabel.text = _replyPanel.contentText;
}

- (void)setMessageCount:(NSUInteger)messageCount {
    NSString *countPrefix = nil;
    if (messageCount > 1)
        countPrefix = [NSString stringWithFormat:@"%d", (int)messageCount];
    _replyPanel.compactPrefix = countPrefix;
    _brandedTextLabel.text = _replyPanel.contentText;
}

- (void)layoutBrandedContent
{
    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    CGFloat bodyX = appearance.backgroundCardHorizontalInset + self.safeAreaInset.left;
    CGFloat bodyWidth = MAX(0.0f, self.bounds.size.width - appearance.backgroundCardHorizontalInset * 2.0f - self.safeAreaInset.left - self.safeAreaInset.right);
    _brandedBackgroundClipView.frame = CGRectMake(bodyX, 0.0f, bodyWidth, self.bounds.size.height);
    if (_compactHeader)
    {
        OGMusicPlayerAppearance *compactAppearance = [OGMusicPlayerAppearance conversationAppearanceDark:[OGTheme brandedTheme].dark compact:YES];
        CGSize compactSize = CGSizeMake(bodyWidth, compactAppearance.height);
        if (!CGSizeEqualToSize(_brandedBackgroundSize, compactSize))
        {
            _brandedBackgroundSize = compactSize;
            _brandedBackgroundView.image = [[OGTheme brandedTheme].surfaceRenderer imageWithStyle:compactAppearance.backgroundSurfaceStyle size:compactSize bodyFrame:CGRectMake(0.0f, 0.0f, compactSize.width, compactSize.height)];
        }
        _brandedBackgroundView.frame = CGRectMake(0.0f, 0.0f, compactSize.width, compactSize.height);
        _brandedTextLabel.frame = CGRectMake(bodyX + (bodyWidth - 130.0f) / 2.0f, 4.0f, 130.0f, 17.0f);
        _compactChevronView.frame = CGRectMake(bodyX + 8.0f, 9.0f, 13.0f, 9.0f);
        return;
    }
    CGSize bodySize = CGSizeMake(bodyWidth, appearance.pinnedPanelHeight);

    UIEdgeInsets backgroundOutsets = UIEdgeInsetsZero;
    if (!CGSizeEqualToSize(_brandedBackgroundSize, bodySize))
    {
        _brandedBackgroundSize = bodySize;
        _brandedBackgroundView.image = [TGPresentation brandedIOS6PinnedPanelImageForSize:bodySize joinedHeader:_joinsPreviousHeader outsets:&backgroundOutsets];
    }
    else if (appearance.pinnedPanelSurfaceStyle != nil)
    {
        backgroundOutsets = [appearance.pinnedPanelSurfaceStyle dropShadowOutsets];
        backgroundOutsets = UIEdgeInsetsMake(ceilf(backgroundOutsets.top), ceilf(backgroundOutsets.left), ceilf(backgroundOutsets.bottom), ceilf(backgroundOutsets.right));
    }
    _brandedBackgroundView.frame = CGRectMake(-backgroundOutsets.left, -backgroundOutsets.top, bodySize.width + backgroundOutsets.left + backgroundOutsets.right, bodySize.height + backgroundOutsets.top + backgroundOutsets.bottom);

    CGRect indicatorFrame = appearance.pinnedIndicatorFrame;
    _brandedIndicatorView.frame = CGRectOffset(indicatorFrame, bodyX, 0.0f);

    CGFloat bubbleWidth = MAX(0.0f, bodyWidth - appearance.pinnedBubbleLeft - appearance.pinnedBubbleRightInset);
    UIEdgeInsets bubbleInsets = appearance.pinnedBubbleImageInsets;
    if (ABS(_brandedBubbleWidth - bubbleWidth) > FLT_EPSILON)
    {
        _brandedBubbleWidth = bubbleWidth;
        _brandedBubbleView.image = [TGPresentation brandedIOS6PinnedBubbleImageForWidth:bubbleWidth outsets:&bubbleInsets];
    }
    CGRect bubbleFrame = CGRectMake(bodyX + appearance.pinnedBubbleLeft, appearance.pinnedBubbleTop, bubbleWidth, appearance.pinnedBubbleHeight);
    _brandedBubbleView.frame = CGRectMake(bubbleFrame.origin.x - bubbleInsets.left, bubbleFrame.origin.y - bubbleInsets.top, bubbleFrame.size.width + bubbleInsets.left + bubbleInsets.right, bubbleFrame.size.height + bubbleInsets.top + bubbleInsets.bottom);

    UIEdgeInsets textInsets = appearance.pinnedTextInsets;
    _brandedTextLabel.frame = CGRectMake(CGRectGetMinX(bubbleFrame) + textInsets.left, CGRectGetMinY(bubbleFrame) + textInsets.top, MAX(0.0f, bubbleFrame.size.width - textInsets.left - textInsets.right), MAX(0.0f, bubbleFrame.size.height - textInsets.top - textInsets.bottom));

    CGSize iconSize = appearance.pinnedIconSize;
    _brandedIconView.frame = CGRectMake(bodyX + bodyWidth - appearance.pinnedIconRightInset - iconSize.width, appearance.pinnedIconTop, iconSize.width, iconSize.height);

    CGSize closeSize = appearance.pinnedCloseSize;
    _brandedCloseButton.frame = CGRectMake(bodyX + bodyWidth - appearance.pinnedCloseRightInset - closeSize.width, appearance.pinnedCloseTop, closeSize.width, closeSize.height);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat separatorHeight = TGScreenPixel;
    _bottomRule.frame = CGRectMake(0.0f, self.frame.size.height - separatorHeight, self.frame.size.width, separatorHeight);
    _classicBackdropView.frame = self.bounds;
    
    UIEdgeInsets insets = self.safeAreaInset;
    _replyPanel.frame = CGRectMake(insets.left, 0.0f, self.frame.size.width - insets.left - insets.right, 28.0f);

    if ([TGPresentation brandedIOS6PinnedPanelAvailable])
        [self layoutBrandedContent];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (_compactHeader && _compactHeaderActivated != nil)
        {
            _compactHeaderActivated();
            return;
        }
        if (_tapped) {
            _tapped();
        }
    }
}

@end
