#import "TGMusicPlayerController.h"
#import <objc/runtime.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGLegacyComponentsContext.h"

#import "TGMusicPlayerFullView.h"
#import "TGTelegraph.h"

#import "TGPreparedLocalDocumentMessage.h"

#import "TGInterfaceManager.h"
#import "TGSharedMediaController.h"

#import "TGShareMenu.h"
#import "TGSendMessageSignals.h"

#import "TGAudioMediaAttachment+Telegraph.h"

static char TGMusicPlayerLegacyOverlayKey;

@interface TGMusicPlayerController () <UIGestureRecognizerDelegate>
{
    TGMusicPlayerFullView *_view;
    SMetaDisposable *_statusDisposable;
    __unsafe_unretained UIViewController *_legacyPresentationHost;
    bool _usesNativeContainment;
}
@end

@implementation TGMusicPlayerController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _statusDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_statusDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    __weak TGMusicPlayerController *weakSelf = self;
    _view = [[TGMusicPlayerFullView alloc] initWithFrame:self.view.bounds context:[TGLegacyComponentsContext shared] presentation:self.presentation];
    _view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _view.actionsPressed = ^
    {
        __strong TGMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf sharePressed];
    };
    _view.dismissed = ^
    {
        __strong TGMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf dismiss];
    };
    [self.view addSubview:_view];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_view layoutSubviews];
}

- (void)presentFromController:(UIViewController *)controller
{
    [controller.view endEditing:true];
    bool supportsContainment = iosMajorVersion() >= 5
        && [controller respondsToSelector:@selector(addChildViewController:)]
        && [self respondsToSelector:@selector(willMoveToParentViewController:)]
        && [self respondsToSelector:@selector(didMoveToParentViewController:)]
        && [self respondsToSelector:@selector(removeFromParentViewController)];
    if (supportsContainment)
    {
        _usesNativeContainment = true;
        [controller addChildViewController:self];
        self.view.frame = controller.view.bounds;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [controller.view addSubview:self.view];
        [self didMoveToParentViewController:controller];
    }
    else
    {
        TGMusicPlayerController *previous = objc_getAssociatedObject(controller, &TGMusicPlayerLegacyOverlayKey);
        [previous dismiss];
        _legacyPresentationHost = controller;
        _usesNativeContainment = false;
        objc_setAssociatedObject(controller, &TGMusicPlayerLegacyOverlayKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.view.frame = controller.view.bounds;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self viewWillAppear:false];
        [controller.view addSubview:self.view];
        [self viewDidAppear:false];
    }
}

- (void)dismiss
{
    if (_legacyPresentationHost != nil)
    {
        __attribute__((objc_precise_lifetime)) TGMusicPlayerController *keepAlive = self;
        UIViewController *host = _legacyPresentationHost;
        _legacyPresentationHost = nil;
        [keepAlive viewWillDisappear:false];
        [keepAlive.view removeFromSuperview];
        [keepAlive viewDidDisappear:false];
        objc_setAssociatedObject(host, &TGMusicPlayerLegacyOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    else if (_usesNativeContainment)
    {
        _usesNativeContainment = false;
        [self willMoveToParentViewController:nil];
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }
    else
        [self.view removeFromSuperview];
}

- (void)dismissAnimated:(bool)animated
{
    if (animated)
        [_view dismissAnimated:true completion:nil];
    else
        [self dismiss];
}

- (void)sharePressed
{
    __weak TGMusicPlayerController *weakSelf = self;
    [TGMusicPlayerController presentActionsInController:self statusDisposable:_statusDisposable sourceView:_view sourceRect:^CGRect
    {
        __strong TGMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return CGRectZero;
        return [strongSelf->_view.actionsButton convertRect:strongSelf->_view.actionsButton.bounds toView:strongSelf->_view];
    } dismiss:^
    {
        __strong TGMusicPlayerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_view dismissAnimated:true completion:nil];
    }];
}

+ (void)presentActionsInController:(TGViewController *)controller statusDisposable:(SMetaDisposable *)statusDisposable sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect dismiss:(void (^)(void))dismiss
{
    __weak TGViewController *weakController = controller;
    __weak UIView *weakSourceView = sourceView;
    [statusDisposable setDisposable:[[[[TGTelegraphInstance.musicPlayer playingStatus] take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(TGMusicPlayerStatus *status) {
        __strong TGViewController *strongController = weakController;
        __strong UIView *strongSourceView = weakSourceView;
        if (strongController == nil || strongSourceView == nil)
            return;
        
        NSString *path = nil;
        bool inSecretChat = false;
        if ([status.item.media isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            TGDocumentMediaAttachment *document = status.item.media;
            inSecretChat = (document.documentId == 0 && document.accessHash == 0);
            if (document.documentId != 0)
            {
                path = [[TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:document.documentId version:document.version] stringByAppendingPathComponent:[document safeFileName]];
            }
            else
            {
                path = [[TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:document.localDocumentId version:document.version] stringByAppendingPathComponent:[document safeFileName]];
            }
        }
        else if ([status.item.media isKindOfClass:[TGAudioMediaAttachment class]])
        {
            TGAudioMediaAttachment *audio = status.item.media;
            path = [audio localFilePath];
        }
        
        void (^shareAction)(NSArray *, NSString *) = ^(NSArray *peerIds, NSString *caption)
        {
            if (![status.item.media isKindOfClass:[TGDocumentMediaAttachment class]])
                return;
            
            TGDocumentMediaAttachment *document = (TGDocumentMediaAttachment *)status.item.media;
            [[TGShareSignals shareDocument:document toPeerIds:peerIds caption:caption] startWithNext:nil];
        };
        
        if (inSecretChat)
            shareAction = nil;
        
        SSignal *externalSignal = status.downloadedStatus.downloaded ? [SSignal single:[NSURL fileURLWithPath:path]] : nil;
        
        [TGShareMenu presentInParentController:strongController menuController:nil buttonTitle:status.item.conversationId != 0 ? TGLocalized(@"SharedMedia.ViewInChat") : nil buttonAction:^
        {
            if (![status.item.key isKindOfClass:[NSNumber class]])
                return;
            
            int32_t messageId = [(NSNumber *)status.item.key intValue];
            [[TGInterfaceManager instance] navigateToConversationWithId:status.item.conversationId conversation:nil performActions:nil atMessage:@{ @"mid": @(messageId), @"useExisting": @true } clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
            
            if (dismiss != nil)
                dismiss();
        } shareAction:shareAction externalShareItemSignal:externalSignal sourceView:strongSourceView sourceRect:sourceRect barButtonItem:nil];
    }]];
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

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if (!TGIsPad())
        return UIInterfaceOrientationPortrait;
    
    return [super preferredInterfaceOrientationForPresentation];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    _view.safeAreaInset = self.controllerSafeAreaInset;
}

@end
