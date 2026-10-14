#import "TGCommunity.h"

#import "../submodules/LegacyComponents/LegacyComponents/PSKeyValueCoder.h"

@implementation TGCommunity

- (instancetype)initWithCommunityId:(int64_t)communityId accessHash:(int64_t)accessHash title:(NSString *)title
{
    self = [super init];
    if (self != nil)
    {
        _communityId = communityId;
        _accessHash = accessHash;
        _title = title;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithCommunityId:[coder decodeInt64ForCKey:"i"] accessHash:[coder decodeInt64ForCKey:"ah"] title:[coder decodeStringForCKey:"t"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt64:_communityId forCKey:"i"];
    [coder encodeInt64:_accessHash forCKey:"ah"];
    [coder encodeString:_title forCKey:"t"];
}

- (TGCommunity *)communityByMergingCommunity:(TGCommunity *)community
{
    if (community == nil)
        return self;

    int64_t accessHash = community.accessHash != 0 ? community.accessHash : _accessHash;
    NSString *title = community.title.length != 0 ? community.title : _title;
    return [[TGCommunity alloc] initWithCommunityId:_communityId accessHash:accessHash title:title];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGCommunity class]])
        return false;

    TGCommunity *other = object;
    return other.communityId == _communityId && other.accessHash == _accessHash && (other.title == _title || [other.title isEqualToString:_title]);
}

- (NSUInteger)hash
{
    return (NSUInteger)_communityId;
}

@end

@implementation TGCommunityChats

- (instancetype)initWithCommunity:(TGCommunity *)community joinedConversations:(NSArray *)joinedConversations viewableConversations:(NSArray *)viewableConversations
{
    self = [super init];
    if (self != nil)
    {
        _community = community;
        _joinedConversations = joinedConversations;
        _viewableConversations = viewableConversations;
    }
    return self;
}

@end
