#import "TGCallButtonsView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCallSession.h"

#import "TGCallButton.h"
#import "TGCallAcceptButton.h"
#import "TGCallMessageButton.h"
#import "TGCallVideoCapturer.h"

const CGFloat TGCallButtonsSpacing = 28.0f;

static void TGCallAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextMoveToPoint(context, minX + radius, minY);
    CGContextAddArcToPoint(context, maxX, minY, maxX, maxY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, minX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, minY, radius);
    CGContextAddArcToPoint(context, minX, minY, maxX, minY, radius);
    CGContextClosePath(context);
}

static UIImage *TGCallCameraIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize size = CGSizeMake(34.0f, 22.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        TGCallAddRoundedRect(context, CGRectMake(0.0f, 0.0f, 23.0f, 22.0f), 4.5f);
        CGContextFillPath(context);
        CGContextMoveToPoint(context, 25.0f, 8.0f);
        CGContextAddLineToPoint(context, 34.0f, 2.0f);
        CGContextAddLineToPoint(context, 34.0f, 20.0f);
        CGContextAddLineToPoint(context, 25.0f, 14.0f);
        CGContextClosePath(context);
        CGContextFillPath(context);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

static void TGCallAddArrowArc(CGContextRef context, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle)
{
    CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
    CGContextStrokePath(context);
    CGPoint tip = CGPointMake(center.x + radius * cos(endAngle), center.y + radius * sin(endAngle));
    CGFloat tangent = endAngle + (CGFloat)M_PI_2;
    CGFloat length = 4.5f;
    CGFloat spread = 0.55f;
    CGContextMoveToPoint(context, tip.x + length * cos(tangent + (CGFloat)M_PI - spread), tip.y + length * sin(tangent + (CGFloat)M_PI - spread));
    CGContextAddLineToPoint(context, tip.x + 1.0f * cos(tangent), tip.y + 1.0f * sin(tangent));
    CGContextAddLineToPoint(context, tip.x + length * cos(tangent + (CGFloat)M_PI + spread), tip.y + length * sin(tangent + (CGFloat)M_PI + spread));
    CGContextClosePath(context);
    CGContextFillPath(context);
}

static UIImage *TGCallFlipCameraIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize size = CGSizeMake(34.0f, 26.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(context, 2.0f);
        CGContextSetLineCap(context, kCGLineCapRound);
        TGCallAddRoundedRect(context, CGRectMake(1.0f, 5.0f, 32.0f, 20.0f), 4.0f);
        CGContextStrokePath(context);
        TGCallAddRoundedRect(context, CGRectMake(11.0f, 1.0f, 12.0f, 5.0f), 1.5f);
        CGContextFillPath(context);
        CGPoint center = CGPointMake(17.0f, 15.0f);
        TGCallAddArrowArc(context, center, 6.0f, (CGFloat)(M_PI * 1.05), (CGFloat)(M_PI * 1.85));
        TGCallAddArrowArc(context, center, 6.0f, (CGFloat)(M_PI * 0.05), (CGFloat)(M_PI * 0.85));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@interface TGCallButtonsView ()
{
    TGCallButton *_declineButton;
    TGCallAcceptButton *_callButton;
    
    TGCallMessageButton *_messageButton;
    TGCallButton *_cancelButton;
    TGCallButton *_muteButton;
    TGCallButton *_speakerButton;
    TGCallButton *_cameraButton;
    TGCallButton *_flipCameraButton;
    
    TGCallState _currentState;
    bool _twoButtons;
}
@end

@implementation TGCallButtonsView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _declineButton = [[TGCallButton alloc] init];
        _declineButton.backColor = [TGCallAcceptButton redColor];
        [_declineButton setImage:[UIImage imageNamed:@"CallPhoneIcon"] forState:UIControlStateNormal];
        [_declineButton addTarget:self action:@selector(declineButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_declineButton];
        
        _callButton = [[TGCallAcceptButton alloc] init];
        [_callButton addTarget:self action:@selector(callButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_callButton];
        
        _declineButton.hidden = true;

        _cancelButton = [[TGCallButton alloc] init];
        _cancelButton.hasBorder = true;
        [_cancelButton setImage:[UIImage imageNamed:@"CallCancelIcon"] forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_cancelButton];
        
        _muteButton = [[TGCallButton alloc] init];
        _muteButton.hasBorder = true;
        [_muteButton setImage:[UIImage imageNamed:@"CallMuteIcon"] forState:UIControlStateNormal];
        [_muteButton addTarget:self action:@selector(muteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_muteButton];
        
        _speakerButton = [[TGCallButton alloc] init];
        _speakerButton.hasBorder = true;
        [_speakerButton setImage:[UIImage imageNamed:@"CallSpeakerIcon"] forState:UIControlStateNormal];
        [_speakerButton addTarget:self action:@selector(speakerButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_speakerButton];
        
        _cameraButton = [[TGCallButton alloc] init];
        _cameraButton.hasBorder = true;
        _cameraButton.hidden = true;
        [_cameraButton setImage:TGCallCameraIcon() forState:UIControlStateNormal];
        [_cameraButton addTarget:self action:@selector(cameraButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_cameraButton];
        
        _flipCameraButton = [[TGCallButton alloc] init];
        _flipCameraButton.hasBorder = true;
        _flipCameraButton.hidden = true;
        [_flipCameraButton setImage:TGCallFlipCameraIcon() forState:UIControlStateNormal];
        [_flipCameraButton addTarget:self action:@selector(flipCameraButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_flipCameraButton];
        
        _messageButton = [[TGCallMessageButton alloc] init];
        [_messageButton setImage:[UIImage imageNamed:@"CallQuickMessageIcon"] forState:UIControlStateNormal];
        [_messageButton addTarget:self action:@selector(messageButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_messageButton setTitle:TGLocalized(@"Call.Message") forState:UIControlStateNormal];
        [self addSubview:_messageButton];
        
        [_callButton setState:TGCallAcceptButtonStateEnd];
        
        if (TGScreenSize().height > 480)
        {
            [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
            [_callButton setTitle:TGLocalized(@"Call.Accept") forState:UIControlStateNormal];
            [_declineButton setTitle:TGLocalized(@"Call.Decline") forState:UIControlStateNormal];
        }
    }
    return self;
}

- (UIButton *)speakerButton
{
    return _speakerButton;
}

- (void)setState:(TGCallSessionState *)state
{
    bool maybeNeedsLayout = false;
    
    TGCallState previousState = _currentState;
    if (_currentState != state.state)
    {
        _currentState = state.state;
        maybeNeedsLayout = true;
    }
    
    switch (state.state)
    {
        case TGCallStateReady:
        case TGCallStateHandshake:
            _declineButton.hidden = false;
            _callButton.hidden = false;
            [_callButton setState:TGCallAcceptButtonStateAccept];
            
            _messageButton.hidden = true;
            _cancelButton.hidden = true;
            _muteButton.hidden = true;
            _speakerButton.hidden = true;
            break;
            
        case TGCallStateAccepting:
        case TGCallStateOngoing:
        {
            _messageButton.hidden = true;
            _cancelButton.hidden = true;
            
            _muteButton.hidden = false;
            _speakerButton.hidden = false;
            
            if (previousState == TGCallStateReady)
            {
                _muteButton.alpha = 0.0f;
                _speakerButton.alpha = 0.0f;
                
                [UIView animateWithDuration:0.2 animations:^
                {
                    _muteButton.alpha = 1.0f;
                    _speakerButton.alpha = 1.0f;
                    _declineButton.alpha = 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    _declineButton.hidden = true;
                    _declineButton.alpha = 1.0f;
                }];
                
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                    [_callButton setState:TGCallAcceptButtonStateEnd];
                    [self layoutSubviews];
                } completion:nil];
                
                maybeNeedsLayout = false;
            }
            else
            {
                _declineButton.hidden = true;
                _callButton.hidden = false;
                [_callButton setState:TGCallAcceptButtonStateEnd];
                
                _muteButton.hidden = false;
                _speakerButton.hidden = false;
            }
        }
            break;
         
        case TGCallStateEnding:
        case TGCallStateEnded:
        case TGCallStateMissed:
            if (previousState == TGCallStateOngoing)
            {
                _muteButton.hidden = false;
                _speakerButton.hidden = false;
                _cancelButton.hidden = true;
                _messageButton.hidden = true;
                
                [_callButton setState:TGCallAcceptButtonStateEnd];
            }
            else if (previousState == TGCallStateReady || previousState == TGCallStateHandshake)
            {
                _twoButtons = true;
            }
            break;
            
        case TGCallStateBusy:
        case TGCallStateNoAnswer:
            if (previousState == TGCallStateWaiting || previousState == TGCallStateWaitingReceived)
            {
                _twoButtons = true;
                
                _cancelButton.hidden = false;
                _cancelButton.alpha = 0.0f;
                
                _messageButton.hidden = false;
                _messageButton.alpha = 0.0f;
                
                [UIView animateWithDuration:0.2 animations:^
                {
                    _muteButton.alpha = 0.0f;
                    _speakerButton.alpha = 0.0f;
                    _cancelButton.alpha = 1.0f;
                    _messageButton.alpha = 1.0f;
                } completion:^(__unused BOOL finished)
                {
                    _messageButton.hidden = false;
                    _cancelButton.hidden = false;
                    _muteButton.hidden = true;
                    _speakerButton.hidden = true;
                    _muteButton.alpha = 1.0f;
                    _speakerButton.alpha = 1.0f;
                }];
                
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                     [_callButton setState:TGCallAcceptButtonStateAccept];
                     [self layoutSubviews];
                } completion:nil];
                
                maybeNeedsLayout = false;
            }
            break;
            
        case TGCallStateRequesting:
        case TGCallStateWaiting:
        case TGCallStateWaitingReceived:
            if (previousState == TGCallStateBusy || previousState == TGCallStateNoAnswer)
            {
                _twoButtons = false;
                
                _muteButton.alpha = 0.0f;
                _speakerButton.alpha = 0.0f;
                _muteButton.hidden = false;
                _speakerButton.hidden = false;
                
                [UIView animateWithDuration:0.2 animations:^
                {
                    _muteButton.alpha = 1.0f;
                    _speakerButton.alpha = 1.0f;
                    _cancelButton.alpha = 0.0f;
                    _messageButton.alpha = 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    if (finished)
                    {
                        _cancelButton.hidden = true;
                        _messageButton.hidden = true;
                    }
                    
                    _cancelButton.alpha = 1.0f;
                    _messageButton.alpha = 1.0f;
                }];
                
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                    [_callButton setState:TGCallAcceptButtonStateEnd];
                    [self layoutSubviews];
                } completion:nil];
                
                maybeNeedsLayout = false;
            }
            else
            {
                _messageButton.hidden = true;
                _cancelButton.hidden = true;
                _declineButton.hidden = true;
                _callButton.hidden = false;
                [_callButton setState:TGCallAcceptButtonStateEnd];
                
                _muteButton.hidden = false;
                _speakerButton.hidden = false;
            }
            break;
        
        default:
            break;
    }
    
    if (maybeNeedsLayout)
        [self setNeedsLayout];
    
    NSString *currentTitle = [_callButton titleForState:UIControlStateNormal];
    if (currentTitle.length > 0)
    {
        NSString *title = TGLocalized(@"Call.Accept");
        if (state.state == TGCallStateBusy || state.state == TGCallStateNoAnswer)
            title = TGLocalized(@"Call.CallAgain");
        
        if (![currentTitle isEqualToString:title])
            [_callButton setTitle:title forState:UIControlStateNormal];
    }
    
    _muteButton.selected = state.mute;
    
    bool videoControlsAllowed = state.canSendVideo && (state.state == TGCallStateRequesting || state.state == TGCallStateWaiting || state.state == TGCallStateWaitingReceived || state.state == TGCallStateAccepting || state.state == TGCallStateOngoing);
    _cameraButton.hidden = !videoControlsAllowed;
    _cameraButton.selected = state.localVideoEnabled;
    _flipCameraButton.hidden = !videoControlsAllowed || !state.localVideoEnabled || ![TGCallVideoCapturer hasFrontAndBackCameras];
    
    bool hasBluetoothRoute = false;
    for (TGAudioRoute *route in state.audioRoutes)
    {
        if (route.isBluetooth)
        {
            hasBluetoothRoute = true;
            break;
        }
    }
    
    if (hasBluetoothRoute)
    {
        [_speakerButton setImage:[UIImage imageNamed:@"CallBluetoothIcon"] forState:UIControlStateNormal];
        _speakerButton.selected = false;
    }
    else
    {
        [_speakerButton setImage:[UIImage imageNamed:@"CallSpeakerIcon"] forState:UIControlStateNormal];
        _speakerButton.selected = state.speaker;
        
        if (TGIsPad())
            _speakerButton.hidden = true;
    }
}

- (void)setBackground:(NSObject<TGPasscodeBackground> *)background
{
    for (TGCallButton *button in self.subviews)
    {
        if (![button isKindOfClass:[TGCallButton class]] || !button.hasBorder)
            continue;
        
        [button setBackground:background];
        [button setAbsoluteOffset:CGPointMake(self.frame.origin.x + button.frame.origin.x, self.frame.origin.y + button.frame.origin.y)];
    }
}

- (void)declineButtonPressed
{
    if (self.declinePressed != nil)
        self.declinePressed();
}

- (void)callButtonPressed
{
    if (self.callPressed != nil)
        self.callPressed();
}

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)muteButtonPressed
{
    if (self.mutePressed != nil)
        self.mutePressed();
}

- (void)speakerButtonPressed
{
    if (self.speakerPressed != nil)
        self.speakerPressed();
}

- (void)cameraButtonPressed
{
    if (self.cameraPressed != nil)
        self.cameraPressed();
}

- (void)flipCameraButtonPressed
{
    if (self.flipCameraPressed != nil)
        self.flipCameraPressed();
}

- (void)messageButtonPressed
{
    if (self.messagePressed != nil)
        self.messagePressed();
}

+ (CGFloat)bottomButtonsOffset
{
    static dispatch_once_t onceToken;
    static CGFloat offset;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if ((int)screenSize.width == 320)
            if ((int)screenSize.height == 480)
                offset = 53;
            else
                offset = 63;
        else
            offset = 83;
    });
    return offset;
}

- (void)layoutSubviews
{
    CGFloat offset = _muteButton.frame.size.height + [TGCallButtonsView bottomButtonsOffset];
    
    _muteButton.frame = CGRectMake(0, offset, _muteButton.frame.size.width, _muteButton.frame.size.height);
    _cancelButton.frame = _muteButton.frame;
    _speakerButton.frame = CGRectMake(_declineButton.frame.size.width + _speakerButton.frame.size.width + 2 * TGCallButtonsSpacing, offset, _speakerButton.frame.size.width, _speakerButton.frame.size.height);
    
    _messageButton.frame = CGRectMake(floor((self.frame.size.width - _callButton.frame.size.width) / 2.0f) + 90.0f, _speakerButton.frame.origin.y - 90.0f, _speakerButton.frame.size.width, 55.0f);
    
    _cameraButton.frame = CGRectMake(_muteButton.frame.origin.x, 0.0f, _cameraButton.frame.size.width, _cameraButton.frame.size.height);
    _flipCameraButton.frame = CGRectMake(_speakerButton.frame.origin.x, 0.0f, _flipCameraButton.frame.size.width, _flipCameraButton.frame.size.height);
    
    for (TGCallButton *button in self.subviews)
    {
        if (![button isKindOfClass:[TGCallButton class]] || !button.hasBorder)
            continue;
        
        [button setAbsoluteOffset:CGPointMake(self.frame.origin.x + button.frame.origin.x, self.frame.origin.y + button.frame.origin.y)];
    }
    
    _declineButton.frame = CGRectMake(floor((self.frame.size.width - _declineButton.frame.size.width) / 2.0f) - 90.0f, offset, _declineButton.frame.size.width, _declineButton.frame.size.height);
    
    bool twoButtons = _twoButtons || _currentState == TGCallStateHandshake || _currentState == TGCallStateReady;
    if (twoButtons)
    {
        _callButton.frame = CGRectMake(floor((self.frame.size.width - _callButton.frame.size.width) / 2.0f) + 90.0f, offset, _callButton.frame.size.width, _callButton.frame.size.height);
    }
    else
    {
        _callButton.frame = CGRectMake(floor((self.frame.size.width - _callButton.frame.size.width) / 2.0f), offset, _callButton.frame.size.width, _callButton.frame.size.height);
    }
}

@end
