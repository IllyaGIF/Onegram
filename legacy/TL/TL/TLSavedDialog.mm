#import "TLSavedDialog.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLPeer.h"
#import "TLDraftMessage.h"

@implementation TLSavedDialog


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

@implementation TLSavedDialog$savedDialog : TLSavedDialog


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xbd87cb6c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x5b23dd46;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLSavedDialog$savedDialog *object = [[TLSavedDialog$savedDialog alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.top_message = metaObject->getInt32((int32_t)0x8cecb775);
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
        value.nativeObject = self.peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9344c37d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.top_message;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8cecb775, value));
    }
}


@end

@implementation TLSavedDialog$monoForumDialog : TLSavedDialog


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x64407ea7;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x8c923255;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLSavedDialog$monoForumDialog *object = [[TLSavedDialog$monoForumDialog alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.top_message = metaObject->getInt32((int32_t)0x8cecb775);
    object.read_inbox_max_id = metaObject->getInt32((int32_t)0xf4c35301);
    object.read_outbox_max_id = metaObject->getInt32((int32_t)0x2317b2ad);
    object.unread_count = metaObject->getInt32((int32_t)0xa6b586be);
    object.unread_reactions_count = metaObject->getInt32((int32_t)0xfe6fec98);
    object.draft = metaObject->getObject((int32_t)0x67a43482);
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
        value.nativeObject = self.peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9344c37d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.top_message;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8cecb775, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.read_inbox_max_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf4c35301, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.read_outbox_max_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x2317b2ad, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.unread_count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa6b586be, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.unread_reactions_count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfe6fec98, value));
    }
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.draft;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x67a43482, value));
    }
}


@end
