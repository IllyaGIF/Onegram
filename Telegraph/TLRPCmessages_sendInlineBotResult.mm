#import "TLRPCmessages_sendInlineBotResult.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"
#import "TLRPCmessages_sendMessage_manual.h"


@implementation TLRPCmessages_sendInlineBotResult

- (int32_t)TLconstructorSignature
{
    return (TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil || _allowPaidStars > 0) ? (int32_t)0xc0cf7646 : (int32_t)0xB16E06FE;
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
    return (TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil || _allowPaidStars > 0) ? 225 : 45;
}

- (void)TLserialize:(NSOutputStream *)os
{
    int32_t flags = TGMessageSendFlags(_flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil || _allowPaidStars > 0);
    if (_sendAs != nil)
        flags |= (1 << 13);
    if (_allowPaidStars > 0)
        flags |= (1 << 21);
    [os writeInt32:flags];
    
    TLMetaClassStore::serializeObject(os, _peer, true);
    
    TGSerializeMessageReply(os, flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil || _allowPaidStars > 0);
    
    [os writeInt64:_random_id];
    [os writeInt64:_query_id];
    
    [os writeString:_n_id];
    if (_sendAs != nil)
        TLMetaClassStore::serializeObject(os, _sendAs, true);
    if (_allowPaidStars > 0)
        [os writeInt64:_allowPaidStars];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCmessages_sendContextBotResult deserialization not supported");
    return nil;
}

@end
