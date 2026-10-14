#import "TGAuthSessionsController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressSpinnerView.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGAuthSession.h"
#import "TGAppSession.h"
#import "TGAuthSessionListSignals.h"

#import "TGHeaderCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCommentCollectionItem.h"

#import "TGAuthSessionItem.h"
#import "TGAppSessionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"
#import "TGCustomActionSheet.h"

#import "TGCustomAlertView.h"
#import "TGTelegramNetworking.h"
#import "TGAccessChecker.h"
#import "../OnegramPlatform/OGPlatformQRCode.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"

#import "TGSegmentedTitleView.h"

#import "TGPresentation.h"

@interface TGAuthSessionsController () <ASWatcher, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    bool _viewingAppSessions;
    NSArray *_authSessions;
    NSArray *_appSessions;
    TGActivityIndicatorView *_activityIndicatorView;
    bool _sessionOperationInProgress;
    bool _sessionListLoading;
    bool _sessionListFailed;
    bool _confirmationVisible;
    TGProgressWindow *_sessionProgressWindow;
    UIImagePickerController *_qrPicker;
    
    TGSegmentedTitleView *_segmentedTitleView;
    
    SMetaDisposable *_authSessionListDisposable;
    SMetaDisposable *_removeSessionDisposable;
    
    SMetaDisposable *_appSessionListDisposable;
    
    bool _editing;
    bool _editButtonHidden;
    bool _updateScheduled;
    bool _updatePendingChanged;
    bool _appearanceTransition;
    bool _builtStateValid;
    NSArray *_builtAuthSessions;
    NSArray *_builtAppSessions;
    bool _builtViewingAppSessions;
    bool _builtEditing;
    bool _builtSessionListFailed;
    bool _builtSessionOperationInProgress;
    TGPresentation *_builtPresentation;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGAuthSessionsController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _authSessionListDisposable = [[SMetaDisposable alloc] init];
        _removeSessionDisposable = [[SMetaDisposable alloc] init];
        
        _appSessionListDisposable = [[SMetaDisposable alloc] init];
        
        _activityIndicatorView = [[TGActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [self updateSessionList];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _qrPicker.delegate = nil;
    [_sessionProgressWindow dismiss:false];
    [_authSessionListDisposable dispose];
    [_removeSessionDisposable dispose];
    
    [_appSessionListDisposable dispose];
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    [_segmentedTitleView setPresentation:presentation];
}

- (void)updateSessionList
{
    if (_sessionOperationInProgress || _sessionListLoading)
        return;
    _sessionListLoading = true;
    _sessionListFailed = false;
    __weak TGAuthSessionsController *weakSelf = self;
    [_authSessionListDisposable setDisposable:[[[TGAuthSessionListSignals authSessionList] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *authSessions)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_sessionListLoading = false;
            [strongSelf->_activityIndicatorView removeFromSuperview];
            strongSelf->_activityIndicatorView = nil;
            [strongSelf setAuthSessions:authSessions];
            
            [strongSelf updateAppSessionsList];
        }
    } error:^(id error)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_sessionListLoading = false;
            strongSelf->_sessionListFailed = true;
            [strongSelf->_activityIndicatorView removeFromSuperview];
            strongSelf->_activityIndicatorView = nil;
            [strongSelf _update:false];
            [strongSelf showSessionError:error];
        }
    } completed:nil]];
}

- (void)viewWillAppear:(BOOL)animated
{
    _appearanceTransition = animated;
    [super viewWillAppear:animated];
    [self updateSessionList];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _appearanceTransition = false;
    [self flushPendingUpdate];
}

- (void)viewWillDisappear:(BOOL)animated
{
    _appearanceTransition = animated;
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    _appearanceTransition = false;
    [self flushPendingUpdate];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    (void)notification;
    if ([self isViewLoaded] && self.view.window != nil && _qrPicker == nil)
        [self updateSessionList];
}

- (void)updateAppSessionsList
{
    __weak TGAuthSessionsController *weakSelf = self;
    [_appSessionListDisposable setDisposable:[[[TGAuthSessionListSignals loggedAppsSessionList] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *appSessions)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf setAppSessions:appSessions];
        }
    }]];
}

- (void)loadView
{
    [super loadView];
    
    self.collectionView.alpha = 1.0f;
    
    if (_activityIndicatorView != nil)
    {
        _activityIndicatorView.frame = CGRectMake(CGFloor((self.view.frame.size.width - _activityIndicatorView.frame.size.width) / 2.0f), CGFloor((self.view.frame.size.height - _activityIndicatorView.frame.size.height) / 2.0f), _activityIndicatorView.frame.size.width, _activityIndicatorView.frame.size.height);
        _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _activityIndicatorView.color = self.presentation.pallete.collectionMenuCommentColor;
        [_activityIndicatorView startAnimating];
        [self.view addSubview:_activityIndicatorView];
    }
    
    NSArray *items = @[TGLocalized(@"AuthSessions.Sessions"), TGLocalized(@"AuthSessions.LoggedIn")];
    _segmentedTitleView = [[TGSegmentedTitleView alloc] initWithTitle:TGLocalized(@"Settings.Devices") segments:items];
    [_segmentedTitleView setSegmentedControlHidden:_appSessions.count == 0 animated:false];
    [_segmentedTitleView setPresentation:self.presentation];
    __weak TGAuthSessionsController *weakSelf = self;
    _segmentedTitleView.segmentChanged = ^(NSInteger selectedIndex)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf)
            [strongSelf setAppSessionsSelected:selectedIndex == 1];
    };
    [self setTitleView:_segmentedTitleView];
    [self _updateNow:false];
}

- (void)setAuthSessions:(NSArray *)authSessions
{
    _authSessions = authSessions;
    [self _update:false];
}

- (void)setAppSessions:(NSArray *)appSessions
{
    _appSessions = appSessions;
    bool hidden = appSessions.count == 0;
    [_segmentedTitleView setSegmentedControlHidden:hidden animated:true];
    
    bool changed = false;
    if (appSessions.count == 0 && _viewingAppSessions)
    {
        changed = true;
        _viewingAppSessions = false;
    }
    
    [self _update:changed];
}

- (void)setAppSessionsSelected:(bool)appSessions
{
    bool changed = _viewingAppSessions != appSessions;
    _viewingAppSessions = appSessions;
    
    [self _update:changed];
}

- (void)_update:(bool)changed
{
    _updatePendingChanged = _updatePendingChanged || changed;
    if (_updateScheduled)
        return;
    _updateScheduled = true;
    __weak TGAuthSessionsController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        [strongSelf flushPendingUpdate];
    });
}

- (void)flushPendingUpdate
{
    if (!_updateScheduled || _appearanceTransition)
        return;
    _updateScheduled = false;
    bool changed = _updatePendingChanged;
    _updatePendingChanged = false;
    if (!changed && [self builtStateMatches])
        return;
    [self _updateNow:changed];
}

- (bool)builtStateMatches
{
    if (!_builtStateValid || _builtAuthSessions != _authSessions || _builtViewingAppSessions != _viewingAppSessions || _builtEditing != _editing || _builtSessionListFailed != _sessionListFailed || _builtSessionOperationInProgress != _sessionOperationInProgress || _builtPresentation != self.presentation)
        return false;
    if (_viewingAppSessions ? _builtAppSessions != _appSessions : (_builtAppSessions.count != 0) != (_appSessions.count != 0))
        return false;
    return self.collectionView.alpha > 1.0f - FLT_EPSILON;
}

- (void)_updateNow:(bool)changed
{
    _builtStateValid = true;
    _builtAuthSessions = _authSessions;
    _builtAppSessions = _appSessions;
    _builtViewingAppSessions = _viewingAppSessions;
    _builtEditing = _editing;
    _builtSessionListFailed = _sessionListFailed;
    _builtSessionOperationInProgress = _sessionOperationInProgress;
    _builtPresentation = self.presentation;
    if (changed)
    {
        UIView *snapshotView = [self.collectionView respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)] ? [self.collectionView snapshotViewAfterScreenUpdates:false] : nil;
        if (snapshotView != nil)
            [self.view insertSubview:snapshotView aboveSubview:self.collectionView];
        
        [UIView animateWithDuration:0.2 animations:^
        {
            snapshotView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
        
        self.collectionView.alpha = 0.0f;
    }
    
    if (_viewingAppSessions)
    {
        if (changed)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                self.collectionView.alpha = 1.0f;
            }];
        }
        
        while (self.menuSections.sections.count != 0)
        {
            [self.menuSections deleteSection:0];
        }
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        TGButtonCollectionItem *resetItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"AuthSessions.LogOutApplications") action:@selector(resetAppSessionsPressed)];
        resetItem.titleColor = self.presentation.pallete.collectionMenuDestructiveColor;
        resetItem.deselectAutomatically = true;
        [items addObject:resetItem];
        
        [items addObject:[[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"AuthSessions.LogOutApplicationsHelp")]];
        
        TGCollectionMenuSection *section = [[TGCollectionMenuSection alloc] initWithItems:items];
        UIEdgeInsets topSectionInsets = section.insets;
        topSectionInsets.top = 32.0f;
        section.insets = topSectionInsets;
        [self.menuSections addSection:section];
        
        items = [[NSMutableArray alloc] init];
        
        NSArray *sessions = @[];
        NSMutableArray *array = [[NSMutableArray alloc] initWithArray:_appSessions];
        [array sortUsingComparator:^NSComparisonResult(TGAppSession *session1, TGAppSession *session2)
        {
            return session1.dateActive > session2.dateActive ? NSOrderedAscending : NSOrderedDescending;
        }];
        sessions = array;
        
        [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"AuthSessions.LoggedInWithTelegram")]];
        
        for (TGAppSession *appSession in sessions)
        {
            __weak TGAuthSessionsController *weakSelf = self;
            [items addObject:[[TGAppSessionItem alloc] initWithAppSession:appSession removeRequested:^
            {
                __strong TGAuthSessionsController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf removeAppSession:appSession];
            }]];
        }
        
        TGCollectionMenuSection *sessionsSection = [[TGCollectionMenuSection alloc] initWithItems:items];
        [self.menuSections addSection:sessionsSection];
        
        if (!_editing)
        {
            [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editPressed)]];
        }

        [self.collectionView reloadData];
    }
    else
    {
        if (changed || (_authSessions.count > 0 && self.collectionView.alpha < FLT_EPSILON))
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                self.collectionView.alpha = 1.0f;
            }];
        }
        
        while (self.menuSections.sections.count != 0)
        {
            [self.menuSections deleteSection:0];
        }
        
        TGAuthSession *currentSession = nil;
        NSArray *otherSessions = @[];
        
        NSMutableArray *array = [[NSMutableArray alloc] init];
        for (TGAuthSession *session in _authSessions)
        {
            if (session.sessionHash == 0 || (session.flags & 1) != 0)
                currentSession = session;
            else
                [array addObject:session];
        }
        [array sortUsingComparator:^NSComparisonResult(TGAuthSession *session1, TGAuthSession *session2)
         {
             if (session1.dateActive == session2.dateActive)
                 return session1.sessionHash == session2.sessionHash ? NSOrderedSame : (session1.sessionHash < session2.sessionHash ? NSOrderedAscending : NSOrderedDescending);
             return session1.dateActive > session2.dateActive ? NSOrderedAscending : NSOrderedDescending;
         }];
        otherSessions = array;
        
        TGButtonCollectionItem *resetItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.EndOtherSessions") action:@selector(resetSessionsPressed)];
        resetItem.alignment = NSTextAlignmentCenter;
        resetItem.enabled = otherSessions.count != 0 && !_sessionOperationInProgress;
        resetItem.deselectAutomatically = true;

        if (currentSession != nil || _authSessions == nil)
        {
            NSMutableArray *items = [[NSMutableArray alloc] init];
            
            [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.ThisDevice")]];
            if (currentSession != nil)
                [items addObject:[[TGAuthSessionItem alloc] initWithAuthSession:currentSession removeRequested:nil]];
            else
                [items addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(_sessionListFailed ? @"Devices.LoadFailed" : @"Devices.Loading")]];
            [items addObject:resetItem];
            
            TGCollectionMenuSection *section = [[TGCollectionMenuSection alloc] initWithItems:items];
            UIEdgeInsets topSectionInsets = section.insets;
            topSectionInsets.top = 32.0f;
            section.insets = topSectionInsets;
            [self.menuSections addSection:section];
        }
        else
        {
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[resetItem]]];
        }

        TGButtonCollectionItem *scanItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.ScanQR") action:@selector(scanQRCodePressed)];
        scanItem.alignment = NSTextAlignmentCenter;
        scanItem.deselectAutomatically = true;
        scanItem.enabled = !_sessionOperationInProgress;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[scanItem]]];
        if (_sessionListFailed)
        {
            TGButtonCollectionItem *retryItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.Retry") action:@selector(updateSessionList)];
            retryItem.deselectAutomatically = true;
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[retryItem]]];
        }
        
        if (otherSessions.count != 0)
        {
            NSMutableArray *items = [[NSMutableArray alloc] init];
            [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.ActiveSessions")]];
            
            for (TGAuthSession *authSession in otherSessions)
            {
                __weak TGAuthSessionsController *weakSelf = self;
                [items addObject:[[TGAuthSessionItem alloc] initWithAuthSession:authSession removeRequested:^
                {
                    __strong TGAuthSessionsController *strongSelf = weakSelf;
                    if (strongSelf != nil)
                        [strongSelf removeSession:authSession];
                }]];
            }
            
            TGCollectionMenuSection *section = [[TGCollectionMenuSection alloc] initWithItems:items];
            [self.menuSections addSection:section];
            
            if (!_editing)
            {
                [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editPressed)]];
            }
        }
        else
        {
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
                [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Devices.ActiveSessions")],
                [[TGCommentCollectionItem alloc] initWithText:TGLocalized(_authSessions == nil ? (_sessionListFailed ? @"Devices.LoadFailed" : @"Devices.Loading") : @"Devices.NoOtherSessions")]
            ]]];
            if (_editing)
            {
                _editing = false;
                [self leaveEditingMode:true];
            }
            [self setLeftBarButtonItem:nil];
            [self setRightBarButtonItem:nil];
        }
        
        [self.collectionView reloadData];
    }
    
    bool editButtonHidden = false;
    if (_appSessions.count > 0)
    {
        CGFloat backWidth = [TGLocalized(@"Common.Back") sizeWithFont:TGSystemFontOfSize(17.0f)].width;
        CGFloat editWidth = [TGLocalized(@"Common.Edit") sizeWithFont:TGSystemFontOfSize(17.0f)].width;
        CGFloat width = _segmentedTitleView.innerWidth + backWidth + editWidth;
        
        if (width > TGScreenSize().width - 44.0f && !_editing)
        {
            [self setRightBarButtonItem:nil];
            editButtonHidden = true;
        }
    }
    _editButtonHidden = editButtonHidden;
}

- (void)editPressed
{
    [self enterEditingMode:true];
}

- (void)donePressed
{
    [self leaveEditingMode:true];
}

- (void)didEnterEditingMode:(bool)animated
{
    [super didEnterEditingMode:animated];
    _editing = true;
    
    if (_editButtonHidden)
        return;
    
    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)]];
}

- (void)didLeaveEditingMode:(bool)animated
{
    [super didLeaveEditingMode:animated];
    _editing = false;
    
    if (_editButtonHidden)
        return;
    
    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editPressed)]];
}

- (void)resetSessionsPressed
{
    bool hasOtherSessions = false;
    for (TGAuthSession *session in _authSessions)
        hasOtherSessions |= session.sessionHash != 0 && (session.flags & 1) == 0;
    if (hasOtherSessions)
        [self confirmRemovalOfSession:nil];
}

- (void)confirmRemovalOfSession:(TGAuthSession *)session
{
    if (_sessionOperationInProgress || _confirmationVisible)
        return;
    _confirmationVisible = true;
    NSString *message = session == nil ? TGLocalized(@"Devices.EndAllConfirmation") : [NSString stringWithFormat:TGLocalized(@"Devices.EndConfirmation"), session.deviceModel, session.appName];
    __weak TGAuthSessionsController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Settings.Devices") message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"AuthSessions.TerminateSession") destructive:true completionBlock:^(bool confirmed)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_confirmationVisible = false;
        if (confirmed)
            [strongSelf performSessionOperation:session == nil ? [TGAuthSessionListSignals removeAllOtherSessions] : [TGAuthSessionListSignals removeSession:session]];
    } disableKeyboardWorkaround:false];
}

- (void)showSessionError:(id)error
{
    NSString *type = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
    NSString *key = @"Devices.RequestFailed";
    if ([type isEqualToString:@"FRESH_RESET_AUTHORISATION_FORBIDDEN"])
        key = @"Devices.FreshSession";
    else if ([type hasPrefix:@"AUTH_TOKEN_"])
        key = @"Devices.QRExpired";
    else if ([type hasPrefix:@"FLOOD_WAIT"])
        key = @"Devices.FloodWait";
    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Settings.Devices") message:TGLocalized(key) cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

- (void)finishSessionOperation
{
    _sessionOperationInProgress = false;
    [_sessionProgressWindow dismiss:true];
    _sessionProgressWindow = nil;
    [self _update:false];
}

- (void)performSessionOperation:(SSignal *)signal
{
    if (_sessionOperationInProgress)
        return;
    [_authSessionListDisposable setDisposable:nil];
    _sessionListLoading = false;
    _sessionOperationInProgress = true;
    _sessionProgressWindow = [[TGProgressWindow alloc] init];
    [_sessionProgressWindow show:true];
    [self _update:false];
    __weak TGAuthSessionsController *weakSelf = self;
    [_removeSessionDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(id result)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil && [result isKindOfClass:[NSArray class]])
        {
            strongSelf->_sessionListFailed = false;
            [strongSelf setAuthSessions:result];
        }
    } error:^(id error)
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_sessionListFailed = true;
            [strongSelf finishSessionOperation];
            [strongSelf showSessionError:error];
        }
    } completed:^
    {
        __strong TGAuthSessionsController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf finishSessionOperation];
            [strongSelf updateSessionList];
        }
    }]];
}

- (void)scanQRCodePressed
{
    if (_sessionOperationInProgress || _qrPicker != nil || _confirmationVisible)
        return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Devices.ScanQR") message:TGLocalized(@"Devices.CameraUnavailable") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        return;
    }
    if (![[[TGAccessChecker alloc] init] checkCameraAuthorizationStatusForIntent:TGCameraAccessIntentDefault alertDismissCompletion:nil])
        return;
    _qrPicker = [[UIImagePickerController alloc] init];
    _qrPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    _qrPicker.delegate = self;
    _qrPicker.allowsEditing = false;
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 16, 296, 64)];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hint.text = TGLocalized(@"Devices.QRPhotoHint");
    hint.numberOfLines = 0;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.font = TGSystemFontOfSize(16.0f);
    hint.textColor = [UIColor whiteColor];
    hint.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55f];
    hint.userInteractionEnabled = false;
    _qrPicker.cameraOverlayView = hint;
    [self presentModalViewController:_qrPicker animated:true];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    picker.delegate = nil;
    [self dismissModalViewControllerAnimated:true];
    _qrPicker = nil;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    picker.delegate = nil;
    [self dismissModalViewControllerAnimated:false];
    _qrPicker = nil;
    _sessionOperationInProgress = true;
    _sessionProgressWindow = [[TGProgressWindow alloc] init];
    [_sessionProgressWindow show:true];
    __weak TGAuthSessionsController *weakSelf = self;
    dispatch_async(OGPlatformBackgroundQueue(), ^
    {
        @autoreleasepool
        {
            NSString *code = OGPlatformReadQRCode(image);
            NSData *token = [TGAuthSessionListSignals loginTokenFromQRCode:code];
            OGPlatformDispatchOnMainThread(^
            {
                __strong TGAuthSessionsController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                [strongSelf finishSessionOperation];
                if (token == nil)
                {
                    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Devices.ScanQR") message:TGLocalized(@"Devices.QRNotFound") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    return;
                }
                strongSelf->_confirmationVisible = true;
                [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Devices.LinkDevice") message:TGLocalized(@"Devices.LinkConfirmation") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Devices.LinkDevice") completionBlock:^(bool confirmed)
                {
                    __strong TGAuthSessionsController *controller = weakSelf;
                    if (controller == nil)
                        return;
                    controller->_confirmationVisible = false;
                    if (confirmed)
                        [controller performSessionOperation:[TGAuthSessionListSignals acceptLoginToken:token]];
                }];
            });
        }
    });
}

- (void)resetAppSessionsPressed
{
    __weak TGAuthSessionsController *weakSelf = self;
    
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"AuthSessions.LogOutApplications") action:@"remove" type:TGActionSheetActionTypeDestructive],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
        ] actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"remove"])
        {
            TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
            [progressWindow show:true];
            
            [_removeSessionDisposable setDisposable:[[[[TGAuthSessionListSignals removeAllAppSessions] deliverOn:[SQueue mainQueue]] onDispose:^
            {
                TGDispatchOnMainThread(^
                {
                    [progressWindow dismiss:true];
                });
            }] startWithNext:^(NSArray *authSessions)
            {
                __strong TGAuthSessionsController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf setAppSessions:authSessions];
            }]];
        }
    } target:self];
    [actionSheet showInView:self.view];
}

- (void)removeSession:(TGAuthSession *)authSession
{
    if (authSession.sessionHash == 0 || (authSession.flags & 1) != 0)
        return;
    [self confirmRemovalOfSession:authSession];
}

- (void)removeAppSession:(TGAppSession *)appSession
{
    __weak TGAuthSessionsController *weakSelf = self;
    
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"AuthSessions.LogOut") action:@"remove" type:TGActionSheetActionTypeDestructive],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
        ] actionBlock:^(__unused TGAuthSessionsController *target, NSString *action)
    {
        if ([action isEqualToString:@"remove"])
        {
            TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
            [progressWindow show:true];
            
            [_removeSessionDisposable setDisposable:[[[[TGAuthSessionListSignals removeAppSession:appSession] deliverOn:[SQueue mainQueue]] onDispose:^
            {
                TGDispatchOnMainThread(^
                {
                    [progressWindow dismiss:true];
                });
            }] startWithNext:^(NSArray *appSessions)
            {
                __strong TGAuthSessionsController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf setAppSessions:appSessions];
            }]];
        }
    } target:self];
    [actionSheet showInView:self.view];
}

@end
