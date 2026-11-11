#import "TGCustomEmojiSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGStickersSignals.h"
#import "TGRichMessageInlineImageStore.h"

#import "TGCustomEmojiThumbnail.h"

static NSString *const TGCustomEmojiRecentKey = @"customEmoji.recent";
static NSString *const TGCustomEmojiPacksKey = @"customEmoji.packs";
static const NSUInteger TGCustomEmojiRecentLimit = 32;

@implementation TGCustomEmojiItem

- (instancetype)initWithDocumentId:(int64_t)documentId alt:(NSString *)alt thumbnailUri:(NSString *)thumbnailUri
{
    self = [super init];
    if (self != nil)
    {
        _documentId = documentId;
        _alt = alt.length != 0 ? [alt copy] : @"\U0001F642";
        _thumbnailUri = [thumbnailUri copy];
        TGCustomEmojiRegisterThumbnailUri(documentId, thumbnailUri);
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"id"] = @(_documentId);
    dict[@"alt"] = _alt;
    if (_thumbnailUri.length != 0)
        dict[@"uri"] = _thumbnailUri;
    return dict;
}

+ (instancetype)itemWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]])
        return nil;
    int64_t documentId = [dict[@"id"] longLongValue];
    if (documentId == 0)
        return nil;
    NSString *alt = [dict[@"alt"] isKindOfClass:[NSString class]] ? dict[@"alt"] : nil;
    NSString *uri = [dict[@"uri"] isKindOfClass:[NSString class]] ? dict[@"uri"] : nil;
    return [[TGCustomEmojiItem alloc] initWithDocumentId:documentId alt:alt thumbnailUri:uri];
}

@end

@implementation TGCustomEmojiPack

- (instancetype)initWithPackId:(int64_t)packId title:(NSString *)title items:(NSArray *)items
{
    self = [super init];
    if (self != nil)
    {
        _packId = packId;
        _title = [title copy] ?: @"";
        _items = [items copy] ?: @[];
    }
    return self;
}

@end

@implementation TGCustomEmojiSignals

+ (id)propertyListForKey:(NSString *)key
{
    if (TGTelegraphInstance.clientUserId == 0)
        return nil;
    NSData *data = [TGDatabaseInstance() customProperty:key];
    if (data.length == 0)
        return nil;
    return [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
}

+ (void)setPropertyList:(id)propertyList forKey:(NSString *)key
{
    if (TGTelegraphInstance.clientUserId == 0 || propertyList == nil)
        return;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
    if (data != nil)
        [TGDatabaseInstance() setCustomProperty:key value:data];
}

+ (bool)canSendCustomEmoji
{
    int64_t userId = TGTelegraphInstance.clientUserId;
    return userId != 0 && [TGDatabaseInstance() loadUser:userId].isPremium;
}

+ (NSArray *)recentItems
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    id list = [self propertyListForKey:TGCustomEmojiRecentKey];
    if ([list isKindOfClass:[NSArray class]])
    {
        for (NSDictionary *dict in list)
        {
            TGCustomEmojiItem *item = [TGCustomEmojiItem itemWithDictionary:dict];
            if (item != nil)
                [items addObject:item];
        }
    }
    return items;
}

+ (void)addRecentItem:(TGCustomEmojiItem *)item
{
    if (item == nil || item.documentId == 0)
        return;
    NSMutableArray *list = [[NSMutableArray alloc] init];
    [list addObject:[item dictionaryRepresentation]];
    for (TGCustomEmojiItem *existing in [self recentItems])
    {
        if (existing.documentId != item.documentId && list.count < TGCustomEmojiRecentLimit)
            [list addObject:[existing dictionaryRepresentation]];
    }
    [self setPropertyList:list forKey:TGCustomEmojiRecentKey];
}

+ (NSString *)imageKeyForItem:(TGCustomEmojiItem *)item
{
    return [TGRichMessageInlineImageStore customEmojiKey:item.documentId];
}

+ (SSignal *)imageSignalForItem:(TGCustomEmojiItem *)item
{
    if (item.thumbnailUri.length != 0)
        return [TGRichMessageInlineImageStore imageSignalForUri:item.thumbnailUri];
    return [TGRichMessageInlineImageStore customEmojiImageSignal:item.documentId];
}

+ (NSString *)altForDocument:(TGDocumentMediaAttachment *)document associations:(NSDictionary *)associations
{
    NSString *alt = associations[@(document.documentId)];
    if (alt.length != 0)
        return alt;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]] && ((TGDocumentAttributeSticker *)attribute).alt.length != 0)
            return ((TGDocumentAttributeSticker *)attribute).alt;
    }
    return nil;
}

+ (TGCustomEmojiPack *)packWithStickerPack:(TGStickerPack *)stickerPack packId:(int64_t)packId title:(NSString *)title
{
    NSMutableDictionary *associations = [[NSMutableDictionary alloc] init];
    for (TGStickerAssociation *association in stickerPack.stickerAssociations)
    {
        for (NSNumber *documentId in association.documentIds)
        {
            if (associations[documentId] == nil && association.key.length != 0)
                associations[documentId] = association.key;
        }
    }
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (TGDocumentMediaAttachment *document in stickerPack.documents)
    {
        if (document.documentId == 0)
            continue;
        [items addObject:[[TGCustomEmojiItem alloc] initWithDocumentId:document.documentId alt:[self altForDocument:document associations:associations] thumbnailUri:TGCustomEmojiThumbnailUri(document)]];
    }
    return [[TGCustomEmojiPack alloc] initWithPackId:packId title:title.length != 0 ? title : stickerPack.title items:items];
}

+ (NSArray *)cachedPacks
{
    NSMutableArray *packs = [[NSMutableArray alloc] init];
    id list = [self propertyListForKey:TGCustomEmojiPacksKey];
    if (![list isKindOfClass:[NSDictionary class]])
        return packs;
    for (NSDictionary *packDict in list[@"packs"])
    {
        if (![packDict isKindOfClass:[NSDictionary class]])
            continue;
        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (NSDictionary *itemDict in packDict[@"items"])
        {
            TGCustomEmojiItem *item = [TGCustomEmojiItem itemWithDictionary:itemDict];
            if (item != nil)
                [items addObject:item];
        }
        NSString *title = [packDict[@"title"] isKindOfClass:[NSString class]] ? packDict[@"title"] : @"";
        [packs addObject:[[TGCustomEmojiPack alloc] initWithPackId:[packDict[@"id"] longLongValue] title:title items:items]];
    }
    return packs;
}

+ (int64_t)cachedPacksHash
{
    id list = [self propertyListForKey:TGCustomEmojiPacksKey];
    return [list isKindOfClass:[NSDictionary class]] ? [list[@"hash"] longLongValue] : 0;
}

+ (void)storePacks:(NSArray *)packs hash:(int64_t)hash
{
    NSMutableArray *list = [[NSMutableArray alloc] init];
    for (TGCustomEmojiPack *pack in packs)
    {
        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (TGCustomEmojiItem *item in pack.items)
            [items addObject:[item dictionaryRepresentation]];
        [list addObject:@{@"id": @(pack.packId), @"title": pack.title ?: @"", @"items": items}];
    }
    [self setPropertyList:@{@"hash": @(hash), @"packs": list} forKey:TGCustomEmojiPacksKey];
}

+ (SSignal *)remotePacksWithHash:(int64_t)hash
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.getEmojiStickers" parameters:@{@"hash": @(hash)}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"messages.allStickers"])
            return [SSignal complete];
        int64_t updatedHash = [result int64Field:@"hash"];
        NSMutableArray *packSignals = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *set in [result arrayField:@"sets"])
        {
            if (![set isKindOfClass:[TGTLDynamicObject class]] || [set flag:@"archived"])
                continue;
            int64_t packId = [set int64Field:@"id"];
            NSString *title = [set stringField:@"title"];
            TGStickerPackIdReference *reference = [[TGStickerPackIdReference alloc] initWithPackId:packId packAccessHash:[set int64Field:@"access_hash"] shortName:[set stringField:@"short_name"]];
            [packSignals addObject:[[[TGStickersSignals stickerPackInfo:reference] map:^id(id pack)
            {
                if (![pack isKindOfClass:[TGStickerPack class]])
                    return [NSNull null];
                return [self packWithStickerPack:pack packId:packId title:title];
            }] catch:^SSignal *(__unused id error)
            {
                return [SSignal single:[NSNull null]];
            }]];
        }
        if (packSignals.count == 0)
        {
            [self storePacks:@[] hash:updatedHash];
            return [SSignal single:@[]];
        }
        return [[SSignal combineSignals:packSignals] map:^id(NSArray *results)
        {
            NSMutableArray *packs = [[NSMutableArray alloc] init];
            for (id pack in results)
            {
                if ([pack isKindOfClass:[TGCustomEmojiPack class]] && ((TGCustomEmojiPack *)pack).items.count != 0)
                    [packs addObject:pack];
            }
            [self storePacks:packs hash:updatedHash];
            return packs;
        }];
    }];
}

+ (SSignal *)installedPacks
{
    return [[SSignal defer:^SSignal *
    {
        NSArray *cached = [self cachedPacks];
        SSignal *remote = [[self remotePacksWithHash:cached.count == 0 ? 0 : [self cachedPacksHash]] catch:^SSignal *(__unused id error)
        {
            return [SSignal complete];
        }];
        if (cached.count == 0)
            return remote;
        return [[SSignal single:cached] then:remote];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

@end
