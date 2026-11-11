#import "TGDialogFilterSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGDialogFilter.h"
#import "TGTLDynamic.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"
#import "TGDatabase.h"
#import "TGStoriesSignals.h"
#import "TGOnegramSettings.h"
#import "TL/TLMetaScheme.h"

NSString *const TGDialogFiltersDidChangeNotification = @"TGDialogFiltersDidChangeNotification";

static NSString *const TGDialogFilterLocalColorsKey = @"dialogFilters.localColors";
static NSString *const TGDialogFilterColorsRequirePremiumKey = @"dialogFilters.colorsRequirePremium";
static NSString *const TGDialogFilterServerTagsKey = @"dialogFilters.serverTagsEnabled";

@implementation TGDialogFiltersState

- (instancetype)initWithFilters:(NSArray *)filters tagsEnabled:(bool)tagsEnabled
{
    self = [super init];
    if (self != nil)
    {
        _filters = filters == nil ? @[] : filters;
        _tagsEnabled = tagsEnabled;
    }
    return self;
}

@end

@interface TGDialogFilterSuggestion ()

- (instancetype)initWithFilter:(TGDialogFilter *)filter descriptionText:(NSString *)descriptionText;

@end

@implementation TGDialogFilterSuggestion

- (instancetype)initWithFilter:(TGDialogFilter *)filter descriptionText:(NSString *)descriptionText
{
    self = [super init];
    if (self != nil)
    {
        _filter = filter;
        _descriptionText = descriptionText == nil ? @"" : descriptionText;
    }
    return self;
}

@end

@interface TGDialogFilterInvite ()

- (instancetype)initWithObject:(TGTLDynamicObject *)object;

@end

static int64_t TGDialogFilterPeerIdForPeerObject(id peer)
{
    if (![peer isKindOfClass:[TGTLDynamicObject class]])
        return 0;
    TGTLDynamicObject *object = peer;
    if ([object isConstructor:@"peerUser"])
        return [object int64Field:@"user_id"];
    if ([object isConstructor:@"peerChat"])
        return TGPeerIdFromGroupId([object int64Field:@"chat_id"]);
    if ([object isConstructor:@"peerChannel"])
        return TGPeerIdFromChannelId([object int64Field:@"channel_id"]);
    return 0;
}

static NSArray *TGDialogFilterPeerIdsForPeerObjects(NSArray *peers)
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (![peers isKindOfClass:[NSArray class]])
        return result;
    for (id peer in peers)
    {
        int64_t peerId = TGDialogFilterPeerIdForPeerObject(peer);
        if (peerId != 0 && ![result containsObject:@(peerId)])
            [result addObject:@(peerId)];
    }
    return result;
}

@implementation TGDialogFilterInvite

- (instancetype)initWithObject:(TGTLDynamicObject *)object
{
    self = [super init];
    if (self != nil)
    {
        _title = [object stringField:@"title"] ?: @"";
        _url = [object stringField:@"url"] ?: @"";
        NSString *slug = [[_url componentsSeparatedByString:@"/"] lastObject];
        _slug = slug == nil ? @"" : slug;
        _peerIds = TGDialogFilterPeerIdsForPeerObjects([object arrayField:@"peers"]);
    }
    return self;
}

@end

@implementation TGDialogFilterSignals

+ (TGTLDynamicObject *)inputChatlistForFilter:(TGDialogFilter *)filter
{
    return [TGTLDynamicObject objectWithConstructor:@"inputChatlistDialogFilter" fields:@{@"filter_id": @(filter.filterId)}];
}

+ (NSArray *)inputPeersForPeerIds:(NSArray *)peerIds
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:peerIds.count];
    for (NSNumber *peerId in peerIds)
    {
        id inputPeer = [TGStoriesSignals inputPeerForPeerId:peerId.longLongValue];
        if (inputPeer != nil && ![inputPeer isKindOfClass:[TLInputPeer$inputPeerEmpty class]])
            [result addObject:inputPeer];
    }
    return result;
}

+ (NSData *)customPropertyForKey:(NSString *)key
{
    if (TGTelegraphInstance.clientUserId == 0)
        return nil;
    return [TGDatabaseInstance() customProperty:key];
}

+ (void)setCustomProperty:(NSData *)value forKey:(NSString *)key
{
    if (TGTelegraphInstance.clientUserId == 0)
        return;
    [TGDatabaseInstance() setCustomProperty:key value:value == nil ? [NSData data] : value];
}

+ (bool)boolPropertyForKey:(NSString *)key defaultValue:(bool)defaultValue
{
    NSData *data = [self customPropertyForKey:key];
    if (data.length != 1)
        return defaultValue;
    return ((const uint8_t *)data.bytes)[0] != 0;
}

+ (void)setBoolProperty:(bool)value forKey:(NSString *)key
{
    uint8_t byte = value ? 1 : 0;
    [self setCustomProperty:[NSData dataWithBytes:&byte length:1] forKey:key];
}

+ (NSDictionary *)localColors
{
    NSData *data = [self customPropertyForKey:TGDialogFilterLocalColorsKey];
    if (data.length == 0)
        return @{};
    id value = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

+ (void)setLocalColor:(int32_t)color forFilterId:(int32_t)filterId
{
    NSMutableDictionary *colors = [[self localColors] mutableCopy];
    NSString *key = [NSString stringWithFormat:@"%d", (int)filterId];
    if (color >= 0 && color < TGDialogFilterColorCount)
        colors[key] = @(color);
    else
        [colors removeObjectForKey:key];
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:colors format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
    [self setCustomProperty:data forKey:TGDialogFilterLocalColorsKey];
}

+ (int32_t)effectiveColorForFilterId:(int32_t)filterId serverColor:(int32_t)serverColor
{
    if (serverColor >= 0 && serverColor < TGDialogFilterColorCount)
        return serverColor;
    NSNumber *color = [self localColors][[NSString stringWithFormat:@"%d", (int)filterId]];
    if ([color isKindOfClass:[NSNumber class]] && color.intValue >= 0 && color.intValue < TGDialogFilterColorCount)
        return color.intValue;
    return TGDialogFilterNoColor;
}

+ (bool)isPremium
{
    int64_t userId = TGTelegraphInstance.clientUserId;
    return userId != 0 && [TGDatabaseInstance() loadUser:userId].isPremium;
}

+ (NSUInteger)folderLimit
{
    return [self isPremium] ? 30 : 10;
}

+ (NSUInteger)chatsPerFolderLimit
{
    return [self isPremium] ? 200 : 100;
}

+ (NSUInteger)invitesPerFolderLimit
{
    return [self isPremium] ? 100 : 3;
}

+ (bool)tagsVisibleWithServerValue:(bool)serverValue
{
    NSInteger mode = [TGOnegramSettings integerForKey:TGOnegramSettingChatListFolderTags];
    if (mode == 1)
        return true;
    if (mode == 2)
        return false;
    return serverValue;
}

+ (bool)tagsVisible
{
    return [self tagsVisibleWithServerValue:[self boolPropertyForKey:TGDialogFilterServerTagsKey defaultValue:false]];
}

+ (void)storeServerTagsEnabled:(bool)enabled
{
    if ([self boolPropertyForKey:TGDialogFilterServerTagsKey defaultValue:!enabled] != enabled)
        [self setBoolProperty:enabled forKey:TGDialogFilterServerTagsKey];
}

+ (int32_t)unusedFilterIdForFilters:(NSArray *)filters
{
    NSMutableSet *used = [[NSMutableSet alloc] init];
    for (TGDialogFilter *filter in filters)
        [used addObject:@(filter.filterId)];
    for (int32_t filterId = 2; filterId < 256; filterId++)
    {
        if (![used containsObject:@(filterId)])
            return filterId;
    }
    return 0;
}

+ (NSString *)errorTypeForError:(id)error
{
    if ([error isKindOfClass:[NSString class]])
        return error;
    if (error == nil || [error isKindOfClass:[NSError class]])
        return nil;
    return [[TGTelegramNetworking instance] extractNetworkErrorType:error];
}

+ (NSString *)errorTextForError:(id)error
{
    NSString *type = [self errorTypeForError:error];
    if ([type isEqualToString:@"FILTER_INCLUDE_TOO_MUCH"] || [type isEqualToString:@"CHATLIST_INCLUDE_TOO_MUCH"])
        return [NSString stringWithFormat:TGLocalized(@"DialogFilters.ErrorTooManyChats"), (int)[self chatsPerFolderLimit]];
    if ([type isEqualToString:@"FILTER_EXCLUDE_TOO_MUCH"])
        return [NSString stringWithFormat:TGLocalized(@"DialogFilters.ErrorTooManyExcluded"), (int)[self chatsPerFolderLimit]];
    if ([type isEqualToString:@"DIALOG_FILTERS_TOO_MUCH"])
        return [NSString stringWithFormat:TGLocalized(@"DialogFilters.ErrorTooManyFolders"), (int)[self folderLimit]];
    if ([type isEqualToString:@"FILTER_INCLUDE_EMPTY"])
        return TGLocalized(@"DialogFilters.ErrorEmpty");
    if ([type isEqualToString:@"FILTER_TITLE_EMPTY"])
        return TGLocalized(@"DialogFilters.ErrorTitleEmpty");
    if ([type isEqualToString:@"INVITES_TOO_MUCH"])
        return [NSString stringWithFormat:TGLocalized(@"DialogFilters.ErrorTooManyInvites"), (int)[self invitesPerFolderLimit]];
    if ([type isEqualToString:@"CHATLISTS_TOO_MUCH"])
        return TGLocalized(@"DialogFilters.ErrorTooManyShared");
    if ([type isEqualToString:@"PEERS_LIST_EMPTY"])
        return TGLocalized(@"DialogFilters.ErrorInviteEmpty");
    if ([type isEqualToString:@"FILTER_NOT_SUPPORTED"] || [type isEqualToString:@"CHATLIST_EXCLUDE_INVALID"])
        return TGLocalized(@"DialogFilters.ErrorShareRules");
    if ([type hasPrefix:@"FLOOD_WAIT"])
        return TGLocalized(@"Login.CodeFloodError");
    return TGLocalized(@"Login.UnknownError");
}

+ (TGDialogFiltersState *)stateWithObject:(TGTLDynamicObject *)object
{
    if (![object isKindOfClass:[TGTLDynamicObject class]] || ![object isConstructor:@"messages.dialogFilters"])
        return nil;
    NSMutableArray *filters = [[NSMutableArray alloc] init];
    bool hasDefault = false;
    for (id filterObject in [object arrayField:@"filters"])
    {
        TGDialogFilter *filter = [TGDialogFilter filterWithObject:filterObject];
        if (filter == nil)
            continue;
        if (filter.defaultFilter)
        {
            if (hasDefault)
                continue;
            hasDefault = true;
        }
        else
            filter.color = [self effectiveColorForFilterId:filter.filterId serverColor:filter.color];
        [filters addObject:filter];
    }
    if (!hasDefault)
        [filters insertObject:[TGDialogFilter defaultDialogFilter] atIndex:0];
    bool tagsEnabled = [object flag:@"tags_enabled"];
    [self storeServerTagsEnabled:tagsEnabled];
    return [[TGDialogFiltersState alloc] initWithFilters:filters tagsEnabled:tagsEnabled];
}

+ (SSignal *)filters
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.getDialogFilters" parameters:@{}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        TGDialogFiltersState *state = [self stateWithObject:result];
        if (state == nil)
            return [SSignal fail:nil];
        return [SSignal single:state];
    }];
}

+ (void)postStateChanged:(TGDialogFiltersState *)state
{
    TGDispatchOnMainThread(^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGDialogFiltersDidChangeNotification object:nil userInfo:@{@"filters": state.filters, @"tagsEnabled": @(state.tagsEnabled)}];
    });
}

+ (SSignal *)reloadAfter:(SSignal *)signal
{
    return [signal mapToSignal:^SSignal *(__unused id next)
    {
        return [[self filters] onNext:^(TGDialogFiltersState *state)
        {
            [self postStateChanged:state];
        }];
    }];
}

+ (SSignal *)suggestedFilters
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.getSuggestedDialogFilters" parameters:@{}] mapToSignal:^SSignal *(NSArray *result)
    {
        if (![result isKindOfClass:[NSArray class]])
            return [SSignal fail:nil];
        NSMutableArray *suggestions = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *object in result)
        {
            if (![object isKindOfClass:[TGTLDynamicObject class]] || ![object isConstructor:@"dialogFilterSuggested"])
                continue;
            TGDialogFilter *filter = [TGDialogFilter filterWithObject:[object objectField:@"filter"]];
            if (filter == nil || filter.defaultFilter)
                continue;
            [suggestions addObject:[[TGDialogFilterSuggestion alloc] initWithFilter:filter descriptionText:[object stringField:@"description"]]];
        }
        return [SSignal single:suggestions];
    }];
}

+ (SSignal *)updateRequestForFilter:(TGDialogFilter *)filter
{
    return [TGTLDynamicRpc requestSignalWithMethod:@"messages.updateDialogFilter" parameters:@{@"id": @(filter.filterId), @"filter": [filter inputObject]}];
}

+ (SSignal *)saveFilter:(TGDialogFilter *)filter
{
    if (filter == nil || filter.defaultFilter || filter.filterId == 0)
        return [SSignal fail:nil];
    int32_t requestedColor = filter.color;
    bool hasColor = requestedColor >= 0 && requestedColor < TGDialogFilterColorCount;
    bool colorsRequirePremium = hasColor && ![self isPremium] && [self boolPropertyForKey:TGDialogFilterColorsRequirePremiumKey defaultValue:false];
    TGDialogFilter *sentFilter = [filter copy];
    if (colorsRequirePremium)
        sentFilter.color = TGDialogFilterNoColor;
    int32_t filterId = filter.filterId;

    SSignal *request = [[self updateRequestForFilter:sentFilter] catch:^SSignal *(id error)
    {
        if (!hasColor || sentFilter.color == TGDialogFilterNoColor || ![[self errorTypeForError:error] isEqualToString:@"PREMIUM_ACCOUNT_REQUIRED"])
            return [SSignal fail:error];
        [self setBoolProperty:true forKey:TGDialogFilterColorsRequirePremiumKey];
        sentFilter.color = TGDialogFilterNoColor;
        return [self updateRequestForFilter:sentFilter];
    }];

    request = [request onNext:^(__unused id next)
    {
        [self setLocalColor:(sentFilter.color == TGDialogFilterNoColor && hasColor) ? requestedColor : TGDialogFilterNoColor forFilterId:filterId];
    }];
    return [self reloadAfter:request];
}

+ (SSignal *)deleteFilter:(TGDialogFilter *)filter
{
    if (filter == nil || filter.defaultFilter || filter.filterId == 0)
        return [SSignal fail:nil];
    int32_t filterId = filter.filterId;
    SSignal *request = [[TGTLDynamicRpc requestSignalWithMethod:@"messages.updateDialogFilter" parameters:@{@"id": @(filterId)}] onNext:^(__unused id next)
    {
        [self setLocalColor:TGDialogFilterNoColor forFilterId:filterId];
    }];
    return [self reloadAfter:request];
}

+ (SSignal *)leaveSuggestionsForFilter:(TGDialogFilter *)filter
{
    if (filter == nil || !filter.chatlist)
        return [SSignal single:@[]];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.getLeaveChatlistSuggestions" parameters:@{@"chatlist": [self inputChatlistForFilter:filter]}] map:^id(NSArray *peers)
    {
        return TGDialogFilterPeerIdsForPeerObjects(peers);
    }];
}

+ (SSignal *)leaveChatlist:(TGDialogFilter *)filter peerIds:(NSArray *)peerIds
{
    if (filter == nil || !filter.chatlist)
        return [SSignal fail:nil];
    int32_t filterId = filter.filterId;
    NSDictionary *parameters = @{@"chatlist": [self inputChatlistForFilter:filter], @"peers": [self inputPeersForPeerIds:peerIds]};
    SSignal *request = [[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.leaveChatlist" parameters:parameters dynamicTypes:[NSSet set]] mapToSignal:^SSignal *(id updates)
    {
        if (![updates isKindOfClass:[TLUpdates class]])
            return [SSignal fail:nil];
        [[TGTelegramNetworking instance] addUpdates:updates];
        [self setLocalColor:TGDialogFilterNoColor forFilterId:filterId];
        return [SSignal single:@true];
    }];
    return [self reloadAfter:request];
}

+ (SSignal *)reorderFilterIds:(NSArray *)filterIds
{
    return [self reloadAfter:[TGTLDynamicRpc requestSignalWithMethod:@"messages.updateDialogFiltersOrder" parameters:@{@"order": filterIds == nil ? @[] : filterIds}]];
}

+ (SSignal *)setTagsVisible:(bool)visible
{
    [TGOnegramSettings setInteger:visible ? 1 : 2 forKey:TGOnegramSettingChatListFolderTags];
    TGDispatchOnMainThread(^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGDialogFiltersDidChangeNotification object:nil userInfo:nil];
    });
    if (![self isPremium])
        return [SSignal single:@true];
    return [[[TGTLDynamicRpc requestSignalWithMethod:@"messages.toggleDialogFilterTags" parameters:@{@"enabled": @(visible)}] onNext:^(__unused id next)
    {
        [self storeServerTagsEnabled:visible];
    }] catch:^SSignal *(__unused id error)
    {
        return [SSignal single:@true];
    }];
}

+ (SSignal *)invitesForFilter:(TGDialogFilter *)filter
{
    if (filter == nil || filter.filterId == 0)
        return [SSignal single:@[]];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.getExportedInvites" parameters:@{@"chatlist": [self inputChatlistForFilter:filter]}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"chatlists.exportedInvites"])
            return [SSignal fail:nil];
        [TGStoriesSignals processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        NSMutableArray *invites = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *object in [result arrayField:@"invites"])
        {
            if ([object isKindOfClass:[TGTLDynamicObject class]] && [object isConstructor:@"exportedChatlistInvite"])
                [invites addObject:[[TGDialogFilterInvite alloc] initWithObject:object]];
        }
        return [SSignal single:invites];
    }];
}

+ (SSignal *)createInviteForFilter:(TGDialogFilter *)filter peerIds:(NSArray *)peerIds
{
    if (filter == nil || filter.filterId == 0)
        return [SSignal fail:nil];
    NSDictionary *parameters = @{@"chatlist": [self inputChatlistForFilter:filter], @"title": @"", @"peers": [self inputPeersForPeerIds:peerIds]};
    SSignal *request = [[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.exportChatlistInvite" parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"chatlists.exportedChatlistInvite"])
            return [SSignal fail:nil];
        TGTLDynamicObject *invite = [result objectField:@"invite"];
        if (![invite isKindOfClass:[TGTLDynamicObject class]] || ![invite isConstructor:@"exportedChatlistInvite"])
            return [SSignal fail:nil];
        return [SSignal single:[[TGDialogFilterInvite alloc] initWithObject:invite]];
    }];
    return [request mapToSignal:^SSignal *(TGDialogFilterInvite *invite)
    {
        return [[[self filters] onNext:^(TGDialogFiltersState *state)
        {
            [self postStateChanged:state];
        }] map:^id(__unused id state)
        {
            return invite;
        }];
    }];
}

+ (SSignal *)editInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter title:(NSString *)title peerIds:(NSArray *)peerIds
{
    if (invite.slug.length == 0 || filter == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"chatlist"] = [self inputChatlistForFilter:filter];
    parameters[@"slug"] = invite.slug;
    if (title != nil)
        parameters[@"title"] = title;
    if (peerIds != nil)
        parameters[@"peers"] = [self inputPeersForPeerIds:peerIds];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.editExportedInvite" parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"exportedChatlistInvite"])
            return [SSignal fail:nil];
        return [SSignal single:[[TGDialogFilterInvite alloc] initWithObject:result]];
    }];
}

+ (SSignal *)deleteInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter
{
    if (invite.slug.length == 0 || filter == nil)
        return [SSignal fail:nil];
    return [self reloadAfter:[TGTLDynamicRpc requestSignalWithMethod:@"chatlists.deleteExportedInvite" parameters:@{@"chatlist": [self inputChatlistForFilter:filter], @"slug": invite.slug}]];
}

@end
