#import "TGUserSignal.h"

#import "TGTelegramNetworking.h"
#import "TL/TLMetaScheme.h"
#import "TGDatabase.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TLUserFull$userFull.h"
#import "TLUser$modernUser.h"
#import "TGUserDataRequestBuilder.h"
#import "TGConversation+Telegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGMediaOriginInfo+Telegraph.h"
#import "TGTLSerialization.h"
#import "TGTelegraph.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTProto.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestMessageService.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTBuffer.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTApiEnvironment.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRpcError.h"

@interface TGProfileMusicRequestService : MTRequestMessageService
{
    bool _profileMusicReady;
    MTRequest *_profileMusicPendingRequest;
}

- (void)enqueueProfileMusicRequest:(MTRequest *)request;
- (void)cancelProfileMusicRequest:(MTRequest *)request;

@end

@implementation TGProfileMusicRequestService

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [super mtProtoDidAddService:mtProto];

    self.apiEnvironment = nil;

    MTRequest *pendingRequest = nil;
    @synchronized(self)
    {
        _profileMusicReady = true;
        pendingRequest = _profileMusicPendingRequest;
        _profileMusicPendingRequest = nil;
    }

    if (pendingRequest != nil)
        [super addRequest:pendingRequest];
}

- (void)mtProtoApiEnvironmentUpdated:(MTProto *)__unused mtProto apiEnvironment:(MTApiEnvironment *)__unused apiEnvironment
{
    self.apiEnvironment = nil;
}

- (void)enqueueProfileMusicRequest:(MTRequest *)request
{
    if (request == nil)
        return;

    bool ready = false;
    @synchronized(self)
    {
        ready = _profileMusicReady;
        if (!ready)
            _profileMusicPendingRequest = request;
    }

    if (ready)
        [super addRequest:request];
}

- (void)cancelProfileMusicRequest:(MTRequest *)request
{
    if (request == nil)
        return;

    bool ready = false;
    @synchronized(self)
    {
        ready = _profileMusicReady;
        if (!ready && _profileMusicPendingRequest == request)
            _profileMusicPendingRequest = nil;
    }

    if (ready)
        [super removeRequestByInternalId:request.internalId];
}

@end

static void TGIOS6ProfileMusicResolveForeignUser(TGUser *user, int64_t *userId, int64_t *accessHash)
{
    if (user == nil)
        return;

    int64_t resolvedUserId = TGModernUserIdForLegacyId(user.uid);
    int64_t resolvedAccessHash = user.phoneNumberHash;

    NSString *photoUrl = user.photoUrlSmall.length != 0 ? user.photoUrlSmall : user.photoUrlBig;
    if ([photoUrl hasPrefix:@"peerphoto:"])
    {
        NSArray *components = [photoUrl componentsSeparatedByString:@":"];
        if (components.count >= 5 && [components[2] intValue] == 1)
        {
            int64_t photoUserId = [components[3] longLongValue];
            int64_t photoAccessHash = [components[4] longLongValue];
            if (photoUserId > 0)
                resolvedUserId = photoUserId;
            if (photoAccessHash != 0)
                resolvedAccessHash = photoAccessHash;
        }
    }

    if (userId != NULL)
        *userId = resolvedUserId;
    if (accessHash != NULL)
        *accessHash = resolvedAccessHash;
}

static NSData *TGIOS6ProfileSavedMusicRequestPayload(MTApiEnvironment *environment, int64_t userId, int64_t accessHash, bool isSelf)
{
    MTBuffer *buffer = [[MTBuffer alloc] init];

    [buffer appendInt32:(int32_t)0xda9b0d0d];
    [buffer appendInt32:[environment.layer intValue]];
    int32_t flags = 0;
    if (environment.socksProxySettings.secret != nil)
        flags |= (1 << 0);

    [buffer appendInt32:(int32_t)0xc1cd5ea9];
    [buffer appendInt32:flags];
    [buffer appendInt32:environment.apiId];
    [buffer appendTLString:environment.deviceModel ?: @"iPhone"];
    [buffer appendTLString:environment.systemVersion ?: @"iOS"];
    [buffer appendTLString:environment.appVersion ?: @"Onegram"];
    [buffer appendTLString:environment.systemLangCode ?: @"en"];
    [buffer appendTLString:environment.langPack ?: @""];
    [buffer appendTLString:environment.langPackCode ?: @"en"];

    if (flags & (1 << 0))
    {
        [buffer appendInt32:(int32_t)0x75588b3f];
        [buffer appendTLString:environment.socksProxySettings.ip ?: @""];
        [buffer appendInt32:(int32_t)environment.socksProxySettings.port];
    }

    [buffer appendInt32:(int32_t)0xbf9459b7];

    [buffer appendInt32:(int32_t)0x788d7fe3];
    if (isSelf)
    {
        [buffer appendInt32:(int32_t)0xf7c1b13f];
    }
    else
    {
        [buffer appendInt32:(int32_t)0xf21158c6];
        [buffer appendInt64:(int64_t)userId];
        [buffer appendInt64:accessHash];
    }
    [buffer appendInt32:0];
    [buffer appendInt32:100];
    [buffer appendInt64:0];

    return buffer.data;
}

static SSignal *TGIOS6ProfileSavedMusicRawSignal(TGUser *user)
{
    if (user == nil)
        return [SSignal single:[NSNull null]];

    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGTelegramNetworking *networking = [TGTelegramNetworking instance];
        MTContext *context = [networking context];
        MTProto *mainMtProto = [networking mtProto];
        NSInteger datacenterId = mainMtProto.datacenterId;
        MTApiEnvironment *environment = context.apiEnvironment;
        MTDatacenterAuthInfo *authInfo = [context authInfoForDatacenterWithId:datacenterId];

        if (context == nil || environment == nil || environment.layer == nil || authInfo == nil || authInfo.authKey.length == 0)
        {
            [subscriber putNext:[NSNull null]];
            [subscriber putCompletion];
            return nil;
        }

        bool isSelf = user.uid == TGTelegraphInstance.clientUserId;
        int64_t profileMusicUserId = user.uid;
        int64_t profileMusicAccessHash = user.phoneNumberHash;
        if (!isSelf)
            TGIOS6ProfileMusicResolveForeignUser(user, &profileMusicUserId, &profileMusicAccessHash);

        if (!isSelf && (profileMusicUserId == 0 || profileMusicAccessHash == 0))
        {
            TGLog(@"PROFILEMUSIC invalid input legacy=%d modern=%lld hash=%lld", user.uid, profileMusicUserId, profileMusicAccessHash);
            [subscriber putNext:[NSNull null]];
            [subscriber putCompletion];
            return nil;
        }

        MTProto *mtProto = [[MTProto alloc] initWithContext:context datacenterId:datacenterId usageCalculationInfo:nil];
        mtProto.useTempAuthKeys = false;
        mtProto.shouldStayConnected = false;

        TGProfileMusicRequestService *requestService = [[TGProfileMusicRequestService alloc] initWithContext:context];
        [mtProto addMessageService:requestService];

        MTRequest *request = [[MTRequest alloc] init];
        NSData *payload = TGIOS6ProfileSavedMusicRequestPayload(environment, profileMusicUserId, profileMusicAccessHash, isSelf);
        [request setPayload:payload metadata:[NSString stringWithFormat:@"profile.savedMusic.layer%@", environment.layer] responseParser:^id(NSData *responseData)
        {
            return [TGTLSerialization parseProfileSavedMusicResponse:responseData];
        }];

        MTProto *profileMtProto = mtProto;
        [request setCompleted:^(id result, __unused NSTimeInterval timestamp, MTRpcError *error)
        {
            id outputValue = [NSNull null];
            if (error != nil)
            {
                TGLog(@"PROFILEMUSIC rpc error uid=%d layer=%@ code=%d description=%@", user.uid, environment.layer, (int)error.errorCode, error.errorDescription);
            }
            else
            {
                NSArray *documents = [result isKindOfClass:[NSArray class]] ? result : nil;
                NSMutableArray *profileMusic = [[NSMutableArray alloc] init];
                for (TLDocument *document in documents)
                {
                    if (![document isKindOfClass:[TLDocument class]])
                        continue;
                    TGDocumentMediaAttachment *attachment = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:document];
                    attachment.originInfo = [TGMediaOriginInfo mediaOriginInfoForDocument:document];
                    if (attachment.documentId != 0)
                        [profileMusic addObject:attachment];
                }
                if (profileMusic.count != 0)
                {
                    outputValue = profileMusic;
                }
                else
                {
                    outputValue = @[];
                }
            }

            [profileMtProto removeMessageService:requestService];
            [profileMtProto stop];
            [subscriber putNext:outputValue];
            [subscriber putCompletion];
        }];

        [mtProto resume];
        [requestService enqueueProfileMusicRequest:request];

        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [requestService cancelProfileMusicRequest:request];
            [mtProto removeMessageService:requestService];
            [mtProto stop];
        }];
    }];
}

static SSignal *TGIOS6ProfileSavedMusicSignal(TGUser *user)
{
    TGTelegramNetworking *networking = [TGTelegramNetworking instance];
    NSString *key = [[NSString alloc] initWithFormat:@"profileSavedMusic:%d", user.uid];
    return [networking.genericTasksSignalManager multicastedSignalForKey:key producer:^SSignal *
    {
        return TGIOS6ProfileSavedMusicRawSignal(user);
    }];
}

@interface TGUserUpdatesAdapter : NSObject <ASWatcher>
{
    int32_t _userId;
    void (^_userUpdated)(TGUser *);
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGUserUpdatesAdapter

- (instancetype)initWithUserId:(int32_t)userId userUpdated:(void (^)(TGUser *))userUpdated
{
    self = [super init];
    if (self != nil)
    {
        _userId = userId;
        _userUpdated = [userUpdated copy];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        [ActionStageInstance() watchForPaths:@[
            @"/tg/userdatachanges",
            @"/tg/userpresencechanges"
        ] watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        for (TGUser *user in users)
        {
            if (user.uid == _userId)
            {
                if (_userUpdated)
                    _userUpdated(user);
            }
        }
    }
}

@end

@implementation TGUserSignal

+ (SSignal *)userWithUserId:(int32_t)userId
{
    SSignal *localSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user == nil)
            [subscriber putError:nil];
        else
        {
            [subscriber putNext:user];
            [subscriber putCompletion];
        }
        return nil;
    }];
    
    SSignal *updatesSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGUserUpdatesAdapter *adapter = [[TGUserUpdatesAdapter alloc] initWithUserId:userId userUpdated:^(TGUser *user)
        {
            [subscriber putNext:user];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [adapter description];
        }];
    }];
    
    return [localSignal then:updatesSignal];
}

+ (SSignal *)profileSavedMusicWithUserId:(int32_t)userId {
    return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user == nil)
            return [SSignal single:@[]];
        return TGIOS6ProfileSavedMusicSignal(user);
    }] switchToLatest];
}

+ (SSignal *)updatedUserCachedDataWithUserId:(int32_t)userId {
    return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user != nil) {
            TLRPCusers_getFullUser$users_getFullUser *getFullUser = [[TLRPCusers_getFullUser$users_getFullUser alloc] init];
            if (userId == TGTelegraphInstance.clientUserId)
            {
                getFullUser.n_id = [[TLInputUser$inputUserSelf alloc] init];
            }
            else
            {
                int64_t resolvedUserId = 0;
                int64_t resolvedAccessHash = 0;
                TGIOS6ProfileMusicResolveForeignUser(user, &resolvedUserId, &resolvedAccessHash);
                TLInputUser$inputUser *inputUser = [[TLInputUser$inputUser alloc] init];
                inputUser.user_id = resolvedUserId;
                inputUser.access_hash = resolvedAccessHash;
                getFullUser.n_id = inputUser;
            }
            return [[[TGTelegramNetworking instance] requestSignal:getFullUser] mapToSignal:^SSignal *(TLUserFull$userFull *result) {
                return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                    [TGDatabaseInstance() updateCachedUserData:user.uid block:^TGCachedUserData *(TGCachedUserData *data) {
                        if (data == nil) {
                            return [[TGCachedUserData alloc] initWithAbout:result.about groupsInCommonCount:result.common_chats_count groupsInCommon:nil supportsCalls:result.flags & (1 << 4) callsPrivate:result.flags & (1 << 5)];
                        } else {
                            return [[[[data updateAbout:result.about] updateGroupsInCommonCount:result.common_chats_count] updateSupportsCalls:result.flags & (1 << 4)] updateCallsPrivate:result.flags & (1 << 5)];
                        }
                    }];

                    if (result.saved_music != nil)
                    {
                        TGDocumentMediaAttachment *profileMusic = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:result.saved_music];
                        profileMusic.originInfo = [TGMediaOriginInfo mediaOriginInfoForDocument:result.saved_music];
                        return [SSignal single:profileMusic];
                    }

                    return [TGIOS6ProfileSavedMusicSignal(user) map:^id(id value) {
                        NSArray *tracks = [value isKindOfClass:[NSArray class]] ? value : nil;
                        return tracks.count != 0 ? tracks[0] : [NSNull null];
                    }];
                }] switchToLatest];
            }];
        } else {
            return [SSignal fail:nil];
        }
    }] switchToLatest];
}

+ (SSignal *)groupsInCommon:(int32_t)userId {
    return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user != nil) {
            TLRPCmessages_getCommonChats$messages_getCommonChats *getCommonChats = [[TLRPCmessages_getCommonChats$messages_getCommonChats alloc] init];
            TLInputUser$inputUser *inputUser = [[TLInputUser$inputUser alloc] init];
            inputUser.user_id = user.uid;
            inputUser.access_hash = user.phoneNumberHash;
            getCommonChats.user_id = inputUser;
            getCommonChats.limit = 200;
            return [[[TGTelegramNetworking instance] requestSignal:getCommonChats] mapToSignal:^SSignal *(TLmessages_Chats *result) {
                NSMutableArray *conversations = [[NSMutableArray alloc] init];
                for (TLChat *chat in result.chats) {
                    TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
                    if (conversation.conversationId != 0) {
                        [conversations addObject:conversation];
                    }
                }
                return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                    [TGDatabaseInstance() updateCachedUserData:user.uid block:^TGCachedUserData *(TGCachedUserData *data) {
                        if (data == nil) {
                            return [[TGCachedUserData alloc] initWithAbout:nil groupsInCommonCount:(int32_t)conversations.count groupsInCommon:[[TGCachedUserGroupsInCommon alloc] initWithGroups:conversations] supportsCalls:false callsPrivate:false];
                        } else {
                            return [[data updateGroupsInCommon:[[TGCachedUserGroupsInCommon alloc] initWithGroups:conversations]] updateGroupsInCommonCount:(int32_t)conversations.count];
                        }
                    }];
                    
                    return [SSignal single:[[TGCachedUserGroupsInCommon alloc] initWithGroups:conversations]];
                }] switchToLatest];
            }];
        } else {
            return [SSignal fail:nil];
        }
    }] switchToLatest];
}

@end
