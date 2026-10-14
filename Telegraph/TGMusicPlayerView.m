#import "TGMusicPlayerView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <MediaPlayer/MediaPlayer.h>

#import "TGTelegraph.h"
#import "TGInterfaceManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "TGMusicPlayerController.h"
#import "TGBrandedMusicPlayerController.h"
#import "TGVideoMessagePIPController.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGMusicPlayerAppearance.h"
#import "../OnegramUI/Core/OGSurfaceStyle.h"
#import "../OnegramUI/Core/OGSurfaceRenderer.h"

@interface TGMusicPlayerTitleLabel : UILabel
@property (nonatomic) bool embossedTitle;
@end

@implementation TGMusicPlayerTitleLabel

- (void)setEmbossedTitle:(bool)embossedTitle
{
    if (_embossedTitle != embossedTitle)
    {
        _embossedTitle = embossedTitle;
        [self setNeedsDisplay];
    }
}

- (void)drawTextInRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    if (_embossedTitle)
        CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.5f, [UIColor colorWithWhite:0.0f alpha:0.3f].CGColor);
    [super drawTextInRect:rect];
    CGContextRestoreGState(context);
}

@end

@interface TGMusicPlayerView ()
{
    __weak UINavigationController *_navigationController;
    
    UIView *_minimizedBar;
    UIButton *_minimizedButton;
    UIView *_minimizedBarStripe;
    TGMusicPlayerTitleLabel *_titleLabel;
    UILabel *_performerLabel;
    UIView *_scrubbingIndicator;
    UIImageView *_brandedBackgroundView;
    UIImageView *_brandedDisplayView;
    UIImageView *_musicGlyphView;
    UILabel *_remainingTimeLabel;
    OGMusicPlayerAppearance *_brandedAppearance;
    UIImageView *_compactChevronView;
    TGNavigationBarMusicPlayerLayout _playerLayout;
    void (^_compactHeaderActivated)(void);
    
    TGModernButton *_closeButton;
    TGModernButton *_pauseButton;
    TGModernButton *_playButton;
    TGModernButton *_rateButton;
    
    id<SDisposable> _playerStatusDisposable;
    
    TGMusicPlayerStatus *_currentStatus;
    NSString *_title;
    NSString *_performer;
    CGFloat _playbackOffset;
    bool _isVoice;
    
    bool _updateLabelsLayout;
    
    MPVolumeView *_volumeOverlayFixView;
    
    TGVideoMessagePIPController *_pipController;
    
    TGPresentation *_presentation;
    id<SDisposable> _presentationDisposable;
}
@end

@implementation TGMusicPlayerView

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController
{
    self = [super init];
    if (self != nil)
    {
        _navigationController = navigationController;
        
        self.clipsToBounds = true;
        
        __weak TGMusicPlayerView *weakSelf = self;
        _presentationDisposable = [TGPresentation.signal startWithNext:^(TGPresentation *next)
        {
            __strong TGMusicPlayerView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setPresentation:next];
        }];
        
        _minimizedBar = [[UIView alloc] init];
        _minimizedBar.backgroundColor = _presentation.pallete.barBackgroundColor;
        _minimizedButton = [[UIButton alloc] init];
        [_minimizedButton addTarget:self action:@selector(minimizedButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_minimizedBar addSubview:_minimizedButton];
        [self addSubview:_minimizedBar];
        
        _minimizedBarStripe = [[UIView alloc] init];
        _minimizedBarStripe.backgroundColor = _presentation.pallete.barSeparatorColor;
        [_minimizedBar addSubview:_minimizedBarStripe];
        
        _closeButton = [[TGModernButton alloc] init];
        _closeButton.adjustsImageWhenHighlighted = false;
        [_closeButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerMinimizedClose.png"), _presentation.pallete.navigationSubtitleColor) forState:UIControlStateNormal];
        [_closeButton addTarget:self action:@selector(closeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_minimizedBar addSubview:_closeButton];
        
        _playButton = [[TGModernButton alloc] init];
        _playButton.adjustsImageWhenHighlighted = false;
        [_playButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerMinimizedPlay.png"), _presentation.pallete.navigationButtonColor) forState:UIControlStateNormal];
        [_playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_minimizedBar addSubview:_playButton];
        _playButton.hidden = true;
        
        _pauseButton = [[TGModernButton alloc] init];
        _pauseButton.adjustsImageWhenHighlighted = false;
        [_pauseButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerMinimizedPause.png"), _presentation.pallete.navigationButtonColor) forState:UIControlStateNormal];
        [_pauseButton addTarget:self action:@selector(pauseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_minimizedBar addSubview:_pauseButton];
        _pauseButton.hidden = true;
        
        _rateButton = [[TGModernButton alloc] init];
        [_rateButton setImage:_presentation.images.musicPlayerRate2xIcon forState:UIControlStateNormal];
        [_rateButton addTarget:self action:@selector(rateButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_minimizedBar addSubview:_rateButton];
        
        _titleLabel = [[TGMusicPlayerTitleLabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = _presentation.pallete.navigationTitleColor;
        _titleLabel.font = TGSystemFontOfSize(12.0f);
        [_minimizedBar addSubview:_titleLabel];
        
        _performerLabel = [[UILabel alloc] init];
        _performerLabel.backgroundColor = [UIColor clearColor];
        _performerLabel.textColor = _presentation.pallete.navigationSubtitleColor;
        _performerLabel.font = TGSystemFontOfSize(10.0f);
        [_minimizedBar addSubview:_performerLabel];
        
        _scrubbingIndicator = [[UIView alloc] init];
        _scrubbingIndicator.backgroundColor = _presentation.pallete.navigationButtonColor;
        [_minimizedBar addSubview:_scrubbingIndicator];

        _brandedBackgroundView = [[UIImageView alloc] init];
        [_minimizedBar insertSubview:_brandedBackgroundView atIndex:0];
        _brandedDisplayView = [[UIImageView alloc] init];
        [_minimizedBar insertSubview:_brandedDisplayView aboveSubview:_brandedBackgroundView];
        _compactChevronView = [[UIImageView alloc] init];
        [_minimizedBar addSubview:_compactChevronView];
        _musicGlyphView = [[UIImageView alloc] init];
        [_minimizedBar addSubview:_musicGlyphView];
        _remainingTimeLabel = [[UILabel alloc] init];
        _remainingTimeLabel.backgroundColor = [UIColor clearColor];
        _remainingTimeLabel.textAlignment = NSTextAlignmentCenter;
        [_minimizedBar addSubview:_remainingTimeLabel];
        [self setPresentation:_presentation];
        
        _playerStatusDisposable = [[TGTelegraphInstance.musicPlayer playingStatus] startWithNext:^(TGMusicPlayerStatus *status)
        {
            __strong TGMusicPlayerView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                [strongSelf setStatus:status];
            }
        }];
        
        _updateLabelsLayout = true;
        
        _pipController = [[TGVideoMessagePIPController alloc] init];
        _pipController.messageVisibilitySignal = ^SSignal *(int64_t cid, int32_t messageId, int64_t peerId)
        {
            return [[[TGInterfaceManager instance] messageVisibilitySignalWithConversationId:cid messageId:messageId peerId:peerId] deliverOn:[SQueue mainQueue]];
        };
        _pipController.requestedDismissal = ^
        {
            [TGTelegraphInstance.musicPlayer setPlaylist:nil initialItemKey:nil metadata:nil];
        };
    }
    return self;
}

- (void)dealloc
{
    [_playerStatusDisposable dispose];
    [_presentationDisposable dispose];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _brandedAppearance = [TGPresentation brandedIOS6Style] ? (_playerLayout == TGNavigationBarMusicPlayerLayoutStandard ? [OGTheme brandedTheme].musicPlayerAppearance : [OGMusicPlayerAppearance conversationAppearanceDark:[OGTheme brandedTheme].dark compact:_playerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation]) : nil;
    
    _minimizedBar.backgroundColor = presentation.pallete.barBackgroundColor;
    _minimizedBarStripe.backgroundColor = presentation.pallete.barSeparatorColor;
    _titleLabel.textColor = presentation.pallete.navigationTitleColor;
    _performerLabel.textColor = presentation.pallete.navigationSubtitleColor;
    
    _scrubbingIndicator.backgroundColor = presentation.pallete.navigationButtonColor;
    
    [_closeButton setImage:presentation.images.pinCloseIcon forState:UIControlStateNormal];
    [_playButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerMinimizedPlay.png"), _presentation.pallete.navigationButtonColor) forState:UIControlStateNormal];
    [_pauseButton setImage:TGTintedImage(TGImageNamed(@"MusicPlayerMinimizedPause.png"), _presentation.pallete.navigationButtonColor) forState:UIControlStateNormal];

    _playButton.imageEdgeInsets = UIEdgeInsetsZero;
    _pauseButton.imageEdgeInsets = UIEdgeInsetsZero;
    _closeButton.imageEdgeInsets = UIEdgeInsetsZero;
    bool branded = _brandedAppearance != nil;
    _brandedBackgroundView.hidden = !branded;
    _brandedDisplayView.hidden = !branded;
    _musicGlyphView.hidden = !branded;
    _remainingTimeLabel.hidden = !branded;
    _minimizedBarStripe.hidden = branded;
    _scrubbingIndicator.alpha = branded ? 0.0f : 1.0f;
    _titleLabel.font = branded ? _brandedAppearance.font : TGSystemFontOfSize(12.0f);
    _performerLabel.hidden = branded;
    if (branded)
    {
        _minimizedBar.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = _brandedAppearance.titleColor;
        _remainingTimeLabel.font = _brandedAppearance.font;
        _remainingTimeLabel.textColor = _brandedAppearance.timeColor;
        [_playButton setImage:[_brandedAppearance imageForGlyph:OGMusicPlayerGlyphPlay] forState:UIControlStateNormal];
        [_pauseButton setImage:[_brandedAppearance imageForGlyph:OGMusicPlayerGlyphPause] forState:UIControlStateNormal];
        [_closeButton setImage:[_brandedAppearance imageForGlyph:OGMusicPlayerGlyphClose] forState:UIControlStateNormal];
        _musicGlyphView.image = [_brandedAppearance imageForGlyph:OGMusicPlayerGlyphMusic];
        _compactChevronView.image = [_brandedAppearance imageForGlyph:OGMusicPlayerGlyphChevron];
    }
    _playButton.alpha = branded ? 0.8f : 1.0f;
    _pauseButton.alpha = branded ? 0.8f : 1.0f;
    _closeButton.alpha = branded ? 0.8f : 1.0f;
    bool compact = _playerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation && branded;
    _titleLabel.embossedTitle = compact;
    [self updateTrackLabels];
    [self updateRateButton];
    [self updatePlayerVisibility];
    _updateLabelsLayout = true;
    [self setNeedsLayout];
}

- (CGFloat)preferredHeight
{
    return [TGPresentation brandedIOS6Style] ? [OGTheme brandedTheme].musicPlayerAppearance.height : 37.0f;
}

- (void)setCompactHeaderActivated:(void (^)(void))activated
{
    _compactHeaderActivated = [activated copy];
}

- (void)setPlayerLayout:(TGNavigationBarMusicPlayerLayout)layout
{
    if (_playerLayout != layout)
    {
        _playerLayout = layout;
        [self setPresentation:_presentation];
    }
}

- (void)updatePlayerVisibility
{
    bool branded = _brandedAppearance != nil;
    bool compact = branded && _playerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation;
    _brandedDisplayView.hidden = !branded || compact;
    _remainingTimeLabel.hidden = !branded || compact;
    _musicGlyphView.hidden = !branded || compact || (_playerLayout != TGNavigationBarMusicPlayerLayoutStandard && _currentStatus.item.isVoice);
    _compactChevronView.hidden = !compact;
    _playButton.hidden = compact || !_currentStatus.paused;
    _pauseButton.hidden = compact || _currentStatus.paused;
    _closeButton.hidden = compact;
    _rateButton.hidden = compact || !_currentStatus.item.isVoice;
}

- (void)updateTrackLabels
{
    if (_brandedAppearance != nil && _playerLayout != TGNavigationBarMusicPlayerLayoutStandard && _currentStatus.item.isVoice)
        _titleLabel.text = TGLocalized(@"MusicPlayer.VoiceNote");
    else if (_brandedAppearance != nil && _performer.length != 0 && _title.length != 0)
        _titleLabel.text = _currentStatus.item.isVoice ? [NSString stringWithFormat:@"%@ · %@", _title, _performer] : [NSString stringWithFormat:@"%@ - %@", _performer, _title];
    else
        _titleLabel.text = _title;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _performerLabel.text = _performer;
}

- (void)updateRateButton
{
    if (_brandedAppearance != nil)
    {
        [_rateButton setImage:nil forState:UIControlStateNormal];
        [_rateButton setTitle:[NSString stringWithFormat:@"%gx", _currentStatus != nil ? _currentStatus.rate : 1.0f] forState:UIControlStateNormal];
        [_rateButton setTitleColor:_brandedAppearance.timeColor forState:UIControlStateNormal];
        _rateButton.titleLabel.font = _brandedAppearance.font;
    }
    else
    {
        [_rateButton setTitle:nil forState:UIControlStateNormal];
        [_rateButton setImage:_currentStatus.rate > 1.5f ? _presentation.images.musicPlayerRate2xActiveIcon : _presentation.images.musicPlayerRate2xIcon forState:UIControlStateNormal];
    }
}

- (void)setFrame:(CGRect)frame
{
    _updateLabelsLayout = ABS(frame.size.width - self.frame.size.width) > FLT_EPSILON;
    [super setFrame:frame];
    
    if (_updateLabelsLayout)
        [self setNeedsLayout];
}

- (void)inhibitVolumeOverlay
{
    if (_volumeOverlayFixView != nil)
        return;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIView *rootView = keyWindow.rootViewController.view;
    
    _volumeOverlayFixView = [[MPVolumeView alloc] initWithFrame:CGRectMake(10000, 10000, 20, 20)];
    [rootView addSubview:_volumeOverlayFixView];
}

- (void)releaseVolumeOverlay
{
    [_volumeOverlayFixView removeFromSuperview];
    _volumeOverlayFixView = nil;
}

- (void)setStatus:(TGMusicPlayerStatus *)status
{
    TGMusicPlayerStatus *previousStatus = _currentStatus;
    _currentStatus = status;
    if (!TGObjectCompare(status.item, previousStatus.item))
    {
        NSString *title = nil;
        NSString *performer = nil;
        
        if (status.item.isVoice) {
            if (status.item.author != nil) {
                NSString *authorName = [status.item.author displayFirstName];
                if (TGTelegraphInstance.clientUserId == status.item.author.uid) {
                    authorName = TGLocalized(@"DialogList.You");
                }
                title = authorName;
                performer = [TGDateUtils stringForApproximateDate:status.item.date];
            } else {
                if (status.item.isVideo) {
                    title = TGLocalized(@"Message.VideoMessage");
                } else {
                    title = TGLocalized(@"MusicPlayer.VoiceNote");
                }
                if (status.item.date > 0)
                    performer = [TGDateUtils stringForApproximateDate:status.item.date];
            }
        } else {
            title = status.item.title;
            performer = status.item.performer;
            
            if (title.length == 0)
                title = @"Unknown Track";
            
            if (performer.length == 0)
                performer = @"Unknown Artist";
        }
        
        if (status != nil)
        {
            _rateButton.hidden = !status.item.isVoice;
            
            if (!TGStringCompare(_title, title) || !TGStringCompare(_performer, performer))
            {
                _updateLabelsLayout = true;
                _title = title;
                _performer = performer;
                
                [self updateTrackLabels];
                
                [self setNeedsLayout];
            }
        }
    }
    
    if (_currentStatus != nil)
        [self inhibitVolumeOverlay];
    else
        [self releaseVolumeOverlay];
    
    static POPAnimatableProperty *property = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        property = [POPAnimatableProperty propertyWithName:@"playbackOffset" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(TGMusicPlayerView *strongSelf, CGFloat *values)
            {
                values[0] = strongSelf->_playbackOffset;
            };
            
            prop.writeBlock = ^(TGMusicPlayerView *strongSelf, CGFloat const *values)
            {
                strongSelf->_playbackOffset = values[0];
                [strongSelf layoutScrubbingIndicator];
            };
        }];
    });
    
    [self updatePlayerVisibility];
    _scrubbingIndicator.hidden = status.isVoice;
    
    if (status != nil && fabs(previousStatus.rate - status.rate) > FLT_EPSILON)
    {
        [self updateRateButton];
    }
    
    if (status == nil || status.paused || status.duration < FLT_EPSILON || status.offset < 0.01 || (_scrubbingIndicator.hidden && _brandedAppearance == nil))
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
            [animation setProperty:property];
            animation.removedOnCompletion = true;
            animation.fromValue = @(status.offset);
            animation.toValue = @(1.0f);
            animation.beginTime = status.timestamp;
            animation.duration = (1.0f - status.offset) * status.duration / (_brandedAppearance != nil ? MAX(0.1f, status.rate) : 1.0f);
            [self pop_addAnimation:animation forKey:@"scrubbingIndicator"];
        }
    }
}

- (void)layoutScrubbingIndicator
{
    if (_brandedAppearance != nil)
    {
        NSInteger remaining = (NSInteger)ceil(MAX(0.0f, _currentStatus.duration * (1.0f - MIN(1.0f, MAX(0.0f, _playbackOffset)))));
        NSString *time = [NSString stringWithFormat:@"%ld:%02ld", (long)(remaining / 60), (long)(remaining % 60)];
        if (![_remainingTimeLabel.text isEqualToString:time])
        {
            _remainingTimeLabel.text = time;
            [self setNeedsLayout];
        }
        return;
    }
    CGFloat indicatorHeight = 2.0f - TGRetinaPixel;
    _scrubbingIndicator.frame = CGRectMake(0.0f, 37.0f - indicatorHeight, TGRetinaFloor(self.frame.size.width *  _playbackOffset), indicatorHeight);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (_brandedAppearance != nil)
    {
        OGMusicPlayerAppearance *appearance = _brandedAppearance;
        OGTheme *theme = [OGTheme brandedTheme];
        CGSize size = CGSizeMake(self.bounds.size.width, appearance.height);
        self.backgroundColor = [UIColor clearColor];
        _minimizedBar.frame = CGRectMake(0.0f, 0.0f, size.width, size.height);
        UIEdgeInsets outsets = [appearance.backgroundSurfaceStyle dropShadowOutsets];
        CGSize backgroundSize = CGSizeMake(size.width, size.height + outsets.bottom);
        _brandedBackgroundView.frame = CGRectMake(0.0f, 0.0f, backgroundSize.width, backgroundSize.height);
        _brandedBackgroundView.image = [theme.surfaceRenderer imageWithStyle:appearance.backgroundSurfaceStyle size:backgroundSize bodyFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
        if (_playerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation)
        {
            _compactChevronView.frame = CGRectMake(8.0f, 9.0f, 13.0f, 9.0f);
            _titleLabel.frame = CGRectMake((size.width - 130.0f) / 2.0f, 4.0f, 130.0f, 17.0f);
            _minimizedButton.frame = _minimizedBar.bounds;
            return;
        }
        CGRect displayFrame = CGRectMake(appearance.displayLeftInset, appearance.displayTopInset, MAX(0.0f, size.width - appearance.displayLeftInset - appearance.displayRightInset), 29.0f);
        _brandedDisplayView.frame = displayFrame;
        _brandedDisplayView.image = [theme.surfaceRenderer imageWithStyle:appearance.displaySurfaceStyle size:displayFrame.size bodyFrame:CGRectMake(0.0f, 0.0f, displayFrame.size.width, displayFrame.size.height)];
        _minimizedButton.frame = displayFrame;
        _musicGlyphView.frame = CGRectMake(displayFrame.origin.x + 7.0f, appearance.controlTopInset, 16.0f, 16.0f);
        _playButton.frame = CGRectMake(0.0f, 0.0f, appearance.displayLeftInset, size.height);
        _pauseButton.frame = _playButton.frame;
        UIEdgeInsets playInsets = UIEdgeInsetsMake(appearance.controlTopInset * 2.0f + 16.0f - size.height, appearance.controlLeftInset * 2.0f + 16.0f - appearance.displayLeftInset, 0.0f, 0.0f);
        _playButton.imageEdgeInsets = playInsets;
        _pauseButton.imageEdgeInsets = playInsets;
        bool conversation = _playerLayout == TGNavigationBarMusicPlayerLayoutConversation;
        CGFloat closeWidth = conversation ? 24.0f : 44.0f;
        _closeButton.frame = CGRectMake(size.width - closeWidth, 0.0f, closeWidth, size.height);
        _closeButton.imageEdgeInsets = UIEdgeInsetsMake(appearance.closeTopInset * 2.0f + 20.0f - size.height, closeWidth - 20.0f - 2.0f * appearance.closeRightInset, 0.0f, 0.0f);
        CGFloat timeWidth = MAX(29.0f, ceil([_remainingTimeLabel.text sizeWithFont:appearance.font].width));
        _remainingTimeLabel.frame = CGRectMake(CGRectGetMaxX(displayFrame) - 6.0f - timeWidth, displayFrame.origin.y + 7.0f, timeWidth, 15.0f);
        _rateButton.frame = conversation ? CGRectMake(CGRectGetMaxX(displayFrame) + 6.0f, displayFrame.origin.y, MAX(0.0f, _closeButton.frame.origin.x - CGRectGetMaxX(displayFrame) - 6.0f), displayFrame.size.height) : CGRectMake(_remainingTimeLabel.frame.origin.x - 28.0f, displayFrame.origin.y, 24.0f, displayFrame.size.height);
        CGFloat titleRight = conversation || _rateButton.hidden ? _remainingTimeLabel.frame.origin.x - 6.0f : _rateButton.frame.origin.x - 4.0f;
        CGFloat titleInset = conversation && _currentStatus.item.isVoice ? 10.0f : 29.0f;
        _titleLabel.frame = CGRectMake(displayFrame.origin.x + titleInset, displayFrame.origin.y + 7.0f, MAX(0.0f, titleRight - displayFrame.origin.x - titleInset), 15.0f);
        [self layoutScrubbingIndicator];
        return;
    }
    
    self.backgroundColor = _presentation.pallete.barBackgroundColor;
    
    _minimizedBar.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, 37.0f);
    CGFloat separatorHeight = TGScreenPixel;
    _minimizedBarStripe.frame = CGRectMake(0.0f, 37.0f - separatorHeight, self.frame.size.width, separatorHeight);
    _closeButton.frame = CGRectMake(self.frame.size.width - 44.0f, TGRetinaPixel, 44.0f, 36.0f);
    
    _pauseButton.frame = CGRectMake(0.0f, 0.0f, 46.0f, 36.0f);
    _playButton.frame = CGRectMake(0.0f, 0.0f, 48.0f, 36.0f);
    _rateButton.frame = CGRectMake(self.frame.size.width - 80.0f, 0.0f, 48.0f, 36.0f);
    
    CGSize titleSize = _titleLabel.frame.size;
    CGSize performerSize = _performerLabel.frame.size;
    if (_updateLabelsLayout)
    {
        titleSize = [_titleLabel.text sizeWithFont:_titleLabel.font];
        performerSize = [_performerLabel.text sizeWithFont:_performerLabel.font];
        CGFloat maxWidth = self.frame.size.width - 54.0f * 2.0f;
        titleSize.width = MIN(titleSize.width, maxWidth);
        performerSize.width = MIN(performerSize.width, maxWidth);
    }
    
    _titleLabel.frame = CGRectMake(CGFloor((self.frame.size.width - titleSize.width) / 2.0f), _performerLabel.text.length == 0 ? 10.0f : 4.0f, titleSize.width, titleSize.height);
    _performerLabel.frame = CGRectMake(CGFloor((self.frame.size.width - performerSize.width) / 2.0f), 20.0f - TGRetinaPixel, performerSize.width, performerSize.height);
    
    _minimizedButton.frame = CGRectMake(44.0f, 0.0f, _minimizedBar.frame.size.width - 44.0f * 2.0f, _minimizedBar.frame.size.height);
    
    [self layoutScrubbingIndicator];
}

- (void)closeButtonPressed
{
    [TGTelegraphInstance.musicPlayer setPlaylist:nil initialItemKey:nil metadata:nil];
}

- (void)pauseButtonPressed
{
    [TGTelegraphInstance.musicPlayer controlPause];
}

- (void)playButtonPressed
{
    [TGTelegraphInstance.musicPlayer controlPlay];
}

- (void)rateButtonPressed
{
    [TGTelegraphInstance.musicPlayer controlToggleRate];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect closeButtonFrame = CGRectOffset(_closeButton.frame, _minimizedBar.frame.origin.x, _minimizedBar.frame.origin.y);
    if (!_closeButton.hidden && _closeButton.alpha > FLT_EPSILON && CGRectContainsPoint(closeButtonFrame, point))
    {
        return _closeButton;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)minimizedButtonPressed
{
    if (_playerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation && _compactHeaderActivated != nil)
    {
        _compactHeaderActivated();
        return;
    }
    if (_currentStatus.item == nil)
        return;
    
    if (_currentStatus.item.isVoice)
    {
        NSNumber *key = (NSNumber *)_currentStatus.item.key;
        int32_t mid = 0;
        if ([key isKindOfClass:[NSNumber class]])
            mid = [key intValue];
        
        if (mid == 0)
            return;
        
        [[TGInterfaceManager instance] navigateToConversationWithId:_currentStatus.item.conversationId conversation:nil performActions:nil atMessage:@{ @"mid": @(mid), @"useExisting": @true } clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
        return;
    }
    
    UINavigationController *navigationController = _navigationController;
    if ([TGPresentation brandedIOS6Style] && navigationController != nil)
    {
        for (UIViewController *viewController in navigationController.viewControllers)
        {
            if ([viewController isKindOfClass:[TGBrandedMusicPlayerController class]])
                return;
        }
        [navigationController pushViewController:[[TGBrandedMusicPlayerController alloc] init] animated:true];
        return;
    }
    
    TGMusicPlayerController *controller = [[TGMusicPlayerController alloc] init];
    controller.presentation = _presentation;
    UIViewController *rootController = _navigationController.parentViewController;
    if (rootController == nil)
        rootController = _navigationController;
    [controller presentFromController:rootController];
}

@end
