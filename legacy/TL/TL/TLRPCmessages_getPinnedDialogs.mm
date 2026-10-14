#import "TLRPCmessages_getPinnedDialogs.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLmessages_PeerDialogs.h"

@implementation TLRPCmessages_getPinnedDialogs


- (Class)responseClass
{
    return [TLmessages_PeerDialogs class];
}

- (int)impliedResponseSignature
{
    return (int)0x3371c354;
}

- (int)layerVersion
{
    return 225;
}

- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

@implementation TLRPCmessages_getPinnedDialogs$messages_getPinnedDialogs : TLRPCmessages_getPinnedDialogs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xd6b94df2;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCmessages_getPinnedDialogs$messages_getPinnedDialogs *object = [[TLRPCmessages_getPinnedDialogs$messages_getPinnedDialogs alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:self.folder_id];
}

@end

