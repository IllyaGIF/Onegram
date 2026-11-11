#import "TGPaidMessagesSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGTelegramNetworking.h"
#import "TGStoriesSignals.h"
#import "TGChannelManagementSignals.h"

NSString *const TGPaidMessagesPriceChangedNotification = @"TGPaidMessagesPriceChangedNotification";
NSString *const TGPaidMessagesPeerIdKey = @"peerId";
NSString *const TGPaidMessagesStarsKey = @"stars";

static NSString *const TGPaidMessagesConfirmedPricesKey = @"paidMessages.confirmedPrices";
static NSString *const TGPaidMessagesPaymentRequiredPrefix = @"ALLOW_PAYMENT_REQUIRED_";
static const int64_t TGPaidMessagesDefaultMaxStars = 10000;
static const int64_t TGPaidMessagesDefaultStars = 10;
static const int32_t TGPaidMessagesDefaultCommissionPermille = 850;

static NSMutableDictionary *TGPaidMessagesCachedPrices(void)
{
    static NSMutableDictionary *prices = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        prices = [[NSMutableDictionary alloc] init];
    });
    return prices;
}

static NSMutableDictionary *TGPaidMessagesApprovals(void)
{
    static NSMutableDictionary *approvals = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        approvals = [[NSMutableDictionary alloc] init];
    });
    return approvals;
}

static const NSTimeInterval TGPaidMessagesApprovalTimeout = 120.0;

static int64_t TGPaidMessagesConfigMaxStars = 0;
static int32_t TGPaidMessagesConfigCommission = 0;
static bool TGPaidMessagesConfigRequested = false;

@implementation TGPaidMessagesFreeLink

- (instancetype)initWithToken:(NSString *)token url:(NSString *)url expires:(int32_t)expires
{
    self = [super init];
    if (self != nil)
    {
        _token = [token copy] ?: @"";
        _url = [url copy] ?: @"";
        _expires = expires;
    }
    return self;
}

@end

@implementation TGStarsTopUpOption

- (instancetype)initWithObject:(TGTLDynamicObject *)object
{
    self = [super init];
    if (self != nil)
    {
        _stars = [object int64Field:@"stars"];
        _currency = [object stringField:@"currency"] ?: @"";
        _amount = [object int64Field:@"amount"];
        _extended = [object flag:@"extended"];
    }
    return self;
}

@end

@implementation TGPaidMessagesSignals

+ (void)requestConfigIfNeeded
{
    @synchronized ([TGPaidMessagesSignals class])
    {
        if (TGPaidMessagesConfigRequested)
            return;
        TGPaidMessagesConfigRequested = true;
    }

    [[TGTLDynamicRpc requestSignalWithMethod:@"help.getAppConfig" parameters:@{@"hash": @0}] startWithNext:^(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"help.appConfig"])
            return;
        TGTLDynamicObject *config = [result objectField:@"config"];
        for (TGTLDynamicObject *entry in [config arrayField:@"value"])
        {
            if (![entry isKindOfClass:[TGTLDynamicObject class]])
                continue;
            NSString *key = [entry stringField:@"key"];
            TGTLDynamicObject *value = [entry objectField:@"value"];
            if (![value isConstructor:@"jsonNumber"])
                continue;
            double number = [value doubleField:@"value"];
            @synchronized ([TGPaidMessagesSignals class])
            {
                if ([key isEqualToString:@"stars_paid_message_amount_max"] && number >= 1.0)
                    TGPaidMessagesConfigMaxStars = (int64_t)number;
                else if ([key isEqualToString:@"stars_paid_message_commission_permille"] && number >= 0.0 && number <= 1000.0)
                    TGPaidMessagesConfigCommission = (int32_t)number;
            }
        }
    } error:^(__unused id error)
    {
        @synchronized ([TGPaidMessagesSignals class])
        {
            TGPaidMessagesConfigRequested = false;
        }
    } completed:nil];
}

+ (int64_t)maxStarsPerMessage
{
    [self requestConfigIfNeeded];
    @synchronized ([TGPaidMessagesSignals class])
    {
        return TGPaidMessagesConfigMaxStars > 0 ? TGPaidMessagesConfigMaxStars : TGPaidMessagesDefaultMaxStars;
    }
}

+ (int64_t)defaultStarsPerMessage
{
    return MIN(TGPaidMessagesDefaultStars, [self maxStarsPerMessage]);
}

+ (int32_t)commissionPermille
{
    [self requestConfigIfNeeded];
    @synchronized ([TGPaidMessagesSignals class])
    {
        return TGPaidMessagesConfigCommission > 0 ? TGPaidMessagesConfigCommission : TGPaidMessagesDefaultCommissionPermille;
    }
}

+ (bool)hasCachedPriceForPeerId:(int64_t)peerId
{
    @synchronized (TGPaidMessagesCachedPrices())
    {
        return [TGPaidMessagesCachedPrices() objectForKey:@(peerId)] != nil;
    }
}

+ (int64_t)cachedPriceForPeerId:(int64_t)peerId
{
    @synchronized (TGPaidMessagesCachedPrices())
    {
        return [[TGPaidMessagesCachedPrices() objectForKey:@(peerId)] longLongValue];
    }
}

+ (void)setCachedPrice:(int64_t)stars forPeerId:(int64_t)peerId
{
    if (peerId == 0)
        return;
    stars = MAX(0, stars);
    bool changed = false;
    @synchronized (TGPaidMessagesCachedPrices())
    {
        NSNumber *previous = [TGPaidMessagesCachedPrices() objectForKey:@(peerId)];
        changed = previous == nil || [previous longLongValue] != stars;
        [TGPaidMessagesCachedPrices() setObject:@(stars) forKey:@(peerId)];
    }
    if (changed)
    {
        TGDispatchOnMainThread(^
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:TGPaidMessagesPriceChangedNotification object:nil userInfo:@{TGPaidMessagesPeerIdKey: @(peerId), TGPaidMessagesStarsKey: @(stars)}];
        });
    }
}

+ (SSignal *)priceForUserId:(int64_t)userId
{
    if (userId == 0 || userId == TGTelegraphInstance.clientUserId || !TGPeerIdIsUser(userId))
        return [SSignal single:@0];
    id inputUser = [TGStoriesSignals inputUserForUserId:userId];
    if (inputUser == nil)
        return [SSignal single:@([self cachedPriceForPeerId:userId])];

    return [[TGTLDynamicRpc requestSignalWithMethod:@"users.getRequirementsToContact" parameters:@{@"id": @[inputUser]}] map:^id(NSArray *result)
    {
        int64_t stars = 0;
        TGTLDynamicObject *requirement = [result isKindOfClass:[NSArray class]] ? result.firstObject : nil;
        if ([requirement isKindOfClass:[TGTLDynamicObject class]] && [requirement isConstructor:@"requirementToContactPaidMessages"])
            stars = [requirement int64Field:@"stars_amount"];
        [self setCachedPrice:stars forPeerId:userId];
        return @(stars);
    }];
}

+ (int64_t)localPriceForPeerId:(int64_t)peerId
{
    if (!TGPeerIdIsChannel(peerId))
        return -1;
    TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
    if (conversation == nil)
        return 0;
    if (conversation.isMonoforum)
    {
        TGConversation *broadcast = TGPeerIdFromChannelId(conversation.linkedMonoforumId) != 0 ? [TGDatabaseInstance() loadConversationWithId:TGPeerIdFromChannelId(conversation.linkedMonoforumId)] : nil;
        if (broadcast != nil && (broadcast.channelRole == TGChannelRoleCreator || broadcast.channelAdminRights.canManageDirectMessages))
            return 0;
        return conversation.sendPaidMessagesStars > 0 ? conversation.sendPaidMessagesStars : broadcast.sendPaidMessagesStars;
    }
    if (!conversation.isChannelGroup || conversation.channelRole == TGChannelRoleCreator || conversation.channelAdminRights != nil)
        return 0;
    return conversation.sendPaidMessagesStars;
}

+ (SSignal *)pricesForPeerIds:(NSArray *)peerIds
{
    NSMutableDictionary *prices = [[NSMutableDictionary alloc] init];
    NSMutableArray *inputUsers = [[NSMutableArray alloc] init];
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    for (NSNumber *nPeerId in peerIds)
    {
        int64_t peerId = [nPeerId longLongValue];
        int64_t localPrice = [self localPriceForPeerId:peerId];
        if (localPrice >= 0)
        {
            prices[nPeerId] = @(localPrice);
            continue;
        }
        if (!TGPeerIdIsUser(peerId) || peerId == TGTelegraphInstance.clientUserId)
        {
            prices[nPeerId] = @0;
            continue;
        }
        TGUser *user = [TGDatabaseInstance() loadUser:peerId];
        id inputUser = user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot ? nil : [TGStoriesSignals inputUserForUserId:peerId];
        if (inputUser == nil)
        {
            prices[nPeerId] = @([self cachedPriceForPeerId:peerId]);
            continue;
        }
        [inputUsers addObject:inputUser];
        [userIds addObject:nPeerId];
    }
    if (inputUsers.count == 0)
        return [SSignal single:prices];

    return [[[TGTLDynamicRpc requestSignalWithMethod:@"users.getRequirementsToContact" parameters:@{@"id": inputUsers}] map:^id(NSArray *result)
    {
        NSMutableDictionary *resolved = [[NSMutableDictionary alloc] initWithDictionary:prices];
        [userIds enumerateObjectsUsingBlock:^(NSNumber *nUserId, NSUInteger index, __unused BOOL *stop)
        {
            TGTLDynamicObject *requirement = [result isKindOfClass:[NSArray class]] && index < result.count ? result[index] : nil;
            int64_t stars = 0;
            if ([requirement isKindOfClass:[TGTLDynamicObject class]] && [requirement isConstructor:@"requirementToContactPaidMessages"])
                stars = [requirement int64Field:@"stars_amount"];
            [self setCachedPrice:stars forPeerId:[nUserId longLongValue]];
            resolved[nUserId] = @(stars);
        }];
        return resolved;
    }] catch:^SSignal *(__unused id error)
    {
        NSMutableDictionary *resolved = [[NSMutableDictionary alloc] initWithDictionary:prices];
        for (NSNumber *nUserId in userIds)
            resolved[nUserId] = @([self cachedPriceForPeerId:[nUserId longLongValue]]);
        return [SSignal single:resolved];
    }];
}

+ (void)approveSendingToPeerIds:(NSArray *)peerIds
{
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + TGPaidMessagesApprovalTimeout;
    @synchronized (TGPaidMessagesApprovals())
    {
        for (NSNumber *nPeerId in peerIds)
            TGPaidMessagesApprovals()[nPeerId] = @(deadline);
    }
}

+ (int64_t)allowedStarsForPeerId:(int64_t)peerId
{
    int64_t localPrice = [self localPriceForPeerId:peerId];
    int64_t price = localPrice >= 0 ? localPrice : [self cachedPriceForPeerId:peerId];
    if (price <= 0)
        return 0;
    bool approved = false;
    @synchronized (TGPaidMessagesApprovals())
    {
        NSNumber *deadline = TGPaidMessagesApprovals()[@(peerId)];
        approved = deadline != nil && [deadline doubleValue] > CFAbsoluteTimeGetCurrent();
    }
    if (approved || ![self needsConfirmationForPeerId:peerId price:price])
        return price;
    return 0;
}

+ (bool)isPaidMessagesError:(NSString *)errorType
{
    return [errorType hasPrefix:TGPaidMessagesPaymentRequiredPrefix] || [errorType isEqualToString:@"BALANCE_TOO_LOW"];
}

+ (int64_t)starsFromPaymentRequiredError:(NSString *)errorType
{
    if (![errorType hasPrefix:TGPaidMessagesPaymentRequiredPrefix])
        return 0;
    return [[errorType substringFromIndex:TGPaidMessagesPaymentRequiredPrefix.length] longLongValue];
}

+ (NSDictionary *)confirmedPrices
{
    if (TGTelegraphInstance.clientUserId == 0)
        return @{};
    NSData *data = [TGDatabaseInstance() customProperty:TGPaidMessagesConfirmedPricesKey];
    if (data.length == 0)
        return @{};
    id value = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

+ (bool)needsConfirmationForPeerId:(int64_t)peerId price:(int64_t)price
{
    if (price <= 0)
        return false;
    NSNumber *confirmed = [[self confirmedPrices] objectForKey:[[NSString alloc] initWithFormat:@"%lld", peerId]];
    return confirmed == nil || [confirmed longLongValue] < price;
}

+ (void)setConfirmationSkipped:(bool)skipped forPeerId:(int64_t)peerId price:(int64_t)price
{
    if (TGTelegraphInstance.clientUserId == 0)
        return;
    NSMutableDictionary *prices = [[NSMutableDictionary alloc] initWithDictionary:[self confirmedPrices]];
    NSString *key = [[NSString alloc] initWithFormat:@"%lld", peerId];
    if (skipped && price > 0)
        [prices setObject:@(price) forKey:key];
    else
        [prices removeObjectForKey:key];
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:prices format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
    if (data != nil)
        [TGDatabaseInstance() setCustomProperty:TGPaidMessagesConfirmedPricesKey value:data];
}

+ (SSignal *)starsBalance
{
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:TGTelegraphInstance.clientUserId];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getStarsStatus" parameters:@{@"peer": inputPeer}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"payments.starsStatus"])
            return [SSignal fail:nil];
        TGTLDynamicObject *balance = [result objectField:@"balance"];
        return [SSignal single:@([balance int64Field:@"amount"])];
    }];
}

+ (SSignal *)topUpOptions
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getStarsTopupOptions" parameters:@{}] map:^id(NSArray *result)
    {
        NSMutableArray *options = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *object in [result isKindOfClass:[NSArray class]] ? result : nil)
        {
            if ([object isKindOfClass:[TGTLDynamicObject class]] && [object isConstructor:@"starsTopupOption"] && [object int64Field:@"stars"] > 0)
                [options addObject:[[TGStarsTopUpOption alloc] initWithObject:object]];
        }
        [options sortUsingComparator:^NSComparisonResult(TGStarsTopUpOption *lhs, TGStarsTopUpOption *rhs)
        {
            if (lhs.stars == rhs.stars)
                return NSOrderedSame;
            return lhs.stars < rhs.stars ? NSOrderedAscending : NSOrderedDescending;
        }];
        return options;
    }];
}

+ (SSignal *)topUpFormUrlForOption:(TGStarsTopUpOption *)option
{
    if (option == nil)
        return [SSignal fail:nil];
    TGTLDynamicObject *purpose = [TGTLDynamicObject objectWithConstructor:@"inputStorePaymentStarsTopup" fields:@{@"stars": @(option.stars), @"currency": option.currency, @"amount": @(option.amount)}];
    TGTLDynamicObject *invoice = [TGTLDynamicObject objectWithConstructor:@"inputInvoiceStars" fields:@{@"purpose": purpose}];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getPaymentForm" parameters:@{@"invoice": invoice}] mapToSignal:^SSignal *(TGTLDynamicObject *form)
    {
        NSString *url = [form isKindOfClass:[TGTLDynamicObject class]] && [form isConstructor:@"payments.paymentForm"] ? [form stringField:@"url"] : nil;
        if (url.length == 0)
            return [SSignal fail:nil];
        return [SSignal single:url];
    }];
}

+ (SSignal *)globalPrivacySettings
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.getGlobalPrivacySettings" parameters:@{}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"globalPrivacySettings"])
            return [SSignal fail:nil];
        return [SSignal single:result];
    }];
}

+ (SSignal *)chargeStarsForNonContacts
{
    return [[self globalPrivacySettings] map:^id(TGTLDynamicObject *settings)
    {
        return @([settings int64Field:@"noncontact_peers_paid_stars"]);
    }];
}

+ (SSignal *)setChargeStarsForNonContacts:(int64_t)stars
{
    return [[self globalPrivacySettings] mapToSignal:^SSignal *(TGTLDynamicObject *settings)
    {
        NSMutableDictionary *fields = [[NSMutableDictionary alloc] initWithDictionary:settings.fields ?: @{}];
        [fields removeObjectForKey:@"flags"];
        if (stars > 0)
        {
            [fields setObject:@(stars) forKey:@"noncontact_peers_paid_stars"];
            [fields removeObjectForKey:@"new_noncontact_peers_require_premium"];
        }
        else
            [fields removeObjectForKey:@"noncontact_peers_paid_stars"];
        TGTLDynamicObject *updated = [TGTLDynamicObject objectWithConstructor:@"globalPrivacySettings" fields:fields];
        return [[TGTLDynamicRpc requestSignalWithMethod:@"account.setGlobalPrivacySettings" parameters:@{@"settings": updated}] map:^id(TGTLDynamicObject *result)
        {
            return @([result isKindOfClass:[TGTLDynamicObject class]] ? [result int64Field:@"noncontact_peers_paid_stars"] : stars);
        }];
    }];
}

+ (SSignal *)freeExceptionUserIds
{
    TGTLDynamicObject *key = [TGTLDynamicObject objectWithConstructor:@"inputPrivacyKeyNoPaidMessages" fields:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.getPrivacy" parameters:@{@"key": key}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"account.privacyRules"])
            return [SSignal fail:nil];
        [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        NSMutableArray *userIds = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *rule in [result arrayField:@"rules"])
        {
            if (![rule isKindOfClass:[TGTLDynamicObject class]] || ![rule isConstructor:@"privacyValueAllowUsers"])
                continue;
            for (NSNumber *userId in [rule arrayField:@"users"])
            {
                NSNumber *peerId = @(TGPeerIdFromUserId([userId longLongValue]));
                if (![userIds containsObject:peerId])
                    [userIds addObject:peerId];
            }
        }
        return [SSignal single:userIds];
    }];
}

+ (SSignal *)setFreeExceptionUserIds:(NSArray *)userIds
{
    NSMutableArray *inputUsers = [[NSMutableArray alloc] init];
    for (NSNumber *userId in userIds)
    {
        id inputUser = [TGStoriesSignals inputUserForUserId:[userId longLongValue]];
        if (inputUser != nil)
            [inputUsers addObject:inputUser];
    }
    NSMutableArray *rules = [[NSMutableArray alloc] init];
    if (inputUsers.count != 0)
        [rules addObject:[TGTLDynamicObject objectWithConstructor:@"inputPrivacyValueAllowUsers" fields:@{@"users": inputUsers}]];
    TGTLDynamicObject *key = [TGTLDynamicObject objectWithConstructor:@"inputPrivacyKeyNoPaidMessages" fields:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.setPrivacy" parameters:@{@"key": key, @"rules": rules}] map:^id(TGTLDynamicObject *result)
    {
        if ([result isKindOfClass:[TGTLDynamicObject class]])
            [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        return userIds;
    }];
}

+ (SSignal *)chargedStarsFromUserId:(int64_t)userId
{
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:userId];
    if (inputPeer == nil || userId == TGTelegraphInstance.clientUserId)
        return [SSignal single:@0];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.getPeerSettings" parameters:@{@"peer": inputPeer}] map:^id(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"messages.peerSettings"])
            return @0;
        TGTLDynamicObject *settings = [result objectField:@"settings"];
        return @([settings isKindOfClass:[TGTLDynamicObject class]] ? [settings int64Field:@"charge_paid_message_stars"] : 0);
    }];
}

+ (SSignal *)revenueFromUserId:(int64_t)userId
{
    id inputUser = [TGStoriesSignals inputUserForUserId:userId];
    if (inputUser == nil)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.getPaidMessagesRevenue" parameters:@{@"user_id": inputUser}] map:^id(TGTLDynamicObject *result)
    {
        return @([result isKindOfClass:[TGTLDynamicObject class]] ? [result int64Field:@"stars_amount"] : 0);
    }];
}

+ (SSignal *)setFeeRemoved:(bool)removed forUserId:(int64_t)userId refundCharged:(bool)refundCharged
{
    id inputUser = [TGStoriesSignals inputUserForUserId:userId];
    if (inputUser == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:@{@"user_id": inputUser}];
    if (!removed)
        parameters[@"require_payment"] = @true;
    else if (refundCharged)
        parameters[@"refund_charged"] = @true;
    return [TGTLDynamicRpc requestSignalWithMethod:@"account.toggleNoPaidMessagesException" parameters:parameters];
}

+ (SSignal *)exportFreeLinkTemporary:(bool)temporary revoke:(bool)revoke
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (temporary)
        parameters[@"temporary"] = @true;
    if (revoke)
        parameters[@"revoke"] = @true;
    return [[TGTLDynamicRpc requestSignalWithMethod:@"contacts.exportNoPaidMessagesToken" parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"exportedNoPaidMessagesToken"])
            return [SSignal fail:nil];
        return [SSignal single:[[TGPaidMessagesFreeLink alloc] initWithToken:[result stringField:@"token"] url:[result stringField:@"url"] expires:[result int32Field:@"expires"]]];
    }];
}

+ (SSignal *)importFreeToken:(NSString *)token userId:(int64_t)userId
{
    id inputUser = [TGStoriesSignals inputUserForUserId:userId];
    if (inputUser == nil || token.length == 0)
        return [SSignal fail:nil];
    SSignal *priceBefore = [[self priceForUserId:userId] catch:^SSignal *(__unused id error)
    {
        return [SSignal single:@([self cachedPriceForPeerId:userId])];
    }];
    return [priceBefore mapToSignal:^SSignal *(NSNumber *starsBefore)
    {
        bool pricedBefore = [starsBefore longLongValue] > 0;
        return [[TGTLDynamicRpc requestSignalWithMethod:@"contacts.importNoPaidMessagesToken" parameters:@{@"user_id": inputUser, @"token": token}] mapToSignal:^SSignal *(id user)
        {
            [TGStoriesSignals processUsers:user != nil ? @[user] : nil chats:nil];
            return [[[self priceForUserId:userId] catch:^SSignal *(__unused id error)
            {
                return [SSignal single:@([self cachedPriceForPeerId:userId])];
            }] map:^id(NSNumber *stars)
            {
                return @(pricedBefore && [stars longLongValue] == 0);
            }];
        }];
    }];
}

+ (SSignal *)setChannelPrice:(int64_t)stars channelId:(int64_t)channelId broadcastMessagesAllowed:(bool)broadcastMessagesAllowed
{
    TGConversation *channel = [TGDatabaseInstance() loadConversationWithId:channelId];
    TLInputChannel *inputChannel = [TGChannelManagementSignals inputChannelForPeerId:channelId accessHash:channel.accessHash];
    if (inputChannel == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:@{@"channel": inputChannel, @"send_paid_messages_stars": @(MAX(0, stars))}];
    if (broadcastMessagesAllowed)
        parameters[@"broadcast_messages_allowed"] = @true;
    return [[TGTLDynamicRpc requestSignalWithMethod:@"channels.updatePaidMessagesPrice" parameters:parameters dynamicTypes:[NSSet set]] map:^id(id updates)
    {
        if (updates != nil)
            [[TGTelegramNetworking instance] addUpdates:updates];
        [self setCachedPrice:MAX(0, stars) forPeerId:channelId];
        return @(MAX(0, stars));
    }];
}

+ (NSString *)starsString:(int64_t)stars
{
    return [[NSString alloc] initWithFormat:@"%lld ⭐", stars];
}

+ (NSString *)serviceTextForAction:(TGActionMediaAttachment *)action outgoing:(bool)outgoing authorName:(NSString *)authorName peerName:(NSString *)peerName
{
    switch (action.actionType)
    {
        case TGMessageActionPaidMessagesRefunded:
        {
            NSString *stars = [self starsString:[action.actionData[@"stars"] longLongValue]];
            if (outgoing)
                return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.RefundedOutgoing"), stars, peerName ?: @""];
            return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.Refunded"), authorName ?: @"", stars];
        }
        case TGMessageActionPaidMessagesPrice:
        {
            int64_t stars = [action.actionData[@"stars"] longLongValue];
            if ([action.actionData[@"broadcastMessagesAllowed"] boolValue])
            {
                if (stars > 0)
                    return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.DirectPrice"), [self starsString:stars]];
                return TGLocalized(@"PaidMessages.Notification.DirectFree");
            }
            if (authorName.length == 0)
            {
                if (stars > 0)
                    return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.PriceChangedGeneric"), [self starsString:stars]];
                return TGLocalized(@"PaidMessages.Notification.PriceRemovedGeneric");
            }
            if (stars > 0)
                return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.PriceChanged"), authorName, [self starsString:stars]];
            return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.PriceRemoved"), authorName];
        }
        case TGMessageActionNoPaidMessagesTokenUsed:
        {
            if (outgoing)
                return TGLocalized(@"PaidMessages.Notification.TokenUsedOutgoing");
            return [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Notification.TokenUsed"), authorName ?: @""];
        }
        default:
            return nil;
    }
}

@end
