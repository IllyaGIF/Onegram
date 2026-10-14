#import "TLMessages_BotResults$botResults.h"

#import "TLMetaClassStore.h"


@implementation TLMessages_BotResults$botResults

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLMessages_BotResults$botResults serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLMessages_BotResults$botResults *result = [[TLMessages_BotResults$botResults alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.query_id = [is readInt64];
    
    if (flags & (1 << 1)) {
        result.next_offset = [is readString];
    }
    
    if (flags & (1 << 2)) {
        int32_t signature = [is readInt32];
        result.switch_pm = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil) {
            return nil;
        }
    }

    if (flags & (1 << 3)) {
        int32_t signature = [is readInt32];
        if (signature == (int32_t)0xb57295d5) {
            [is readString];
            [is readString];
        } else {
            TLMetaClassStore::constructObject(is, signature, environment, nil, error);
            if (error != nil && *error != nil) {
                return nil;
            }
        }
    }
    
    {
        int32_t vectorSignature = [is readInt32];
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        int32_t count = [is readInt32];
        for (int32_t i = 0; i < count; i++) {
            int32_t signature = [is readInt32];
            id item = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
            if (error != nil && *error != nil) {
                return nil;
            }
            if (item != nil) {
                [items addObject:item];
            }
        }
        
        result.results = items;
    }
    
    result.cache_time = [is readInt32];
    
    {
        int32_t vectorSignature = [is readInt32];
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        int32_t count = [is readInt32];
        for (int32_t i = 0; i < count; i++) {
            int32_t signature = [is readInt32];
            id item = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
            if (error != nil && *error != nil) {
                return nil;
            }
            if (item != nil) {
                [items addObject:item];
            }
        }
        
        result.users = items;
    }
    
    return result;
}

- (bool)isMedia {
    return self.flags & (1 << 0);
}

@end
