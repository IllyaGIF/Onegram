#import "TLaccount_Password$account_password.h"

#import "TLMetaClassStore.h"


@implementation TLaccount_Password$account_password

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLaccount_Password$account_password serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLaccount_Password$account_password *result = [[TLaccount_Password$account_password alloc] init];
    
    result.flags = [is readInt32];
    
    if (result.flags & (1 << 2)) {
        int32_t signature = [is readInt32];
        result.current_algo = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        
        result.srp_B = [is readBytes];
        result.srp_id = [is readInt64];
    }
    
    if (result.flags & (1 << 3)) {
        result.hint = [is readString];
    }
    
    if (result.flags & (1 << 4)) {
        result.email_unconfirmed_pattern = [is readString];
    }
    
    {
        int32_t signature = [is readInt32];
        result.n_new_algo = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    }
    
    {
        int32_t signature = [is readInt32];
        result.n_new_secure_algo = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    }
    
    result.secure_random = [is readBytes];
    
    if (result.flags & (1 << 5)) {
        [is readInt32];
    }
    
    if (result.flags & (1 << 6)) {
        [is readString];
    }
    
    return result;
}

@end
