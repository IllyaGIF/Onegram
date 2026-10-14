#import "TGBrandedMusicPlayerController.h"

#import <QuartzCore/QuartzCore.h>

#import "TGMusicPlayerController.h"
#import "TGMusicPlayer.h"
#import "TGMusicPlayerPlaylist.h"
#import "TGTelegraph.h"

#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Player/OGMusicPlayerScreenView.h"

static NSString *TGBrandedMusicPlayerDurationText(int32_t seconds)
{
    seconds = MAX(0, seconds);
    return [[NSString alloc] initWithFormat:@"%d:%02d", seconds / 60, seconds % 60];
}

static NSString *TGBrandedMusicPlayerItemTitle(TGMusicPlayerItem *item)
{
    NSString *title = item.title.length != 0 ? item.title : @"Unknown Track";
    NSString *performer = item.performer.length != 0 ? item.performer : @"Unknown Artist";
    return [[NSString alloc] initWithFormat:@"%@ - %@", performer, title];
}

@interface TGBrandedMusicPlayerController ()
{
    OGMusicPlayerScreenView *_screenView;
    id<SDisposable> _statusDisposable;
    id<SDisposable> _playlistDisposable;
    SMetaDisposable *_actionsDisposable;
    TGMusicPlayerStatus *_status;
    TGMusicPlayerPlaylist *_playlist;
    NSArray *_orderedItems;
    bool _reversedOrder;
    STimer *_progressTimer;
    bool _scrolledToCurrentItem;
}
@end

@implementation TGBrandedMusicPlayerController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.navigationBarShouldBeHidden = true;
        _actionsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_statusDisposable dispose];
    [_playlistDisposable dispose];
    [_actionsDisposable dispose];
    [_progressTimer invalidate];
}

- (void)loadView
{
    [super loadView];

    _screenView = [[OGMusicPlayerScreenView alloc] initWithFrame:self.view.bounds theme:[OGTheme brandedTheme]];
    _screenView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _screenView.title = TGLocalized(@"MusicPlayer.WindowTitle");
    _screenView.backTitle = TGLocalized(@"Common.Back");
    [self.view addSubview:_screenView];

    __weak TGBrandedMusicPlayerController *weakSelf = self;
    _screenView.backPressed = ^
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf dismissWindow];
    };
    _screenView.playPausePressed = ^
    {
        [TGTelegraphInstance.musicPlayer controlPlayPause];
    };
    _screenView.previousPressed = ^
    {
        [TGTelegraphInstance.musicPlayer controlPrevious];
    };
    _screenView.nextPressed = ^
    {
        [TGTelegraphInstance.musicPlayer controlNext];
    };
    _screenView.orderPressed = ^
    {
        [TGTelegraphInstance.musicPlayer controlOrder];
    };
    _screenView.repeatPressed = ^
    {
        [TGTelegraphInstance.musicPlayer controlRepeat];
    };
    _screenView.rowSelected = ^(NSUInteger index)
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil && index < strongSelf->_orderedItems.count)
            [TGTelegraphInstance.musicPlayer playMediaFromItem:strongSelf->_orderedItems[index]];
    };
    _screenView.actionsRequested = ^
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        UIView *displayView = strongSelf->_screenView.displayView;
        __weak UIView *weakDisplayView = displayView;
        [TGMusicPlayerController presentActionsInController:strongSelf statusDisposable:strongSelf->_actionsDisposable sourceView:strongSelf->_screenView sourceRect:^CGRect
        {
            __strong TGBrandedMusicPlayerController *innerSelf = weakSelf;
            __strong UIView *strongDisplayView = weakDisplayView;
            if (innerSelf == nil || strongDisplayView == nil)
                return CGRectZero;
            return [strongDisplayView convertRect:strongDisplayView.bounds toView:innerSelf->_screenView];
        } dismiss:nil];
    };
    _screenView.scrubbingBegan = ^
    {
        [TGTelegraphInstance.musicPlayer controlPause];
    };
    _screenView.scrubbingFinished = ^(CGFloat progress)
    {
        [TGTelegraphInstance.musicPlayer controlSeekToPosition:progress];
        [TGTelegraphInstance.musicPlayer controlPlay];
    };
    _screenView.scrubbingCancelled = ^
    {
        [TGTelegraphInstance.musicPlayer controlPlay];
    };

    _statusDisposable = [[TGTelegraphInstance.musicPlayer playingStatus] startWithNext:^(TGMusicPlayerStatus *status)
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf setStatus:status];
    }];
    _playlistDisposable = [[TGTelegraphInstance.musicPlayer playlist] startWithNext:^(TGMusicPlayerPlaylist *playlist)
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf setPlaylist:playlist];
    }];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateProgressTimer];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [_progressTimer invalidate];
    _progressTimer = nil;
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    _screenView.contentInsets = UIEdgeInsetsMake(self.controllerInset.top, 0.0f, self.controllerSafeAreaInset.bottom, 0.0f);
}

- (void)dismissWindow
{
    UINavigationController *navigationController = self.navigationController;
    if (navigationController == nil)
        return;
    if (navigationController.topViewController == self)
    {
        [navigationController popViewControllerAnimated:true];
        return;
    }
    NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:navigationController.viewControllers];
    [viewControllers removeObject:self];
    [navigationController setViewControllers:viewControllers animated:false];
}

- (void)setPlaylist:(TGMusicPlayerPlaylist *)playlist
{
    if (playlist.voice)
    {
        [self dismissWindow];
        return;
    }

    _playlist = playlist;
    [self updateRows];
}

- (void)setStatus:(TGMusicPlayerStatus *)status
{
    TGMusicPlayerStatus *previousStatus = _status;
    _status = status;

    if (status.item == nil)
    {
        if (previousStatus.item != nil)
            [self dismissWindow];
        return;
    }

    if (![status.item.key isEqual:previousStatus.item.key])
        _screenView.trackTitle = TGBrandedMusicPlayerItemTitle(status.item);

    _screenView.paused = status.paused;
    _screenView.controlsEnabled = status.downloadedStatus.downloaded;

    switch (status.orderType)
    {
        case TGMusicPlayerOrderTypeNewestFirst:
            _screenView.order = OGMusicPlayerScreenOrderNormal;
            break;
        case TGMusicPlayerOrderTypeOldestFirst:
            _screenView.order = OGMusicPlayerScreenOrderReversed;
            break;
        case TGMusicPlayerOrderTypeShuffle:
            _screenView.order = OGMusicPlayerScreenOrderShuffled;
            break;
    }

    switch (status.repeatType)
    {
        case TGMusicPlayerRepeatTypeNone:
            _screenView.repeat = OGMusicPlayerScreenRepeatNone;
            break;
        case TGMusicPlayerRepeatTypeAll:
            _screenView.repeat = OGMusicPlayerScreenRepeatAll;
            break;
        case TGMusicPlayerRepeatTypeOne:
            _screenView.repeat = OGMusicPlayerScreenRepeatOne;
            break;
    }

    if ((status.orderType == TGMusicPlayerOrderTypeNewestFirst) != _reversedOrder)
        [self updateRows];

    [self updateProgress];
    [self updateProgressTimer];
    [self scrollToCurrentItemIfNeeded];
}

- (void)updateRows
{
    _reversedOrder = _status.orderType == TGMusicPlayerOrderTypeNewestFirst;
    NSArray *items = _playlist.items;
    _orderedItems = _reversedOrder ? [[items reverseObjectEnumerator] allObjects] : items;

    NSMutableArray *rows = [[NSMutableArray alloc] initWithCapacity:_orderedItems.count];
    for (TGMusicPlayerItem *item in _orderedItems)
    {
        OGMusicPlayerScreenRow *row = [[OGMusicPlayerScreenRow alloc] init];
        row.title = TGBrandedMusicPlayerItemTitle(item);
        row.durationText = TGBrandedMusicPlayerDurationText(item.duration);
        [rows addObject:row];
    }
    _screenView.rows = rows;
    [self scrollToCurrentItemIfNeeded];
}

- (void)scrollToCurrentItemIfNeeded
{
    if (_scrolledToCurrentItem || _status.item == nil || _orderedItems.count == 0)
        return;

    NSUInteger index = 0;
    for (TGMusicPlayerItem *item in _orderedItems)
    {
        if ([item.key isEqual:_status.item.key])
        {
            _scrolledToCurrentItem = true;
            [_screenView scrollToRowAtIndex:index animated:false];
            return;
        }
        index++;
    }
}

- (void)updateProgress
{
    TGMusicPlayerStatus *status = _status;
    if (status == nil || _screenView.scrubbing)
        return;

    CGFloat offset = status.offset;
    if (!status.paused && status.duration > FLT_EPSILON)
        offset = MIN(1.0f, status.offset + (CGFloat)((CACurrentMediaTime() - status.timestamp) / status.duration));

    bool downloaded = status.downloadedStatus.downloaded;
    [_screenView setProgress:downloaded ? offset : status.downloadedStatus.progress knobVisible:downloaded];
    _screenView.trackSubtitle = [[NSString alloc] initWithFormat:TGLocalized(@"MusicPlayer.ElapsedTime"), TGBrandedMusicPlayerDurationText((int32_t)(offset * status.duration))];
}

- (void)updateProgressTimer
{
    bool running = _status != nil && (!_status.paused || _status.downloadedStatus.downloading) && self.isViewLoaded && self.view.window != nil;
    if (!running)
    {
        [_progressTimer invalidate];
        _progressTimer = nil;
        return;
    }
    if (_progressTimer != nil)
        return;

    __weak TGBrandedMusicPlayerController *weakSelf = self;
    _progressTimer = [[STimer alloc] initWithTimeout:0.25 repeat:true completion:^
    {
        __strong TGBrandedMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updateProgress];
    } queue:[SQueue mainQueue]];
    [_progressTimer start];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (!TGIsPad())
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (BOOL)shouldAutorotate
{
    if (!TGIsPad())
        return false;
    return [super shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (!TGIsPad())
        return UIInterfaceOrientationMaskPortrait;
    return [super supportedInterfaceOrientations];
}

@end
