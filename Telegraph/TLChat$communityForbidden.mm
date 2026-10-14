#import "TLChat$communityForbidden.h"

#import "TLMetaClassStore.h"

@implementation TLChat$communityForbidden

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xfd3cdab8;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLChat$communityForbidden serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChat$communityForbidden *result = [[TLChat$communityForbidden alloc] init];

    int32_t flags = [is readInt32];
    result.flags = flags;
    result.community_id = [is readInt64];

    if (flags & (1 << 13))
        result.access_hash = [is readInt64];

    result.title = [is readString];

    return result;
}

@end
