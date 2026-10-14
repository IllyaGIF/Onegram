#import "TLRPCchannels_getAdminedPublicChannels.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLmessages_Chats.h"

@implementation TLRPCchannels_getAdminedPublicChannels


- (Class)responseClass
{
    return [TLmessages_Chats class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 55;
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

@implementation TLRPCchannels_getAdminedPublicChannels$channels_getAdminedPublicChannels : TLRPCchannels_getAdminedPublicChannels


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x8d8d82d7;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xda925482;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCchannels_getAdminedPublicChannels$channels_getAdminedPublicChannels *object = [[TLRPCchannels_getAdminedPublicChannels$channels_getAdminedPublicChannels alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

