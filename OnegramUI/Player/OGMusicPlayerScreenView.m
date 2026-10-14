#import "OGMusicPlayerScreenView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGAssets.h"
#import "../Core/OGGeometry.h"
#import "../Core/OGSurfaceStyle.h"
#import "../Core/OGSurfaceRenderer.h"
#import "../Core/OGMusicPlayerScreenAppearance.h"

#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>

static void OGMusicPlayerSetVolumeViewImage(MPVolumeView *volumeView, NSString *selectorName, UIImage *image)
{
    SEL selector = NSSelectorFromString(selectorName);
    if (volumeView == nil || ![volumeView respondsToSelector:selector])
        return;
    void (*function)(id, SEL, UIImage *, UIControlState) = (void (*)(id, SEL, UIImage *, UIControlState))[volumeView methodForSelector:selector];
    if (function != NULL)
        function(volumeView, selector, image, UIControlStateNormal);
}

static NSString *const OGMusicPlayerScreenCellIdentifier = @"OGMusicPlayerScreenCell";

@implementation OGMusicPlayerScreenRow
@end

@class OGMusicPlayerScreenTouchView;

@protocol OGMusicPlayerScreenTouchViewDelegate <NSObject>
- (void)touchView:(OGMusicPlayerScreenTouchView *)touchView beganAtPoint:(CGPoint)point;
- (void)touchView:(OGMusicPlayerScreenTouchView *)touchView movedToPoint:(CGPoint)point;
- (void)touchView:(OGMusicPlayerScreenTouchView *)touchView endedAtPoint:(CGPoint)point;
- (void)touchViewCancelled:(OGMusicPlayerScreenTouchView *)touchView;
@end

@interface OGMusicPlayerScreenTouchView : UIView
@property (nonatomic, assign) id<OGMusicPlayerScreenTouchViewDelegate> delegate;
@end

@implementation OGMusicPlayerScreenTouchView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)__unused event
{
    [_delegate touchView:self beganAtPoint:[[touches anyObject] locationInView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)__unused event
{
    [_delegate touchView:self movedToPoint:[[touches anyObject] locationInView:self]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)__unused event
{
    [_delegate touchView:self endedAtPoint:[[touches anyObject] locationInView:self]];
}

- (void)touchesCancelled:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event
{
    [_delegate touchViewCancelled:self];
}

@end

@interface OGMusicPlayerScreenCell : UITableViewCell
{
    UIImageView *_rowBackgroundView;
    UIImageView *_rowSelectedBackgroundView;
    UIView *_highlightView;
    UIImageView *_iconView;
    UILabel *_rowTitleLabel;
    UILabel *_durationLabel;
    OGMusicPlayerScreenAppearance *_appearance;
}
- (void)setAppearance:(OGMusicPlayerScreenAppearance *)appearance icon:(UIImage *)icon rowImage:(UIImage *)rowImage;
- (void)setRow:(OGMusicPlayerScreenRow *)row;
@end

@implementation OGMusicPlayerScreenCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _rowBackgroundView = [[UIImageView alloc] init];
        self.backgroundView = _rowBackgroundView;

        UIView *selectedBackground = [[UIView alloc] init];
        selectedBackground.backgroundColor = [UIColor clearColor];
        _highlightView = [[UIView alloc] init];
        _highlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [selectedBackground addSubview:_highlightView];
        _rowSelectedBackgroundView = [[UIImageView alloc] init];
        _rowSelectedBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [selectedBackground addSubview:_rowSelectedBackgroundView];
        self.selectedBackgroundView = selectedBackground;

        _iconView = [[UIImageView alloc] init];
        [self.contentView addSubview:_iconView];

        _rowTitleLabel = [[UILabel alloc] init];
        _rowTitleLabel.backgroundColor = [UIColor clearColor];
        _rowTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_rowTitleLabel];

        _durationLabel = [[UILabel alloc] init];
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_durationLabel];
    }
    return self;
}

- (void)setAppearance:(OGMusicPlayerScreenAppearance *)appearance icon:(UIImage *)icon rowImage:(UIImage *)rowImage
{
    _appearance = appearance;
    _rowBackgroundView.image = rowImage;
    _rowSelectedBackgroundView.image = rowImage;
    _highlightView.backgroundColor = appearance.rowHighlightColor;
    _iconView.image = icon;
    _rowTitleLabel.font = appearance.rowTitleFont;
    _rowTitleLabel.textColor = appearance.rowTitleColor;
    _rowTitleLabel.highlightedTextColor = appearance.rowTitleColor;
    _durationLabel.font = appearance.rowDurationFont;
    _durationLabel.textColor = appearance.rowDurationColor;
    _durationLabel.highlightedTextColor = appearance.rowDurationColor;
    [self setNeedsLayout];
}

- (void)setRow:(OGMusicPlayerScreenRow *)row
{
    _rowTitleLabel.text = row.title;
    _durationLabel.text = row.durationText;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.bounds.size;
    UIEdgeInsets iconOutsets = [_appearance.rowIconStyle symmetricOutsets];
    CGSize iconSize = _iconView.image.size;
    _iconView.frame = CGRectMake(_appearance.rowIconOrigin.x - iconOutsets.left, _appearance.rowIconOrigin.y - iconOutsets.top, iconSize.width, iconSize.height);
    _rowTitleLabel.frame = CGRectMake(_appearance.rowTitleLeftInset, _appearance.rowTitleTopInset, MAX(0.0f, size.width - _appearance.rowTitleLeftInset - _appearance.rowTitleRightInset), _appearance.rowTitleHeight);
    CGFloat durationCenter = size.width - _appearance.rowDurationCenterRightInset;
    _durationLabel.frame = CGRectMake(OGPixelRound(durationCenter - _appearance.rowDurationWidth / 2.0f), _appearance.rowDurationTopInset, _appearance.rowDurationWidth, _appearance.rowDurationHeight);
}

@end

@interface OGMusicPlayerScreenView () <UITableViewDataSource, UITableViewDelegate, OGMusicPlayerScreenTouchViewDelegate>
{
    OGTheme *_theme;
    OGMusicPlayerScreenAppearance *_appearance;

    UIView *_statusBarBackgroundView;
    UIImageView *_backgroundView;
    CGSize _backgroundSize;
    UILabel *_titleLabel;
    UIButton *_backButton;
    UIEdgeInsets _backButtonOutsets;
    CGFloat _backButtonWidth;

    UIImageView *_displayView;
    CGSize _displaySize;
    UILabel *_trackTitleLabel;
    UILabel *_trackSubtitleLabel;
    UIView *_progressBorderView;
    UIView *_progressFillView;
    UIView *_progressKnobView;
    OGMusicPlayerScreenTouchView *_progressTouchView;
    CGFloat _progress;
    bool _knobVisible;

    UIImageView *_playlistBackgroundView;
    UIView *_playlistClipView;
    UITableView *_tableView;
    UIImageView *_playlistOverlayView;
    CGSize _playlistSize;
    UIImage *_rowImage;
    UIImage *_rowIcon;

    UIButton *_previousButton;
    UIButton *_playPauseButton;
    UIButton *_nextButton;
    UIButton *_repeatButton;
    UIButton *_orderButton;

    MPVolumeView *_volumeView;
    UIImageView *_volumeLowView;
    UIImageView *_volumeHighView;
}
@end

@implementation OGMusicPlayerScreenView

- (instancetype)initWithFrame:(CGRect)frame theme:(OGTheme *)theme
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = theme;
        _appearance = theme.musicPlayerScreenAppearance;
        _controlsEnabled = true;
        _paused = true;
        self.backgroundColor = _appearance.statusBarBackgroundColor;

        _statusBarBackgroundView = [[UIView alloc] init];
        _statusBarBackgroundView.backgroundColor = _appearance.statusBarBackgroundColor;
        [self addSubview:_statusBarBackgroundView];

        _backgroundView = [[UIImageView alloc] init];
        [self addSubview:_backgroundView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = _appearance.titleFont;
        _titleLabel.textColor = _appearance.titleColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];

        _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _backButton.exclusiveTouch = true;
        _backButton.titleLabel.font = _appearance.backButtonFont;
        [_backButton setTitleColor:_appearance.backButtonTitleColor forState:UIControlStateNormal];
        [_backButton addTarget:self action:@selector(backButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_backButton];

        _displayView = [[UIImageView alloc] init];
        _displayView.userInteractionEnabled = true;
        [self addSubview:_displayView];

        _trackTitleLabel = [[UILabel alloc] init];
        _trackTitleLabel.backgroundColor = [UIColor clearColor];
        _trackTitleLabel.font = _appearance.displayTitleFont;
        _trackTitleLabel.textColor = _appearance.displayTitleColor;
        _trackTitleLabel.textAlignment = NSTextAlignmentCenter;
        _trackTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_displayView addSubview:_trackTitleLabel];

        _trackSubtitleLabel = [[UILabel alloc] init];
        _trackSubtitleLabel.backgroundColor = [UIColor clearColor];
        _trackSubtitleLabel.font = _appearance.displaySubtitleFont;
        _trackSubtitleLabel.textColor = _appearance.displaySubtitleColor;
        _trackSubtitleLabel.textAlignment = NSTextAlignmentCenter;
        _trackSubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_displayView addSubview:_trackSubtitleLabel];

        _progressBorderView = [[UIView alloc] init];
        _progressBorderView.backgroundColor = [UIColor clearColor];
        _progressBorderView.layer.borderColor = _appearance.progressBorderColor.CGColor;
        _progressBorderView.layer.borderWidth = _appearance.progressBorderWidth;
        _progressBorderView.userInteractionEnabled = false;
        [_displayView addSubview:_progressBorderView];

        _progressFillView = [[UIView alloc] init];
        _progressFillView.backgroundColor = _appearance.progressFillColor;
        _progressFillView.userInteractionEnabled = false;
        [_displayView addSubview:_progressFillView];

        _progressKnobView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _appearance.progressKnobSize, _appearance.progressKnobSize)];
        _progressKnobView.backgroundColor = _appearance.progressKnobColor;
        _progressKnobView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
        _progressKnobView.userInteractionEnabled = false;
        _progressKnobView.hidden = true;
        [_displayView addSubview:_progressKnobView];

        _progressTouchView = [[OGMusicPlayerScreenTouchView alloc] init];
        _progressTouchView.delegate = self;
        [_displayView addSubview:_progressTouchView];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(displayLongPressed:)];
        [_displayView addGestureRecognizer:longPress];

        _playlistBackgroundView = [[UIImageView alloc] init];
        [self addSubview:_playlistBackgroundView];

        _playlistClipView = [[UIView alloc] init];
        _playlistClipView.backgroundColor = [UIColor clearColor];
        _playlistClipView.clipsToBounds = true;
        _playlistClipView.layer.cornerRadius = _appearance.playlistCornerRadius;
        [self addSubview:_playlistClipView];

        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.rowHeight = _appearance.rowHeight;
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.scrollsToTop = false;
        [_playlistClipView addSubview:_tableView];

        _playlistOverlayView = [[UIImageView alloc] init];
        _playlistOverlayView.userInteractionEnabled = false;
        [self addSubview:_playlistOverlayView];

        _rowIcon = [self glyphImageNamed:_appearance.rowIconName style:_appearance.rowIconStyle];

        _previousButton = [self transportButtonWithLarge:false glyph:[self glyphImageNamed:_appearance.rewindIconName style:_appearance.rewindGlyphStyle] offset:_appearance.rewindGlyphOffset action:@selector(previousButtonPressed)];
        _playPauseButton = [self transportButtonWithLarge:true glyph:nil offset:CGPointZero action:@selector(playPauseButtonPressed)];
        _nextButton = [self transportButtonWithLarge:false glyph:[self glyphImageNamed:_appearance.forwardIconName style:_appearance.forwardGlyphStyle] offset:_appearance.forwardGlyphOffset action:@selector(nextButtonPressed)];

        _repeatButton = [self modeButtonWithAction:@selector(repeatButtonPressed)];
        _orderButton = [self modeButtonWithAction:@selector(orderButtonPressed)];

        _volumeLowView = [[UIImageView alloc] initWithImage:[self glyphImageNamed:_appearance.volumeLowIconName style:_appearance.volumeGlyphStyle]];
        [self addSubview:_volumeLowView];
        _volumeHighView = [[UIImageView alloc] initWithImage:[self glyphImageNamed:_appearance.volumeHighIconName style:_appearance.volumeGlyphStyle]];
        [self addSubview:_volumeHighView];

        _volumeView = [[MPVolumeView alloc] init];
        SEL routeButtonSelector = NSSelectorFromString(@"setShowsRouteButton:");
        if ([_volumeView respondsToSelector:routeButtonSelector])
        {
            void (*setShowsRouteButton)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[_volumeView methodForSelector:routeButtonSelector];
            if (setShowsRouteButton != NULL)
                setShowsRouteButton(_volumeView, routeButtonSelector, NO);
        }
        [self applyVolumeAppearance];
        [self addSubview:_volumeView];

        [self updatePlayPauseGlyph];
        [self updateModeButtons];
    }
    return self;
}

#pragma mark - Rendering

- (UIImage *)glyphImageNamed:(NSString *)name style:(OGMusicPlayerScreenGlyphStyle *)style
{
    return [self glyphImageNamed:name style:style opticalSize:0.0f];
}

- (UIImage *)glyphImageNamed:(NSString *)name style:(OGMusicPlayerScreenGlyphStyle *)style opticalSize:(CGFloat)opticalSize
{
    UIImage *glyphTemplate = [_theme.assets imageNamed:name inDirectory:_appearance.resourceDirectory];
    if (glyphTemplate == nil)
        return nil;
    if (opticalSize > 0.0f)
        glyphTemplate = [_theme.surfaceRenderer glyphImageWithTemplate:glyphTemplate opticalSize:opticalSize];
    return [_theme.surfaceRenderer iconImageWithTemplate:glyphTemplate gradientColors:style.colors locations:style.locations shadows:style.shadows outsets:[style symmetricOutsets]];
}

- (UIImage *)imageWithStyle:(OGSurfaceStyle *)style bodySize:(CGSize)bodySize outsets:(UIEdgeInsets)outsets
{
    if (bodySize.width < 1.0f || bodySize.height < 1.0f)
        return nil;
    return [_theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(bodySize.width + outsets.left + outsets.right, bodySize.height + outsets.top + outsets.bottom) bodyFrame:CGRectMake(outsets.left, outsets.top, bodySize.width, bodySize.height)];
}

- (UIButton *)transportButtonWithLarge:(bool)large glyph:(UIImage *)glyph offset:(CGPoint)offset action:(SEL)action
{
    CGFloat diameter = large ? _appearance.largeButtonDiameter : _appearance.smallButtonDiameter;
    OGSurfaceStyle *style = large ? _appearance.largeButtonSurfaceStyle : _appearance.smallButtonSurfaceStyle;
    OGSurfaceStyle *pressedStyle = large ? _appearance.largeButtonPressedSurfaceStyle : _appearance.smallButtonPressedSurfaceStyle;
    CGSize size = CGSizeMake(diameter, diameter);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.exclusiveTouch = true;
    button.adjustsImageWhenHighlighted = false;
    button.adjustsImageWhenDisabled = false;
    [button setBackgroundImage:[self imageWithStyle:style bodySize:size outsets:UIEdgeInsetsZero] forState:UIControlStateNormal];
    [button setBackgroundImage:[self imageWithStyle:pressedStyle bodySize:size outsets:UIEdgeInsetsZero] forState:UIControlStateHighlighted];
    [button setImage:glyph forState:UIControlStateNormal];
    [self setGlyphOffset:offset forButton:button];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
    return button;
}

- (UIButton *)modeButtonWithAction:(SEL)action
{
    CGFloat diameter = _appearance.modeButtonDiameter;
    CGFloat inset = MAX(0.0f, (_appearance.modeButtonTouchSize - diameter) / 2.0f);
    UIEdgeInsets outsets = UIEdgeInsetsMake(inset, inset, inset, inset);
    CGSize size = CGSizeMake(diameter, diameter);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.exclusiveTouch = true;
    button.adjustsImageWhenHighlighted = false;
    [button setBackgroundImage:[self imageWithStyle:_appearance.modeButtonSurfaceStyle bodySize:size outsets:outsets] forState:UIControlStateNormal];
    [button setBackgroundImage:[self imageWithStyle:_appearance.modeButtonPressedSurfaceStyle bodySize:size outsets:outsets] forState:UIControlStateHighlighted];
    [self setGlyphOffset:_appearance.modeGlyphOffset forButton:button];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
    return button;
}

- (void)setGlyphOffset:(CGPoint)offset forButton:(UIButton *)button
{
    button.imageEdgeInsets = UIEdgeInsetsMake(offset.y * 2.0f, offset.x * 2.0f, 0.0f, 0.0f);
}

- (void)applyVolumeAppearance
{
    if (![_volumeView respondsToSelector:NSSelectorFromString(@"setMinimumVolumeSliderImage:forState:")])
        return;

    CGSize trackSize = CGSizeMake(1.0f, _appearance.volumeTrackHeight);
    UIEdgeInsets minimumCaps = [_appearance.volumeMinimumTrackSurfaceStyle horizontalCapInsets];
    UIEdgeInsets maximumCaps = [_appearance.volumeMaximumTrackSurfaceStyle horizontalCapInsets];
    UIImage *minimumTrack = [self imageWithStyle:_appearance.volumeMinimumTrackSurfaceStyle bodySize:CGSizeMake(minimumCaps.left + minimumCaps.right + trackSize.width, trackSize.height) outsets:UIEdgeInsetsZero];
    UIImage *maximumTrack = [self imageWithStyle:_appearance.volumeMaximumTrackSurfaceStyle bodySize:CGSizeMake(maximumCaps.left + maximumCaps.right + trackSize.width, trackSize.height) outsets:UIEdgeInsetsZero];
    minimumTrack = [minimumTrack resizableImageWithCapInsets:minimumCaps];
    maximumTrack = [maximumTrack resizableImageWithCapInsets:maximumCaps];

    UIEdgeInsets thumbShadow = [_appearance.volumeThumbSurfaceStyle dropShadowOutsets];
    CGFloat thumbOutset = MAX(MAX(thumbShadow.top, thumbShadow.bottom), MAX(thumbShadow.left, thumbShadow.right));
    UIImage *thumb = [self imageWithStyle:_appearance.volumeThumbSurfaceStyle bodySize:CGSizeMake(_appearance.volumeThumbDiameter, _appearance.volumeThumbDiameter) outsets:UIEdgeInsetsMake(thumbOutset, thumbOutset, thumbOutset, thumbOutset)];

    OGMusicPlayerSetVolumeViewImage(_volumeView, @"setMinimumVolumeSliderImage:forState:", minimumTrack);
    OGMusicPlayerSetVolumeViewImage(_volumeView, @"setMaximumVolumeSliderImage:forState:", maximumTrack);
    OGMusicPlayerSetVolumeViewImage(_volumeView, @"setVolumeThumbImage:forState:", thumb);
}

#pragma mark - State

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    _titleLabel.text = title;
}

- (void)setBackTitle:(NSString *)backTitle
{
    _backTitle = [backTitle copy];
    [_backButton setTitle:backTitle forState:UIControlStateNormal];
    _backButtonWidth = 0.0f;
    [self setNeedsLayout];
}

- (void)setTrackTitle:(NSString *)trackTitle
{
    _trackTitle = [trackTitle copy];
    _trackTitleLabel.text = trackTitle;
}

- (void)setTrackSubtitle:(NSString *)trackSubtitle
{
    _trackSubtitle = [trackSubtitle copy];
    _trackSubtitleLabel.text = trackSubtitle;
}

- (void)setRows:(NSArray *)rows
{
    _rows = [rows copy];
    [_tableView reloadData];
}

- (void)setPaused:(bool)paused
{
    if (_paused == paused)
        return;
    _paused = paused;
    [self updatePlayPauseGlyph];
}

- (void)setControlsEnabled:(bool)controlsEnabled
{
    if (_controlsEnabled == controlsEnabled)
        return;
    _controlsEnabled = controlsEnabled;
    _playPauseButton.enabled = controlsEnabled;
    _playPauseButton.alpha = controlsEnabled ? 1.0f : _appearance.disabledControlAlpha;
    _progressTouchView.userInteractionEnabled = controlsEnabled;
    if (!controlsEnabled && _scrubbing)
        [self cancelScrubbing];
}

- (void)setOrder:(OGMusicPlayerScreenOrder)order
{
    if (_order == order)
        return;
    _order = order;
    [self updateModeButtons];
}

- (void)setRepeat:(OGMusicPlayerScreenRepeat)repeat
{
    if (_repeat == repeat)
        return;
    _repeat = repeat;
    [self updateModeButtons];
}

- (UIView *)displayView
{
    return _displayView;
}

- (void)updatePlayPauseGlyph
{
    NSString *name = _paused ? _appearance.playIconName : _appearance.pauseIconName;
    [_playPauseButton setImage:[self glyphImageNamed:name style:_appearance.playPauseGlyphStyle] forState:UIControlStateNormal];
    [self setGlyphOffset:_paused ? _appearance.playGlyphOffset : _appearance.pauseGlyphOffset forButton:_playPauseButton];
}

- (void)updateModeButtons
{
    NSString *repeatName = _repeat == OGMusicPlayerScreenRepeatOne ? _appearance.repeatOneIconName : _appearance.repeatIconName;
    OGMusicPlayerScreenGlyphStyle *repeatStyle = _repeat == OGMusicPlayerScreenRepeatNone ? _appearance.repeatGlyphStyle : _appearance.modeSelectedGlyphStyle;
    [_repeatButton setImage:[self glyphImageNamed:repeatName style:repeatStyle opticalSize:_appearance.modeGlyphOpticalSize] forState:UIControlStateNormal];

    NSString *orderName = _order == OGMusicPlayerScreenOrderReversed ? _appearance.reverseIconName : _appearance.shuffleIconName;
    OGMusicPlayerScreenGlyphStyle *orderStyle = _order == OGMusicPlayerScreenOrderNormal ? _appearance.orderGlyphStyle : _appearance.modeSelectedGlyphStyle;
    [_orderButton setImage:[self glyphImageNamed:orderName style:orderStyle opticalSize:_appearance.modeGlyphOpticalSize] forState:UIControlStateNormal];
}

- (void)setProgress:(CGFloat)progress knobVisible:(bool)knobVisible
{
    if (_scrubbing)
        return;
    _progress = MAX(0.0f, MIN(1.0f, progress));
    _knobVisible = knobVisible;
    [self layoutProgress];
}

- (void)scrollToRowAtIndex:(NSUInteger)index animated:(bool)animated
{
    if (index >= _rows.count)
        return;
    [_tableView layoutIfNeeded];
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)index inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:animated];
}

#pragma mark - Scrubbing

- (CGRect)progressInnerFrame
{
    CGRect frame = CGRectInset(_progressBorderView.frame, _appearance.progressBorderWidth, _appearance.progressBorderWidth);
    return CGRectMake(frame.origin.x, frame.origin.y, MAX(0.0f, frame.size.width), MAX(0.0f, frame.size.height));
}

- (CGFloat)progressForTouchPoint:(CGPoint)point
{
    CGRect inner = [self progressInnerFrame];
    CGPoint location = [_progressTouchView convertPoint:point toView:_displayView];
    if (inner.size.width < FLT_EPSILON)
        return 0.0f;
    return MAX(0.0f, MIN(1.0f, (location.x - inner.origin.x) / inner.size.width));
}

- (void)dealloc
{
    _progressTouchView.delegate = nil;
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
}

- (void)touchView:(OGMusicPlayerScreenTouchView *)__unused touchView beganAtPoint:(CGPoint)point
{
    [self beginScrubbingAtPoint:point];
}

- (void)touchView:(OGMusicPlayerScreenTouchView *)__unused touchView movedToPoint:(CGPoint)point
{
    [self continueScrubbingAtPoint:point];
}

- (void)touchView:(OGMusicPlayerScreenTouchView *)__unused touchView endedAtPoint:(CGPoint)point
{
    [self finishScrubbingAtPoint:point];
}

- (void)touchViewCancelled:(OGMusicPlayerScreenTouchView *)__unused touchView
{
    [self cancelScrubbing];
}

- (void)beginScrubbingAtPoint:(CGPoint)point
{
    if (!_controlsEnabled)
        return;
    _scrubbing = true;
    if (_scrubbingBegan != nil)
        _scrubbingBegan();
    _progress = [self progressForTouchPoint:point];
    _knobVisible = true;
    [self layoutProgress];
}

- (void)continueScrubbingAtPoint:(CGPoint)point
{
    if (!_scrubbing)
        return;
    _progress = [self progressForTouchPoint:point];
    [self layoutProgress];
}

- (void)finishScrubbingAtPoint:(CGPoint)point
{
    if (!_scrubbing)
        return;
    _progress = [self progressForTouchPoint:point];
    _scrubbing = false;
    [self layoutProgress];
    if (_scrubbingFinished != nil)
        _scrubbingFinished(_progress);
}

- (void)cancelScrubbing
{
    if (!_scrubbing)
        return;
    _scrubbing = false;
    if (_scrubbingCancelled != nil)
        _scrubbingCancelled();
}

#pragma mark - Actions

- (void)backButtonPressed
{
    if (_backPressed != nil)
        _backPressed();
}

- (void)playPauseButtonPressed
{
    if (_playPausePressed != nil)
        _playPausePressed();
}

- (void)previousButtonPressed
{
    if (_previousPressed != nil)
        _previousPressed();
}

- (void)nextButtonPressed
{
    if (_nextPressed != nil)
        _nextPressed();
}

- (void)repeatButtonPressed
{
    if (_repeatPressed != nil)
        _repeatPressed();
}

- (void)orderButtonPressed
{
    if (_orderPressed != nil)
        _orderPressed();
}

- (void)displayLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan && !_scrubbing && _actionsRequested != nil)
        _actionsRequested();
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OGMusicPlayerScreenCell *cell = (OGMusicPlayerScreenCell *)[tableView dequeueReusableCellWithIdentifier:OGMusicPlayerScreenCellIdentifier];
    if (cell == nil)
        cell = [[OGMusicPlayerScreenCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:OGMusicPlayerScreenCellIdentifier];
    [cell setAppearance:_appearance icon:_rowIcon rowImage:_rowImage];
    [cell setRow:_rows[(NSUInteger)indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)__unused tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    cell.backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    if (_rowSelected != nil)
        _rowSelected((NSUInteger)indexPath.row);
}

#pragma mark - Layout

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(_contentInsets, contentInsets))
        return;
    _contentInsets = contentInsets;
    [self setNeedsLayout];
}

- (void)layoutProgress
{
    CGRect inner = [self progressInnerFrame];
    CGFloat knobX = inner.origin.x + OGPixelRound(inner.size.width * _progress);
    _progressFillView.frame = CGRectMake(inner.origin.x, inner.origin.y, MAX(0.0f, knobX - inner.origin.x), inner.size.height);
    _progressKnobView.center = CGPointMake(knobX, CGRectGetMidY(inner));
    _progressKnobView.hidden = !_knobVisible;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.bounds.size;
    CGFloat top = _contentInsets.top;
    CGFloat bottom = size.height - _contentInsets.bottom;
    CGFloat width = size.width;

    _statusBarBackgroundView.frame = CGRectMake(0.0f, 0.0f, width, top);

    CGSize backgroundSize = CGSizeMake(width, MAX(0.0f, size.height - top));
    _backgroundView.frame = CGRectMake(0.0f, top, backgroundSize.width, backgroundSize.height);
    if (!CGSizeEqualToSize(_backgroundSize, backgroundSize))
    {
        _backgroundSize = backgroundSize;
        _backgroundView.image = [self imageWithStyle:_appearance.backgroundSurfaceStyle bodySize:backgroundSize outsets:UIEdgeInsetsZero];
    }

    _titleLabel.frame = CGRectMake(_appearance.titleHorizontalOffset, top + _appearance.titleTopInset, width, _appearance.titleHeight);

    if (_backButtonWidth < FLT_EPSILON)
    {
        CGFloat titleWidth = [_backButton.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, _appearance.backButtonHeight)].width;
        _backButtonWidth = MAX(_appearance.backButtonMinimumWidth, OGPixelCeil(titleWidth) + _appearance.backButtonHorizontalPadding * 2.0f);
        _backButtonOutsets = [_appearance.backButtonSurfaceStyle dropShadowOutsets];
        CGSize bodySize = CGSizeMake(_backButtonWidth, _appearance.backButtonHeight);
        [_backButton setBackgroundImage:[self imageWithStyle:_appearance.backButtonSurfaceStyle bodySize:bodySize outsets:_backButtonOutsets] forState:UIControlStateNormal];
        [_backButton setBackgroundImage:[self imageWithStyle:_appearance.backButtonPressedSurfaceStyle bodySize:bodySize outsets:_backButtonOutsets] forState:UIControlStateHighlighted];
        _backButton.titleEdgeInsets = _backButtonOutsets;
    }
    _backButton.frame = CGRectMake(_appearance.backButtonOrigin.x - _backButtonOutsets.left, top + _appearance.backButtonOrigin.y - _backButtonOutsets.top, _backButtonWidth + _backButtonOutsets.left + _backButtonOutsets.right, _appearance.backButtonHeight + _backButtonOutsets.top + _backButtonOutsets.bottom);

    CGSize displaySize = CGSizeMake(MAX(0.0f, width - _appearance.displayLeftInset - _appearance.displayRightInset), _appearance.displayHeight);
    _displayView.frame = CGRectMake(_appearance.displayLeftInset, top + _appearance.displayTopInset, displaySize.width, displaySize.height);
    if (!CGSizeEqualToSize(_displaySize, displaySize))
    {
        _displaySize = displaySize;
        _displayView.image = [self imageWithStyle:_appearance.displaySurfaceStyle bodySize:displaySize outsets:UIEdgeInsetsZero];
    }
    CGFloat textWidth = MAX(0.0f, displaySize.width - _appearance.displayTextHorizontalInset * 2.0f);
    _trackTitleLabel.frame = CGRectMake(_appearance.displayTextHorizontalInset + _appearance.displayTitleHorizontalOffset, _appearance.displayTitleTopInset, textWidth, _appearance.displayTitleHeight);
    _trackSubtitleLabel.frame = CGRectMake(_appearance.displayTextHorizontalInset + _appearance.displaySubtitleHorizontalOffset, _appearance.displaySubtitleTopInset, textWidth, _appearance.displaySubtitleHeight);
    _progressBorderView.frame = CGRectMake(_appearance.progressLeftInset, _appearance.progressTopInset, MAX(0.0f, displaySize.width - _appearance.progressLeftInset - _appearance.progressRightInset), _appearance.progressHeight);
    _progressTouchView.frame = CGRectInset(_progressBorderView.frame, -_appearance.progressTouchOutset, -_appearance.progressTouchOutset);
    [self layoutProgress];

    CGFloat largeTop = bottom - _appearance.transportBottomInset;
    CGFloat centerX = OGPixelRound(width / 2.0f + _appearance.transportCenterOffset);
    CGFloat largeDiameter = _appearance.largeButtonDiameter;
    CGFloat smallDiameter = _appearance.smallButtonDiameter;
    _playPauseButton.frame = CGRectMake(centerX - largeDiameter / 2.0f, largeTop, largeDiameter, largeDiameter);
    CGFloat smallTop = largeTop + _appearance.smallButtonTopOffset;
    _previousButton.frame = CGRectMake(centerX - _appearance.smallButtonCenterSpacing - smallDiameter / 2.0f, smallTop, smallDiameter, smallDiameter);
    _nextButton.frame = CGRectMake(centerX + _appearance.smallButtonCenterSpacing - smallDiameter / 2.0f, smallTop, smallDiameter, smallDiameter);

    CGFloat playlistTop = top + _appearance.playlistTopInset;
    CGSize playlistSize = CGSizeMake(MAX(0.0f, width - _appearance.playlistHorizontalInset * 2.0f), MAX(0.0f, largeTop - _appearance.playlistBottomSpacing - playlistTop));
    CGRect playlistFrame = CGRectMake(_appearance.playlistHorizontalInset, playlistTop, playlistSize.width, playlistSize.height);
    _playlistBackgroundView.frame = playlistFrame;
    _playlistClipView.frame = playlistFrame;
    _playlistOverlayView.frame = playlistFrame;
    _tableView.frame = _playlistClipView.bounds;
    if (!CGSizeEqualToSize(_playlistSize, playlistSize))
    {
        bool rowWidthChanged = ABS(_playlistSize.width - playlistSize.width) > FLT_EPSILON;
        _playlistSize = playlistSize;
        _playlistBackgroundView.image = [self imageWithStyle:_appearance.playlistSurfaceStyle bodySize:playlistSize outsets:UIEdgeInsetsZero];
        _playlistOverlayView.image = [self imageWithStyle:_appearance.playlistOverlaySurfaceStyle bodySize:playlistSize outsets:UIEdgeInsetsZero];
        if (rowWidthChanged)
        {
            _rowImage = [self imageWithStyle:_appearance.rowSurfaceStyle bodySize:CGSizeMake(playlistSize.width, _appearance.rowHeight) outsets:UIEdgeInsetsZero];
            [_tableView reloadData];
        }
    }

    CGFloat touchSize = _appearance.modeButtonTouchSize;
    CGFloat modeDiameter = _appearance.modeButtonDiameter;
    CGFloat modeCenterY = bottom - _appearance.modeButtonBottomInset + modeDiameter / 2.0f;
    CGFloat repeatCenterX = _appearance.modeButtonSideInset + modeDiameter / 2.0f;
    CGFloat orderCenterX = width - _appearance.modeButtonSideInset - modeDiameter / 2.0f;
    _repeatButton.frame = CGRectMake(repeatCenterX - touchSize / 2.0f, modeCenterY - touchSize / 2.0f, touchSize, touchSize);
    _orderButton.frame = CGRectMake(orderCenterX - touchSize / 2.0f, modeCenterY - touchSize / 2.0f, touchSize, touchSize);

    CGFloat volumeCenterY = bottom - _appearance.volumeCenterBottomInset;
    UIEdgeInsets volumeOutsets = [_appearance.volumeGlyphStyle symmetricOutsets];
    CGSize lowSize = _volumeLowView.image.size;
    CGSize highSize = _volumeHighView.image.size;
    _volumeLowView.frame = CGRectMake(_appearance.volumeLowIconLeftInset - volumeOutsets.left, OGPixelRound(volumeCenterY + _appearance.volumeIconVerticalOffset - lowSize.height / 2.0f), lowSize.width, lowSize.height);
    _volumeHighView.frame = CGRectMake(width - _appearance.volumeHighIconRightInset - (highSize.width - volumeOutsets.right), OGPixelRound(volumeCenterY + _appearance.volumeIconVerticalOffset - highSize.height / 2.0f), highSize.width, highSize.height);
    CGFloat volumeWidth = MAX(0.0f, width - _appearance.volumeTrackLeftInset - _appearance.volumeTrackRightInset);
    CGFloat volumeHeight = [_volumeView sizeThatFits:CGSizeMake(volumeWidth, CGFLOAT_MAX)].height;
    CGRect volumeFrame = CGRectMake(_appearance.volumeTrackLeftInset, OGPixelRound(volumeCenterY - volumeHeight / 2.0f), volumeWidth, volumeHeight);
    _volumeView.frame = volumeFrame;
    [self alignVolumeTrackToFrame:CGRectMake(_appearance.volumeTrackLeftInset, volumeCenterY + _appearance.volumeTrackVerticalOffset - _appearance.volumeTrackHeight / 2.0f, volumeWidth, _appearance.volumeTrackHeight)];
}

- (UISlider *)volumeSlider
{
    for (UIView *subview in _volumeView.subviews)
    {
        if ([subview isKindOfClass:[UISlider class]])
            return (UISlider *)subview;
    }
    return nil;
}

- (void)alignVolumeTrackToFrame:(CGRect)targetFrame
{
    [_volumeView layoutIfNeeded];
    UISlider *slider = [self volumeSlider];
    if (slider == nil || slider.bounds.size.width < 1.0f)
        return;

    CGRect track = [slider convertRect:[slider trackRectForBounds:slider.bounds] toView:self];
    if (track.size.width < 1.0f)
        return;

    CGRect frame = _volumeView.frame;
    frame.origin.x += OGPixelRound(CGRectGetMinX(targetFrame) - CGRectGetMinX(track));
    frame.size.width += OGPixelRound(targetFrame.size.width - track.size.width);
    frame.origin.y += OGPixelRound(CGRectGetMidY(targetFrame) - CGRectGetMidY(track));
    _volumeView.frame = frame;
}

@end
