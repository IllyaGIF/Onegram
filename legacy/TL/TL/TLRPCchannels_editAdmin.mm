#import "TLRPCchannels_editAdmin.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputChannel.h"
#import "TLInputUser.h"
#import "TLUpdates.h"

@implementation TLRPCchannels_editAdmin


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

@implementation TLRPCchannels_editAdmin$channels_editAdmin : TLRPCchannels_editAdmin


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x9a98ad68;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xcdb8de75;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCchannels_editAdmin$channels_editAdmin *object = [[TLRPCchannels_editAdmin$channels_editAdmin alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.channel = metaObject->getObject((int32_t)0xe11f3d41);
    object.user_id = metaObject->getObject((int32_t)0xafdf4073);
    object.admin_rights = metaObject->getObject((int32_t)0x86c3114f);
    object.rank = metaObject->getString((int32_t)0x89ff708);
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
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.user_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xafdf4073, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.admin_rights;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x86c3114f, value));
    }
    if (self.flags & (1 << 0))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.rank;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x89ff708, value));
    }
}


@end

