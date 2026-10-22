#import "TLRPCmessages_sendMessage_manual.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"

int32_t TGMessageSendFlags(int32_t flags, int32_t replyMessageId, int32_t topicId)
{
    if (topicId == 0)
        return flags;
    flags &= ~((1 << 4) | (1 << 0));
    if (replyMessageId != 0 || topicId > 1)
        flags |= (1 << 0);
    return flags;
}

void TGSerializeMessageReply(NSOutputStream *stream, int32_t flags, int32_t replyMessageId, int32_t topicId)
{
    if ((flags & (1 << 0)) == 0)
        return;
    if (topicId == 0)
    {
        [stream writeInt32:replyMessageId];
        return;
    }
    int32_t replyId = replyMessageId != 0 ? replyMessageId : topicId;
    bool includeTopId = topicId > 1 && replyId != topicId;
    [stream writeInt32:(int32_t)0x3bd4b7c2];
    [stream writeInt32:includeTopId ? (1 << 0) : 0];
    [stream writeInt32:replyId];
    if (includeTopId)
        [stream writeInt32:topicId];
}

@implementation TLRPCmessages_sendMessage_manual

- (int32_t)TLconstructorSignature
{
    return _forumTopicId != 0 ? (int32_t)0x545cd15a : (int32_t)0xFA88427A;
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
    
    [os writeString:_message];
    [os writeInt64:_random_id];
    
    if (_flags & (1 << 3)) {
        int32_t vectorSignature = TL_UNIVERSAL_VECTOR_CONSTRUCTOR;
        [os writeInt32:vectorSignature];
        
        [os writeInt32:(int32_t)_entities.count];
        for (TLMessageEntity *entity in _entities) {
            TLMetaClassStore::serializeObject(os, entity, true);
        }
    }
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCmessages_sendMessage_manual deserialization not supported");
    return nil;
}

@end

@implementation TLRPCmessages_sendReaction_manual

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xd30d78d4;
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
    return 26;
}

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
        [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
        [os writeInt32:1];
        if ([_reaction hasPrefix:@"◆"] && _reaction.length > 1)
        {
            [os writeInt32:(int32_t)0x8935fc73];
            [os writeInt64:[[_reaction substringFromIndex:1] longLongValue]];
        }
        else
        {
            [os writeInt32:(int32_t)0x1b2286b8];
            [os writeString:_reaction];
        }
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

- (int32_t)TLconstructorSignature { return (int32_t)0x18dea0ac; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLmessages_AvailableReactions_manual class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 26; }

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:_hashValue];
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
    [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
    [os writeInt32:0];
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
    [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
    [os writeInt32:(int32_t)poll.answers.count];
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
        [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
        [os writeInt32:(int32_t)poll.countries.count];
        for (NSString *country in poll.countries)
            [os writeString:country];
    }
    [os writeInt64:poll.pollHash];
}

@implementation TLRPCmessages_sendVote_manual

- (int32_t)TLconstructorSignature { return (int32_t)0x10ea6184; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLUpdates class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 26; }

- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, _peer, true);
    [os writeInt32:_msg_id];
    [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
    [os writeInt32:(int32_t)_options.count];
    for (NSData *option in _options)
        [os writeBytes:option];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end

@implementation TLRPCmessages_getPollResults_manual

- (int32_t)TLconstructorSignature { return (int32_t)0xeda3e33b; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLUpdates class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 26; }

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

- (int32_t)TLconstructorSignature { return (int32_t)0xb106e66c; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLUpdates class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 26; }

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
    {
        [os writeInt32:TL_UNIVERSAL_VECTOR_CONSTRUCTOR];
        [os writeInt32:(int32_t)_correct_answers.count];
        for (NSNumber *index in _correct_answers)
            [os writeInt32:[index intValue]];
    }
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return nil;
}

@end
