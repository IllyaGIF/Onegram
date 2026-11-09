#import "TGStoryViewerController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryVideoView.h"
#endif

#import "TGStoryItem.h"
#import "TGStoriesSignals.h"
#import "TGStoriesStore.h"
#import "TGSharedPhotoSignals.h"
#import "TGSharedVideoSignals.h"
#import "TGSharedMediaUtils.h"
#import "TGVideoDownloadActor.h"
#import "OGMediaStreamServer.h"
#import "OGMediaFetchDescriptor+Telegraph.h"
#import "TGAudioSessionManager.h"
#import "TGCustomActionSheet.h"
#import "TGCustomAlertView.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTLDynamic.h"
#import "../OnegramRuntime/OGRemoteClock.h"
#import "../OnegramPlatform/OGPlatformMedia.h"

static const NSTimeInterval TGStoryPhotoDuration = 6.0;
static const NSTimeInterval TGStoryTimerInterval = 1.0 / 30.0;
static const NSTimeInterval TGStoryPartialImageGrace = 2.5;

@interface TGStoryImageView : TGImageView

@property (nonatomic, copy) void (^imageCommitted)(bool partial);

@end

@implementation TGStoryImageView

- (void)_commitImage:(UIImage *)image partial:(bool)partial loadTime:(NSTimeInterval)loadTime
{
    [super _commitImage:image partial:partial loadTime:loadTime];
    if (image != nil && _imageCommitted != nil)
        _imageCommitted(partial);
}

@end

@interface TGStoryProgressView : UIView
{
    NSMutableArray *_tracks;
    NSMutableArray *_fills;
    NSUInteger _currentIndex;
    CGFloat _progress;
}

- (void)setCount:(NSUInteger)count;
- (void)setCurrentIndex:(NSUInteger)index progress:(CGFloat)progress;

@end

@implementation TGStoryProgressView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        _tracks = [[NSMutableArray alloc] init];
        _fills = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setCount:(NSUInteger)count
{
    while (_tracks.count > count)
    {
        [[_tracks lastObject] removeFromSuperview];
        [_tracks removeLastObject];
        [[_fills lastObject] removeFromSuperview];
        [_fills removeLastObject];
    }
    while (_tracks.count < count)
    {
        UIView *track = [[UIView alloc] init];
        track.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.35f];
        track.layer.cornerRadius = 1.0f;
        track.clipsToBounds = true;
        [self addSubview:track];
        [_tracks addObject:track];

        UIView *fill = [[UIView alloc] init];
        fill.backgroundColor = [UIColor whiteColor];
        [track addSubview:fill];
        [_fills addObject:fill];
    }
    [self setNeedsLayout];
}

- (void)setCurrentIndex:(NSUInteger)index progress:(CGFloat)progress
{
    _currentIndex = index;
    _progress = MAX(0.0f, MIN(1.0f, progress));
    [self layoutFills];
}

- (void)layoutFills
{
    for (NSUInteger i = 0; i < _tracks.count; i++)
    {
        UIView *track = [_tracks objectAtIndex:i];
        UIView *fill = [_fills objectAtIndex:i];
        CGFloat fraction = i < _currentIndex ? 1.0f : (i == _currentIndex ? _progress : 0.0f);
        fill.frame = CGRectMake(0.0f, 0.0f, CGFloor(track.bounds.size.width * fraction), track.bounds.size.height);
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    NSUInteger count = _tracks.count;
    if (count == 0)
        return;
    CGFloat spacing = 3.0f;
    CGFloat width = (self.bounds.size.width - spacing * (count - 1)) / count;
    for (NSUInteger i = 0; i < count; i++)
    {
        UIView *track = [_tracks objectAtIndex:i];
        track.frame = CGRectMake(CGFloor(i * (width + spacing)), 0.0f, CGFloor(width), 2.0f);
    }
    [self layoutFills];
}

@end

static UIImage *TGStoryGradientImage(bool top)
{
    CGSize size = CGSizeMake(1.0f, 64.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {0.0f, 0.0f, 0.0f, 0.55f, 0.0f, 0.0f, 0.0f, 0.0f};
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGPoint start = top ? CGPointZero : CGPointMake(0.0f, size.height);
    CGPoint end = top ? CGPointMake(0.0f, size.height) : CGPointZero;
    CGContextDrawLinearGradient(context, gradient, start, end, 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TGStoryCloseImage(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0f, 20.0f), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, 4.0f, 4.0f);
    CGContextAddLineToPoint(context, 16.0f, 16.0f);
    CGContextMoveToPoint(context, 16.0f, 4.0f);
    CGContextAddLineToPoint(context, 4.0f, 16.0f);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TGStoryMoreImage(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(22.0f, 20.0f), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    for (int i = 0; i < 3; i++)
        CGContextFillEllipseInRect(context, CGRectMake(2.0f + i * 7.0f, 8.0f, 4.0f, 4.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static NSString *TGStoryRelativeTime(int32_t date)
{
    int32_t delta = (int32_t)OGRemoteClockTime() - date;
    if (delta < 60)
        return TGLocalized(@"OnegramStories.JustNow");
    if (delta < 60 * 60)
        return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramStories.MinutesAgo"), (int)(delta / 60)];
    if (delta < 24 * 60 * 60)
        return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramStories.HoursAgo"), (int)(delta / 3600)];
    return [TGDateUtils stringForMessageListDate:date];
}

@interface TGStoryViewerController () <ASWatcher>
{
    NSMutableArray *_peerStoriesList;
    NSUInteger _peerIndex;
    NSUInteger _storyIndex;
    TGStoryItem *_story;

    UIView *_mediaView;
    TGStoryImageView *_imageView;
    UIView *_videoContainer;
    UIImageView *_topGradientView;
    UIImageView *_bottomGradientView;
    TGStoryProgressView *_progressView;
    TGLetteredAvatarView *_avatarView;
    UILabel *_nameLabel;
    UILabel *_timeLabel;
    UIButton *_closeButton;
    UIButton *_moreButton;
    UILabel *_captionLabel;
    UILabel *_viewsLabel;
    UIActivityIndicatorView *_activityIndicator;

    NSTimer *_timer;
    NSTimeInterval _elapsed;
    NSTimeInterval _duration;
    NSTimeInterval _partialImageTime;
    bool _mediaReady;
    bool _hasPartialImage;
    bool _holdPaused;
    bool _actionPaused;
    bool _dismissing;
    NSUInteger _displayGeneration;
    CFAbsoluteTime _gestureEndTime;

    NSString *_downloadingVideoPath;
    OGMediaStream *_videoStream;
    SMetaDisposable *_storyFetchDisposable;
    SMetaDisposable *_audioSessionDisposable;
    NSMutableSet *_viewedStoryKeys;

    id _playbackFinishedObserver;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    OGPlatformMoviePlayer *_moviePlayer;
#else
    AVPlayer *_player;
    TGModernGalleryVideoView *_videoView;
#endif
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGStoryViewerController

+ (void)presentActiveStoriesForPeerId:(int64_t)peerId fromController:(UIViewController *)controller
{
    if (controller == nil || peerId == 0)
        return;
    TGPeerStories *cached = [[TGStoriesStore instance] peerStoriesForPeerId:peerId];
    if (cached.stories.count != 0)
    {
        [self presentActiveStoriesList:@[cached] peerIndex:0 fromController:controller];
        return;
    }
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak UIViewController *weakController = controller;
    [[[[TGStoriesStore instance] peerStoriesSignal:peerId] deliverOn:[SQueue mainQueue]] startWithNext:^(TGPeerStories *peerStories)
    {
        [progressWindow dismiss:true];
        __strong UIViewController *strongController = weakController;
        if (strongController == nil)
            return;
        if (peerStories.stories.count == 0)
            return;
        [self presentActiveStoriesList:@[peerStories] peerIndex:0 fromController:strongController];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
    } completed:nil];
}

+ (void)presentActiveStoriesList:(NSArray *)peerStoriesList peerIndex:(NSUInteger)peerIndex fromController:(UIViewController *)controller
{
    if (peerIndex >= peerStoriesList.count)
        return;
    TGPeerStories *peerStories = [peerStoriesList objectAtIndex:peerIndex];
    TGStoryViewerController *viewer = [[TGStoryViewerController alloc] initWithPeerStories:peerStoriesList peerIndex:peerIndex storyIndex:[peerStories firstUnreadIndex]];
    viewer.marksStoriesAsRead = true;
    [controller presentViewController:viewer animated:true completion:nil];
}

- (instancetype)initWithPeerStories:(NSArray *)peerStoriesList peerIndex:(NSUInteger)peerIndex storyIndex:(NSUInteger)storyIndex
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _peerStoriesList = [[NSMutableArray alloc] initWithArray:peerStoriesList];
        _peerIndex = MIN(peerIndex, peerStoriesList.count == 0 ? 0 : peerStoriesList.count - 1);
        _storyIndex = storyIndex;
        _storyFetchDisposable = [[SMetaDisposable alloc] init];
        _audioSessionDisposable = [[SMetaDisposable alloc] init];
        _viewedStoryKeys = [[NSMutableSet alloc] init];
        self.automaticallyManageScrollViewInsets = false;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    [_timer invalidate];
    [_storyFetchDisposable dispose];
    [_audioSessionDisposable dispose];
    [self stopVideo];
}

- (BOOL)prefersStatusBarHidden
{
    return true;
}

- (bool)shouldIgnoreStatusBar
{
    return true;
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];

    _mediaView = [[UIView alloc] initWithFrame:self.view.bounds];
    _mediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mediaView.clipsToBounds = true;
    _mediaView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_mediaView];

    _imageView = [[TGStoryImageView alloc] initWithFrame:_mediaView.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    [_mediaView addSubview:_imageView];

    _videoContainer = [[UIView alloc] initWithFrame:_mediaView.bounds];
    _videoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _videoContainer.userInteractionEnabled = false;
    [_mediaView addSubview:_videoContainer];

    _topGradientView = [[UIImageView alloc] initWithImage:TGStoryGradientImage(true)];
    [self.view addSubview:_topGradientView];
    _bottomGradientView = [[UIImageView alloc] initWithImage:TGStoryGradientImage(false)];
    [self.view addSubview:_bottomGradientView];

    _progressView = [[TGStoryProgressView alloc] init];
    [self.view addSubview:_progressView];

    _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
    [_avatarView setSingleFontSize:14.0f doubleFontSize:14.0f useBoldFont:true];
    _avatarView.fadeTransition = true;
    [self.view addSubview:_avatarView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.backgroundColor = [UIColor clearColor];
    _nameLabel.textColor = [UIColor whiteColor];
    _nameLabel.font = TGBoldSystemFontOfSize(15.0f);
    [self.view addSubview:_nameLabel];

    _timeLabel = [[UILabel alloc] init];
    _timeLabel.backgroundColor = [UIColor clearColor];
    _timeLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.75f];
    _timeLabel.font = TGSystemFontOfSize(13.0f);
    [self.view addSubview:_timeLabel];

    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_closeButton setImage:TGStoryCloseImage() forState:UIControlStateNormal];
    _closeButton.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
    [_closeButton addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];

    _moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_moreButton setImage:TGStoryMoreImage() forState:UIControlStateNormal];
    _moreButton.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
    [_moreButton addTarget:self action:@selector(morePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_moreButton];

    _captionLabel = [[UILabel alloc] init];
    _captionLabel.backgroundColor = [UIColor clearColor];
    _captionLabel.textColor = [UIColor whiteColor];
    _captionLabel.font = TGSystemFontOfSize(15.0f);
    _captionLabel.numberOfLines = 4;
    _captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.view addSubview:_captionLabel];

    _viewsLabel = [[UILabel alloc] init];
    _viewsLabel.backgroundColor = [UIColor clearColor];
    _viewsLabel.textColor = [UIColor whiteColor];
    _viewsLabel.font = TGSystemFontOfSize(14.0f);
    [self.view addSubview:_viewsLabel];

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.hidesWhenStopped = true;
    [self.view addSubview:_activityIndicator];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    [_mediaView addGestureRecognizer:tapRecognizer];

    UILongPressGestureRecognizer *holdRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(holdGesture:)];
    holdRecognizer.minimumPressDuration = 0.25;
    [_mediaView addGestureRecognizer:holdRecognizer];
    [tapRecognizer requireGestureRecognizerToFail:holdRecognizer];

    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    [_mediaView addGestureRecognizer:panRecognizer];

    __weak TGStoryViewerController *weakSelf = self;
    _imageView.imageCommitted = ^(bool partial)
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf imageCommitted:partial];
    };
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_story == nil)
        [self displayCurrentStory];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startTimer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_timer invalidate];
    _timer = nil;
}

- (void)startTimer
{
    if (_timer != nil)
        return;
    _timer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerTick) interval:TGStoryTimerInterval repeat:true];
}

- (UIEdgeInsets)contentInsets
{
    UIEdgeInsets insets = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation];
    if (insets.top < FLT_EPSILON && iosMajorVersion() < 7)
        insets.top = 0.0f;
    return insets;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutInterface];
}

- (void)layoutInterface
{
    CGRect bounds = self.view.bounds;
    UIEdgeInsets insets = [self contentInsets];
    CGFloat top = insets.top + 8.0f;
    CGFloat side = 8.0f;

    _topGradientView.frame = CGRectMake(0.0f, 0.0f, bounds.size.width, top + 70.0f);
    _progressView.frame = CGRectMake(side + insets.left, top, bounds.size.width - side * 2.0f - insets.left - insets.right, 2.0f);
    _avatarView.frame = CGRectMake(12.0f + insets.left, top + 12.0f, 32.0f, 32.0f);
    _closeButton.frame = CGRectMake(bounds.size.width - 44.0f - insets.right, top + 6.0f, 44.0f, 44.0f);
    _moreButton.frame = CGRectMake(CGRectGetMinX(_closeButton.frame) - 40.0f, top + 6.0f, 44.0f, 44.0f);
    CGFloat textLeft = CGRectGetMaxX(_avatarView.frame) + 8.0f;
    CGFloat textRight = (_moreButton.hidden ? CGRectGetMinX(_closeButton.frame) : CGRectGetMinX(_moreButton.frame)) - 4.0f;
    _nameLabel.frame = CGRectMake(textLeft, top + 11.0f, MAX(0.0f, textRight - textLeft), 18.0f);
    _timeLabel.frame = CGRectMake(textLeft, top + 29.0f, MAX(0.0f, textRight - textLeft), 16.0f);

    CGFloat captionWidth = bounds.size.width - 32.0f - insets.left - insets.right;
    CGSize captionSize = _captionLabel.text.length == 0 ? CGSizeZero : [_captionLabel sizeThatFits:CGSizeMake(captionWidth, 200.0f)];
    CGFloat bottom = bounds.size.height - insets.bottom - 16.0f;
    CGFloat viewsHeight = _viewsLabel.hidden ? 0.0f : 20.0f;
    _viewsLabel.frame = CGRectMake(16.0f + insets.left, bottom - viewsHeight, captionWidth, viewsHeight);
    CGFloat captionBottom = bottom - viewsHeight - (viewsHeight > 0.0f ? 8.0f : 0.0f);
    _captionLabel.frame = CGRectMake(16.0f + insets.left, captionBottom - CGCeil(captionSize.height), captionWidth, CGCeil(captionSize.height));
    CGFloat bottomGradientHeight = bounds.size.height - MIN(CGRectGetMinY(_captionLabel.frame), CGRectGetMinY(_viewsLabel.frame)) + 40.0f;
    _bottomGradientView.hidden = captionSize.height < FLT_EPSILON && _viewsLabel.hidden;
    _bottomGradientView.frame = CGRectMake(0.0f, bounds.size.height - bottomGradientHeight, bounds.size.width, bottomGradientHeight);
    _activityIndicator.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _moviePlayer.view.frame = _videoContainer.bounds;
#else
    _videoView.frame = _videoContainer.bounds;
#endif
}

#pragma mark - Model

- (TGPeerStories *)currentPeerStories
{
    return _peerIndex < _peerStoriesList.count ? [_peerStoriesList objectAtIndex:_peerIndex] : nil;
}

- (bool)isOwnPeer
{
    return [self currentPeerStories].peerId == TGTelegraphInstance.clientUserId;
}

- (void)updateHeaderForPeerId:(int64_t)peerId
{
    UIImage *placeholder = [[UIImage alloc] init];
    NSString *filter = @"circle:32x32";
    if (TGPeerIdIsUser(peerId))
    {
        TGUser *user = [TGDatabaseInstance() loadUser:peerId];
        _nameLabel.text = peerId == TGTelegraphInstance.clientUserId ? TGLocalized(@"OnegramStories.MyStory") : user.displayName;
        NSString *avatarUrl = user.photoFullUrlSmall.length != 0 ? user.photoFullUrlSmall : user.photoUrlSmall;
        if (avatarUrl.length != 0)
            [_avatarView loadImage:avatarUrl filter:filter placeholder:placeholder];
        else
            [_avatarView loadUserPlaceholderWithSize:CGSizeMake(32.0f, 32.0f) uid:user.uid firstName:user.firstName lastName:user.lastName placeholder:placeholder];
    }
    else
    {
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
        _nameLabel.text = conversation.chatTitle;
        NSString *avatarUrl = conversation.chatPhotoFullSmall.length != 0 ? conversation.chatPhotoFullSmall : conversation.chatPhotoSmall;
        if (avatarUrl.length != 0)
            [_avatarView loadImage:avatarUrl filter:filter placeholder:placeholder];
        else
            [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(32.0f, 32.0f) conversationId:peerId title:conversation.chatTitle placeholder:placeholder];
    }
}

- (void)displayCurrentStory
{
    TGPeerStories *peerStories = [self currentPeerStories];
    if (peerStories == nil || peerStories.stories.count == 0)
    {
        [self dismissViewer];
        return;
    }
    if (_storyIndex >= peerStories.stories.count)
        _storyIndex = peerStories.stories.count - 1;

    _displayGeneration++;
    [self stopVideo];
    [_storyFetchDisposable setDisposable:nil];
    if (_downloadingVideoPath != nil)
    {
        [ActionStageInstance() removeWatcher:self fromPath:_downloadingVideoPath];
        _downloadingVideoPath = nil;
    }

    _story = [peerStories.stories objectAtIndex:_storyIndex];
    _elapsed = 0.0;
    _duration = TGStoryPhotoDuration;
    _mediaReady = false;
    _hasPartialImage = false;
    _partialImageTime = 0.0;

    [self updateHeaderForPeerId:peerStories.peerId];
    _timeLabel.text = TGStoryRelativeTime(_story.date);
    [_progressView setCount:peerStories.stories.count];
    [_progressView setCurrentIndex:_storyIndex progress:0.0f];
    _moreButton.hidden = ![self isOwnPeer];
    _captionLabel.text = _story.caption;
    _viewsLabel.hidden = !([self isOwnPeer] && _story.hasViewsCount);
    _viewsLabel.text = _viewsLabel.hidden ? nil : [[NSString alloc] initWithFormat:TGLocalized(@"OnegramStories.ViewsCount"), (int)_story.viewsCount];
    [self layoutInterface];

    [_imageView reset];
    _videoContainer.hidden = true;

    if (![_story hasMedia])
    {
        [self fetchFullStory];
        return;
    }

    [self registerViewOfCurrentStory];

    CGSize screenSize = self.view.bounds.size;
    if (_story.image != nil)
    {
        [_activityIndicator startAnimating];
        [_imageView setSignal:[TGSharedPhotoSignals sharedPhotoImage:_story.image size:screenSize threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:nil cacheKey:[[NSString alloc] initWithFormat:@"story-%lld-%d", _story.peerId, _story.storyId]]];
    }
    else if (_story.video != nil)
    {
        if (_story.videoDuration > 0.5)
            _duration = _story.videoDuration;
        [_imageView setSignal:[TGSharedVideoSignals squareVideoThumbnail:_story.video ofSize:screenSize threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:nil downloadLargeThumbnail:true]];
        [self prepareVideo];
    }
}

- (void)fetchFullStory
{
    TGPeerStories *peerStories = [self currentPeerStories];
    NSMutableArray *storyIds = [[NSMutableArray alloc] init];
    for (TGStoryItem *item in peerStories.stories)
    {
        if (![item hasMedia])
            [storyIds addObject:@(item.storyId)];
    }
    if (storyIds.count == 0)
    {
        [self advanceToNext];
        return;
    }
    [_activityIndicator startAnimating];
    NSUInteger generation = _displayGeneration;
    int64_t peerId = peerStories.peerId;
    __weak TGStoryViewerController *weakSelf = self;
    [_storyFetchDisposable setDisposable:[[[TGStoriesSignals storiesWithPeerId:peerId storyIds:storyIds] deliverOn:[SQueue mainQueue]] startWithNext:^(TGStoriesPage *page)
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_displayGeneration != generation)
            return;
        [strongSelf replaceStoriesForPeerId:peerId withStories:page.stories];
    } error:^(__unused id error)
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_displayGeneration == generation)
        {
            [strongSelf->_activityIndicator stopAnimating];
            [strongSelf advanceToNext];
        }
    } completed:nil]];
}

- (void)replaceStoriesForPeerId:(int64_t)peerId withStories:(NSArray *)stories
{
    for (NSUInteger i = 0; i < _peerStoriesList.count; i++)
    {
        TGPeerStories *peerStories = [_peerStoriesList objectAtIndex:i];
        if (peerStories.peerId != peerId)
            continue;
        NSMutableArray *fetched = [[NSMutableArray alloc] init];
        NSMutableArray *missingIds = [[NSMutableArray alloc] init];
        for (TGStoryItem *item in peerStories.stories)
        {
            if (![item hasMedia])
                [missingIds addObject:@(item.storyId)];
        }
        for (TGStoryItem *item in stories)
        {
            if ([item hasMedia])
                [fetched addObject:item];
            [missingIds removeObject:@(item.storyId)];
        }
        for (NSNumber *storyId in missingIds)
        {
            TGStoryItem *deleted = [TGStoryItem storyItemWithObject:[TGTLDynamicObject objectWithConstructor:@"storyItemDeleted" fields:@{@"id": storyId}] peerId:peerId];
            if (deleted != nil)
                [fetched addObject:deleted];
        }
        TGPeerStories *updated = [peerStories peerStoriesByMergingStories:fetched];
        [_peerStoriesList replaceObjectAtIndex:i withObject:updated];
        if (i == _peerIndex)
        {
            NSUInteger index = NSNotFound;
            for (NSUInteger j = 0; j < updated.stories.count; j++)
            {
                if (((TGStoryItem *)[updated.stories objectAtIndex:j]).storyId == _story.storyId)
                {
                    index = j;
                    break;
                }
            }
            if (index == NSNotFound)
                index = MIN(_storyIndex, updated.stories.count == 0 ? 0 : updated.stories.count - 1);
            _storyIndex = index;
            [_activityIndicator stopAnimating];
            [self displayCurrentStory];
        }
        break;
    }
}

- (void)registerViewOfCurrentStory
{
    int64_t peerId = [self currentPeerStories].peerId;
    NSString *key = [[NSString alloc] initWithFormat:@"%lld:%d", peerId, _story.storyId];
    if ([_viewedStoryKeys containsObject:key])
        return;
    [_viewedStoryKeys addObject:key];
    if (peerId == TGTelegraphInstance.clientUserId)
        return;
    if (_marksStoriesAsRead)
        [[TGStoriesStore instance] markStory:_story seenForPeerId:peerId];
    else
        [[TGStoriesSignals incrementViews:peerId storyIds:@[@(_story.storyId)]] startWithNext:nil];
}

- (void)imageCommitted:(bool)partial
{
    if (_story.image == nil)
        return;
    if (!partial)
    {
        _mediaReady = true;
        [_activityIndicator stopAnimating];
    }
    else if (!_hasPartialImage)
    {
        _hasPartialImage = true;
        _partialImageTime = CFAbsoluteTimeGetCurrent();
    }
}

#pragma mark - Video

- (NSString *)localVideoPath
{
    NSString *url = [_story.video.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:NULL];
    return url.length == 0 ? nil : [TGVideoDownloadActor localPathForVideoUrl:url];
}

- (void)prepareVideo
{
    NSString *videoPath = [self localVideoPath];
    if (videoPath != nil && [OGMediaFetchDescriptor isDecodableOriginalOfVideoAttachment:_story.video] && [[NSFileManager defaultManager] fileExistsAtPath:videoPath])
    {
        [self playVideoAtURL:[NSURL fileURLWithPath:videoPath]];
        return;
    }
    if ([OGMediaFetchDescriptor isStreamableVideoAttachment:_story.video])
    {
        NSString *publishPath = nil;
        OGMediaFetchDescriptor *descriptor = [OGMediaFetchDescriptor descriptorForStreamingVideoAttachment:_story.video publishPath:&publishPath];
        if (descriptor != nil && publishPath.length != 0 && [[NSFileManager defaultManager] fileExistsAtPath:publishPath])
        {
            [self playVideoAtURL:[NSURL fileURLWithPath:publishPath]];
            return;
        }
        OGMediaStream *stream = descriptor != nil ? [[OGMediaStreamServer sharedServer] streamWithDescriptor:descriptor publishPath:publishPath mimeType:@"video/mp4" pathExtension:@"mp4"] : nil;
        if (stream != nil)
        {
            _videoStream = stream;
            [self playVideoAtURL:stream.URL];
            return;
        }
    }
    NSString *url = [_story.video.videoInfo urlWithQuality:1 actualQuality:NULL actualSize:NULL];
    if (url.length == 0)
    {
        [self advanceToNext];
        return;
    }
    [_activityIndicator startAnimating];
    _downloadingVideoPath = [[NSString alloc] initWithFormat:@"/as/media/video/(%@)", url];
    [ActionStageInstance() requestActor:_downloadingVideoPath options:@{@"videoAttachment": _story.video} watcher:self];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result
{
    TGDispatchOnMainThread(^
    {
        if (![path isEqualToString:_downloadingVideoPath])
            return;
        _downloadingVideoPath = nil;
        if (status != ASStatusSuccess)
        {
            [_activityIndicator stopAnimating];
            [self advanceToNext];
            return;
        }
        NSString *videoPath = [self localVideoPath];
        if (videoPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:videoPath])
            [self playVideoAtURL:[NSURL fileURLWithPath:videoPath]];
        else
            [self advanceToNext];
    });
}

- (void)playVideoAtURL:(NSURL *)videoURL
{
    [_activityIndicator stopAnimating];
    __weak TGStoryViewerController *weakSelf = self;
    [_audioSessionDisposable setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayVideo interrupted:^
    {
        TGDispatchOnMainThread(^
        {
            __strong TGStoryViewerController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf stopVideo];
        });
    }]];

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _moviePlayer = [[OGPlatformMoviePlayer alloc] initWithURL:videoURL];
    if (_moviePlayer == nil)
    {
        [self advanceToNext];
        return;
    }
    _moviePlayer.playbackFinished = ^
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf videoPlaybackFinished:nil];
    };
    UIView *movieView = _moviePlayer.view;
    if (movieView != nil)
    {
        movieView.frame = _videoContainer.bounds;
        movieView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_videoContainer addSubview:movieView];
        _videoContainer.hidden = false;
    }
    _mediaReady = true;
    _duration = MAX(_duration, 1.0);
    [_moviePlayer play];
#else
    _player = [[AVPlayer alloc] initWithURL:videoURL];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    _playbackFinishedObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(videoPlaybackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:[_player currentItem]];
    _videoView = [[TGModernGalleryVideoView alloc] initWithFrame:_videoContainer.bounds player:_player];
    _videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_videoContainer addSubview:_videoView];
    _videoContainer.hidden = false;
    _mediaReady = true;
    [_player play];
#endif
}

- (void)stopVideo
{
    _playbackFinishedObserver = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _moviePlayer.playbackFinished = nil;
    [_moviePlayer stop];
    [_moviePlayer.view removeFromSuperview];
    _moviePlayer = nil;
#else
    [_player pause];
    [_videoView cleanupPlayer];
    [_videoView removeFromSuperview];
    _videoView = nil;
    _player = nil;
#endif
    [_videoStream invalidate];
    _videoStream = nil;
    [_audioSessionDisposable setDisposable:nil];
}

- (void)setVideoPaused:(bool)paused
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    if (paused)
        [_moviePlayer pause];
    else
        [_moviePlayer play];
#else
    if (paused)
        [_player pause];
    else
        [_player play];
#endif
}

- (void)videoPlaybackFinished:(NSNotification *)__unused notification
{
    [self advanceToNext];
}

- (NSTimeInterval)currentVideoTime
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    if (_moviePlayer == nil)
        return _elapsed;
    return _moviePlayer.currentTime;
#else
    if (_player == nil)
        return _elapsed;
    CMTime time = _player.currentTime;
    if (!CMTIME_IS_VALID(time) || time.timescale == 0)
        return _elapsed;
    return CMTimeGetSeconds(time);
#endif
}

#pragma mark - Playback

- (bool)isPaused
{
    return _holdPaused || _actionPaused || _dismissing;
}

- (void)timerTick
{
    if (_story == nil || [self isPaused])
        return;
    if (!_mediaReady)
    {
        if (_hasPartialImage && CFAbsoluteTimeGetCurrent() - _partialImageTime > TGStoryPartialImageGrace)
        {
            _mediaReady = true;
            [_activityIndicator stopAnimating];
        }
        else
            return;
    }

    if (_story.video != nil)
    {
        _elapsed = [self currentVideoTime];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        if (_videoStream != nil && _player != nil)
        {
            if (_player.currentItem.playbackLikelyToKeepUp || [_videoStream isComplete])
                [_activityIndicator stopAnimating];
            else
                [_activityIndicator startAnimating];
        }
#endif
    }
    else
        _elapsed += TGStoryTimerInterval;

    [_progressView setCurrentIndex:_storyIndex progress:(CGFloat)(_duration > DBL_EPSILON ? _elapsed / _duration : 1.0)];
    if (_story.image != nil && _elapsed >= _duration)
        [self advanceToNext];
}

- (void)advanceToNext
{
    TGPeerStories *peerStories = [self currentPeerStories];
    if (_storyIndex + 1 < peerStories.stories.count)
    {
        _storyIndex++;
        [self displayCurrentStory];
        return;
    }
    if (_peerIndex + 1 < _peerStoriesList.count)
    {
        _peerIndex++;
        TGPeerStories *next = [self currentPeerStories];
        _storyIndex = _marksStoriesAsRead ? [next firstUnreadIndex] : 0;
        [self displayCurrentStory];
        return;
    }
    [self dismissViewer];
}

- (void)goToPrevious
{
    if (_storyIndex > 0)
    {
        _storyIndex--;
        [self displayCurrentStory];
        return;
    }
    if (_peerIndex > 0)
    {
        _peerIndex--;
        TGPeerStories *previous = [self currentPeerStories];
        _storyIndex = previous.stories.count == 0 ? 0 : previous.stories.count - 1;
        [self displayCurrentStory];
        return;
    }
    [self displayCurrentStory];
}

#pragma mark - Gestures

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateEnded || CFAbsoluteTimeGetCurrent() - _gestureEndTime < 0.35)
        return;
    CGPoint location = [recognizer locationInView:self.view];
    if (location.x < self.view.bounds.size.width * 0.3f)
        [self goToPrevious];
    else
        [self advanceToNext];
}

- (void)holdGesture:(UILongPressGestureRecognizer *)recognizer
{
    switch (recognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            _holdPaused = true;
            [self setVideoPaused:true];
            [self setInterfaceHidden:true];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _holdPaused = false;
            _gestureEndTime = CFAbsoluteTimeGetCurrent();
            if (![self isPaused])
                [self setVideoPaused:false];
            [self setInterfaceHidden:false];
            break;
        default:
            break;
    }
}

- (void)setInterfaceHidden:(bool)hidden
{
    [UIView animateWithDuration:0.2 animations:^
    {
        CGFloat alpha = hidden ? 0.0f : 1.0f;
        _progressView.alpha = alpha;
        _avatarView.alpha = alpha;
        _nameLabel.alpha = alpha;
        _timeLabel.alpha = alpha;
        _closeButton.alpha = alpha;
        _moreButton.alpha = alpha;
        _captionLabel.alpha = alpha;
        _viewsLabel.alpha = alpha;
        _topGradientView.alpha = alpha;
        _bottomGradientView.alpha = alpha;
    }];
}

- (void)panGesture:(UIPanGestureRecognizer *)recognizer
{
    CGPoint translation = [recognizer translationInView:self.view];
    switch (recognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            _holdPaused = true;
            [self setVideoPaused:true];
            break;
        case UIGestureRecognizerStateChanged:
            self.view.transform = CGAffineTransformMakeTranslation(0.0f, MAX(0.0f, translation.y));
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _gestureEndTime = CFAbsoluteTimeGetCurrent();
            CGPoint velocity = [recognizer velocityInView:self.view];
            if (translation.y > 120.0f || velocity.y > 900.0f)
            {
                [self dismissViewer];
                return;
            }
            if (fabs(translation.x) > 80.0f && fabs(translation.x) > fabs(translation.y))
            {
                _holdPaused = false;
                [UIView animateWithDuration:0.2 animations:^
                {
                    self.view.transform = CGAffineTransformIdentity;
                }];
                [self switchPeerForward:translation.x < 0.0f];
                return;
            }
            _holdPaused = false;
            if (![self isPaused])
                [self setVideoPaused:false];
            [UIView animateWithDuration:0.2 animations:^
            {
                self.view.transform = CGAffineTransformIdentity;
            }];
            break;
        }
        default:
            break;
    }
}

- (void)switchPeerForward:(bool)forward
{
    if (forward && _peerIndex + 1 < _peerStoriesList.count)
    {
        _peerIndex++;
        TGPeerStories *next = [self currentPeerStories];
        _storyIndex = _marksStoriesAsRead ? [next firstUnreadIndex] : 0;
        [self displayCurrentStory];
    }
    else if (!forward && _peerIndex > 0)
    {
        _peerIndex--;
        _storyIndex = 0;
        [self displayCurrentStory];
    }
    else if (!forward)
        [self displayCurrentStory];
    else
        [self dismissViewer];
}

#pragma mark - Actions

- (void)closePressed
{
    [self dismissViewer];
}

- (void)dismissViewer
{
    if (_dismissing)
        return;
    _dismissing = true;
    [_timer invalidate];
    _timer = nil;
    [self stopVideo];
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)morePressed
{
    if (![self isOwnPeer] || _story == nil)
        return;
    _actionPaused = true;
    [self setVideoPaused:true];
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:_story.pinned ? TGLocalized(@"OnegramStories.RemoveFromProfile") : TGLocalized(@"OnegramStories.AddToProfile") action:@"pin"]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramStories.Delete") action:@"delete" type:TGActionSheetActionTypeDestructive]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
    [[[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(TGStoryViewerController *controller, NSString *action)
    {
        if ([action isEqualToString:@"pin"])
            [controller togglePinnedCurrentStory];
        else if ([action isEqualToString:@"delete"])
            [controller deleteCurrentStory];
        else
            [controller resumeAfterAction];
    } target:self] showInView:self.view];
}

- (void)resumeAfterAction
{
    _actionPaused = false;
    if (![self isPaused])
        [self setVideoPaused:false];
}

- (void)togglePinnedCurrentStory
{
    TGStoryItem *story = _story;
    int64_t peerId = [self currentPeerStories].peerId;
    bool pinned = !story.pinned;
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    __weak TGStoryViewerController *weakSelf = self;
    [[[TGStoriesSignals setStories:peerId storyIds:@[@(story.storyId)] pinned:pinned] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        __strong TGStoryViewerController *strongSelf = weakSelf;
        [strongSelf resumeAfterAction];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (strongSelf.storyPinnedChanged != nil)
            strongSelf.storyPinnedChanged(peerId, story.storyId, pinned);
        [strongSelf refetchCurrentPeerStory:story.storyId];
        [strongSelf resumeAfterAction];
    }];
}

- (void)refetchCurrentPeerStory:(int32_t)storyId
{
    int64_t peerId = [self currentPeerStories].peerId;
    __weak TGStoryViewerController *weakSelf = self;
    [[[TGStoriesSignals storiesWithPeerId:peerId storyIds:@[@(storyId)]] deliverOn:[SQueue mainQueue]] startWithNext:^(TGStoriesPage *page)
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        for (NSUInteger i = 0; i < strongSelf->_peerStoriesList.count; i++)
        {
            TGPeerStories *peerStories = [strongSelf->_peerStoriesList objectAtIndex:i];
            if (peerStories.peerId == peerId)
            {
                [strongSelf->_peerStoriesList replaceObjectAtIndex:i withObject:[peerStories peerStoriesByMergingStories:page.stories]];
                if (i == strongSelf->_peerIndex)
                {
                    for (TGStoryItem *item in page.stories)
                    {
                        if (item.storyId == strongSelf->_story.storyId)
                            strongSelf->_story = item;
                    }
                }
            }
        }
    } error:nil completed:nil];
}

- (void)deleteCurrentStory
{
    __weak TGStoryViewerController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramStories.DeleteConfirm") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.Delete") destructive:true completionBlock:^(bool okButtonPressed)
    {
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (okButtonPressed)
            [strongSelf commitDeleteCurrentStory];
        else
            [strongSelf resumeAfterAction];
    } disableKeyboardWorkaround:false];
}

- (void)commitDeleteCurrentStory
{
    TGStoryItem *story = _story;
    int64_t peerId = [self currentPeerStories].peerId;
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    __weak TGStoryViewerController *weakSelf = self;
    [[[TGStoriesSignals deleteStories:peerId storyIds:@[@(story.storyId)]] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        __strong TGStoryViewerController *strongSelf = weakSelf;
        [strongSelf resumeAfterAction];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
        [[TGStoriesStore instance] removeStoryIds:@[@(story.storyId)] forPeerId:peerId];
        __strong TGStoryViewerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (strongSelf.storiesDeleted != nil)
            strongSelf.storiesDeleted(peerId, @[@(story.storyId)]);
        [strongSelf removeCurrentStoryFromList];
    }];
}

- (void)removeCurrentStoryFromList
{
    TGPeerStories *peerStories = [self currentPeerStories];
    NSMutableArray *stories = [[NSMutableArray alloc] initWithArray:peerStories.stories];
    if (_storyIndex < stories.count)
        [stories removeObjectAtIndex:_storyIndex];
    _actionPaused = false;
    if (stories.count == 0)
    {
        [_peerStoriesList removeObjectAtIndex:_peerIndex];
        if (_peerIndex >= _peerStoriesList.count)
        {
            [self dismissViewer];
            return;
        }
        _storyIndex = 0;
    }
    else
    {
        [_peerStoriesList replaceObjectAtIndex:_peerIndex withObject:[[TGPeerStories alloc] initWithPeerId:peerStories.peerId maxReadId:peerStories.maxReadId stories:stories]];
        if (_storyIndex >= stories.count)
            _storyIndex = stories.count - 1;
    }
    [self displayCurrentStory];
}

@end
