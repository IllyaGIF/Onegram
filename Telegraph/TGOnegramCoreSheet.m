#import "TGOnegramCoreSheet.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramCore/OGOnegramCore.h"
#import "../OnegramCore/VLESSSubscriptions.h"
#import "../legacy/TelegraphKit/TGCommon.h"

#import "TGAppDelegate.h"
#import "TGPresentation.h"
#import "TGTelegramNetworking.h"
#import "TGOnegramCoreHealthMonitor.h"
#import "TGOnegramCorePowerButton.h"
#import "TGVLESSServersController.h"

static const OGOnegramCoreMode TGOnegramCoreSheetModes[] = { OGOnegramCoreModeWebSocket, OGOnegramCoreModeWARP, OGOnegramCoreModeVLESS };
static const NSUInteger TGOnegramCoreSheetModeCount = 3;
static const CGFloat TGOnegramCoreSheetInset = 20.0f;

static NSString *TGOnegramCoreSheetModeTitle(OGOnegramCoreMode mode)
{
    switch (mode)
    {
        case OGOnegramCoreModeWebSocket:
            return TGLocalized(@"OnegramCore.Mode.WebSocket");
        case OGOnegramCoreModeWARP:
            return TGLocalized(@"OnegramCore.Mode.WARP");
        case OGOnegramCoreModeVLESS:
            return TGLocalized(@"OnegramCore.Mode.VLESS");
        default:
            return @"";
    }
}

static NSString *TGOnegramCoreSheetRate(double bytesPerSecond)
{
    if (bytesPerSecond < 1024.0)
        return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.BytesPerSecond"), (int)(bytesPerSecond + 0.5)];
    if (bytesPerSecond < 1024.0 * 1024.0)
        return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.KilobytesPerSecond"), bytesPerSecond / 1024.0];
    return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.MegabytesPerSecond"), bytesPerSecond / (1024.0 * 1024.0)];
}

static CGFloat TGOnegramCoreSheetTextHeight(NSString *text, UIFont *font, CGFloat width)
{
    if (text.length == 0)
        return 0.0f;
    return CGCeil(OGPlatformTextSize(text, font, CGSizeMake(width, CGFLOAT_MAX), UILineBreakModeWordWrap).height);
}

@interface TGOnegramCoreModeSelector : UIView
{
    UIView *_highlightView;
    NSArray *_labels;
    UIColor *_textColor;
    UIColor *_selectedTextColor;
}

@property (nonatomic, readonly) NSUInteger selectedIndex;
@property (nonatomic, copy) void (^selected)(NSUInteger index);

- (instancetype)initWithTitles:(NSArray *)titles pallete:(TGPresentationPallete *)pallete;
- (void)setSelectedIndex:(NSUInteger)selectedIndex animated:(bool)animated;

@end

@implementation TGOnegramCoreModeSelector

- (instancetype)initWithTitles:(NSArray *)titles pallete:(TGPresentationPallete *)pallete
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = pallete.menuSelectionColor;
        self.layer.cornerRadius = 12.0f;
        _textColor = pallete.menuTextColor;
        _selectedTextColor = pallete.accentContrastColor;

        _highlightView = [[UIView alloc] init];
        _highlightView.backgroundColor = pallete.menuAccentColor;
        _highlightView.layer.cornerRadius = 9.0f;
        [self addSubview:_highlightView];

        NSMutableArray *labels = [[NSMutableArray alloc] init];
        for (NSString *title in titles)
        {
            UILabel *label = [[UILabel alloc] init];
            label.backgroundColor = [UIColor clearColor];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = TGMediumSystemFontOfSize(15.0f);
            label.text = title;
            label.isAccessibilityElement = true;
            label.accessibilityTraits = UIAccessibilityTraitButton;
            [self addSubview:label];
            [labels addObject:label];
        }
        _labels = labels;

        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
        [self updateLabelColors];
    }
    return self;
}

- (void)updateLabelColors
{
    [_labels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger index, __unused BOOL *stop)
    {
        label.textColor = index == _selectedIndex ? _selectedTextColor : _textColor;
        label.accessibilityTraits = index == _selectedIndex ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    }];
}

- (CGRect)segmentFrameAtIndex:(NSUInteger)index
{
    CGFloat inset = 3.0f;
    CGFloat width = (self.bounds.size.width - inset * 2.0f) / MAX(1, _labels.count);
    return CGRectMake(inset + CGFloor(width * index), inset, CGFloor(width), self.bounds.size.height - inset * 2.0f);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_labels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger index, __unused BOOL *stop)
    {
        label.frame = [self segmentFrameAtIndex:index];
    }];
    _highlightView.frame = [self segmentFrameAtIndex:_selectedIndex];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex animated:(bool)animated
{
    if (selectedIndex >= _labels.count)
        return;
    _selectedIndex = selectedIndex;
    void (^changes)(void) = ^
    {
        _highlightView.frame = [self segmentFrameAtIndex:_selectedIndex];
    };
    if (animated)
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
    else
        changes();
    [self updateLabelColors];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;
    CGPoint location = [recognizer locationInView:self];
    for (NSUInteger index = 0; index < _labels.count; index++)
    {
        if (CGRectContainsPoint(CGRectInset([self segmentFrameAtIndex:index], -2.0f, -6.0f), location))
        {
            if (_selected != nil)
                _selected(index);
            return;
        }
    }
}

@end

@interface TGOnegramCoreSheet ()
{
    TGPresentationPallete *_pallete;
    UIView *_grabberView;
    UILabel *_titleLabel;
    TGModernButton *_closeButton;
    TGOnegramCorePowerButton *_powerButton;
    UILabel *_stateLabel;
    UILabel *_hintLabel;
    UIView *_healthView;
    UIView *_healthDot;
    UILabel *_healthLabel;
    UILabel *_trafficLabel;
    UILabel *_modeHeaderLabel;
    TGOnegramCoreModeSelector *_modeSelector;
    TGModernButton *_serversButton;
    UILabel *_serversTitleLabel;
    UILabel *_serversValueLabel;
    TGOnegramCoreHealthMonitor *_healthMonitor;
    OGOnegramCoreMode _monitoredMode;
    OGOnegramCoreState _monitoredState;
    CGFloat _availableHeight;
}

@end

@implementation TGOnegramCoreSheet

+ (void)presentFromViewController:(UIViewController *)viewController
{
    static __weak TGOnegramCoreSheet *currentSheet = nil;
    if (currentSheet != nil)
        return;
    TGOnegramCoreSheet *sheet = [[TGOnegramCoreSheet alloc] initWithFrame:CGRectZero];
    currentSheet = sheet;
    [TGOnegramCardOverlay presentCardView:sheet placement:TGOnegramCardPlacementBottom parentController:viewController];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _pallete = [TGPresentation current].pallete;
        self.backgroundColor = _pallete.menuBackgroundColor;

        _grabberView = [[UIView alloc] init];
        _grabberView.backgroundColor = [_pallete.menuSecondaryTextColor colorWithAlphaComponent:0.35f];
        _grabberView.layer.cornerRadius = 2.5f;
        [self addSubview:_grabberView];

        _titleLabel = [self labelWithFont:TGSemiboldSystemFontOfSize(17.0f) color:_pallete.menuTextColor];
        _titleLabel.text = TGLocalized(@"OnegramCore.Title");
        [self addSubview:_titleLabel];

        _closeButton = [[TGModernButton alloc] init];
        [_closeButton setImage:[self closeImage] forState:UIControlStateNormal];
        _closeButton.accessibilityLabel = TGLocalized(@"Common.Close");
        [_closeButton addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeButton];

        _powerButton = [[TGOnegramCorePowerButton alloc] init];
        _powerButton.accentColor = _pallete.menuAccentColor;
        _powerButton.contrastColor = _pallete.accentContrastColor;
        _powerButton.surfaceColor = _pallete.menuSelectionColor;
        _powerButton.trackColor = _pallete.menuSeparatorColor;
        _powerButton.secondaryColor = _pallete.menuSecondaryTextColor;
        _powerButton.destructiveColor = _pallete.menuDestructiveColor;
        _powerButton.accessibilityLabel = TGLocalized(@"OnegramCore.Title");
        [_powerButton addTarget:self action:@selector(powerPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_powerButton];

        _stateLabel = [self labelWithFont:TGMediumSystemFontOfSize(22.0f) color:_pallete.menuTextColor];
        [self addSubview:_stateLabel];

        _hintLabel = [self labelWithFont:TGSystemFontOfSize(15.0f) color:_pallete.menuSecondaryTextColor];
        [self addSubview:_hintLabel];

        _healthView = [[UIView alloc] init];
        _healthView.backgroundColor = _pallete.menuSelectionColor;
        _healthView.layer.cornerRadius = 15.0f;
        [self addSubview:_healthView];

        _healthDot = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 10.0f, 10.0f)];
        _healthDot.layer.cornerRadius = 5.0f;
        [_healthView addSubview:_healthDot];

        _healthLabel = [self labelWithFont:TGMediumSystemFontOfSize(14.0f) color:_pallete.menuTextColor];
        _healthLabel.numberOfLines = 1;
        [_healthView addSubview:_healthLabel];

        _trafficLabel = [self labelWithFont:TGSystemFontOfSize(13.0f) color:_pallete.menuSecondaryTextColor];
        _trafficLabel.numberOfLines = 1;
        [self addSubview:_trafficLabel];

        _modeHeaderLabel = [self labelWithFont:TGSystemFontOfSize(13.0f) color:_pallete.menuSecondaryTextColor];
        _modeHeaderLabel.textAlignment = NSTextAlignmentLeft;
        _modeHeaderLabel.numberOfLines = 1;
        _modeHeaderLabel.text = [TGLocalized(@"OnegramCore.ModeHeader") uppercaseString];
        [self addSubview:_modeHeaderLabel];

        NSMutableArray *titles = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < TGOnegramCoreSheetModeCount; index++)
            [titles addObject:TGOnegramCoreSheetModeTitle(TGOnegramCoreSheetModes[index])];
        _modeSelector = [[TGOnegramCoreModeSelector alloc] initWithTitles:titles pallete:_pallete];
        __weak TGOnegramCoreSheet *weakSelf = self;
        _modeSelector.selected = ^(NSUInteger index)
        {
            __strong TGOnegramCoreSheet *strongSelf = weakSelf;
            [strongSelf selectMode:TGOnegramCoreSheetModes[index]];
        };
        [self addSubview:_modeSelector];


        _serversButton = [[TGModernButton alloc] init];
        _serversButton.backgroundColor = _pallete.menuSelectionColor;
        _serversButton.highlightBackgroundColor = [_pallete.menuSeparatorColor colorWithAlphaComponent:0.6f];
        _serversButton.layer.cornerRadius = 12.0f;
        _serversButton.clipsToBounds = true;
        [_serversButton addTarget:self action:@selector(serversPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_serversButton];

        _serversTitleLabel = [self labelWithFont:TGSystemFontOfSize(16.0f) color:_pallete.menuTextColor];
        _serversTitleLabel.textAlignment = NSTextAlignmentLeft;
        _serversTitleLabel.numberOfLines = 1;
        _serversTitleLabel.text = TGLocalized(@"OnegramCore.VLESSServers");
        [_serversButton addSubview:_serversTitleLabel];

        _serversValueLabel = [self labelWithFont:TGSystemFontOfSize(16.0f) color:_pallete.menuSecondaryTextColor];
        _serversValueLabel.textAlignment = NSTextAlignmentRight;
        _serversValueLabel.numberOfLines = 1;
        [_serversButton addSubview:_serversValueLabel];


        _healthMonitor = [[TGOnegramCoreHealthMonitor alloc] init];
        _healthMonitor.updated = ^
        {
            __strong TGOnegramCoreSheet *strongSelf = weakSelf;
            [strongSelf updateHealth];
        };

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(coreChanged:) name:OGOnegramCoreDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(coreChanged:) name:VLESSSubscriptionsDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

        OGOnegramCore *core = [OGOnegramCore sharedCore];
        _monitoredMode = core.mode;
        _monitoredState = core.state;
        [self updateStateAnimated:false];
        [self updateHealth];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_healthMonitor stop];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (UIImage *)closeImage
{
    CGSize size = CGSizeMake(30.0f, 30.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, _pallete.menuSelectionColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextSetStrokeColorWithColor(context, _pallete.menuSecondaryTextColor.CGColor);
    CGContextSetLineWidth(context, 2.0f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, 10.5f, 10.5f);
    CGContextAddLineToPoint(context, 19.5f, 19.5f);
    CGContextMoveToPoint(context, 19.5f, 10.5f);
    CGContextAddLineToPoint(context, 10.5f, 19.5f);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (OGOnegramCoreMode)displayedMode
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    OGOnegramCoreMode mode = core.mode;
    return mode != OGOnegramCoreModeNone ? mode : core.preferredMode;
}

- (TGOnegramCorePowerState)powerState
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    if (core.mode == OGOnegramCoreModeNone)
        return TGOnegramCorePowerStateOff;
    switch (core.state)
    {
        case OGOnegramCoreStateConnected:
            return TGOnegramCorePowerStateConnected;
        case OGOnegramCoreStateFailed:
            return TGOnegramCorePowerStateFailed;
        default:
            return TGOnegramCorePowerStateConnecting;
    }
}

- (void)updateStateAnimated:(bool)animated
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    OGOnegramCoreMode mode = [self displayedMode];
    TGOnegramCorePowerState powerState = [self powerState];
    [_powerButton setPowerState:powerState animated:animated];

    switch (powerState)
    {
        case TGOnegramCorePowerStateOff:
            _stateLabel.text = TGLocalized(@"OnegramCore.Sheet.Off");
            _stateLabel.textColor = _pallete.menuTextColor;
            _hintLabel.text = nil;
            break;
        case TGOnegramCorePowerStateConnecting:
            _stateLabel.text = TGLocalized(@"OnegramCore.Connecting");
            _stateLabel.textColor = _pallete.menuTextColor;
            _hintLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.HintConnecting"), TGOnegramCoreSheetModeTitle(mode)];
            break;
        case TGOnegramCorePowerStateConnected:
            _stateLabel.text = TGLocalized(@"OnegramCore.Connected");
            _stateLabel.textColor = _pallete.menuAccentColor;
            _hintLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.HintConnected"), TGOnegramCoreSheetModeTitle(mode)];
            break;
        case TGOnegramCorePowerStateFailed:
        {
            _stateLabel.text = TGLocalized(@"OnegramCore.Failed");
            _stateLabel.textColor = _pallete.menuDestructiveColor;
            NSString *reason = core.lastError.localizedDescription;
            _hintLabel.text = reason;
            break;
        }
    }

    NSUInteger selectedIndex = 0;
    for (NSUInteger index = 0; index < TGOnegramCoreSheetModeCount; index++)
    {
        if (TGOnegramCoreSheetModes[index] == mode)
            selectedIndex = index;
    }
    [_modeSelector setSelectedIndex:selectedIndex animated:animated];
    _serversButton.hidden = mode != OGOnegramCoreModeVLESS;
    _serversValueLabel.text = [[VLESSSubscriptions shared] allLines].count == 0 ? TGLocalized(@"OnegramCore.Sheet.NoServers") : [TGVLESSServersController selectedServerTitle];
    _powerButton.accessibilityValue = _stateLabel.text;
}

- (void)updateHealth
{
    UIColor *dotColor = _pallete.menuSecondaryTextColor;
    NSString *text = nil;
    NSInteger ping = _healthMonitor.pingMilliseconds;
    switch (_healthMonitor.health)
    {
        case TGOnegramCoreHealthGood:
            dotColor = UIColorRGB(0x34c759);
            text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.HealthGood"), (int)ping];
            break;
        case TGOnegramCoreHealthFair:
            dotColor = UIColorRGB(0xff9f0a);
            text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.HealthFair"), (int)ping];
            break;
        case TGOnegramCoreHealthPoor:
            dotColor = UIColorRGB(0xff3b30);
            text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.HealthPoor"), (int)ping];
            break;
        case TGOnegramCoreHealthNoResponse:
            dotColor = UIColorRGB(0xff3b30);
            text = TGLocalized(@"OnegramCore.Sheet.HealthNoResponse");
            break;
        default:
            text = TGLocalized(@"OnegramCore.Sheet.HealthChecking");
            break;
    }
    _healthDot.backgroundColor = dotColor;
    _healthLabel.text = text;
    _healthView.accessibilityLabel = text;
    _trafficLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.Sheet.Traffic"), TGOnegramCoreSheetRate(_healthMonitor.incomingBytesPerSecond), TGOnegramCoreSheetRate(_healthMonitor.outgoingBytesPerSecond)];
    [self setNeedsLayout];
}

- (CGFloat)powerSideForWidth:(CGFloat)width
{
    CGFloat side = MIN(216.0f, CGFloor(width * 0.6f));
    if (_availableHeight <= 0.0f)
        return side;
    CGFloat overflow = [self layoutForWidth:width powerSide:side apply:false] - _availableHeight;
    if (overflow <= 0.0f)
        return side;
    return MAX(MIN(side, 96.0f), side - CGCeil(overflow));
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(bool)apply
{
    return [self layoutForWidth:width powerSide:[self powerSideForWidth:width] apply:apply];
}

- (CGFloat)layoutForWidth:(CGFloat)width powerSide:(CGFloat)powerSide apply:(bool)apply
{
    CGFloat contentWidth = width - TGOnegramCoreSheetInset * 2.0f;
    if (apply)
    {
        _grabberView.frame = CGRectMake(CGFloor((width - 36.0f) / 2.0f), 7.0f, 36.0f, 5.0f);
        _closeButton.frame = CGRectMake(width - 14.0f - 30.0f, 16.0f, 30.0f, 30.0f);
        _titleLabel.frame = CGRectMake(60.0f, 20.0f, width - 120.0f, 22.0f);
    }
    CGFloat y = 56.0f;

    if (apply)
        _powerButton.frame = CGRectMake(CGFloor((width - powerSide) / 2.0f), y, powerSide, powerSide);
    y += powerSide + 12.0f;

    CGFloat stateHeight = TGOnegramCoreSheetTextHeight(_stateLabel.text, _stateLabel.font, contentWidth);
    if (apply)
        _stateLabel.frame = CGRectMake(TGOnegramCoreSheetInset, y, contentWidth, stateHeight);
    y += stateHeight + 6.0f;

    CGFloat hintHeight = _hintLabel.text.length == 0 ? 0.0f : TGOnegramCoreSheetTextHeight(_hintLabel.text, _hintLabel.font, contentWidth);
    if (apply)
        _hintLabel.frame = CGRectMake(TGOnegramCoreSheetInset, y, contentWidth, hintHeight);
    y += hintHeight == 0.0f ? 8.0f : hintHeight + 14.0f;

    CGSize healthTextSize = OGPlatformTextSize(_healthLabel.text, _healthLabel.font, CGSizeMake(contentWidth - 40.0f, 20.0f), UILineBreakModeTailTruncation);
    CGFloat healthWidth = MIN(contentWidth, CGCeil(healthTextSize.width) + 14.0f + 10.0f + 8.0f + 14.0f);
    if (apply)
    {
        _healthView.frame = CGRectMake(CGFloor((width - healthWidth) / 2.0f), y, healthWidth, 30.0f);
        _healthDot.frame = CGRectMake(14.0f, 10.0f, 10.0f, 10.0f);
        _healthLabel.frame = CGRectMake(14.0f + 10.0f + 8.0f, 5.0f, healthWidth - 14.0f - 10.0f - 8.0f - 14.0f, 20.0f);
    }
    y += 30.0f + 6.0f;

    if (apply)
        _trafficLabel.frame = CGRectMake(TGOnegramCoreSheetInset, y, contentWidth, 18.0f);
    y += 18.0f + 22.0f;

    if (apply)
        _modeHeaderLabel.frame = CGRectMake(TGOnegramCoreSheetInset + 4.0f, y, contentWidth - 4.0f, 18.0f);
    y += 18.0f + 6.0f;

    if (apply)
        _modeSelector.frame = CGRectMake(TGOnegramCoreSheetInset, y, contentWidth, 42.0f);
    y += 42.0f;

    if (!_serversButton.hidden)
    {
        y += 12.0f;
        if (apply)
        {
            _serversButton.frame = CGRectMake(TGOnegramCoreSheetInset, y, contentWidth, 46.0f);
            CGFloat titleWidth = MIN(contentWidth * 0.5f, CGCeil(OGPlatformTextSize(_serversTitleLabel.text, _serversTitleLabel.font, CGSizeMake(contentWidth, 22.0f), UILineBreakModeTailTruncation).width));
            _serversTitleLabel.frame = CGRectMake(14.0f, 12.0f, titleWidth, 22.0f);
            _serversValueLabel.frame = CGRectMake(14.0f + titleWidth + 10.0f, 12.0f, contentWidth - 14.0f - titleWidth - 10.0f - 14.0f, 22.0f);
        }
        y += 46.0f;
    }

    y += 24.0f;
    return y;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
    return [self heightForWidth:width availableHeight:0.0f];
}

- (CGFloat)heightForWidth:(CGFloat)width availableHeight:(CGFloat)availableHeight
{
    _availableHeight = availableHeight;
    return [self layoutForWidth:width apply:false];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self layoutForWidth:self.bounds.size.width apply:true];
}

- (void)cardWillAppear
{
    [_healthMonitor start];
}

- (void)cardDidDisappear
{
    [_healthMonitor stop];
}

- (void)applicationDidBecomeActive:(NSNotification *)__unused notification
{
    [_powerButton resumeAnimations];
}

- (void)coreChanged:(NSNotification *)__unused notification
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    if (core.mode != _monitoredMode || (core.state == OGOnegramCoreStateConnected && _monitoredState != OGOnegramCoreStateConnected))
        [_healthMonitor restart];
    _monitoredMode = core.mode;
    _monitoredState = core.state;
    [self updateStateAnimated:true];
    [self setNeedsLayout];
    [self.overlay setNeedsCardLayoutAnimated:true];
}

- (bool)vlessNeedsServers:(OGOnegramCoreMode)mode
{
    return mode == OGOnegramCoreModeVLESS && [[VLESSSubscriptions shared] allLines].count == 0;
}

- (void)powerPressed
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    switch ([self powerState])
    {
        case TGOnegramCorePowerStateOff:
        {
            OGOnegramCoreMode mode = core.preferredMode;
            if ([self vlessNeedsServers:mode])
                [self presentServersEnablingVLESS:true];
            else
                [[TGTelegramNetworking instance] setOnegramCoreMode:mode];
            break;
        }
        case TGOnegramCorePowerStateFailed:
            [core reconnect];
            break;
        default:
            [[TGTelegramNetworking instance] setOnegramCoreMode:OGOnegramCoreModeNone];
            break;
    }
}

- (void)selectMode:(OGOnegramCoreMode)mode
{
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    bool enabled = core.mode != OGOnegramCoreModeNone;
    if ([self vlessNeedsServers:mode])
    {
        [core setPreferredMode:mode];
        [self presentServersEnablingVLESS:enabled];
        return;
    }
    if (enabled)
    {
        if (core.mode != mode)
            [[TGTelegramNetworking instance] setOnegramCoreMode:mode];
    }
    else
    {
        [core setPreferredMode:mode];
    }
}

- (void)presentControllerAfterDismiss:(UIViewController *)controller
{
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
    if (TGIsPad())
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    UIViewController *presenter = self.overlay.parentController;
    while (presenter.presentedViewController != nil)
        presenter = presenter.presentedViewController;
    [self.overlay dismissAnimated:true completion:^
    {
        TGPresentViewController(presenter, navigationController, true, nil);
    }];
}

- (void)presentServersEnablingVLESS:(bool)enablesVLESS
{
    TGVLESSServersController *controller = [[TGVLESSServersController alloc] initModal:true];
    controller.enablesVLESSAfterAddingServers = enablesVLESS;
    [self presentControllerAfterDismiss:controller];
}

- (void)serversPressed
{
    [self presentServersEnablingVLESS:false];
}

- (void)closePressed
{
    [self.overlay dismissAnimated:true completion:nil];
}

@end
