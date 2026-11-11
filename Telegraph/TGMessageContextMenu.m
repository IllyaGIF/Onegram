#import "TGMessageContextMenu.h"
#import "TGPresentation.h"
#import "TGCollectionItemView.h"
#import "TGApplication.h"
#import "TGOnegramSettings.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import <QuartzCore/QuartzCore.h>
#import "../OnegramPlatform/OGPlatformGraphics.h"

static void TGMessageContextMenuApplyShadow(UIView *view, CGFloat cornerRadius)
{
    OGPlatformApplyRoundedViewShadow(view, [UIColor blackColor], 0.2f, 4.0f, CGSizeMake(0.0f, 1.0f), cornerRadius);
}

static const CGFloat TGMessageMenuRowHeight = 44.0f;
static const CGFloat TGMessageMenuSectionSpacing = 8.0f;
static const CGFloat TGMessageMenuReactionItemSize = 44.0f;
static const CGFloat TGMessageMenuReactionInset = 6.0f;

static UIImage *TGMessageMenuIcon(NSString *action, UIColor *color)
{
    NSDictionary *names = @{@"reply": @"msg_reply_small", @"copy": @"msg_copy", @"delete": @"msg_delete", @"moderate": @"msg_delete", @"edit": @"msg_edit", @"forward": @"msg_forward", @"copyLink": @"msg_link", @"pin": @"msg_pin", @"unpin": @"msg_unpin", @"translate": @"msg_translate", @"report": @"msg_report", @"ban": @"msg_report", @"select": @"msg_select", @"unvotePoll": @"msg_unvote", @"stopPoll": @"msg_pollstop", @"save": @"msg_saved", @"messageTime": @"msg_recent", @"saveGif": @"msg_gif", @"stickerPackInfo": @"msg_sticker", @"stopLiveLocation": @"msg_location", @"sendCallLog": @"msg_calls"};
    NSString *name = names[action];
    if (name != nil)
    {
        UIImage *source = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"png"]];
        if (source != nil)
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), false, 0);
            [source drawInRect:CGRectMake(0, 0, 28, 28)];
            [color setFill];
            UIRectFillUsingBlendMode(CGRectMake(0, 0, 28, 28), kCGBlendModeSourceIn);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            return image;
        }
    }
    if (![action isEqualToString:@"expand"] && ![action isEqualToString:@"readDate"])
        return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), false, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return nil;
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.8f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    if ([action isEqualToString:@"expand"])
    {
        CGContextMoveToPoint(context, 7, 11);
        CGContextAddLineToPoint(context, 14, 18);
        CGContextAddLineToPoint(context, 21, 11);
    }
    else
    {
        CGContextMoveToPoint(context, 4, 15);
        CGContextAddLineToPoint(context, 8, 19);
        CGContextAddLineToPoint(context, 16, 9);
        CGContextMoveToPoint(context, 12, 17);
        CGContextAddLineToPoint(context, 14, 19);
        CGContextAddLineToPoint(context, 22, 9);
    }
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static CGFloat TGMessageMenuIconHorizontalOffset(UIImage *image)
{
    CGImageRef imageRef = image.CGImage;
    if (imageRef == NULL)
        return 0.0f;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0)
        return 0.0f;
    uint8_t *alpha = calloc(width * height, 1);
    if (alpha == NULL)
        return 0.0f;
    CGContextRef context = CGBitmapContextCreate(alpha, width, height, 8, width, NULL, kCGImageAlphaOnly);
    if (context == NULL)
    {
        free(alpha);
        return 0.0f;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    size_t minX = width;
    size_t maxX = 0;
    for (size_t y = 0; y < height; y++)
    {
        for (size_t x = 0; x < width; x++)
        {
            if (alpha[y * width + x] > 24)
            {
                minX = MIN(minX, x);
                maxX = MAX(maxX, x);
            }
        }
    }
    free(alpha);
    if (minX > maxX)
        return 0.0f;
    CGFloat contentCenter = ((CGFloat)minX + (CGFloat)maxX + 1.0f) / 2.0f;
    CGFloat scale = image.size.width > FLT_EPSILON ? (CGFloat)width / image.size.width : 1.0f;
    return ((CGFloat)width / 2.0f - contentCenter) / scale;
}

@interface TGMessageMenuContentView : UIView
@end

@implementation TGMessageMenuContentView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

@end

@implementation TGMessageContextMenu
{
    TGMessageContextMenuStyle _style;
    UIImageView *_backgroundView;
    UIView *_backgroundTint;
    UIControl *_backdrop;
    UIView *_contents;
    UIView *_cardShadow;
    UIView *_toolbarShadow;
    UIView *_toolbar;
    NSArray *_toolbarActions;
    UIView *_tailLarge;
    UIView *_tailSmall;
    CGFloat _menuScale;
    UIView *_card;
    UIScrollView *_rows;
    NSMutableArray *_rowButtons;
    NSMutableArray *_separators;
    UIScrollView *_reactionBar;
    UIImageView *_preview;
    CGRect _sourceRect;
    NSArray *_sections;
    NSArray *_reactions;
    NSString *_chosenReaction;
    UIColor *_surfaceColor;
    UIColor *_textColor;
    UIColor *_destructiveColor;
    UIColor *_separatorColor;
    UIColor *_selectionColor;
    UIButton *_trackedButton;
    bool _trackingMoved;
    CGPoint _trackingStart;
    bool _expanded;
    bool _dismissing;
}

+ (UIImage *)blurredSnapshotOfView:(UIView *)view
{
    CGSize size = view.bounds.size;
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGFloat factor = 0.25f;
    size_t pixelWidth = (size_t)MAX(1.0f, CGCeil(size.width * factor));
    size_t pixelHeight = (size_t)MAX(1.0f, CGCeil(size.height * factor));
    size_t stride = pixelWidth * 4;
    void *pixels = calloc(stride * pixelHeight, 1);
    if (pixels == NULL)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, pixelWidth, pixelHeight, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        free(pixels);
        return nil;
    }
    CGContextTranslateCTM(context, 0.0f, (CGFloat)pixelHeight);
    CGContextScaleCTM(context, factor, -factor);
    UIGraphicsPushContext(context);
    if ([view respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:false];
    else
        [view.layer renderInContext:context];
    UIGraphicsPopContext();
    for (int i = 0; i < 3; i++)
        telegramFastBlur((int)pixelWidth, (int)pixelHeight, (int)stride, pixels);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    free(pixels);
    if (imageRef == NULL)
        return nil;
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}

+ (CGFloat)screenScaleForStyle:(TGMessageContextMenuStyle)style
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat shortSide = MIN(screenSize.width, screenSize.height);
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        shortSide = MIN(shortSide, 414.0f);
    CGFloat referenceWidth = style == TGMessageContextMenuStyleAndroid ? 411.0f : 390.0f;
    return MAX(0.6f, MIN(1.2f, shortSide / referenceWidth));
}

+ (TGMessageContextMenuStyle)currentStyle
{
    return [TGOnegramSettings integerForKey:TGOnegramSettingGeneralMessageMenuStyle] == TGMessageContextMenuStyleAndroid ? TGMessageContextMenuStyleAndroid : TGMessageContextMenuStyleIOS;
}

- (instancetype)initWithActions:(NSArray *)actions style:(TGMessageContextMenuStyle)style sourceRect:(CGRect)sourceRect previewImage:(UIImage *)previewImage backgroundImage:(UIImage *)backgroundImage
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _style = style;
        _sourceRect = sourceRect;
        _menuScale = 1.0f;
        TGPresentationPallete *pallete = TGPresentation.current.pallete;
        _surfaceColor = pallete.menuBackgroundColor ?: pallete.collectionMenuCellBackgroundColor;
        _textColor = pallete.menuTextColor ?: pallete.textColor;
        _destructiveColor = pallete.menuDestructiveColor ?: pallete.collectionMenuDestructiveColor;
        _separatorColor = pallete.menuSeparatorColor ?: pallete.collectionMenuSeparatorColor;
        _selectionColor = pallete.menuSelectionColor ?: pallete.collectionMenuCellSelectionColor;
        if (backgroundImage != nil)
        {
            _backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
            _backgroundView.contentMode = UIViewContentModeScaleToFill;
            [self addSubview:_backgroundView];
        }
        _backgroundTint = [[UIView alloc] init];
        if (style == TGMessageContextMenuStyleIOS)
            _backgroundTint.backgroundColor = pallete.isDark ? [UIColor colorWithWhite:0.0f alpha:backgroundImage != nil ? 0.3f : 0.6f] : [UIColor colorWithWhite:1.0f alpha:backgroundImage != nil ? 0.3f : 0.7f];
        else
            _backgroundTint.backgroundColor = [UIColor clearColor];
        [self addSubview:_backgroundTint];
        _backdrop = [[UIControl alloc] init];
        _backdrop.backgroundColor = [UIColor clearColor];
        [_backdrop addTarget:self action:@selector(outsidePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_backdrop];
        if (style == TGMessageContextMenuStyleIOS && previewImage != nil && sourceRect.size.width >= 1.0f && sourceRect.size.height >= 1.0f)
        {
            _preview = [[UIImageView alloc] initWithImage:previewImage];
            _preview.userInteractionEnabled = false;
            [self addSubview:_preview];
        }
        _contents = [[TGMessageMenuContentView alloc] init];
        [self addSubview:_contents];
        _cardShadow = [[UIView alloc] init];
        _cardShadow.backgroundColor = [UIColor clearColor];
        [_contents addSubview:_cardShadow];
        if (style == TGMessageContextMenuStyleAndroid)
        {
            _toolbarShadow = [[UIView alloc] init];
            _toolbarShadow.backgroundColor = [UIColor clearColor];
            [_contents addSubview:_toolbarShadow];
            _toolbar = [[UIView alloc] init];
            _toolbar.backgroundColor = _surfaceColor;
            _toolbar.layer.cornerRadius = 16.0f;
            _toolbar.clipsToBounds = true;
            [_toolbarShadow addSubview:_toolbar];
            for (UIView *shadowView in @[_cardShadow, _toolbarShadow])
                TGMessageContextMenuApplyShadow(shadowView, 0.0f);
            _tailLarge = [[UIView alloc] init];
            _tailLarge.backgroundColor = _surfaceColor;
            _tailLarge.userInteractionEnabled = false;
            [_contents addSubview:_tailLarge];
            _tailSmall = [[UIView alloc] init];
            _tailSmall.backgroundColor = _surfaceColor;
            _tailSmall.userInteractionEnabled = false;
            [_contents addSubview:_tailSmall];
        }
        _card = [[UIView alloc] init];
        _card.backgroundColor = _surfaceColor;
        _card.layer.cornerRadius = style == TGMessageContextMenuStyleAndroid ? 16.0f : 14.0f;
        _card.clipsToBounds = true;
        [_cardShadow addSubview:_card];
        _rows = [[UIScrollView alloc] init];
        _rows.showsVerticalScrollIndicator = false;
        _rows.showsHorizontalScrollIndicator = false;
        [_card addSubview:_rows];
        _reactionBar = [[UIScrollView alloc] init];
        _reactionBar.showsVerticalScrollIndicator = false;
        _reactionBar.showsHorizontalScrollIndicator = false;
        _reactionBar.backgroundColor = _surfaceColor;
        _reactionBar.clipsToBounds = true;
        _reactionBar.hidden = true;
        [_contents addSubview:_reactionBar];
        
        NSMutableArray *infoActions = [[NSMutableArray alloc] init];
        NSMutableArray *mainActions = [[NSMutableArray alloc] init];
        NSMutableArray *selectActions = [[NSMutableArray alloc] init];
        for (NSDictionary *action in actions)
        {
            NSString *name = action[@"action"];
            if ([name isEqualToString:@"reaction"] || [name isEqualToString:@"removeReaction"])
            {
                UIButton *fallback = [UIButton buttonWithType:UIButtonTypeCustom];
                [fallback setTitle:TGLocalized(@"OnegramSettings.Reactions") forState:UIControlStateNormal];
                [fallback setTitleColor:_textColor forState:UIControlStateNormal];
                fallback.titleLabel.font = TGSystemFontOfSize(16);
                [fallback addTarget:self action:@selector(openReactionPicker) forControlEvents:UIControlEventTouchUpInside];
                [_reactionBar addSubview:fallback];
                _reactionBar.hidden = false;
            }
            else if ([name isEqualToString:@"messageTime"] || [name isEqualToString:@"readDate"])
                [infoActions addObject:action];
            else if ([name isEqualToString:@"select"] && style == TGMessageContextMenuStyleAndroid)
                continue;
            else if ([name isEqualToString:@"select"])
            {
                NSMutableDictionary *selectAction = [[NSMutableDictionary alloc] initWithDictionary:action];
                selectAction[@"title"] = TGLocalized(@"Common.Select");
                [selectActions addObject:selectAction];
            }
            else
                [mainActions addObject:action];
        }
        NSArray *order = @[@"reply", @"edit", @"copy", @"pin", @"unpin", @"translate", @"copyLink", @"forward", @"saveGif", @"stickerPackInfo", @"stopLiveLocation", @"unvotePoll", @"stopPoll", @"sendCallLog", @"report", @"ban", @"moderate", @"delete"];
        [mainActions sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right)
        {
            NSUInteger l = [order indexOfObject:left[@"action"]];
            NSUInteger r = [order indexOfObject:right[@"action"]];
            bool lDestructive = [left[@"destructive"] boolValue];
            bool rDestructive = [right[@"destructive"] boolValue];
            if (lDestructive != rDestructive)
                return lDestructive ? NSOrderedDescending : NSOrderedAscending;
            return l < r ? NSOrderedAscending : (l > r ? NSOrderedDescending : NSOrderedSame);
        }];
        if (style == TGMessageContextMenuStyleAndroid)
        {
            NSArray *toolOrder = @[@"reply", @"delete", @"moderate", @"copy", @"forward"];
            NSMutableArray *tools = [[NSMutableArray alloc] init];
            for (NSString *name in toolOrder)
            {
                for (NSDictionary *action in [mainActions copy])
                {
                    if ([action[@"action"] isEqualToString:name] && tools.count < 4)
                    {
                        [tools addObject:action];
                        [mainActions removeObject:action];
                    }
                }
            }
            _toolbarActions = tools;
            for (NSUInteger i = 0; i < tools.count; i++)
            {
                NSDictionary *action = tools[i];
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.tag = (NSInteger)i;
                button.accessibilityLabel = action[@"title"];
                UIColor *color = [action[@"destructive"] boolValue] ? _destructiveColor : _textColor;
                UIImage *icon = TGMessageMenuIcon(action[@"action"], color);
                [button setImage:icon forState:UIControlStateNormal];
                CGFloat iconOffset = CGRound(TGMessageMenuIconHorizontalOffset(icon) * 2.0f) / 2.0f;
                button.imageEdgeInsets = UIEdgeInsetsMake(0, iconOffset, 0, -iconOffset);
                button.adjustsImageWhenHighlighted = false;
                [button addTarget:self action:@selector(toolPressed:) forControlEvents:UIControlEventTouchUpInside];
                [button addTarget:self action:@selector(rowHighlightChanged:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter | UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
                [_toolbar addSubview:button];
            }
        }
        NSMutableArray *sections = [[NSMutableArray alloc] init];
        if (infoActions.count != 0)
            [sections addObject:infoActions];
        if (mainActions.count != 0)
            [sections addObject:mainActions];
        if (selectActions.count != 0)
            [sections addObject:selectActions];
        _sections = sections;
        [self rebuildRows];
    }
    return self;
}

- (void)rebuildRows
{
    for (UIView *view in [_rows.subviews copy])
        [view removeFromSuperview];
    _rowButtons = [[NSMutableArray alloc] init];
    _separators = [[NSMutableArray alloc] init];
    for (NSUInteger section = 0; section < _sections.count; section++)
    {
        if (section != 0)
        {
            UIView *separator = [[UIView alloc] init];
            separator.backgroundColor = _separatorColor;
            [_rows addSubview:separator];
            [_separators addObject:separator];
        }
        for (NSDictionary *action in _sections[section])
        {
            UIButton *button = [self buttonForAction:action];
            [_rows addSubview:button];
            [_rowButtons addObject:button];
        }
    }
    [self setNeedsLayout];
}

- (NSDictionary *)actionForButton:(UIButton *)button
{
    NSUInteger index = [_rowButtons indexOfObjectIdenticalTo:button];
    if (index == NSNotFound)
        return nil;
    for (NSArray *section in _sections)
    {
        if (index < section.count)
            return section[index];
        index -= section.count;
    }
    return nil;
}

- (UIButton *)buttonForAction:(NSDictionary *)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.accessibilityLabel = action[@"title"];
    bool info = [action[@"disabled"] boolValue];
    button.enabled = !info;
    UIColor *color = [action[@"destructive"] boolValue] ? _destructiveColor : _textColor;
    if (info)
        color = [_textColor colorWithAlphaComponent:0.6f];
    [button setImage:TGMessageMenuIcon(action[@"action"], color) forState:UIControlStateNormal];
    [button setImage:TGMessageMenuIcon(action[@"action"], color) forState:UIControlStateDisabled];
    [button setTitleColor:color forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateDisabled];
    [button setTitleColor:color forState:UIControlStateHighlighted];
    [button setTitle:action[@"title"] forState:UIControlStateNormal];
    button.titleLabel.font = TGSystemFontOfSize(info ? 14 : 17);
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, _style == TGMessageContextMenuStyleAndroid ? 16 : 14, 0, 14);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, _style == TGMessageContextMenuStyleAndroid ? 20 : 14, 0, 0);
    button.adjustsImageWhenHighlighted = false;
    [button addTarget:self action:@selector(rowPressed:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(rowHighlightChanged:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(rowHighlightChanged:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
    return button;
}

- (void)rowHighlightChanged:(UIButton *)button
{
    [self setRowButton:button highlighted:button.highlighted];
}

- (void)setRowButton:(UIButton *)button highlighted:(bool)highlighted
{
    button.backgroundColor = highlighted ? _selectionColor : [UIColor clearColor];
}

- (void)setInfoTitle:(NSString *)title forAction:(NSString *)action
{
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    for (NSArray *section in _sections)
    {
        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (NSDictionary *item in section)
        {
            if (![item[@"action"] isEqualToString:action])
                [items addObject:item];
            else if (title.length != 0)
            {
                NSMutableDictionary *updated = [[NSMutableDictionary alloc] initWithDictionary:item];
                updated[@"title"] = title;
                [items addObject:updated];
            }
        }
        if (items.count != 0)
            [sections addObject:items];
    }
    _sections = sections;
    [self rebuildRows];
    [self layoutIfNeeded];
}

- (void)setReactions:(NSArray *)reactions chosenReaction:(NSString *)chosenReaction
{
    NSMutableArray *ordered = [[NSMutableArray alloc] init];
    NSArray *preferred = @[@"❤️", @"🔥", @"👏", @"🙈", @"🐳", @"😈", @"🤡"];
    for (NSString *candidate in preferred)
        for (NSString *reaction in reactions)
            if ([[candidate stringByReplacingOccurrencesOfString:@"\uFE0F" withString:@""] isEqualToString:[reaction stringByReplacingOccurrencesOfString:@"\uFE0F" withString:@""]])
                [ordered addObject:reaction];
    for (NSString *reaction in reactions)
        if (![ordered containsObject:reaction])
            [ordered addObject:reaction];
    _reactions = ordered;
    _chosenReaction = [chosenReaction copy];
    _reactionBar.hidden = _reactions.count == 0;
    [self rebuildReactions];
    [self setNeedsLayout];
}

- (void)rebuildReactions
{
    for (UIView *view in [_reactionBar.subviews copy])
        [view removeFromSuperview];
    NSUInteger count = _expanded ? _reactions.count : MIN((NSUInteger)7, _reactions.count);
    for (NSUInteger i = 0; i < count; i++)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = i;
        NSString *emoji = _reactions[i];
        UIImage *image = TGEmojiImageOfSize(emoji, 32);
        [button setImage:image forState:UIControlStateNormal];
        if (image == nil)
        {
            [button setTitle:emoji forState:UIControlStateNormal];
            button.titleLabel.font = TGSystemFontOfSize(30);
        }
        button.accessibilityLabel = emoji;
        button.layer.cornerRadius = (TGMessageMenuReactionItemSize - 4.0f) / 2.0f;
        if ([emoji isEqualToString:_chosenReaction])
            button.backgroundColor = [TGPresentation.current.pallete.accentColor colorWithAlphaComponent:0.2];
        [button addTarget:self action:@selector(reactionPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_reactionBar addSubview:button];
    }
    if (_reactions.count > 7 || _expanded)
    {
        UIButton *expand = [UIButton buttonWithType:UIButtonTypeCustom];
        expand.tag = -1;
        expand.accessibilityLabel = _expanded ? TGLocalized(@"Common.Cancel") : TGLocalized(@"Common.More");
        [expand setImage:TGMessageMenuIcon(@"expand", _textColor) forState:UIControlStateNormal];
        if (_style == TGMessageContextMenuStyleAndroid)
        {
            expand.backgroundColor = [_textColor colorWithAlphaComponent:0.12f];
            expand.layer.cornerRadius = (TGMessageMenuReactionItemSize - 4.0f) / 2.0f;
        }
        [expand addTarget:self action:@selector(expandPressed) forControlEvents:UIControlEventTouchUpInside];
        [_reactionBar addSubview:expand];
    }
}

- (TGMessageContextMenuStyle)style
{
    return _style;
}

- (CGFloat)menuScale
{
    return _menuScale;
}

- (void)setMenuScale:(CGFloat)menuScale
{
    if (!isfinite(menuScale))
        return;
    _menuScale = MAX(0.7f, MIN(1.3f, menuScale));
    [self setNeedsLayout];
}

- (CGFloat)rowHeight
{
    return _style == TGMessageContextMenuStyleAndroid ? 50.0f : TGMessageMenuRowHeight;
}

- (CGFloat)androidCardHeightForAvailableHeight:(CGFloat)availableHeight reactionHeight:(CGFloat)reactionHeight
{
    CGFloat rowsHeight = [self rowsContentHeight];
    CGFloat toolsHeight = _toolbarActions.count == 0 ? 0 : 52;
    CGFloat toolsGap = toolsHeight > 0 && rowsHeight > 0 ? 8 : 0;
    CGFloat reactionGap = reactionHeight > 0 ? 14 : 0;
    return MIN(rowsHeight, MAX(rowsHeight > 0 ? [self rowHeight] : 0, availableHeight - reactionHeight - reactionGap - toolsHeight - toolsGap));
}

- (CGFloat)androidStackHeightForAvailableHeight:(CGFloat)availableHeight reactionHeight:(CGFloat)reactionHeight
{
    CGFloat rowsHeight = [self rowsContentHeight];
    CGFloat toolsHeight = _toolbarActions.count == 0 ? 0 : 52;
    CGFloat toolsGap = toolsHeight > 0 && rowsHeight > 0 ? 8 : 0;
    CGFloat reactionGap = reactionHeight > 0 ? 14 : 0;
    return reactionHeight + reactionGap + [self androidCardHeightForAvailableHeight:availableHeight reactionHeight:reactionHeight] + toolsGap + toolsHeight;
}

- (CGFloat)requiredHeightBelowSourceInBounds:(CGRect)bounds
{
    if (_style != TGMessageContextMenuStyleAndroid)
        return 0.0f;
    CGFloat scale = _menuScale * [TGMessageContextMenu screenScaleForStyle:_style];
    CGFloat height = bounds.size.height / scale;
    CGFloat top = MAX(12, self.contentInsets.top + 6) / scale;
    CGFloat bottom = height - MAX(12, self.contentInsets.bottom + 6) / scale;
    CGFloat reactionHeight = _reactionBar.hidden ? 0 : TGMessageMenuReactionItemSize + TGMessageMenuReactionInset * 2;
    return ([self androidStackHeightForAvailableHeight:MAX(0, bottom - top) reactionHeight:reactionHeight] - 2.0f) * scale;
}

- (void)updateSourceRect:(CGRect)sourceRect
{
    _sourceRect = sourceRect;
    [self setNeedsLayout];
}

- (CGFloat)rowsContentHeight
{
    return _rowButtons.count * [self rowHeight] + _separators.count * TGMessageMenuSectionSpacing;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _backgroundView.frame = self.bounds;
    _backgroundTint.frame = self.bounds;
    _backdrop.frame = self.bounds;
    _backgroundView.hidden = self.previewMode;
    _backgroundTint.hidden = self.previewMode;
    _backdrop.hidden = self.previewMode;
    CGFloat scale = _menuScale * [TGMessageContextMenu screenScaleForStyle:_style];
    CGFloat width = self.bounds.size.width / scale;
    CGFloat height = self.bounds.size.height / scale;
    _contents.transform = CGAffineTransformIdentity;
    _contents.bounds = CGRectMake(0, 0, width, height);
    _contents.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _contents.transform = CGAffineTransformMakeScale(scale, scale);
    CGRect sourceRect = CGRectApplyAffineTransform(_sourceRect, CGAffineTransformMakeScale(1.0f / scale, 1.0f / scale));
    CGFloat top = MAX(12, self.contentInsets.top + 6) / scale;
    CGFloat bottom = height - MAX(12, self.contentInsets.bottom + 6) / scale;
    CGFloat availableHeight = MAX(0, bottom - top);
    CGFloat sideInset = 12.0f;
    bool android = _style == TGMessageContextMenuStyleAndroid;
    CGFloat cardWidth = MIN(250, width - sideInset * 2);
    if (android)
    {
        CGFloat titleWidth = 0.0f;
        for (UIButton *button in _rowButtons)
            titleWidth = MAX(titleWidth, CGCeil([[button titleForState:UIControlStateNormal] sizeWithFont:button.titleLabel.font].width));
        cardWidth = MIN(width - sideInset * 2, MIN(280.0f, MAX(200.0f, 16.0f + 28.0f + 20.0f + titleWidth + 16.0f)));
    }
    
    NSUInteger buttons = 0;
    for (UIView *view in _reactionBar.subviews)
        if ([view isKindOfClass:[UIButton class]])
            buttons++;
    CGFloat maximumReactionWidth = MIN(320, width - sideInset * 2);
    NSUInteger columns = MAX((NSUInteger)1, (NSUInteger)((maximumReactionWidth - TGMessageMenuReactionInset * 2) / TGMessageMenuReactionItemSize));
    bool reactionsPending = _reactions == nil;
    CGFloat reactionWidth = _expanded ? maximumReactionWidth : MIN(maximumReactionWidth, reactionsPending ? 180.0f : buttons * TGMessageMenuReactionItemSize + TGMessageMenuReactionInset * 2);
    NSUInteger rowsCount = _expanded ? (NSUInteger)ceil((CGFloat)buttons / columns) : 1;
    CGFloat reactionContentHeight = rowsCount * TGMessageMenuReactionItemSize + TGMessageMenuReactionInset * 2;
    CGFloat reactionHeight = (_reactionBar.hidden || buttons == 0) ? 0 : (_expanded ? MIN(reactionContentHeight, MAX(TGMessageMenuReactionItemSize + TGMessageMenuReactionInset * 2, availableHeight * 0.35f)) : TGMessageMenuReactionItemSize + TGMessageMenuReactionInset * 2);
    CGFloat reactionGap = reactionHeight > 0 ? (android ? 14 : 8) : 0;
    
    CGFloat rowsHeight = [self rowsContentHeight];
    CGFloat toolsHeight = _toolbarActions.count == 0 ? 0 : 52;
    CGFloat toolsGap = toolsHeight > 0 && rowsHeight > 0 ? 8 : 0;
    CGFloat cardHeight = MIN(rowsHeight, MAX(rowsHeight > 0 ? [self rowHeight] : 0, availableHeight - reactionHeight - reactionGap - toolsHeight - toolsGap));
    CGFloat menuGap = cardHeight > 0 ? 8 : 0;
    CGFloat previewHeight = (self.previewMode || _preview == nil) ? 0 : sourceRect.size.height;
    bool outgoing = CGRectGetMidX(sourceRect) > width / 2;
    
    CGFloat reactionX = 0.0f;
    CGFloat reactionY = 0.0f;
    CGFloat previewY = sourceRect.origin.y;
    CGFloat cardX = 0.0f;
    CGFloat cardY = 0.0f;
    if (android)
    {
        cardHeight = [self androidCardHeightForAvailableHeight:availableHeight reactionHeight:reactionHeight];
        CGFloat stackHeight = [self androidStackHeightForAvailableHeight:availableHeight reactionHeight:reactionHeight];
        CGFloat stackTop = CGRectGetMaxY(sourceRect) - 2.0f;
        if (self.previewMode)
            stackTop = top;
        else if (stackTop + stackHeight > bottom)
        {
            CGFloat aboveTop = sourceRect.origin.y + 2.0f - stackHeight;
            stackTop = aboveTop >= top ? aboveTop : bottom - stackHeight;
        }
        stackTop = MAX(top, MIN(stackTop, bottom - stackHeight));
        reactionY = stackTop;
        cardY = stackTop + reactionHeight + reactionGap;
        
        reactionX = outgoing ? CGRectGetMaxX(sourceRect) - 8.0f - reactionWidth : sourceRect.origin.x + 8.0f;
        if (self.previewMode)
            reactionX = sideInset;
        reactionX = MAX(sideInset, MIN(reactionX, width - reactionWidth - sideInset));
        cardX = (outgoing && !self.previewMode) ? reactionX + reactionWidth - cardWidth : reactionX;
        cardX = MAX(sideInset, MIN(cardX, width - cardWidth - sideInset));
        
        bool showTail = reactionHeight > 0 && !_expanded;
        _tailLarge.hidden = !showTail;
        _tailSmall.hidden = !showTail;
        if (showTail)
        {
            CGFloat tailX = reactionX + reactionWidth - 40.0f;
            _tailLarge.frame = CGRectMake(tailX - 6.0f, reactionY + reactionHeight - 4.0f, 12.0f, 12.0f);
            _tailLarge.layer.cornerRadius = 6.0f;
            _tailSmall.frame = CGRectMake(tailX + 6.0f, reactionY + reactionHeight + 9.0f, 6.0f, 6.0f);
            _tailSmall.layer.cornerRadius = 3.0f;
        }
    }
    else
    {
        previewHeight = MAX(0, MIN(previewHeight, availableHeight - reactionHeight - reactionGap - menuGap - cardHeight));
        CGFloat totalHeight = reactionHeight + reactionGap + previewHeight + menuGap + cardHeight;
        CGFloat stackTop = sourceRect.origin.y - reactionHeight - reactionGap;
        stackTop = MAX(top, MIN(stackTop, bottom - totalHeight));
        reactionY = stackTop;
        previewY = stackTop + reactionHeight + reactionGap;
        cardY = previewY + previewHeight + menuGap;
        cardX = outgoing ? CGRectGetMaxX(sourceRect) - cardWidth : sourceRect.origin.x;
        cardX = MAX(sideInset, MIN(cardX, width - cardWidth - sideInset));
        reactionX = outgoing ? CGRectGetMaxX(sourceRect) - reactionWidth : sourceRect.origin.x;
        reactionX = MAX(sideInset, MIN(reactionX, width - reactionWidth - sideInset));
    }
    
    _reactionBar.frame = CGRectMake(reactionX, reactionY, reactionWidth, reactionHeight);
    _reactionBar.layer.cornerRadius = _expanded ? 20 : reactionHeight / 2.0f;
    if (_preview != nil)
    {
        CGFloat imageHeight = _preview.image.size.height;
        _preview.frame = CGRectMake(_sourceRect.origin.x, previewY * scale, _sourceRect.size.width, previewHeight * scale);
        _preview.contentMode = previewHeight * scale + 0.5f >= imageHeight ? UIViewContentModeScaleToFill : UIViewContentModeBottom;
        _preview.clipsToBounds = true;
        _preview.hidden = previewHeight <= FLT_EPSILON;
    }
    _cardShadow.frame = CGRectMake(cardX, cardY, cardWidth, cardHeight);
    TGMessageContextMenuApplyShadow(_cardShadow, _card.layer.cornerRadius);
    _cardShadow.hidden = cardHeight <= FLT_EPSILON;
    _card.frame = _cardShadow.bounds;
    _rows.frame = _card.bounds;
    _rows.contentSize = CGSizeMake(cardWidth, rowsHeight);
    _rows.scrollEnabled = rowsHeight > cardHeight + 0.5f;
    
    if (_toolbarShadow != nil)
    {
        _toolbarShadow.frame = CGRectMake(cardX, cardY + cardHeight + toolsGap, cardWidth, toolsHeight);
        TGMessageContextMenuApplyShadow(_toolbarShadow, _toolbar.layer.cornerRadius);
        _toolbarShadow.hidden = toolsHeight <= FLT_EPSILON;
        _toolbar.frame = _toolbarShadow.bounds;
        NSUInteger toolIndex = 0;
        CGFloat toolInset = 14.0f;
        CGFloat toolWidth = _toolbarActions.count == 0 ? 0 : (cardWidth - toolInset * 2.0f) / _toolbarActions.count;
        for (UIView *view in _toolbar.subviews)
        {
            CGFloat centerX = toolInset + toolWidth * (toolIndex++ + 0.5f);
            view.frame = CGRectMake(CGFloor(centerX - toolWidth / 2.0f), 0, CGFloor(toolWidth), toolsHeight);
        }
    }
    
    CGFloat rowHeight = [self rowHeight];
    CGFloat rowY = 0.0f;
    NSUInteger buttonIndex = 0;
    for (NSUInteger section = 0; section < _sections.count; section++)
    {
        if (section != 0)
        {
            UIView *separator = _separators[section - 1];
            separator.frame = CGRectMake(0, rowY + CGFloor((TGMessageMenuSectionSpacing - TGScreenPixel) / 2.0f), cardWidth, TGScreenPixel);
            rowY += TGMessageMenuSectionSpacing;
        }
        for (NSUInteger i = 0; i < [_sections[section] count]; i++)
        {
            UIButton *button = _rowButtons[buttonIndex++];
            button.frame = CGRectMake(0, rowY, cardWidth, rowHeight);
            rowY += rowHeight;
        }
    }
    
    NSUInteger index = 0;
    CGFloat step = _expanded ? (reactionWidth - TGMessageMenuReactionInset * 2) / columns : TGMessageMenuReactionItemSize;
    for (UIView *view in _reactionBar.subviews)
    {
        if (![view isKindOfClass:[UIButton class]])
            continue;
        if (reactionsPending)
        {
            view.frame = CGRectMake(0, 0, reactionWidth, reactionHeight);
            continue;
        }
        NSUInteger column = _expanded ? index % columns : index;
        NSUInteger row = _expanded ? index / columns : 0;
        CGFloat itemX = TGMessageMenuReactionInset + column * step + CGFloor((step - TGMessageMenuReactionItemSize) / 2.0f);
        view.frame = CGRectMake(itemX + 2.0f, TGMessageMenuReactionInset + row * TGMessageMenuReactionItemSize + 2.0f, TGMessageMenuReactionItemSize - 4.0f, TGMessageMenuReactionItemSize - 4.0f);
        index++;
    }
    _reactionBar.contentSize = CGSizeMake(reactionWidth, reactionContentHeight);
}

- (void)presentInView:(UIView *)view
{
    self.frame = view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:self];
    [self layoutIfNeeded];
    self.alpha = 0;
    if (_style == TGMessageContextMenuStyleAndroid)
    {
        CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        slide.fromValue = @(-8.0f);
        slide.toValue = @(0.0f);
        slide.additive = true;
        slide.duration = 0.15;
        slide.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [_contents.layer addAnimation:slide forKey:@"appear"];
    }
    [UIView animateWithDuration:_style == TGMessageContextMenuStyleAndroid ? 0.15 : 0.18 animations:^{ self.alpha = 1; }];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _card);
}

- (void)beginTrackingTouch
{
    if (_style != TGMessageContextMenuStyleIOS)
        return;
    TGApplication *application = (TGApplication *)[UIApplication sharedApplication];
    if (![application isKindOfClass:[TGApplication class]])
        return;
    _trackingMoved = false;
    _trackingStart = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
    __weak TGMessageContextMenu *weakSelf = self;
    application.touchTracker = ^(UITouch *touch)
    {
        __strong TGMessageContextMenu *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        [strongSelf trackTouch:touch];
    };
}

- (void)endTrackingTouch
{
    TGApplication *application = (TGApplication *)[UIApplication sharedApplication];
    if ([application isKindOfClass:[TGApplication class]])
        application.touchTracker = nil;
    if (_trackedButton != nil)
    {
        [self setTrackedButton:nil];
    }
}

- (UIButton *)trackableButtonAtPoint:(CGPoint)point
{
    if (!_card.hidden)
    {
        CGPoint cardPoint = [self convertPoint:point toView:_rows];
        for (UIButton *button in _rowButtons)
        {
            if (button.enabled && CGRectContainsPoint(button.frame, cardPoint) && CGRectContainsPoint(_card.bounds, [self convertPoint:point toView:_card]))
                return button;
        }
    }
    if (!_reactionBar.hidden)
    {
        CGPoint barPoint = [self convertPoint:point toView:_reactionBar];
        if (CGRectContainsPoint(_reactionBar.bounds, barPoint))
        {
            for (UIView *view in _reactionBar.subviews)
            {
                if ([view isKindOfClass:[UIButton class]] && CGRectContainsPoint(CGRectInset(view.frame, -2.0f, -TGMessageMenuReactionInset), barPoint))
                    return (UIButton *)view;
            }
        }
    }
    return nil;
}

- (void)setTrackedButton:(UIButton *)button
{
    if (_trackedButton == button)
        return;
    if (_trackedButton != nil)
    {
        if ([_rowButtons containsObject:_trackedButton])
            [self setRowButton:_trackedButton highlighted:false];
        else
            _trackedButton.transform = CGAffineTransformIdentity;
    }
    _trackedButton = button;
    if (button != nil)
    {
        if ([_rowButtons containsObject:button])
            [self setRowButton:button highlighted:true];
        else
        {
            [UIView animateWithDuration:0.12 animations:^
            {
                button.transform = CGAffineTransformMakeScale(1.25f, 1.25f);
            }];
        }
    }
}

- (void)trackTouch:(UITouch *)touch
{
    if (_dismissing || self.superview == nil)
    {
        [self endTrackingTouch];
        return;
    }
    CGPoint point = [touch locationInView:self];
    if (_trackingStart.x == CGFLOAT_MAX)
        _trackingStart = point;
    switch (touch.phase)
    {
        case UITouchPhaseMoved:
        {
            CGFloat dx = point.x - _trackingStart.x;
            CGFloat dy = point.y - _trackingStart.y;
            if (dx * dx + dy * dy > 8.0f * 8.0f)
                _trackingMoved = true;
            if (_trackingMoved)
                [self setTrackedButton:[self trackableButtonAtPoint:point]];
            break;
        }
        case UITouchPhaseEnded:
        {
            UIButton *button = _trackingMoved ? [self trackableButtonAtPoint:point] : nil;
            [self endTrackingTouch];
            if (button != nil)
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case UITouchPhaseCancelled:
            [self endTrackingTouch];
            break;
        default:
            break;
    }
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (_dismissing)
        return;
    _dismissing = true;
    [self endTrackingTouch];
    void (^finish)(BOOL) = ^(__unused BOOL finished)
    {
        [self removeFromSuperview];
        void (^dismissed)(void) = self.dismissed;
        self.dismissed = nil;
        if (dismissed != nil)
            dismissed();
        if (completion != nil)
            completion();
    };
    if (animated)
        [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0; } completion:finish];
    else
        finish(true);
}

- (void)openReactionPicker
{
    [self performAction:@{@"action": @"reaction"}];
}

- (void)outsidePressed
{
    [self dismissAnimated:true completion:nil];
}

- (void)performAction:(NSDictionary *)action
{
    void (^selected)(NSDictionary *) = self.actionSelected;
    [self dismissAnimated:true completion:^{ if (selected != nil) selected(action); }];
}

- (void)rowPressed:(UIButton *)button
{
    NSDictionary *action = [self actionForButton:button];
    if (action != nil && ![action[@"disabled"] boolValue])
        [self performAction:action];
}

- (void)toolPressed:(UIButton *)button
{
    if (button.tag >= 0 && (NSUInteger)button.tag < _toolbarActions.count)
        [self performAction:_toolbarActions[(NSUInteger)button.tag]];
}

- (void)reactionPressed:(UIButton *)button
{
    NSString *reaction = _reactions[(NSUInteger)button.tag];
    if ([reaction isEqualToString:_chosenReaction])
        reaction = nil;
    void (^selected)(NSString *) = self.reactionSelected;
    [self dismissAnimated:true completion:^{ if (selected != nil) selected(reaction); }];
}

- (void)expandPressed
{
    _expanded = !_expanded;
    [self rebuildReactions];
    [self setNeedsLayout];
}

@end

@interface TGMessageMenuPreviewCollectionItemView : TGCollectionItemView
- (void)refreshPreview;
@end

@implementation TGMessageMenuPreviewCollectionItemView
{
    TGMessageContextMenu *_menu;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self rebuildMenu];
    }
    return self;
}

- (void)rebuildMenu
{
    [_menu removeFromSuperview];
    NSArray *actions = @[
        @{@"title": TGLocalized(@"Conversation.ContextMenuReply"), @"action": @"reply"},
        @{@"title": TGLocalized(@"Conversation.ContextMenuCopy"), @"action": @"copy"},
        @{@"title": TGLocalized(@"Conversation.Pin"), @"action": @"pin"},
        @{@"title": TGLocalized(@"Conversation.ContextMenuForward"), @"action": @"forward"},
        @{@"title": TGLocalized(@"Conversation.ContextMenuDelete"), @"action": @"delete", @"destructive": @true},
        @{@"title": TGLocalized(@"Common.Select"), @"action": @"select"}
    ];
    _menu = [[TGMessageContextMenu alloc] initWithActions:actions style:[TGMessageContextMenu currentStyle] sourceRect:CGRectMake(16, 0, 120, 1) previewImage:nil backgroundImage:nil];
    _menu.previewMode = true;
    _menu.userInteractionEnabled = false;
    [_menu setReactions:@[@"❤️", @"🔥", @"👏", @"🙈", @"🐳", @"😈", @"🤡"] chosenReaction:nil];
    [self addSubview:_menu];
    [self setNeedsLayout];
}

- (void)refreshPreview
{
    TGMessageMenuPreviewCollectionItem *item = (TGMessageMenuPreviewCollectionItem *)self.boundItem;
    if (_menu.style != [TGMessageContextMenu currentStyle])
        [self rebuildMenu];
    _menu.menuScale = item.menuScale;
    [self setNeedsLayout];
    [_menu layoutIfNeeded];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect frame = [self classicIOS6GroupedFrame];
    _menu.frame = CGRectMake(frame.origin.x, 0, frame.size.width, self.bounds.size.height);
}

@end

@implementation TGMessageMenuPreviewCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.selectable = false;
        self.highlightable = false;
        _menuScale = 1.0f;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGMessageMenuPreviewCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 380);
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];
    [(TGMessageMenuPreviewCollectionItemView *)view refreshPreview];
}

- (void)setMenuScale:(CGFloat)menuScale
{
    if (!isfinite(menuScale))
        return;
    _menuScale = MAX(0.7f, MIN(1.3f, menuScale));
    [(TGMessageMenuPreviewCollectionItemView *)self.boundView refreshPreview];
}

@end
