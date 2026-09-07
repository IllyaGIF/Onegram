#import "TGCallInfoView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCallSession.h"
#import "TGDatabase.h"

#import "TGMarqueeLabel.h"
#import "TGCallReceptionView.h"

const CGFloat TGCallInfoViewHeight = 86.0f;
const CGFloat TGCallInfoNamePadding = 25.0f;

const CGFloat TGCallInfoNormalSpacing = 9.0f;
const CGFloat TGCallInfoLargeSpacing = 11.0f;

const CGFloat TGCallInfoSmallNameFontSize = 28.0f;
const CGFloat TGCallInfoNormalNameFontSize = 36.0f;

const CGFloat TGCallInfoSmallStatusFontSize = 16.0f;
const CGFloat TGCallInfoNormalStatusFontSize = 18.0f;

@interface TGCallInfoView ()
{
    UILabel *_nameLabel;
    UILabel *_statusLabel;
    TGCallReceptionView *_receptionView;
    
    bool _legacyMode;
    bool _needsFontUpdate;

    int32_t _currentPeerId;
    NSInteger _peerRefreshAttempts;
    bool _peerRefreshScheduled;
    
    CGFloat _statusWidth;
    
    TGCallState _currentState;
    
    NSInteger _debugTapCount;
    UITapGestureRecognizer *_tapGestureRecognizer;
}
@end

@implementation TGCallInfoView

static NSString *TGCallInfoLocalizedStatus(NSString *key, NSString *fallback)
{
    NSString *value = TGLocalized(key);
    if (value.length == 0 || [value isEqualToString:key])
        return fallback;
    return value;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self != nil)
    {
        _legacyMode = iosMajorVersion() <= 8;
        
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        
        if (_legacyMode)
        {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
            
            label.backgroundColor = [UIColor clearColor];
            label.opaque = false;
            
            label.font = TGSystemFontOfSize([TGCallInfoView nameFontSize]);
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor whiteColor];
            
            label.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.85f];
            label.shadowOffset = CGSizeMake(0.0f, 1.0f);
            
            label.numberOfLines = 1;
            label.adjustsFontSizeToFitWidth = true;
            label.minimumFontSize = 18.0f;
            
            label.text = @"Name";
            label.hidden = true;
            
            label.userInteractionEnabled = true;
            
            _nameLabel = label;
        }
        else
        {
            TGMarqueeLabel *label =
            [[TGMarqueeLabel alloc] initWithFrame:CGRectZero];
            
            label.backgroundColor = [UIColor clearColor];
            label.opaque = false;
            
            label.font =
            TGLightSystemFontOfSize([TGCallInfoView nameFontSize]);
            
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor whiteColor];
            
            label.shadowColor =
            [UIColor colorWithWhite:0.0f alpha:0.65f];
            
            label.shadowOffset = CGSizeMake(0.0f, 1.0f);
            
            label.text = @"Name";
            label.hidden = true;
            
            label.scrollDuration = 15.0;
            label.fadeLength = 25.0f;
            label.trailingBuffer = 60.0f;
            label.animationDelay = 2.0;
            
            label.userInteractionEnabled = true;
            
            _nameLabel = label;
        }
        
        [self addSubview:_nameLabel];
        
        _tapGestureRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(nameTapped)];
        
        [_nameLabel addGestureRecognizer:_tapGestureRecognizer];
        
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.opaque = false;
        
        _statusLabel.font =
        TGSystemFontOfSize([TGCallInfoView statusFontSize]);
        
        _statusLabel.textColor = [UIColor whiteColor];
        
        _statusLabel.shadowColor =
        [UIColor colorWithWhite:0.0f alpha:0.85f];
        
        _statusLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 1;
        
        _statusLabel.hidden = true;
        _statusLabel.text = @"Status";
        
        [self addSubview:_statusLabel];
        
        _receptionView = [[TGCallReceptionView alloc] initWithFrame:CGRectZero];
        _receptionView.alpha = 0.0f;
        
        [self addSubview:_receptionView];
    }
    
    return self;
}

- (void)nameTapped
{
    if (self.debugPressed == nil)
        return;
    
#ifdef INTERNAL_RELEASE
    
    self.debugPressed();
    
#else
    
    _debugTapCount++;
    
    if (_debugTapCount == 10)
    {
        self.debugPressed();
        _debugTapCount = 0;
    }
    
#endif
}

+ (CGFloat)spacing
{
    CGSize screenSize = TGScreenSize();
    int height = (int)screenSize.height;
    
    if (height == 736 || height == 768 || height == 1366)
        return TGCallInfoLargeSpacing;
    
    return TGCallInfoNormalSpacing;
}

+ (CGFloat)nameFontSize
{
    CGSize screenSize = TGScreenSize();
    
    if ((int)screenSize.width == 320)
        return TGCallInfoSmallNameFontSize;
    
    return TGCallInfoNormalNameFontSize;
}

+ (CGFloat)statusFontSize
{
    CGSize screenSize = TGScreenSize();
    
    if ((int)screenSize.width == 320)
        return TGCallInfoSmallStatusFontSize;
    
    return TGCallInfoNormalStatusFontSize;
}

- (CGFloat)scaledSizeForName:(NSString *)name size:(CGSize)size
{
    CGFloat baseSize = [TGCallInfoView nameFontSize];
    
    UIFont *font = _legacyMode
    ? TGSystemFontOfSize(baseSize)
    : TGLightSystemFontOfSize(baseSize);
    
    if (name.length == 0 || size.width < 1.0f)
        return baseSize;
    
    CGSize textSize = [name sizeWithFont:font];
    
    if (textSize.width <= size.width || textSize.width < 1.0f)
        return baseSize;
    
    CGFloat scale = size.width / textSize.width;
    
    if (scale < 0.65f)
        scale = 0.65f;
    
    return floor(baseSize * scale);
}

- (NSString *)displayNameForPeer:(TGUser *)peer
{
    if (peer == nil)
        return @"";

    NSString *displayName = peer.displayName;
    if (displayName.length != 0)
        return displayName;

    NSString *firstName = peer.firstName ?: @"";
    NSString *lastName = peer.lastName ?: @"";
    if (firstName.length != 0 && lastName.length != 0)
        return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    if (firstName.length != 0)
        return firstName;
    if (lastName.length != 0)
        return lastName;

    return @"";
}

- (void)applyDisplayPeer:(TGUser *)peer
{
    NSString *displayName = [self displayNameForPeer:peer];
    _nameLabel.hidden = displayName.length == 0;

    if (![displayName isEqualToString:_nameLabel.text])
    {
        _nameLabel.text = displayName;
        _needsFontUpdate = true;
        [self setNeedsLayout];

        if (displayName.length != 0)
            TGLog(@"CALL ui.name peer=%d name=%@ legacyLabel=%d", peer.uid, displayName, _legacyMode ? 1 : 0);
    }
}

- (void)schedulePeerRefreshIfNeeded
{
    if (_currentPeerId == 0 || _peerRefreshScheduled || _peerRefreshAttempts >= 12)
        return;

    _peerRefreshScheduled = true;
    [self performSelector:@selector(refreshPeerName) withObject:nil afterDelay:0.35];
}

- (void)refreshPeerName
{
    _peerRefreshScheduled = false;

    if (_currentPeerId == 0)
        return;

    TGUser *peer = [TGDatabaseInstance() loadUser:_currentPeerId];
    NSString *displayName = [self displayNameForPeer:peer];
    if (displayName.length != 0)
    {
        [self applyDisplayPeer:peer];
        return;
    }

    _peerRefreshAttempts++;
    [self schedulePeerRefreshIfNeeded];
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshPeerName) object:nil];
}

- (void)setState:(TGCallSessionState *)state duration:(NSTimeInterval)duration
{
    int32_t peerId = (int32_t)state.stateData.peerId;
    if (_currentPeerId != peerId)
    {
        _currentPeerId = peerId;
        _peerRefreshAttempts = 0;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshPeerName) object:nil];
        _peerRefreshScheduled = false;
    }

    TGUser *displayPeer = state.peer;
    if ((displayPeer == nil || [self displayNameForPeer:displayPeer].length == 0) && peerId != 0)
    {
        TGUser *databasePeer = [TGDatabaseInstance() loadUser:peerId];
        if (databasePeer != nil)
            displayPeer = databasePeer;
    }

    [self applyDisplayPeer:displayPeer];
    if (_nameLabel.hidden)
        [self schedulePeerRefreshIfNeeded];
    
    [_receptionView setSignalBars:state.signalBars];
    
    _statusLabel.hidden = false;
    
    CGFloat previousStatusWidth = _statusWidth;
    
    TGCallState previousState = _currentState;
    _currentState = state.state;
    
    switch (_currentState)
    {
        case TGCallStateRequesting:
        {
            _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusRequesting", @"Contacting...");
            _statusWidth = 0.0f;
        }
            break;
            
        case TGCallStateWaiting:
        {
            _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusWaiting", @"Waiting...");
            _statusWidth = 0.0f;
        }
            break;
            
        case TGCallStateWaitingReceived:
        {
            _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusRinging", @"Ringing...");
            _statusWidth = 0.0f;
        }
            break;
            
        case TGCallStateHandshake:
        case TGCallStateReady:
        {
            _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusIncoming", @"Incoming call...");
            _statusWidth = 0.0f;
        }
            break;
            
        case TGCallStateAccepting:
        {
            _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusConnecting", @"Connecting...");
            _statusWidth = 0.0f;
        }
            break;
            
        case TGCallStateOngoing:
        {
            switch (state.transmissionState)
            {
                case TGCallTransmissionStateInitializing:
                {
                    _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusConnecting", @"Connecting...");
                    _statusWidth = 0.0f;
                }
                    break;
                    
                case TGCallTransmissionStateEstablished:
                {
                    NSString *durationString = nil;
                    
                    if (duration >= 60.0 * 60.0)
                    {
                        durationString =
                        [NSString stringWithFormat:@"%02d:%02d:%02d",
                         (int)(duration / 3600.0),
                         (int)(duration / 60.0) % 60,
                         (int)duration % 60];
                    }
                    else
                    {
                        durationString =
                        [NSString stringWithFormat:@"%02d:%02d",
                         (int)(duration / 60.0) % 60,
                         (int)duration % 60];
                    }
                    
                    NSString *format = TGCallInfoLocalizedStatus(@"Call.StatusOngoing", @"%@");
                    
                    if (format.length == 0)
                        format = @"%@";
                    
                    _statusLabel.text =
                    [NSString stringWithFormat:format, durationString];
                    
                    if (duration >= 60.0 * 60.0)
                    {
                        _statusWidth =
                        [self widthForStatusString:
                         [NSString stringWithFormat:format, @"00:00:00"]];
                    }
                    else
                    {
                        _statusWidth =
                        [self widthForStatusString:
                         [NSString stringWithFormat:format, @"00:00"]];
                    }
                }
                    break;
                    
                case TGCallTransmissionStateReconnecting:
                {
                    _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusConnecting", @"Connecting...");
                    _statusWidth = 0.0f;
                }
                    break;

                case TGCallTransmissionStateFailed:
                {
                    _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusFailed", @"Call failed");
                    _statusWidth =
                    [self widthForStatusString:_statusLabel.text];
                }
                    break;
                    
                default:
                    break;
            }
            
            if (state.transmissionState == TGCallTransmissionStateEstablished &&
                _receptionView.alpha < FLT_EPSILON)
            {
                [UIView animateWithDuration:0.2 animations:^
                 {
                     _receptionView.alpha = 1.0f;
                 }];
            }
        }
            break;
            
        case TGCallStateEnding:
        case TGCallStateEnded:
        case TGCallStateBusy:
        case TGCallStateNoAnswer:
        case TGCallStateMissed:
        {
            if (state.stateData.error.length > 0 ||
                state.transmissionState == TGCallTransmissionStateFailed)
            {
                _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusFailed", @"Call failed");
            }
            else if (state.state == TGCallStateBusy)
            {
                _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusBusy", @"Busy");
            }
            else if (state.state == TGCallStateNoAnswer)
            {
                _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusNoAnswer", @"No answer");
            }
            else
            {
                _statusLabel.text = TGCallInfoLocalizedStatus(@"Call.StatusEnded", @"Call ended");
            }
            
            _statusWidth = 0.0f;
            
            if (previousState != _currentState)
            {
                [UIView animateWithDuration:0.2 animations:^
                 {
                     _receptionView.alpha = 0.0f;
                 } completion:nil];
            }
        }
            break;
            
        default:
            break;
    }
    
    if (_statusLabel.text.length == 0)
        _statusLabel.text = @"Call";
    
    if (_needsFontUpdate ||
        fabs(_statusWidth - previousStatusWidth) > FLT_EPSILON)
    {
        [self setNeedsLayout];
    }
    else
    {

        [self setNeedsLayout];
    }
}

- (CGFloat)widthForStatusString:(NSString *)string
{
    if (string.length == 0)
        return 0.0f;
    
    return [string sizeWithFont:_statusLabel.font
                       forWidth:FLT_MAX
                  lineBreakMode:UILineBreakModeClip].width + 2.0f;
}

- (void)onPause
{
    if ([_nameLabel isKindOfClass:[TGMarqueeLabel class]])
        [(TGMarqueeLabel *)_nameLabel shutdownLabel];
}

- (void)onResume
{
    if ([_nameLabel isKindOfClass:[TGMarqueeLabel class]])
        [(TGMarqueeLabel *)_nameLabel restartLabel];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = self.bounds.size.width;
    
    if (width < 1.0f)
        return;
    
    CGFloat nameWidth = width - TGCallInfoNamePadding * 2.0f;
    
    if (nameWidth < 1.0f)
        nameWidth = 1.0f;
    
    if (_needsFontUpdate)
    {
        CGFloat fontSize =
        [self scaledSizeForName:_nameLabel.text
                           size:CGSizeMake(nameWidth, 100.0f)];
        
        if (_legacyMode)
            _nameLabel.font = TGSystemFontOfSize(fontSize);
        else
            _nameLabel.font = TGLightSystemFontOfSize(fontSize);
        
        _needsFontUpdate = false;
    }
    
    CGFloat nameHeight = ceil(_nameLabel.font.lineHeight + 2.0f);
    CGFloat statusHeight = ceil(_statusLabel.font.lineHeight + 2.0f);
    
    if (nameHeight < 1.0f)
        nameHeight = 36.0f;
    
    if (statusHeight < 1.0f)
        statusHeight = 20.0f;
    
    _nameLabel.frame =
    CGRectMake(TGCallInfoNamePadding,
               0.0f,
               nameWidth,
               nameHeight);
    
    CGFloat statusY =
    nameHeight + [TGCallInfoView spacing];
    
    if (_statusWidth > FLT_EPSILON)
    {
        _statusLabel.textAlignment = NSTextAlignmentLeft;
        
        _statusLabel.frame =
        CGRectMake(round((width - _statusWidth) / 2.0f) + 14.0f,
                   statusY,
                   _statusWidth,
                   statusHeight);
    }
    else
    {
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        
        _statusLabel.frame =
        CGRectMake(0.0f,
                   statusY,
                   width,
                   statusHeight);
    }
    
    CGSize qualitySize = TGCallQualityViewSize;
    
    _receptionView.frame =
    CGRectMake((width - _statusWidth - 7.0f) / 2.0f -
               qualitySize.width + 15.0f,
               floor(CGRectGetMidY(_statusLabel.frame) -
                     qualitySize.height / 2.0f) +
               1.0f + TGScreenPixel,
               qualitySize.width,
               qualitySize.height);
    
    [self bringSubviewToFront:_nameLabel];
    [self bringSubviewToFront:_statusLabel];
    [self bringSubviewToFront:_receptionView];
}

@end