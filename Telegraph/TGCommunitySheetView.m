#import "TGCommunitySheetView.h"

#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGCommunitySignals.h"
#import "../OnegramPlatform/OGPlatformVersion.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGCommunitySheetAppearance.h"
#import "../OnegramUI/Chrome/OGNavigationTitleView.h"

static const CGFloat TGCommunitySheetHeightFraction = 0.65f;
static const CGFloat TGCommunitySheetTitleHeight = 50.0f;
static const CGFloat TGCommunitySheetIndicatorTouchSize = 44.0f;

typedef enum {
    TGCommunitySheetPositionCollapsed,
    TGCommunitySheetPositionExpanded,
    TGCommunitySheetPositionDismissed
} TGCommunitySheetPosition;

static TGCommunitySheetPosition TGCommunitySheetTargetPosition(CGFloat fullTop, CGFloat halfTop, CGFloat halfHeight, CGFloat top, CGFloat velocity)
{
    CGFloat projectedTop = top + velocity * 0.2f;
    CGFloat dismissalThreshold = halfTop + halfHeight / 2.0f;
    if (top >= halfTop && (projectedTop >= dismissalThreshold || (top > halfTop + 12.0f && velocity > 550.0f)))
        return TGCommunitySheetPositionDismissed;
    return projectedTop < (fullTop + halfTop) / 2.0f ? TGCommunitySheetPositionExpanded : TGCommunitySheetPositionCollapsed;
}

@interface TGCommunitySheetView () <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>
{
    TGConversation *_conversation;
    TGPresentation *_presentation;
    id<TGCommunitySheetViewDataSource> _dataSource;
    OGCommunitySheetAppearance *_brandedAppearance;

    UIView *_dimView;
    UIButton *_indicatorButton;
    UIView *_sheetView;
    UIView *_contentBackgroundView;
    UIImageView *_headerView;
    CGFloat _headerImageWidth;
    UIView *_titleSeparatorView;
    UIView *_grabberView;
    UILabel *_titleLabel;
    OGNavigationTitleView *_brandedTitleView;
    UIPanGestureRecognizer *_headerPanGestureRecognizer;
    UITableView *_tableView;
    UIActivityIndicatorView *_activityIndicator;
    UILabel *_statusLabel;

    NSArray *_conversations;
    NSArray *_conversationJoined;
    bool _dismissing;
    bool _presented;
    bool _expanded;
    bool _dragging;
    CGFloat _dragStartY;
    CGSize _layoutSize;

    id<SDisposable> _disposable;
    id<SDisposable> _displayDisposable;
}

@end

@implementation TGCommunitySheetView

- (instancetype)initWithConversation:(TGConversation *)conversation presentation:(TGPresentation *)presentation dataSource:(id<TGCommunitySheetViewDataSource>)dataSource
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _conversation = conversation;
        _presentation = presentation;
        _dataSource = dataSource;
        _brandedAppearance = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6CommunitySheetAppearance] : nil;
        _conversations = @[];
        _conversationJoined = @[];

        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];

        _dimView = [[UIView alloc] init];
        _dimView.backgroundColor = _brandedAppearance.dimColor ?: UIColorRGBA(0x000000, 0.4f);
        _dimView.alpha = 0.0f;
        [_dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimTapped:)]];
        [self addSubview:_dimView];

        if (_brandedAppearance != nil)
        {
            _indicatorButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [_indicatorButton setImage:[TGPresentation brandedIOS6CommunitySheetIndicatorImage] forState:UIControlStateNormal];
            _indicatorButton.adjustsImageWhenHighlighted = false;
            _indicatorButton.alpha = 0.0f;
            [_indicatorButton addTarget:self action:@selector(indicatorPressed) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_indicatorButton];
        }

        _sheetView = [[UIView alloc] init];
        _sheetView.backgroundColor = [UIColor clearColor];
        _sheetView.clipsToBounds = true;
        [self addSubview:_sheetView];

        _contentBackgroundView = [[UIView alloc] init];
        _contentBackgroundView.backgroundColor = presentation.pallete.backgroundColor;
        [_sheetView addSubview:_contentBackgroundView];

        _headerView = [[UIImageView alloc] init];
        _headerView.userInteractionEnabled = true;
        if (_brandedAppearance == nil)
            _headerView.backgroundColor = presentation.pallete.barBackgroundColor;
        [_sheetView addSubview:_headerView];

        _headerPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(headerPanned:)];
        _headerPanGestureRecognizer.delegate = self;
        [_headerView addGestureRecognizer:_headerPanGestureRecognizer];

        if (_brandedAppearance != nil)
        {
            _brandedTitleView = [[OGNavigationTitleView alloc] initWithFrame:CGRectZero];
            _brandedTitleView.theme = [OGTheme brandedTheme];
            _brandedTitleView.userInteractionEnabled = false;
            [_headerView addSubview:_brandedTitleView];
        }
        else
        {
            _grabberView = [[UIView alloc] init];
            _grabberView.backgroundColor = presentation.pallete.secondaryTextColor;
            _grabberView.alpha = 0.5f;
            _grabberView.layer.cornerRadius = 2.0f;
            _grabberView.userInteractionEnabled = false;
            [_headerView addSubview:_grabberView];

            _titleSeparatorView = [[UIView alloc] init];
            _titleSeparatorView.backgroundColor = presentation.pallete.barSeparatorColor;
            [_headerView addSubview:_titleSeparatorView];

            _titleLabel = [[UILabel alloc] init];
            _titleLabel.backgroundColor = [UIColor clearColor];
            _titleLabel.font = TGBoldSystemFontOfSize(17.0f);
            _titleLabel.textColor = presentation.pallete.navigationTitleColor;
            _titleLabel.textAlignment = NSTextAlignmentCenter;
            _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [_headerView addSubview:_titleLabel];
        }
        [self setTitleText:[TGCommunitySignals cachedCommunityWithId:conversation.linkedCommunityId].title];

        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.tableFooterView = [[UIView alloc] init];
        if (OGPlatformSystemVersionAtLeast(11.0f))
            _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _tableView.hidden = true;
        [dataSource communitySheetView:self configureTableView:_tableView];
        [_sheetView addSubview:_tableView];

        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:presentation.pallete.isDark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray];
        [_sheetView addSubview:_activityIndicator];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.font = TGSystemFontOfSize(15.0f);
        _statusLabel.textColor = presentation.pallete.secondaryTextColor;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 0;
        _statusLabel.hidden = true;
        [_sheetView addSubview:_statusLabel];
    }
    return self;
}

- (void)setTitleText:(NSString *)title
{
    _titleLabel.text = title;
    _brandedTitleView.title = title;
    [self setNeedsLayout];
}

- (void)dealloc
{
    [_disposable dispose];
    [_displayDisposable dispose];
}

- (UIEdgeInsets)sheetSafeAreaInsets
{
    if (iosMajorVersion() >= 11 && [self respondsToSelector:@selector(safeAreaInsets)])
    {
        UIEdgeInsets (*insetsImp)(id, SEL) = (UIEdgeInsets (*)(id, SEL))[self methodForSelector:@selector(safeAreaInsets)];
        return insetsImp(self, @selector(safeAreaInsets));
    }

    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (self.window != nil && ![UIApplication sharedApplication].statusBarHidden)
    {
        CGRect statusBarFrame = [self.window convertRect:[UIApplication sharedApplication].statusBarFrame fromWindow:nil];
        statusBarFrame = [self convertRect:statusBarFrame fromView:self.window];
        CGRect intersection = CGRectIntersection(self.bounds, statusBarFrame);
        if (!CGRectIsNull(intersection) && CGRectGetMinY(intersection) <= CGRectGetMinY(self.bounds) + TGScreenPixel)
            insets.top = CGRectGetMaxY(intersection) - CGRectGetMinY(self.bounds);
    }
    return insets;
}

- (CGRect)sheetFrameForBounds:(CGRect)bounds expanded:(bool)expanded visible:(bool)visible
{
    CGFloat fullTop = [self sheetSafeAreaInsets].top;
    CGFloat heightFraction = _brandedAppearance != nil ? _brandedAppearance.collapsedHeightFraction : TGCommunitySheetHeightFraction;
    CGFloat top = expanded ? fullTop : MAX(fullTop, bounds.size.height - CGFloor(bounds.size.height * heightFraction));
    CGFloat height = MAX(0.0f, bounds.size.height - top);
    return CGRectMake(0.0f, visible ? top : bounds.size.height, bounds.size.width, height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _dimView.frame = bounds;
    if (_dragging && !CGSizeEqualToSize(_layoutSize, bounds.size))
    {
        _dragging = false;
        _headerPanGestureRecognizer.enabled = false;
        _headerPanGestureRecognizer.enabled = true;
        _dimView.alpha = _presented ? 1.0f : 0.0f;
    }
    _layoutSize = bounds.size;
    if (!_dismissing && !_dragging)
        _sheetView.frame = [self sheetFrameForBounds:bounds expanded:_expanded visible:_presented];

    [self layoutSheetContents];
    [self layoutIndicator];
}

- (CGFloat)headerHeight
{
    return _brandedAppearance != nil ? _brandedAppearance.headerHeight : TGCommunitySheetTitleHeight;
}

- (void)layoutSheetContents
{
    CGSize sheetSize = _sheetView.bounds.size;
    UIEdgeInsets safeInsets = [self sheetSafeAreaInsets];
    CGFloat headerHeight = [self headerHeight];
    _headerView.frame = CGRectMake(0.0f, 0.0f, sheetSize.width, headerHeight);
    if (_brandedAppearance != nil && sheetSize.width >= 1.0f && ABS(_headerImageWidth - sheetSize.width) > FLT_EPSILON)
    {
        _headerImageWidth = sheetSize.width;
        _headerView.image = [TGPresentation brandedIOS6CommunitySheetHeaderImageForWidth:sheetSize.width];
    }
    _titleSeparatorView.frame = CGRectMake(0.0f, headerHeight - TGScreenPixel, sheetSize.width, TGScreenPixel);
    _grabberView.frame = CGRectMake(CGFloor((sheetSize.width - 36.0f) / 2.0f), 6.0f, 36.0f, 4.0f);
    _titleLabel.frame = CGRectMake(safeInsets.left + 16.0f, 12.0f, MAX(0.0f, sheetSize.width - safeInsets.left - safeInsets.right - 32.0f), headerHeight - 12.0f);
    if (_brandedTitleView != nil)
    {
        CGSize titleSize = [_brandedTitleView sizeThatFits:CGSizeZero];
        CGFloat titleWidth = MIN(titleSize.width, MAX(0.0f, sheetSize.width - safeInsets.left - safeInsets.right - 32.0f));
        _brandedTitleView.frame = CGRectMake(TGScreenPixelFloor((sheetSize.width - titleWidth) / 2.0f), TGScreenPixelFloor((headerHeight - titleSize.height) / 2.0f), titleWidth, titleSize.height);
    }

    CGRect contentFrame = CGRectMake(safeInsets.left, headerHeight, MAX(0.0f, sheetSize.width - safeInsets.left - safeInsets.right), MAX(0.0f, sheetSize.height - headerHeight));
    _contentBackgroundView.frame = CGRectMake(0.0f, headerHeight, sheetSize.width, contentFrame.size.height);
    _tableView.frame = contentFrame;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0f, 0.0f, safeInsets.bottom, 0.0f);
    if (!UIEdgeInsetsEqualToEdgeInsets(_tableView.contentInset, contentInsets))
        _tableView.contentInset = contentInsets;
    _tableView.scrollIndicatorInsets = contentInsets;

    CGSize indicatorSize = _activityIndicator.bounds.size;
    _activityIndicator.frame = CGRectMake(CGFloor(CGRectGetMidX(contentFrame) - indicatorSize.width / 2.0f), CGFloor(CGRectGetMidY(contentFrame) - indicatorSize.height / 2.0f), indicatorSize.width, indicatorSize.height);

    CGFloat statusWidth = MAX(0.0f, contentFrame.size.width - 40.0f);
    CGSize statusSize = [_statusLabel sizeThatFits:CGSizeMake(statusWidth, contentFrame.size.height)];
    _statusLabel.frame = CGRectMake(contentFrame.origin.x + 20.0f, CGFloor(CGRectGetMidY(contentFrame) - statusSize.height / 2.0f), statusWidth, statusSize.height);
}

- (void)layoutIndicator
{
    if (_indicatorButton == nil)
        return;

    CGRect sheetFrame = _sheetView.frame;
    CGRect fullFrame = [self sheetFrameForBounds:self.bounds expanded:true visible:true];
    CGRect halfFrame = [self sheetFrameForBounds:self.bounds expanded:false visible:true];
    CGSize imageSize = [_indicatorButton imageForState:UIControlStateNormal].size;
    CGFloat imageBottom = sheetFrame.origin.y - _brandedAppearance.indicatorSpacing;
    _indicatorButton.frame = CGRectMake(TGScreenPixelFloor((self.bounds.size.width - TGCommunitySheetIndicatorTouchSize) / 2.0f), TGScreenPixelFloor(imageBottom - imageSize.height / 2.0f - TGCommunitySheetIndicatorTouchSize / 2.0f), TGCommunitySheetIndicatorTouchSize, TGCommunitySheetIndicatorTouchSize);

    CGFloat range = halfFrame.origin.y - fullFrame.origin.y;
    CGFloat progress = range > FLT_EPSILON ? MAX(0.0f, MIN(1.0f, (sheetFrame.origin.y - fullFrame.origin.y) / range)) : 0.0f;
    _indicatorButton.alpha = progress * _dimView.alpha;
}

- (void)indicatorPressed
{
    if (_presented && !_dismissing && !_dragging)
        [self settleExpanded:true];
}

- (void)showInView:(UIView *)view
{
    self.frame = view.bounds;
    [view addSubview:self];
    [self layoutIfNeeded];

    _sheetView.frame = [self sheetFrameForBounds:self.bounds expanded:_expanded visible:false];
    [self layoutIndicator];
    _presented = true;
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^
    {
        _dimView.alpha = 1.0f;
        _sheetView.frame = [self sheetFrameForBounds:self.bounds expanded:_expanded visible:true];
        [self layoutIndicator];
    } completion:nil];

    [self loadChats];
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (_dismissing)
        return;
    _dismissing = true;
    _dragging = false;
    _headerPanGestureRecognizer.enabled = false;
    [_disposable dispose];
    [_displayDisposable dispose];

    void (^finish)(void) = ^
    {
        [self removeFromSuperview];
        if (completion)
            completion();
    };

    if (!animated)
    {
        finish();
        return;
    }

    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^
    {
        _dimView.alpha = 0.0f;
        CGRect frame = _sheetView.frame;
        frame.origin.y = self.bounds.size.height;
        _sheetView.frame = frame;
        [self layoutIndicator];
    } completion:^(__unused BOOL finished)
    {
        finish();
    }];
}

- (void)dimTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
        [self dismissAnimated:true completion:nil];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _headerPanGestureRecognizer)
    {
        CGPoint velocity = [_headerPanGestureRecognizer velocityInView:self];
        return _presented && !_dismissing && ABS(velocity.y) > ABS(velocity.x);
    }
    return YES;
}

- (void)settleExpanded:(bool)expanded
{
    _expanded = expanded;
    _dragging = false;
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut animations:^
    {
        _sheetView.frame = [self sheetFrameForBounds:self.bounds expanded:_expanded visible:true];
        _dimView.alpha = 1.0f;
        [self layoutSheetContents];
        [self layoutIndicator];
    } completion:nil];
}

- (void)headerPanned:(UIPanGestureRecognizer *)recognizer
{
    if (_dismissing || !_presented)
        return;

    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        CALayer *sheetLayer = _sheetView.layer.presentationLayer;
        CGRect frame = sheetLayer != nil ? sheetLayer.frame : _sheetView.frame;
        CALayer *dimLayer = _dimView.layer.presentationLayer;
        CGFloat alpha = dimLayer != nil ? dimLayer.opacity : _dimView.alpha;
        [_sheetView.layer removeAllAnimations];
        [_dimView.layer removeAllAnimations];
        [_tableView.layer removeAllAnimations];
        [_statusLabel.layer removeAllAnimations];
        [_activityIndicator.layer removeAnimationForKey:@"position"];
        [_indicatorButton.layer removeAllAnimations];
        _sheetView.frame = frame;
        _dimView.alpha = alpha;
        _dragStartY = frame.origin.y;
        _dragging = true;
        [recognizer setTranslation:CGPointZero inView:self];
        [self layoutSheetContents];
        [self layoutIndicator];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged && _dragging)
    {
        CGRect fullFrame = [self sheetFrameForBounds:self.bounds expanded:true visible:true];
        CGRect halfFrame = [self sheetFrameForBounds:self.bounds expanded:false visible:true];
        CGFloat height = self.bounds.size.height;
        CGFloat top = MAX(fullFrame.origin.y, MIN(height, _dragStartY + [recognizer translationInView:self].y));
        _sheetView.frame = CGRectMake(0.0f, top, self.bounds.size.width, height - top);
        _dimView.alpha = MIN(1.0f, MAX(0.0f, (height - top) / MAX(1.0f, halfFrame.size.height)));
        [self layoutSheetContents];
        [self layoutIndicator];
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded && _dragging)
    {
        CGRect fullFrame = [self sheetFrameForBounds:self.bounds expanded:true visible:true];
        CGRect halfFrame = [self sheetFrameForBounds:self.bounds expanded:false visible:true];
        CGFloat top = _sheetView.frame.origin.y;
        CGFloat velocity = [recognizer velocityInView:self].y;
        TGCommunitySheetPosition position = TGCommunitySheetTargetPosition(fullFrame.origin.y, halfFrame.origin.y, halfFrame.size.height, top, velocity);
        if (position == TGCommunitySheetPositionDismissed)
            [self dismissAnimated:true completion:nil];
        else
            [self settleExpanded:position == TGCommunitySheetPositionExpanded];
    }
    else if ((recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) && _dragging)
    {
        [self settleExpanded:_expanded];
    }
}

- (void)loadChats
{
    [_activityIndicator startAnimating];

    __weak TGCommunitySheetView *weakSelf = self;
    _disposable = [[[TGCommunitySignals communityChatsForConversation:_conversation] deliverOn:[SQueue mainQueue]] startWithNext:^(TGCommunityChats *chats)
    {
        __strong TGCommunitySheetView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyChats:chats];
    } error:^(__unused id error)
    {
        __strong TGCommunitySheetView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyFailure];
    } completed:nil];
}

- (void)applyChats:(TGCommunityChats *)chats
{
    if (chats.community.title.length != 0)
        [self setTitleText:chats.community.title];

    NSMutableArray *conversations = [[NSMutableArray alloc] init];
    NSMutableArray *conversationJoined = [[NSMutableArray alloc] init];
    for (TGConversation *conversation in chats.joinedConversations)
    {
        [conversations addObject:conversation];
        [conversationJoined addObject:@true];
    }
    for (TGConversation *conversation in chats.viewableConversations)
    {
        [conversations addObject:conversation];
        [conversationJoined addObject:@false];
    }

    if (conversations.count == 0)
    {
        [self applyConversations:@[] joined:@[]];
        return;
    }

    __weak TGCommunitySheetView *weakSelf = self;
    [_displayDisposable dispose];
    _displayDisposable = [[[_dataSource communitySheetView:self displayConversations:conversations] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *displayConversations)
    {
        __strong TGCommunitySheetView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyConversations:displayConversations joined:conversationJoined];
    } error:^(__unused id error)
    {
        __strong TGCommunitySheetView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyFailure];
    } completed:nil];
}

- (void)applyConversations:(NSArray *)conversations joined:(NSArray *)conversationJoined
{
    [_activityIndicator stopAnimating];
    _activityIndicator.hidden = true;

    _conversations = conversations;
    _conversationJoined = conversationJoined;

    _tableView.hidden = conversations.count == 0;
    _statusLabel.hidden = conversations.count != 0;
    _statusLabel.text = TGLocalized(@"Community.NoChats");
    [_tableView reloadData];
    [self setNeedsLayout];
}

- (void)applyFailure
{
    [_activityIndicator stopAnimating];
    _activityIndicator.hidden = true;
    _tableView.hidden = true;
    _statusLabel.hidden = false;
    _statusLabel.text = TGLocalized(@"Community.LoadFailed");
    [self setNeedsLayout];
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return (NSInteger)_conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [_dataSource communitySheetView:self tableView:tableView cellForConversation:_conversations[(NSUInteger)indexPath.row]];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    [_dataSource communitySheetView:self tableView:tableView willDisplayCell:cell];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:true];

    TGConversation *conversation = _conversations[(NSUInteger)indexPath.row];
    bool joined = [_conversationJoined[(NSUInteger)indexPath.row] boolValue];

    void (^conversationSelected)(TGConversation *, bool) = _conversationSelected;
    [self dismissAnimated:true completion:^
    {
        if (conversationSelected)
            conversationSelected(conversation, joined);
    }];
}

@end
