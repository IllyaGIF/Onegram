#import "TLRPCmessages_searchGlobal.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputChannel.h"
#import "TLInputPeer.h"
#import "TLMessagesFilter.h"
#import "TLmessages_Messages.h"

@implementation TLRPCmessages_searchGlobal


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

@implementation TLRPCmessages_searchGlobal$messages_searchGlobal : TLRPCmessages_searchGlobal


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x6126a43c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x43461509;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_searchGlobal$messages_searchGlobal *object = [[TLRPCmessages_searchGlobal$messages_searchGlobal alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.folder_id = metaObject->getInt32((int32_t)0xa8f1f444);
    object.community = metaObject->getObject((int32_t)0x5ce8ef8);
    object.q = metaObject->getString((int32_t)0xcd45cb1c);
    object.filter = metaObject->getObject((int32_t)0x834de586);
    object.min_date = metaObject->getInt32((int32_t)0x5d407234);
    object.max_date = metaObject->getInt32((int32_t)0xf4d47b51);
    object.offset_rate = metaObject->getInt32((int32_t)0x3f7b18d9);
    object.offset_peer = metaObject->getObject((int32_t)0xfcfce48f);
    object.offset_id = metaObject->getInt32((int32_t)0x1120a8cd);
    object.limit = metaObject->getInt32((int32_t)0xb8433fca);
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
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.folder_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa8f1f444, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.community;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5ce8ef8, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.q;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xcd45cb1c, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.filter;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x834de586, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.min_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5d407234, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.max_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf4d47b51, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.offset_rate;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x3f7b18d9, value));
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
        value.primitive.int32Value = self.offset_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1120a8cd, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.limit;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb8433fca, value));
    }
}


@end

