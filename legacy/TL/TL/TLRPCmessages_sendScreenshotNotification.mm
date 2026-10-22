#import "TLRPCmessages_sendScreenshotNotification.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"
#import "TLUpdates.h"

@implementation TLRPCmessages_sendScreenshotNotification


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

@implementation TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification : TLRPCmessages_sendScreenshotNotification


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa1405817;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xb97dbb08;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification *object = [[TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification alloc] init];
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.reply_to = metaObject->getObject((int32_t)0x5776d75a);
    object.random_id = metaObject->getInt64((int32_t)0xca5a160a);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9344c37d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.reply_to;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5776d75a, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.random_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xca5a160a, value));
    }
}


@end

