#import "RMGeometry.h"

#import "../../../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLoginPhoneController.h"
#import "TGLoginPasswordController.h"
#import "../../../../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "RMIntroViewController.h"
#import "RMIntroPageView.h"

#include "animations.h"
#include "objects.h"
#include "texture_helper.h"

#include "TGAppDelegate.h"

#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"
#import <CoreImage/CoreImage.h>

#import "TGLocalizationSignals.h"
#import "../../../../submodules/LegacyComponents/LegacyComponents/TGAnimationUtils.h"
#import "../../../../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGDatabase.h"

@interface UIScrollView (CurrentPage)
- (int)currentPage;
- (void)setPage:(NSInteger)page;
- (int)currentPageMin;
- (int)currentPageMax;

@end

@implementation UIScrollView (CurrentPage)

- (int)currentPage
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMin
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMax
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 + pageWidth / 2 ) / pageWidth) + 1;
}

- (void)setPage:(NSInteger)page
{
    self.contentOffset = CGPointMake(self.frame.size.width*page, 0);
}
@end


@interface RMIntroViewController () <UIGestureRecognizerDelegate>
{
    id _didEnterBackgroundObserver;
    id _willEnterBackgroundObserver;
    
    UIImageView *_stillLogoView;
    bool _displayedStillLogo;
    
    UIButton *_switchToDebugButton;
    
    TGModernButton *_alternativeLanguageButton;
    
    SMetaDisposable *_localizationsDisposable;
    TGSuggestedLocalization *_alternativeLocalizationInfo;
    
    SVariable *_alternativeLocalization;

    bool _qrLoginEnabled;
    bool _displayingQrLogin;
    bool _qrRequestInProgress;
    bool _qrRefreshPending;
    UIView *_qrContainerView;
    UIImageView *_qrImageView;
    UILabel *_qrTitleLabel;
    UILabel *_qrHelpLabel;
    UILabel *_qrStatusLabel;
    NSTimer *_qrRefreshTimer;
    NSObject *_qrLoginRequestToken;
    id _qrLoginUpdateObserver;
}

- (void)layoutIntroViews;

@end

static NSString *replaceAppTitle(NSString *string, NSString *title) {
    return [string stringByReplacingOccurrencesOfString:@"Telegram" withString:title];
}

static NSString *TGIOS6Base64UrlString(NSData *data)
{
    if (data.length == 0)
        return @"";

    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:((length + 2) / 3) * 4];
    for (NSUInteger i = 0; i < length; i += 3)
    {
        uint32_t value = ((uint32_t)bytes[i]) << 16;
        NSUInteger remaining = length - i;
        if (remaining > 1)
            value |= ((uint32_t)bytes[i + 1]) << 8;
        if (remaining > 2)
            value |= bytes[i + 2];

        [result appendFormat:@"%c", table[(value >> 18) & 63]];
        [result appendFormat:@"%c", table[(value >> 12) & 63]];
        if (remaining > 1)
            [result appendFormat:@"%c", table[(value >> 6) & 63]];
        if (remaining > 2)
            [result appendFormat:@"%c", table[value & 63]];
    }

    [result replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, result.length)];
    return result;
}

static NSString *TGIOS6QRCodeJavaScript(void)
{
    static NSString *script = nil;
    if (script == nil)
    {
        static const char source[] =
#include "TGIOS6QRCodeJavaScript.inc"
        ;
        script = [[NSString alloc] initWithBytes:source length:sizeof(source) - 1 encoding:NSUTF8StringEncoding];
    }
    return script;
}


@interface TGIOS6QRLoginController : UIViewController
{
    UIView *_qrContainerView;
    UIImageView *_qrImageView;
    UIWebView *_qrWebView;
    UILabel *_statusLabel;
    TGModernButton *_phoneButton;
    NSTimer *_refreshTimer;
    NSObject *_requestToken;
    id _loginTokenObserver;
    bool _requestInProgress;
    bool _refreshPending;
    bool _hasQrCode;
    bool _passwordControllerPresented;
}
- (void)layoutQrLoginViews;
@end

@implementation TGIOS6QRLoginController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        if (iosMajorVersion() >= 7)
            self.automaticallyAdjustsScrollViewInsets = false;
        self.wantsFullScreenLayout = true;

        // Set this before auth.exportLoginToken can change MTProto's global
        // password-required state. TGTelegramNetworking otherwise races this
        // flow and installs a normal password controller.
        TGIOS6SetQRLoginFlowActive(true);

        __unsafe_unretained TGIOS6QRLoginController *weakSelf = self;
        _loginTokenObserver = [[NSNotificationCenter defaultCenter] addObserverForName:TGLoginTokenUpdatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            __strong TGIOS6QRLoginController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                TGLog(@"IOS6QR separate controller updateLoginToken");
                [strongSelf refreshQrLoginToken];
            }
        }];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];

    _qrContainerView = [[UIView alloc] init];
    _qrContainerView.backgroundColor = [UIColor whiteColor];
    _qrContainerView.clipsToBounds = true;
    [self.view addSubview:_qrContainerView];

    _qrImageView = [[UIImageView alloc] init];
    _qrImageView.backgroundColor = [UIColor whiteColor];
    _qrImageView.contentMode = UIViewContentModeCenter;
    [_qrContainerView addSubview:_qrImageView];

    _qrWebView = [[UIWebView alloc] init];
    _qrWebView.backgroundColor = [UIColor whiteColor];
    _qrWebView.opaque = false;
    _qrWebView.userInteractionEnabled = false;
    _qrWebView.hidden = true;
    _qrWebView.scalesPageToFit = false;
    UIScrollView *qrScrollView = TGUIWebViewScrollView(_qrWebView);
    qrScrollView.scrollEnabled = false;
    qrScrollView.bounces = false;
    qrScrollView.contentInset = UIEdgeInsetsZero;
    [_qrContainerView addSubview:_qrWebView];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textColor = UIColorRGB(0x888888);
    _statusLabel.font = TGSystemFontOfSize(13.0f);
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.text = TGLocalized(@"Login.QRLoading");
    [self.view addSubview:_statusLabel];

    _phoneButton = [[TGModernButton alloc] init];
    _phoneButton.modernHighlight = true;
    [_phoneButton setTitle:TGLocalized(@"Login.PhoneLogin") forState:UIControlStateNormal];
    [_phoneButton setTitleColor:TGAccentColor() forState:UIControlStateNormal];
    _phoneButton.titleLabel.font = TGMediumSystemFontOfSize(17.0f);
    [_phoneButton addTarget:self action:@selector(phoneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_phoneButton];

    [self layoutQrLoginViews];
}

- (void)layoutQrLoginViews
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat phoneHeight = 44.0f;
    CGFloat phoneBottom = 18.0f;
    _phoneButton.frame = CGRectMake(20.0f, height - phoneBottom - phoneHeight, width - 40.0f, phoneHeight);

    CGFloat qrSize = MIN(width - 64.0f, 210.0f);
    if (height <= 480.0f)
        qrSize = MIN(qrSize, 176.0f);

    CGFloat top = iosMajorVersion() >= 7 ? 28.0f : 20.0f;
    CGFloat bottom = CGRectGetMinY(_phoneButton.frame) - 32.0f;
    CGFloat availableHeight = MAX(140.0f, bottom - top);
    qrSize = MIN(qrSize, availableHeight);
    CGFloat qrY = top + floor((availableHeight - qrSize) / 2.0f);

    _qrContainerView.frame = CGRectMake(floor((width - qrSize) / 2.0f), qrY, qrSize, qrSize);
    _qrImageView.frame = _qrContainerView.bounds;
    _qrWebView.frame = _qrContainerView.bounds;
    _statusLabel.frame = CGRectMake(16.0f, CGRectGetMaxY(_qrContainerView.frame) + 4.0f, width - 32.0f, 20.0f);
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutQrLoginViews];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutQrLoginViews];
}

- (UIImage *)qrImageForLoginToken:(NSData *)token targetSize:(CGFloat)targetSize
{
    if (token.length == 0)
        return nil;

    NSString *payload = [NSString stringWithFormat:@"tg://login?token=%@", TGIOS6Base64UrlString(token)];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (filter == nil)
        return nil;

    [filter setDefaults];
    [filter setValue:[payload dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    @try { [filter setValue:@"M" forKey:@"inputCorrectionLevel"]; } @catch (__unused NSException *exception) { }
    CIImage *outputImage = filter.outputImage;
    if (outputImage == nil)
        return nil;

    CGRect extent = CGRectIntegral(outputImage.extent);
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ciContext createCGImage:outputImage fromRect:extent];
    if (cgImage == NULL)
        return nil;

    UIImage *sourceImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);

    CGFloat moduleScale = floor(targetSize / MAX(extent.size.width, extent.size.height));
    if (moduleScale < 1.0f)
        moduleScale = 1.0f;
    CGSize renderedSize = CGSizeMake(extent.size.width * moduleScale, extent.size.height * moduleScale);

    UIGraphicsBeginImageContextWithOptions(renderedSize, true, 1.0f);
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(contextRef, kCGInterpolationNone);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, renderedSize.width, renderedSize.height));
    [sourceImage drawInRect:CGRectMake(0, 0, renderedSize.width, renderedSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (bool)renderLegacyQrLoginToken:(NSData *)token targetSize:(CGFloat)targetSize
{
    if (token.length == 0)
        return false;

    NSString *payload = [NSString stringWithFormat:@"tg://login?token=%@", TGIOS6Base64UrlString(token)];
    NSString *script = TGIOS6QRCodeJavaScript();
    if (script.length == 0)
        return false;

    int pixelSize = MAX(120, (int)floor(targetSize));
    NSString *html = [NSString stringWithFormat:
        @"<html><head><meta name='viewport' content='width=%d,initial-scale=1.0,maximum-scale=1.0,user-scalable=no'><style>html,body{margin:0;padding:0;width:%dpx;height:%dpx;background:#fff;overflow:hidden}#wrap{position:relative;width:%dpx;height:%dpx;overflow:hidden;background:#fff}canvas{position:absolute;display:block}</style></head><body><div id='wrap'><canvas id='q'></canvas></div><script>%@;var q=new QRCode(0,QRErrorCorrectLevel.M);q.addData('%@');q.make();var n=q.getModuleCount(),quiet=4,scale=Math.max(1,Math.floor(%d/(n+quiet*2))),size=(n+quiet*2)*scale,c=document.getElementById('q'),x=c.getContext('2d'),left=Math.floor((%d-size)/2),top=Math.floor((%d-size)/2);c.width=size;c.height=size;c.style.left=left+'px';c.style.top=top+'px';x.fillStyle='#fff';x.fillRect(0,0,size,size);x.fillStyle='#000';for(var r=0;r<n;r++){for(var col=0;col<n;col++){if(q.isDark(r,col))x.fillRect((col+quiet)*scale,(r+quiet)*scale,scale,scale);}}</script></body></html>",
        pixelSize, pixelSize, pixelSize, pixelSize, pixelSize, script, payload, pixelSize, pixelSize, pixelSize];

    [_qrWebView loadHTMLString:html baseURL:nil];
    TGUIWebViewScrollView(_qrWebView).contentOffset = CGPointZero;
    _qrWebView.hidden = false;
    _qrImageView.hidden = true;
    return true;
}

- (void)scheduleRefreshAtExpires:(int32_t)expires
{
    [_refreshTimer invalidate];
    _refreshTimer = nil;

    NSTimeInterval remoteNow = [[TGTelegramNetworking instance] approximateRemoteTime];
    NSTimeInterval delay = expires > 0 ? ((NSTimeInterval)expires - remoteNow - 3.0) : 20.0;
    delay = MAX(5.0, MIN(25.0, delay));
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(refreshTimerFired) userInfo:nil repeats:false];
}

- (void)refreshTimerFired
{
    _refreshTimer = nil;
    [self refreshQrLoginToken];
}

- (void)refreshQrLoginToken
{
    if (!self.isViewLoaded || self.view.window == nil)
        return;

    if (_requestInProgress)
    {
        _refreshPending = true;
        return;
    }

    _requestInProgress = true;
    _refreshPending = false;
    if (!_hasQrCode)
        _statusLabel.text = TGLocalized(@"Login.QRLoading");

    __unsafe_unretained TGIOS6QRLoginController *weakSelf = self;
    _requestToken = [TGTelegraphInstance doExportLoginTokenWithCompletion:^(NSData *token, int32_t expires, bool authorized, NSString *errorText)
    {
        TGDispatchOnMainThread(^{
            __strong TGIOS6QRLoginController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_requestToken = nil;
            strongSelf->_requestInProgress = false;

            if (authorized)
            {
                TGIOS6SetQRLoginFlowActive(false);
                strongSelf->_statusLabel.text = TGLocalized(@"Login.QRAuthorized");
                [strongSelf->_refreshTimer invalidate];
                strongSelf->_refreshTimer = nil;
                TGLog(@"IOS6QR separate authorized -> present main controller");
                [TGAppDelegateInstance presentMainController];
                return;
            }

            if (token.length != 0)
            {
                CGFloat qrSize = strongSelf.view.bounds.size.height <= 480.0f ? 168.0f : 192.0f;
                bool rendered = false;
                if (iosMajorVersion() >= 7)
                {
                    UIImage *image = [strongSelf qrImageForLoginToken:token targetSize:qrSize];
                    if (image != nil)
                    {
                        strongSelf->_qrImageView.image = image;
                        strongSelf->_qrImageView.hidden = false;
                        strongSelf->_qrWebView.hidden = true;
                        rendered = true;
                    }
                }

                if (!rendered)
                {
                    rendered = [strongSelf renderLegacyQrLoginToken:token targetSize:qrSize];
                    if (rendered)
                        TGLog(@"IOS6QR software renderer os=%d", iosMajorVersion());
                }

                if (rendered)
                {
                    strongSelf->_hasQrCode = true;
                    strongSelf->_statusLabel.text = @"";
                    TGLog(@"IOS6QR separate rendered token bytes=%d expires=%d", (int)token.length, expires);
                    [strongSelf scheduleRefreshAtExpires:expires];
                }
                else
                {
                    strongSelf->_statusLabel.text = TGLocalized(@"Login.QRError");
                    [strongSelf scheduleRefreshAtExpires:0];
                }
            }
            else
            {
                TGLog(@"IOS6QR separate UI error=%@", errorText ?: @"unknown");

                if ([errorText hasPrefix:@"SESSION_PASSWORD_NEEDED"])
                {
                    [strongSelf->_refreshTimer invalidate];
                    strongSelf->_refreshTimer = nil;
                    strongSelf->_refreshPending = false;
                    strongSelf->_statusLabel.text = @"";

                    if (!strongSelf->_passwordControllerPresented)
                    {
                        strongSelf->_passwordControllerPresented = true;
                        TGLog(@"IOS6QR password required -> push password controller");
                        TGLoginPasswordController *passwordController = [[TGLoginPasswordController alloc] initForQrLogin];
                        [strongSelf.navigationController pushViewController:passwordController animated:true];
                    }
                    return;
                }

                if ([errorText isEqualToString:@"AUTH_RESTART"])
                {
                    strongSelf->_statusLabel.text = TGLocalized(@"Login.QRLoading");
                    [strongSelf->_refreshTimer invalidate];
                    strongSelf->_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:strongSelf selector:@selector(refreshTimerFired) userInfo:nil repeats:false];
                }
                else
                {
                    strongSelf->_statusLabel.text = TGLocalized(@"Login.QRError");
                    [strongSelf scheduleRefreshAtExpires:0];
                }
            }

            if (strongSelf->_refreshPending)
            {
                strongSelf->_refreshPending = false;
                [strongSelf refreshQrLoginToken];
            }
        });
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self layoutQrLoginViews];
    TGIOS6SetQRLoginFlowActive(true);
    TGLog(@"IOS6QR separate controller visible");

    if (_passwordControllerPresented)
    {
        _passwordControllerPresented = false;
        TGLog(@"IOS6QR returned from password controller");
        return;
    }

    [self refreshQrLoginToken];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_refreshTimer invalidate];
    _refreshTimer = nil;
    if (_requestToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:_requestToken softCancel:true];
        _requestToken = nil;
    }
    _requestInProgress = false;
}

- (void)phoneButtonPressed
{
    TGIOS6SetQRLoginFlowActive(false);
    TGLog(@"IOS6QR phone login pressed");
    TGLoginPhoneController *phoneController = [[TGLoginPhoneController alloc] init];
    [self.navigationController pushViewController:phoneController animated:true];
}

- (void)dealloc
{
    TGIOS6SetQRLoginFlowActive(false);
    if (_loginTokenObserver != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:_loginTokenObserver];
    [_refreshTimer invalidate];
    if (_requestToken != nil)
        [TGTelegraphInstance cancelRequestByToken:_requestToken softCancel:true];
}

@end

@implementation RMIntroViewController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        if (iosMajorVersion() >= 7)
            self.automaticallyAdjustsScrollViewInsets = false;
        
        self.wantsFullScreenLayout = true;

        // Keep QR login available on iOS 5-10. iOS 7+ uses CoreImage;
        // iOS 5/6 falls back to the bundled local JavaScript encoder.
        _qrLoginEnabled = true;
        _displayingQrLogin = false;
        
        NSString *appTitle = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
        if (appTitle == nil) {
            appTitle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        }
        if (appTitle == nil) {
            appTitle = @"Telegram";
        }
        
        _headlines = @[ appTitle, TGLocalized(@"Tour.Title2"),  TGLocalized(@"Tour.Title6"), TGLocalized(@"Tour.Title3"), TGLocalized(@"Tour.Title4"), TGLocalized(@"Tour.Title5")];
        _descriptions = @[replaceAppTitle(TGLocalized(@"Tour.Text1"), appTitle), replaceAppTitle(TGLocalized(@"Tour.Text2"), appTitle), replaceAppTitle(TGLocalized(@"Tour.Text6"), appTitle), replaceAppTitle(TGLocalized(@"Tour.Text3"), appTitle), replaceAppTitle(TGLocalized(@"Tour.Text4"), appTitle), replaceAppTitle(TGLocalized(@"Tour.Text5"), appTitle)];
        
        __unsafe_unretained RMIntroViewController *weakSelf = self;
        _didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            [strongSelf stopTimer];
        }];
        
        _willEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            if (strongSelf->_displayingQrLogin)
            {
                [strongSelf refreshQrLoginToken];
            }
            else
            {
                [strongSelf loadGL];
                [strongSelf startTimer];
            }
        }];
        
        _alternativeLanguageButton = [[TGModernButton alloc] init];
        _alternativeLanguageButton.modernHighlight = true;
        [_alternativeLanguageButton setTitleColor:TGAccentColor()];
        _alternativeLanguageButton.titleLabel.font = TGSystemFontOfSize(18.0f);
        // Always keep the language action visible on first launch. The
        // suggested-localization request may arrive late on slow networks.
        [_alternativeLanguageButton setTitle:@"Continue in English" forState:UIControlStateNormal];
        [_alternativeLanguageButton sizeToFit];
        _alternativeLanguageButton.hidden = false;
        [_alternativeLanguageButton addTarget:self action:@selector(alternativeLanguageButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _alternativeLocalization = [[SVariable alloc] init];

        if (_qrLoginEnabled)
        {
            _qrLoginUpdateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:TGLoginTokenUpdatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
            {
                __strong RMIntroViewController *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    TGLog(@"IOS6QR intro received updateLoginToken");
                    [strongSelf refreshQrLoginToken];
                }
            }];
        }
        
        SSignal *localizationSignal = [TGLocalizationSignals suggestedLocalization];
#ifdef DEBUG
        localizationSignal = [localizationSignal delay:1.0 onQueue:[SQueue mainQueue]];
#endif
        _localizationsDisposable = [[localizationSignal deliverOn:[SQueue mainQueue]] startWithNext:^(TGSuggestedLocalization *next) {
            __strong RMIntroViewController *strongSelf = weakSelf;
            if (strongSelf != nil && next != nil) {
                strongSelf->_alternativeLocalizationInfo = next;
                NSString *title = next.continueWithLanguageString;
                if (title.length == 0)
                    title = @"Continue in English";
                [strongSelf->_alternativeLanguageButton setTitle:title forState:UIControlStateNormal];
                [strongSelf->_alternativeLanguageButton sizeToFit];
                strongSelf->_alternativeLanguageButton.hidden = false;
                if ([strongSelf isViewLoaded]) {
                    [UIView animateWithDuration:0.2 animations:^{
                        [strongSelf layoutIntroViews];
                    }];
                }
            }
        }];
    }
    return self;
}

- (void)startTimer
{
    if (_displayingQrLogin || _glkView == nil)
        return;

    if (_updateAndRenderTimer == nil)
    {
        _updateAndRenderTimer = [NSTimer timerWithTimeInterval:1.0f / 60.0f target:self selector:@selector(updateAndRender) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_updateAndRenderTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopTimer
{
    if (_updateAndRenderTimer != nil)
    {
        [_updateAndRenderTimer invalidate];
        _updateAndRenderTimer = nil;
    }
}


- (void)loadView
{
    [super loadView];
    
#if defined(DEBUG) || defined(INTERNAL_RELEASE)
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(switchToDebugPressed:)]];
#endif
}

- (void)switchToDebugPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_switchToDebugButton == nil)
        {
            _switchToDebugButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, self.view.frame.size.height - 45.0f, self.view.frame.size.width, 45.0f)];
            _switchToDebugButton.backgroundColor = [UIColor grayColor];
            [_switchToDebugButton setTitle:!TGAppDelegateInstance.useDifferentBackend ? @"Switch to production" : @"Switch to debug" forState:UIControlStateNormal];
            [_switchToDebugButton addTarget:self action:@selector(reallySwitchToDebugPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.view removeGestureRecognizer:recognizer];
            [self.view addSubview:_switchToDebugButton];
        }
    }
}

- (void)reallySwitchToDebugPressed
{
    [[TGTelegramNetworking instance] switchBackends];
}

- (void)loadGL
{
    if (_displayingQrLogin)
        return;

    if (NSClassFromString(@"GLKView") == Nil)
        return;

    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground && !_isOpenGLLoaded)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context)
            NSLog(@"Failed to create ES context");
        
        bool isIpad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
        
        CGFloat size = 200;
        if (isIpad)
            size *= 1.2;
        
        int height = 50;
        if (isIpad)
            height += 138 / 2;
        
        _glkView = [[GLKView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - size / 2, height, size, size) context:context];
        _glkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.drawableMultisample = GLKViewDrawableMultisample4X;
        _glkView.enableSetNeedsDisplay = false;
        _glkView.userInteractionEnabled = false;
        _glkView.delegate = self;
        if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.example.Tele6ram"]) {
            _glkView.hidden = true;
        }
        
        int patchHalfWidth = 1;
        UIView *v1 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth, _glkView.frame.size.width + patchHalfWidth * 2, patchHalfWidth * 2)];
        UIView *v2 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth, patchHalfWidth * 2, _glkView.frame.size.height + patchHalfWidth * 2)];
        UIView *v3 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth + _glkView.frame.size.height, _glkView.frame.size.width + patchHalfWidth * 2, patchHalfWidth * 2)];
        UIView *v4 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth + _glkView.frame.size.width, -patchHalfWidth, patchHalfWidth * 2, _glkView.frame.size.height + patchHalfWidth * 2)];
        
        v1.backgroundColor = v2.backgroundColor = v3.backgroundColor = v4.backgroundColor = [UIColor whiteColor];
        
        [_glkView addSubview:v1];
        [_glkView addSubview:v2];
        [_glkView addSubview:v3];
        [_glkView addSubview:v4];
        
        [self setupGL];
        [self.view addSubview:_glkView];
        
        [self startTimer];
        _isOpenGLLoaded = true;
    }
}

- (void)freeGL
{
    if (!_isOpenGLLoaded)
        return;

    [self stopTimer];
    
    if ([EAGLContext currentContext] == _glkView.context)
        [EAGLContext setCurrentContext:nil];

    _glkView.context = nil;
    context = nil;
    [_glkView removeFromSuperview];
    _glkView = nil;
    _isOpenGLLoaded = false;
}

- (void)updateQrLocalization
{
    _qrTitleLabel.text = TGLocalized(@"Login.QRTitle");
    _qrHelpLabel.text = TGLocalized(@"Login.QRHelp");
    if (!_qrRequestInProgress && _qrImageView.image == nil)
        _qrStatusLabel.text = TGLocalized(@"Login.QRLoading");
    [_startButton setTitle:TGLocalized(@"Login.PhoneLogin") forState:UIControlStateNormal];
    [_alternativeLanguageButton sizeToFit];
}

- (UIImage *)qrImageForLoginToken:(NSData *)token targetSize:(CGFloat)targetSize
{
    if (token.length == 0)
        return nil;

    NSString *payload = [NSString stringWithFormat:@"tg://login?token=%@", TGIOS6Base64UrlString(token)];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (filter == nil)
        return nil;

    [filter setDefaults];
    [filter setValue:[payload dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    @try { [filter setValue:@"M" forKey:@"inputCorrectionLevel"]; } @catch (__unused NSException *exception) { }
    CIImage *outputImage = filter.outputImage;
    if (outputImage == nil)
        return nil;

    CGRect extent = CGRectIntegral(outputImage.extent);
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ciContext createCGImage:outputImage fromRect:extent];
    if (cgImage == NULL)
        return nil;

    UIImage *sourceImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);

    CGFloat moduleScale = floor(targetSize / MAX(extent.size.width, extent.size.height));
    if (moduleScale < 1.0f)
        moduleScale = 1.0f;
    CGSize renderedSize = CGSizeMake(extent.size.width * moduleScale, extent.size.height * moduleScale);

    UIGraphicsBeginImageContextWithOptions(renderedSize, true, 1.0f);
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(contextRef, kCGInterpolationNone);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, renderedSize.width, renderedSize.height));
    [sourceImage drawInRect:CGRectMake(0, 0, renderedSize.width, renderedSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)scheduleQrRefreshAtExpires:(int32_t)expires
{
    [_qrRefreshTimer invalidate];
    _qrRefreshTimer = nil;

    NSTimeInterval remoteNow = [[TGTelegramNetworking instance] approximateRemoteTime];
    NSTimeInterval delay = expires > 0 ? ((NSTimeInterval)expires - remoteNow - 3.0) : 20.0;
    delay = MAX(5.0, MIN(25.0, delay));
    _qrRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(qrRefreshTimerFired) userInfo:nil repeats:false];
}

- (void)qrRefreshTimerFired
{
    _qrRefreshTimer = nil;
    [self refreshQrLoginToken];
}

- (void)refreshQrLoginToken
{
    if (!_qrLoginEnabled || !_displayingQrLogin || !self.isViewLoaded || self.view.window == nil)
        return;

    if (_qrRequestInProgress)
    {
        _qrRefreshPending = true;
        return;
    }

    _qrRequestInProgress = true;
    _qrRefreshPending = false;
    if (_qrImageView.image == nil)
        _qrStatusLabel.text = TGLocalized(@"Login.QRLoading");

    __unsafe_unretained RMIntroViewController *weakSelf = self;
    _qrLoginRequestToken = [TGTelegraphInstance doExportLoginTokenWithCompletion:^(NSData *token, int32_t expires, bool authorized, NSString *errorText)
    {
        TGDispatchOnMainThread(^{
            __strong RMIntroViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_qrLoginRequestToken = nil;
            strongSelf->_qrRequestInProgress = false;

            if (authorized)
            {
                TGIOS6SetQRLoginFlowActive(false);
                strongSelf->_qrStatusLabel.text = TGLocalized(@"Login.QRAuthorized");
                [strongSelf->_qrRefreshTimer invalidate];
                strongSelf->_qrRefreshTimer = nil;
                TGLog(@"IOS6QR embedded authorized -> present main controller");
                [TGAppDelegateInstance presentMainController];
                return;
            }

            if (token.length != 0)
            {
                CGFloat qrSize = [strongSelf deviceScreen] == Inch35 ? 168.0f : 192.0f;
                UIImage *image = [strongSelf qrImageForLoginToken:token targetSize:qrSize];
                if (image != nil)
                {
                    strongSelf->_qrImageView.image = image;
                    strongSelf->_qrStatusLabel.text = @"";
                    TGLog(@"IOS6QR rendered token bytes=%d expires=%d", (int)token.length, expires);
                    [strongSelf scheduleQrRefreshAtExpires:expires];
                }
                else
                {
                    strongSelf->_qrStatusLabel.text = TGLocalized(@"Login.QRError");
                    [strongSelf scheduleQrRefreshAtExpires:0];
                }
            }
            else
            {
                TGLog(@"IOS6QR UI error=%@", errorText ?: @"unknown");
                strongSelf->_qrStatusLabel.text = TGLocalized(@"Login.QRError");
                [strongSelf scheduleQrRefreshAtExpires:0];
            }

            if (strongSelf->_qrRefreshPending)
            {
                strongSelf->_qrRefreshPending = false;
                [strongSelf refreshQrLoginToken];
            }
        });
    }];
}

- (void)setupQrLoginView
{
    self.view.backgroundColor = [UIColor whiteColor];

    _qrTitleLabel = [[UILabel alloc] init];
    _qrTitleLabel.backgroundColor = [UIColor clearColor];
    _qrTitleLabel.textColor = [UIColor blackColor];
    _qrTitleLabel.font = TGMediumSystemFontOfSize(27.0f);
    _qrTitleLabel.textAlignment = NSTextAlignmentCenter;
    _qrTitleLabel.hidden = true;
    [self.view addSubview:_qrTitleLabel];

    _qrHelpLabel = [[UILabel alloc] init];
    _qrHelpLabel.backgroundColor = [UIColor clearColor];
    _qrHelpLabel.textColor = UIColorRGB(0x777777);
    _qrHelpLabel.font = TGSystemFontOfSize(14.0f);
    _qrHelpLabel.textAlignment = NSTextAlignmentCenter;
    _qrHelpLabel.numberOfLines = 2;
    _qrHelpLabel.hidden = true;
    [self.view addSubview:_qrHelpLabel];

    _qrContainerView = [[UIView alloc] init];
    _qrContainerView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_qrContainerView];

    _qrImageView = [[UIImageView alloc] init];
    _qrImageView.backgroundColor = [UIColor whiteColor];
    _qrImageView.contentMode = UIViewContentModeCenter;
    [_qrContainerView addSubview:_qrImageView];

    _qrStatusLabel = [[UILabel alloc] init];
    _qrStatusLabel.backgroundColor = [UIColor clearColor];
    _qrStatusLabel.textColor = UIColorRGB(0x888888);
    _qrStatusLabel.font = TGSystemFontOfSize(13.0f);
    _qrStatusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_qrStatusLabel];

    _startButton = [[TGModernButton alloc] init];
    ((TGModernButton *)_startButton).modernHighlight = true;
    [_startButton setTitleColor:TGAccentColor() forState:UIControlStateNormal];
    [_startButton.titleLabel setFont:TGMediumSystemFontOfSize(17.0f)];
    [_startButton addTarget:self action:@selector(startButtonPress) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_startButton];

    _alternativeLanguageButton.hidden = true;
    [self updateQrLocalization];
}

- (void)showQrLoginView
{
    if (!_qrLoginEnabled || _displayingQrLogin)
        return;

    _displayingQrLogin = true;
    [self stopTimer];
    [self freeGL];

    [_pageScrollView removeFromSuperview];
    _pageScrollView = nil;
    [_pageControl removeFromSuperview];
    _pageControl = nil;
    for (UIView *pageView in _pageViews)
        [pageView removeFromSuperview];
    _pageViews = nil;
    [_stillLogoView removeFromSuperview];
    _stillLogoView = nil;
    [_startButton removeFromSuperview];
    _startButton = nil;
    _alternativeLanguageButton.hidden = true;

    [self setupQrLoginView];
    [self.view setNeedsLayout];
    [self refreshQrLoginToken];
    TGLog(@"IOS6QR show QR login screen");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];

    [self loadGL];
    
    bool isIpad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
    
    _pageScrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    _pageScrollView.clipsToBounds = true;
    _pageScrollView.opaque = true;
    _pageScrollView.clearsContextBeforeDrawing = false;
    [_pageScrollView setShowsHorizontalScrollIndicator:false];
    [_pageScrollView setShowsVerticalScrollIndicator:false];
    _pageScrollView.pagingEnabled = true;
    _pageScrollView.contentSize = CGSizeMake(_headlines.count * self.view.bounds.size.width, self.view.bounds.size.height);
    _pageScrollView.delegate = self;
    [self.view addSubview:_pageScrollView];
    
    _pageViews = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < _headlines.count; i++)
    {
        RMIntroPageView *p = [[RMIntroPageView alloc]initWithFrame:CGRectMake(i * self.view.bounds.size.width, 0, self.view.bounds.size.width, 0) headline:[_headlines objectAtIndex:i] description:[_descriptions objectAtIndex:i]];
        p.opaque = true;
        p.clearsContextBeforeDrawing = false;
        [_pageViews addObject:p];
        [_pageScrollView addSubview:p];
    }
    [_pageScrollView setPage:0];
    
    _startButton = [[TGModernButton alloc] init];
    ((TGModernButton *)_startButton).modernHighlight = false;
    [_startButton setTitle:TGLocalized(@"Tour.StartButton") forState:UIControlStateNormal];
    [_startButton.titleLabel setFont:TGMediumSystemFontOfSize(20.0f)];
    [_startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0f, 48.0f), false, 0.0f);
        CGContextRef contextRef = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(contextRef, UIColorRGB(0x2ca5e0).CGColor);
        CGContextFillEllipseInRect(contextRef, CGRectMake(0.0f, 0.0f, 48.0f, 48.0f));
        UIImage *startButtonImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:24 topCapHeight:24];
        UIGraphicsEndImageContext();
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0f, 48.0f), false, 0.0f);
        contextRef = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(contextRef, UIColorRGB(0x227eab).CGColor);
        CGContextFillEllipseInRect(contextRef, CGRectMake(0.0f, 0.0f, 48.0f, 48.0f));
        UIImage *startButtonHighlightedImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:24 topCapHeight:24];
        UIGraphicsEndImageContext();
        
        [_startButton setBackgroundImage:startButtonImage forState:UIControlStateNormal];
        [_startButton setBackgroundImage:startButtonHighlightedImage forState:UIControlStateHighlighted];
        [_startButton setContentEdgeInsets:UIEdgeInsetsMake(0.0f, 20.0f, 0.0f, 20.0f)];
    }
    _startArrow = [[UIImageView alloc]initWithImage:TGImageNamed(isIpad ? @"start_arrow_ipad.png" : @"start_arrow.png")];
    _startButton.titleLabel.clipsToBounds = false;
    _startArrow.frame = CGRectChangedOrigin(_startArrow.frame, CGPointMake([_startButton.titleLabel.text sizeWithFont:_startButton.titleLabel.font].width + (isIpad ? 7 : 6), isIpad ? 6.5f : 4.5f));
    //[_startButton.titleLabel addSubview:_startArrow];
    [self.view addSubview:_startButton];
    
    [self.view addSubview:_alternativeLanguageButton];
    
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    _pageControl.userInteractionEnabled = false;
    // These tint APIs are not available on iOS 5.
    if ([_pageControl respondsToSelector:@selector(setPageIndicatorTintColor:)])
        [_pageControl setPageIndicatorTintColor:[UIColor colorWithWhite:.85 alpha:1]];
    if ([_pageControl respondsToSelector:@selector(setCurrentPageIndicatorTintColor:)])
        [_pageControl setCurrentPageIndicatorTintColor:[UIColor colorWithWhite:.2 alpha:1]];
    [_pageControl setNumberOfPages:6];
    [self.view addSubview:_pageControl];
}

- (BOOL)shouldAutorotate
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return true;
    
    return false;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAll;
    
    return UIInterfaceOrientationMaskPortrait;
}

- (DeviceScreen)deviceScreen
{
    CGSize viewSize = self.view.frame.size;
    int max = (int)MAX(viewSize.width, viewSize.height);
    
    DeviceScreen deviceScreen = Inch55;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        switch (max)
        {
            case 1366:
                deviceScreen = iPadPro;
                break;
                
            default:
                deviceScreen = iPad;
                break;
        }
    }
    else
    {
        switch (max)
        {
            case 480:
                deviceScreen = Inch35;
                break;
            case 568:
                deviceScreen = Inch4;
                break;
            case 667:
                deviceScreen = Inch47;
                break;
            default:
                deviceScreen = Inch55;
                break;
        }
    }
    
    return deviceScreen;
}

- (void)viewWillLayoutSubviews
{
    [self layoutIntroViews];
}

- (void)layoutIntroViews
{
    if (_displayingQrLogin)
    {
        CGFloat width = self.view.bounds.size.width;
        CGFloat height = self.view.bounds.size.height;
        CGFloat qrSize = [self deviceScreen] == Inch35 ? 176.0f : 210.0f;
        CGFloat phoneButtonHeight = 44.0f;
        CGFloat phoneBottom = 18.0f;
        _startButton.frame = CGRectMake(20.0f, height - phoneBottom - phoneButtonHeight, width - 40.0f, phoneButtonHeight);

        CGFloat availableBottom = CGRectGetMinY(_startButton.frame) - 26.0f;
        CGFloat availableTop = (iosMajorVersion() >= 7) ? 30.0f : 20.0f;
        CGFloat availableHeight = availableBottom - availableTop;
        if (qrSize > availableHeight)
            qrSize = MAX(140.0f, availableHeight);
        CGFloat qrY = availableTop + floor((availableHeight - qrSize) / 2.0f);
        _qrContainerView.frame = CGRectMake(CGFloor((width - qrSize) / 2.0f), qrY, qrSize, qrSize);
        _qrImageView.frame = _qrContainerView.bounds;
        _qrStatusLabel.frame = CGRectMake(16.0f, CGRectGetMaxY(_qrContainerView.frame) + 3.0f, width - 32.0f, 20.0f);
        return;
    }
    UIInterfaceOrientation isVertical = (self.view.bounds.size.height / self.view.bounds.size.width > 1.0f);
    
    CGFloat statusBarHeight = (iosMajorVersion() >= 7) ? 0 : 20;
    
    CGFloat pageControlY = 0;
    CGFloat glViewY = 0;
    CGFloat startButtonY = 0;
    CGFloat pageY = 0;
    
    CGFloat languageButtonSpread = 60.0f;
    CGFloat languageButtonOffset = 26.0f;
    
    DeviceScreen deviceScreen = [self deviceScreen];
    switch (deviceScreen)
    {
        case iPad:
            glViewY = isVertical ? 121 + 90 : 121;
            startButtonY = 120;
            pageY = isVertical ? 485 : 335;
            pageControlY = pageY + 200.0f;
            break;
        
        case iPadPro:
            glViewY = isVertical ? 221 + 110 : 221;
            startButtonY = 120;
            pageY = isVertical ? 605 : 435;
            pageControlY = pageY + 200.0f;
            break;
            
        case Inch35:
            pageControlY = 162 / 2;
            glViewY = 62 - 20;
            startButtonY = 75;
            pageY = 215;
            pageControlY = pageY + 160.0f;
            if (!_alternativeLanguageButton.isHidden) {
                glViewY -= 40.0f;
                pageY -= 40.0f;
                pageControlY -= 40.0f;
                startButtonY -= 30.0f;
            }
            languageButtonSpread = 65.0f;
            languageButtonOffset = 15.0f;
            break;
            
        case Inch4:
            glViewY = 62;
            startButtonY = 75;
            pageY = 245;
            pageControlY = pageY + 160.0f;
            languageButtonSpread = 50.0f;
            languageButtonOffset = 20.0f;
            break;

        case Inch47:
            pageControlY = 162 / 2 + 10;
            glViewY = 62 + 25;
            startButtonY = 75 + 5;
            pageY = 245 + 50;
            pageControlY = pageY + 160.0f;
            break;

        case Inch55:
            glViewY = 62 + 45;
            startButtonY = 75 + 20;
            pageY = 245 + 85;
            pageControlY = pageY + 160.0f;
            break;
            
        default:
            break;
    }
    
    if (_glkView.hidden) {
        pageY -= 54.0;
        pageControlY -= 54.0;
    }
    
    if (!_alternativeLanguageButton.isHidden) {
        startButtonY += languageButtonSpread;
    }
    
    _pageControl.frame = CGRectMake(0, pageControlY, self.view.bounds.size.width, 7);
    _glkView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
    
    [_startButton sizeToFit];
    _startButton.frame = CGRectMake(CGFloor((self.view.bounds.size.width - _startButton.frame.size.width) / 2.0f), self.view.bounds.size.height - startButtonY - statusBarHeight, _startButton.frame.size.width, 48.0f);
    [_startButton addTarget:self action:@selector(startButtonPress) forControlEvents:UIControlEventTouchUpInside];
    
    _alternativeLanguageButton.frame = CGRectMake(CGFloor((self.view.bounds.size.width - _alternativeLanguageButton.frame.size.width) / 2.0f), CGRectGetMaxY(_startButton.frame) + languageButtonOffset, _alternativeLanguageButton.frame.size.width, _alternativeLanguageButton.frame.size.height);
    
    _pageScrollView.frame=CGRectMake(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 20);
    _pageScrollView.contentSize=CGSizeMake(_headlines.count * self.view.bounds.size.width, 150);
    _pageScrollView.contentOffset = CGPointMake(_currentPage * self.view.bounds.size.width, 0);
    
    [_pageViews enumerateObjectsUsingBlock:^(UIView *pageView, NSUInteger index, __unused BOOL *stop)
    {
        pageView.frame = CGRectMake(index * self.view.bounds.size.width, (pageY - statusBarHeight), self.view.bounds.size.width, 150);
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:true animated:false];
    [self layoutIntroViews];

    if (_displayingQrLogin)
    {
        [self refreshQrLoginToken];
        return;
    }
    
    if (_stillLogoView == nil && !_displayedStillLogo)
    {
        _displayedStillLogo = true;
        
        _stillLogoView = [[UIImageView alloc] initWithImage:TGImageNamed(@"telegram_logo_still.png")];
        _stillLogoView.contentMode = UIViewContentModeCenter;
        _stillLogoView.bounds = CGRectMake(0, 0, 200, 200);
        
        UIInterfaceOrientation isVertical = (self.view.bounds.size.height / self.view.bounds.size.width > 1.0f);
        
        CGFloat statusBarHeight = (iosMajorVersion() >= 7) ? 0 : 20;
        
        CGFloat glViewY = 0;
        DeviceScreen deviceScreen = [self deviceScreen];
        switch (deviceScreen)
        {
            case iPad:
                glViewY = isVertical ? 121 + 90 : 121;
                break;
                
            case iPadPro:
                glViewY = isVertical ? 221 + 110 : 221;
                break;
                
            case Inch35:
                glViewY = 62 - 20;
                break;
                
            case Inch4:
                glViewY = 62;
                break;
                
            case Inch47:
                glViewY = 62 + 25;
                break;
                
            case Inch55:
                glViewY = 62 + 45;
                break;
                
            default:
                break;
        }
        
        CGFloat logoSize = 200.0f;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            logoSize *= 1.2f;
        _stillLogoView.frame = CGRectMake(CGFloor((self.view.bounds.size.width - logoSize) / 2.0f), glViewY - statusBarHeight, logoSize, logoSize);
        [self.view addSubview:_stillLogoView];
    }
    
    [self loadGL];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (_displayingQrLogin)
    {
        [self refreshQrLoginToken];
        return;
    }
    
    if (_stillLogoView != nil && _isOpenGLLoaded)
    {
        [_stillLogoView removeFromSuperview];
        _stillLogoView = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:false animated:false];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutIntroViews];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    if (_displayingQrLogin)
    {
        [_qrRefreshTimer invalidate];
        _qrRefreshTimer = nil;
        if (_qrLoginRequestToken != nil)
        {
            [TGTelegraphInstance cancelRequestByToken:_qrLoginRequestToken softCancel:true];
            _qrLoginRequestToken = nil;
        }
        _qrRequestInProgress = false;
        return;
    }
    
    [self freeGL];
}

- (void)startButtonPress
{
    if (_alternativeLocalizationInfo != nil) {
        [TGDatabaseInstance() setCustomProperty:@"checkedLocalization" value:[_alternativeLocalizationInfo.info.code dataUsingEncoding:NSUTF8StringEncoding]];
    }

    if (_qrLoginEnabled)
    {
        TGLog(@"IOS6QR push separate QR controller");
        TGIOS6QRLoginController *qrController = [[TGIOS6QRLoginController alloc] init];
        [self.navigationController pushViewController:qrController animated:true];
        return;
    }
    
    TGLoginPhoneController *phoneController = [[TGLoginPhoneController alloc] init];
    [self.navigationController pushViewController:phoneController animated:true];
}

- (void)updateAndRender
{
    [_glkView display];
    
    TGDispatchOnMainThread(^
    {
        if (_stillLogoView != nil)
        {
            [_stillLogoView removeFromSuperview];
            _stillLogoView = nil;
        }
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_willEnterBackgroundObserver];
    if (_qrLoginUpdateObserver != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:_qrLoginUpdateObserver];
    [_qrRefreshTimer invalidate];
    if (_qrLoginRequestToken != nil)
        [TGTelegraphInstance cancelRequestByToken:_qrLoginRequestToken softCancel:true];
    
    [self freeGL];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_glkView.context];
    
    
    set_telegram_textures(setup_texture(@"telegram_sphere.png"), setup_texture(@"telegram_plane.png"));
    
    set_ic_textures(setup_texture(@"ic_bubble_dot.png"), setup_texture(@"ic_bubble.png"), setup_texture(@"ic_cam_lens.png"), setup_texture(@"ic_cam.png"), setup_texture(@"ic_pencil.png"), setup_texture(@"ic_pin.png"), setup_texture(@"ic_smile_eye.png"), setup_texture(@"ic_smile.png"), setup_texture(@"ic_videocam.png"));
    
    set_fast_textures(setup_texture(@"fast_body.png"), setup_texture(@"fast_spiral.png"), setup_texture(@"fast_arrow.png"), setup_texture(@"fast_arrow_shadow.png"));
    
    set_free_textures(setup_texture(@"knot_up.png"), setup_texture(@"knot_down.png"));
    
    set_powerful_textures(setup_texture(@"powerful_mask.png"), setup_texture(@"powerful_star.png"), setup_texture(@"powerful_infinity.png"), setup_texture(@"powerful_infinity_white.png"));
    
     set_private_textures(setup_texture(@"private_door.png"), setup_texture(@"private_screw.png"));
    
    
    set_need_pages(0);
    
    
    on_surface_created();
    on_surface_changed(200, 200, 1, 0,0,0,0,0);
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)__unused view drawInRect:(CGRect)__unused rect
{
    double time = CFAbsoluteTimeGetCurrent();
    
    set_page((int)_currentPage);
    set_date(time);
    
    on_draw_frame();
}

static CGFloat x;
static bool justEndDragging;

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)__unused decelerate
{
    x = scrollView.contentOffset.x;
    justEndDragging = true;
}

NSInteger _current_page_end;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = (scrollView.contentOffset.x - _currentPage * scrollView.frame.size.width) / self.view.frame.size.width;
    
    set_scroll_offset((float)offset);
    
    if (justEndDragging)
    {
        justEndDragging = false;
        
        CGFloat page = scrollView.contentOffset.x / scrollView.frame.size.width;
        CGFloat sign = scrollView.contentOffset.x - x;
        
        if (sign > 0)
        {
            if (page > _currentPage)
                _currentPage++;
        }
        
        if (sign < 0)
        {
            if (page < _currentPage)
                _currentPage--;
        }
        
        _currentPage = MAX(0, MIN(5, _currentPage));
        _current_page_end = _currentPage;
    }
    else
    {
        if (_pageScrollView.contentOffset.x > _current_page_end*_pageScrollView.frame.size.width)
        {
            if (_pageScrollView.currentPageMin > _current_page_end) {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
        else
        {
            if (_pageScrollView.currentPageMax < _current_page_end)
            {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
    }
    
    [_pageControl setCurrentPage:_currentPage];
}

- (void)updateLocalization {
    if (_displayingQrLogin)
    {
        [self updateQrLocalization];
        [self.view setNeedsLayout];
        return;
    }

    [_startButton setTitle:TGLocalized(@"Tour.StartButton") forState:UIControlStateNormal];
    
    _headlines = @[ TGLocalized(@"Tour.Title1"), TGLocalized(@"Tour.Title2"),  TGLocalized(@"Tour.Title6"), TGLocalized(@"Tour.Title3"), TGLocalized(@"Tour.Title4"), TGLocalized(@"Tour.Title5")];
    _descriptions = @[TGLocalized(@"Tour.Text1"), TGLocalized(@"Tour.Text2"),  TGLocalized(@"Tour.Text6"), TGLocalized(@"Tour.Text3"), TGLocalized(@"Tour.Text4"), TGLocalized(@"Tour.Text5")];
}

- (void)alternativeLanguageButtonPressed {
    NSString *languageCode = _alternativeLocalizationInfo != nil ? _alternativeLocalizationInfo.info.code : @"en";
    if (languageCode.length == 0)
        languageCode = @"en";

    [TGDatabaseInstance() setCustomProperty:@"checkedLocalization" value:[languageCode dataUsingEncoding:NSUTF8StringEncoding]];

    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    __unsafe_unretained RMIntroViewController *weakSelf = self;
    [[[[TGLocalizationSignals applyLocalization:languageCode] deliverOn:[SQueue mainQueue]] onDispose:^{
        TGDispatchOnMainThread(^{
            [progressWindow dismiss:true];
        });
    }] startWithNext:nil error:^(__unused id error) {
        __strong RMIntroViewController *strongSelf = weakSelf;
        if (strongSelf != nil && [languageCode isEqualToString:@"en"])
            [strongSelf startButtonPress];
    } completed:^{
        __strong RMIntroViewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf startButtonPress];
    }];
}

@end
