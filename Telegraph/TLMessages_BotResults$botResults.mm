#import "TLMessages_BotResults$botResults.h"

#import "TLMetaClassStore.h"


static bool OGCompatReadFailed(NSError **error)
{
    return error != nil && *error != nil;
}

static id OGCompatReadObject(NSInputStream *is, id<TLSerializationEnvironment> environment, NSError **error)
{
    int32_t objectSignature = [is readInt32];
    return TLMetaClassStore::constructObject(is, objectSignature, environment, nil, error);
}

static NSArray *OGCompatReadObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, NSError **error)
{
    [is readInt32];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    int32_t count = [is readInt32];
    for (int32_t i = 0; i < count; i++) {
        id item = OGCompatReadObject(is, environment, error);
        if (OGCompatReadFailed(error))
            return nil;
        if (item != nil)
            [items addObject:item];
    }
    return items;
}

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
        result.switch_pm = OGCompatReadObject(is, environment, error);
        if (OGCompatReadFailed(error))
            return nil;
    }

    if (flags & (1 << 3)) {
        int32_t webviewSignature = [is readInt32];
        if (webviewSignature == (int32_t)0xb57295d5) {
            [is readString];
            [is readString];
        } else {
            TLMetaClassStore::constructObject(is, webviewSignature, environment, nil, error);
            if (OGCompatReadFailed(error))
                return nil;
        }
    }
    
    NSArray *results = OGCompatReadObjectVector(is, environment, error);
    if (OGCompatReadFailed(error))
        return nil;
    result.results = results;
    
    result.cache_time = [is readInt32];
    
    NSArray *users = OGCompatReadObjectVector(is, environment, error);
    if (OGCompatReadFailed(error))
        return nil;
    result.users = users;
    
    return result;
}

- (bool)isMedia {
    return self.flags & (1 << 0);
}

@end
