#import "TLRPCmessages_getSavedHistory.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"
#import "TLmessages_Messages.h"

@implementation TLRPCmessages_getSavedHistory


- (Class)responseClass
{
    return [TLmessages_Messages class];
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

@implementation TLRPCmessages_getSavedHistory$messages_getSavedHistory : TLRPCmessages_getSavedHistory


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x998ab009;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xe57d147e;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_getSavedHistory$messages_getSavedHistory *object = [[TLRPCmessages_getSavedHistory$messages_getSavedHistory alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.parent_peer = metaObject->getObject((int32_t)0x6b8ffdf3);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.offset_id = metaObject->getInt32((int32_t)0x1120a8cd);
    object.offset_date = metaObject->getInt32((int32_t)0xe37adfc2);
    object.add_offset = metaObject->getInt32((int32_t)0xb3d4dff0);
    object.limit = metaObject->getInt32((int32_t)0xb8433fca);
    object.max_id = metaObject->getInt32((int32_t)0xe2c00ace);
    object.min_id = metaObject->getInt32((int32_t)0x52b518c0);
    object.n_hash = metaObject->getInt64((int32_t)0xc152e470);
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
    if (self.flags & (1 << 0))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.parent_peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x6b8ffdf3, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9344c37d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.offset_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1120a8cd, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.offset_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe37adfc2, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.add_offset;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb3d4dff0, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.limit;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb8433fca, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.max_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe2c00ace, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.min_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x52b518c0, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xc152e470, value));
    }
}


@end

