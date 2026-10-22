#import "TLInputReplyTo.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"

@implementation TLInputReplyTo


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

@implementation TLInputReplyTo$inputReplyToMessage : TLInputReplyTo


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x3bd4b7c2;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x93e649c9;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputReplyTo$inputReplyToMessage *object = [[TLInputReplyTo$inputReplyToMessage alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.reply_to_msg_id = metaObject->getInt32((int32_t)0x598ed37b);
    object.top_msg_id = metaObject->getInt32((int32_t)0xa751959);
    object.reply_to_peer_id = metaObject->getObject((int32_t)0x5ab5e24a);
    object.quote_text = metaObject->getString((int32_t)0xe7c4f588);
    object.quote_entities = metaObject->getArray((int32_t)0xa86477bf);
    object.quote_offset = metaObject->getInt32((int32_t)0xac46f1b6);
    object.monoforum_peer_id = metaObject->getObject((int32_t)0x5e0016bb);
    object.todo_item_id = metaObject->getInt32((int32_t)0x407f2ee1);
    object.poll_option = metaObject->getBytes((int32_t)0xe3ea8a4f);
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
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.reply_to_msg_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x598ed37b, value));
    }
    if (self.flags & (1 << 0))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.top_msg_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa751959, value));
    }
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.reply_to_peer_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5ab5e24a, value));
    }
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.quote_text;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe7c4f588, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.quote_entities;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa86477bf, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.quote_offset;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xac46f1b6, value));
    }
    if (self.flags & (1 << 5))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.monoforum_peer_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5e0016bb, value));
    }
    if (self.flags & (1 << 6))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.todo_item_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x407f2ee1, value));
    }
    if (self.flags & (1 << 7))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.poll_option;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe3ea8a4f, value));
    }
}


@end

