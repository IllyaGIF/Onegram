#import "TLUpdate$updateReadFeed.h"

#import "TLMetaClassStore.h"

@implementation TLUpdate$updateReadFeed

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLUpdate$updateReadFeed serialization not supported");
}


- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateReadFeed *result = [[TLUpdate$updateReadFeed alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.feed_id = [is readInt32];

    {
        int32_t signature = [is readInt32];
        result.max_position = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    }
    
    if (flags & (1 << 0) ) {
        result.unread_count = [is readInt32];
        result.unread_muted_count = [is readInt32];
    }
    
    return result;
}


@end
