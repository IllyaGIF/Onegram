#import "TLRPCmessages_editChatAbout.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"

@implementation TLRPCmessages_editChatAbout


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

@implementation TLRPCmessages_editChatAbout$messages_editChatAbout : TLRPCmessages_editChatAbout


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xdef60797;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xa79b4c68;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_editChatAbout$messages_editChatAbout *object = [[TLRPCmessages_editChatAbout$messages_editChatAbout alloc] init];
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.about = metaObject->getString((int32_t)0xdf4f0b19);
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
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.about;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdf4f0b19, value));
    }
}


@end

