#import "TLRPCmessages_sendMultiMedia.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"
#import "TLRPCmessages_sendMessage_manual.h"

@implementation TLRPCmessages_sendMultiMedia

- (int32_t)TLconstructorSignature
{
    return (TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil) ? (int32_t)0x1bf89d74 : (int32_t)0x2095512f;
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
    return (TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil) ? 225 : 73;
}

- (void)TLserialize:(NSOutputStream *)os
{
    int32_t flags = TGMessageSendFlags(_flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil);
    if (_sendAs != nil)
        flags |= (1 << 13);
    [os writeInt32:flags];
    
    TLMetaClassStore::serializeObject(os, _peer, true);
    
    TGSerializeMessageReply(os, flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil);
    
    int32_t vectorSignature = TL_UNIVERSAL_VECTOR_CONSTRUCTOR;
    [os writeInt32:vectorSignature];
    
    [os writeInt32:(int32_t)self.multi_media.count];
    for (TLInputSingleMedia *media in self.multi_media) {
        TLMetaClassStore::serializeObject(os, media, true);
    }
    if (_sendAs != nil)
        TLMetaClassStore::serializeObject(os, _sendAs, true);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCmessages_sendMultiMedia deserialization not supported");
    return nil;
}

@end
