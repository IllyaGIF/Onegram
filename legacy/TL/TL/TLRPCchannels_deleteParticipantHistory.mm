#import "TLRPCchannels_deleteParticipantHistory.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputChannel.h"
#import "TLInputPeer.h"
#import "TLmessages_AffectedHistory.h"

@implementation TLRPCchannels_deleteParticipantHistory


- (Class)responseClass
{
    return [TLmessages_AffectedHistory class];
}

- (int)impliedResponseSignature
{
    return (int)0xb45c69d1;
}

- (int)layerVersion
{
    return 228;
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

@implementation TLRPCchannels_deleteParticipantHistory$channels_deleteParticipantHistory : TLRPCchannels_deleteParticipantHistory


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x367544db;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x2b418fec;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCchannels_deleteParticipantHistory$channels_deleteParticipantHistory *object = [[TLRPCchannels_deleteParticipantHistory$channels_deleteParticipantHistory alloc] init];
    object.channel = metaObject->getObject((int32_t)0xe11f3d41);
    object.participant = metaObject->getObject((int32_t)0x837816d4);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.channel;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe11f3d41, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.participant;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x837816d4, value));
    }
}


@end

