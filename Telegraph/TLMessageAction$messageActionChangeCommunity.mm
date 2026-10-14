#import "TLMessageAction$messageActionChangeCommunity.h"

#import "TLMetaClassStore.h"

@implementation TLMessageAction$messageActionChangeCommunity

- (int32_t)TLconstructorSignature
{
    return (int32_t)0x5d20bae8;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLMessageAction$messageActionChangeCommunity serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLMessageAction$messageActionChangeCommunity *result = [[TLMessageAction$messageActionChangeCommunity alloc] init];

    int32_t flags = [is readInt32];
    result.flags = flags;

    if (flags & (1 << 0))
        result.community_id = [is readInt64];

    return result;
}

@end
