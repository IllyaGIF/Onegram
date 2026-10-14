#import "TLCommunityPeer.h"

#import "TLMetaClassStore.h"
#import "TLPeer.h"

@implementation TLCommunityPeer

- (int32_t)TLconstructorSignature
{
    return (int32_t)0x76141ebd;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x36f5ea83;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (bool)can_view_history
{
    return self.flags & (1 << 2);
}

@end

@implementation TLCommunityPeer$communityPeer

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLCommunityPeer$communityPeer serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCommunityPeer$communityPeer *result = [[TLCommunityPeer$communityPeer alloc] init];

    int32_t flags = [is readInt32];
    result.flags = flags;

    if (flags & (1 << 0))
    {
        int32_t visibleSignature = [is readInt32];
        id visible = TLMetaClassStore::constructObject(is, visibleSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
        if ([visible isKindOfClass:[NSNumber class]])
            result.visible = visible;
    }

    {
        int32_t peerSignature = [is readInt32];
        result.peer = TLMetaClassStore::constructObject(is, peerSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }

    return result;
}

@end
