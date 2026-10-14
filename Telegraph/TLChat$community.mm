#import "TLChat$community.h"

#import "TLMetaClassStore.h"

@implementation TLChat$community

- (int32_t)TLconstructorSignature
{
    return (int32_t)0x65efe954;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLChat$community serialization not supported");
}

- (bool)creator
{
    return self.flags & (1 << 0);
}

- (bool)left
{
    return self.flags & (1 << 2);
}

- (bool)min
{
    return self.flags & (1 << 12);
}

- (bool)collapsed_in_dialogs
{
    return self.flags2 & (1 << 20);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChat$community *result = [[TLChat$community alloc] init];

    int32_t flags = [is readInt32];
    result.flags = flags;
    result.flags2 = [is readInt32];
    result.community_id = [is readInt64];

    if (flags & (1 << 13))
        result.access_hash = [is readInt64];

    result.title = [is readString];

    {
        int32_t photoSignature = [is readInt32];
        result.photo = TLMetaClassStore::constructObject(is, photoSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    result.date = [is readInt32];

    if (flags & (1 << 14))
    {
        int32_t rightsSignature = [is readInt32];
        TLMetaClassStore::constructObject(is, rightsSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    if (flags & (1 << 18))
    {
        int32_t rightsSignature = [is readInt32];
        TLMetaClassStore::constructObject(is, rightsSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    return result;
}

@end
