#import "TLMessageAction$messageActionPhoneCall.h"
#import "TLMessage$modernMessageService.h"
#import "TGTLDynamic.h"

#import "TLMetaClassStore.h"
#import "TLMessageAction.h"
#import "TLPeer.h"
#import "TLUser$modernUser.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"


static inline bool OGServiceFailed(__autoreleasing NSError **error)
{
    return error != nil && *error != nil;
}

static inline id<TLObject> OGServiceConstruct(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return TLMetaClassStore::constructObject(is, signature, environment, nil, error);
}

static inline void OGServiceDiscardInt32(NSInputStream *is)
{
    (void)[is readInt32];
}

static inline void OGServiceDiscardString(NSInputStream *is)
{
    (void)[is readString];
}

static inline void OGServiceDiscardBytes(NSInputStream *is)
{
    (void)[is readBytes];
}

static id<TLObject> OGServiceReadBoxed(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t boxedSignature = [is readInt32];
    return OGServiceConstruct(is, boxedSignature, environment, error);
}

static NSArray *OGServiceReadBoxedVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t marker = [is readInt32];
    if (marker != (int32_t)0x1cb5c415)
    {
        if (error != nil)
        {
            NSString *text = [[NSString alloc] initWithFormat:@"Expected vector, got 0x%08x", marker];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: text}];
        }
        return nil;
    }
    
    NSMutableArray *collected = [NSMutableArray arrayWithCapacity:0];
    for (int32_t remaining = [is readInt32]; remaining > 0; remaining--)
    {
        id element = OGServiceReadBoxed(is, environment, error);
        if (OGServiceFailed(error))
            return nil;
        if (element == nil)
            continue;
        [collected addObject:element];
    }
    return collected;
}

static int64_t OGServicePeerKey(TLPeer *peer)
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

static TLPeer *OGServiceMakePeer(Class peerClass, int64_t identifier)
{
    if (peerClass == [TLPeer$peerUser class])
    {
        TLPeer$peerUser *user = [[TLPeer$peerUser alloc] init];
        user.user_id = identifier;
        return user;
    }
    if (peerClass == [TLPeer$peerChat class])
    {
        TLPeer$peerChat *chat = [[TLPeer$peerChat alloc] init];
        chat.chat_id = identifier;
        return chat;
    }
    TLPeer$peerChannel *channel = [[TLPeer$peerChannel alloc] init];
    channel.channel_id = identifier;
    return channel;
}

static TLPeer *OGServiceReadPeer(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    switch ((uint32_t)signature)
    {
        case 0x59511722:
        case 0x15752102:
            return OGServiceMakePeer([TLPeer$peerUser class], [is readInt64]);
        case 0x36c6019a:
            return OGServiceMakePeer([TLPeer$peerChat class], [is readInt64]);
        case 0xa2a5371e:
            return OGServiceMakePeer([TLPeer$peerChannel class], [is readInt64]);
        case 0x9db1bc6d:
        case 0xbad0e5bb:
        case 0xbddde532:
            return (TLPeer *)OGServiceConstruct(is, signature, environment, error);
        default:
            break;
    }
    
    int32_t highWord = [is readInt32];
    int64_t rawPeerId = (((int64_t)highWord) << 32) | ((uint32_t)signature);
    Class peerClass = rawPeerId < 0 ? [TLPeer$peerChannel class] : [TLPeer$peerUser class];
    return OGServiceMakePeer(peerClass, rawPeerId < 0 ? -rawPeerId : rawPeerId);
}

static int32_t OGServiceReadReplyHeader(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    switch ((uint32_t)signature)
    {
        case 0xafbc09db:
        case 0x1b97dd66:
        case 0xddb5ab75:
        {
            const bool hasQuoteFields = signature != (int32_t)0xafbc09db;
            int32_t flags = [is readInt32];
            int32_t replyToMessageId = (flags & (1 << 4)) ? [is readInt32] : 0;
            if (flags & (1 << 0))
                OGServiceReadBoxed(is, environment, error);
            if (flags & (1 << 5))
                OGServiceReadBoxed(is, environment, error);
            if (flags & (1 << 8))
                OGServiceReadBoxed(is, environment, error);
            if (flags & (1 << 1))
                OGServiceDiscardInt32(is);
            if (flags & (1 << 6))
                OGServiceDiscardString(is);
            if (flags & (1 << 7))
                OGServiceReadBoxedVector(is, environment, error);
            if (flags & (1 << 10))
                OGServiceDiscardInt32(is);
            if (hasQuoteFields && (flags & (1 << 11)))
                OGServiceDiscardInt32(is);
            if (hasQuoteFields && (flags & (1 << 12)))
                OGServiceDiscardBytes(is);
            if (signature == (int32_t)0xddb5ab75 && (flags & (1 << 14)))
                OGServiceReadBoxedVector(is, environment, error);
            return replyToMessageId;
        }
        case 0x0e5af939:
            OGServiceReadBoxed(is, environment, error);
            OGServiceDiscardInt32(is);
            return 0;
        default:
            break;
    }
    
    if (signature <= 0 || signature >= 10000000)
    {
        OGServiceConstruct(is, signature, environment, error);
        return 0;
    }
    return signature;
}

@implementation TGStarGiftTLMessageAction

@end

@implementation TLMessage$modernMessageService

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLMessage$modernMessageService serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLMessage$modernMessageService *result = [[TLMessage$modernMessageService alloc] init];
    
    int32_t flags = [is readInt32];
    const bool baseLayout = signature == (int32_t)0x2b085862;
    const bool modern = baseLayout || signature == (int32_t)0x7a800e0a || signature == (int32_t)0x6a3ac8ea;
    const bool extended = modern && !baseLayout;
    
    result.flags = flags;
    result.n_id = [is readInt32];
    
    if (flags & (1 << 8))
    {
        if (modern)
        {
            TLPeer *fromPeer = OGServiceReadPeer(is, environment, error);
            if (OGServiceFailed(error))
                return nil;
            result.senderPeerId = OGServicePeerKey(fromPeer);
            result.from_id = TGPeerIdIsUser(result.senderPeerId) ? result.senderPeerId : 0;
        }
        else
            result.from_id = [is readInt32];
    }
    
    result.to_id = OGServiceReadPeer(is, environment, error);
    if (OGServiceFailed(error))
        return nil;
    
    if (extended && (flags & (1 << 28)))
    {
        TLPeer *savedPeer = OGServiceReadPeer(is, environment, error);
        if (OGServiceFailed(error))
            return nil;
        result.saved_peer_id = OGServicePeerKey(savedPeer);
    }
    
    if (flags & (1 << 3))
    {
        result.reply_to_msg_id = modern ? OGServiceReadReplyHeader(is, environment, error) : [is readInt32];
        if (OGServiceFailed(error))
            return nil;
    }
    
    result.date = [is readInt32];
    
    int32_t actionSignature = [is readInt32];
    switch ((uint32_t)actionSignature)
    {
        case 0xea2c31d3:
        case 0xe6c31522:
        case 0x7e1c1187:
        case 0x774278d4:
        case 0x73ada76b:
        {
            TGTLDynamicObject *giftAction = [TGTLDynamicObject parseObjectFromStream:is signature:actionSignature error:error];
            if (giftAction == nil)
                return nil;
            TGStarGiftTLMessageAction *action = [[TGStarGiftTLMessageAction alloc] init];
            action.giftAction = giftAction;
            result.action = action;
            break;
        }
        case 0x80e11a7f:
        case 0xcc02aa6d:
        {
            if (!modern)
            {
                result.action = OGServiceConstruct(is, actionSignature, environment, error);
                if (OGServiceFailed(error))
                    return nil;
            }
            else if (actionSignature == (int32_t)0x80e11a7f)
            {
                TLMessageAction$messageActionPhoneCall *phoneAction = [[TLMessageAction$messageActionPhoneCall alloc] init];
                result.action = [phoneAction TLdeserialize:is signature:actionSignature environment:environment context:nil error:error];
                if (OGServiceFailed(error))
                    return nil;
            }
            else
            {
                OGServiceDiscardInt32(is);
                result.action = [[TLMessageAction$messageActionEmpty alloc] init];
            }
            break;
        }
        default:
            result.action = OGServiceConstruct(is, actionSignature, environment, error);
            if (OGServiceFailed(error))
                return nil;
            break;
    }
    
    if (extended && (flags & (1 << 20)))
    {
        OGServiceReadBoxed(is, environment, error);
        if (OGServiceFailed(error))
            return nil;
    }
    
    if (modern && (flags & (1 << 25)))
        OGServiceDiscardInt32(is);
    
    return result;
}

@end
