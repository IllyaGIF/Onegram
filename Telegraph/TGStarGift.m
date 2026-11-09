#import "TGStarGift.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGStoryItem.h"
#import "TGTelegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGMediaOriginInfo+Telegraph.h"
#import "TL/TLMetaScheme.h"

UIColor *TGStarGiftColor(int32_t rgb)
{
    return UIColorRGB((uint32_t)rgb & 0xffffff);
}

static TGDocumentMediaAttachment *TGStarGiftDocument(id document)
{
    if (![document isKindOfClass:[TLDocument class]])
        return nil;
    TGDocumentMediaAttachment *attachment = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:document];
    if (attachment.documentId == 0)
        return nil;
    attachment.originInfo = [TGMediaOriginInfo mediaOriginInfoForDocument:document];
    return attachment;
}

static int32_t TGStarGiftRarityPermille(TGTLDynamicObject *rarity)
{
    return [rarity isConstructor:@"starGiftAttributeRarity"] ? [rarity int32Field:@"permille"] : 0;
}

static NSString *TGStarGiftRarityLevel(TGTLDynamicObject *rarity)
{
    if ([rarity isConstructor:@"starGiftAttributeRarityUncommon"])
        return @"Uncommon";
    if ([rarity isConstructor:@"starGiftAttributeRarityRare"])
        return @"Rare";
    if ([rarity isConstructor:@"starGiftAttributeRarityEpic"])
        return @"Epic";
    if ([rarity isConstructor:@"starGiftAttributeRarityLegendary"])
        return @"Legendary";
    return nil;
}

@interface TGStarGift ()

@property (nonatomic) int64_t giftId;
@property (nonatomic) bool unique;
@property (nonatomic, strong) TGDocumentMediaAttachment *sticker;
@property (nonatomic, strong) TGDocumentMediaAttachment *patternSticker;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *slug;
@property (nonatomic) int32_t number;
@property (nonatomic) int64_t ownerPeerId;
@property (nonatomic, strong) NSString *ownerName;
@property (nonatomic) int64_t releasedByPeerId;
@property (nonatomic) int64_t valueAmount;
@property (nonatomic, strong) NSString *valueCurrency;
@property (nonatomic, strong) NSArray *resellAmounts;
@property (nonatomic) bool burned;
@property (nonatomic) bool crafted;
@property (nonatomic) bool resaleTonOnly;
@property (nonatomic) int64_t stars;
@property (nonatomic) int64_t convertStars;
@property (nonatomic) int64_t upgradeStars;
@property (nonatomic) bool limited;
@property (nonatomic) bool soldOut;
@property (nonatomic) bool birthday;
@property (nonatomic) bool requirePremium;
@property (nonatomic) int32_t availabilityRemains;
@property (nonatomic) int32_t availabilityTotal;
@property (nonatomic) bool limitedPerUser;
@property (nonatomic) int32_t perUserRemains;
@property (nonatomic) bool hasBackdrop;
@property (nonatomic) int32_t backdropCenterColor;
@property (nonatomic) int32_t backdropEdgeColor;
@property (nonatomic) int32_t backdropPatternColor;
@property (nonatomic) int32_t backdropTextColor;
@property (nonatomic, strong) NSString *modelName;
@property (nonatomic, strong) NSString *backdropName;
@property (nonatomic, strong) NSString *patternName;
@property (nonatomic) int32_t modelRarityPermille;
@property (nonatomic) int32_t backdropRarityPermille;
@property (nonatomic) int32_t patternRarityPermille;
@property (nonatomic, strong) NSString *modelRarityLevel;
@property (nonatomic, strong) NSString *backdropRarityLevel;
@property (nonatomic, strong) NSString *patternRarityLevel;

@end

@implementation TGStarGift

+ (NSArray *)archivePropertyNames
{
    static NSArray *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        names = @[@"giftId", @"unique", @"sticker", @"patternSticker", @"title", @"slug", @"number", @"ownerPeerId", @"ownerName", @"releasedByPeerId", @"valueAmount", @"valueCurrency", @"burned", @"crafted", @"resaleTonOnly", @"stars", @"convertStars", @"upgradeStars", @"limited", @"soldOut", @"birthday", @"requirePremium", @"availabilityRemains", @"availabilityTotal", @"limitedPerUser", @"perUserRemains", @"hasBackdrop", @"backdropCenterColor", @"backdropEdgeColor", @"backdropPatternColor", @"backdropTextColor", @"modelName", @"backdropName", @"patternName", @"modelRarityPermille", @"backdropRarityPermille", @"patternRarityPermille", @"modelRarityLevel", @"backdropRarityLevel", @"patternRarityLevel"];
    });
    return names;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
    for (NSString *key in [TGStarGift archivePropertyNames])
    {
        id value = [self valueForKey:key];
        if (value != nil)
            fields[key] = value;
    }
    [coder encodeObject:fields forKey:@"giftFields"];
    NSMutableArray *prices = [[NSMutableArray alloc] init];
    for (TGTLDynamicObject *amount in _resellAmounts)
    {
        if (![amount isKindOfClass:[TGTLDynamicObject class]])
            continue;
        [prices addObject:@{ @"constructor": amount.constructor, @"fields": amount.fields }];
    }
    [coder encodeObject:prices forKey:@"resellAmounts"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        NSDictionary *fields = [coder decodeObjectForKey:@"giftFields"];
        for (NSString *key in [TGStarGift archivePropertyNames])
        {
            id value = fields[key];
            if (value != nil)
                [self setValue:value forKey:key];
        }
        NSMutableArray *prices = [[NSMutableArray alloc] init];
        for (NSDictionary *price in [coder decodeObjectForKey:@"resellAmounts"])
        {
            if ([price[@"constructor"] isKindOfClass:[NSString class]] && [price[@"fields"] isKindOfClass:[NSDictionary class]])
                [prices addObject:[TGTLDynamicObject objectWithConstructor:price[@"constructor"] fields:price[@"fields"]]];
        }
        _resellAmounts = prices;
    }
    return self;
}

+ (TGStarGift *)starGiftWithObject:(TGTLDynamicObject *)object
{
    if ([object isConstructor:@"starGift"])
    {
        TGStarGift *gift = [[TGStarGift alloc] init];
        gift.giftId = [object int64Field:@"id"];
        gift.sticker = TGStarGiftDocument([object field:@"sticker"]);
        gift.stars = [object int64Field:@"stars"];
        gift.convertStars = [object int64Field:@"convert_stars"];
        gift.upgradeStars = [object int64Field:@"upgrade_stars"];
        gift.limited = [object flag:@"limited"];
        gift.soldOut = [object flag:@"sold_out"];
        gift.birthday = [object flag:@"birthday"];
        gift.requirePremium = [object flag:@"require_premium"];
        gift.availabilityRemains = [object int32Field:@"availability_remains"];
        gift.availabilityTotal = [object int32Field:@"availability_total"];
        gift.limitedPerUser = [object flag:@"limited_per_user"];
        gift.perUserRemains = [object int32Field:@"per_user_remains"];
        gift.title = [object stringField:@"title"];
        gift.releasedByPeerId = TGStoryPeerIdFromObject([object objectField:@"released_by"]);
        TGTLDynamicObject *background = [object objectField:@"background"];
        if (background != nil)
        {
            gift.hasBackdrop = true;
            gift.backdropCenterColor = [background int32Field:@"center_color"];
            gift.backdropEdgeColor = [background int32Field:@"edge_color"];
            gift.backdropPatternColor = [background int32Field:@"center_color"];
            gift.backdropTextColor = [background int32Field:@"text_color"];
        }
        return gift;
    }
    if ([object isConstructor:@"starGiftUnique"])
    {
        TGStarGift *gift = [[TGStarGift alloc] init];
        gift.unique = true;
        gift.giftId = [object int64Field:@"gift_id"];
        gift.title = [object stringField:@"title"];
        gift.slug = [object stringField:@"slug"];
        gift.number = [object int32Field:@"num"];
        gift.ownerPeerId = TGStoryPeerIdFromObject([object objectField:@"owner_id"]);
        gift.ownerName = [object stringField:@"owner_name"];
        gift.releasedByPeerId = TGStoryPeerIdFromObject([object objectField:@"released_by"]);
        gift.valueAmount = [object int64Field:@"value_amount"];
        gift.valueCurrency = [object stringField:@"value_currency"];
        gift.resellAmounts = [object arrayField:@"resell_amount"];
        gift.burned = [object flag:@"burned"];
        gift.crafted = [object flag:@"crafted"];
        gift.resaleTonOnly = [object flag:@"resale_ton_only"];
        gift.availabilityRemains = [object int32Field:@"availability_issued"];
        gift.availabilityTotal = [object int32Field:@"availability_total"];
        gift.limited = true;
        for (TGTLDynamicObject *attribute in [object arrayField:@"attributes"])
        {
            if (![attribute isKindOfClass:[TGTLDynamicObject class]])
                continue;
            if ([attribute isConstructor:@"starGiftAttributeModel"])
            {
                gift.sticker = TGStarGiftDocument([attribute field:@"document"]);
                gift.modelName = [attribute stringField:@"name"];
                gift.crafted = gift.crafted || [attribute flag:@"crafted"];
                TGTLDynamicObject *rarity = [attribute objectField:@"rarity"];
                gift.modelRarityPermille = TGStarGiftRarityPermille(rarity);
                gift.modelRarityLevel = TGStarGiftRarityLevel(rarity);
            }
            else if ([attribute isConstructor:@"starGiftAttributePattern"])
            {
                gift.patternSticker = TGStarGiftDocument([attribute field:@"document"]);
                gift.patternName = [attribute stringField:@"name"];
                TGTLDynamicObject *rarity = [attribute objectField:@"rarity"];
                gift.patternRarityPermille = TGStarGiftRarityPermille(rarity);
                gift.patternRarityLevel = TGStarGiftRarityLevel(rarity);
            }
            else if ([attribute isConstructor:@"starGiftAttributeBackdrop"])
            {
                gift.hasBackdrop = true;
                gift.backdropName = [attribute stringField:@"name"];
                gift.backdropCenterColor = [attribute int32Field:@"center_color"];
                gift.backdropEdgeColor = [attribute int32Field:@"edge_color"];
                gift.backdropPatternColor = [attribute int32Field:@"pattern_color"];
                gift.backdropTextColor = [attribute int32Field:@"text_color"];
                TGTLDynamicObject *rarity = [attribute objectField:@"rarity"];
                gift.backdropRarityPermille = TGStarGiftRarityPermille(rarity);
                gift.backdropRarityLevel = TGStarGiftRarityLevel(rarity);
            }
        }
        return gift;
    }
    return nil;
}

- (bool)canBePurchased
{
    if (_unique || _soldOut || _sticker == nil)
        return false;
    if (_limited && _availabilityRemains <= 0)
        return false;
    if (_limitedPerUser && _perUserRemains <= 0)
        return false;
    return true;
}

@end

@interface TGSavedStarGift ()

@property (nonatomic) int64_t ownerPeerId;
@property (nonatomic, strong) TGStarGift *gift;
@property (nonatomic) int64_t fromPeerId;
@property (nonatomic) int32_t date;
@property (nonatomic, strong) NSString *message;
@property (nonatomic) bool nameHidden;
@property (nonatomic) bool unsaved;
@property (nonatomic) bool refunded;
@property (nonatomic) bool canUpgrade;
@property (nonatomic) bool pinnedToTop;
@property (nonatomic) int32_t messageId;
@property (nonatomic) int64_t savedId;
@property (nonatomic) int64_t convertStars;
@property (nonatomic) int64_t upgradeStars;
@property (nonatomic) int64_t transferStars;
@property (nonatomic) int32_t giftNumber;
@property (nonatomic) int32_t canTransferAt;
@property (nonatomic) int32_t canResellAt;

@end

@implementation TGSavedStarGift

+ (TGSavedStarGift *)savedStarGiftWithActionData:(NSDictionary *)actionData ownerPeerId:(int64_t)ownerPeerId messageId:(int32_t)messageId fromPeerId:(int64_t)fromPeerId date:(int32_t)date
{
    TGStarGift *gift = actionData[@"gift"];
    if (![gift isKindOfClass:[TGStarGift class]])
        return nil;
    TGSavedStarGift *savedGift = [[TGSavedStarGift alloc] init];
    savedGift.ownerPeerId = ownerPeerId;
    savedGift.gift = gift;
    int64_t giftFromPeerId = [actionData[@"fromPeerId"] longLongValue];
    savedGift.fromPeerId = giftFromPeerId != 0 ? giftFromPeerId : fromPeerId;
    savedGift.date = date;
    savedGift.message = actionData[@"message"];
    savedGift.nameHidden = [actionData[@"nameHidden"] boolValue];
    savedGift.unsaved = ![actionData[@"saved"] boolValue];
    savedGift.refunded = [actionData[@"refunded"] boolValue];
    savedGift.canUpgrade = [actionData[@"canUpgrade"] boolValue];
    savedGift.messageId = messageId;
    savedGift.savedId = [actionData[@"savedId"] longLongValue];
    savedGift.convertStars = [actionData[@"convertStars"] longLongValue];
    savedGift.upgradeStars = [actionData[@"upgradeStars"] longLongValue];
    savedGift.transferStars = [actionData[@"transferStars"] longLongValue];
    savedGift.giftNumber = [actionData[@"giftNum"] intValue];
    savedGift.canTransferAt = [actionData[@"canTransferAt"] intValue];
    savedGift.canResellAt = [actionData[@"canResellAt"] intValue];
    return savedGift;
}

+ (TGSavedStarGift *)savedStarGiftWithObject:(TGTLDynamicObject *)object ownerPeerId:(int64_t)ownerPeerId
{
    if (![object isConstructor:@"savedStarGift"])
        return nil;
    TGStarGift *gift = [TGStarGift starGiftWithObject:[object objectField:@"gift"]];
    if (gift == nil)
        return nil;
    TGSavedStarGift *savedGift = [[TGSavedStarGift alloc] init];
    savedGift.ownerPeerId = ownerPeerId;
    savedGift.gift = gift;
    savedGift.fromPeerId = TGStoryPeerIdFromObject([object objectField:@"from_id"]);
    savedGift.date = [object int32Field:@"date"];
    savedGift.message = [[object objectField:@"message"] stringField:@"text"];
    savedGift.nameHidden = [object flag:@"name_hidden"];
    savedGift.unsaved = [object flag:@"unsaved"];
    savedGift.refunded = [object flag:@"refunded"];
    savedGift.canUpgrade = [object flag:@"can_upgrade"];
    savedGift.pinnedToTop = [object flag:@"pinned_to_top"];
    savedGift.messageId = [object int32Field:@"msg_id"];
    savedGift.savedId = [object int64Field:@"saved_id"];
    savedGift.convertStars = [object int64Field:@"convert_stars"];
    savedGift.upgradeStars = [object int64Field:@"upgrade_stars"];
    savedGift.transferStars = [object int64Field:@"transfer_stars"];
    savedGift.giftNumber = [object int32Field:@"gift_num"];
    savedGift.canTransferAt = [object int32Field:@"can_transfer_at"];
    savedGift.canResellAt = [object int32Field:@"can_resell_at"];
    return savedGift;
}

- (TGSavedStarGift *)copyWithMutation:(void (^)(TGSavedStarGift *))mutation
{
    TGSavedStarGift *copy = [[TGSavedStarGift alloc] init];
    copy.ownerPeerId = _ownerPeerId;
    copy.gift = _gift;
    copy.fromPeerId = _fromPeerId;
    copy.date = _date;
    copy.message = _message;
    copy.nameHidden = _nameHidden;
    copy.unsaved = _unsaved;
    copy.refunded = _refunded;
    copy.canUpgrade = _canUpgrade;
    copy.pinnedToTop = _pinnedToTop;
    copy.messageId = _messageId;
    copy.savedId = _savedId;
    copy.convertStars = _convertStars;
    copy.upgradeStars = _upgradeStars;
    copy.transferStars = _transferStars;
    copy.giftNumber = _giftNumber;
    copy.canTransferAt = _canTransferAt;
    copy.canResellAt = _canResellAt;
    mutation(copy);
    return copy;
}

- (TGSavedStarGift *)savedStarGiftWithUnsaved:(bool)unsaved
{
    return [self copyWithMutation:^(TGSavedStarGift *copy)
    {
        copy.unsaved = unsaved;
    }];
}

- (TGSavedStarGift *)savedStarGiftWithPinnedToTop:(bool)pinnedToTop
{
    return [self copyWithMutation:^(TGSavedStarGift *copy)
    {
        copy.pinnedToTop = pinnedToTop;
    }];
}

- (bool)canManage
{
    if (_refunded)
        return false;
    if (_ownerPeerId == TGTelegraphInstance.clientUserId)
        return _messageId != 0;
    return _savedId != 0;
}

- (bool)canConvert
{
    return [self canManage] && !_gift.unique && _convertStars > 0;
}

- (bool)canTransfer
{
    return [self canManage] && _gift.unique && (_canTransferAt == 0 || _canTransferAt <= (int32_t)[[NSDate date] timeIntervalSince1970]);
}

- (bool)canResell
{
    return [self canManage] && _gift.unique && !_gift.resaleTonOnly && (_canResellAt == 0 || _canResellAt <= (int32_t)[[NSDate date] timeIntervalSince1970]);
}

@end
