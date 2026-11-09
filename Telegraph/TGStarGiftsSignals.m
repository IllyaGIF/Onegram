#import "TGStarGiftsSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGStarGift.h"
#import "TGStoriesSignals.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"
#import "TLUpdates+TG.h"

@implementation TGSavedStarGiftsPage

- (instancetype)initWithTotalCount:(int32_t)totalCount gifts:(NSArray *)gifts nextOffset:(NSString *)nextOffset
{
    self = [super init];
    if (self != nil)
    {
        _totalCount = totalCount;
        _gifts = gifts == nil ? @[] : gifts;
        _nextOffset = nextOffset;
    }
    return self;
}

@end

@implementation TGStarGiftsSignals

+ (TGTLDynamicObject *)inputSavedGift:(TGSavedStarGift *)gift
{
    if (gift.ownerPeerId == TGTelegraphInstance.clientUserId && gift.messageId != 0)
        return [TGTLDynamicObject objectWithConstructor:@"inputSavedStarGiftUser" fields:@{@"msg_id": @(gift.messageId)}];
    if (gift.savedId != 0)
    {
        id inputPeer = [TGStoriesSignals inputPeerForPeerId:gift.ownerPeerId];
        if (inputPeer != nil)
            return [TGTLDynamicObject objectWithConstructor:@"inputSavedStarGiftChat" fields:@{@"peer": inputPeer, @"saved_id": @(gift.savedId)}];
    }
    if (gift.gift.slug.length != 0)
        return [TGTLDynamicObject objectWithConstructor:@"inputSavedStarGiftSlug" fields:@{@"slug": gift.gift.slug}];
    return nil;
}

+ (SSignal *)savedGifts:(int64_t)peerId offset:(NSString *)offset limit:(int32_t)limit
{
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    NSDictionary *parameters = @{@"peer": inputPeer, @"offset": offset == nil ? @"" : offset, @"limit": @(limit)};
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getSavedStarGifts" parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"payments.savedStarGifts"])
            return [SSignal fail:nil];
        [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        NSMutableArray *gifts = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *giftObject in [result arrayField:@"gifts"])
        {
            TGSavedStarGift *gift = [TGSavedStarGift savedStarGiftWithObject:giftObject ownerPeerId:peerId];
            if (gift != nil)
                [gifts addObject:gift];
        }
        return [SSignal single:[[TGSavedStarGiftsPage alloc] initWithTotalCount:[result int32Field:@"count"] gifts:gifts nextOffset:[result stringField:@"next_offset"]]];
    }];
}

+ (SSignal *)savedGift:(TGSavedStarGift *)gift
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    if (inputGift == nil)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getSavedStarGift" parameters:@{@"stargift": @[inputGift]}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"payments.savedStarGifts"])
            return [SSignal fail:nil];
        [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        for (TGTLDynamicObject *object in [result arrayField:@"gifts"])
        {
            TGSavedStarGift *updated = [TGSavedStarGift savedStarGiftWithObject:object ownerPeerId:gift.ownerPeerId];
            if (updated != nil && [self savedGift:updated isEqualToGift:gift])
                return [SSignal single:updated];
        }
        return [SSignal fail:nil];
    }];
}

+ (SSignal *)setGift:(TGSavedStarGift *)gift saved:(bool)saved
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    if (inputGift == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"stargift"] = inputGift;
    if (!saved)
        parameters[@"unsave"] = @true;
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.saveStarGift" parameters:parameters] mapToSignal:^SSignal *(NSNumber *result)
    {
        return [result boolValue] ? [SSignal single:result] : [SSignal fail:nil];
    }];
}

+ (SSignal *)setGifts:(NSArray *)gifts pinnedToTopForPeerId:(int64_t)peerId
{
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    NSMutableArray *inputGifts = [[NSMutableArray alloc] init];
    for (TGSavedStarGift *gift in gifts)
    {
        TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
        if (inputGift != nil)
            [inputGifts addObject:inputGift];
    }
    return [TGTLDynamicRpc requestSignalWithMethod:@"payments.toggleStarGiftsPinnedToTop" parameters:@{@"peer": inputPeer, @"stargift": inputGifts}];
}

+ (bool)savedGift:(TGSavedStarGift *)lhs isEqualToGift:(TGSavedStarGift *)rhs
{
    if (lhs.messageId != 0 || rhs.messageId != 0)
        return lhs.messageId == rhs.messageId;
    if (lhs.savedId != 0 || rhs.savedId != 0)
        return lhs.savedId == rhs.savedId;
    return lhs.gift.slug.length != 0 && [lhs.gift.slug isEqualToString:rhs.gift.slug];
}

+ (SSignal *)setGift:(TGSavedStarGift *)gift pinnedToTop:(bool)pinnedToTop
{
    int64_t peerId = gift.ownerPeerId;
    return [[self savedGifts:peerId offset:nil limit:100] mapToSignal:^SSignal *(TGSavedStarGiftsPage *page)
    {
        NSMutableArray *pinned = [[NSMutableArray alloc] init];
        for (TGSavedStarGift *item in page.gifts)
        {
            if (item.pinnedToTop && ![self savedGift:item isEqualToGift:gift])
                [pinned addObject:item];
        }
        if (pinnedToTop)
            [pinned insertObject:gift atIndex:0];
        return [self setGifts:pinned pinnedToTopForPeerId:peerId];
    }];
}

+ (SSignal *)convertGift:(TGSavedStarGift *)gift
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    if (inputGift == nil)
        return [SSignal fail:nil];
    return [TGTLDynamicRpc requestSignalWithMethod:@"payments.convertStarGift" parameters:@{@"stargift": inputGift}];
}

+ (SSignal *)availableGifts
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getStarGifts" parameters:@{@"hash": @0}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"payments.starGifts"])
            return [SSignal fail:nil];
        [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        NSMutableArray *gifts = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *giftObject in [result arrayField:@"gifts"])
        {
            TGStarGift *gift = [TGStarGift starGiftWithObject:giftObject];
            if (gift != nil && [gift canBePurchased])
                [gifts addObject:gift];
        }
        return [SSignal single:gifts];
    }];
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

+ (SSignal *)upgradePreviewForGift:(TGSavedStarGift *)gift
{
    if (gift == nil || gift.gift.unique || gift.gift.giftId == 0 || !gift.canUpgrade || ![gift canManage])
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getStarGiftUpgradePreview" parameters:@{@"gift_id": @(gift.gift.giftId)}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"payments.starGiftUpgradePreview"])
            return [SSignal fail:nil];
        return [SSignal single:result];
    }];
}

+ (SSignal *)upgradeGift:(TGSavedStarGift *)gift expectedStars:(int64_t)expectedStars
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    if (inputGift == nil || !gift.canUpgrade || ![gift canManage] || expectedStars < 0)
        return [SSignal fail:nil];
    NSDictionary *fields = @{@"stargift": inputGift, @"keep_original_details": @true};
    if (expectedStars == 0)
        return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.upgradeStarGift" parameters:fields dynamicTypes:[NSSet set]] mapToSignal:^SSignal *(id updates)
        {
            if (![updates isKindOfClass:[TLUpdates class]])
                return [SSignal fail:nil];
            [[TGTelegramNetworking instance] addUpdates:updates];
            return [SSignal single:@true];
        }];
    TGTLDynamicObject *invoice = [TGTLDynamicObject objectWithConstructor:@"inputInvoiceStarGiftUpgrade" fields:fields];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getPaymentForm" parameters:@{@"invoice": invoice}] mapToSignal:^SSignal *(TGTLDynamicObject *form)
    {
        if (![form isKindOfClass:[TGTLDynamicObject class]] || [form field:@"form_id"] == nil)
            return [SSignal fail:nil];
        TGTLDynamicObject *invoiceData = [form objectField:@"invoice"];
        if (![[invoiceData stringField:@"currency"] isEqualToString:@"XTR"])
            return [SSignal fail:nil];
        int64_t total = 0;
        for (TGTLDynamicObject *price in [invoiceData arrayField:@"prices"])
        {
            if (![price isKindOfClass:[TGTLDynamicObject class]] || [price int64Field:@"amount"] < 0 || total > INT64_MAX - [price int64Field:@"amount"])
                return [SSignal fail:nil];
            total += [price int64Field:@"amount"];
        }
        if (total != expectedStars)
            return [SSignal fail:nil];
        return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.sendStarsForm" parameters:@{@"form_id": @([form int64Field:@"form_id"]), @"invoice": invoice} dynamicTypes:[NSSet setWithObject:@"payments.PaymentResult"]] mapToSignal:^SSignal *(TGTLDynamicObject *result)
        {
            if (![result isConstructor:@"payments.paymentResult"])
                return [SSignal fail:nil];
            id updates = [result field:@"updates"];
            if (![updates isKindOfClass:[TLUpdates class]])
                return [SSignal fail:nil];
            [[TGTelegramNetworking instance] addUpdates:updates];
            return [SSignal single:@true];
        }];
    }];
}

+ (SSignal *)sendGiftWithId:(int64_t)giftId toPeerId:(int64_t)peerId message:(NSString *)message hideName:(bool)hideName
{
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *invoiceFields = [[NSMutableDictionary alloc] init];
    invoiceFields[@"peer"] = inputPeer;
    invoiceFields[@"gift_id"] = @(giftId);
    if (hideName)
        invoiceFields[@"hide_name"] = @true;
    if (message.length != 0)
        invoiceFields[@"message"] = [TGTLDynamicObject objectWithConstructor:@"textWithEntities" fields:@{@"text": message, @"entities": @[]}];
    TGTLDynamicObject *invoice = [TGTLDynamicObject objectWithConstructor:@"inputInvoiceStarGift" fields:invoiceFields];

    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getPaymentForm" parameters:@{@"invoice": invoice}] mapToSignal:^SSignal *(TGTLDynamicObject *form)
    {
        if (![form isKindOfClass:[TGTLDynamicObject class]] || [form field:@"form_id"] == nil)
            return [SSignal fail:nil];
        return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.sendStarsForm" parameters:@{@"form_id": @([form int64Field:@"form_id"]), @"invoice": invoice}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
        {
            if ([result isConstructor:@"payments.paymentResult"])
            {
                TGTLDynamicObject *updates = [result objectField:@"updates"];
                [TGStoriesSignals processUsers:[updates arrayField:@"users"] chats:[updates arrayField:@"chats"]];
                return [SSignal single:@true];
            }
            return [SSignal fail:nil];
        }];
    }];
}

+ (SSignal *)transferGift:(TGSavedStarGift *)gift toPeerId:(int64_t)peerId expectedStars:(int64_t)expectedStars
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    id inputPeer = [TGStoriesSignals inputPeerForPeerId:peerId];
    if (inputGift == nil || inputPeer == nil || ![gift canTransfer] || peerId == TGTelegraphInstance.clientUserId || expectedStars < 0)
        return [SSignal fail:nil];
    NSDictionary *fields = @{@"stargift": inputGift, @"to_id": inputPeer};
    if (expectedStars == 0)
        return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.transferStarGift" parameters:fields dynamicTypes:[NSSet set]] mapToSignal:^SSignal *(id updates)
        {
            if (![updates isKindOfClass:[TLUpdates class]])
                return [SSignal fail:nil];
            [[TGTelegramNetworking instance] addUpdates:updates];
            return [SSignal single:@true];
        }];
    TGTLDynamicObject *invoice = [TGTLDynamicObject objectWithConstructor:@"inputInvoiceStarGiftTransfer" fields:fields];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.getPaymentForm" parameters:@{@"invoice": invoice}] mapToSignal:^SSignal *(TGTLDynamicObject *form)
    {
        if (![form isKindOfClass:[TGTLDynamicObject class]] || [form field:@"form_id"] == nil)
            return [SSignal fail:nil];
        TGTLDynamicObject *invoiceData = [form objectField:@"invoice"];
        if (![[invoiceData stringField:@"currency"] isEqualToString:@"XTR"])
            return [SSignal fail:nil];
        int64_t total = 0;
        for (TGTLDynamicObject *item in [invoiceData arrayField:@"prices"])
        {
            if (![item isKindOfClass:[TGTLDynamicObject class]] || [item int64Field:@"amount"] < 0 || total > INT64_MAX - [item int64Field:@"amount"])
                return [SSignal fail:nil];
            total += [item int64Field:@"amount"];
        }
        if (total != expectedStars)
            return [SSignal fail:nil];
        return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.sendStarsForm" parameters:@{@"form_id": @([form int64Field:@"form_id"]), @"invoice": invoice} dynamicTypes:[NSSet setWithObject:@"payments.PaymentResult"]] mapToSignal:^SSignal *(TGTLDynamicObject *result)
        {
            if (![result isConstructor:@"payments.paymentResult"])
                return [SSignal fail:nil];
            id updates = [result field:@"updates"];
            if (![updates isKindOfClass:[TLUpdates class]])
                return [SSignal fail:nil];
            [[TGTelegramNetworking instance] addUpdates:updates];
            return [SSignal single:@true];
        }];
    }];
}

+ (SSignal *)setResalePrice:(int64_t)price forGift:(TGSavedStarGift *)gift
{
    TGTLDynamicObject *inputGift = [self inputSavedGift:gift];
    if (inputGift == nil || ![gift canResell] || price < 0)
        return [SSignal fail:nil];
    TGTLDynamicObject *amount = [TGTLDynamicObject objectWithConstructor:@"starsAmount" fields:@{@"amount": @(price), @"nanos": @0}];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"payments.updateStarGiftPrice" parameters:@{@"stargift": inputGift, @"resell_amount": amount} dynamicTypes:[NSSet set]] mapToSignal:^SSignal *(id updates)
    {
        if (![updates isKindOfClass:[TLUpdates class]])
            return [SSignal fail:nil];
        [[TGTelegramNetworking instance] addUpdates:updates];
        return [SSignal single:@true];
    }];
}

@end
