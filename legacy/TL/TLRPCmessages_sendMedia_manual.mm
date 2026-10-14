#import "TLRPCmessages_sendMedia_manual.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"
#import "TLRPCmessages_sendMessage_manual.h"


@implementation TLRPCmessages_sendMedia_manual

- (int32_t)TLconstructorSignature
{
    return _forumTopicId != 0 ? (int32_t)0x0330e77f : (int32_t)0xb8d1262b;
}

- (int32_t)TLconstructorName
{
    return -1;
}

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
    return _forumTopicId != 0 ? 225 : 26;
}

- (void)TLserialize:(NSOutputStream *)os
{
    int32_t flags = TGMessageSendFlags(_flags, _reply_to_msg_id, _forumTopicId);
    [os writeInt32:flags];
    
    TLMetaClassStore::serializeObject(os, _peer, true);
    
    TGSerializeMessageReply(os, flags, _reply_to_msg_id, _forumTopicId);
    
    TLMetaClassStore::serializeObject(os, _media, true);
    
    [os writeString:_message];
    [os writeInt64:_random_id];
    
    if (_flags & (1 << 3)) {
        int32_t vectorSignature = TL_UNIVERSAL_VECTOR_CONSTRUCTOR;
        [os writeInt32:vectorSignature];
        [os writeInt32:(int32_t)self.entities.count];
        for (TLMessageEntity *entity in self.entities) {
            TLMetaClassStore::serializeObject(os, entity, true);
        }
    }
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCmessages_sendMedia_manual deserialization not supported");
    return nil;
}

@end
