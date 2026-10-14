#import "TLChatFull$communityFull.h"

#import "TLMetaClassStore.h"

@implementation TLChatFull$communityFull

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xcbb7a507;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLChatFull$communityFull serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChatFull$communityFull *result = [[TLChatFull$communityFull alloc] init];

    int32_t flags = [is readInt32];
    result.flags = flags;
    result.community_id = [is readInt64];
    result.about = [is readString];

    {
        int32_t photoSignature = [is readInt32];
        result.chat_photo = TLMetaClassStore::constructObject(is, photoSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    {
        int32_t vectorSignature = [is readInt32];
        if (vectorSignature != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        {
            if (error != NULL)
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"communityFull.linked_peers expected vector, got %08x", vectorSignature]}];
            return nil;
        }

        int32_t count = [is readInt32];
        NSMutableArray *linkedPeers = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
        for (int32_t i = 0; i < count; i++)
        {
            int32_t itemSignature = [is readInt32];
            id item = TLMetaClassStore::constructObject(is, itemSignature, environment, nil, error);
            if (error != nil && *error != nil)
                return nil;
            if (item != nil)
                [linkedPeers addObject:item];
        }
        result.linked_peers = linkedPeers;
    }

    if (flags & (1 << 1))
        result.admins_count = [is readInt32];

    if (flags & (1 << 2))
        result.kicked_count = [is readInt32];

    if (flags & (1 << 0))
        result.peer_link_requests_pending = [is readInt32];

    return result;
}

@end
