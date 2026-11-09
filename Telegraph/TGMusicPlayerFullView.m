#import "TGMusicPlayerFullView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGMusicPlayerModeButton.h"
#import "TGMusicPlayerScrubbingArea.h"
#import "TGMusicPlaylistCell.h"
#import "TGScrollIndicatorView.h"

#import "TGMusicPlayerItemSignals.h"
#import "TGMusicPlayer.h"
#import "OGMediaBitrateIndicatorView.h"
#import "TGTelegraph.h"
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>

#import "TGPresentation.h"
#import "../OnegramRuntime/OGPluginAvailability.h"
#if OG_PLUGINS_AVAILABLE
#import "../OnegramPlugins/OGPluginUI.h"
#endif

UIColor *TGPlayerPluginColor(id value)
{
    if (![value isKindOfClass:[NSString class]] || [value length] != 7 || ![value hasPrefix:@"#"])
        return nil;
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[value substringFromIndex:1]];
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd)
        return nil;
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0f green:((rgb >> 8) & 255) / 255.0f blue:(rgb & 255) / 255.0f alpha:1];
}

NSArray *TGPlayerPluginArtworkColors(UIImage *image)
{
    if (image.CGImage == NULL)
        return nil;
    unsigned char pixels[16 * 16 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 16, 16, 8, 16 * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (context == NULL)
        return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, 16, 16), image.CGImage);
    CGContextRelease(context);
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    for (int part = 0; part < 2; part++)
    {
        NSUInteger totals[3] = {0, 0, 0};
        NSUInteger count = 0;
        for (int y = part * 8; y < part * 8 + 8; y++)
            for (int x = 0; x < 16; x++)
            {
                unsigned char *pixel = pixels + (y * 16 + x) * 4;
                if (pixel[3] < 32)
                    continue;
                for (int channel = 0; channel < 3; channel++)
                    totals[channel] += pixel[channel];
                count++;
            }
        if (count == 0)
            return nil;
        CGFloat red = MIN(0.65f, (CGFloat)totals[0] / (255.0f * count) * 0.7f);
        CGFloat green = MIN(0.65f, (CGFloat)totals[1] / (255.0f * count) * 0.7f);
        CGFloat blue = MIN(0.65f, (CGFloat)totals[2] / (255.0f * count) * 0.7f);
        [colors addObject:[UIColor colorWithRed:red green:green blue:blue alpha:1]];
    }
    return colors;
}

NSCache *TGPlayerPluginPaletteCache(void)
{
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    return cache;
}

@interface TGMusicPlayerCollectionView : PSUICollectionView

@end

@interface TGMusicPlayerFullView () <PSUICollectionViewDelegate, PSUICollectionViewDataSource, UIScrollViewDelegate, UIGestureRecognizerDelegate>
{
    TGPresentation *_presentation;
    
    UIView *_dimView;
    
    UIView *_containerView;

    TGModernButton *_arrowView;
    UIView *_panelView;
    UIView *_controlsView;
    TGMusicPlayerScrubbingArea *_scrubbingArea;
    UIImageView *_scrubbingBackground;
    UIImageView *_playbackScrubbingForeground;
    UIImageView *_downloadingScrubbingForeground;
    UIImageView *_scrubbingHandle;
    
    UILabel *_titleLabel;
    UILabel *_performerLabel;
    TGModernButton *_controlBackButton;
    TGModernButton *_controlForwardButton;
    TGModernButton *_controlPlayButton;
    TGModernButton *_controlPauseButton;
    TGMusicPlayerModeButton *_controlShuffleButton;
    TGMusicPlayerModeButton *_controlRepeatButton;
    TGModernButton *_actionsButton;
    
    UILabel *_positionLabel;
    int _positionLabelValue;
    UILabel *_durationLabel;
    int _durationLabelValue;
    OGMediaBitrateIndicatorView *_bitrateView;
    
    bool _shouldBeginScrubbing;
    bool _scrubbing;
    CGPoint _scrubbingReferencePoint;
    CGFloat _scrubbingReferenceOffset;
    CGFloat _scrubbingOffset;
    
    CGFloat _playbackOffset;
    CGFloat _downloadProgress;
    
    id<SDisposable> _playerStatusDisposable;
    id<SDisposable> _playlistDisposable;
    
    TGMusicPlayerStatus *_currentStatus;
    TGMusicPlayerPlaylist *_currentPlaylist;
    NSString *_title;
    NSString *_performer;
    TGMusicPlayerItemPosition _currentItemPosition;
    
    TGImageView *_coverView;
    
    CGFloat _coverExpandProgress;
    
    TGMusicPlayerCollectionView *_collectionView;
    UIView *_separator;
    TGScrollIndicatorView *_scrollIndicator;
    
    bool _updateLabelsLayout;
    
    bool _presented;
    
    CGFloat _panelScrollingReferencePoint;
    NSNumber *_previousContentOffset;
    
    id<LegacyComponentsContext> _context;
    CAGradientLayer *_pluginBackgroundLayer;
    UIView *_pluginLyricsContainer;
    UILabel *_pluginLyricsLabel;
    UIView *_pluginLyricsScene;
    NSArray *_pluginLyricsLines;
    id<SDisposable> _pluginArtworkDisposable;
    NSString *_pluginTrackKey;
    NSUInteger _pluginThemeGeneration;
}
@end

@implementation TGMusicPlayerFullView

- (instancetype)initWithFrame:(CGRect)frame context:(id<LegacyComponentsContext>)context presentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _context = context;
        _presentation = presentation;
        
        _dimView = [[UIView alloc] init];
        _dimView.alpha = 0.0f;
        _dimView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
        [self addSubview:_dimView];
        
        _containerView = [[UIView alloc] init];
        _containerView.backgroundColor = presentation.pallete.menuBackgroundColor;
        _containerView.hidden = true;
        [self addSubview:_containerView];
        
        PSUICollectionViewFlowLayout *collectionLayout = [[PSUICollectionViewFlowLayout alloc] init];
        collectionLayout.minimumLineSpacing = 0.0f;
        collectionLayout.minimumInteritemSpacing = 0.0f;

        _collectionView = [[TGMusicPlayerCollectionView alloc] initWithFrame:self.bounds collectionViewLayout:collectionLayout];
        if (iosMajorVersion() >= 11)
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _collectionView.backgroundColor = presentation.pallete.menuBackgroundColor;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.scrollsToTop = false;
        _collectionView.showsVerticalScrollIndicator = false;
        _collectionView.delaysContentTouches = false;
        _collectionView.canCancelContentTouches = true;
        [_collectionView registerClass:[TGMusicPlaylistCell class] forCellWithReuseIdentifier:TGMusicPlaylistCellKind];
        [_containerView addSubview:_collectionView];
        
        _panelView = [[UIView alloc] init];
        _panelView.backgroundColor = presentation.pallete.menuBackgroundColor;
        [_containerView addSubview:_panelView];
        
        _separator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, TGScreenPixel)];
        _separator.alpha = 0.0f;
        _separator.backgroundColor = presentation.pallete.separatorColor;
        [_panelView addSubview:_separator];
        
        _controlsView = [[UIView alloc] init];
        _controlsView.backgroundColor = presentation.pallete.menuBackgroundColor;
        [_panelView addSubview:_controlsView];
        
        _arrowView = [[TGModernButton alloc] init];
        _arrowView.adjustsImageWhenHighlighted = false;
        [_arrowView setImage:TGTintedImage(TGImageNamed(@"MusicPlayerArrow"), presentation.pallete.collectionMenuAccessoryColor) forState:UIControlStateNormal];
        [_arrowView addTarget:self action:@selector(arrowPressed) forControlEvents:UIControlEventTouchUpInside];
        [_arrowView sizeToFit];
        [_panelView addSubview:_arrowView];
        
        UIImage *moreImage;
        UIImage *trackImage;
        UIImage *handleImage;

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(19.0f, 5.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, presentation.pallete.menuAccentColor.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 5.0f, 5.0f));
        CGContextFillEllipseInRect(context, CGRectMake(7.0f, 0.0f, 5.0f, 5.0f));
        CGContextFillEllipseInRect(context, CGRectMake(14.0f, 0.0f, 5.0f, 5.0f));
        
        moreImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(3.0f, 3.0f), false, 0.0f);
        context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, presentation.pallete.menuAccentColor.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 3.0f, 3.0f));
        trackImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(6.0f, 6.0f), false, 0.0f);
        context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, presentation.pallete.menuAccentColor.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 6.0f, 6.0f));
        handleImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        _scrubbingBackground = [[UIImageView alloc] initWithImage:[TGTintedImage(trackImage, presentation.pallete.collectionMenuAccessoryColor) resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 1.5f, 0.0f, 1.5f)]];
        [_controlsView addSubview:_scrubbingBackground];
        
        _playbackScrubbingForeground = [[UIImageView alloc] initWithImage:[trackImage resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 1.5f, 0.0f, 1.5f)]];
        [_controlsView addSubview:_playbackScrubbingForeground];
        
        _downloadingScrubbingForeground = [[UIImageView alloc] initWithImage:_playbackScrubbingForeground.image];
        [_controlsView addSubview:_downloadingScrubbingForeground];
        
        _scrubbingHandle = [[UIImageView alloc] initWithImage:handleImage];
        [_controlsView addSubview:_scrubbingHandle];
        
        _scrubbingArea = [[TGMusicPlayerScrubbingArea alloc] init];
        __weak TGMusicPlayerFullView *weakSelf = self;
        _scrubbingArea.didBeginDragging = ^(UITouch *touch)
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf beginScrubbingAtPoint:[strongSelf scrubbingLocationForTouch:touch]];
        };
        _scrubbingArea.willMove = ^(UITouch *touch)
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf continueScrubbingAtPoint:[strongSelf scrubbingLocationForTouch:touch]];
        };
        _scrubbingArea.didFinishDragging = ^
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf finishScrubbing];
        };
        _scrubbingArea.didCancelDragging = ^
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf cancelScrubbing];
        };
        [_controlsView addSubview:_scrubbingArea];
        
        _positionLabel = [[UILabel alloc] init];
        _positionLabel.backgroundColor = [UIColor clearColor];
        _positionLabel.textColor = presentation.pallete.menuSecondaryTextColor;
        _positionLabel.font = TGSystemFontOfSize(13.0f);
        [_controlsView addSubview:_positionLabel];
        _positionLabelValue = INT_MIN;
        
        _durationLabel = [[UILabel alloc] init];
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.textColor = presentation.pallete.menuSecondaryTextColor;
        _durationLabel.font = TGSystemFontOfSize(13.0f);
        [_controlsView addSubview:_durationLabel];
        
        _bitrateView = [[OGMediaBitrateIndicatorView alloc] init];
        _bitrateView.font = TGSystemFontOfSize(13.0f);
        _bitrateView.rateProvider = ^double
        {
            return [TGTelegraphInstance.musicPlayer currentStreamDownloadRate];
        };
        [_controlsView addSubview:_bitrateView];
        _durationLabelValue = INT_MIN;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = presentation.pallete.menuTextColor;
        _titleLabel.font = TGMediumSystemFontOfSize(16.0f);
        [_controlsView addSubview:_titleLabel];
        
        _performerLabel = [[UILabel alloc] init];
        _performerLabel.backgroundColor = [UIColor clearColor];
        _performerLabel.textColor = presentation.pallete.menuSecondaryTextColor;
        _performerLabel.font = TGSystemFontOfSize(12.0f);
        [_controlsView addSubview:_performerLabel];
        
        _coverView = [[TGImageView alloc] init];
        _coverView.backgroundColor = UIColorRGB(0xeeeeee);
        _coverView.clipsToBounds = true;
        _coverView.layer.cornerRadius = 7.0f;
        _coverView.userInteractionEnabled = true;
        [_controlsView addSubview:_coverView];
        
        if (iosMajorVersion() >= 11)
            _coverView.accessibilityIgnoresInvertColors = true;
        
        [_coverView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(coverTapped)]];
        
        [_dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimTapped:)]];
        
        UIPanGestureRecognizer *swipeGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        swipeGestureRecognizer.delegate = self;
        [_panelView addGestureRecognizer:swipeGestureRecognizer];
        
        _controlPlayButton = [[TGModernButton alloc] init];
        _controlPlayButton.adjustsImageWhenHighlighted = false;
        [_controlPlayButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlPlay.png"), presentation.pallete.musicControlsColor) forState:UIControlStateNormal];
        [_controlPlayButton setContentEdgeInsets:UIEdgeInsetsMake(0.0f, 5.0f, 0.0f, 0.0f)];
        [_controlPlayButton addTarget:self action:@selector(controlPlay) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlPlayButton];
        
        _controlPauseButton = [[TGModernButton alloc] init];
        _controlPauseButton.adjustsImageWhenHighlighted = false;
        [_controlPauseButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlPause.png"), presentation.pallete.musicControlsColor) forState:UIControlStateNormal];
        [_controlPauseButton addTarget:self action:@selector(controlPause) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlPauseButton];
        
        _controlBackButton = [[TGModernButton alloc] init];
        _controlBackButton.adjustsImageWhenHighlighted = false;
        [_controlBackButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlBack.png"), presentation.pallete.musicControlsColor) forState:UIControlStateNormal];
        [_controlBackButton addTarget:self action:@selector(controlBack) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlBackButton];
        
        _controlForwardButton = [[TGModernButton alloc] init];
        _controlForwardButton.adjustsImageWhenHighlighted = false;
        [_controlForwardButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlForward.png"), presentation.pallete.musicControlsColor) forState:UIControlStateNormal];
        [_controlForwardButton addTarget:self action:@selector(controlForward) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlForwardButton];
        
        _controlShuffleButton = [[TGMusicPlayerModeButton alloc] init];
        _controlShuffleButton.accentColor = presentation.pallete.accentColor;
        _controlShuffleButton.adjustsImageWhenHighlighted = false;
        [_controlShuffleButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlReverse.png"), presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
        [_controlShuffleButton addTarget:self action:@selector(controlOrder) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlShuffleButton];
        
        _controlRepeatButton = [[TGMusicPlayerModeButton alloc] init];
        _controlRepeatButton.accentColor = presentation.pallete.accentColor;
        _controlRepeatButton.adjustsImageWhenHighlighted = false;
        [_controlRepeatButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlRepeat.png"), presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
        [_controlRepeatButton addTarget:self action:@selector(controlRepeat) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_controlRepeatButton];
        
        _actionsButton = [[TGModernButton alloc] init];
        _actionsButton.adjustsImageWhenHighlighted = false;
        [_actionsButton setImage:moreImage forState:UIControlStateNormal];
        [_actionsButton addTarget:self action:@selector(actionsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_controlsView addSubview:_actionsButton];
        
        _currentItemPosition = (TGMusicPlayerItemPosition){.index = 0, .count = -1};
        
        _playerStatusDisposable = [[TGTelegraphInstance.musicPlayer playingStatus] startWithNext:^(TGMusicPlayerStatus *status)
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setStatus:status];
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pluginThemeDidChange:) name:@"OGSDKPlayerThemeChanged" object:nil];
        
        _playlistDisposable = [[TGTelegraphInstance.musicPlayer playlist] startWithNext:^(TGMusicPlayerPlaylist *playlist)
        {
            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setPlaylist:playlist];
        }];
        
        _updateLabelsLayout = true;
        
        _scrollIndicator = [[TGScrollIndicatorView alloc] init];
        [_scrollIndicator setHidden:true animated:false];
        [_collectionView addSubview:_scrollIndicator];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_pluginArtworkDisposable dispose];
    [_playerStatusDisposable dispose];
}

- (void)setFrame:(CGRect)frame
{
    _updateLabelsLayout = ABS(self.frame.size.width - frame.size.width) > FLT_EPSILON;
    [super setFrame:frame];
    
    if (_updateLabelsLayout)
    {
        [self setNeedsLayout];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self scrollViewDidScroll:_collectionView];
        });
    }
}

- (void)applyPluginPalette:(NSArray *)colors
{
    if (colors.count == 0)
        return;
    if (_pluginBackgroundLayer == nil)
    {
        _pluginBackgroundLayer = [CAGradientLayer layer];
        [_containerView.layer insertSublayer:_pluginBackgroundLayer atIndex:0];
    }
    NSMutableArray *layers = [[NSMutableArray alloc] init];
    for (UIColor *color in colors)
        if ([color isKindOfClass:[UIColor class]])
            [layers addObject:(id)color.CGColor];
    _pluginBackgroundLayer.colors = layers;
    _pluginBackgroundLayer.frame = _containerView.bounds;
    _containerView.backgroundColor = [UIColor clearColor];
    _panelView.backgroundColor = [UIColor clearColor];
    _controlsView.backgroundColor = [UIColor clearColor];
    _collectionView.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = [UIColor whiteColor];
    _performerLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
}

- (void)pluginThemeDidChange:(NSNotification *)__unused notification
{
    [self refreshPluginTheme];
}

- (void)pluginLyricsTapped:(UITapGestureRecognizer *)__unused gesture
{
#if OG_PLUGINS_AVAILABLE
    if (_currentStatus != nil && !_currentStatus.item.isVoice)
        OGPluginUIPlayerLyricsRequested([_currentStatus.item.key description], _currentStatus.item.title, _currentStatus.item.performer, _currentStatus.item.duration);
#endif
}

- (void)updatePluginLyrics
{
    if (_pluginLyricsLabel == nil || _currentStatus == nil)
        return;
    double elapsed = _currentStatus.paused ? 0 : MAX(0, CACurrentMediaTime() - _currentStatus.timestamp) * MAX(0.1f, _currentStatus.rate);
    double seconds = MIN(_currentStatus.duration, _currentStatus.offset * _currentStatus.duration + elapsed);
    NSInteger low = 0;
    NSInteger high = (NSInteger)_pluginLyricsLines.count;
    while (low < high)
    {
        NSInteger middle = low + (high - low) / 2;
        if ([_pluginLyricsLines[middle][@"at"] doubleValue] <= seconds)
            low = middle + 1;
        else
            high = middle;
    }
    NSString *line = low > 0 ? _pluginLyricsLines[(NSUInteger)low - 1][@"text"] : @"";
    if (![_pluginLyricsLabel.text isEqualToString:line])
        _pluginLyricsLabel.text = line;
}

- (void)schedulePluginLyricsTick:(NSUInteger)generation
{
    __weak TGMusicPlayerFullView *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        TGMusicPlayerFullView *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_pluginThemeGeneration != generation || strongSelf->_pluginLyricsLines.count == 0)
            return;
        [strongSelf updatePluginLyrics];
        [strongSelf schedulePluginLyricsTick:generation];
    });
}

- (void)refreshPluginTheme
{
    _pluginThemeGeneration++;
    [_pluginArtworkDisposable dispose];
    _pluginArtworkDisposable = nil;
    if ([_pluginLyricsScene respondsToSelector:@selector(stop)])
        ((void (*)(id, SEL))objc_msgSend)(_pluginLyricsScene, @selector(stop));
    [_pluginLyricsScene removeFromSuperview];
    _pluginLyricsScene = nil;
    [_pluginLyricsContainer removeFromSuperview];
    _pluginLyricsContainer = nil;
    _pluginLyricsLabel = nil;
    _pluginLyricsLines = nil;
    [_pluginBackgroundLayer removeFromSuperlayer];
    _pluginBackgroundLayer = nil;
    _containerView.backgroundColor = _presentation.pallete.menuBackgroundColor;
    _panelView.backgroundColor = _presentation.pallete.menuBackgroundColor;
    _controlsView.backgroundColor = _presentation.pallete.menuBackgroundColor;
    _collectionView.backgroundColor = _presentation.pallete.menuBackgroundColor;
    _titleLabel.textColor = _presentation.pallete.menuTextColor;
    _performerLabel.textColor = _presentation.pallete.menuSecondaryTextColor;
    Class cls = NSClassFromString(@"OGPluginSDKDecoration");
    SEL selector = NSSelectorFromString(@"playerThemeForTrack:");
    NSString *track = [_currentStatus.item.key description] ?: @"";
    NSDictionary *theme = [cls respondsToSelector:selector] ? ((id (*)(id, SEL, id))objc_msgSend)(cls, selector, track) : nil;
    if (![theme isKindOfClass:[NSDictionary class]] || theme.count == 0 || _currentStatus.item.isVoice)
    {
        _pluginTrackKey = nil;
        return;
    }
    _pluginTrackKey = [NSString stringWithFormat:@"%lld:%lld:%@", (long long)TGTelegraphInstance.clientUserId, (long long)_currentStatus.item.peerId, track];
    NSMutableArray *palette = [[NSMutableArray alloc] init];
    for (NSString *value in theme[@"palette"])
    {
        UIColor *color = TGPlayerPluginColor(value);
        if (color != nil)
            [palette addObject:color];
    }
    if (palette.count != 0)
        [self applyPluginPalette:palette];
    else
    {
        NSArray *cached = [TGPlayerPluginPaletteCache() objectForKey:_pluginTrackKey];
        if (cached != nil)
            [self applyPluginPalette:cached];
        else
        {
            NSUInteger generation = _pluginThemeGeneration;
            NSString *cacheKey = _pluginTrackKey;
            __weak TGMusicPlayerFullView *weakSelf = self;
            SSignal *artwork = _currentStatus.albumArt ?: [TGMusicPlayerItemSignals albumArtForItem:_currentStatus.item thumbnail:true];
            _pluginArtworkDisposable = [[artwork deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
            {
                if (![image isKindOfClass:[UIImage class]])
                    return;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
                {
                    NSArray *colors = TGPlayerPluginArtworkColors(image);
                    if (colors != nil)
                        [TGPlayerPluginPaletteCache() setObject:colors forKey:cacheKey];
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        TGMusicPlayerFullView *strongSelf = weakSelf;
                        if (strongSelf != nil && generation == strongSelf->_pluginThemeGeneration && colors != nil)
                            [strongSelf applyPluginPalette:colors];
                    });
                });
            }];
        }
    }
    NSDictionary *scene = [theme[@"scene"] isKindOfClass:[NSDictionary class]] ? theme[@"scene"] : nil;
    NSArray *lines = [theme[@"lines"] isKindOfClass:[NSArray class]] ? theme[@"lines"] : nil;
    if (scene != nil || lines.count != 0)
    {
        _pluginLyricsContainer = [[UIView alloc] init];
        _pluginLyricsContainer.userInteractionEnabled = true;
        [_pluginLyricsContainer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pluginLyricsTapped:)]];
        _pluginLyricsContainer.clipsToBounds = true;
        _pluginLyricsContainer.layer.cornerRadius = 8.0f;
        _pluginLyricsContainer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.42f];
        [_controlsView addSubview:_pluginLyricsContainer];
        if (scene != nil)
        {
            Class sceneClass = NSClassFromString(@"OGPluginSceneView");
            SEL sceneSelector = NSSelectorFromString(@"viewWithDescription:");
            if ([sceneClass respondsToSelector:sceneSelector])
            {
                _pluginLyricsScene = ((id (*)(id, SEL, id))objc_msgSend)(sceneClass, sceneSelector, scene);
                _pluginLyricsScene.userInteractionEnabled = false;
                _pluginLyricsScene.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [_pluginLyricsContainer addSubview:_pluginLyricsScene];
            }
        }
        if (lines.count != 0)
        {
            _pluginLyricsLines = lines;
            _pluginLyricsLabel = [[UILabel alloc] init];
            _pluginLyricsLabel.font = [UIFont boldSystemFontOfSize:13.0f];
            _pluginLyricsLabel.textColor = [UIColor whiteColor];
            _pluginLyricsLabel.textAlignment = NSTextAlignmentCenter;
            _pluginLyricsLabel.numberOfLines = 2;
            _pluginLyricsLabel.backgroundColor = [UIColor clearColor];
            _pluginLyricsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_pluginLyricsContainer addSubview:_pluginLyricsLabel];
            [self updatePluginLyrics];
            [self schedulePluginLyricsTick:_pluginThemeGeneration];
        }
        [self setNeedsLayout];
    }
}

- (void)setStatus:(TGMusicPlayerStatus *)status
{
    TGMusicPlayerStatus *previousStatus = _currentStatus;
    _currentStatus = status;
    
    if (_currentItemPosition.index != status.position.index || _currentItemPosition.count != status.position.count)
    {
        _currentItemPosition = status.position;
        [self updateCells];
    }
    
    if (previousStatus.paused != status.paused)
        [self updateCells];
    
    bool itemChanged = !TGObjectCompare(status.item.key, previousStatus.item.key);
    if (itemChanged)
    {
#if OG_PLUGINS_AVAILABLE
        OGPluginUIPlayerTrackChangedWithAudio([status.item.key description], status.item.title, status.item.performer, status.item.duration, status.item.isVoice, TGMusicPlayerCurrentLocalAudioPath(status));
#endif
        [self refreshPluginTheme];
    }
    bool itemDownloaded = !itemChanged && status.downloadedStatus.downloaded && !previousStatus.downloadedStatus.downloaded;
    if (itemDownloaded)
    {
#if OG_PLUGINS_AVAILABLE
        OGPluginUIPlayerTrackChangedWithAudio([status.item.key description], status.item.title, status.item.performer, status.item.duration, status.item.isVoice, TGMusicPlayerCurrentLocalAudioPath(status));
#endif
    }
    if (itemChanged)
    {
        _bitrateView.mediaBitrate = [TGMusicPlayer mediaBitrateForItem:status.item];
        NSString *title = status.item.title;
        NSString *performer = status.item.performer;
        
        if (title.length == 0)
            title = @"Unknown Track";
        
        if (performer.length == 0)
            performer = @"Unknown Artist";
        
        if (status != nil)
        {
            if (!TGStringCompare(_title, title) || !TGStringCompare(_performer, performer))
            {
                _title = title;
                _performer = performer;
                
                _updateLabelsLayout = true;
                
                _titleLabel.text = title;
                _performerLabel.text = performer;
                
                [self setNeedsLayout];
            }
        }
    }
    
    if (itemChanged || itemDownloaded)
    {
        [_coverView setSignal:[[TGMusicPlayerItemSignals albumArtForItem:status.item thumbnail:false] catch:^(__unused id error)
        {
            CGSize size = CGSizeMake(390.0f, 390.0f);
            UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [UIColorRGB(0xeeeeee) setFill];
            CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
            
            UIImage *icon = TGImageNamed(@"MusicPlayerAlbumArtPlaceholder");
            [icon drawAtPoint:CGPointMake((size.width - icon.size.width) / 2.0f - 10.0f, (size.height - icon.size.height) / 2.0f)];
            
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            return [SSignal single:image];
        }]];
    }
    
    if (itemDownloaded)
    {
        for (TGMusicPlaylistCell *cell in _collectionView.visibleCells)
        {
            if ([cell.item.key isEqual:status.item.key])
                [cell setItem:cell.item];
        }
    }
    
    _controlPlayButton.hidden = !status.paused;
    _controlPauseButton.hidden = status.paused;
    
    if ([self reversePlaylistForOrderType:status.orderType] != [self reversePlaylistForOrderType:previousStatus.orderType])
        [_collectionView reloadData];
    
    if (previousStatus == nil || status.orderType != previousStatus.orderType)
    {
        switch (status.orderType)
        {
            case TGMusicPlayerOrderTypeOldestFirst:
                [_controlShuffleButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlReverse.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlShuffleButton.selected = false;
                break;
                
            case TGMusicPlayerOrderTypeNewestFirst:
                [_controlShuffleButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlReverse.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlShuffleButton.selected = true;
                break;
                
            case TGMusicPlayerOrderTypeShuffle:
                [_controlShuffleButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlShuffle.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlShuffleButton.selected = true;
                break;
        }
    }
    if (status.repeatType != previousStatus.repeatType)
    {
        switch (status.repeatType)
        {
            case TGMusicPlayerRepeatTypeNone:
                [_controlRepeatButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlRepeat.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlRepeatButton.selected = false;
                break;
                
            case TGMusicPlayerRepeatTypeAll:
                [_controlRepeatButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlRepeat.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlRepeatButton.selected = true;
                break;
                
            case TGMusicPlayerRepeatTypeOne:
                [_controlRepeatButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerControlRepeatOne.png"), _presentation.pallete.secondaryTextColor) forState:UIControlStateNormal];
                _controlRepeatButton.selected = true;
                break;
        }
    }
    
    CGFloat disabledAlpha = 0.6f;
    
    _scrubbingHandle.hidden = !status.downloadedStatus.playable;
    
    bool buttonsEnabled = status.downloadedStatus.playable;
    if (buttonsEnabled != _controlPlayButton.enabled)
    {
        _controlPlayButton.enabled = buttonsEnabled;
        _controlPauseButton.enabled = buttonsEnabled;
        _controlPlayButton.alpha = buttonsEnabled ? 1.0f : disabledAlpha;
        _controlPauseButton.alpha = buttonsEnabled ? 1.0f : disabledAlpha;
        _scrubbingArea.enabled = buttonsEnabled;
    }
    
    static POPAnimatableProperty *playbackOffsetProperty = nil;
    static POPAnimatableProperty *downloadProgressProperty = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        playbackOffsetProperty = [POPAnimatableProperty propertyWithName:@"playbackOffset" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(TGMusicPlayerFullView *strongSelf, CGFloat *values)
            {
                values[0] = strongSelf->_playbackOffset;
            };
            
            prop.writeBlock = ^(TGMusicPlayerFullView *strongSelf, CGFloat const *values)
            {
                strongSelf->_playbackOffset = values[0];
                if (!strongSelf->_scrubbing)
                    [strongSelf layoutScrubbingIndicator];
            };
        }];
        
        downloadProgressProperty = [POPAnimatableProperty propertyWithName:@"downloadProgress" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(TGMusicPlayerFullView *strongSelf, CGFloat *values)
            {
                values[0] = strongSelf->_downloadProgress;
            };
            
            prop.writeBlock = ^(TGMusicPlayerFullView *strongSelf, CGFloat const *values)
            {
                strongSelf->_downloadProgress = values[0];
                [strongSelf layoutScrubbingIndicator];
            };
        }];
    });
    
    if (!status.downloadedStatus.downloaded)
    {
        if (status.downloadedStatus.downloading)
        {
            _downloadingScrubbingForeground.alpha = 1.0f;
            if (TGObjectCompare(previousStatus.item.key, status.item.key))
            {
                [self pop_removeAnimationForKey:@"downloadIndicator"];
                POPBasicAnimation *animation = [self pop_animationForKey:@"downloadIndicator"];
                if (animation == nil)
                {
                    animation = [POPBasicAnimation linearAnimation];
                    [animation setProperty:downloadProgressProperty];
                    animation.removedOnCompletion = true;
                    animation.fromValue = @(_downloadProgress);
                    animation.toValue = @(status.downloadedStatus.progress);
                    animation.beginTime = status.timestamp;
                    animation.duration = 0.25;
                    [self pop_addAnimation:animation forKey:@"downloadIndicator"];
                }
            }
            else
            {
                [self pop_removeAnimationForKey:@"downloadIndicator"];
                _downloadProgress = status.downloadedStatus.progress;
                [self layoutScrubbingIndicator];
            }
        }
        else
        {
            _downloadProgress = status.downloadedStatus.progress;
            _downloadingScrubbingForeground.alpha = 0.0f;
            [self layoutScrubbingIndicator];
        }
    }
    else
    {
        if (TGObjectCompare(previousStatus.item.key, status.item.key))
        {
            if (!previousStatus.downloadedStatus.downloaded)
            {
                [self pop_removeAnimationForKey:@"downloadIndicator"];
                POPBasicAnimation *animation = [self pop_animationForKey:@"downloadIndicator"];
                if (animation == nil)
                {
                    animation = [POPBasicAnimation linearAnimation];
                    [animation setProperty:downloadProgressProperty];
                    animation.removedOnCompletion = true;
                    animation.fromValue = @(_downloadProgress);
                    animation.toValue = @(1.0f);
                    animation.beginTime = status.timestamp;
                    animation.duration = 0.25;
                    
                    __weak TGMusicPlayerFullView *weakSelf = self;
                    animation.completionBlock = ^(__unused POPAnimation *animation, BOOL finished)
                    {
                        if (finished)
                        {
                            __strong TGMusicPlayerFullView *strongSelf = weakSelf;
                            if (strongSelf != nil)
                            {
                                [UIView animateWithDuration:0.3 animations:^
                                {
                                    strongSelf->_downloadingScrubbingForeground.alpha = 0.0f;
                                }];
                            }
                        }
                    };
                    [self pop_addAnimation:animation forKey:@"downloadIndicator"];
                }
            }
        }
        else
            _downloadingScrubbingForeground.alpha = 0.0f;
    }
    
    if (status == nil || status.paused || status.duration < FLT_EPSILON)
    {
        [self pop_removeAnimationForKey:@"scrubbingIndicator"];
        
        _playbackOffset = status.offset;
        [self layoutScrubbingIndicator];
    }
    else
    {
        [self pop_removeAnimationForKey:@"scrubbingIndicator"];
        POPBasicAnimation *animation = [self pop_animationForKey:@"scrubbingIndicator"];
        if (animation == nil)
        {
            animation = [POPBasicAnimation linearAnimation];
            [animation setProperty:playbackOffsetProperty];
            animation.removedOnCompletion = true;
            _playbackOffset = status.offset;
            animation.fromValue = @(status.offset);
            animation.toValue = @(1.0f);
            animation.beginTime = status.timestamp;
            animation.duration = (1.0f - status.offset) * status.duration;
            [self pop_addAnimation:animation forKey:@"scrubbingIndicator"];
        }
    }
}

- (void)setPlaylist:(TGMusicPlayerPlaylist *)playlist
{
    if (playlist.voice)
    {
        [self dismissAnimated:true completion:nil];
        return;
    }
    
    _currentPlaylist = playlist;
    [_collectionView reloadData];
    [_collectionView layoutSubviews];
    
    if (!_presented)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self layoutControls];
            [self setDimViewHidden:false animated:true];
            [self scrollToCurrentItem];
            
            [self applyViewOffset:self.bounds.size.height];
            _containerView.hidden = false;
            
            [self animateSheetViewToPosition:0.0f velocity:0.0f present:true completion:nil];
            
            TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
            {
                _presented = true;
            });
        });
    }
}

- (void)scrollToCurrentItem
{
    NSUInteger count = (NSUInteger)[self collectionView:_collectionView numberOfItemsInSection:0];
    if (_currentItemPosition.index >= count)
        return;
    
    NSUInteger row = [self reversePlaylist] ? count - _currentItemPosition.index - 1 : _currentItemPosition.index;
    CGFloat visibleHeight = _collectionView.frame.size.height - _collectionView.contentInset.bottom;
    CGFloat maxOffset = MAX(0.0f, count * TGMusicPlaylistCellHeight - visibleHeight);
    CGFloat offset = row * TGMusicPlaylistCellHeight - (visibleHeight - TGMusicPlaylistCellHeight) / 2.0f;
    [_collectionView setContentOffset:CGPointMake(0.0f, MAX(0.0f, MIN(maxOffset, offset))) animated:false];
}

- (bool)isGrabAreaPoint:(CGPoint)point
{
    CGFloat grabHeight = CGRectGetMinY(_controlsView.frame) + CGRectGetMinY(_coverView.frame);
    return CGRectContainsPoint(CGRectMake(0.0f, 0.0f, _panelView.bounds.size.width, grabHeight), point);
}

- (void)controlPlay
{
    [TGTelegraphInstance.musicPlayer controlPlay];
}

- (void)controlPause
{
    [TGTelegraphInstance.musicPlayer controlPause];
}

- (void)controlBack
{
    [TGTelegraphInstance.musicPlayer controlPrevious];
}

- (void)controlForward
{
    [TGTelegraphInstance.musicPlayer controlNext];
}

- (void)controlOrder
{
    [TGTelegraphInstance.musicPlayer controlOrder];
}

- (void)controlRepeat
{
    [TGTelegraphInstance.musicPlayer controlRepeat];
}

- (void)actionsButtonPressed
{
    if (self.actionsPressed != nil)
        self.actionsPressed();
}

- (CGPoint)scrubbingLocationForTouch:(UITouch *)touch
{
    return [touch locationInView:_scrubbingArea];
}

- (void)beginScrubbingAtPoint:(CGPoint)point
{
    _shouldBeginScrubbing = true;
    _scrubbingReferencePoint = point;
    _scrubbingOffset = _playbackOffset;
    _scrubbingReferenceOffset = _playbackOffset;
}

- (void)continueScrubbingAtPoint:(CGPoint)point
{
    if (_shouldBeginScrubbing && !_scrubbing && fabs(point.x - _scrubbingReferencePoint.x) > 4.0f)
    {
        _shouldBeginScrubbing = false;
        _scrubbing = true;
        [TGTelegraphInstance.musicPlayer controlPause];
    }
    
    if (_scrubbing && _scrubbingArea.frame.size.width > FLT_EPSILON)
    {
        _scrubbingOffset = MAX(0.0f, MIN(1.0f, _scrubbingReferenceOffset + (point.x - _scrubbingReferencePoint.x) / _scrubbingArea.frame.size.width));
        [self layoutScrubbingIndicator];
    }
}

- (void)finishScrubbing
{
    if (_scrubbing)
    {
        [TGTelegraphInstance.musicPlayer controlSeekToPosition:_scrubbingOffset];
        [TGTelegraphInstance.musicPlayer controlPlay];
    }
    
    _shouldBeginScrubbing = false;
    _scrubbing = false;
    _playbackOffset = _scrubbingOffset;
    _scrubbingOffset = 0.0f;
    [self layoutScrubbingIndicator];
}

- (void)cancelScrubbing
{
    _scrubbing = false;
    _scrubbingOffset = 0.0f;
    [self layoutScrubbingIndicator];
    [TGTelegraphInstance.musicPlayer controlPlay];
}

#pragma mark -

- (void)applyViewOffset:(CGFloat)position
{
    _containerView.frame = CGRectMake(_containerView.frame.origin.x, position, _containerView.frame.size.width, _containerView.frame.size.height);
}

- (void)animateSheetViewToPosition:(CGFloat)position velocity:(CGFloat)velocity present:(bool)present completion:(void (^)(void))completion
{
    CGFloat animationVelocity = position > 0 ? fabs(velocity) / fabs(position - self.frame.origin.y) : 0;
    
    void (^changeBlock)(void) = ^
    {
        [self applyViewOffset:position];
    };
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    };
    
    CGFloat duration = 0.45;
    
    if (present)
    {
        UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAllowAnimatedContent;
        if (iosMajorVersion() >= 7)
            options |= 7 << 16;
        [UIView animateWithDuration:0.3 delay:0.0 options:options animations:changeBlock completion:completionBlock];
    }
    else
    {
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:animationVelocity options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowAnimatedContent animations:changeBlock completion:completionBlock];
        }
        else
        {
            [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowAnimatedContent animations:changeBlock completion:completionBlock];
        }
    }
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (animated)
    {
        [self setDimViewHidden:true animated:true];
        
        [self animateSheetViewToPosition:self.bounds.size.height velocity:0.0 present:false completion:^
        {
           if (self.dismissed != nil)
               self.dismissed();
            
            if (completion != nil)
                completion();
        }];
    }
    else
    {
        if (self.dismissed != nil)
            self.dismissed();
        
        if (completion != nil)
            completion();
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return [self isGrabAreaPoint:[touch locationInView:_panelView]];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self].y > -FLT_EPSILON;
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGFloat location = [gestureRecognizer locationInView:self].y;
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        _panelScrollingReferencePoint = location;
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        [self applyViewOffset:MAX(0.0f, location - _panelScrollingReferencePoint)];
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded && (location - _panelScrollingReferencePoint > self.frame.size.height / 3.0f || [gestureRecognizer velocityInView:self].y > 1000.0f))
    {
        [self dismissAnimated:true completion:nil];
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        [self animateSheetViewToPosition:0.0f velocity:0.0f present:true completion:nil];
    }
}

- (void)dimTapped:(UIGestureRecognizer *)__unused gestureRecognizer
{
    [self dismissAnimated:true completion:nil];
}

- (void)setDimViewHidden:(bool)hidden animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        _dimView.alpha = hidden ? 0.0f : 1.0f;
    };
    
    if (animated)
        [UIView animateWithDuration:0.25f animations:changeBlock];
    else
        changeBlock();
}

- (void)setSeparatorHidden:(bool)hidden animated:(bool)animated
{
    if ((hidden && _separator.alpha < FLT_EPSILON) || (!hidden && _separator.alpha > FLT_EPSILON))
        return;
    
    if (animated)
    {
        [UIView animateWithDuration:0.25 animations:^
         {
             _separator.alpha = hidden ? 0.0f : 1.0f;
         }];
    }
    else
    {
        _separator.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)coverTapped
{
    [self setCoverZoomedIn:_coverExpandProgress < FLT_EPSILON animated:true];
}

- (void)arrowPressed
{
    [self dismissAnimated:true completion:nil];
}

- (void)setCoverZoomedIn:(bool)zoomedIn animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
        {
            _coverExpandProgress = zoomedIn ? 1.0f : 0.0f;
            [self layoutSubviews];
        } completion:nil];
    }
    else
    {
        _coverExpandProgress = zoomedIn ? 1.0f : 0.0f;
        [self setNeedsLayout];
    }
}

#pragma mark -

- (void)updateCells
{
    for (TGMusicPlaylistCell *cell in _collectionView.visibleCells)
    {
        bool isCurrent = [cell.item.key isEqual:_currentStatus.item.key];
        [cell setCurrent:isCurrent];
        [cell setPlaying:isCurrent && !_currentStatus.paused];
    }
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGMusicPlaylistCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:TGMusicPlaylistCellKind forIndexPath:indexPath];
    cell.presentation = _presentation;
    NSUInteger index = [self reversePlaylist] ? _currentPlaylist.items.count - indexPath.row - 1 : indexPath.row;
    TGMusicPlayerItem *item = _currentPlaylist.items[index];
    [cell setItem:item];

    bool isCurrent = [item.key isEqual:_currentStatus.item.key];
    [cell setCurrent:isCurrent];
    [cell setPlaying:isCurrent && !_currentStatus.paused];
    
    return cell;
}

- (NSInteger)collectionView:(PSUICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    return _currentPlaylist.items.count > 1 ? _currentPlaylist.items.count : 0;
}

- (void)collectionView:(PSUICollectionView *)__unused collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger index = [self reversePlaylist] ? _currentPlaylist.items.count - indexPath.row - 1 : indexPath.row;
    TGMusicPlayerItem *item = _currentPlaylist.items[index];
    [TGTelegraphInstance.musicPlayer playMediaFromItem:item];

    [collectionView deselectItemAtIndexPath:collectionView.indexPathsForSelectedItems.firstObject animated:true];
}

- (CGSize)collectionView:(PSUICollectionView *)collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    CGFloat width = collectionView.frame.size.width;
    if (iosMajorVersion() < 7)
        width = MAX(1.0f, width - 1.0f);
    return CGSizeMake(width, TGMusicPlaylistCellHeight);
}

- (bool)reversePlaylistForOrderType:(TGMusicPlayerOrderType)orderType
{
    return orderType == TGMusicPlayerOrderTypeNewestFirst;
}

- (bool)reversePlaylist
{
    return [self reversePlaylistForOrderType:_currentStatus.orderType];
}

#pragma mark -

- (CGFloat)progressHeight
{
    return 3.0f;
}

- (CGSize)handleSize
{
    return CGSizeMake(6.0f, 6.0f);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self layoutControls];
    
    CGFloat previousOffset = scrollView.contentOffset.y;
    if (_previousContentOffset != nil)
        previousOffset = _previousContentOffset.doubleValue;
    _previousContentOffset = @(scrollView.contentOffset.y);
    
    if (scrollView.isTracking && _coverExpandProgress > 1.0f - FLT_EPSILON && fabs(scrollView.contentOffset.y - previousOffset) > FLT_EPSILON)
        [self setCoverZoomedIn:false animated:true];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)__unused scrollView willDecelerate:(BOOL)__unused decelerate
{
    _previousContentOffset = nil;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)__unused scrollView
{
    _previousContentOffset = nil;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)__unused scrollView
{
    _previousContentOffset = nil;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self layoutSubviews];
}

- (void)layoutScrubbingIndicator
{
    CGFloat displayOffset = _scrubbing ? _scrubbingOffset : _playbackOffset;
    
    CGFloat progressHeight = [self progressHeight];
    CGSize handleSize = [self handleSize];
    
    CGFloat screenWidth = TGIsPad() ? 414.0f : self.frame.size.width;
    
    CGFloat padding = 20.0f;
    CGFloat side = screenWidth - padding * 2.0f;
    CGFloat handleOriginX = TGScreenPixelFloor((side - handleSize.width) * displayOffset);
    _playbackScrubbingForeground.frame = CGRectMake(padding, _scrubbingBackground.frame.origin.y, handleOriginX, progressHeight);
    _downloadingScrubbingForeground.frame = CGRectMake(padding, _scrubbingBackground.frame.origin.y, _downloadProgress * side, progressHeight);
    _scrubbingHandle.frame = CGRectMake(padding + handleOriginX - 1.5f, _scrubbingBackground.frame.origin.y - 1.0f - TGScreenPixel, handleSize.width, handleSize.height);
    
    int positionLabelValue = (int)(displayOffset * _currentStatus.duration);
    int durationLabelValue = (int)(_currentStatus.duration) - positionLabelValue;
    
    if (_positionLabelValue != positionLabelValue)
    {
        _positionLabelValue = positionLabelValue;
        
        if (positionLabelValue > 60 * 60)
        {
            _positionLabel.text = [[NSString alloc] initWithFormat:@"%d:%02d:%02d", positionLabelValue / (60 * 60), (positionLabelValue % (60 * 60)) / 60, positionLabelValue % 60];
        }
        else
        {
            _positionLabel.text = [[NSString alloc] initWithFormat:@"%d:%02d", positionLabelValue / 60, positionLabelValue % 60];
        }
        [_positionLabel sizeToFit];
    }
    _positionLabel.frame = CGRectMake(padding, _scrubbingBackground.frame.origin.y + 8.0f, _positionLabel.frame.size.width, _positionLabel.frame.size.height);
    
    if (_durationLabelValue != durationLabelValue)
    {
        _durationLabelValue = durationLabelValue;
        
        if (durationLabelValue > 60 * 60)
        {
            _durationLabel.text = [[NSString alloc] initWithFormat:@"-%d:%02d:%02d", durationLabelValue / (60 * 60), (durationLabelValue % (60 * 60)) / 60, durationLabelValue % 60];
        }
        else
        {
            _durationLabel.text = [[NSString alloc] initWithFormat:@"-%d:%02d", durationLabelValue / 60, durationLabelValue % 60];
        }
        [_durationLabel sizeToFit];
    }
    _durationLabel.frame = CGRectMake(padding + side - _durationLabel.frame.size.width, _scrubbingBackground.frame.origin.y + 8.0f, _durationLabel.frame.size.width, _durationLabel.frame.size.height);
    
    CGFloat center = padding + side / 2.0f;
    CGFloat bitrateWidth = MAX(0.0f, 2.0f * MIN(center - CGRectGetMaxX(_positionLabel.frame) - 6.0f, CGRectGetMinX(_durationLabel.frame) - center - 6.0f));
    _bitrateView.frame = CGRectMake(CGFloor(center - bitrateWidth / 2.0f), _durationLabel.frame.origin.y, bitrateWidth, _durationLabel.frame.size.height);
}

- (void)layoutControls
{
    CGFloat side = MIN(self.frame.size.width, self.frame.size.height);
    side = MIN(side, 414.0f);
    
    CGFloat screenWidth = TGIsPad() ? 414.0f : (self.frame.size.width - _safeAreaInset.left - _safeAreaInset.right);
    if (TGIsPad())
        side = screenWidth;
    
    CGFloat scrubbingHeight = 32.0f;
    CGFloat progressHeight = [self progressHeight];
    
    CGFloat albumArtHeight = side;
    CGSize albumArtImageSize = CGSizeZero;
    
    albumArtHeight = 280.0f;
    albumArtImageSize = CGSizeMake(200.0f, 200.0f);
    
    CGFloat headerHeight = 20.0f;
    CGFloat collapsedControlsHeight = 230.0f - headerHeight;
    CGFloat collapsedPanelHeight = _safeAreaInset.top + headerHeight + collapsedControlsHeight;
    CGFloat largeCoverSize = MAX(48.0f, MIN(side - 20.0f * 2.0f, self.frame.size.height - _safeAreaInset.bottom - collapsedPanelHeight - 20.0f));
    CGFloat largeCoverSpace = largeCoverSize + 20.0f;
    CGFloat scrubberOffset = 94.0f + largeCoverSpace * _coverExpandProgress;
    CGFloat controlsHeight = collapsedControlsHeight + largeCoverSpace * _coverExpandProgress;
    _controlsView.frame = CGRectMake(0.0f, _safeAreaInset.top + headerHeight, screenWidth, controlsHeight);
    
    CGFloat panelHeight = CGRectGetMaxY(_controlsView.frame);
    _panelView.frame = CGRectMake(0.0f, 0.0f, screenWidth, panelHeight);
    _arrowView.frame = CGRectMake((screenWidth - _arrowView.frame.size.width) / 2.0f, _safeAreaInset.top + 22.0f, _arrowView.frame.size.width, _arrowView.frame.size.height);
    
    CGRect collectionFrame = CGRectMake(0.0f, panelHeight, screenWidth, MAX(0.0f, self.frame.size.height - panelHeight));
    if (!CGRectEqualToRect(_collectionView.frame, collectionFrame))
        _collectionView.frame = collectionFrame;
    if (fabs(_collectionView.contentInset.bottom - _safeAreaInset.bottom) > FLT_EPSILON)
        _collectionView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, _safeAreaInset.bottom, 0.0f);
    
    [self setSeparatorHidden:_collectionView.contentOffset.y < -_collectionView.contentInset.top + FLT_EPSILON animated:true];
    
    _scrubbingArea.frame = CGRectMake(0.0f, scrubberOffset + progressHeight / 2.0f - scrubbingHeight / 2.0f, _controlsView.bounds.size.width, scrubbingHeight);
    _scrubbingBackground.frame = CGRectMake(20.0f, scrubberOffset, _controlsView.bounds.size.width - 20.0f * 2.0f, progressHeight);
    
    CGFloat titleOffset = 27.0f + largeCoverSpace * _coverExpandProgress;
    CGFloat controlButtonsOffset = scrubberOffset + 35.0f;
    CGFloat controlButtonSize = 60.0f;
    CGFloat controlButtonSpread = 142.0f;
    if ([_context fullscreenBounds].size.width <= 320)
        controlButtonSpread = 100.0f;
    
    CGSize titleSize = _titleLabel.frame.size;
    CGSize performerSize = _performerLabel.frame.size;
    
    if (_updateLabelsLayout)
    {
        _updateLabelsLayout = false;
        titleSize = [_titleLabel.text sizeWithFont:_titleLabel.font];
        performerSize = [_performerLabel.text sizeWithFont:_performerLabel.font];
        CGFloat maxWidth = _controlsView.bounds.size.width - 68.0f * 2.0f;
        titleSize.width = MIN(titleSize.width, maxWidth);
        performerSize.width = MIN(performerSize.width, maxWidth);
    }
    
    CGFloat coverSize = 48.0f + (largeCoverSize - 48.0f) * _coverExpandProgress;
    CGFloat coverX = 20.0f + (CGFloor((_controlsView.bounds.size.width - largeCoverSize) / 2.0f) - 20.0f) * _coverExpandProgress;
    _coverView.frame = CGRectMake(coverX, 24.0f, coverSize, coverSize);
    if (_pluginLyricsContainer != nil)
    {
        _pluginLyricsContainer.hidden = _coverExpandProgress < 0.7f;
        _pluginLyricsContainer.frame = CGRectMake(coverX + 8.0f, CGRectGetMaxY(_coverView.frame) - 72.0f, MAX(0.0f, coverSize - 16.0f), 64.0f);
        _pluginLyricsScene.frame = _pluginLyricsContainer.bounds;
        _pluginLyricsLabel.frame = _pluginLyricsContainer.bounds;
    }
    
    CGFloat titleX = 85.0f + (CGFloor((_controlsView.bounds.size.width - titleSize.width) / 2.0f) - 85.0f) * _coverExpandProgress;
    CGFloat performerX = 85.0f + (CGFloor((_controlsView.bounds.size.width - performerSize.width) / 2.0f) - 85.0f) * _coverExpandProgress;
    
    _titleLabel.frame = CGRectMake(titleX, titleOffset, titleSize.width, titleSize.height);
    _performerLabel.frame = CGRectMake(performerX, titleOffset + titleSize.height + 6.0f, performerSize.width, performerSize.height);
    
    _controlPauseButton.frame = _controlPlayButton.frame = CGRectMake(CGFloor((_controlsView.bounds.size.width - controlButtonSize) / 2.0f), controlButtonsOffset, controlButtonSize, controlButtonSize);
    _controlBackButton.frame = CGRectMake(CGFloor((_controlsView.bounds.size.width - controlButtonSpread) / 2.0f) - controlButtonSize, controlButtonsOffset, controlButtonSize, controlButtonSize);
    _controlForwardButton.frame = CGRectMake(CGFloor((_controlsView.bounds.size.width + controlButtonSpread) / 2.0f), controlButtonsOffset, controlButtonSize, controlButtonSize);
    
    CGSize modeButtonSize = CGSizeMake(28.0f, 21.0f);
    _controlShuffleButton.frame = CGRectMake(16.0f, _controlPlayButton.frame.origin.y + 19.0f, modeButtonSize.width, modeButtonSize.height);
    _controlRepeatButton.frame = CGRectMake(_controlsView.bounds.size.width - 44.0f, _controlShuffleButton.frame.origin.y, modeButtonSize.width, modeButtonSize.height);
    
    _actionsButton.frame = CGRectMake(_controlsView.bounds.size.width - 51.0f, titleOffset - 1.0f, 44.0f, 44.0f);
    
    _separator.frame = CGRectMake(0.0f, CGRectGetMaxY(_controlsView.frame), _containerView.bounds.size.width, TGScreenPixel);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!TGIsPad() && self.frame.size.width > self.frame.size.height)
        _coverExpandProgress = 0.0f;
    
    _dimView.frame = self.bounds;
    
    CGFloat screenWidth = TGIsPad() ? 414.0f : (self.frame.size.width - _safeAreaInset.left - _safeAreaInset.right);
    _containerView.frame = CGRectMake(floor((self.frame.size.width - screenWidth) / 2.0f), _containerView.frame.origin.y, screenWidth, self.frame.size.height);
    _pluginBackgroundLayer.frame = _containerView.bounds;
    
    CGFloat collectonViewWidth = _collectionView.frame.size.width;
    [self layoutControls];
    
    if (fabs(collectonViewWidth - _collectionView.frame.size.width) > FLT_EPSILON)
        [_collectionView.collectionViewLayout invalidateLayout];
    
    [self layoutScrubbingIndicator];
}

- (UIButton *)actionsButton
{
    return _actionsButton;
}

@end


@implementation TGMusicPlayerCollectionView

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    [super setContentOffset:contentOffset animated:animated];
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)__unused view
{
    return true;
}

@end
