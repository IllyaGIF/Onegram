#import "TGSendAsSignals.h"
#import "TGTLDynamic.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGTelegramNetworking.h"
#import "TGUserDataRequestBuilder.h"
#import "TGConversation+Telegraph.h"
#import "TLInputPeer.h"
#import "TLChat.h"
#import "TLUser.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SMulticastSignalManager.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

static NSMutableSet *TGSendAsInvalidPeers = nil;
static SMulticastSignalManager *TGSendAsRequestManager = nil;

static SMulticastSignalManager *TGSendAsRequests(void)
{
    @synchronized([TGSendAsSignals class])
    {
        if (TGSendAsRequestManager == nil)
            TGSendAsRequestManager = [[SMulticastSignalManager alloc] init];
        return TGSendAsRequestManager;
    }
}

static NSString *TGSendAsStorageKey(int64_t accountId, int64_t peerId)
{
    return [NSString stringWithFormat:@"Onegram.SendAs.%lld.%lld", accountId, peerId];
}

static int64_t TGSendAsPeerId(TGTLDynamicObject *peer)
{
    if ([peer isConstructor:@"peerUser"])
        return TGPeerIdFromUserId([peer int64Field:@"user_id"]);
    if ([peer isConstructor:@"peerChannel"])
        return TGPeerIdFromChannelId([peer int64Field:@"channel_id"]);
    if ([peer isConstructor:@"peerChat"])
        return TGPeerIdFromGroupId([peer int64Field:@"chat_id"]);
    return 0;
}

@interface TGSendAsPeer ()
@property (nonatomic) int64_t peerId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) bool premiumRequired;
@end

@implementation TGSendAsPeer

+ (instancetype)peerWithId:(int64_t)peerId
{
    if (peerId == 0)
        return nil;
    TGSendAsPeer *peer = [[TGSendAsPeer alloc] init];
    peer.peerId = peerId;
    if (TGPeerIdIsChannel(peerId))
        peer.accessHash = [TGDatabaseInstance() loadConversationWithId:peerId].accessHash;
    else if (TGPeerIdIsUser(peerId))
        peer.accessHash = [TGDatabaseInstance() loadUser:peerId].phoneNumberHash;
    return peer;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        _peerId = [coder decodeInt64ForCKey:"peer"];
        _accessHash = [coder decodeInt64ForCKey:"hash"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt64:_peerId forCKey:"peer"];
    [coder encodeInt64:_accessHash forCKey:"hash"];
}

- (TLInputPeer *)inputPeer
{
    return [TGTelegraphInstance createInputPeerForConversation:_peerId accessHash:_accessHash];
}

- (NSString *)title
{
    if (TGPeerIdIsUser(_peerId))
        return [[TGDatabaseInstance() loadUser:_peerId] displayName];
    return [TGDatabaseInstance() loadConversationWithId:_peerId].chatTitle;
}

- (NSString *)firstName
{
    return TGPeerIdIsUser(_peerId) ? [TGDatabaseInstance() loadUser:_peerId].firstName : self.title;
}

- (NSString *)lastName
{
    return TGPeerIdIsUser(_peerId) ? [TGDatabaseInstance() loadUser:_peerId].lastName : nil;
}

- (NSString *)avatarUrl
{
    if (TGPeerIdIsUser(_peerId))
        return [TGDatabaseInstance() loadUser:_peerId].photoFullUrlSmall;
    return [TGDatabaseInstance() loadConversationWithId:_peerId].chatPhotoFullSmall;
}

@end

@interface TGSendAsState ()
@property (nonatomic, copy) NSArray *peers;
@property (nonatomic, strong) TGSendAsPeer *selectedPeer;
@end
@implementation TGSendAsState
@end

@implementation TGSendAsSignals

+ (TGSendAsPeer *)selectedSenderForPeerId:(int64_t)peerId
{
    NSDictionary *value = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TGSendAsStorageKey(TGTelegraphInstance.clientUserId, peerId)];
    TGSendAsPeer *peer = [TGSendAsPeer peerWithId:[value[@"peer"] longLongValue]];
    if (peer != nil)
        peer.accessHash = [value[@"hash"] longLongValue];
    return peer;
}

+ (void)savePeer:(TGSendAsPeer *)peer storageKey:(NSString *)storageKey
{
    if (peer != nil)
        [[NSUserDefaults standardUserDefaults] setObject:@{@"peer": @(peer.peerId), @"hash": @(peer.accessHash)} forKey:storageKey];
}

+ (SSignal *)availableSendersForPeerId:(int64_t)peerId accessHash:(int64_t)accessHash
{
    if (!TGPeerIdIsChannel(peerId))
        return [SSignal fail:nil];
    int64_t accountId = TGTelegraphInstance.clientUserId;
    TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
    if (conversation == nil || !conversation.isChannelMember || ![conversation currentUserCanSendMessages])
        return [SSignal fail:nil];
    if (accessHash == 0)
        accessHash = conversation.accessHash;
    if (accessHash == 0)
        return [SSignal fail:nil];
    NSString *requestKey = [NSString stringWithFormat:@"%lld:%lld:%lld", accountId, peerId, accessHash];
    @synchronized(self)
    {
        if ([TGSendAsInvalidPeers containsObject:requestKey])
            return [SSignal fail:nil];
    }
    NSString *storageKey = TGSendAsStorageKey(accountId, peerId);
    TLInputPeer *inputPeer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    int64_t resolvedAccessHash = accessHash;
    return [TGSendAsRequests() multicastedSignalForKey:requestKey producer:^SSignal *
    {
    SSignal *requestSignal = [[TGTLDynamicRpc requestSignalWithMethod:@"channels.getSendAs" parameters:@{@"peer": inputPeer}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (TGTelegraphInstance.clientUserId != accountId || ![result isConstructor:@"channels.sendAsPeers"])
            return [SSignal fail:nil];
        NSMutableArray *users = [[NSMutableArray alloc] init];
        for (id user in [result arrayField:@"users"])
            if ([user isKindOfClass:[TLUser class]])
                [users addObject:user];
        [TGUserDataRequestBuilder executeUserDataUpdate:users];
        NSMutableArray *channels = [[NSMutableArray alloc] init];
        for (id chat in [result arrayField:@"chats"])
        {
            if (![chat isKindOfClass:[TLChat class]])
                continue;
            TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
            if (conversation != nil && TGPeerIdIsChannel(conversation.conversationId))
                [channels addObject:conversation];
        }
        if (channels.count != 0)
            [TGDatabaseInstance() updateChannels:channels];
        NSMutableArray *peers = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *item in [result arrayField:@"peers"])
        {
            TGSendAsPeer *peer = [TGSendAsPeer peerWithId:TGSendAsPeerId([item objectField:@"peer"])];
            if (peer == nil)
                continue;
            peer.premiumRequired = [item flag:@"premium_required"];
            [peers addObject:peer];
        }
        TGSendAsPeer *cached = [self selectedSenderForPeerId:peerId];
        TGSendAsState *state = [[TGSendAsState alloc] init];
        state.peers = peers;
        id channel = [TGTLDynamicObject objectWithConstructor:@"inputChannel" fields:@{@"channel_id": @(TGChannelIdFromPeerId(peerId)), @"access_hash": @(resolvedAccessHash)}];
        SSignal *full = [[TGTLDynamicRpc requestSignalWithMethod:@"channels.getFullChannel" parameters:@{@"channel": channel}] catch:^SSignal *(__unused id error) { return [SSignal single:nil]; }];
        return [full map:^id(TGTLDynamicObject *data)
        {
            if (TGTelegraphInstance.clientUserId != accountId)
                return nil;
            int64_t defaultId = TGSendAsPeerId([[data objectField:@"full_chat"] objectField:@"default_send_as"]);
            if (defaultId == 0)
                defaultId = data == nil && cached.peerId != 0 ? cached.peerId : accountId;
            for (TGSendAsPeer *peer in peers)
                if (peer.peerId == defaultId)
                    state.selectedPeer = peer;
            if (state.selectedPeer == nil)
                for (TGSendAsPeer *peer in peers)
                    if (peer.peerId == accountId)
                        state.selectedPeer = peer;
            if (state.selectedPeer == nil)
                state.selectedPeer = peers.firstObject;
            [self savePeer:state.selectedPeer storageKey:storageKey];
            return state;
        }];
    }];
    return [requestSignal catch:^SSignal *(id error)
    {
        NSString *type = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
        if ([type isEqualToString:@"PEER_ID_INVALID"] || [type isEqualToString:@"CHANNEL_INVALID"] || [type isEqualToString:@"CHAT_ID_INVALID"])
        {
            @synchronized(self)
            {
                if (TGSendAsInvalidPeers == nil)
                    TGSendAsInvalidPeers = [[NSMutableSet alloc] init];
                [TGSendAsInvalidPeers addObject:requestKey];
            }
        }
        return [SSignal fail:error];
    }];
    }];
}

+ (SSignal *)selectSender:(TGSendAsPeer *)sender peerId:(int64_t)peerId accessHash:(int64_t)accessHash
{
    int64_t accountId = TGTelegraphInstance.clientUserId;
    NSString *storageKey = TGSendAsStorageKey(accountId, peerId);
    TLInputPeer *inputPeer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.saveDefaultSendAs" parameters:@{@"peer": inputPeer, @"send_as": [sender inputPeer]}] mapToSignal:^SSignal *(id result)
    {
        if (TGTelegraphInstance.clientUserId != accountId || ([result isKindOfClass:[NSNumber class]] && ![result boolValue]))
            return [SSignal fail:nil];
        [self savePeer:sender storageKey:storageKey];
        return [SSignal single:sender];
    }];
}

@end
