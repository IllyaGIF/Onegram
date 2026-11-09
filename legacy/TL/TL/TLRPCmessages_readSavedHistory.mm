#import "TLRPCmessages_readSavedHistory.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"

@implementation TLRPCmessages_readSavedHistory


- (Class)responseClass
{
    return [NSNumber class];
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

@implementation TLRPCmessages_readSavedHistory$messages_readSavedHistory : TLRPCmessages_readSavedHistory


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xba4a3b5b;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xc43cf7aa;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_readSavedHistory$messages_readSavedHistory *object = [[TLRPCmessages_readSavedHistory$messages_readSavedHistory alloc] init];
    object.parent_peer = metaObject->getObject((int32_t)0x6b8ffdf3);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.max_id = metaObject->getInt32((int32_t)0xe2c00ace);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
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
        value.primitive.int32Value = self.max_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xe2c00ace, value));
    }
}


@end

