#import "TLRPCmessages_editChatDefaultBannedRights.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputPeer.h"
#import "TLUpdates.h"

@implementation TLRPCmessages_editChatDefaultBannedRights


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

@implementation TLRPCmessages_editChatDefaultBannedRights$messages_editChatDefaultBannedRights : TLRPCmessages_editChatDefaultBannedRights


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa5866b41;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x9f8bb55c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCmessages_editChatDefaultBannedRights$messages_editChatDefaultBannedRights *object = [[TLRPCmessages_editChatDefaultBannedRights$messages_editChatDefaultBannedRights alloc] init];
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.banned_rights = metaObject->getObject((int32_t)0x7ecb6900);
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
        value.nativeObject = self.banned_rights;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7ecb6900, value));
    }
}


@end

