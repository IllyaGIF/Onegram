#import "TLRPCmessages_getSavedDialogs.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"
#import "TLmessages_SavedDialogs.h"

@implementation TLRPCmessages_getSavedDialogs


- (Class)responseClass
{
    return [TLmessages_SavedDialogs class];
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

@implementation TLRPCmessages_getSavedDialogs$messages_getSavedDialogs : TLRPCmessages_getSavedDialogs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x1e91fc99;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x49f8b434;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_getSavedDialogs$messages_getSavedDialogs *object = [[TLRPCmessages_getSavedDialogs$messages_getSavedDialogs alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.parent_peer = metaObject->getObject((int32_t)0x6b8ffdf3);
    object.offset_date = metaObject->getInt32((int32_t)0xe37adfc2);
    object.offset_id = metaObject->getInt32((int32_t)0x1120a8cd);
    object.offset_peer = metaObject->getObject((int32_t)0xfcfce48f);
    object.limit = metaObject->getInt32((int32_t)0xb8433fca);
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
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.parent_peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x6b8ffdf3, value));
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
        value.primitive.int32Value = self.offset_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1120a8cd, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.offset_peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfcfce48f, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.limit;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb8433fca, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xc152e470, value));
    }
}


@end

