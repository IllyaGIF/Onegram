#import "TLMessageFwdHeader$messageFwdHeader.h"

#import "TLMetaClassStore.h"


@implementation TLMessageFwdHeader$messageFwdHeader

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLMessageFwdHeader$messageFwdHeader serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLMessageFwdHeader$messageFwdHeader *result = [[TLMessageFwdHeader$messageFwdHeader alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    
    if (flags & (1 << 0)) {
        result.from_id = [is readInt32];
    }
    
    result.date = [is readInt32];
    
    if (flags & (1 << 1)) {
        result.channel_id = [is readInt32];
    }
    
    if (flags & (1 << 2)) {
        result.channel_post = [is readInt32];
    }
    
    if (flags & (1 << 3)) {
        result.post_author = [is readString];
    }
    
    if (flags & (1 << 4)) {
        int32_t signature = [is readInt32];
        result.saved_from_peer = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil) {
            return nil;
        }
        
        result.saved_from_msg_id = [is readInt32];
    }
    
    return result;
}

@end
