#import "TGPaidMessagesConfirmation.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGAppDelegate.h"
#import "TGPaidMessagesSignals.h"
#import "TGPaymentWebController.h"
#import "TGCustomActionSheet.h"
#import "TGCustomAlertView.h"

static CFAbsoluteTime TGPaidMessagesLastErrorTime = 0.0;

@implementation TGPaidMessagesConfirmation

+ (UIViewController *)topController
{
    UIViewController *controller = TGAppDelegateInstance.rootController;
    while (controller.presentedViewController != nil)
        controller = controller.presentedViewController;
    return controller;
}

+ (UIView *)sheetViewForController:(UIViewController *)controller
{
    UIViewController *target = controller ?: [self topController];
    return target.view;
}

+ (NSString *)priceStringForOption:(TGStarsTopUpOption *)option
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = option.currency;
    NSUInteger digits = formatter.maximumFractionDigits;
    double divisor = 1.0;
    for (NSUInteger i = 0; i < digits; i++)
        divisor *= 10.0;
    NSString *price = [formatter stringFromNumber:@((double)option.amount / divisor)];
    return price ?: [[NSString alloc] initWithFormat:@"%lld %@", option.amount, option.currency];
}

+ (void)confirmMessagesCount:(NSUInteger)count price:(int64_t)price peerId:(int64_t)peerId controller:(UIViewController *)controller completion:(void (^)(bool confirmed))completion
{
    if (completion == nil)
        return;
    if (price <= 0 || count == 0)
    {
        completion(true);
        return;
    }
    if (![TGPaidMessagesSignals needsConfirmationForPeerId:peerId price:price])
    {
        completion(true);
        return;
    }

    int64_t total = price * (int64_t)count;
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak UIViewController *weakController = controller;
    [[[TGPaidMessagesSignals starsBalance] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *balanceValue)
    {
        [progressWindow dismiss:true];
        __strong UIViewController *strongController = weakController;
        [self presentConfirmationForCount:count price:price total:total balance:[balanceValue longLongValue] peerId:peerId controller:strongController completion:completion];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        __strong UIViewController *strongController = weakController;
        [self presentConfirmationForCount:count price:price total:total balance:-1 peerId:peerId controller:strongController completion:completion];
    } completed:nil];
}

+ (void)confirmSendingToPeerIds:(NSArray *)peerIds messagesPerPeer:(NSUInteger)messagesPerPeer controller:(UIViewController *)controller completion:(void (^)(bool confirmed))completion
{
    if (completion == nil)
        return;
    if (peerIds.count == 0)
    {
        completion(true);
        return;
    }

    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.3];
    __weak UIViewController *weakController = controller;
    SSignal *signal = [[TGPaidMessagesSignals pricesForPeerIds:peerIds] mapToSignal:^SSignal *(NSDictionary *prices)
    {
        int64_t total = 0;
        NSMutableArray *paidPeerIds = [[NSMutableArray alloc] init];
        for (NSNumber *nPeerId in peerIds)
        {
            int64_t price = [prices[nPeerId] longLongValue];
            if (price > 0 && [TGPaidMessagesSignals needsConfirmationForPeerId:[nPeerId longLongValue] price:price])
            {
                total += price * (int64_t)MAX((NSUInteger)1, messagesPerPeer);
                [paidPeerIds addObject:nPeerId];
            }
        }
        if (paidPeerIds.count == 0)
            return [SSignal single:@{@"total": @0, @"peers": @[]}];
        return [[[TGPaidMessagesSignals starsBalance] catch:^SSignal *(__unused id error)
        {
            return [SSignal single:@(-1)];
        }] map:^id(NSNumber *balance)
        {
            return @{@"total": @(total), @"peers": paidPeerIds, @"balance": balance};
        }];
    }];
    [[signal deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *info)
    {
        [progressWindow dismiss:true];
        NSArray *paidPeerIds = info[@"peers"];
        int64_t total = [info[@"total"] longLongValue];
        if (paidPeerIds.count == 0 || total <= 0)
        {
            completion(true);
            return;
        }
        int64_t balance = [info[@"balance"] longLongValue];
        __strong UIViewController *strongController = weakController;
        NSString *title = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.ConfirmChats"), (int)paidPeerIds.count, [TGPaidMessagesSignals starsString:total]];
        if (balance >= 0)
            title = [[NSString alloc] initWithFormat:@"%@\n%@", title, [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Balance"), [TGPaidMessagesSignals starsString:balance]]];
        bool insufficient = balance >= 0 && balance < total;
        NSMutableArray *actions = [[NSMutableArray alloc] init];
        if (insufficient)
        {
            title = [[NSString alloc] initWithFormat:@"%@\n%@", title, TGLocalized(@"PaidMessages.NotEnoughStars")];
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.TopUp") action:@"topup"]];
        }
        else
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.SendFor"), [TGPaidMessagesSignals starsString:total]] action:@"send"]];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
        TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:title actions:actions actionBlock:^(__unused id target, NSString *action)
        {
            if ([action isEqualToString:@"send"])
            {
                [TGPaidMessagesSignals approveSendingToPeerIds:paidPeerIds];
                completion(true);
            }
            else if ([action isEqualToString:@"topup"])
            {
                [self presentTopUpFromController:strongController requiredStars:total - balance completion:^(bool toppedUp)
                {
                    if (toppedUp)
                        [self confirmSendingToPeerIds:peerIds messagesPerPeer:messagesPerPeer controller:strongController completion:completion];
                    else
                        completion(false);
                }];
            }
            else
                completion(false);
        } target:self];
        [actionSheet showInView:[self sheetViewForController:strongController]];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        completion(true);
    } completed:nil];
}

+ (void)presentConfirmationForCount:(NSUInteger)count price:(int64_t)price total:(int64_t)total balance:(int64_t)balance peerId:(int64_t)peerId controller:(UIViewController *)controller completion:(void (^)(bool confirmed))completion
{
    NSString *title = nil;
    if (count == 1)
        title = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.ConfirmSingle"), [TGPaidMessagesSignals starsString:price]];
    else
        title = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.ConfirmMultiple"), (int)count, [TGPaidMessagesSignals starsString:total]];
    if (balance >= 0)
        title = [[NSString alloc] initWithFormat:@"%@\n%@", title, [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Balance"), [TGPaidMessagesSignals starsString:balance]]];

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    bool insufficient = balance >= 0 && balance < total;
    if (insufficient)
    {
        title = [[NSString alloc] initWithFormat:@"%@\n%@", title, TGLocalized(@"PaidMessages.NotEnoughStars")];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.TopUp") action:@"topup"]];
    }
    else
    {
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.SendFor"), [TGPaidMessagesSignals starsString:total]] action:@"send"]];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.SendDontAsk") action:@"sendAlways"]];
    }
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    __weak UIViewController *weakController = controller;
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:title actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"send"])
            completion(true);
        else if ([action isEqualToString:@"sendAlways"])
        {
            [TGPaidMessagesSignals setConfirmationSkipped:true forPeerId:peerId price:price];
            completion(true);
        }
        else if ([action isEqualToString:@"topup"])
        {
            __strong UIViewController *strongController = weakController;
            [self presentTopUpFromController:strongController requiredStars:total - balance completion:^(bool toppedUp)
            {
                if (toppedUp)
                    [self confirmMessagesCount:count price:price peerId:peerId controller:strongController completion:completion];
                else
                    completion(false);
            }];
        }
        else
            completion(false);
    } target:self];
    [actionSheet showInView:[self sheetViewForController:controller]];
}

+ (void)presentTopUpFromController:(UIViewController *)controller requiredStars:(int64_t)requiredStars completion:(void (^)(bool toppedUp))completion
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak UIViewController *weakController = controller;
    [[[TGPaidMessagesSignals topUpOptions] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *options)
    {
        [progressWindow dismiss:true];
        __strong UIViewController *strongController = weakController;
        NSMutableArray *suitable = [[NSMutableArray alloc] init];
        for (TGStarsTopUpOption *option in options)
        {
            if (!option.extended || option.stars >= requiredStars)
                [suitable addObject:option];
        }
        if (suitable.count == 0)
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.TopUpUnavailable") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            if (completion)
                completion(false);
            return;
        }
        [self presentTopUpOptions:suitable requiredStars:requiredStars controller:strongController completion:completion];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.TopUpUnavailable") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        if (completion)
            completion(false);
    } completed:nil];
}

+ (void)presentTopUpOptions:(NSArray *)options requiredStars:(int64_t)requiredStars controller:(UIViewController *)controller completion:(void (^)(bool toppedUp))completion
{
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [options enumerateObjectsUsingBlock:^(TGStarsTopUpOption *option, NSUInteger index, __unused BOOL *stop)
    {
        NSString *title = [[NSString alloc] initWithFormat:@"%@ — %@", [TGPaidMessagesSignals starsString:option.stars], [self priceStringForOption:option]];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:[[NSString alloc] initWithFormat:@"%d", (int)index]]];
    }];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    NSString *title = requiredStars > 0 ? [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.TopUpRequired"), [TGPaidMessagesSignals starsString:requiredStars]] : TGLocalized(@"PaidMessages.TopUpTitle");
    __weak UIViewController *weakController = controller;
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:title actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"cancel"])
        {
            if (completion)
                completion(false);
            return;
        }
        NSInteger index = [action integerValue];
        if (index < 0 || index >= (NSInteger)options.count)
        {
            if (completion)
                completion(false);
            return;
        }
        __strong UIViewController *strongController = weakController;
        [self openTopUpOption:options[index] controller:strongController completion:completion];
    } target:self];
    [actionSheet showInView:[self sheetViewForController:controller]];
}

+ (void)openTopUpOption:(TGStarsTopUpOption *)option controller:(UIViewController *)controller completion:(void (^)(bool toppedUp))completion
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak UIViewController *weakController = controller;
    [[[TGPaidMessagesSignals topUpFormUrlForOption:option] deliverOn:[SQueue mainQueue]] startWithNext:^(NSString *url)
    {
        [progressWindow dismiss:true];
        __strong UIViewController *strongController = weakController ?: [self topController];
        TGPaymentWebController *webController = [[TGPaymentWebController alloc] initWithUrl:url confirmation:true canSave:false allowSaving:false];
        webController.completedConfirmation = ^
        {
            [strongController dismissViewControllerAnimated:true completion:^
            {
                if (completion)
                    completion(true);
            }];
        };
        TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[webController]];
        if (TGIsPad())
        {
            navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
            navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        [strongController presentViewController:navigationController animated:true completion:nil];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.TopUpUnavailable") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        if (completion)
            completion(false);
    } completed:nil];
}

+ (void)handleSendError:(NSString *)errorType peerId:(int64_t)peerId
{
    if (![TGPaidMessagesSignals isPaidMessagesError:errorType])
        return;

    int64_t stars = [TGPaidMessagesSignals starsFromPaymentRequiredError:errorType];
    if (stars > 0)
        [TGPaidMessagesSignals setCachedPrice:stars forPeerId:peerId];

    TGDispatchOnMainThread(^
    {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - TGPaidMessagesLastErrorTime < 2.0)
            return;
        TGPaidMessagesLastErrorTime = now;

        if ([errorType isEqualToString:@"BALANCE_TOO_LOW"])
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.BalanceTooLow") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"PaidMessages.TopUp") completionBlock:^(bool okButtonPressed)
            {
                if (okButtonPressed)
                    [self presentTopUpFromController:[self topController] requiredStars:0 completion:nil];
            }];
        }
        else
        {
            NSString *message = stars > 0 ? [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.PriceChanged"), [TGPaidMessagesSignals starsString:stars]] : TGLocalized(@"PaidMessages.PriceChangedGeneric");
            [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        }
    });
}

@end
