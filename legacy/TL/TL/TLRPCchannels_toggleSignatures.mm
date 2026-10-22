#import "TLRPCchannels_toggleSignatures.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputChannel.h"
#import "TLUpdates.h"

@implementation TLRPCchannels_toggleSignatures


- (Class)responseClass
{
    return [TLUpdates class];
}

- (int)impliedResponseSignature
{
    return 0;
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

@implementation TLRPCchannels_toggleSignatures$channels_toggleSignatures : TLRPCchannels_toggleSignatures


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x418d549c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x10df3b5a;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCchannels_toggleSignatures$channels_toggleSignatures *object = [[TLRPCchannels_toggleSignatures$channels_toggleSignatures alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.channel = metaObject->getObject((int32_t)0xe11f3d41);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.flags;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x81915c23, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.channel;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe11f3d41, value));
    }
}


@end

