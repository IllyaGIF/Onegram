#import "TGMessageContextMenu.h"
#import "TGPresentation.h"
#import "TGCollectionItemView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"
#import <QuartzCore/QuartzCore.h>

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
    if (![action isEqualToString:@"expand"])
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
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
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
    UIControl *_backdrop;
    UIView *_contents;
    CGFloat _menuScale;
    UIView *_card;
    UIScrollView *_rows;
    UIView *_toolbar;
    UIScrollView *_reactionBar;
    UIImageView *_preview;
    CGRect _sourceRect;
    NSArray *_actions;
    NSArray *_toolbarActions;
    NSArray *_reactions;
    NSString *_chosenReaction;
    UIColor *_surfaceColor;
    UIColor *_textColor;
    bool _compact;
    bool _expanded;
    bool _dismissing;
}

- (instancetype)initWithActions:(NSArray *)actions sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect compact:(bool)compact
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _sourceRect = sourceRect;
        _compact = compact;
        _menuScale = 0.85f;
        TGPresentationPallete *pallete = TGPresentation.current.pallete;
        _surfaceColor = pallete.collectionMenuBackgroundColor;
        _textColor = pallete.textColor;
        _backdrop = [[UIControl alloc] init];
        _backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:compact ? 0 : 0.25f];
        [_backdrop addTarget:self action:@selector(outsidePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_backdrop];
        _contents = [[TGMessageMenuContentView alloc] init];
        [self addSubview:_contents];
        CGRect visibleRect = CGRectIntersection(sourceRect, sourceView.bounds);
        if (!compact && !CGRectIsNull(visibleRect) && !CGRectIsEmpty(visibleRect))
        {
            CGRect snapshotRect = visibleRect;
            snapshotRect.size.height = MIN(72, snapshotRect.size.height);
            UIGraphicsBeginImageContextWithOptions(snapshotRect.size, false, MIN(2.0f, TGScreenScaling()));
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (context != NULL)
            {
                CGContextTranslateCTM(context, -visibleRect.origin.x, -visibleRect.origin.y);
                [sourceView.layer renderInContext:context];
                _preview = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
            }
            UIGraphicsEndImageContext();
            [_contents addSubview:_preview];

        }
        _card = [[UIView alloc] init];
        _card.backgroundColor = _surfaceColor;
        _card.layer.cornerRadius = 16;
        _card.clipsToBounds = true;
        [_contents addSubview:_card];
        _rows = [[UIScrollView alloc] init];
        [_card addSubview:_rows];
        _toolbar = [[UIView alloc] init];
        _toolbar.backgroundColor = _surfaceColor;
        _toolbar.layer.cornerRadius = 16;
        [_contents addSubview:_toolbar];
        _reactionBar = [[UIScrollView alloc] init];
        _reactionBar.backgroundColor = _surfaceColor;
        _reactionBar.layer.cornerRadius = 28;
        _reactionBar.clipsToBounds = true;
        _reactionBar.hidden = true;
        [_contents addSubview:_reactionBar];
        NSMutableArray *rows = [[NSMutableArray alloc] init];
        NSMutableArray *tools = [[NSMutableArray alloc] init];
        NSArray *toolNames = @[@"reply", @"delete", @"moderate", @"copy", @"edit", @"copyLink"];
        for (NSDictionary *action in actions)
        {
            NSString *name = action[@"action"];
            if ([name isEqualToString:@"select"])
                continue;
            if ([name isEqualToString:@"reaction"] || [name isEqualToString:@"removeReaction"])
            {
                UIButton *fallback = [UIButton buttonWithType:UIButtonTypeCustom];
                [fallback setTitle:TGLocalized(@"OnegramSettings.Reactions") forState:UIControlStateNormal];
                [fallback setTitleColor:_textColor forState:UIControlStateNormal];
                fallback.titleLabel.font = TGSystemFontOfSize(16);
                [fallback addTarget:self action:@selector(openReactionPicker) forControlEvents:UIControlEventTouchUpInside];
                [_reactionBar addSubview:fallback];
                _reactionBar.hidden = false;
                continue;
            }
            if ([toolNames containsObject:name])
                [tools addObject:action];
            else
                [rows addObject:action];
        }
        NSArray *toolOrder = @[@"reply", @"delete", @"moderate", @"copy", @"edit", @"copyLink"];
        [tools sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right)
        {
            NSUInteger l = [toolOrder indexOfObject:left[@"action"]];
            NSUInteger r = [toolOrder indexOfObject:right[@"action"]];
            return l < r ? NSOrderedAscending : (l > r ? NSOrderedDescending : NSOrderedSame);
        }];
        while (tools.count > 4)
        {
            [rows addObject:tools.lastObject];
            [tools removeLastObject];
        }
        NSArray *rowOrder = @[@"messageTime", @"forward", @"pin", @"unpin", @"translate"];
        NSMutableArray *orderedRows = [[NSMutableArray alloc] init];
        for (NSString *name in rowOrder)
            for (NSDictionary *action in rows)
                if ([action[@"action"] isEqualToString:name])
                    [orderedRows addObject:action];
        for (NSDictionary *action in rows)
            if (![rowOrder containsObject:action[@"action"]])
                [orderedRows addObject:action];
        _actions = orderedRows;
        _toolbarActions = tools;
        for (NSUInteger i = 0; i < _actions.count; i++)
            [_rows addSubview:[self buttonForAction:_actions[i] index:i toolbar:false]];
        for (NSUInteger i = 0; i < _toolbarActions.count; i++)
            [_toolbar addSubview:[self buttonForAction:_toolbarActions[i] index:i toolbar:true]];
    }
    return self;
}

- (UIButton *)buttonForAction:(NSDictionary *)action index:(NSUInteger)index toolbar:(bool)toolbar
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = index;
    button.accessibilityLabel = action[@"title"];
    button.enabled = ![action[@"disabled"] boolValue];
    UIColor *color = _textColor;
    [button setImage:TGMessageMenuIcon(action[@"action"], color) forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    [button setTitleColor:[color colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    if (!toolbar)
    {
        [button setTitle:action[@"title"] forState:UIControlStateNormal];
        button.titleLabel.font = TGSystemFontOfSize(16);
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 0);
    }
    [button addTarget:self action:toolbar ? @selector(toolPressed:) : @selector(rowPressed:) forControlEvents:UIControlEventTouchUpInside];
    return button;
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
        if ([emoji isEqualToString:_chosenReaction])
        {
            button.backgroundColor = [TGPresentation.current.pallete.accentColor colorWithAlphaComponent:0.2];
            button.layer.cornerRadius = 22;
        }
        [button addTarget:self action:@selector(reactionPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_reactionBar addSubview:button];
    }
    if (_reactions.count > 7 || _expanded)
    {
        UIButton *expand = [UIButton buttonWithType:UIButtonTypeCustom];
        expand.tag = -1;
        expand.accessibilityLabel = _expanded ? TGLocalized(@"Common.Cancel") : TGLocalized(@"Common.More");
        [expand setImage:TGMessageMenuIcon(@"expand", _textColor) forState:UIControlStateNormal];
        [expand addTarget:self action:@selector(expandPressed) forControlEvents:UIControlEventTouchUpInside];
        [_reactionBar addSubview:expand];
    }
}

- (CGFloat)menuScale
{
    return _menuScale;
}

- (void)setMenuScale:(CGFloat)menuScale
{
    if (!isfinite(menuScale))
        return;
    _menuScale = MAX(0.7f, MIN(1.1f, menuScale));
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _backdrop.frame = self.bounds;
    CGFloat scale = _menuScale;
    CGFloat width = self.bounds.size.width / scale;
    CGFloat height = self.bounds.size.height / scale;
    _contents.transform = CGAffineTransformIdentity;
    _contents.bounds = CGRectMake(0, 0, width, height);
    _contents.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _contents.transform = CGAffineTransformMakeScale(scale, scale);
    CGRect sourceRect = CGRectApplyAffineTransform(_sourceRect, CGAffineTransformMakeScale(1.0f / scale, 1.0f / scale));
    CGFloat top = MAX(12, self.contentInsets.top + 6) / scale;
    CGFloat bottom = height - MAX(12, self.contentInsets.bottom + 6) / scale;
    CGFloat cardWidth = MIN(244, width - 32 / scale);
    CGFloat reactionWidth = MIN(320, width - 24 / scale);
    NSUInteger columns = MAX((NSUInteger)1, (NSUInteger)(reactionWidth / 44));
    NSUInteger buttons = 0;
    for (UIView *view in _reactionBar.subviews)
        if ([view isKindOfClass:[UIButton class]])
            buttons++;
    CGFloat availableHeight = MAX(0, bottom - top);
    CGFloat reactionHeight = _reactionBar.hidden ? 0 : (_expanded ? MIN(MIN(192, availableHeight * 0.35), ceil((CGFloat)buttons / columns) * 48 + 8) : 56);
    CGFloat toolsHeight = _toolbarActions.count == 0 ? 0 : 52;
    CGFloat toolbarGap = toolsHeight > 0 && _actions.count > 0 ? 8 : 0;
    CGFloat previewHeight = _compact ? 0 : MIN(72, sourceRect.size.height);
    CGFloat gap = _compact ? 0 : 8;
    CGFloat cardHeight = MIN(_actions.count * 44, MAX(44, MIN(176, availableHeight * (self.previewMode ? 1.0f : 0.7f) - reactionHeight - toolsHeight - toolbarGap - previewHeight - gap * 2)));
    CGFloat totalHeight = reactionHeight + (reactionHeight > 0 ? 8 : 0) + previewHeight + gap + cardHeight + toolbarGap + toolsHeight;
    CGFloat below = CGRectGetMaxY(sourceRect) + 6;
    CGFloat above = sourceRect.origin.y - totalHeight - 6;
    CGFloat y = _compact ? (below + totalHeight <= bottom ? below : above) : sourceRect.origin.y - reactionHeight - 8;
    y = MAX(top, MIN(y, bottom - totalHeight));
    bool outgoing = CGRectGetMidX(sourceRect) > width / 2;
    CGFloat cardX = outgoing ? CGRectGetMaxX(sourceRect) - cardWidth : sourceRect.origin.x;
    cardX = MAX(16, MIN(cardX, width - cardWidth - 16));
    CGFloat reactionX = MAX(12, MIN(cardX, width - reactionWidth - 12));
    _reactionBar.frame = CGRectMake(reactionX, y, reactionWidth, reactionHeight);
    if (reactionHeight > 0)
        y += reactionHeight + 8;
    _preview.frame = CGRectMake(sourceRect.origin.x, y, sourceRect.size.width, previewHeight);
    _preview.contentMode = UIViewContentModeTop;
    _preview.clipsToBounds = true;
    y += previewHeight + gap;
    _card.frame = CGRectMake(cardX, y, cardWidth, cardHeight);
    _card.hidden = _actions.count == 0;
    _rows.frame = _card.bounds;
    _rows.contentSize = CGSizeMake(cardWidth, _actions.count * 44);
    NSUInteger index = 0;
    for (UIView *view in _rows.subviews)
        if ([view isKindOfClass:[UIButton class]])
            view.frame = CGRectMake(0, index++ * 44, cardWidth, 44);
    _toolbar.frame = CGRectMake(cardX, y + cardHeight + toolbarGap, cardWidth, toolsHeight);
    _toolbar.hidden = toolsHeight == 0;
    index = 0;
    for (UIView *view in _toolbar.subviews)
        view.frame = CGRectMake(index++ * cardWidth / _toolbarActions.count, 0, cardWidth / _toolbarActions.count, toolsHeight);
    CGFloat step = _expanded ? reactionWidth / columns : reactionWidth / MAX((NSUInteger)1, buttons);
    index = 0;
    for (UIView *view in _reactionBar.subviews)
    {
        if (![view isKindOfClass:[UIButton class]])
            continue;
        view.frame = CGRectMake(_expanded ? (index % columns) * step : index * step, _expanded ? 4 + (index / columns) * 48 : 4, step, 48);
        index++;
    }
    _reactionBar.contentSize = CGSizeMake(reactionWidth, _expanded ? ceil((CGFloat)buttons / columns) * 48 + 8 : 56);
}

- (void)presentInView:(UIView *)view
{
    self.frame = view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:self];
    [self layoutIfNeeded];
    self.alpha = 0;
    [UIView animateWithDuration:0.18 animations:^{ self.alpha = 1; }];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _card);
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (_dismissing)
        return;
    _dismissing = true;
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
    [self performAction:_actions[(NSUInteger)button.tag]];
}

- (void)toolPressed:(UIButton *)button
{
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
        NSArray *actions = @[
            @{@"title": TGLocalized(@"Conversation.ContextMenuForward"), @"action": @"forward"},
            @{@"title": TGLocalized(@"Conversation.Pin"), @"action": @"pin"},
            @{@"title": TGLocalized(@"Translator.Translate"), @"action": @"translate"},
            @{@"title": TGLocalized(@"Conversation.ContextMenuReply"), @"action": @"reply"},
            @{@"title": TGLocalized(@"Conversation.ContextMenuDelete"), @"action": @"delete"},
            @{@"title": TGLocalized(@"Conversation.ContextMenuCopy"), @"action": @"copy"},
            @{@"title": TGLocalized(@"Conversation.Edit"), @"action": @"edit"}
        ];
        _menu = [[TGMessageContextMenu alloc] initWithActions:actions sourceView:self sourceRect:CGRectMake(16, 0, 120, 1) compact:true];
        _menu.previewMode = true;
        _menu.userInteractionEnabled = false;
        [_menu setReactions:@[@"❤️", @"🔥", @"👏", @"🙈", @"🐳", @"😈", @"🤡"] chosenReaction:nil];
        [self addSubview:_menu];
    }
    return self;
}

- (void)refreshPreview
{
    TGMessageMenuPreviewCollectionItem *item = (TGMessageMenuPreviewCollectionItem *)self.boundItem;
    _menu.menuScale = item.menuScale;
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
        _menuScale = 0.85f;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGMessageMenuPreviewCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 316);
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
    _menuScale = MAX(0.7f, MIN(1.1f, menuScale));
    [(TGMessageMenuPreviewCollectionItemView *)self.boundView refreshPreview];
}

@end
