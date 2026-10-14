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

static UIImage *TGClassicIOS6PinnedPanelBackgroundImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize size = CGSizeMake(2.0f, 29.0f);
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
        CGContextSetFillColorWithColor(context, UIColorRGB(0x6d7884).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, size.height - 1.0f, size.width, 1.0f));
        CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.35f).CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, size.height - 2.0f, size.width, 1.0f));

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@interface TGPinnedMessageChevronView : UIView
{
    UIColor *_color;
}

@property (nonatomic, strong) UIColor *color;

@end


@implementation TGPinnedMessageChevronView

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = false;
        _color = UIColorRGB(0xb5b5b5);
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    [self setNeedsDisplay];
}

- (UIColor *)color
{
    return _color;
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, _color.CGColor);
    CGContextSetLineWidth(context, 1.5f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextMoveToPoint(context, 1.0f, 1.0f);
    CGContextAddLineToPoint(context, 6.0f, 7.0f);
    CGContextAddLineToPoint(context, 1.0f, 13.0f);
    CGContextStrokePath(context);
}

@end


@interface TGPinnedMessagesMenuHeaderItemView ()
{
    UILabel *_titleLabel;
    UIView *_countBackgroundView;
    UILabel *_countLabel;
    UIView *_separatorView;
}

@end


@implementation TGPinnedMessagesMenuHeaderItemView

- (instancetype)initWithMessageCount:(NSUInteger)messageCount
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        NSString *title = TGLocalized(@"Channel.AdminLogFilter.EventsPinned");
        if ([title isEqualToString:@"Channel.AdminLogFilter.EventsPinned"])
            title = TGLocalized(@"Conversation.PinnedMessage");

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGMediumSystemFontOfSize(17.0f);
        _titleLabel.textColor = UIColorRGB(0x222222);
        _titleLabel.text = title;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _countBackgroundView = [[UIView alloc] init];
        _countBackgroundView.userInteractionEnabled = false;
        _countBackgroundView.backgroundColor = TGAccentColor();
        _countBackgroundView.layer.cornerRadius = 12.0f;
        [self addSubview:_countBackgroundView];

        _countLabel = [[UILabel alloc] init];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.font = TGMediumSystemFontOfSize(12.0f);
        _countLabel.textColor = [UIColor whiteColor];
        _countLabel.textAlignment = NSTextAlignmentCenter;
        _countLabel.text = [NSString stringWithFormat:@"%d", (int)messageCount];
        _countLabel.adjustsFontSizeToFitWidth = true;
        if ([_countLabel respondsToSelector:@selector(setMinimumScaleFactor:)])
            OGPlatformSetLabelMinimumScaleFactor(_countLabel, 0.7f);
        else
            _countLabel.minimumFontSize = _countLabel.font.pointSize * 0.7f;
        [_countBackgroundView addSubview:_countLabel];

        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = UIColorRGB(0xd9d9d9);
        [self addSubview:_separatorView];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    return 52.0f;
}

- (bool)requiresDivider
{
    return false;
}

- (void)setDark
{
    _titleLabel.textColor = [UIColor whiteColor];
    _separatorView.backgroundColor = UIColorRGB(0x383838);
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _titleLabel.textColor = pallete.textColor;
    _countBackgroundView.backgroundColor = pallete.accentColor;
    _separatorView.backgroundColor = pallete.separatorColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat countSize = 24.0f;
    _countBackgroundView.frame = CGRectMake(self.bounds.size.width - 16.0f - countSize, 14.0f, countSize, countSize);
    _countBackgroundView.layer.cornerRadius = countSize / 2.0f;
    _countLabel.frame = _countBackgroundView.bounds;
    _titleLabel.frame = CGRectMake(16.0f, 0.0f, self.bounds.size.width - 16.0f - countSize - 26.0f, self.bounds.size.height);
    _separatorView.frame = CGRectMake(16.0f, self.bounds.size.height - TGScreenPixel, self.bounds.size.width - 16.0f, TGScreenPixel);
}

@end


@interface TGPinnedMessageMenuItemView ()
{
    UIView *_indexBackgroundView;
    UILabel *_indexLabel;
    UILabel *_messageLabel;
    TGPinnedMessageChevronView *_chevronView;
    UIView *_separatorView;
}

@end


@implementation TGPinnedMessageMenuItemView

- (instancetype)initWithTitle:(NSString *)title index:(NSUInteger)index action:(void (^)(void))action
{
    self = [super initWithTitle:@"" type:TGMenuSheetButtonTypeDefault action:action];
    if (self != nil)
    {
        _button.accessibilityLabel = title;
        _button.titleLabel.adjustsFontSizeToFitWidth = false;

        _indexBackgroundView = [[UIView alloc] init];
        _indexBackgroundView.userInteractionEnabled = false;
        _indexBackgroundView.backgroundColor = TGAccentColor();
        _indexBackgroundView.layer.cornerRadius = 14.0f;
        [self addSubview:_indexBackgroundView];

        _indexLabel = [[UILabel alloc] init];
        _indexLabel.backgroundColor = [UIColor clearColor];
        _indexLabel.font = TGMediumSystemFontOfSize(12.0f);
        _indexLabel.textColor = [UIColor whiteColor];
        _indexLabel.textAlignment = NSTextAlignmentCenter;
        _indexLabel.text = [NSString stringWithFormat:@"%d", (int)index + 1];
        _indexLabel.adjustsFontSizeToFitWidth = true;
        if ([_indexLabel respondsToSelector:@selector(setMinimumScaleFactor:)])
            OGPlatformSetLabelMinimumScaleFactor(_indexLabel, 0.65f);
        else
            _indexLabel.minimumFontSize = _indexLabel.font.pointSize * 0.65f;
        [_indexBackgroundView addSubview:_indexLabel];

        _messageLabel = [[UILabel alloc] init];
        _messageLabel.userInteractionEnabled = false;
        _messageLabel.backgroundColor = [UIColor clearColor];
        _messageLabel.font = TGSystemFontOfSize(15.5f);
        _messageLabel.textColor = UIColorRGB(0x222222);
        _messageLabel.numberOfLines = 2;
        _messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _messageLabel.text = title;
        [self addSubview:_messageLabel];

        _chevronView = [[TGPinnedMessageChevronView alloc] init];
        [self addSubview:_chevronView];

        _separatorView = [[UIView alloc] init];
        _separatorView.userInteractionEnabled = false;
        _separatorView.backgroundColor = UIColorRGB(0xd9d9d9);
        [self addSubview:_separatorView];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    return 64.0f;
}

- (bool)requiresDivider
{
    return false;
}

- (void)setDark
{
    [super setDark];
    _messageLabel.textColor = [UIColor whiteColor];
    _separatorView.backgroundColor = UIColorRGB(0x383838);
    _chevronView.color = UIColorRGB(0x666666);
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    [super setPallete:pallete];
    _messageLabel.textColor = pallete.textColor;
    _indexBackgroundView.backgroundColor = pallete.accentColor;
    _separatorView.backgroundColor = pallete.separatorColor;
    _chevronView.color = pallete.secondaryTextColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat indexSize = 28.0f;
    _indexBackgroundView.frame = CGRectMake(14.0f, floor((self.bounds.size.height - indexSize) / 2.0f), indexSize, indexSize);
    _indexBackgroundView.layer.cornerRadius = indexSize / 2.0f;
    _indexLabel.frame = _indexBackgroundView.bounds;
    _messageLabel.frame = CGRectMake(54.0f, 8.0f, self.bounds.size.width - 54.0f - 34.0f, self.bounds.size.height - 16.0f);
    _chevronView.frame = CGRectMake(self.bounds.size.width - 21.0f, floor((self.bounds.size.height - 14.0f) / 2.0f), 8.0f, 14.0f);
    _separatorView.frame = CGRectMake(54.0f, self.bounds.size.height - TGScreenPixel, self.bounds.size.width - 54.0f, TGScreenPixel);
}

@end

@interface TGPinnedMessageTitlePanel () {
    TGModenConcersationReplyAssociatedPanel *_replyPanel;
    UIView *_separatorView;
    UIImageView *_classicIOS6BackgroundView;
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
        self.clipsToBounds = true;

        UIImage *classicBackgroundImage = TGClassicIOS6PinnedPanelBackgroundImage();
        classicBackgroundImage = [TGPresentation classicIOS6ThemedImage:classicBackgroundImage tintColor:TGPresentation.current.pallete.barBackgroundColor alpha:0.85f];
        _classicIOS6BackgroundView = [[UIImageView alloc] initWithImage:classicBackgroundImage];
        _classicIOS6BackgroundView.userInteractionEnabled = false;
        _classicIOS6BackgroundView.hidden = ![TGPresentation classicIOS6Style];
        [self addSubview:_classicIOS6BackgroundView];
        
        _replyPanel = [[TGModenConcersationReplyAssociatedPanel alloc] initWithMessage:message];
        _replyPanel.compactMode = true;
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
        self.backgroundColor = [TGPresentation classicIOS6Style] ? [UIColor clearColor] : UIColorRGB(0xf7f7f7);
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = [TGPresentation classicIOS6Style] ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? TGPresentation.current.pallete.barSeparatorColor : UIColorRGB(0x6d7884)) : TGSeparatorColor();
        [self addSubview:_separatorView];

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
    _separatorView.hidden = brandedStyle;
    _brandedBackgroundSize = CGSizeZero;
    _brandedBubbleWidth = 0.0f;
    if (!brandedStyle)
        return;

    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    _classicIOS6BackgroundView.hidden = true;
    self.backgroundColor = [UIColor clearColor];
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
    
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    _classicIOS6BackgroundView.hidden = !classicIOS6Style;
    if (classicIOS6Style)
        _classicIOS6BackgroundView.image = [TGPresentation classicIOS6ThemedImage:TGClassicIOS6PinnedPanelBackgroundImage() tintColor:presentation.pallete.barBackgroundColor alpha:0.85f];
    self.backgroundColor = classicIOS6Style ? [UIColor clearColor] : presentation.pallete.barBackgroundColor;
    _separatorView.backgroundColor = classicIOS6Style ? ([TGPresentation classicIOS6UsesPaletteAdaptedAssets] ? presentation.pallete.barSeparatorColor : UIColorRGB(0x6d7884)) : presentation.pallete.barSeparatorColor;
    _replyPanel.pallete = presentation.associatedInputPanelPallete;
    [self updateBrandedStyle];
}

- (void)updateMessage:(TGMessage *)message {
    _message = message;
    [_replyPanel updateMessage:message];
    _brandedTextLabel.text = _replyPanel.contentText;
}

- (void)setMessageCount:(NSUInteger)messageCount {
    _replyPanel.compactPrefix = messageCount > 1 ? [NSString stringWithFormat:@"%d", (int)messageCount] : nil;
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
    _separatorView.frame = CGRectMake(0.0f, self.frame.size.height - separatorHeight, self.frame.size.width, separatorHeight);
    _classicIOS6BackgroundView.frame = self.bounds;
    
    _replyPanel.frame = CGRectMake(self.safeAreaInset.left, 0.0f, self.frame.size.width - self.safeAreaInset.left - self.safeAreaInset.right, 28.0f);

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
