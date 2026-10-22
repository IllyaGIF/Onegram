#import "TGAccountSwitcher.h"

#import <libkern/OSAtomic.h>
#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGCache.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGEmbedCoubPlayerView.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTFileBasedKeychain.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRpcError.h"

#import "TL/TLMetaScheme.h"

#import "TGAccountManager.h"
#import "TGAppDelegate.h"
#import "TGCallManager.h"
#import "TGCustomAlertView.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"
#import "TGUserDefaults.h"

#import "TGChannelManagementSignals.h"
#import "TGChannelStateSignals.h"
#import "TGCommunitySignals.h"
#import "TGFavoriteStickersSignal.h"
#import "TGImageDownloadActor.h"
#import "TGLiveUploadActor.h"
#import "TGMaskStickersSignals.h"
#import "TGModernConversationCompanion.h"
#import "TGModernSendCommonMessageActor.h"
#import "TGPassportSignals.h"
#import "TGPeerInfoSignals.h"
#import "TGPollSignals.h"
#import "TGPrivateModernConversationCompanion.h"
#import "TGRecentContextBotsSignal.h"
#import "TGRecentGifsSignal.h"
#import "TGRecentMaskStickersSignal.h"
#import "TGRecentStickersSignal.h"
#import "TGStickersSignals.h"
#import "TGSynchronizeContactsActor.h"
#import "TGUpdateStateRequestBuilder.h"
#import "TGVideoDownloadActor.h"

NSString *const TGAccountSwitcherAccountsDidChangeNotification = @"TGAccountSwitcherAccountsDidChangeNotification";

static const NSTimeInterval TGAccountSwitcherDuplicateLogoutTimeout = 5.0;
static const NSTimeInterval TGAccountSwitcherProgressDelay = 0.3;

@interface TGAccountSwitcher ()
{
    volatile int32_t _switching;
    UIWindow *_overlayWindow;
    NSString *_returnAccountId;
}

@end

@implementation TGAccountSwitcher

+ (TGAccountSwitcher *)instance
{
    static TGAccountSwitcher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[TGAccountSwitcher alloc] init];
    });
    return instance;
}

- (bool)isSwitching
{
    return OSAtomicAdd32Barrier(0, &_switching) != 0;
}

- (bool)canCancelAddingAccount
{
    TGAccountManager *manager = [TGAccountManager instance];
    return [manager activeAccount].userId == 0 && [manager authorizedAccounts].count != 0;
}

- (void)postAccountsDidChange
{
    TGDispatchOnMainThread(^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGAccountSwitcherAccountsDidChangeNotification object:self];
    });
}

#pragma mark - Public actions

- (bool)ensureCanSwitch
{
    if ([self isSwitching])
        return false;

    if (TGTelegraphInstance.callManager.hasActiveCall)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Accounts.CallInProgress") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        return false;
    }

    return true;
}

- (void)switchToAccount:(TGAccountRecord *)account
{
    if (account.userId == 0 || ![self ensureCanSwitch])
        return;

    [self performSwitchToAccount:account completion:nil];
}

+ (int32_t)receiverUserIdFromPayload:(NSDictionary *)payload
{
    if (![payload isKindOfClass:[NSDictionary class]])
        return 0;

    id value = payload[@"user_id"];
    if (value == nil)
    {
        NSDictionary *data = payload[@"data"];
        if ([data isKindOfClass:[NSDictionary class]])
            value = data[@"user_id"];
    }

    if ([value respondsToSelector:@selector(intValue)])
        return [value intValue];
    return 0;
}

- (void)routeNotificationPayload:(NSDictionary *)payload completion:(void (^)(bool routed))completion
{
    int32_t receiverUserId = [TGAccountSwitcher receiverUserIdFromPayload:payload];
    TGAccountRecord *account = receiverUserId == 0 ? nil : [[TGAccountManager instance] accountWithUserId:receiverUserId];
    TGAccountRecord *activeAccount = [[TGAccountManager instance] activeAccount];

    if (account == nil || [account.accountId isEqualToString:activeAccount.accountId])
    {
        if (completion != nil)
            completion(account != nil || receiverUserId == 0);
        return;
    }

    TGLog(@"ACCOUNTS notification.route userId=%d", receiverUserId);

    if (![self ensureCanSwitch] || ![self performSwitchToAccount:account completion:^(bool transferred)
    {
        if (completion != nil)
            completion(transferred);
    }])
    {
        if (completion != nil)
            completion(false);
    }
}

- (NSArray *)otherAuthorizedUserIds
{
    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *activeAccount = [manager activeAccount];
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    for (TGAccountRecord *account in [manager authorizedAccounts])
    {
        if (![account.accountId isEqualToString:activeAccount.accountId])
            [userIds addObject:@(account.userId)];
    }
    return userIds;
}

- (void)addAccount
{
    if (![self ensureCanSwitch])
        return;

    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *previousAccount = [manager activeAccount];
    TGAccountRecord *account = [manager createAccount];
    _returnAccountId = previousAccount.userId != 0 ? previousAccount.accountId : nil;

    bool started = [self performSwitchToAccount:account completion:^(bool transferred)
    {
        if (!transferred)
        {
            _returnAccountId = nil;
            [manager removeInactiveAccount:account];
        }
    }];

    if (!started)
    {
        _returnAccountId = nil;
        [manager removeInactiveAccount:account];
    }
}

- (void)cancelAddingAccount
{
    if (![self canCancelAddingAccount] || [self isSwitching])
        return;

    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *pendingAccount = [manager activeAccount];
    TGAccountRecord *targetAccount = [manager accountWithId:_returnAccountId];
    if (targetAccount.userId == 0)
        targetAccount = [manager authorizedAccounts].firstObject;
    _returnAccountId = nil;

    [self performSwitchToAccount:targetAccount completion:^(bool transferred)
    {
        if (transferred)
            [manager removeInactiveAccount:pendingAccount];
    }];
}

- (bool)switchToRemainingAccountAfterLogout
{
    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *loggedOutAccount = [manager activeAccount];
    if ([manager updateActiveAccountWithUserId:0 firstName:nil lastName:nil phoneNumber:nil])
        [self postAccountsDidChange];

    TGAccountRecord *targetAccount = [manager accountWithId:_returnAccountId];
    if (targetAccount.userId == 0)
        targetAccount = [manager authorizedAccounts].firstObject;
    _returnAccountId = nil;
    if (targetAccount == nil)
        return false;

    TGLog(@"ACCOUNTS logout.continue from=%@ to=%@", loggedOutAccount.accountId, targetAccount.accountId);
    return [self performSwitchToAccount:targetAccount completion:^(bool transferred)
    {
        if (transferred)
            [manager removeInactiveAccount:loggedOutAccount];
    }];
}

#pragma mark - Registry

- (void)refreshActiveAccount
{
    int32_t userId = TGTelegraphInstance.clientUserId;
    if (userId == 0)
        return;

    TGDatabase *database = TGDatabaseInstance();
    [database dispatchOnDatabaseThread:^
    {
        if (TGDatabaseInstance() != database)
            return;
        TGUser *user = [database loadUser:userId];
        if (user != nil)
            [self updateActiveAccountWithUser:user];
    } synchronous:false];
}

- (void)updateActiveAccountWithUser:(TGUser *)user
{
    if (user.uid == 0)
        return;

    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *account = [manager activeAccount];
    if (account == nil)
        return;

    if ([manager updateActiveAccountWithUserId:user.uid firstName:user.firstName lastName:user.lastName phoneNumber:user.phoneNumber])
        [self postAccountsDidChange];

    NSString *photoUrl = user.photoUrlSmall;
    NSString *avatarPath = [manager avatarPathForAccount:account];
    if (avatarPath == nil)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        if (photoUrl.length == 0)
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:avatarPath])
            {
                [[NSFileManager defaultManager] removeItemAtPath:avatarPath error:NULL];
                [self postAccountsDidChange];
            }
            return;
        }

        NSData *data = [[TGRemoteImageView sharedCache] cachedDataForUrl:photoUrl];
        if (data.length == 0)
            return;

        NSData *storedData = [[NSData alloc] initWithContentsOfFile:avatarPath];
        if ([storedData isEqualToData:data])
            return;

        if ([data writeToFile:avatarPath atomically:true])
            [self postAccountsDidChange];
    });
}

- (bool)consumeAuthorizationWithUserId:(int32_t)userId
{
    if (userId == 0)
        return false;

    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *activeAccount = [manager activeAccount];
    TGAccountRecord *existingAccount = [manager accountWithUserId:userId];

    if (existingAccount == nil || activeAccount == nil || [existingAccount.accountId isEqualToString:activeAccount.accountId])
    {
        if (activeAccount != nil && activeAccount.userId != userId)
        {
            if ([manager updateActiveAccountWithUserId:userId firstName:nil lastName:nil phoneNumber:nil])
                [self postAccountsDidChange];
            TGDispatchOnMainThread(^
            {
                _returnAccountId = nil;
            });
        }
        return false;
    }

    TGLog(@"ACCOUNTS duplicate userId=%d pending=%@ existing=%@", userId, activeAccount.accountId, existingAccount.accountId);

    TGDispatchOnMainThread(^
    {
        [self showOverlay];
    });

    __block bool resolved = false;
    void (^resolve)(void) = ^
    {
        if (resolved)
            return;
        resolved = true;

        TGDispatchOnMainThread(^
        {
            _returnAccountId = nil;
            bool started = [self performSwitchToAccount:existingAccount completion:^(bool transferred)
            {
                if (transferred)
                    [manager removeInactiveAccount:activeAccount];
            }];
            if (!started)
                [self dismissOverlay];
        });
    };

    TLRPCauth_logOut$auth_logOut *logout = [[TLRPCauth_logOut$auth_logOut alloc] init];
    [[TGTelegramNetworking instance] performRpc:logout completionBlock:^(__unused id<TLObject> response, __unused int64_t responseTime, MTRpcError *error)
    {
        if (error != nil)
            TGLog(@"ACCOUNTS duplicate.logout error=%@", error.errorDescription);
        dispatch_async([ActionStageInstance() globalStageDispatchQueue], resolve);
    } progressBlock:nil requiresCompletion:true requestClass:TGRequestClassGeneric];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TGAccountSwitcherDuplicateLogoutTimeout * NSEC_PER_SEC)), [ActionStageInstance() globalStageDispatchQueue], resolve);

    return true;
}

#pragma mark - Switch pipeline

+ (void)reloadAccountScopedModules
{
    [TGRecentGifsSignal reloadForAccountSwitch];
    [TGRecentStickersSignal reloadForAccountSwitch];
    [TGRecentMaskStickersSignal reloadForAccountSwitch];
    [TGFavoriteStickersSignal reloadForAccountSwitch];
    [TGRecentContextBotsSignal reloadForAccountSwitch];
    [TGStickersSignals reloadForAccountSwitch];
    [TGMaskStickersSignals reloadForAccountSwitch];
    [TGChannelManagementSignals reloadForAccountSwitch];
    [TGUpdateStateRequestBuilder reloadForAccountSwitch];
    [TGChannelStateSignals reloadForAccountSwitch];
    [TGPeerInfoSignals reloadForAccountSwitch];
    [TGPollSignals reloadForAccountSwitch];
    [TGCommunitySignals reloadForAccountSwitch];
    [TGLiveUploadActor reloadForAccountSwitch];
    [TGModernConversationCompanion reloadForAccountSwitch];
    [TGPrivateModernConversationCompanion reloadForAccountSwitch];
    [TGImageDownloadActor reloadForAccountSwitch];
    [TGVideoDownloadActor reloadForAccountSwitch];
    [TGModernSendCommonMessageActor reloadForAccountSwitch];
    [TGEmbedCoubPlayerView reloadForAccountSwitch];
    [[TGSynchronizeContactsManager instance] resetForAccountSwitch];
    [TGPassportSignals clearStoredPasswordHashes];
}

- (bool)performSwitchToAccount:(TGAccountRecord *)account completion:(void (^)(bool transferred))completion
{
    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *previousAccount = [manager activeAccount];
    if (account == nil || previousAccount == nil || [account.accountId isEqualToString:previousAccount.accountId] || [manager accountWithId:account.accountId] == nil)
        return false;

    if (!OSAtomicCompareAndSwap32Barrier(0, 1, &_switching))
        return false;

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    TGLog(@"ACCOUNTS switch.begin from=%@ to=%@", previousAccount.accountId, account.accountId);

    [self refreshActiveAccount];
    [self showOverlay];

    bool inheritSettings = account.userId == 0;

    [TGAppDelegateInstance saveSettings];
    [[TGUserDefaults standard] suspendForAccountSwitch];
    [TGAppDelegateInstance prepareInterfaceForAccountSwitch];

    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() cancelAllActors];
        [TGTelegraphInstance suspendAccountSessionForSwitch];
        [TGTelegramNetworking suspendInstanceForAccountSwitch];
        [MTFileBasedKeychain invalidateAllKeychains];
        [TGDatabase closeInstanceForAccountSwitch];

        NSError *error = nil;
        bool transferred = [manager transferActiveSlotToAccount:account error:&error];
        if (!transferred)
            TGLog(@"ACCOUNTS switch.transfer.failed code=%d", (int)error.code);

        [[TGUserDefaults standard] reloadAfterAccountSwitch];
        [TGDatabase openInstanceAfterAccountSwitch];
        [TGAccountSwitcher reloadAccountScopedModules];
        [[TGRemoteImageView sharedCache] clearCache:TGCacheMemory];
        [TGTelegramNetworking resumeInstanceCreationAfterAccountSwitch];

        dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
        {
            [ActionStageInstance() cancelAllActors];

            TGDispatchOnMainThread(^
            {
                [[TGUserDefaults standard] resumeAfterAccountSwitch];
                [TGAppDelegateInstance startSessionAfterAccountSwitch:inheritSettings && transferred];
                OSAtomicCompareAndSwap32Barrier(1, 0, &_switching);
                [self dismissOverlay];

                TGLog(@"ACCOUNTS switch.end transferred=%d time=%.3f", transferred ? 1 : 0, CFAbsoluteTimeGetCurrent() - startTime);

                if (completion != nil)
                    completion(transferred);

                [[NSNotificationCenter defaultCenter] postNotificationName:TGAccountSwitcherAccountsDidChangeNotification object:self];

                if (!transferred)
                    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Accounts.SwitchFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            });
        });
    }];

    return true;
}

#pragma mark - Overlay

- (void)showOverlay
{
    if (_overlayWindow != nil)
        return;

    UIWindow *sourceWindow = TGAppDelegateInstance.window;
    if (sourceWindow == nil)
        return;

    UIView *snapshotView = nil;
    if ([sourceWindow respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)])
    {
        snapshotView = [sourceWindow snapshotViewAfterScreenUpdates:false];
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(sourceWindow.bounds.size, true, 0.0f);
        [sourceWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        snapshotView = [[UIImageView alloc] initWithImage:image];
    }

    UIWindow *overlayWindow = [[UIWindow alloc] initWithFrame:sourceWindow.frame];
    overlayWindow.windowLevel = UIWindowLevelStatusBar - 0.01f;
    overlayWindow.backgroundColor = [UIColor blackColor];
    if (snapshotView != nil)
    {
        snapshotView.frame = overlayWindow.bounds;
        snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [overlayWindow addSubview:snapshotView];
    }
    overlayWindow.hidden = false;
    _overlayWindow = overlayWindow;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TGAccountSwitcherProgressDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        if (_overlayWindow != overlayWindow)
            return;

        UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 80.0f, 80.0f)];
        progressView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.7f];
        progressView.layer.cornerRadius = 12.0f;
        progressView.center = CGPointMake(CGFloor(overlayWindow.bounds.size.width / 2.0f), CGFloor(overlayWindow.bounds.size.height / 2.0f));
        progressView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        indicator.center = CGPointMake(40.0f, 40.0f);
        [indicator startAnimating];
        [progressView addSubview:indicator];

        progressView.alpha = 0.0f;
        [overlayWindow addSubview:progressView];
        [UIView animateWithDuration:0.15 animations:^
        {
            progressView.alpha = 1.0f;
        }];
    });
}

- (void)dismissOverlay
{
    UIWindow *overlayWindow = _overlayWindow;
    if (overlayWindow == nil)
        return;
    _overlayWindow = nil;

    [UIView animateWithDuration:0.2 animations:^
    {
        overlayWindow.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        overlayWindow.hidden = true;
    }];
}

@end
