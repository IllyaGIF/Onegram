#import "TLGroupCall.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLPeer.h"

@implementation TLGroupCall


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

@implementation TLGroupCall$groupCall : TLGroupCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xefb2b617;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x53d64a86;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLGroupCall$groupCall *object = [[TLGroupCall$groupCall alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.participants_count = metaObject->getInt32((int32_t)0xeb6aa445);
    object.title = metaObject->getString((int32_t)0xcdebf414);
    object.stream_dc_id = metaObject->getInt32((int32_t)0x16cb9138);
    object.record_start_date = metaObject->getInt32((int32_t)0xcaa29cdc);
    object.schedule_date = metaObject->getInt32((int32_t)0x542b3e4b);
    object.unmuted_video_count = metaObject->getInt32((int32_t)0xb502c3e5);
    object.unmuted_video_limit = metaObject->getInt32((int32_t)0xd3305985);
    object.version = metaObject->getInt32((int32_t)0x4ea810e9);
    object.invite_link = metaObject->getString((int32_t)0xfd46d20a);
    object.send_paid_messages_stars = metaObject->getInt64((int32_t)0xf85263de);
    object.default_send_as = metaObject->getObject((int32_t)0xe3a88ca1);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.participants_count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xeb6aa445, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.title;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xcdebf414, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.stream_dc_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x16cb9138, value));
    }
    if (self.flags & (1 << 5))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.record_start_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xcaa29cdc, value));
    }
    if (self.flags & (1 << 7))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.schedule_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x542b3e4b, value));
    }
    if (self.flags & (1 << 10))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.unmuted_video_count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb502c3e5, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.unmuted_video_limit;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xd3305985, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.version;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x4ea810e9, value));
    }
    if (self.flags & (1 << 16))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.invite_link;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfd46d20a, value));
    }
    if (self.flags & (1 << 20))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.send_paid_messages_stars;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf85263de, value));
    }
    if (self.flags & (1 << 21))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.default_send_as;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe3a88ca1, value));
    }
}


@end

@implementation TLGroupCall$groupCallDiscarded : TLGroupCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x7780bcb4;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x3fb67d10;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLGroupCall$groupCallDiscarded *object = [[TLGroupCall$groupCallDiscarded alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.duration = metaObject->getInt32((int32_t)0xac00f752);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.duration;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xac00f752, value));
    }
}


@end
