#import "TLDialog$dialogFeed.h"

#import "TLMetaClassStore.h"


@implementation TLDialog$dialogFeed

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLDialog$dialogFeed serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLDialog$dialogFeed *result = [[TLDialog$dialogFeed alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    
    {
        int32_t signature = [is readInt32];
        result.peer = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil) {
            return nil;
        }
    }
    
    result.top_message = [is readInt32];
    
    result.feed_id = [is readInt32];
    
    {
        [is readInt32];
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        int32_t count = [is readInt32];
        for (int32_t i = 0; i < count; i++) {
            int32_t value = [is readInt32];
            [items addObject:@(value)];
        }
        
        result.feed_other_channels = items;
    }
    
    if (flags & (1 << 3)) {
        int32_t signature = [is readInt32];
        result.read_max_position = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil) {
            return nil;
        }
    }
    
    result.unread_count = [is readInt32];
    result.unread_muted_count = [is readInt32];
    
    return result;
}

@end

