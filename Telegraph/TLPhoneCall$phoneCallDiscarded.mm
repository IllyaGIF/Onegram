#import "TLPhoneCall$phoneCallDiscarded.h"

#import "TLMetaClassStore.h"

@implementation TLPhoneCall$phoneCallDiscarded

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLPhoneCall$phoneCallDiscarded serialization not supported");
}


- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPhoneCall$phoneCallDiscarded *result = [[TLPhoneCall$phoneCallDiscarded alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    
    result.n_id = [is readInt64];
    
    if (flags & (1 << 0) ) {
        int32_t signature = [is readInt32];
        result.reason = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    }
    
    if (flags & (1 << 1)) {
        result.duration = [is readInt32];
    }
    
    return result;
}

@end
