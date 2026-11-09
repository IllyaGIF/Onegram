#import "TGPluginHost.h"

#if OG_PLUGINS_AVAILABLE

#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRpcError.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestErrorContext.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../OnegramPlugins/OGPluginHooks.h"
#import "../OnegramPlugins/OGPluginUI.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

#import "TGAccountManager.h"
#import "TGAccountSwitcher.h"
#import "TGAppDelegate.h"
#import "TGRootController.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"
#import "TGTLSerialization.h"
#import "TGMessage+Telegraph.h"
#import "TGModernSendCommonMessageActor.h"
#import "TGPreparedLocalDocumentMessage.h"
#import "TGShareMenu.h"
#import "TGPluginsController.h"
#import "TGCustomAlertView.h"
#import "TGPresentation.h"
#import "TGDefaultPresentationPallete.h"
#import "TGDayPresentationPallete.h"
#import "TGNightPresentationPallete.h"
#import "TGNightBluePresentationPallete.h"
#import "TGCloudTheme.h"
#import "TGWallpaperManager.h"
#import "TelegramMediaResources.h"
#import "MediaBoxContexts.h"
#import "MultipartFetch.h"

static const int64_t TGPluginHostEncryptedDialogFlag = 0x4000000000000000LL;
static NSMutableDictionary *TGPluginHostPendingSends = nil;

typedef NS_OPTIONS(NSInteger, TGPluginHostRequestFlags)
{
    TGPluginHostRequestFlagEnableUnauthorized = 1,
    TGPluginHostRequestFlagFailOnServerErrors = 2,
    TGPluginHostRequestFlagWithoutLogin = 8,
    TGPluginHostRequestFlagInvokeAfter = 64,
    TGPluginHostRequestFlagDoNotWaitFloodWait = 1024,
    TGPluginHostRequestFlagFailOnServerErrorsExceptFloodWait = 65536
};

@interface TGPluginHostRequestMetadata : NSObject

@property (nonatomic, readonly) NSInteger flags;

- (instancetype)initWithFlags:(NSInteger)flags;

@end

@implementation TGPluginHostRequestMetadata

- (instancetype)initWithFlags:(NSInteger)flags
{
    self = [super init];
    if (self != nil)
        _flags = flags;
    return self;
}

@end

@interface TGPluginHostDownload : NSObject

- (instancetype)initWithPath:(NSString *)path partialPath:(NSString *)partialPath handle:(NSFileHandle *)handle;

- (void)attachDisposable:(id<SDisposable>)disposable;
- (bool)appendData:(NSData *)data;
- (bool)finishWithError:(NSString **)error;
- (void)fail;
- (void)cancel;

@end

@implementation TGPluginHostDownload
{
    NSString *_path;
    NSString *_partialPath;
    NSFileHandle *_handle;
    id<SDisposable> _disposable;
    bool _finished;
}

- (instancetype)initWithPath:(NSString *)path partialPath:(NSString *)partialPath handle:(NSFileHandle *)handle
{
    self = [super init];
    if (self != nil)
    {
        _path = path;
        _partialPath = partialPath;
        _handle = handle;
    }
    return self;
}

- (void)attachDisposable:(id<SDisposable>)disposable
{
    bool dispose = false;
    @synchronized (self)
    {
        if (_finished)
            dispose = true;
        else
            _disposable = disposable;
    }
    if (dispose)
        [disposable dispose];
}

- (bool)appendData:(NSData *)data
{
    @synchronized (self)
    {
        if (_finished)
            return false;
        [_handle writeData:data];
        return true;
    }
}

- (bool)finishWithError:(NSString **)error
{
    @synchronized (self)
    {
        if (_finished)
            return false;
        _finished = true;
        _disposable = nil;
        [_handle closeFile];
        _handle = nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:_path error:NULL];
    NSError *moveError = nil;
    if ([fileManager moveItemAtPath:_partialPath toPath:_path error:&moveError])
        return true;
    [fileManager removeItemAtPath:_partialPath error:NULL];
    if (error != NULL)
        *error = moveError.localizedDescription ?: @"FILE_MOVE_FAILED";
    return false;
}

- (void)fail
{
    @synchronized (self)
    {
        if (_finished)
            return;
        _finished = true;
        _disposable = nil;
        [_handle closeFile];
        _handle = nil;
    }
    [[NSFileManager defaultManager] removeItemAtPath:_partialPath error:NULL];
}

- (void)cancel
{
    id<SDisposable> disposable = nil;
    @synchronized (self)
    {
        disposable = _disposable;
    }
    [disposable dispose];
    [self fail];
}

@end

static UIViewController *TGPluginHostPresentedController(UIViewController *controller)
{
    if ([controller respondsToSelector:@selector(presentedViewController)])
        return controller.presentedViewController;
    return [controller valueForKey:@"modalViewController"];
}

@interface TGPluginHost ()
{
    NSMutableArray *_pendingPluginFailures;
    bool _pluginFailureAlertVisible;
    bool _pluginFailureAlertScheduled;
}

@end

@implementation TGPluginHost

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _pendingPluginFailures = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pluginFailureNotified:) name:OGPluginsEventNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pluginFailureNotified:(NSNotification *)notification
{
    if (![notification.userInfo[OGPluginsEventNameKey] isEqualToString:@"plugin_failed"])
        return;
    id payload = notification.userInfo[OGPluginsEventPayloadKey];
    if (![payload isKindOfClass:[NSDictionary class]])
        return;
    if (![payload[@"id"] isKindOfClass:[NSString class]] || ![payload[@"name"] isKindOfClass:[NSString class]])
        return;
    [_pendingPluginFailures addObject:payload];
    [self schedulePluginFailureAlert];
}

- (void)applicationBecameActive:(NSNotification *)__unused notification
{
    [self schedulePluginFailureAlert];
}

- (void)schedulePluginFailureAlert
{
    if (_pluginFailureAlertVisible || _pluginFailureAlertScheduled || _pendingPluginFailures.count == 0)
        return;
    _pluginFailureAlertScheduled = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        self->_pluginFailureAlertScheduled = false;
        [self presentPendingPluginFailures];
    });
}

- (void)presentPendingPluginFailures
{
    if (_pluginFailureAlertVisible || _pendingPluginFailures.count == 0 ||
        [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        return;
    NSArray *failures = [_pendingPluginFailures copy];
    [_pendingPluginFailures removeAllObjects];
    _pluginFailureAlertVisible = true;
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    NSUInteger shown = MIN((NSUInteger)10, failures.count);
    for (NSUInteger index = 0; index < shown; index++)
    {
        NSDictionary *entry = failures[index];
        NSString *name = entry[@"name"];
        NSString *reason = [entry[@"error"] isKindOfClass:[NSString class]] ? entry[@"error"] : @"";
        NSArray *parts = [reason componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *part in [parts reverseObjectEnumerator])
        {
            if ([part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length != 0)
            {
                reason = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                break;
            }
        }
        if (reason.length > 180)
            reason = [[reason substringToIndex:180] stringByAppendingString:@"…"];
        [lines addObject:[NSString stringWithFormat:TGLocalized(@"OnegramPlugins.FailureEntry"), name, reason]];
    }
    if (failures.count > shown)
        [lines addObject:[NSString stringWithFormat:TGLocalized(@"OnegramPlugins.FailureMore"), (unsigned long)(failures.count - shown)]];
    NSString *message = [lines componentsJoinedByString:@"\n"];
    NSString *identifier = failures.count == 1 ? failures[0][@"id"] : nil;
    NSString *title = TGLocalized(failures.count == 1 ? @"OnegramPlugins.FailureTitleSingle" : @"OnegramPlugins.FailureTitle");
    [TGCustomAlertView presentAlertWithTitle:title message:message
        cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:TGLocalized(@"OnegramPlugins.Open")
        completionBlock:^(bool openPressed)
    {
        self->_pluginFailureAlertVisible = false;
        if (openPressed)
            [TGPluginsController openPluginWithIdentifier:identifier];
        [self schedulePluginFailureAlert];
    }];
}

+ (void)load
{
    @autoreleasepool
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
    }
}

+ (void)applicationDidFinishLaunching:(NSNotification *)__unused notification
{
    TGPluginHost *host = [self sharedHost];
    [[NSNotificationCenter defaultCenter] addObserver:host selector:@selector(accountsDidChange:) name:TGAccountSwitcherAccountsDidChangeNotification object:nil];
    [host refreshSelectedAccount];
    OGPluginsSetHost(host);
}

+ (TGPluginHost *)sharedHost
{
    static TGPluginHost *host = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        host = [[TGPluginHost alloc] init];
    });
    return host;
}

- (void)accountsDidChange:(NSNotification *)__unused notification
{
    [self refreshSelectedAccount];
    OGPluginHooksNotifyAccountChanged([self selectedAccountIndex]);
}

- (NSInteger)selectedAccountIndex
{
    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *active = [manager activeAccount];
    NSInteger index = 0;
    for (TGAccountRecord *account in [manager accounts])
    {
        if (active != nil && [account.accountId isEqualToString:active.accountId])
            return index;
        index++;
    }
    return 0;
}

- (void)refreshSelectedAccount
{
    OGPluginHooksSetSelectedAccount([self selectedAccountIndex]);
}

- (NSArray *)pluginHostAccounts
{
    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *active = [manager activeAccount];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSInteger index = 0;
    for (TGAccountRecord *account in [manager accounts])
    {
        bool selected = active != nil && [account.accountId isEqualToString:active.accountId];
        [result addObject:@{
            @"index": @(index),
            @"account_id": account.accountId ?: @"",
            @"user_id": @(account.userId),
            @"first_name": account.firstName ?: @"",
            @"last_name": account.lastName ?: @"",
            @"phone": account.phoneNumber ?: @"",
            @"selected": @(selected)
        }];
        index++;
    }
    return result;
}

- (NSDictionary *)pluginHostCachedPeer:(int64_t)dialogId
{
    if (dialogId > 0)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:dialogId];
        if (user == nil)
            return nil;
        return @{ @"kind": @"user", @"id": @(user.uid), @"access_hash": @(user.phoneNumberHash),
                  @"first_name": user.firstName ?: @"", @"last_name": user.lastName ?: @"",
                  @"username": user.userName ?: @"",
                  @"bot": @(user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot) };
    }
    if (dialogId == 0)
        return nil;
    TGConversation *conversation = [TGDatabaseInstance() loadConversationWithIdCached:[TGPluginHost peerIdForDialogId:dialogId]];
    if (conversation == nil)
        return nil;
    return @{ @"kind": conversation.isChannel ? @"channel" : @"chat", @"id": @(-dialogId),
              @"access_hash": @(conversation.accessHash), @"title": conversation.chatTitle ?: @"",
              @"username": conversation.username ?: @"",
              @"joined": @(!conversation.leftChat && !conversation.kickedFromChat && !conversation.isDeactivated &&
                            (!conversation.isChannel || conversation.isChannelMember)),
              @"creator": @(conversation.isCreator), @"members": @(MAX(0, conversation.chatParticipantCount)),
              @"broadcast": @(conversation.isChannel && !conversation.isChannelGroup) };
}

- (NSDictionary *)pluginHostCachedMessage:(int32_t)messageId dialogId:(int64_t)dialogId
{
    int64_t peerId = [TGPluginHost peerIdForDialogId:dialogId];
    TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
    if (message == nil)
        return nil;
    return @{ @"id": @(message.mid), @"text": message.text ?: @"",
              @"from_id": @(message.fromUid), @"peer_id": @(dialogId), @"out": @(message.outgoing) };
}

- (NSArray *)pluginHostCachedDialogsWithLimit:(int32_t)limit folderId:(int32_t)folderId
{
    NSArray *conversations = [TGPluginHost conversationsInFolder:folderId limit:limit];
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:conversations.count];
    for (TGConversation *conversation in conversations)
    {
        int64_t dialogId = [TGPluginHost dialogIdForPeerId:conversation.conversationId];
        [result addObject:@{ @"id": @(dialogId), @"top_message": @(conversation.maxKnownMessageId),
                             @"date": @(conversation.messageDate), @"unread_count": @(conversation.unreadCount),
                             @"unread": @(conversation.unread), @"pinned": @(conversation.pinnedDate != 0),
                             @"archived": @(conversation.isArchived), @"title": conversation.chatTitle ?: @"" }];
    }
    return result;
}

- (id)pluginHostDownload:(NSDictionary *)location toPath:(NSString *)path progress:(void (^)(int64_t, int64_t))progress completion:(void (^)(NSString *, NSString *))completion
{
    return [TGPluginHost downloadFileLocation:location toPath:path progress:progress completion:completion];
}

- (void)pluginHostCancelDownload:(id)token
{
    [TGPluginHost cancelDownload:token];
}

- (id)pluginHostPerformRequest:(NSData *)payload account:(NSInteger)account flags:(NSInteger)flags completion:(void (^)(NSData *response, int32_t errorCode, NSString *errorDescription))completion
{
    void (^finish)(NSData *, int32_t, NSString *) = [completion copy];
    if (account != [self selectedAccountIndex])
    {
        if (finish != nil)
            finish(nil, 400, @"ACCOUNT_NOT_CONNECTED");
        return nil;
    }
    MTRequest *request = [[MTRequest alloc] init];
    TGPluginHostRequestMetadata *metadata = [[TGPluginHostRequestMetadata alloc] initWithFlags:flags];
    [request setPayload:payload metadata:metadata responseParser:^id(NSData *data)
    {
        return data;
    }];
    request.dependsOnPasswordEntry = (flags & (TGPluginHostRequestFlagEnableUnauthorized | TGPluginHostRequestFlagWithoutLogin)) == 0;
    [request setShouldContinueExecutionWithErrorContext:^bool(MTRequestErrorContext *errorContext)
    {
        bool floodWait = errorContext.floodWaitSeconds > 0;
        if (floodWait && (flags & TGPluginHostRequestFlagDoNotWaitFloodWait) != 0)
            return false;
        if ((flags & TGPluginHostRequestFlagFailOnServerErrors) != 0)
            return false;
        if ((flags & TGPluginHostRequestFlagFailOnServerErrorsExceptFloodWait) != 0)
            return floodWait;
        return true;
    }];
    if ((flags & TGPluginHostRequestFlagInvokeAfter) != 0)
    {
        [request setShouldDependOnRequest:^bool(MTRequest *anotherRequest)
        {
            id another = anotherRequest.metadata;
            return [another isKindOfClass:[TGPluginHostRequestMetadata class]] && (((TGPluginHostRequestMetadata *)another).flags & TGPluginHostRequestFlagInvokeAfter) != 0;
        }];
    }
    [request setCompleted:^(id result, __unused NSTimeInterval timestamp, MTRpcError *error)
    {
        if (finish == nil)
            return;
        if (error != nil)
            finish(nil, error.errorCode, error.errorDescription ?: @"UNKNOWN_ERROR");
        else if ([result isKindOfClass:[NSData class]])
            finish(result, 0, nil);
        else
            finish(nil, 500, @"TL_PARSING_ERROR");
    }];
    id internalId = request.internalId;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [[TGTelegramNetworking instance] addRequest:request];
    }];
    return internalId;
}

- (void)pluginHostCancelRequest:(id)token
{
    if (token == nil)
        return;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [[TGTelegramNetworking instance] cancelRpc:token];
    }];
}

+ (int64_t)dialogIdForPeerId:(int64_t)peerId
{
    if (TGPeerIdIsChannel(peerId))
        return -TGChannelIdFromPeerId(peerId);
    if (TGPeerIdIsSecretChat(peerId))
    {
        int64_t encryptedId = [TGDatabaseInstance() encryptedConversationIdForPeerId:peerId];
        return TGPluginHostEncryptedDialogFlag | (encryptedId & 0xffffffffLL);
    }
    return peerId;
}

+ (int64_t)peerIdForDialogId:(int64_t)dialogId
{
    if ((dialogId & TGPluginHostEncryptedDialogFlag) != 0 && dialogId > 0)
    {
        int64_t encryptedId = (int32_t)(dialogId & 0xffffffffLL);
        return [TGDatabaseInstance() peerIdForEncryptedConversationId:encryptedId];
    }
    if (dialogId >= 0)
        return dialogId;
    int64_t identifier = -dialogId;
    int64_t channelPeerId = TGPeerIdFromChannelId(identifier);
    if (channelPeerId != 0 && [TGDatabaseInstance() loadConversationWithIdCached:channelPeerId] != nil)
        return channelPeerId;
    int64_t groupPeerId = TGPeerIdFromGroupId(identifier);
    if (groupPeerId != 0 && [TGDatabaseInstance() loadConversationWithIdCached:groupPeerId] != nil)
        return groupPeerId;
    return channelPeerId != 0 ? channelPeerId : groupPeerId;
}

+ (NSArray *)serializedEntities:(NSArray *)entities
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (id entity in [TGModernSendCommonMessageActor convertEntities:entities])
    {
        NSData *data = [TGTLSerialization serializeMessage:entity];
        if (data.length != 0)
            [result addObject:data];
    }
    return result;
}

+ (NSArray *)entitiesFromSerialized:(NSArray *)serialized
{
    NSMutableArray *objects = [[NSMutableArray alloc] init];
    for (id item in serialized)
    {
        if (![item isKindOfClass:[NSData class]])
            continue;
        id entity = [TGTLSerialization parseObject:item];
        if (entity != nil)
            [objects addObject:entity];
    }
    return [TGMessage parseTelegraphEntities:objects];
}

+ (NSString *)languageCode
{
    return effectiveLocalization().code;
}

+ (NSString *)localizedStringForKey:(NSString *)key
{
    return key.length != 0 ? TGLocalized(key) : nil;
}

+ (bool)applyUpdatesData:(NSData *)data
{
    id updates = data.length != 0 ? [TGTLSerialization parseObject:data] : nil;
    if (![updates isKindOfClass:[TLUpdates class]])
        return false;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [[TGTelegramNetworking instance] addUpdates:updates];
    }];
    return true;
}

+ (NSString *)localPathForDocumentId:(int64_t)documentId version:(int32_t)version fileName:(NSString *)fileName
{
    NSString *directory = [TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:documentId version:version];
    return [directory stringByAppendingPathComponent:[TGDocumentMediaAttachment safeFileNameForFileName:fileName.length != 0 ? fileName : @"file"]];
}

+ (id<TelegramCloudMediaResource>)resourceForLocation:(NSDictionary *)location mediaType:(TGNetworkMediaTypeTag *)mediaType
{
    NSString *kind = location[@"kind"];
    int32_t datacenterId = [location[@"datacenter"] intValue];
    int64_t identifier = [location[@"id"] longLongValue];
    int64_t accessHash = [location[@"access_hash"] longLongValue];
    int64_t size = [location[@"size"] longLongValue];
    NSData *fileReference = [location[@"file_reference"] isKindOfClass:[NSData class]] ? location[@"file_reference"] : nil;
    NSString *thumbSize = [location[@"thumb_size"] isKindOfClass:[NSString class]] ? location[@"thumb_size"] : @"";
    NSNumber *sizeValue = size > 0 ? @(size) : nil;
    if (datacenterId <= 0 || identifier == 0)
        return nil;
    if ([kind isEqualToString:@"document"])
    {
        *mediaType = TGNetworkMediaTypeTagDocument;
        return [[CloudDocumentMediaResource alloc] initWithDatacenterId:datacenterId fileId:identifier accessHash:accessHash fileReference:fileReference thumbSize:thumbSize size:sizeValue mediaType:@(TGNetworkMediaTypeTagDocument) originInfo:nil identifier:identifier];
    }
    if ([kind isEqualToString:@"photo"])
    {
        *mediaType = TGNetworkMediaTypeTagImage;
        return [[CloudPhotoMediaResource alloc] initWithDatacenterId:datacenterId fileId:identifier accessHash:accessHash fileReference:fileReference thumbSize:thumbSize size:sizeValue mediaType:@(TGNetworkMediaTypeTagImage) originInfo:nil identifier:identifier];
    }
    return nil;
}

+ (id)downloadFileLocation:(NSDictionary *)location toPath:(NSString *)path progress:(void (^)(int64_t loaded, int64_t total))progress completion:(void (^)(NSString *path, NSString *error))completion
{
    void (^report)(int64_t, int64_t) = [progress copy];
    void (^finish)(NSString *, NSString *) = [completion copy];
    TGNetworkMediaTypeTag mediaType = TGNetworkMediaTypeTagGeneric;
    id<TelegramCloudMediaResource> resource = [location isKindOfClass:[NSDictionary class]] ? [self resourceForLocation:location mediaType:&mediaType] : nil;
    if (resource == nil || path.length == 0)
    {
        if (finish != nil)
            finish(nil, @"INVALID_LOCATION");
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *partialPath = [path stringByAppendingPathExtension:@"part"];
    [fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:NULL];
    [fileManager removeItemAtPath:partialPath error:NULL];
    NSFileHandle *handle = [fileManager createFileAtPath:partialPath contents:nil attributes:nil] ? [NSFileHandle fileHandleForWritingAtPath:partialPath] : nil;
    if (handle == nil)
    {
        if (finish != nil)
            finish(nil, @"FILE_CREATE_FAILED");
        return nil;
    }
    int64_t total = [location[@"size"] longLongValue];
    TGPluginHostDownload *download = [[TGPluginHostDownload alloc] initWithPath:path partialPath:partialPath handle:handle];
    __block int64_t loaded = 0;
    id<SDisposable> disposable = [multipartFetch(resource, total > 0 ? @(total) : nil, NSMakeRange(0, INT32_MAX), mediaType) startWithNext:^(MediaResourceDataFetchResult *next)
    {
        if (next.data.length == 0 || ![download appendData:next.data])
            return;
        loaded += (int64_t)next.data.length;
        if (report != nil)
            report(loaded, total > 0 ? total : loaded);
    } error:^(__unused id error)
    {
        [download fail];
        if (finish != nil)
            finish(nil, @"DOWNLOAD_FAILED");
    } completed:^
    {
        NSString *errorText = nil;
        if ([download finishWithError:&errorText])
        {
            if (finish != nil)
                finish(path, nil);
        }
        else if (errorText != nil && finish != nil)
            finish(nil, errorText);
    }];
    [download attachDisposable:disposable];
    return download;
}

+ (void)cancelDownload:(id)download
{
    if ([download isKindOfClass:[TGPluginHostDownload class]])
        [(TGPluginHostDownload *)download cancel];
}

+ (TGMusicPlayer *)musicPlayer
{
    return TGTelegraphInstance.musicPlayer;
}

+ (bool)switchToAccountIndex:(NSInteger)index
{
    TGAccountManager *manager = [TGAccountManager instance];
    NSArray *accounts = [manager accounts];
    if (index < 0 || index >= (NSInteger)accounts.count)
        return false;
    TGAccountRecord *account = accounts[(NSUInteger)index];
    TGAccountRecord *active = [manager activeAccount];
    if (active != nil && [active.accountId isEqualToString:account.accountId])
        return true;
    bool authorized = false;
    for (TGAccountRecord *candidate in [manager authorizedAccounts])
    {
        if ([candidate.accountId isEqualToString:account.accountId])
        {
            authorized = true;
            break;
        }
    }
    TGAccountSwitcher *switcher = [TGAccountSwitcher instance];
    if (!authorized || [switcher isSwitching])
        return false;
    [switcher switchToAccount:account];
    return true;
}

+ (NSArray *)conversationsInFolder:(int32_t)folderId limit:(int32_t)limit
{
    __block NSArray *conversations = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [TGDatabaseInstance() loadConversationListFromDate:INT32_MAX limit:limit excludeConversationIds:nil folderId:folderId completion:^(NSArray *result, __unused bool loadedAllRegular)
    {
        conversations = result;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semaphore);
#endif
    NSMutableArray *filtered = [[NSMutableArray alloc] init];
    for (id conversation in conversations)
    {
        if ([conversation isKindOfClass:[TGConversation class]])
            [filtered addObject:conversation];
    }
    return filtered;
}

+ (NSString *)presentationKind
{
    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    if ([pallete isKindOfClass:[TGNightBluePresentationPallete class]])
        return @"nightBlue";
    if ([pallete isKindOfClass:[TGNightPresentationPallete class]])
        return @"night";
    if ([pallete isKindOfClass:[TGDayPresentationPallete class]])
        return @"day";
    if ([pallete isMemberOfClass:[TGDefaultPresentationPallete class]])
        return @"default";
    return pallete.isDark ? @"customDark" : @"custom";
}

+ (bool)applyPresentationKind:(NSString *)kind
{
    TGPresentationPallete *pallete = nil;
    if ([kind isEqualToString:@"nightBlue"])
        pallete = [[TGNightBluePresentationPallete alloc] init];
    else if ([kind isEqualToString:@"night"])
        pallete = [[TGNightPresentationPallete alloc] init];
    else if ([kind isEqualToString:@"day"])
        pallete = [[TGDayPresentationPallete alloc] init];
    else if ([kind isEqualToString:@"default"])
        pallete = [[TGDefaultPresentationPallete alloc] init];
    if (pallete == nil)
        return false;
    TGDispatchOnMainThread(^
    {
        [TGCloudTheme resetInstalledTheme];
        [TGPresentation switchToPallete:pallete];
    });
    return true;
}

+ (UIImage *)currentWallpaperImage
{
    return [[TGWallpaperManager instance] currentWallpaperImage];
}

+ (int32_t)notificationsMuteUntilForPeerId:(int64_t)peerId
{
    __autoreleasing NSNumber *muteUntil = nil;
    bool notFound = false;
    [TGDatabaseInstance() loadPeerNotificationSettings:peerId soundId:NULL muteUntil:&muteUntil previewText:NULL messagesMuted:NULL notFound:&notFound];
    if (notFound || muteUntil == nil)
        return -1;
    return [muteUntil intValue];
}

+ (int64_t)notificationDefaultsPeerIdForPeerId:(int64_t)peerId
{
    if (TGPeerIdIsChannel(peerId))
    {
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithIdCached:peerId];
        return conversation.isChannelGroup ? TGPeerIdNotificationDefaultsGroup : TGPeerIdNotificationDefaultsChannel;
    }
    if (TGPeerIdIsGroup(peerId))
        return TGPeerIdNotificationDefaultsGroup;
    return TGPeerIdNotificationDefaultsPrivate;
}

+ (int64_t)notificationDefaultsPeerIdForType:(int32_t)type
{
    switch (type)
    {
        case 0:
            return TGPeerIdNotificationDefaultsGroup;
        case 2:
            return TGPeerIdNotificationDefaultsChannel;
        default:
            return TGPeerIdNotificationDefaultsPrivate;
    }
}

+ (void)refreshNotifications
{
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        [TGDatabaseInstance() transactionCalculateUnreadChats];
        int unreadChatsCount = [TGDatabaseInstance() unreadChatsCount];
        int unreadChannelsCount = [TGDatabaseInstance() unreadChannelsCount];
        if (unreadChatsCount == INT_MIN || unreadChannelsCount == INT_MIN)
            return;
        int unreadCount = MAX(0, unreadChatsCount) + MAX(0, unreadChannelsCount);
        dispatch_async(dispatch_get_main_queue(), ^
        {
            UIApplication *application = [UIApplication sharedApplication];
            [application setApplicationIconBadgeNumber:unreadCount];
            if (unreadCount == 0)
                OGPlatformCancelAllLocalNotifications(application);
        });
    } synchronous:false];
}

+ (bool)isSendingMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    if (messageId < TGMessageLocalMidBaseline)
        return false;
    TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
    return message != nil && message.deliveryState == TGMessageDeliveryStatePending;
}

+ (bool)cancelSendingMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    if (![self isSendingMessageId:messageId peerId:peerId])
        return false;
    static volatile int32_t sequence = 0;
    int32_t identifier = __sync_add_and_fetch(&sequence, 1);
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/deleteMessages/(plugin%d)", peerId, identifier] options:@{@"mids": @[@(messageId)], @"forEveryone": @true} watcher:TGTelegraphInstance];
    return true;
}

+ (TGViewController *)presentingController
{
    UIViewController *controller = TGAppDelegateInstance.rootController;
    UIViewController *presented = TGPluginHostPresentedController(controller);
    while (presented != nil)
    {
        controller = presented;
        presented = TGPluginHostPresentedController(controller);
    }
    if ([controller isKindOfClass:[UINavigationController class]])
        controller = ((UINavigationController *)controller).topViewController;
    if ([controller isKindOfClass:[TGViewController class]])
        return (TGViewController *)controller;
    return TGAppDelegateInstance.rootController;
}

+ (bool)presentShareWithText:(NSString *)text paths:(NSArray *)paths completion:(void (^)(NSArray *peerIds, NSString *comment))completion
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    if (text.length != 0)
        [items addObject:text];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (id path in paths)
    {
        if ([path isKindOfClass:[NSString class]] && [fileManager fileExistsAtPath:path])
            [items addObject:[NSURL fileURLWithPath:path]];
    }
    TGViewController *parentController = [self presentingController];
    if (items.count == 0 || parentController == nil)
        return false;
    void (^chosen)(NSArray *, NSString *) = [completion copy];
    UIView *sourceView = parentController.view;
    [TGShareMenu presentInParentController:parentController menuController:nil buttonTitle:nil buttonAction:nil shareAction:^(NSArray *peerIds, NSString *caption)
    {
        if (chosen != nil && peerIds.count != 0)
            chosen(peerIds, caption);
    } externalShareItemSignal:[SSignal single:items.count == 1 ? items[0] : items] sourceView:sourceView sourceRect:^CGRect
    {
        CGSize size = sourceView.bounds.size;
        return CGRectMake(CGFloor(size.width / 2.0f), CGFloor(size.height / 2.0f), 1.0f, 1.0f);
    } barButtonItem:nil];
    return true;
}

+ (void)resolveLink:(NSURL *)url completion:(void (^)(NSURL *resolved))completion
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{ [self resolveLink:url completion:completion]; });
        return;
    }
    if (url == nil || (!OGPluginUIWants(OGPluginUIInterestBrowser) && !OGPluginHooksWantsLinks()))
    {
        completion(url);
        return;
    }
    __block bool finished = false;
    void (^finish)(NSURL *) = ^(NSURL *resolved)
    {
        if (finished)
            return;
        finished = true;
        completion(resolved);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish(url); });
    OGPluginUIBrowserLinkAsync(url.absoluteString, ^(NSDictionary *outcome)
    {
        if (finished)
            return;
        if ([outcome[@"cancelled"] boolValue])
        {
            finish(nil);
            return;
        }
        NSString *replacement = outcome[@"url"];
        NSURL *resolved = [replacement isKindOfClass:[NSString class]] ? [NSURL URLWithString:replacement] : nil;
        resolved = resolved ?: url;
        OGPluginHooksProcessOpenLinkAsync(resolved.absoluteString, OGPluginLinkPhaseBefore, ^(bool handled)
        {
            finish(handled ? nil : resolved);
        });
    });
}

+ (void)completeLink:(NSURL *)url
{
    OGPluginHooksProcessOpenLinkAsync(url.absoluteString, OGPluginLinkPhaseAfter, nil);
}

+ (bool)openDocumentAtPath:(NSString *)path attachment:(TGDocumentMediaAttachment *)attachment peerId:(int64_t)peerId messageId:(int32_t)messageId place:(NSString *)place
{
    NSString *fileName = attachment.fileName.length != 0 ? attachment.fileName : [path lastPathComponent];
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path])
        return false;
    if ([TGPluginsController isPluginArchivePath:path fileName:fileName])
    {
        [TGPluginsController presentInstallPromptForPath:path fileName:fileName];
        return true;
    }
    if (!OGPluginHooksWantsDocument(fileName))
        return false;
    return OGPluginHooksProcessOpenDocument(OGPluginHooksSelectedAccount(), place, path, fileName, peerId, messageId);
}

+ (bool)hasMenuItemsOfType:(NSString *)menuType
{
    return OGPluginHooksWantsMenu(menuType);
}

+ (bool)isMenuChangeNotification:(NSNotification *)notification
{
    NSString *name = notification.userInfo[OGPluginsEventNameKey];
    return [name isEqualToString:@"menus"] || [name isEqualToString:@"changed"] || [name isEqualToString:@"ready"] || [name isEqualToString:@"menu_snapshot"];
}

+ (NSDictionary *)menuContextWithController:(UIViewController *)controller peerId:(int64_t)peerId messageId:(int32_t)messageId groupedMessageIds:(NSArray *)groupedMessageIds
{
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
    context[@"account"] = @(OGPluginHooksSelectedAccount());
    if (controller != nil)
        context[@"controller"] = controller;
    if (peerId != 0)
        context[@"peer_id"] = @(peerId);
    if (messageId != 0)
        context[@"message_id"] = @(messageId);
    if (groupedMessageIds.count != 0)
        context[@"grouped_ids"] = groupedMessageIds;
    return context;
}

+ (NSArray *)menuItemsOfType:(NSString *)menuType context:(NSDictionary *)context
{
    return OGPluginHooksMenuItems(menuType, context);
}

+ (bool)performMenuItem:(NSDictionary *)item ofType:(NSString *)menuType context:(NSDictionary *)context
{
    return OGPluginHooksPerformMenuItem(menuType, item[@"plugin"], item[@"id"], context);
}

+ (void)processOutgoingText:(NSString *)text entities:(NSArray *)entities peerId:(int64_t)peerId replyMessageId:(int32_t)replyMessageId disableLinkPreviews:(bool)disableLinkPreviews completion:(void (^)(NSString *, NSArray *, int32_t, bool, bool))completion
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{ [self processOutgoingText:text entities:entities peerId:peerId replyMessageId:replyMessageId disableLinkPreviews:disableLinkPreviews completion:completion]; });
        return;
    }
    if ((!OGPluginHooksWantsKind(OGPluginHookKindSendMessage) && !OGPluginUIWants(OGPluginUIInterestSendMessages)) || text.length == 0)
    {
        completion(text, entities, replyMessageId, disableLinkPreviews, false);
        return;
    }
    if (entities == nil)
    {
        NSString *resultingText = text;
        entities = [TGMessage entitiesForMarkedUpText:text resultingText:&resultingText] ?: @[];
        text = resultingText;
    }
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"kind"] = @"text";
    parameters[@"peer"] = @([self dialogIdForPeerId:peerId]);
    parameters[@"message"] = text;
    parameters[@"entities"] = [self serializedEntities:entities];
    parameters[@"reply_to_msg_id"] = @(replyMessageId);
    parameters[@"search_links"] = @(!disableLinkPreviews);
    NSInteger account = OGPluginHooksSelectedAccount();
    NSString *key = [NSString stringWithFormat:@"%ld:%lld", (long)account, (long long)peerId];
    if (TGPluginHostPendingSends == nil)
        TGPluginHostPendingSends = [[NSMutableDictionary alloc] init];
    NSMutableArray *queue = TGPluginHostPendingSends[key];
    if (queue == nil)
    {
        queue = [[NSMutableArray alloc] init];
        TGPluginHostPendingSends[key] = queue;
    }
    NSString *originalText = text;
    NSArray *originalEntities = entities;
    void (^work)(void) = ^
    {
        __block bool finished = false;
        void (^finish)(OGPluginHookOutcome *) = ^(OGPluginHookOutcome *outcome)
        {
            if (finished)
                return;
            finished = true;
            NSString *resultText = originalText;
            NSArray *resultEntities = originalEntities;
            int32_t resultReply = replyMessageId;
            bool resultPreviews = disableLinkPreviews;
            bool cancelled = outcome.action == OGPluginHookActionCancel;
            if (outcome.action == OGPluginHookActionReplace && outcome.parameters != nil)
            {
                NSDictionary *result = outcome.parameters;
                resultText = [result[@"message"] isKindOfClass:[NSString class]] ? result[@"message"] : @"";
                if ([result[@"entities"] isKindOfClass:[NSArray class]])
                    resultEntities = [self entitiesFromSerialized:result[@"entities"]];
                if ([result[@"reply_to_msg_id"] respondsToSelector:@selector(intValue)])
                    resultReply = [result[@"reply_to_msg_id"] intValue];
                if ([result[@"search_links"] respondsToSelector:@selector(boolValue)])
                    resultPreviews = ![result[@"search_links"] boolValue];
            }
            completion(resultText, resultEntities, resultReply, resultPreviews, cancelled);
            [queue removeObjectAtIndex:0];
            if (queue.count != 0)
            {
                void (^next)(void) = queue[0];
                next();
            }
            else
                [TGPluginHostPendingSends removeObjectForKey:key];
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ finish([OGPluginHookOutcome continueOutcome]); });
        OGPluginHooksProcessSendMessageAsync(account, parameters, finish);
    };
    [queue addObject:[work copy]];
    if (queue.count == 1)
        work();
}

@end

#endif
