#import "TGCallView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGDefaultPasscodeBackground.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageBasedPasscodeBackground.h"

#import "../submodules/LegacyComponents/LegacyComponents/UIControl+HitTestEdgeInsets.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMenuView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "TGCallInfoView.h"
#import "TGCallAvatarView.h"
#import "TGCallButtonsView.h"
#import "TGCallBackgroundView.h"
#import "TGCallIdenticonView.h"
#import "TGCallEncryptionKeyView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryZoomableScrollViewSwipeGestureRecognizer.h"

#import "TGCallSession.h"
#import "TGCallVideoView.h"
#import "TGCallVideoCapturer.h"

#include <syslog.h>

const CGFloat TGCallSwipeMinimumVelocity = 600.0f;
const CGFloat TGCallSwipeVelocityThreshold = 700.0f;
const CGFloat TGCallSwipeDistanceThreshold = 128.0f;

@interface TGCallView () <ASWatcher, UIGestureRecognizerDelegate>
{
    TGCallState _currentState;
    
    UIView *_dimView;
    UIView *_mainView;
    UIView *_wrapperView;
    UIImage *_backgroundImage;
    TGCallBackgroundView *_backgroundView;
    
    TGModernButton *_backButton;
    UILabel *_emojiLabel;
    TGCallInfoView *_infoView;
    TGCallButtonsView *_buttonsView;
    TGCallEncryptionKeyView *_keyView;
    
    bool _panning;
    TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *_panGestureRecognizer;
    
    TGMenuContainerView *_tooltipContainerView;
    NSTimer *_tooltipTimer;
    
    TGCallVideoView *_remoteVideoView;
    UIView *_localVideoContainer;
    TGCallVideoView *_localVideoView;
    TGCallVideoCapturer *_videoCapturer;
    UITapGestureRecognizer *_videoTapGestureRecognizer;
    bool _remoteVideoActive;
    bool _remoteFrameRendered;
    bool _localFrameRendered;
    bool _localVideoActive;
    bool _videoControlsHidden;
    bool _callFinished;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGCallView

@dynamic debugPressed;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        __weak TGCallView *weakSelf = self;
        
        _dimView = [[UIView alloc] init];
        _dimView.backgroundColor = [UIColor blackColor];
        _dimView.hidden = true;
        [self addSubview:_dimView];
        
        _mainView = [[UIView alloc] init];
        
        if (iosMajorVersion() < 6)
        {
            self.backgroundColor = UIColorRGB(0x244f74);
            _mainView.backgroundColor = UIColorRGB(0x244f74);
        }
        
        [self addSubview:_mainView];
        
        _backgroundView = [[TGCallBackgroundView alloc] init];
        _backgroundView.imageChanged = ^(UIImage *image)
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_backgroundImage = image;
                [strongSelf _updateBackground];
            }
        };
        [_mainView addSubview:_backgroundView];
        
        _remoteVideoView = [[TGCallVideoView alloc] init];
        _remoteVideoView.fillsBounds = true;
        _remoteVideoView.hidden = true;
        _remoteVideoView.userInteractionEnabled = false;
        _remoteVideoView.firstFrameRendered = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_remoteFrameRendered = true;
                [strongSelf _updateVideoAnimated:true];
            }
        };
        [_mainView addSubview:_remoteVideoView];
        
        _localVideoContainer = [[UIView alloc] init];
        _localVideoContainer.backgroundColor = [UIColor blackColor];
        _localVideoContainer.clipsToBounds = true;
        _localVideoContainer.hidden = true;
        _localVideoContainer.userInteractionEnabled = false;
        [_mainView addSubview:_localVideoContainer];
        
        _localVideoView = [[TGCallVideoView alloc] init];
        _localVideoView.fillsBounds = true;
        _localVideoView.userInteractionEnabled = false;
        _localVideoView.firstFrameRendered = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_localFrameRendered = true;
                [strongSelf _updateVideoAnimated:true];
            }
        };
        [_localVideoContainer addSubview:_localVideoView];
        
        _wrapperView = [[UIView alloc] init];
        [_mainView addSubview:_wrapperView];
        
        _keyView = [[TGCallEncryptionKeyView alloc] init];
        _keyView.hidden = true;
        _keyView.backPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf closeKeyView];
        };
        _keyView.emojiInitialCenter = ^CGPoint
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf->_wrapperView convertPoint:strongSelf->_emojiLabel.center toView:strongSelf->_keyView];
            
            return CGPointZero;
        };
        [_wrapperView addSubview:_keyView];
        
        _backButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _backButton.exclusiveTouch = true;
        _backButton.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -20, -5, -5);
        _backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _backButton.titleLabel.textAlignment = NSTextAlignmentLeft;
        _backButton.titleLabel.font = TGSystemFontOfSize(17);
        [_backButton setTitle:TGLocalized(@"Common.Back") forState:UIControlStateNormal];
        [_backButton setTitleColor:[UIColor whiteColor]];
        [_backButton addTarget:self action:@selector(backButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_wrapperView addSubview:_backButton];
        
        UIImageView *arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(-19, 5.5f, 13, 22)];
        arrowView.image = [UIImage imageNamed:@"NavigationBackArrow"];
        [_backButton addSubview:arrowView];
        
        _buttonsView = [[TGCallButtonsView alloc] init];
        _buttonsView.mutePressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.mutePressed != nil)
                strongSelf.mutePressed();
        };
        _buttonsView.speakerPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.speakerPressed != nil)
                strongSelf.speakerPressed();
        };
        _buttonsView.cancelPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.cancelPressed != nil)
                strongSelf.cancelPressed();
        };
        _buttonsView.declinePressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.declinePressed != nil)
                strongSelf.declinePressed();
        };
        _buttonsView.callPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.callPressed != nil)
                strongSelf.callPressed();
        };
        _buttonsView.messagePressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.messagePressed != nil)
                strongSelf.messagePressed();
        };
        _buttonsView.cameraPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.cameraPressed != nil)
                strongSelf.cameraPressed();
        };
        _buttonsView.flipCameraPressed = ^
        {
            __strong TGCallView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.flipCameraPressed != nil)
                strongSelf.flipCameraPressed();
        };
        [_wrapperView addSubview:_buttonsView];
        
        _emojiLabel = [[UILabel alloc] init];
        _emojiLabel.alpha = 0.0f;
        _emojiLabel.backgroundColor = [UIColor clearColor];
        _emojiLabel.font = TGSystemFontOfSize(22);
        _emojiLabel.userInteractionEnabled = true;
        _emojiLabel.textAlignment = NSTextAlignmentCenter;
        [_wrapperView addSubview:_emojiLabel];
        
        _infoView = [[TGCallInfoView alloc] init];
        [_wrapperView addSubview:_infoView];
        
        UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEmojiTap:)];
        [_emojiLabel addGestureRecognizer:gestureRecognizer];
        
        _videoTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleVideoTap:)];
        _videoTapGestureRecognizer.delegate = self;
        _videoTapGestureRecognizer.cancelsTouchesInView = false;
        _videoTapGestureRecognizer.enabled = false;
        [self addGestureRecognizer:_videoTapGestureRecognizer];
        
        if (!TGIsPad())
        {
            _panGestureRecognizer = [[TGModernGalleryZoomableScrollViewSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            _panGestureRecognizer.delegate = self;
            _panGestureRecognizer.delaysTouchesBegan = true;
            _panGestureRecognizer.cancelsTouchesInView = false;
            [self addGestureRecognizer:_panGestureRecognizer];
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_videoCapturer setPreviewView:nil];
}

- (TGCallVideoView *)remoteVideoView
{
    return _remoteVideoView;
}

- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer
{
    if (_videoCapturer == capturer)
        return;
    
    [_videoCapturer setPreviewView:nil];
    _videoCapturer = capturer;
    _localFrameRendered = false;
    [_localVideoView resetFrames];
    [capturer setPreviewView:_localVideoView];
    [self _updateVideoAnimated:false];
}

- (void)_updateVideoAnimated:(bool)animated
{
    bool remoteVisible = _remoteVideoActive && _remoteFrameRendered && !_callFinished;
    bool localVisible = _localVideoActive && _localFrameRendered && !_callFinished;
    
    _remoteVideoView.hidden = !remoteVisible;
    _videoTapGestureRecognizer.enabled = remoteVisible;
    
    if (!remoteVisible && _videoControlsHidden)
        [self _setVideoControlsHidden:false animated:animated];
    else if (remoteVisible && !_videoControlsHidden)
        [self _scheduleVideoControlsHiding];
    
    bool wasLocalHidden = _localVideoContainer.hidden;
    _localVideoContainer.hidden = !localVisible;
    if (wasLocalHidden != !localVisible || _remoteVideoView.hidden != !remoteVisible)
        syslog(LOG_NOTICE, "IOS6MEDIA ui.video local=%d remote=%d localActive=%d localRendered=%d capturer=%d", localVisible ? 1 : 0, remoteVisible ? 1 : 0, _localVideoActive ? 1 : 0, _localFrameRendered ? 1 : 0, _videoCapturer != nil ? 1 : 0);
    
    void (^layoutBlock)(void) = ^
    {
        [self _layoutVideoViews];
    };
    
    if (animated && !wasLocalHidden && localVisible)
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:layoutBlock completion:nil];
    else
        layoutBlock();
}

- (CGRect)_localVideoFrame
{
    if (!(_remoteVideoActive && _remoteFrameRendered))
        return self.bounds;
    
    CGFloat width = floor(MIN(self.bounds.size.width, self.bounds.size.height) * 0.28f);
    CGFloat height = floor(width * 4.0f / 3.0f);
    CGFloat topOffset = self.safeAreaInset.top > FLT_EPSILON ? self.safeAreaInset.top : 20.0f;
    return CGRectMake(self.bounds.size.width - width - 12.0f, topOffset + 44.0f, width, height);
}

- (void)_layoutVideoViews
{
    _remoteVideoView.frame = self.bounds;
    
    CGRect localFrame = [self _localVideoFrame];
    _localVideoContainer.frame = localFrame;
    _localVideoContainer.layer.cornerRadius = CGRectEqualToRect(localFrame, self.bounds) ? 0.0f : 8.0f;
    _localVideoView.frame = _localVideoContainer.bounds;
}

- (void)_scheduleVideoControlsHiding
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideVideoControls) object:nil];
    [self performSelector:@selector(_hideVideoControls) withObject:nil afterDelay:4.0];
}

- (void)_hideVideoControls
{
    if (_remoteVideoActive && _remoteFrameRendered && !_callFinished && _currentState == TGCallStateOngoing)
        [self _setVideoControlsHidden:true animated:true];
}

- (void)_setVideoControlsHidden:(bool)hidden animated:(bool)animated
{
    if (_videoControlsHidden == hidden)
        return;
    
    _videoControlsHidden = hidden;
    if (!hidden)
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideVideoControls) object:nil];
    
    _wrapperView.userInteractionEnabled = !hidden && !_callFinished;
    CGFloat alpha = hidden ? 0.0f : (_callFinished ? 0.5f : 1.0f);
    if (animated)
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _wrapperView.alpha = alpha;
        }];
    }
    else
    {
        _wrapperView.alpha = alpha;
    }
}

- (void)handleVideoTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateRecognized)
        return;
    
    bool hidden = !_videoControlsHidden;
    [self _setVideoControlsHidden:hidden animated:true];
    if (!hidden)
        [self _scheduleVideoControlsHiding];
}

- (void)setDebugPressed:(void (^)(void))debugPressed
{
    _infoView.debugPressed = debugPressed;
}

- (void)setState:(TGCallSessionState *)state duration:(NSTimeInterval)duration
{
    [_backgroundView setState:state];
    [_infoView setState:state duration:duration];
    [_buttonsView setState:state];
    [_keyView setState:state];
    
    TGCallState previousState = _currentState;
    _currentState = state.state;
    
    bool finished = state.state == TGCallStateEnding || state.state == TGCallStateEnded || state.state == TGCallStateMissed || state.state == TGCallStateBusy || state.state == TGCallStateNoAnswer;
    bool remoteActive = state.remoteVideoActive && !finished;
    if (!remoteActive && _remoteVideoActive)
    {
        _remoteFrameRendered = false;
        [_remoteVideoView resetFrames];
    }
    bool videoChanged = _remoteVideoActive != remoteActive || _localVideoActive != state.localVideoEnabled || _callFinished != finished;
    _remoteVideoActive = remoteActive;
    _localVideoActive = state.localVideoEnabled;
    _callFinished = finished;
    if (videoChanged)
        [self _updateVideoAnimated:true];
    
    if (previousState != _currentState)
    {
        bool animated = state.state == TGCallStateAccepting && previousState == TGCallStateReady;
     
        bool backHidden = (_currentState == TGCallStateHandshake || _currentState == TGCallStateReady || _currentState == TGCallStateBusy || _currentState == TGCallStateNoAnswer) || ((_currentState == TGCallStateEnded || _currentState == TGCallStateEnding || _currentState == TGCallStateBusy || _currentState == TGCallStateMissed) && duration < DBL_EPSILON && !state.outgoing);
        [self setBackButtonHidden:backHidden];
        
        if ((_currentState == TGCallStateEnding || _currentState == TGCallStateEnded || _currentState == TGCallStateMissed) && (_wrapperView.alpha > 1.0f - FLT_EPSILON || _videoControlsHidden))
        {
            _videoControlsHidden = false;
            _wrapperView.userInteractionEnabled = false;
            [UIView animateWithDuration:0.3 animations:^
            {
                _wrapperView.alpha = 0.5f;
            }];
        }
        
        if (state.keySha256 != nil && _emojiLabel.text.length == 0)
        {
            NSString *text = [TGStringUtils stringForEmojiHashOfData:state.keySha256 count:4 positionExtractor:^int32_t(uint8_t *bytes, int32_t i, int32_t count) {
                int offset = i * 8;
                int64_t num = (((int64_t)bytes[offset] & 0x7F) << 56) | (((int64_t)bytes[offset+1] & 0xFF) << 48) | (((int64_t)bytes[offset+2] & 0xFF) << 40) | (((int64_t)bytes[offset+3] & 0xFF) << 32) | (((int64_t)bytes[offset+4] & 0xFF) << 24) | (((int64_t)bytes[offset+5] & 0xFF) << 16) | (((int64_t)bytes[offset+6] & 0xFF) << 8) | (((int64_t)bytes[offset+7] & 0xFF));
                return num % count;
            }];
            
            NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName: _emojiLabel.font, NSKernAttributeName: @2.5f }];
            
            _emojiLabel.attributedText = attributedString;
            [_emojiLabel sizeToFit];
            _emojiLabel.alpha = 0.0f;
            
            [UIView animateWithDuration:0.2 animations:^
            {
                _emojiLabel.alpha = 1.0f;
            } completion:^(__unused BOOL finished)
            {
                [self setupTooltip:false name:state.peer.displayFirstName];
            }];
            
            [_keyView setEmoji:text];
        }
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                [self layoutSubviews];
            } completion:nil];
        }
        else
        {
            [self setNeedsLayout];
        }
    }
}

- (void)onPause
{
    [_infoView onPause];
}

- (void)onResume
{
    [_infoView onResume];
}

- (void)setFrame:(CGRect)frame
{    
    [super setFrame:frame];
    [self _updateBackground];
}

- (void)_updateBackground
{
    NSObject<TGPasscodeBackground> *background;
    if (_backgroundImage != nil)
        background = [[TGImageBasedPasscodeBackground alloc] initWithImage:_backgroundImage size:self.frame.size];
    else
        background = [[TGDefaultPasscodeBackground alloc] initWithSize:self.frame.size];
    
    [_buttonsView setBackground:background];
}

- (void)backButtonPressed
{
    if (self.backPressed != nil)
        self.backPressed();
}

- (void)setBackButtonHidden:(bool)hidden
{
    _backButton.hidden = hidden;
    _panGestureRecognizer.enabled = !hidden;
}

- (void)showKeyView
{
    if ([_keyView present])
    {
        [self setBackButtonHidden:true];
        _emojiLabel.hidden = true;
    }
}

- (void)closeKeyView
{
    [_keyView dismiss:^
    {
        _emojiLabel.hidden = false;
    }];
    [self setBackButtonHidden:false];
}

- (UIButton *)speakerButton
{
    return _buttonsView.speakerButton;
}

- (void)handlePan:(TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            _panning = true;
            _dimView.hidden = false;
            [self _updateDismissTransitionMovementWithDistance:[gestureRecognizer swipeDistance] animated:false completion:nil];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            CGFloat swipeVelocity = [gestureRecognizer swipeVelocity];
            if (ABS(swipeVelocity) < TGCallSwipeMinimumVelocity)
                swipeVelocity = (swipeVelocity < 0.0f ? -1.0f : 1.0f) * TGCallSwipeMinimumVelocity;
            
            __weak TGCallView *weakSelf = self;
            bool(^transitionOut)(CGFloat) = ^bool(__unused CGFloat swipeVelocity)
            {
                __strong TGCallView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return false;
                
                [self performMinimize];
            
                return true;
            };
            
            if ((ABS(swipeVelocity) < TGCallSwipeVelocityThreshold && ABS([gestureRecognizer swipeDistance]) < TGCallSwipeDistanceThreshold) || !transitionOut(swipeVelocity))
            {
                [self _updateDismissTransitionMovementWithDistance:0.0f animated:true completion:^
                {
                    _panning = false;
                    _dimView.hidden = true;
                }];
            }
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            [self _updateDismissTransitionMovementWithDistance:0.0f animated:true completion:^
            {
                _panning = false;
                _dimView.hidden = true;
            }];
        }
            break;
            
        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    UIView *hitTest = [self hitTest:[touch locationInView:self] withEvent:nil];
    if (gestureRecognizer.state == UIGestureRecognizerStatePossible && [hitTest isKindOfClass:[UIButton class]])
        return false;
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return (gestureRecognizer == _videoTapGestureRecognizer && otherGestureRecognizer == _panGestureRecognizer) || (gestureRecognizer == _panGestureRecognizer && otherGestureRecognizer == _videoTapGestureRecognizer);
}

- (void)performMinimize
{
    if (self.minimizeRequested != nil)
        self.minimizeRequested();
}

- (void)centralize
{
    _mainView.transform = CGAffineTransformIdentity;
}

- (void)resetPan
{
    _panning = false;
}

- (CGFloat)dismissProgressForSwipeDistance:(CGFloat)distance
{
    return MAX(0.0f, MIN(1.0f, ABS(distance / 150.0f)));
}

- (void)_updateDismissTransitionMovementWithDistance:(CGFloat)distance animated:(bool)animated completion:(void (^)(void))completion
{
    CGFloat scale = 1.0f + 0.06f * MIN(1.0f, (fabs(distance) / 200.0f));
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, distance);
    transform = CGAffineTransformScale(transform, scale, scale);
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _mainView.transform = transform;
        } completion:^(__unused BOOL finished)
        {
            if (completion != nil)
                completion();
        }];
    }
    else
    {
        _mainView.transform = transform;
    }
}

- (void)setupTooltip:(bool)manual name:(NSString *)name
{
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
        return;
    
    NSInteger displayed = manual ? 0 : [[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedCallEmojiTooltip_v0"] integerValue];
#if defined(INTERNAL_RELEASE)
#endif
    if (displayed > 2)
        return;
    
    if (_tooltipContainerView != nil)
        return;
    
    NSString *textFormat = TGLocalized(@"Call.EmojiDescription");
    NSString *baseText = [[NSString alloc] initWithFormat:textFormat, name];
    
    NSDictionary *attrs = @{NSFontAttributeName: TGSystemFontOfSize(14), NSForegroundColorAttributeName: [UIColor whiteColor]};
    NSDictionary *subAttrs = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14], NSForegroundColorAttributeName: [UIColor whiteColor]};
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseText attributes:attrs];
    [attributedText setAttributes:subAttrs range:NSMakeRange([textFormat rangeOfString:@"%@"].location, name.length)];
    
    _tooltipTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(tooltipTimerTick) interval:5.5 repeat:false];
    
    _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_tooltipContainerView];
    
    _tooltipContainerView.menuView.multiline = true;
    [_tooltipContainerView.menuView setButtonsAndActions:@[ @{ @"title": attributedText } ] watcherHandle:self.actionHandle];
    [_tooltipContainerView.menuView sizeToFit];
    _tooltipContainerView.menuView.buttonHighlightDisabled = true;
    
    CGRect frame = _emojiLabel.frame;
    frame.origin.y -= 6.0f;
    [_tooltipContainerView showMenuFromRect:frame animated:false];
    
    if (!manual)
        [[NSUserDefaults standardUserDefaults] setObject:@(displayed + 1) forKey:@"TG_displayedCallEmojiTooltip_v0"];
}

- (void)tooltipTimerTick
{
    [_tooltipTimer invalidate];
    _tooltipTimer = nil;
    
    [_tooltipContainerView hideMenu];
    _tooltipContainerView = nil;
}

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"menuAction"])
    {
        [_tooltipTimer invalidate];
        _tooltipTimer = nil;
        
        [_tooltipContainerView hideMenu];
        _tooltipContainerView = nil;
    }
    else if ([action isEqualToString:@"menuWillHide"])
    {
        [_tooltipTimer invalidate];
        _tooltipTimer = nil;
        
        _tooltipContainerView = nil;
    }
}

- (void)handleEmojiTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    [self showKeyView];
}

+ (CGFloat)infoTopOffset
{
    CGFloat offset = 0.0f;
    if (TGIsPad())
    {
        static dispatch_once_t onceToken;
        static CGFloat staticOffset;
        dispatch_once(&onceToken, ^
        {
            CGSize screenSize = TGScreenSize();
            int height = (int)screenSize.height;
            if (height == 1366)
            {
                staticOffset = 160.0f;
            }
            else
            {
                staticOffset = 120.0f;
            }
        });
        offset = staticOffset;
    }
    else
    {
        static dispatch_once_t onceToken;
        static CGFloat staticOffset;
        dispatch_once(&onceToken, ^
        {
            CGSize screenSize = TGScreenSize();
            int width = (int)screenSize.width;
            int height = (int)screenSize.height;
            if (height == 812)
                staticOffset = 125;
            else if (height == 736)
                staticOffset = 80;
            else if (width == 320)
                staticOffset = 60;
            else
                staticOffset = 64;
        });
        offset = staticOffset;
    }
    return offset;
}

+ (CGFloat)buttonsTopOffset:(CGRect)bounds
{
    CGFloat offset = 0.0f;
    static dispatch_once_t onceToken;
    static CGFloat screenHeight;
    dispatch_once(&onceToken, ^
    {
        screenHeight = TGScreenSize().height;
    });
    
    if (TGIsPad())
    {
        int height = (int)screenHeight;
        if (height == 1366)
            offset = bounds.size.height - 420.0f;
        else
            offset = bounds.size.height - 375.0f;
    }
    else
    {
        static dispatch_once_t onceToken;
        static CGFloat staticOffset;
        dispatch_once(&onceToken, ^
        {
            int height = (int)screenHeight;
            if (height == 812)
                staticOffset = 440;
            else if (height == 736)
                staticOffset = 410;
            else if (height == 480)
                staticOffset = 270;
            else if (height == 568)
                staticOffset = 306;
            else
                staticOffset = 385;
        });
        offset = staticOffset;
    }
    return offset;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    _keyView.safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    _dimView.frame = self.bounds;
    
    if (!_panning)
        _mainView.frame = self.bounds;
    
    _backgroundView.frame = self.bounds;
    _wrapperView.frame = self.bounds;
    [self _layoutVideoViews];
    _keyView.frame = self.bounds;
    
    if (!_panning)
    {
        [_backButton sizeToFit];
        
        CGFloat topOffset = self.safeAreaInset.top > FLT_EPSILON ? self.safeAreaInset.top : 20.0f;
        _backButton.frame = CGRectMake(27, topOffset + 5, ceil(_backButton.frame.size.width), ceil(_backButton.frame.size.height));
        _infoView.frame = CGRectMake(0, [TGCallView infoTopOffset], self.frame.size.width, TGCallInfoViewHeight);
        
        CGFloat buttonsTop = [TGCallView buttonsTopOffset:self.bounds];
        CGFloat buttonsWidth = [TGCallButton buttonSize].width * 3 + TGCallButtonsSpacing * 2;
        _buttonsView.frame = CGRectMake(floor((self.frame.size.width - buttonsWidth) / 2.0f), buttonsTop, buttonsWidth, 232);
        
        _emojiLabel.frame = CGRectMake(self.frame.size.width - _emojiLabel.frame.size.width - 8.0f, topOffset + 8.0f, _emojiLabel.frame.size.width, _emojiLabel.frame.size.height);
    }
}

@end
