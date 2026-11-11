#import "TGDialogFilter.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGTelegraph.h"
#import "TL/TLMetaScheme.h"

const int32_t TGDialogFilterIncludeCategoriesMask = TGDialogFilterIncludeContacts | TGDialogFilterIncludeNonContacts | TGDialogFilterIncludeGroups | TGDialogFilterIncludeChannels | TGDialogFilterIncludeBots;
const int32_t TGDialogFilterExcludeCategoriesMask = TGDialogFilterExcludeMuted | TGDialogFilterExcludeRead | TGDialogFilterExcludeArchived;
const int32_t TGDialogFilterNoColor = -1;
const int32_t TGDialogFilterColorCount = 7;
const NSUInteger TGDialogFilterTitleMaxLength = 12;

static int64_t TGDialogFilterPeerIdForInputPeer(id peer)
{
    if ([peer isKindOfClass:[TGTLDynamicObject class]])
    {
        TGTLDynamicObject *object = peer;
        if ([object isConstructor:@"inputPeerSelf"])
            return TGTelegraphInstance.clientUserId;
        if ([object isConstructor:@"inputPeerUser"] || [object isConstructor:@"inputPeerUserFromMessage"])
            return [object int64Field:@"user_id"];
        if ([object isConstructor:@"inputPeerChat"])
            return TGPeerIdFromGroupId([object int64Field:@"chat_id"]);
        if ([object isConstructor:@"inputPeerChannel"] || [object isConstructor:@"inputPeerChannelFromMessage"])
            return TGPeerIdFromChannelId([object int64Field:@"channel_id"]);
        return 0;
    }
    if ([peer isKindOfClass:[TLInputPeer$inputPeerSelf class]])
        return TGTelegraphInstance.clientUserId;
    if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]])
        return ((TLInputPeer$inputPeerUser *)peer).user_id;
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]])
        return TGPeerIdFromGroupId(((TLInputPeer$inputPeerChat *)peer).chat_id);
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
        return TGPeerIdFromChannelId(((TLInputPeer$inputPeerChannel *)peer).channel_id);
    return 0;
}

static TLInputPeer *TGDialogFilterLegacyInputPeer(id peer, int64_t peerId)
{
    if ([peer isKindOfClass:[TLInputPeer class]])
        return peer;
    if ([peer isKindOfClass:[TGTLDynamicObject class]])
    {
        TGTLDynamicObject *object = peer;
        if ([object isConstructor:@"inputPeerSelf"])
            return [[TLInputPeer$inputPeerSelf alloc] init];
        if ([object isConstructor:@"inputPeerUser"])
        {
            TLInputPeer$inputPeerUser *result = [[TLInputPeer$inputPeerUser alloc] init];
            result.user_id = [object int64Field:@"user_id"];
            result.access_hash = [object int64Field:@"access_hash"];
            return result;
        }
        if ([object isConstructor:@"inputPeerChat"])
        {
            TLInputPeer$inputPeerChat *result = [[TLInputPeer$inputPeerChat alloc] init];
            result.chat_id = [object int64Field:@"chat_id"];
            return result;
        }
        if ([object isConstructor:@"inputPeerChannel"])
        {
            TLInputPeer$inputPeerChannel *result = [[TLInputPeer$inputPeerChannel alloc] init];
            result.channel_id = [object int64Field:@"channel_id"];
            result.access_hash = [object int64Field:@"access_hash"];
            return result;
        }
    }
    if (peerId == 0)
        return nil;
    TLInputPeer *result = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:0];
    return [result isKindOfClass:[TLInputPeer$inputPeerEmpty class]] ? nil : result;
}

static NSArray *TGDialogFilterUniquePeerIds(NSArray *peerIds)
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:peerIds.count];
    NSMutableSet *seen = [[NSMutableSet alloc] initWithCapacity:peerIds.count];
    for (NSNumber *peerId in peerIds)
    {
        if (![peerId isKindOfClass:[NSNumber class]] || peerId.longLongValue == 0 || [seen containsObject:peerId])
            continue;
        [seen addObject:peerId];
        [result addObject:peerId];
    }
    return result;
}

@interface TGDialogFilter ()
{
    NSMutableDictionary *_inputPeers;
    NSString *_originalTitle;
    NSArray *_originalTitleEntities;
}

@end

@implementation TGDialogFilter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _title = @"";
        _color = TGDialogFilterNoColor;
        _pinnedPeerIds = @[];
        _includePeerIds = @[];
        _excludePeerIds = @[];
        _inputPeers = [[NSMutableDictionary alloc] init];
        _originalTitleEntities = @[];
    }
    return self;
}

+ (instancetype)defaultDialogFilter
{
    TGDialogFilter *filter = [[TGDialogFilter alloc] init];
    filter.defaultFilter = true;
    filter.title = TGLocalized(@"DialogList.Title");
    return filter;
}

+ (instancetype)emptyFilterWithId:(int32_t)filterId
{
    TGDialogFilter *filter = [[TGDialogFilter alloc] init];
    filter.filterId = filterId;
    return filter;
}

+ (instancetype)filterWithObject:(TGTLDynamicObject *)object
{
    if (![object isKindOfClass:[TGTLDynamicObject class]])
        return nil;
    if ([object isConstructor:@"dialogFilterDefault"])
        return [self defaultDialogFilter];

    bool chatlist = [object isConstructor:@"dialogFilterChatlist"];
    if (!chatlist && ![object isConstructor:@"dialogFilter"])
        return nil;

    TGDialogFilter *filter = [[TGDialogFilter alloc] init];
    filter.filterId = [object int32Field:@"id"];
    filter.chatlist = chatlist;
    filter.hasMyInvites = [object flag:@"has_my_invites"];
    filter.titleNoAnimate = [object flag:@"title_noanimate"];

    id titleValue = [object field:@"title"];
    NSString *title = @"";
    NSArray *entities = @[];
    if ([titleValue isKindOfClass:[TGTLDynamicObject class]])
    {
        title = [(TGTLDynamicObject *)titleValue stringField:@"text"] ?: @"";
        NSArray *titleEntities = [(TGTLDynamicObject *)titleValue arrayField:@"entities"];
        if ([titleEntities isKindOfClass:[NSArray class]])
            entities = titleEntities;
    }
    else if ([titleValue isKindOfClass:[NSString class]])
        title = titleValue;
    filter.title = title;
    filter->_originalTitle = title;
    filter->_originalTitleEntities = entities;

    NSString *emoticon = [object stringField:@"emoticon"];
    filter.emoticon = emoticon.length == 0 ? nil : emoticon;
    filter.color = [object field:@"color"] == nil ? TGDialogFilterNoColor : [object int32Field:@"color"];

    if (!chatlist)
    {
        int32_t flags = 0;
        if ([object flag:@"contacts"])
            flags |= TGDialogFilterIncludeContacts;
        if ([object flag:@"non_contacts"])
            flags |= TGDialogFilterIncludeNonContacts;
        if ([object flag:@"groups"])
            flags |= TGDialogFilterIncludeGroups;
        if ([object flag:@"broadcasts"])
            flags |= TGDialogFilterIncludeChannels;
        if ([object flag:@"bots"])
            flags |= TGDialogFilterIncludeBots;
        if ([object flag:@"exclude_muted"])
            flags |= TGDialogFilterExcludeMuted;
        if ([object flag:@"exclude_read"])
            flags |= TGDialogFilterExcludeRead;
        if ([object flag:@"exclude_archived"])
            flags |= TGDialogFilterExcludeArchived;
        filter.flags = flags;
    }

    filter.pinnedPeerIds = [filter peerIdsRegisteringInputPeers:[object arrayField:@"pinned_peers"]];
    filter.includePeerIds = [filter peerIdsRegisteringInputPeers:[object arrayField:@"include_peers"]];
    filter.excludePeerIds = chatlist ? @[] : [filter peerIdsRegisteringInputPeers:[object arrayField:@"exclude_peers"]];
    return filter;
}

- (NSArray *)peerIdsRegisteringInputPeers:(NSArray *)peers
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (![peers isKindOfClass:[NSArray class]])
        return result;
    for (id peer in peers)
    {
        int64_t peerId = TGDialogFilterPeerIdForInputPeer(peer);
        if (peerId == 0)
            continue;
        _inputPeers[@(peerId)] = peer;
        [result addObject:@(peerId)];
    }
    return TGDialogFilterUniquePeerIds(result);
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGDialogFilter *filter = [[TGDialogFilter alloc] init];
    filter->_filterId = _filterId;
    filter->_defaultFilter = _defaultFilter;
    filter->_chatlist = _chatlist;
    filter->_hasMyInvites = _hasMyInvites;
    filter->_title = [_title copy];
    filter->_titleNoAnimate = _titleNoAnimate;
    filter->_emoticon = [_emoticon copy];
    filter->_color = _color;
    filter->_flags = _flags;
    filter->_pinnedPeerIds = [_pinnedPeerIds copy];
    filter->_includePeerIds = [_includePeerIds copy];
    filter->_excludePeerIds = [_excludePeerIds copy];
    filter->_inputPeers = [_inputPeers mutableCopy];
    filter->_originalTitle = [_originalTitle copy];
    filter->_originalTitleEntities = [_originalTitleEntities copy];
    return filter;
}

- (void)setTitle:(NSString *)title
{
    _title = title == nil ? @"" : [title copy];
}

- (void)setPinnedPeerIds:(NSArray *)pinnedPeerIds
{
    _pinnedPeerIds = TGDialogFilterUniquePeerIds(pinnedPeerIds);
}

- (void)setIncludePeerIds:(NSArray *)includePeerIds
{
    _includePeerIds = TGDialogFilterUniquePeerIds(includePeerIds);
}

- (void)setExcludePeerIds:(NSArray *)excludePeerIds
{
    _excludePeerIds = TGDialogFilterUniquePeerIds(excludePeerIds);
}

- (void)registerInputPeer:(id)inputPeer forPeerId:(int64_t)peerId
{
    if (inputPeer != nil && peerId != 0)
        _inputPeers[@(peerId)] = inputPeer;
}

- (NSArray *)includedPeerIds
{
    return TGDialogFilterUniquePeerIds([_pinnedPeerIds arrayByAddingObjectsFromArray:_includePeerIds]);
}

- (bool)includesPeerId:(int64_t)peerId
{
    return [_pinnedPeerIds containsObject:@(peerId)] || [_includePeerIds containsObject:@(peerId)];
}

- (bool)excludesPeerId:(int64_t)peerId
{
    return [_excludePeerIds containsObject:@(peerId)];
}

- (void)setIncludedPeerIds:(NSArray *)peerIds
{
    NSArray *unique = TGDialogFilterUniquePeerIds(peerIds);
    NSMutableArray *pinned = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in _pinnedPeerIds)
    {
        if ([unique containsObject:peerId])
            [pinned addObject:peerId];
    }
    NSMutableArray *include = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in unique)
    {
        if (![pinned containsObject:peerId])
            [include addObject:peerId];
    }
    _pinnedPeerIds = pinned;
    _includePeerIds = include;
    NSMutableArray *exclude = [_excludePeerIds mutableCopy];
    [exclude removeObjectsInArray:unique];
    _excludePeerIds = exclude;
}

- (void)setExcludedPeerIds:(NSArray *)peerIds
{
    NSArray *unique = TGDialogFilterUniquePeerIds(peerIds);
    _excludePeerIds = unique;
    NSMutableArray *pinned = [_pinnedPeerIds mutableCopy];
    [pinned removeObjectsInArray:unique];
    _pinnedPeerIds = pinned;
    NSMutableArray *include = [_includePeerIds mutableCopy];
    [include removeObjectsInArray:unique];
    _includePeerIds = include;
}

- (void)addIncludedPeerId:(int64_t)peerId
{
    if (peerId == 0 || [self includesPeerId:peerId])
        return;
    [self setIncludedPeerIds:[[self includedPeerIds] arrayByAddingObject:@(peerId)]];
}

- (void)removeIncludedPeerId:(int64_t)peerId
{
    NSMutableArray *peerIds = [[self includedPeerIds] mutableCopy];
    [peerIds removeObject:@(peerId)];
    [self setIncludedPeerIds:peerIds];
}

- (void)addExcludedPeerId:(int64_t)peerId
{
    if (peerId == 0 || [self excludesPeerId:peerId])
        return;
    [self setExcludedPeerIds:[_excludePeerIds arrayByAddingObject:@(peerId)]];
}

- (void)removeExcludedPeerId:(int64_t)peerId
{
    NSMutableArray *peerIds = [_excludePeerIds mutableCopy];
    [peerIds removeObject:@(peerId)];
    _excludePeerIds = peerIds;
}

- (bool)hasCategoryRules
{
    return (_flags & (TGDialogFilterIncludeCategoriesMask | TGDialogFilterExcludeCategoriesMask)) != 0 || _excludePeerIds.count != 0;
}

- (id)inputPeerForPeerId:(int64_t)peerId
{
    id peer = _inputPeers[@(peerId)];
    if (peer != nil)
        return peer;
    peer = TGDialogFilterLegacyInputPeer(nil, peerId);
    if (peer != nil)
        _inputPeers[@(peerId)] = peer;
    return peer;
}

- (NSArray *)inputPeersForPeerIds:(NSArray *)peerIds
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:peerIds.count];
    for (NSNumber *peerId in peerIds)
    {
        id peer = [self inputPeerForPeerId:peerId.longLongValue];
        if (peer != nil)
            [result addObject:peer];
    }
    return result;
}

- (NSArray *)legacyInputPeersForPeerIds:(NSArray *)peerIds
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:peerIds.count];
    for (NSNumber *peerId in peerIds)
    {
        TLInputPeer *peer = TGDialogFilterLegacyInputPeer(_inputPeers[peerId], peerId.longLongValue);
        if (peer != nil)
            [result addObject:peer];
    }
    return result;
}

- (NSArray *)pinnedPeers
{
    return [self legacyInputPeersForPeerIds:_pinnedPeerIds];
}

- (NSArray *)includePeers
{
    return [self legacyInputPeersForPeerIds:_includePeerIds];
}

- (NSArray *)excludePeers
{
    return [self legacyInputPeersForPeerIds:_excludePeerIds];
}

- (TGTLDynamicObject *)inputObject
{
    if (_defaultFilter)
        return [TGTLDynamicObject objectWithConstructor:@"dialogFilterDefault" fields:@{}];

    NSArray *entities = [_title isEqualToString:_originalTitle ?: @""] ? (_originalTitleEntities ?: @[]) : @[];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
    fields[@"id"] = @(_filterId);
    fields[@"title"] = [TGTLDynamicObject objectWithConstructor:@"textWithEntities" fields:@{@"text": _title ?: @"", @"entities": entities}];
    if (_titleNoAnimate && entities.count != 0)
        fields[@"title_noanimate"] = @true;
    if (_emoticon.length != 0)
        fields[@"emoticon"] = _emoticon;
    if (_color >= 0 && _color < TGDialogFilterColorCount)
        fields[@"color"] = @(_color);
    fields[@"pinned_peers"] = [self inputPeersForPeerIds:_pinnedPeerIds];
    fields[@"include_peers"] = [self inputPeersForPeerIds:_includePeerIds];

    if (_chatlist)
    {
        if (_hasMyInvites)
            fields[@"has_my_invites"] = @true;
        return [TGTLDynamicObject objectWithConstructor:@"dialogFilterChatlist" fields:fields];
    }

    if (_flags & TGDialogFilterIncludeContacts)
        fields[@"contacts"] = @true;
    if (_flags & TGDialogFilterIncludeNonContacts)
        fields[@"non_contacts"] = @true;
    if (_flags & TGDialogFilterIncludeGroups)
        fields[@"groups"] = @true;
    if (_flags & TGDialogFilterIncludeChannels)
        fields[@"broadcasts"] = @true;
    if (_flags & TGDialogFilterIncludeBots)
        fields[@"bots"] = @true;
    if (_flags & TGDialogFilterExcludeMuted)
        fields[@"exclude_muted"] = @true;
    if (_flags & TGDialogFilterExcludeRead)
        fields[@"exclude_read"] = @true;
    if (_flags & TGDialogFilterExcludeArchived)
        fields[@"exclude_archived"] = @true;
    fields[@"exclude_peers"] = [self inputPeersForPeerIds:_excludePeerIds];
    return [TGTLDynamicObject objectWithConstructor:@"dialogFilter" fields:fields];
}

- (bool)isContentEqualToFilter:(TGDialogFilter *)filter
{
    if (filter == nil)
        return false;
    return _filterId == filter.filterId && _defaultFilter == filter.defaultFilter && _chatlist == filter.chatlist && _flags == filter.flags && _color == filter.color && TGStringCompare(_title, filter.title) && TGStringCompare(_emoticon ?: @"", filter.emoticon ?: @"") && [_pinnedPeerIds isEqualToArray:filter.pinnedPeerIds] && [_includePeerIds isEqualToArray:filter.includePeerIds] && [_excludePeerIds isEqualToArray:filter.excludePeerIds];
}

+ (UIColor *)colorForIndex:(int32_t)index
{
    static const uint32_t colors[] = {0xcc5049, 0xd67722, 0x955cdb, 0x40a920, 0x309eba, 0x368ad1, 0xc7508b};
    if (index < 0 || index >= TGDialogFilterColorCount)
        return nil;
    return UIColorRGB(colors[index]);
}

+ (NSArray *)availableEmoticons
{
    static NSArray *emoticons = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        emoticons = @[@"💬", @"✅", @"⭐", @"🤖", @"👤", @"👥", @"📢", @"🗂", @"🏠", @"💼", @"❤", @"🍸", @"🎮", @"🎵", @"🎨", @"📕", @"🎓", @"💰", @"📈", @"✈", @"⚽", @"🐱", @"👑", @"🌹", @"🎭", @"💡", @"👌", @"🛫"];
    });
    return emoticons;
}

+ (NSArray *)includeCategories
{
    return @[@(TGDialogFilterIncludeContacts), @(TGDialogFilterIncludeNonContacts), @(TGDialogFilterIncludeGroups), @(TGDialogFilterIncludeChannels), @(TGDialogFilterIncludeBots)];
}

+ (NSArray *)excludeCategories
{
    return @[@(TGDialogFilterExcludeMuted), @(TGDialogFilterExcludeRead), @(TGDialogFilterExcludeArchived)];
}

+ (NSString *)titleForCategory:(TGDialogFilterCategory)category
{
    switch (category)
    {
        case TGDialogFilterIncludeContacts:
            return TGLocalized(@"DialogFilters.Category.Contacts");
        case TGDialogFilterIncludeNonContacts:
            return TGLocalized(@"DialogFilters.Category.NonContacts");
        case TGDialogFilterIncludeGroups:
            return TGLocalized(@"DialogFilters.Category.Groups");
        case TGDialogFilterIncludeChannels:
            return TGLocalized(@"DialogFilters.Category.Channels");
        case TGDialogFilterIncludeBots:
            return TGLocalized(@"DialogFilters.Category.Bots");
        case TGDialogFilterExcludeMuted:
            return TGLocalized(@"DialogFilters.Category.Muted");
        case TGDialogFilterExcludeRead:
            return TGLocalized(@"DialogFilters.Category.Read");
        case TGDialogFilterExcludeArchived:
            return TGLocalized(@"DialogFilters.Category.Archived");
    }
    return @"";
}

@end
