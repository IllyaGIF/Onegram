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

    // The request contains its own layer-213 initConnection.  Never let the
    // base request service prepend the layer-181 initializer.
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
    // Keep automatic request decoration disabled for this isolated service.
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

    // Modern 64-bit ids are collapsed into a synthetic int32 uid for the old
    // TelegraphKit database.  The in-memory map is lost after an app restart,
    // but modern peer-photo urls persist the real id and access hash:
    // peerphoto:dc:type:peerId:accessHash:photoId:big
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

    // The main Onegram connection intentionally stays on layer 181.  Saved
    // Music was introduced in layer 213, so this payload initializes only a
    // short-lived secondary MTProto connection at layer 213.
    [buffer appendInt32:(int32_t)0xda9b0d0d]; // invokeWithLayer
    [buffer appendInt32:213];

    // initConnection#c1cd5ea9 (the constructor used by layer 213)
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
        [buffer appendInt32:(int32_t)0x75588b3f]; // inputClientProxy
        [buffer appendTLString:environment.socksProxySettings.ip ?: @""];
        [buffer appendInt32:(int32_t)environment.socksProxySettings.port];
    }

    // Do not subscribe this secondary connection for updates.
    [buffer appendInt32:(int32_t)0xbf9459b7]; // invokeWithoutUpdates

    // users.getSavedMusic#788d7fe3 id:InputUser offset:int limit:int hash:long
    [buffer appendInt32:(int32_t)0x788d7fe3];
    if (isSelf)
    {
        [buffer appendInt32:(int32_t)0xf7c1b13f]; // inputUserSelf
    }
    else
    {
        [buffer appendInt32:(int32_t)0xf21158c6]; // inputUser
        [buffer appendInt64:(int64_t)userId];
        [buffer appendInt64:accessHash];
    }
    [buffer appendInt32:0]; // offset
    [buffer appendInt32:100]; // fetch the whole Saved Music page for the player queue
    [buffer appendInt64:0]; // hash: force the full result

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

        if (context == nil || environment == nil || authInfo == nil || authInfo.authKey.length == 0)
        {
            TGLog(@"PROFILEMUSIC layer213 unavailable uid=%d dc=%ld context=%d env=%d auth=%d", user.uid, (long)datacenterId, context != nil, environment != nil, authInfo.authKey.length != 0);
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
            TGLog(@"PROFILEMUSIC layer213 invalid input legacy=%d modern=%lld hash=%lld", user.uid, profileMusicUserId, profileMusicAccessHash);
            [subscriber putNext:[NSNull null]];
            [subscriber putCompletion];
            return nil;
        }

        // invokeWithLayer is effectively sticky for this authorization key.
        // Freeze the legacy connection while the short-lived layer-213 request is
        // active so it can never receive layer-213 Updates/Message constructors.
        [mainMtProto pause];

        MTProto *mtProto = [[MTProto alloc] initWithContext:context datacenterId:datacenterId usageCalculationInfo:nil];
        mtProto.useTempAuthKeys = false;
        mtProto.shouldStayConnected = false;

        TGProfileMusicRequestService *requestService = [[TGProfileMusicRequestService alloc] initWithContext:context];
        [mtProto addMessageService:requestService];

        MTRequest *request = [[MTRequest alloc] init];
        NSData *payload = TGIOS6ProfileSavedMusicRequestPayload(environment, profileMusicUserId, profileMusicAccessHash, isSelf);
        [request setPayload:payload metadata:@"profile.savedMusic.layer213" responseParser:^id(NSData *responseData)
        {
            return [TGTLSerialization parseProfileSavedMusicResponse:responseData];
        }];

        MTProto *profileMtProto = mtProto;
        [request setCompleted:^(id result, __unused NSTimeInterval timestamp, MTRpcError *error)
        {
            id outputValue = [NSNull null];
            if (error != nil)
            {
                TGLog(@"PROFILEMUSIC layer213 rpc error uid=%d code=%d description=%@", user.uid, (int)error.errorCode, error.errorDescription);
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
                    TGLog(@"PROFILEMUSIC loaded uid=%d tracks=%lu", user.uid, (unsigned long)profileMusic.count);
                    outputValue = profileMusic;
                }
                else
                {
                    TGLog(@"PROFILEMUSIC layer213 empty uid=%d", user.uid);
                    outputValue = @[];
                }
            }

            // Shut down layer 213 before mapToSignal starts the legacy-layer
            // restore.  This prevents the two layer initializations from racing.
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

            // Cancellation may happen after layer 213 was already sent.  Mark the
            // shared key as uninitialized before resuming the legacy connection.
            [context performBatchUpdates:^
            {
                MTDatacenterAuthInfo *currentAuthInfo = [context authInfoForDatacenterWithId:datacenterId];
                if (currentAuthInfo != nil)
                {
                    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithDictionary:currentAuthInfo.authKeyAttributes];
                    [attributes removeObjectForKey:@"apiInitializationHash"];
                    [context updateAuthInfoForDatacenterWithId:datacenterId authInfo:[currentAuthInfo withUpdatedAuthKeyAttributes:attributes]];
                }
            }];
        }];
    }];
}

static void TGIOS6ProfileMusicInvalidateMainApiInitialization(TGTelegramNetworking *networking, NSInteger datacenterId)
{
    MTContext *context = networking.context;
    [context performBatchUpdates:^
    {
        MTDatacenterAuthInfo *authInfo = [context authInfoForDatacenterWithId:datacenterId];
        if (authInfo != nil)
        {
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithDictionary:authInfo.authKeyAttributes];
            [attributes removeObjectForKey:@"apiInitializationHash"];
            [context updateAuthInfoForDatacenterWithId:datacenterId authInfo:[authInfo withUpdatedAuthKeyAttributes:attributes]];
        }
    }];
}

static SSignal *TGIOS6ProfileMusicRestoreLegacyLayerSignal(TGTelegramNetworking *networking, NSInteger datacenterId, id value)
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGIOS6ProfileMusicInvalidateMainApiInitialization(networking, datacenterId);

        // Queue the reset request while the legacy MTProto is still paused.
        // When it resumes, MTRequestMessageService sees the missing
        // apiInitializationHash and wraps this request (and any queued ordinary
        // requests) in invokeWithLayer(181)+initConnection before anything can
        // receive layer-213 updates.
        MTRequest *resetRequest = [[MTRequest alloc] init];
        resetRequest.body = [[TLRPCupdates_getState$updates_getState alloc] init];
        [resetRequest setCompleted:^(__unused id result, __unused NSTimeInterval timestamp, MTRpcError *error)
        {
            if (error != nil)
                TGLog(@"PROFILEMUSIC restore layer181 error dc=%ld code=%d description=%@", (long)datacenterId, (int)error.errorCode, error.errorDescription);

            [subscriber putNext:value ?: [NSNull null]];
            [subscriber putCompletion];
        }];

        [networking addRequest:resetRequest];
        [networking.mtProto resume];

        // Never cancel the reset request: even if the UI subscription disappears,
        // the shared authorization key must be returned to layer 181.
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [networking.mtProto resume];
        }];
    }];
}

static SSignal *TGIOS6ProfileSavedMusicSignal(TGUser *user)
{
    TGTelegramNetworking *networking = [TGTelegramNetworking instance];
    NSString *key = [[NSString alloc] initWithFormat:@"profileSavedMusic:%d", user.uid];
    return [networking.genericTasksSignalManager multicastedSignalForKey:key producer:^SSignal *
    {
        NSInteger datacenterId = networking.mtProto.datacenterId;
        return [[TGIOS6ProfileSavedMusicRawSignal(user) mapToSignal:^SSignal *(id value)
        {
            return TGIOS6ProfileMusicRestoreLegacyLayerSignal(networking, datacenterId, value);
        }] onDispose:^
        {
            [networking.mtProto resume];
        }];
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
            [adapter description]; //keep reference
        }];
    }];
    
    return [localSignal then:updatesSignal];
}

+ (SSignal *)profileSavedMusicWithUserId:(int32_t)userId {
    return [[TGDatabaseInstance() modify:^id {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user == nil)
            return [SSignal single:@[]];
        return TGIOS6ProfileSavedMusicSignal(user);
    }] switchToLatest];
}

+ (SSignal *)updatedUserCachedDataWithUserId:(int32_t)userId {
    return [[TGDatabaseInstance() modify:^id {
        TGUser *user = [TGDatabaseInstance() loadUser:userId];
        if (user != nil) {
            TLRPCusers_getFullUser$users_getFullUser *getFullUser = [[TLRPCusers_getFullUser$users_getFullUser alloc] init];
            TLInputUser$inputUser *inputUser = [[TLInputUser$inputUser alloc] init];
            inputUser.user_id = user.uid;
            inputUser.access_hash = user.phoneNumberHash;
            getFullUser.n_id = inputUser;
            return [[[TGTelegramNetworking instance] requestSignal:getFullUser] mapToSignal:^SSignal *(TLUserFull$userFull *result) {
                return [[TGDatabaseInstance() modify:^id{
                    [TGDatabaseInstance() updateCachedUserData:user.uid block:^TGCachedUserData *(TGCachedUserData *data) {
                        if (data == nil) {
                            return [[TGCachedUserData alloc] initWithAbout:result.about groupsInCommonCount:result.common_chats_count groupsInCommon:nil supportsCalls:result.flags & (1 << 4) callsPrivate:result.flags & (1 << 5)];
                        } else {
                            return [[[[data updateAbout:result.about] updateGroupsInCommonCount:result.common_chats_count] updateSupportsCalls:result.flags & (1 << 4)] updateCallsPrivate:result.flags & (1 << 5)];
                        }
                    }];

                    // Layer 181 userFull cannot contain profile Saved Music.  Keep
                    // accepting saved_music if a compatible server ever sends it, but
                    // normally fetch the first attached track through a short-lived
                    // layer-213 connection.
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
    return [[TGDatabaseInstance() modify:^id {
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
                return [[TGDatabaseInstance() modify:^id{
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
