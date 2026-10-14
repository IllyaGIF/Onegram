#import "TLDialog$dialogCommunity.h"

#import "TLMetaClassStore.h"

@implementation TLDialog$dialogCommunity

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xf78a0973;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLDialog$dialogCommunity serialization not supported");
}

- (bool)pinned
{
    return self.flags & (1 << 2);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDialog$dialogCommunity *result = [[TLDialog$dialogCommunity alloc] init];

    result.flags = [is readInt32];
    result.community_id = [is readInt64];

    {
        int32_t settingsSignature = [is readInt32];
        result.notify_settings = TLMetaClassStore::constructObject(is, settingsSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    return result;
}

@end
