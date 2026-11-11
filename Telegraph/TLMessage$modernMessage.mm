#import "TLMessage$modernMessage.h"

#import "TLMetaClassStore.h"
#import "TLPeer.h"
#import "OGFeatureProbe.h"
#import "TLUser$modernUser.h"
#import "TGRichMessageTLParser.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"

static const int32_t OGModernVectorSignature = (int32_t)0x1cb5c415;

static inline bool OGModernFailed(__autoreleasing NSError **error)
{
    return error != nil && *error != nil;
}

static inline bool OGModernIsFlagsWord(int32_t word)
{
    return word > 0 && word < 0x10000;
}

static inline id<TLObject> OGModernConstructQuiet(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return TLMetaClassStore::constructObject(is, signature, environment, nil, error);
}

static inline void OGModernDiscardInt32(NSInputStream *is)
{
    (void)[is readInt32];
}

static inline void OGModernDiscardInt64(NSInputStream *is)
{
    (void)[is readInt64];
}

static inline void OGModernDiscardString(NSInputStream *is)
{
    (void)[is readString];
}

static inline void OGModernDiscardBytes(NSInputStream *is)
{
    (void)[is readBytes];
}

static id<TLObject> OGModernConstructLogged(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    id<TLObject> object = OGModernConstructQuiet(is, signature, environment, error);
    if (OGModernFailed(error))
        TGLog(@"MSG readObject failed signature=0x%08x error=%@", signature, *error);
    return object;
}

static id<TLObject> OGModernReadBoxed(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    return OGModernConstructLogged(is, signature, environment, error);
}

static bool OGModernOpenVector(NSInputStream *is, NSString *fixedFailureText, int32_t *count, __autoreleasing NSError **error)
{
    int32_t marker = [is readInt32];
    if (marker != OGModernVectorSignature)
    {
        if (error != nil)
        {
            NSString *text = fixedFailureText ?: [[NSString alloc] initWithFormat:@"Expected vector, got 0x%08x", marker];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: text}];
        }
        return false;
    }
    *count = [is readInt32];
    return true;
}

static NSArray *OGModernReadBoxedVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t count = 0;
    if (!OGModernOpenVector(is, nil, &count, error))
        return nil;
    
    NSMutableArray *collected = [NSMutableArray arrayWithCapacity:0];
    for (int32_t index = 0; index < count; index++)
    {
        id element = OGModernReadBoxed(is, environment, error);
        if (OGModernFailed(error))
            return nil;
        if (element == nil)
            continue;
        [collected addObject:element];
    }
    return collected;
}

static NSString *OGModernReactionLabel(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t kind = [is readInt32];
    switch ((uint32_t)kind)
    {
        case 0x1b2286b8:
            return [is readString];
        case 0x8935fc73:
            return [NSString stringWithFormat:@"◆%lld", [is readInt64]];
        case 0x523da4eb:
            return @"★";
        case 0x79f5d419:
            return nil;
        default:
            OGModernConstructQuiet(is, kind, environment, error);
            return nil;
    }
}

static NSString *OGModernReadReactionSummary(NSInputStream *is, id<TLSerializationEnvironment> environment, NSString **chosenReaction, __autoreleasing NSError **error)
{
    NSString *selected = nil;
    if (chosenReaction != NULL)
        *chosenReaction = selected;
    int32_t signature = [is readInt32];
    const bool isShortForm = signature == (int32_t)0x4f2b9479;
    if (signature != (int32_t)0x0a339f0b && !isShortForm)
    {
        OGModernConstructQuiet(is, signature, environment, error);
        return nil;
    }

    int32_t flags = [is readInt32];
    int32_t count = 0;
    if (!OGModernOpenVector(is, @"Invalid reaction results vector", &count, error))
        return nil;

    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:0];
    for (int32_t index = 0; index < count; index++)
    {
        int32_t entrySignature = [is readInt32];
        if (entrySignature != (int32_t)0xa3d1cb80)
        {
            OGModernConstructQuiet(is, entrySignature, environment, error);
            if (OGModernFailed(error))
                return nil;
            continue;
        }

        const bool chosen = ([is readInt32] & 1) != 0;
        if (chosen)
            OGModernDiscardInt32(is);

        NSString *reaction = OGModernReactionLabel(is, environment, error);
        const int32_t reactionCount = [is readInt32];
        const bool labelled = reaction.length != 0;
        if (labelled && chosen && chosenReaction != NULL)
            *chosenReaction = reaction;
        if (labelled && reactionCount > 0)
            [parts addObject:[NSString stringWithFormat:@"%@ %d", reaction, reactionCount]];
    }

    if (flags & (1 << 1))
        OGModernReadBoxedVector(is, environment, error);
    if (!isShortForm && (flags & (1 << 4)))
        OGModernReadBoxedVector(is, environment, error);

    if (parts.count == 0)
        return nil;
    return [parts componentsJoinedByString:@"  "];
}

static void OGModernSkipFactCheck(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t word = [is readInt32];
    if (!OGModernIsFlagsWord(word))
    {
        OGModernConstructLogged(is, word, environment, error);
        return;
    }
    
    if (word & (1 << 1))
    {
        OGModernDiscardString(is);
        OGModernReadBoxed(is, environment, error);
    }
    OGModernDiscardInt64(is);
}

static void OGModernSkipSuggestedPost(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t word = [is readInt32];
    if (!OGModernIsFlagsWord(word))
    {
        OGModernConstructLogged(is, word, environment, error);
        return;
    }
    
    if (word & (1 << 3))
        OGModernReadBoxed(is, environment, error);
    if (OGModernFailed(error))
        return;
    if (word & (1 << 0))
        OGModernDiscardInt32(is);
}

static TLPeer *OGModernReadPeer(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);
static int64_t OGModernPeerKey(TLPeer *peer);

static NSArray *OGModernReadPeerKeys(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t count = 0;
    if (!OGModernOpenVector(is, nil, &count, error))
        return nil;

    NSMutableArray *peerKeys = [[NSMutableArray alloc] init];
    for (int32_t index = 0; index < count; index++)
    {
        TLPeer *peer = OGModernReadPeer(is, environment, error);
        if (OGModernFailed(error))
            return nil;
        int64_t key = OGModernPeerKey(peer);
        if (key != 0)
            [peerKeys addObject:@(key)];
    }
    return peerKeys;
}

static NSDictionary *OGModernReadReplies(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t word = [is readInt32];
    int32_t flags = 0;

    if (word == (int32_t)0x83d60fc2)
        flags = [is readInt32];
    else if (word >= 0 && word < 0x10000)
        flags = word;
    else
    {
        OGModernConstructLogged(is, word, environment, error);
        return nil;
    }

    int32_t replies = [is readInt32];
    OGModernDiscardInt32(is);

    NSArray *recentRepliers = @[];
    if (flags & (1 << 1))
    {
        recentRepliers = OGModernReadPeerKeys(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }

    int64_t channelId = (flags & (1 << 0)) ? [is readInt64] : 0;
    int32_t maxId = (flags & (1 << 2)) ? [is readInt32] : 0;
    int32_t readMaxId = (flags & (1 << 3)) ? [is readInt32] : 0;

    return @{
        @"comments": @((flags & (1 << 0)) != 0),
        @"replies": @(replies),
        @"channelId": @(channelId),
        @"maxId": @(maxId),
        @"readMaxId": @(readMaxId),
        @"recentRepliers": recentRepliers ?: @[]
    };
}

static int64_t OGModernPeerKey(TLPeer *peer)
{
    int64_t key = 0;
    if ([peer isKindOfClass:[TLPeer$peerChannel class]])
        key = TGPeerIdFromChannelId(((TLPeer$peerChannel *)peer).channel_id);
    else if ([peer isKindOfClass:[TLPeer$peerChat class]])
        key = TGPeerIdFromGroupId(((TLPeer$peerChat *)peer).chat_id);
    else if ([peer isKindOfClass:[TLPeer$peerUser class]])
        key = ((TLPeer$peerUser *)peer).user_id;
    return key;
}

static TLPeer$peerUser *OGModernUserPeer(int64_t userId)
{
    TLPeer$peerUser *created = [TLPeer$peerUser new];
    created.user_id = userId;
    return created;
}

static TLPeer$peerChannel *OGModernChannelPeer(int64_t channelId)
{
    TLPeer$peerChannel *created = [TLPeer$peerChannel new];
    created.channel_id = channelId;
    return created;
}

static TLPeer *OGModernReadPeer(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    switch ((uint32_t)signature)
    {
        case 0x59511722:
        case 0x15752102:
            return OGModernUserPeer([is readInt64]);
        case 0x36c6019a:
        {
            TLPeer$peerChat *chatPeer = [TLPeer$peerChat new];
            chatPeer.chat_id = [is readInt64];
            return chatPeer;
        }
        case 0xa2a5371e:
            return OGModernChannelPeer([is readInt64]);
        case 0x9db1bc6d:
        case 0xbad0e5bb:
        case 0xbddde532:
            return (TLPeer *)OGModernConstructQuiet(is, signature, environment, error);
        default:
            break;
    }
    
    int32_t highWord = [is readInt32];
    int64_t rawPeerId = (((int64_t)highWord) << 32) | ((uint32_t)signature);
    return rawPeerId < 0 ? (TLPeer *)OGModernChannelPeer(-rawPeerId) : (TLPeer *)OGModernUserPeer(rawPeerId);
}

static int32_t OGModernReadReplyHeader(NSInputStream *is, id<TLSerializationEnvironment> environment, int32_t *replyToTopId, bool *forumTopic, int64_t *storyPeerId, int32_t *storyId, __autoreleasing NSError **error)
{
    if (replyToTopId != NULL)
        *replyToTopId = 0;
    if (forumTopic != NULL)
        *forumTopic = false;
    if (storyPeerId != NULL)
        *storyPeerId = 0;
    if (storyId != NULL)
        *storyId = 0;

    int32_t signature = [is readInt32];
    
    switch ((uint32_t)signature)
    {
        case 0xafbc09db:
        case 0x1b97dd66:
        case 0x6917560b:
        case 0xddb5ab75:
        {
            const bool hasQuoteOffset = signature != (int32_t)0xafbc09db;
            const bool hasQuoteBytes = signature == (int32_t)0x1b97dd66 || signature == (int32_t)0xddb5ab75;
            int32_t flags = [is readInt32];
            if (forumTopic != NULL)
                *forumTopic = (flags & (1 << 3)) != 0;
            int32_t replyToMessageId = (flags & (1 << 4)) ? [is readInt32] : 0;
            if (flags & (1 << 0))
                OGModernReadBoxed(is, environment, error);
            if (flags & (1 << 5))
                OGModernReadBoxed(is, environment, error);
            if (flags & (1 << 8))
                OGModernReadBoxed(is, environment, error);
            if (flags & (1 << 1))
            {
                int32_t topMessageId = [is readInt32];
                if (replyToTopId != NULL)
                    *replyToTopId = topMessageId;
            }
            if (flags & (1 << 6))
                OGModernDiscardString(is);
            if (flags & (1 << 7))
                OGModernReadBoxedVector(is, environment, error);
            if (flags & (1 << 10))
                OGModernDiscardInt32(is);
            if (hasQuoteOffset && (flags & (1 << 11)))
                OGModernDiscardInt32(is);
            if (hasQuoteBytes && (flags & (1 << 12)))
                OGModernDiscardBytes(is);
            if (signature == (int32_t)0xddb5ab75 && (flags & (1 << 14)))
                OGModernReadBoxedVector(is, environment, error);
            return replyToMessageId;
        }
        case 0x0e5af939:
        {
            TLPeer *peer = OGModernReadPeer(is, environment, error);
            int32_t replyStoryId = [is readInt32];
            if (storyPeerId != NULL)
                *storyPeerId = OGModernPeerKey(peer);
            if (storyId != NULL)
                *storyId = replyStoryId;
            return 0;
        }
        default:
            break;
    }
    
    if (signature <= 0 || signature >= 10000000)
    {
        OGModernConstructQuiet(is, signature, environment, error);
        return 0;
    }
    return signature;
}

static bool OGModernMessageHasSecondFlags(int32_t signature)
{
    static const uint32_t knownSignatures[] = {
        0x94345242, 0x96fdbbe9, 0x7600b9d3, 0x95ef6f2b, 0x6a26cb37, 0xd0bbd081, 0x003e38e7, 0xd9a7d88a,
        0xd18fd1bb, 0xff86154d, 0xbb294f27, 0x65fdf943, 0x6a4ced37, 0x6236ae4a, 0xd8a8d820, 0x9815cec8
    };
    for (size_t index = 0; index < sizeof(knownSignatures) / sizeof(knownSignatures[0]); index++)
    {
        if ((int32_t)knownSignatures[index] == signature)
            return true;
    }
    return false;
}

@implementation TLMessage$modernMessage

+ (NSDictionary *)readMessageRepliesFromStream:(NSInputStream *)is error:(__autoreleasing NSError **)error
{
    return OGModernReadReplies(is, nil, error);
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLMessage$modernMessage serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLMessage$modernMessage *result = [[TLMessage$modernMessage alloc] init];
    
    int32_t flags = [is readInt32];
    const bool modern = OGModernMessageHasSecondFlags(signature);
    const bool extended = modern && signature != (int32_t)0x94345242;
    int32_t flags2 = modern ? [is readInt32] : 0;
    
    result.flags = flags;
    result.n_id = [is readInt32];
    
    if (flags & (1 << 8))
    {
        if (modern)
        {
            TLPeer *fromPeer = OGModernReadPeer(is, environment, error);
            if (OGModernFailed(error))
                return nil;
            result.senderPeerId = OGModernPeerKey(fromPeer);
            result.from_id = TGPeerIdIsUser(result.senderPeerId) ? result.senderPeerId : 0;
        }
        else
            result.from_id = [is readInt32];
    }
    
    if (modern && (flags & (1 << 29)))
        OGModernDiscardInt32(is);
    
    if (extended && (flags2 & (1 << 12)))
        OGModernDiscardString(is);
    
    result.to_id = OGModernReadPeer(is, environment, error);
    if (OGModernFailed(error))
        return nil;
    
    if (modern && (flags & (1 << 28)))
    {
        TLPeer *savedPeer = OGModernReadPeer(is, environment, error);
        if (OGModernFailed(error))
            return nil;
        result.saved_peer_id = OGModernPeerKey(savedPeer);
    }
    
    if (flags & (1 << 2))
    {
        result.fwd_from = (TLMessageFwdHeader *)OGModernReadBoxed(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (flags & (1 << 11))
        result.via_bot_id = modern ? [is readInt64] : [is readInt32];
    
    if (modern && (flags2 & (1 << 0)))
        OGModernDiscardInt64(is);
    
    if (extended && (flags2 & (1 << 19)))
    {
        OGModernReadBoxed(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (flags & (1 << 3))
    {
        if (modern)
        {
            int32_t topId = 0;
            bool forum = false;
            int64_t storyPeer = 0;
            int32_t storyId = 0;
            result.reply_to_msg_id = OGModernReadReplyHeader(is, environment, &topId, &forum, &storyPeer, &storyId, error);
            result.reply_to_top_id = topId;
            result.forum_topic = forum;
            result.reply_to_story_peer_id = storyPeer;
            result.reply_to_story_id = storyId;
        }
        else
            result.reply_to_msg_id = [is readInt32];
        if (OGModernFailed(error))
            return nil;
    }
    
    result.date = [is readInt32];
    result.message = [is readString];
    
    if (flags & (1 << 9))
    {
        int32_t mediaSignature = [is readInt32];
        result.media = TLMetaClassStore::constructObject(is, mediaSignature, environment, nil, error);
        if (OGModernFailed(error))
        {
            TGLog(@"MSG id=%d media failed signature=0x%08x error=%@", result.n_id, mediaSignature, *error);
            return nil;
        }
    }
    
    if (flags & (1 << 6))
    {
        int32_t markupSignature = [is readInt32];
        result.reply_markup = TLMetaClassStore::constructObject(is, markupSignature, environment, nil, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (flags & (1 << 7))
    {
        result.entities = OGModernReadBoxedVector(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (flags & (1 << 10))
    {
        result.views = [is readInt32];
        if (modern)
            OGModernDiscardInt32(is);
    }
    
    if (modern && (flags & (1 << 23)))
    {
        NSDictionary *discussion = OGModernReadReplies(is, environment, error);
        if (OGModernFailed(error))
            return nil;
        if ([discussion isKindOfClass:[NSDictionary class]])
        {
            result.discussion_comments = [discussion[@"comments"] boolValue];
            result.discussion_replies = [discussion[@"replies"] intValue];
            result.discussion_channel_id = [discussion[@"channelId"] longLongValue];
            result.discussion_max_id = [discussion[@"maxId"] intValue];
            result.discussion_read_max_id = [discussion[@"readMaxId"] intValue];
            result.discussion_recent_repliers = discussion[@"recentRepliers"];
        }
    }
    
    if (flags & (1 << 15))
        result.edit_date = [is readInt32];
    
    if (flags & (1 << 16))
        result.post_author = [is readString];
    
    if (flags & (1 << 17))
        result.grouped_id = [is readInt64];
    
    if (modern && (flags & (1 << 20)))
    {
        NSString *chosenReaction = nil;
        result.reactionSummary = OGModernReadReactionSummary(is, environment, &chosenReaction, error);
        result.chosenReaction = chosenReaction;
        if (OGModernFailed(error))
            return nil;
    }
    
    if (modern && (flags & (1 << 22)))
    {
        OGModernReadBoxedVector(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (modern && (flags & (1 << 25)))
        OGModernDiscardInt32(is);
    
    if (modern && (flags & (1 << 30)))
        OGModernDiscardInt32(is);
    
    if (modern && (flags2 & (1 << 2)))
        OGModernDiscardInt64(is);
    
    if (modern && (flags2 & (1 << 3)))
    {
        OGModernSkipFactCheck(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (extended && (flags2 & (1 << 5)))
        OGModernDiscardInt32(is);
    
    if (extended && (flags2 & (1 << 6)))
        OGModernDiscardInt64(is);
    
    if (extended && (flags2 & (1 << 7)))
    {
        OGModernSkipSuggestedPost(is, environment, error);
        if (OGModernFailed(error))
            return nil;
    }
    
    if (extended && (flags2 & (1 << 10)))
        OGModernDiscardInt32(is);
    
    if (extended && (flags2 & (1 << 11)))
        OGModernDiscardString(is);
    
    if (extended && (flags2 & (1 << 13)))
    {
        NSArray *richMessagePhotos = nil;
        NSArray *richMessageDocuments = nil;
        NSError *richMessageError = nil;
        result.richMessage = TGRichMessageReadTL(is, environment, &richMessagePhotos, &richMessageDocuments, &richMessageError);
        if (richMessageError != nil)
        {
            TGLog(@"MSG id=%d richMessage failed error=%@", result.n_id, richMessageError);
            if (error != nil)
                *error = richMessageError;
            return nil;
        }
        result.richMessagePhotos = richMessagePhotos;
        result.richMessageDocuments = richMessageDocuments;
    }
    
    return result;
}

@end
