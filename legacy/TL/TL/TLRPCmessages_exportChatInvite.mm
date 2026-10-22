#import "TLRPCmessages_exportChatInvite.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLExportedChatInvite.h"
#import "TLInputPeer.h"

@implementation TLRPCmessages_exportChatInvite


- (Class)responseClass
{
    return [TLExportedChatInvite class];
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

@implementation TLRPCmessages_exportChatInvite$messages_exportChatInvite : TLRPCmessages_exportChatInvite


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa455de90;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x3fe1647c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_exportChatInvite$messages_exportChatInvite *object = [[TLRPCmessages_exportChatInvite$messages_exportChatInvite alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.expire_date = metaObject->getInt32((int32_t)0x65ecd48a);
    object.usage_limit = metaObject->getInt32((int32_t)0x2e51f385);
    object.title = metaObject->getString((int32_t)0xcdebf414);
    object.subscription_pricing = metaObject->getObject((int32_t)0xc16e75b1);
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
    if (self.flags & (1 << 0))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.expire_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x65ecd48a, value));
    }
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.usage_limit;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x2e51f385, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.title;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xcdebf414, value));
    }
    if (self.flags & (1 << 5))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.subscription_pricing;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xc16e75b1, value));
    }
}


@end

