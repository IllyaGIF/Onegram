#import "TLRPCmessages_sendMessage_manual.h"

#import "TL/TLMetaScheme.h"
#import "TL/TLBool.h"
#import "TLMetaClassStore.h"

#define OG_COMPAT_MANUAL_RPC(signatureValue, responseClassName, layerValue) \
- (int32_t)TLconstructorSignature { return (int32_t)signatureValue; } \
- (int32_t)TLconstructorName { return -1; } \
- (Class)responseClass { return [responseClassName class]; } \
- (int)layerVersion { return layerValue; }

static void OGCompatWriteVectorHeader(NSOutputStream *os, NSUInteger count)
{
    [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
    [os writeInt32:(int32_t)count];
}

static void OGCompatWriteReaction(NSOutputStream *os, NSString *reaction)
{
    if ([reaction hasPrefix:@"◆"] && reaction.length > 1)
    {
        [os writeInt32:(int32_t)0x8935fc73];
        [os writeInt64:[[reaction substringFromIndex:1] longLongValue]];
    }
    else
    {
        [os writeInt32:(int32_t)0x1b2286b8];
        [os writeString:reaction];
    }
}

static void OGCompatWriteInt32Vector(NSOutputStream *os, NSArray *indexes)
{
    OGCompatWriteVectorHeader(os, indexes.count);
    for (NSNumber *index in indexes)
        [os writeInt32:[index intValue]];
}

bool TGMessageSendUsesReplyTo(int32_t topicId, TLInputPeer *monoforumPeer)
{
    return topicId != 0 || monoforumPeer != nil;
}

int32_t TGMessageSendFlags(int32_t flags, int32_t replyMessageId, int32_t topicId, TLInputPeer *monoforumPeer, bool modernReply)
{
    if (!modernReply)
        return flags;
    flags &= ~((1 << 4) | (1 << 0));
    if (replyMessageId != 0 || topicId > 1 || monoforumPeer != nil)
        flags |= (1 << 0);
    return flags;
}

void TGSerializeMessageReply(NSOutputStream *stream, int32_t flags, int32_t replyMessageId, int32_t topicId, TLInputPeer *monoforumPeer, bool modernReply)
{
    if ((flags & (1 << 0)) == 0)
        return;
    if (monoforumPeer != nil)
    {
        if (replyMessageId != 0)
        {
            [stream writeInt32:(int32_t)0x75c1ad70];
            [stream writeInt32:(1 << 5)];
            [stream writeInt32:replyMessageId];
        }
        else
            [stream writeInt32:(int32_t)0x69d66c45];
        TLMetaClassStore::serializeObject(stream, monoforumPeer, true);
        return;
    }
    if (!modernReply)
    {
        [stream writeInt32:replyMessageId];
        return;
    }
    int32_t replyId = replyMessageId != 0 ? replyMessageId : topicId;
    bool includeTopId = topicId > 1 && replyId != topicId;
    [stream writeInt32:(int32_t)0x75c1ad70];
    [stream writeInt32:includeTopId ? (1 << 0) : 0];
    [stream writeInt32:replyId];
    if (includeTopId)
        [stream writeInt32:topicId];
}

@implementation TGIOS6ForwardMessagesToThreadRpc

OG_COMPAT_MANUAL_RPC(0x13704a7c, TLUpdates, 225)

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:self.flags | (self.sendAs != nil ? (1 << 13) : 0) | (self.allowPaidStars > 0 ? (1 << 21) : 0)];
    TLMetaClassStore::serializeObject(os, self.fromPeer, true);

    OGCompatWriteInt32Vector(os, self.messageIds);

    OGCompatWriteVectorHeader(os, self.randomIds.count);
    for (NSNumber *randomId in self.randomIds)
        [os writeInt64:[randomId longLongValue]];

    TLMetaClassStore::serializeObject(os, self.toPeer, true);
    if ((self.flags & (1 << 9)) != 0)
        [os writeInt32:self.topMessageId];
    if ((self.flags & (1 << 22)) != 0)
    {
        [os writeInt32:(int32_t)0x69d66c45];
        TLMetaClassStore::serializeObject(os, self.monoforumPeer, true);
    }
    if (self.sendAs != nil)
        TLMetaClassStore::serializeObject(os, self.sendAs, true);
    if (self.allowPaidStars > 0)
        [os writeInt64:self.allowPaidStars];
}

@end

@implementation TLRPCmessages_sendMessage_manual

- (bool)usesModernLayout
{
    return TGMessageSendUsesReplyTo(_forumTopicId, _monoforumPeer) || _sendAs != nil || _replyToStoryPeer != nil || _allowPaidStars > 0;
}

- (int32_t)TLconstructorSignature
{
    if (_allowPaidStars > 0)
        return (int32_t)0xfef48f62;
    return [self usesModernLayout] ? (int32_t)0x545cd15a : (int32_t)0xFA88427A;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (Class)responseClass
{
    return [TLUpdates class];
}

- (int)layerVersion
{
    return [self usesModernLayout] ? 225 : 26;
}

- (void)TLserialize:(NSOutputStream *)os
{
    bool modernLayout = [self usesModernLayout];
    int32_t flags = TGMessageSendFlags(_flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, modernLayout);
    if (_replyToStoryPeer != nil)
        flags |= (1 << 0);
    if (_sendAs != nil)
        flags |= (1 << 13);
    if (_allowPaidStars > 0)
        flags |= (1 << 21);
    [os writeInt32:flags];
    
    TLMetaClassStore::serializeObject(os, _peer, true);
    
    if (_replyToStoryPeer != nil)
    {
        [os writeInt32:(int32_t)0x5881323a];
        TLMetaClassStore::serializeObject(os, _replyToStoryPeer, true);
        [os writeInt32:_replyToStoryId];
    }
    else
        TGSerializeMessageReply(os, flags, _reply_to_msg_id, _forumTopicId, _monoforumPeer, modernLayout);
    
    [os writeString:_message];
    [os writeInt64:_random_id];
    
    if (_flags & (1 << 3))
    {
        OGCompatWriteVectorHeader(os, _entities.count);
        for (TLMessageEntity *entity in _entities)
            TLMetaClassStore::serializeObject(os, entity, true);
    }
    if (_sendAs != nil)
        TLMetaClassStore::serializeObject(os, _sendAs, true);
    if (_allowPaidStars > 0)
        [os writeInt64:_allowPaidStars];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCmessages_sendMessage_manual deserialization not supported");
    return nil;
}

@end

@implementation TLRPCmessages_sendReaction_manual

OG_COMPAT_MANUAL_RPC(0xd30d78d4, TLUpdates, 26)

- (void)TLserialize:(NSOutputStream *)os
{
    int32_t flags = _flags;
    if (_reaction.length != 0)
        flags |= (1 << 0);

    [os writeInt32:flags];
    TLMetaClassStore::serializeObject(os, _peer, true);
    [os writeInt32:_msg_id];

    if (flags & (1 << 0))
    {
        OGCompatWriteVectorHeader(os, 1);
        OGCompatWriteReaction(os, _reaction);
    }
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLAvailableReaction_manual

- (int32_t)TLconstructorSignature { return (int32_t)0xc077ec01; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }

@end

@implementation TLmessages_AvailableReactions_manual

- (int32_t)TLconstructorSignature { return (int32_t)0x768e3aad; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }

@end

@implementation TLRPCmessages_getAvailableReactions_manual

OG_COMPAT_MANUAL_RPC(0x18dea0ac, TLmessages_AvailableReactions_manual, 26)

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:_hashValue];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLRPCmessages_setDefaultReaction_manual

OG_COMPAT_MANUAL_RPC(0x4f47a016, TLBool, 228)

- (void)TLserialize:(NSOutputStream *)os
{
    OGCompatWriteReaction(os, _reaction);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

static void TLRPCWritePollTextWithEntities(NSOutputStream *os, NSString *text)
{
    [os writeInt32:(int32_t)0x751f3146];
    [os writeString:text ?: @""];
    OGCompatWriteVectorHeader(os, 0);
}

static void TLRPCWritePoll(NSOutputStream *os, TLCodexPollValue *poll)
{
    int32_t flags = poll.flags;
    if (poll.countries.count == 0)
        flags &= ~(1 << 12);
    [os writeInt32:(int32_t)0x966e2dbf];
    [os writeInt64:poll.pollId];
    [os writeInt32:flags];
    TLRPCWritePollTextWithEntities(os, poll.question);
    OGCompatWriteVectorHeader(os, poll.answers.count);
    for (TLCodexPollAnswerValue *answer in poll.answers)
    {
        [os writeInt32:(int32_t)0x4b7d786a];
        [os writeInt32:0];
        TLRPCWritePollTextWithEntities(os, answer.text);
        [os writeBytes:answer.option ?: [NSData data]];
    }
    if (flags & (1 << 4))
        [os writeInt32:poll.closePeriod];
    if (flags & (1 << 5))
        [os writeInt32:poll.closeDate];
    if (flags & (1 << 12))
    {
        OGCompatWriteVectorHeader(os, poll.countries.count);
        for (NSString *country in poll.countries)
            [os writeString:country];
    }
    [os writeInt64:poll.pollHash];
}

@implementation TLRPCmessages_sendVote_manual

OG_COMPAT_MANUAL_RPC(0x10ea6184, TLUpdates, 26)

- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, _peer, true);
    [os writeInt32:_msg_id];
    OGCompatWriteVectorHeader(os, _options.count);
    for (NSData *option in _options)
        [os writeBytes:option];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLRPCmessages_getPollResults_manual

OG_COMPAT_MANUAL_RPC(0xeda3e33b, TLUpdates, 26)

- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, _peer, true);
    [os writeInt32:_msg_id];
    [os writeInt64:_poll_hash];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLRPCmessages_editMessagePoll_manual

OG_COMPAT_MANUAL_RPC(0xb106e66c, TLUpdates, 26)

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:(1 << 14)];
    TLMetaClassStore::serializeObject(os, _peer, true);
    [os writeInt32:_msg_id];
    int32_t mediaFlags = _correct_answers.count != 0 ? (1 << 0) : 0;
    [os writeInt32:(int32_t)0x883a4108];
    [os writeInt32:mediaFlags];
    TLRPCWritePoll(os, _poll);
    if (mediaFlags & (1 << 0))
        OGCompatWriteInt32Vector(os, _correct_answers);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLInputMedia$inputMediaPoll_manual

- (int32_t)TLconstructorSignature { return (int32_t)0x883a4108; }
- (int32_t)TLconstructorName { return -1; }

- (void)TLserialize:(NSOutputStream *)os
{
    int32_t flags = 0;
    if (_correct_answers.count != 0)
        flags |= (1 << 0);
    if (_solution.length != 0)
        flags |= (1 << 1);
    [os writeInt32:flags];
    TLRPCWritePoll(os, _poll);
    if (flags & (1 << 0))
        OGCompatWriteInt32Vector(os, _correct_answers);
    if (flags & (1 << 1))
    {
        [os writeString:_solution];
        OGCompatWriteVectorHeader(os, 0);
    }
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end
