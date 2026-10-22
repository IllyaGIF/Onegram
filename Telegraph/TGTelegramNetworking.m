#import "TGTelegramNetworking.h"

#import <unistd.h>
#import <notify.h>
#import <Security/Security.h>
#import <sys/socket.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <sys/time.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"
#import "../OnegramPlatform/OGPlatformVersion.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../OnegramPushHelper/OGPushHelperProtocol.h"

#if !TGUseModernNetworking
#import "TGSession.h"
#endif

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

static NSDictionary *TGShareProtectionQuery(int32_t userId)
{
    return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: @"Onegram.Core.ShareProtection", (__bridge id)kSecAttrAccount: [NSString stringWithFormat:@"%d", userId]};
}

static NSDictionary *TGShareReadProtection(int32_t userId, NSData *fingerprint)
{
    NSMutableDictionary *query = [TGShareProtectionQuery(userId) mutableCopy];
    query[(__bridge id)kSecReturnData] = [NSNumber numberWithBool:YES];
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSData *data = (__bridge_transfer NSData *)result;
    if (status != errSecSuccess || ![data isKindOfClass:[NSData class]]) return nil;
    NSString *error = nil;
    id value = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error];
    if (![value isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *record = value;
    if (![record[@"fingerprint"] isEqual:fingerprint] || ![record[@"key"] isKindOfClass:[NSData class]] || [record[@"key"] length] != 32 || ![record[@"salt"] isKindOfClass:[NSData class]] || [record[@"salt"] length] != 32 || ![record[@"rounds"] isKindOfClass:[NSNumber class]] || [record[@"rounds"] intValue] < 10000 || [record[@"rounds"] intValue] > 2000000) return nil;
    return record;
}

static bool TGShareWriteProtection(int32_t userId, NSDictionary *record)
{
    NSString *error = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:record format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
    if (data == nil) return false;
    NSDictionary *query = TGShareProtectionQuery(userId);
    NSMutableDictionary *attributes = [@{(__bridge id)kSecValueData: data} mutableCopy];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    attributes[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
#endif
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound)
    {
        [attributes addEntriesFromDictionary:query];
        status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    }
    return status == errSecSuccess;
}

static bool sTGIOS6QRLoginFlowActive = false;
static const NSInteger TGOnegramTransportCacheVersion = 1;

void TGIOS6SetQRLoginFlowActive(bool active)
{
    sTGIOS6QRLoginFlowActive = active;
}

bool TGIOS6QRLoginFlowActive(void)
{
    return sTGIOS6QRLoginFlowActive;
}
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGTelegraph.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTLogging.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTKeychain.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTApiEnvironment.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddressSet.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddress.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTTransportScheme.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTProto.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestMessageService.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestErrorContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAuthInfo.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTTcpConnection.h"
#import "TGUpdateMessageService.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTInternalId.h"

#import <CommonCrypto/CommonKeyDerivation.h>

#ifndef kCCSuccess
#define kCCSuccess 0
#endif

#import "TGNetworkWorker.h"
#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

static bool TGIos6IsHexString(NSString *string)
{
    if (![string isKindOfClass:[NSString class]] || string.length == 0 || string.length % 2 != 0)
        return false;
    
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    return [string rangeOfCharacterFromSet:[hexSet invertedSet]].location == NSNotFound;
}

static MTSocksProxySettings *TGOnegramStoredProxySettings(void)
{
    NSData *data = [TGDatabaseInstance() customProperty:@"socksProxyData"];
    if (data == nil || data.length == 0)
        return nil;

    NSDictionary *dict = nil;
    @try
    {
        dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (__unused NSException *exception)
    {
        return nil;
    }

    if (![dict isKindOfClass:[NSDictionary class]] || [dict[@"inactive"] boolValue])
        return nil;
    NSString *ip = dict[@"ip"];
    NSNumber *port = dict[@"port"];
    if (![ip isKindOfClass:[NSString class]] || ip.length == 0 || ![port isKindOfClass:[NSNumber class]] || [port intValue] <= 0)
        return nil;

    NSString *secretString = dict[@"secret"];
    NSData *secret = TGIos6IsHexString(secretString) ? [NSData dataWithHexString:secretString] : nil;
    return [[MTSocksProxySettings alloc] initWithIp:ip port:(uint16_t)[port intValue] username:dict[@"username"] password:dict[@"password"] secret:secret];
}

static bool TGIOS6NtpUnixTime(const char *host, NSTimeInterval *unixTime)
{
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    struct addrinfo *addresses = NULL;
    if (getaddrinfo(host, "123", &hints, &addresses) != 0 || addresses == NULL)
        return false;

    bool success = false;
    int attempts = 0;
    for (struct addrinfo *address = addresses; address != NULL && !success && attempts < 2; address = address->ai_next, attempts++)
    {
        int socketFd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (socketFd < 0)
            continue;

        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        uint8_t packet[48];
        memset(packet, 0, sizeof(packet));
        packet[0] = 0x1b;

        CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
        ssize_t sent = sendto(socketFd, packet, sizeof(packet), 0, address->ai_addr, address->ai_addrlen);
        ssize_t received = -1;
        if (sent == sizeof(packet))
            received = recvfrom(socketFd, packet, sizeof(packet), 0, NULL, NULL);
        CFAbsoluteTime finished = CFAbsoluteTimeGetCurrent();

        if (received >= 48)
        {
            uint8_t mode = packet[0] & 7;
            uint8_t stratum = packet[1];
            uint32_t seconds = 0;
            uint32_t fraction = 0;
            memcpy(&seconds, packet + 40, 4);
            memcpy(&fraction, packet + 44, 4);
            seconds = ntohl(seconds);
            fraction = ntohl(fraction);

            if ((mode == 4 || mode == 5) && stratum != 0 && seconds > 2208988800U)
            {
                NSTimeInterval value = (NSTimeInterval)seconds - 2208988800.0;
                value += (NSTimeInterval)fraction / 4294967296.0;
                value += MAX(0.0, finished - started) * 0.5;
                if (value > 1262304000.0)
                {
                    if (unixTime != NULL)
                        *unixTime = value;
                    success = true;
                }
            }
        }

        close(socketFd);
    }

    freeaddrinfo(addresses);
    return success;
}

static bool TGIOS6HttpUnixTime(NSString *urlString, NSTimeInterval *unixTime)
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil)
        return false;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
    [request setHTTPMethod:@"GET"];

    NSURLResponse *response = nil;
    NSError *error = nil;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error != nil || ![response isKindOfClass:[NSHTTPURLResponse class]])
        return false;

    NSString *dateString = nil;
    NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
    for (id key in headers)
    {
        if ([[key description] caseInsensitiveCompare:@"Date"] == NSOrderedSame)
        {
            dateString = [headers[key] description];
            break;
        }
    }
    if (dateString.length == 0)
        return false;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
    NSDate *date = [formatter dateFromString:dateString];
    if (date == nil)
        return false;

    NSTimeInterval value = [date timeIntervalSince1970];
    if (value <= 1262304000.0)
        return false;

    if (unixTime != NULL)
        *unixTime = value;
    return true;
}

static bool TGIOS6FetchNetworkUnixTime(NSTimeInterval *unixTime)
{
    const char *hosts[] = { "time.apple.com", "time.google.com" };
    NSTimeInterval value = 0.0;
    for (NSUInteger i = 0; i < sizeof(hosts) / sizeof(hosts[0]); i++)
    {
        if (TGIOS6NtpUnixTime(hosts[i], &value))
        {
            if (unixTime != NULL)
                *unixTime = value;
            return true;
        }
    }

    NSArray *urls = @[ @"http://captive.apple.com/hotspot-detect.html" ];
    for (NSString *urlString in urls)
    {
        if (TGIOS6HttpUnixTime(urlString, &value))
        {
            if (unixTime != NULL)
                *unixTime = value;
            return true;
        }
    }

    return false;
}

#import "TGTLSerialization.h"
#import "TGKeychainImport.h"

#import "TGLoginPasswordController.h"

#import "TLUpdates+TG.h"

#import "TLRPCmessages_sendMessage_manual.h"
#import "TLRPCmessages_sendMedia_manual.h"
#import "TLRPCmessages_sendInlineBotResult.h"
#import "TLRPCmessages_forwardMessages.h"

#import "TLRPCauth_sendCode.h"
#import "TLRPChelp_test.h"

#import "TLInputChannel.h"
#import "TLInputPeer.h"
#import "TLInputUser.h"
#import "TLRPCchannels_getFullChannel.h"
#import "TLRPCchannels_getMessages.h"
#import "TLRPCchannels_getParticipant.h"
#import "TLRPCmessages_getHistory.h"
#import "TLRPCupdates_getChannelDifference.h"

#import "../config.h"

#import "TGAccountSignals.h"

#import "TGInterfaceManager.h"

#import "TGICloudEmergencyDataSignals.h"

#import "TGNetworkSettings.h"

static int TGMaxWorkerCount(void)
{
    return cpuCoreCount() > 1 ? 4 : 2;
}

static void TGIOS6NormalizeInputChannelForModernApi(TLInputChannel *channel, NSString *context)
{
    if ([channel isKindOfClass:[TLInputChannel$inputChannel class]])
    {
        TLInputChannel$inputChannel *inputChannel = (TLInputChannel$inputChannel *)channel;
        if (inputChannel.channel_id < 0 && inputChannel.channel_id >= INT32_MIN)
        {
            int64_t oldChannelId = inputChannel.channel_id;
            inputChannel.channel_id = (int64_t)(uint32_t)((int32_t)inputChannel.channel_id);
            TGLog(@"AUTH normalize inputChannel %@ raw=%lld id=%lld hash=%lld", context, oldChannelId, inputChannel.channel_id, inputChannel.access_hash);
        }
    }
}

static void TGIOS6NormalizeRpcForModernApi(TLMetaRpc *rpc)
{
    if ([rpc isKindOfClass:[TLRPCupdates_getChannelDifference class]])
        TGIOS6NormalizeInputChannelForModernApi(((TLRPCupdates_getChannelDifference *)rpc).channel, @"updates.getChannelDifference");
    else if ([rpc isKindOfClass:[TLRPCchannels_getFullChannel class]])
        TGIOS6NormalizeInputChannelForModernApi(((TLRPCchannels_getFullChannel *)rpc).channel, @"channels.getFullChannel");
    else if ([rpc isKindOfClass:[TLRPCchannels_getMessages class]])
        TGIOS6NormalizeInputChannelForModernApi(((TLRPCchannels_getMessages *)rpc).channel, @"channels.getMessages");
    else if ([rpc isKindOfClass:[TLRPCchannels_getParticipant class]])
        TGIOS6NormalizeInputChannelForModernApi(((TLRPCchannels_getParticipant *)rpc).channel, @"channels.getParticipant");
}

static NSString *TGIOS6DescribeInputChannel(TLInputChannel *channel)
{
    if ([channel isKindOfClass:[TLInputChannel$inputChannel class]])
    {
        TLInputChannel$inputChannel *inputChannel = (TLInputChannel$inputChannel *)channel;
        return [[NSString alloc] initWithFormat:@"inputChannel id=%lld accessHash=%lld", inputChannel.channel_id, inputChannel.access_hash];
    }
    
    return [[NSString alloc] initWithFormat:@"%@", channel];
}

static NSString *TGIOS6DescribeInputPeer(TLInputPeer *peer)
{
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
    {
        TLInputPeer$inputPeerChannel *inputPeer = (TLInputPeer$inputPeerChannel *)peer;
        return [[NSString alloc] initWithFormat:@"inputPeerChannel id=%lld accessHash=%lld", inputPeer.channel_id, inputPeer.access_hash];
    }
    else if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]])
    {
        TLInputPeer$inputPeerUser *inputPeer = (TLInputPeer$inputPeerUser *)peer;
        return [[NSString alloc] initWithFormat:@"inputPeerUser id=%lld accessHash=%lld", inputPeer.user_id, inputPeer.access_hash];
    }
    else if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]])
    {
        return [[NSString alloc] initWithFormat:@"inputPeerChat id=%lld", ((TLInputPeer$inputPeerChat *)peer).chat_id];
    }
    
    return [[NSString alloc] initWithFormat:@"%@", peer];
}

static NSString *TGIOS6DescribeRpcForError(TLMetaRpc *rpc)
{
    if ([rpc isKindOfClass:[TLRPCchannels_getFullChannel class]])
        return [[NSString alloc] initWithFormat:@"channels.getFullChannel %@", TGIOS6DescribeInputChannel(((TLRPCchannels_getFullChannel *)rpc).channel)];
    else if ([rpc isKindOfClass:[TLRPCchannels_getParticipant class]])
    {
        TLRPCchannels_getParticipant *getParticipant = (TLRPCchannels_getParticipant *)rpc;
        return [[NSString alloc] initWithFormat:@"channels.getParticipant %@ %@", TGIOS6DescribeInputChannel(getParticipant.channel), TGIOS6DescribeInputPeer(getParticipant.participant)];
    }
    else if ([rpc isKindOfClass:[TLRPCchannels_getMessages class]])
    {
        TLRPCchannels_getMessages *getMessages = (TLRPCchannels_getMessages *)rpc;
        return [[NSString alloc] initWithFormat:@"channels.getMessages %@ ids=%@", TGIOS6DescribeInputChannel(getMessages.channel), getMessages.n_id];
    }
    else if ([rpc isKindOfClass:[TLRPCupdates_getChannelDifference class]])
    {
        TLRPCupdates_getChannelDifference *getDifference = (TLRPCupdates_getChannelDifference *)rpc;
        return [[NSString alloc] initWithFormat:@"updates.getChannelDifference %@ pts=%d limit=%d", TGIOS6DescribeInputChannel(getDifference.channel), getDifference.pts, getDifference.limit];
    }
    else if ([rpc isKindOfClass:[TLRPCmessages_getHistory class]])
    {
        TLRPCmessages_getHistory *getHistory = (TLRPCmessages_getHistory *)rpc;
        return [[NSString alloc] initWithFormat:@"messages.getHistory %@ offset=%d add=%d limit=%d max=%d min=%d hash=%lld", TGIOS6DescribeInputPeer(getHistory.peer), getHistory.offset_id, getHistory.add_offset, getHistory.limit, getHistory.max_id, getHistory.min_id, getHistory.n_hash];
    }
    
    return [[NSString alloc] initWithFormat:@"%@", [rpc class]];
}

MTInternalIdClass(TGDownloadWorker)

@implementation MTRequest (LegacyTL)

- (void)setBody:(TLMetaRpc *)body
{
    [self setPayload:[TGTLSerialization serializeMessage:body] metadata:body responseParser:^id(NSData *data)
    {
        return [TGTLSerialization parseResponse:data request:body];
    }];
}

- (id)body
{
    return self.metadata;
}

@end

static int TGMaxUploadWorkerCount(void)
{
    return 2;
}

@interface TGUploadWorkerRequest : NSObject

@property (nonatomic, strong) id token;
@property (nonatomic, strong) MTContext *context;
@property (nonatomic) NSInteger datacenterId;
@property (nonatomic) NSInteger masterDatacenterId;
@property (nonatomic) TGNetworkMediaTypeTag type;
@property (nonatomic, copy) void (^completion)(TGNetworkWorkerGuard *);

@end

@implementation TGUploadWorkerRequest

@end

@interface TGUploadWorkerPool : NSObject <TGNetworkWorkerDelegate>
{
    ASQueue *_queue;
    MTQueue *_networkQueue;
    NSMutableDictionary *_workersByDatacenterId;
    NSMutableArray *_pendingRequests;
}

- (instancetype)initWithNetworkQueue:(MTQueue *)networkQueue;
- (void)enqueueRequest:(TGUploadWorkerRequest *)request;
- (void)cancelRequestByToken:(id)token;
- (void)shutdown;

@end

@implementation TGUploadWorkerPool

- (instancetype)initWithNetworkQueue:(MTQueue *)networkQueue
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[ASQueue alloc] initWithName:"org.telegram.uploadWorkerPool"];
        dispatch_set_target_queue(_queue.nativeQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _networkQueue = networkQueue;
        _workersByDatacenterId = [[NSMutableDictionary alloc] init];
        _pendingRequests = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)enqueueRequest:(TGUploadWorkerRequest *)request
{
    [_queue dispatchOnQueue:^
    {
        [_pendingRequests addObject:request];
        [self processPendingRequests];
    }];
}

- (void)cancelRequestByToken:(id)token
{
    [_queue dispatchOnQueue:^
    {
        NSUInteger index = 0;
        for (TGUploadWorkerRequest *request in _pendingRequests)
        {
            if ([request.token isEqual:token])
            {
                [_pendingRequests removeObjectAtIndex:index];
                break;
            }
            index++;
        }
    }];
}

- (void)shutdown
{
    [_queue dispatchOnQueue:^
    {
        [_pendingRequests removeAllObjects];
        for (NSArray *workers in [_workersByDatacenterId allValues])
        {
            for (TGNetworkWorker *worker in workers)
            {
                [worker shutdown];
            }
        }
        [_workersByDatacenterId removeAllObjects];
    } synchronous:true];
}

- (TGNetworkWorker *)availableWorkerForRequest:(TGUploadWorkerRequest *)request
{
    NSNumber *datacenterKey = @(request.datacenterId);
    NSMutableArray *workers = _workersByDatacenterId[datacenterKey];
    if (workers == nil)
    {
        workers = [[NSMutableArray alloc] init];
        _workersByDatacenterId[datacenterKey] = workers;
    }

    for (TGNetworkWorker *worker in workers)
    {
        if (!worker.isBusy)
            return worker;
    }

    if ((int)workers.count >= TGMaxUploadWorkerCount())
        return nil;

    TGNetworkWorker *worker = [[TGNetworkWorker alloc] initWithContext:request.context datacenterId:request.datacenterId masterDatacenterId:request.masterDatacenterId isCdn:false networkQueue:_networkQueue stateQueue:_queue];
    worker.delegate = self;
    [workers addObject:worker];
    return worker;
}

- (void)processPendingRequests
{
    NSUInteger index = 0;
    while (index < _pendingRequests.count)
    {
        TGUploadWorkerRequest *request = _pendingRequests[index];
        TGNetworkWorker *worker = [self availableWorkerForRequest:request];
        if (worker == nil)
        {
            index++;
            continue;
        }

        [_pendingRequests removeObjectAtIndex:index];
        [worker setIsBusy:true];
        [worker setUsageCalculationInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:request.type]];
        request.completion([[TGNetworkWorkerGuard alloc] initWithWorker:worker]);
    }
}

- (void)networkWorkerDidBecomeAvailable:(TGNetworkWorker *)__unused networkWorker
{
    [_queue dispatchOnQueue:^
    {
        [self processPendingRequests];
    }];
}

- (void)networkWorkerReadyToBeRemoved:(TGNetworkWorker *)networkWorker
{
    [_queue dispatchOnQueue:^
    {
        NSMutableArray *workers = _workersByDatacenterId[@(networkWorker.datacenterId)];
        if ([workers containsObject:networkWorker] && !networkWorker.isBusy)
        {
            networkWorker.delegate = nil;
            [workers removeObject:networkWorker];
        }
    }];
}

@end

@interface TGTelegramNetworking () <ASWatcher, MTProtoDelegate, MTRequestMessageServiceDelegate, TGNetworkWorkerDelegate, MTContextChangeListener>
{
    bool _isTestingEnvironment;
    id<MTKeychain> _settingsKeychain;
    id<MTKeychain> _keychain;
    MTContext *_context;
    MTProto *_mtProto;
    MTRequestMessageService *_requestService;
    TGUpdateMessageService *_updateService;
    NSInteger _masterDatacenterId;
    
    NSMutableArray *_postponedRequests;
    
    bool _isNetworkAvailable;
    bool _isConnected;
    bool _isUsingProxy;
    bool _proxyHasConnectionIssues;
    bool _isUpdatingConnectionContext;
    bool _isPerformingServiceTasks;
    int _serviceTasksWatchdogToken;
    
    bool _isPerformingGetDifference;
    
    int _dispatchNetworkStateToken;
    
    int _completeWakeUpToken;
    
    NSMutableDictionary *_workersByDatacenterId;
    NSMutableDictionary *_awaitingWorkerTokensByDatacenterId;
    MTQueue *_mediaNetworkQueue;
    MTQueue *_transferNetworkQueue;
    TGUploadWorkerPool *_uploadWorkerPool;
    NSMutableDictionary *_cdnDatas;
    
    NSMutableArray *_currentWakeUpCompletions;
    
    UIWindow *_currentPasswordEntryWindow;
    
    SMetaDisposable *_updateCallsConfig;
    SVariable *_socksProxySettingsValue;
    bool _authorizationRecoveryInProgress;
}

@property (nonatomic, strong) ASHandle *actionHandle;

- (void)resetMainMtProto:(NSInteger)datacenterId completion:(void (^)(void))completion;
- (void)shutdownForAccountSwitch;
- (void)completeWakeUpIfAny:(NSString *)reason;

@end

@implementation TGTelegramNetworking

static bool TGTelegramLoggingFormatIsNetworkTrace(NSString *format)
{
    if (!OGPlatformUsesConstrainedBackgroundExecution())
        return false;

    return [format hasPrefix:@"MTHttpWorker"] || [format hasPrefix:@"[MTHttpTransport"] || [format rangeOfString:@"resetting session"].location != NSNotFound || [format rangeOfString:@"changing transport"].location != NSNotFound;
}

static void TGTelegramLoggingFunction(NSString *format, va_list args)
{
    if ([format rangeOfString:@"MTDatacenterAuth"].location != NSNotFound)
    {
    }
    else if (TGTelegramLoggingFormatIsNetworkTrace(format))
    {
    }
    else
    {
        TGLogv(format, args);
    }
}

static TGTelegramNetworking *singleton = nil;
static TGTelegramNetworking *retiredSingleton = nil;
static bool singletonCreationSuspended = false;

+ (TGTelegramNetworking *)instance
{
    TGTelegramNetworking *current = singleton;
    if (current != nil)
        return current;

    @synchronized (self)
    {
        if (singleton == nil && !singletonCreationSuspended)
        {
            static dispatch_once_t loggingOnceToken;
            dispatch_once(&loggingOnceToken, ^
            {
                MTLogSetLoggingFunction(&TGTelegramLoggingFunction);
            });
            NSData *socksProxyData = [TGDatabaseInstance() customProperty:@"socksProxyData"];
            NSData *networkSettingsData = [TGDatabaseInstance() customProperty:@"networkSettingsData"];
            singleton = [[TGTelegramNetworking alloc] initWithSocksProxyData:socksProxyData networkSettingsData:networkSettingsData];
        }
        return singleton;
    }
}

+ (void)suspendInstanceForAccountSwitch
{
    TGTelegramNetworking *previous = nil;
    @synchronized (self)
    {
        singletonCreationSuspended = true;
        previous = singleton;
        singleton = nil;
        retiredSingleton = previous;
    }
    [previous shutdownForAccountSwitch];
}

+ (void)resumeInstanceCreationAfterAccountSwitch
{
    @synchronized (self)
    {
        singletonCreationSuspended = false;
    }
}

- (void)shutdownForAccountSwitch
{
    [self completeWakeUpIfAny:@"account switch"];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [ActionStageInstance() removeWatcher:self];
    [_updateCallsConfig dispose];
    [_context removeChangeListener:self];

    _dispatchNetworkStateToken++;
    _serviceTasksWatchdogToken++;

    if (_requestService != nil)
    {
        _requestService.delegate = nil;
        [_mtProto removeMessageService:_requestService];
        _requestService = nil;
    }
    if (_updateService != nil)
    {
        [_mtProto removeMessageService:_updateService];
        _updateService = nil;
    }
    _mtProto.delegate = nil;
    [_mtProto stop];

    [_postponedRequests removeAllObjects];
    [_awaitingWorkerTokensByDatacenterId removeAllObjects];
    for (NSArray *workers in [_workersByDatacenterId allValues])
    {
        for (TGNetworkWorker *worker in workers)
        {
            [worker shutdown];
        }
    }
    [_workersByDatacenterId removeAllObjects];
    [_uploadWorkerPool shutdown];

    MTContext *context = _context;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        [context cleanup];
    } synchronous:true];

    UIWindow *passwordEntryWindow = _currentPasswordEntryWindow;
    _currentPasswordEntryWindow = nil;
    if (passwordEntryWindow != nil)
    {
        TGDispatchOnMainThread(^
        {
            passwordEntryWindow.hidden = true;
        });
    }
}

+ (void)prepareInstanceWithCompletion:(dispatch_block_t)completion
{
    OGRuntimeDispatch(OGRuntimePriorityUserInitiated, ^
    {
        [self instance];
        if (completion)
            completion();
    });
}

+ (TGTelegramNetworking *)maybeInstance
{
    return singleton;
}

- (instancetype)initWithSocksProxyData:(NSData *)socksProxyData networkSettingsData:(NSData *)networkSettingsData
{
    self = [super init];
    if (self != nil)
    {

        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        [ActionStageInstance() watchForPath:@"/tg/service/synchronizationstate" watcher:self];

        _postponedRequests = [[NSMutableArray alloc] init];
        _currentWakeUpCompletions = [[NSMutableArray alloc] init];
        
        _settingsKeychain = [MTFileBasedKeychain keychainWithName:@"Telegram-Settings" documentsPath:[TGAppDelegate documentsPath]];

        NSString *environmentId = [_settingsKeychain objectForKey:@"environmentId" group:@"environment"];

        _isTestingEnvironment = environmentId != nil && [environmentId isEqualToString:@"testing"];
        
        NSString *keychainName = _isTestingEnvironment ? @"Telegram-Testing" : @"Telegram";
        _keychain = [MTFileBasedKeychain keychainWithName:keychainName documentsPath:[TGAppDelegate documentsPath]];

        _cdnDatas = [[NSMutableDictionary alloc] init];
        
#if TGUseModernNetworking
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        bool keychainImportedLegacyKeychain = [[_keychain objectForKey:@"importedLegacyKeychain" group:@"meta"] boolValue];

        bool defaultsImportedLegacyKeychain = [userDefaults boolForKey:@"TGModernNetworkingImportedLegacyKeychain"];
        bool importedLegacyKeychain = keychainImportedLegacyKeychain || defaultsImportedLegacyKeychain;
        if (!importedLegacyKeychain)
        {
            TGLog(@"AUTH legacyKeychain.import.begin clientUserId=%d", TGTelegraphInstance.clientUserId);
            [TGKeychainImport importKeychain:_keychain clientUserId:TGTelegraphInstance.clientUserId];
            [_keychain setObject:@(true) forKey:@"importedLegacyKeychain" group:@"meta"];
            [userDefaults setBool:true forKey:@"TGModernNetworkingImportedLegacyKeychain"];
            [userDefaults synchronize];
            TGLog(@"AUTH legacyKeychain.import.end");
        }
#endif

        MTApiEnvironment *apiEnvironment = [[MTApiEnvironment alloc] init];

        apiEnvironment.tcpPayloadPrefix = [[[NSUserDefaults standardUserDefaults] objectForKey:@"network_tcpPayloadPrefix"] dataByDecodingHexString];

        NSMutableDictionary *datacenterAddressOverrides = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < 5; i++) {
            NSString *text = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"network_datacenterAddress_%d", i + 1]];
            if (text.length != 0) {
                NSRange portRange = [text rangeOfString:@":"];
                NSString *ip = nil;
                uint16_t port = 443;
                if (portRange.location != NSNotFound) {
                    ip = [text substringToIndex:portRange.location];
                    port = (uint16_t)[[text substringFromIndex:portRange.location + 1] intValue];
                } else {
                    ip = text;
                }
                datacenterAddressOverrides[@(i + 1)] = [[MTDatacenterAddress alloc] initWithIp:ip port:port preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil];
            }
        }
        apiEnvironment.datacenterAddressOverrides = datacenterAddressOverrides;

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        int32_t apiId = 0;
        SETUP_API_ID(apiId)

        apiEnvironment.apiId = apiId;
        
        apiEnvironment.layer = @([[[TGTLSerialization alloc] init] currentLayer]);

        apiEnvironment = [apiEnvironment withUpdatedLangPackCode:currentNativeLocalizationCode()];

        OGOnegramCore *onegramCore = [OGOnegramCore sharedCore];
        OGOnegramCoreMode proxyMode = onegramCore.mode;
        bool webSocketEnabled = proxyMode == OGOnegramCoreModeWebSocket;
        if (OGPlatformMajorVersion() <= 3 && proxyMode == OGOnegramCoreModeNone) {
            apiEnvironment = [apiEnvironment withUpdatedPreferHttpTransport:true];
        }

        if (socksProxyData != nil) {
            NSDictionary *socksProxyDict = [NSKeyedUnarchiver unarchiveObjectWithData:socksProxyData];
            if (socksProxyDict[@"ip"] != nil && socksProxyDict[@"port"] != nil && ![socksProxyDict[@"inactive"] boolValue]) {
                NSString *secretString = socksProxyDict[@"secret"];
                NSData *secret = TGIos6IsHexString(secretString) ? [NSData dataWithHexString:secretString] : nil;
                if ([secretString isKindOfClass:[NSString class]] && secretString.length != 0 && secret == nil)
                    TGLog(@"AUTH ignoring non-hex proxy secret length=%d", (int)secretString.length);
                apiEnvironment = [apiEnvironment withUpdatedSocksProxySettings:[[MTSocksProxySettings alloc] initWithIp:socksProxyDict[@"ip"] port:(uint16_t)[socksProxyDict[@"port"] intValue] username:socksProxyDict[@"username"] password:socksProxyDict[@"password"] secret:secret]];
            }
        }
        if (webSocketEnabled)
        {
            apiEnvironment = [apiEnvironment withUpdatedSocksProxySettings:nil];
            apiEnvironment = [apiEnvironment withUpdatedOnegramWebSocketEnabled:true];
        }

        if (proxyMode == OGOnegramCoreModeDanteWARP || proxyMode == OGOnegramCoreModeDantePower) {
            apiEnvironment = [apiEnvironment withUpdatedSocksProxySettings:[[MTSocksProxySettings alloc] initWithIp:@"127.0.0.1" port:onegramCore.socksPort username:nil password:nil secret:nil]];
            apiEnvironment = [apiEnvironment withUpdatedPreferHttpTransport:false];
        }

        TGNetworkSettings *networkSettings = nil;
        if (networkSettingsData != nil) {
            networkSettings = [NSKeyedUnarchiver unarchiveObjectWithData:networkSettingsData];
        }

        if (networkSettings == nil) {
            TGUser *user = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];

            NSString *phoneNumber = @"";
            if (user != nil) {
                phoneNumber = [TGPhoneUtils cleanPhone:user.phoneNumber];
            }
            if ([phoneNumber hasPrefix:@"7"]) {
                networkSettings = [[TGNetworkSettings alloc] initWithReducedBackupDiscoveryTimeout:true];
            }
        }
        
        if (networkSettings != nil) {
            apiEnvironment = [apiEnvironment withUpdatedNetworkSettings:[[MTNetworkSettings alloc] initWithReducedBackupDiscoveryTimeout:networkSettings.reducedBackupDiscoveryTimeout]];
        }

        _socksProxySettingsValue = [[SVariable alloc] init];

        [_socksProxySettingsValue set:[SSignal single:apiEnvironment.socksProxySettings]];


        _context = [[MTContext alloc] initWithSerialization:[[TGTLSerialization alloc] init] apiEnvironment:apiEnvironment isTestingEnvironment:_isTestingEnvironment useTempAuthKeys:false];

        [_context addChangeListener:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onegramCoreDidChange:) name:OGOnegramCoreDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onegramWebSocketStatusChanged:) name:MTTcpConnectionOnegramWebSocketStatusNotification object:nil];
        
        _workersByDatacenterId = [[NSMutableDictionary alloc] init];
        _awaitingWorkerTokensByDatacenterId = [[NSMutableDictionary alloc] init];
        _mediaNetworkQueue = [[MTQueue alloc] initWithName:"org.telegram.network.media"];
        _transferNetworkQueue = [[MTQueue alloc] initWithName:"org.telegram.network.transfer"];
        dispatch_set_target_queue(_transferNetworkQueue.nativeQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _uploadWorkerPool = [[TGUploadWorkerPool alloc] initWithNetworkQueue:_transferNetworkQueue];
        
        if (_isTestingEnvironment)
        {
            [_context updateAddressSetForDatacenterWithId:1 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                [[MTDatacenterAddress alloc] initWithIp:@"149.154.175.10" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
            ]] forceUpdateSchemes:true];
            [_context updateAddressSetForDatacenterWithId:2 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.40" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
            ]] forceUpdateSchemes:true];
        }
        else
        {
            [_context performBatchUpdates:^
            {
                [_context setSeedAddressSetForDatacenterWithId:1 seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                    [[MTDatacenterAddress alloc] initWithIp:@"149.154.175.50" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"2001:b28:f23d:f001::a" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
                ]]];
                
                [_context setSeedAddressSetForDatacenterWithId:2 seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                    [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.51" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"2001:67c:4e8:f002::a" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
                ]]];
                
                [_context setSeedAddressSetForDatacenterWithId:3 seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                    [[MTDatacenterAddress alloc] initWithIp:@"149.154.175.100" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"2001:b28:f23d:f003::a" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
                ]]];

                [_context setSeedAddressSetForDatacenterWithId:4 seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                    [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.91" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"2001:67c:4e8:f004::a" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
                ]]];

                [_context setSeedAddressSetForDatacenterWithId:5 seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                    [[MTDatacenterAddress alloc] initWithIp:@"91.108.56.130" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"149.154.171.5" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
                    [[MTDatacenterAddress alloc] initWithIp:@"2001:b28:f23f:f005::a" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
                ]]];
            }];
        }
        
        NSNumber *transportCacheVersion = [_keychain objectForKey:@"onegramTransportCacheVersion" group:@"meta"];
        if ([transportCacheVersion integerValue] < TGOnegramTransportCacheVersion)
        {
            [_keychain removeObjectForKey:@"datacenterAddressSetById" group:@"persistent"];
            [_keychain removeObjectForKey:@"datacenterGenericTransportSchemeById" group:@"persistent"];
            [_keychain removeObjectForKey:@"datacenterMediaTransportSchemeById" group:@"persistent"];
            [_keychain removeObjectForKey:@"datacenterProxyGenericTransportSchemeById" group:@"persistent"];
            [_keychain removeObjectForKey:@"datacenterProxyMediaTransportSchemeById" group:@"persistent"];
            [_keychain setObject:@(TGOnegramTransportCacheVersion) forKey:@"onegramTransportCacheVersion" group:@"meta"];
        }

        _context.keychain = _keychain;

        if (_isTestingEnvironment)
        {
            [_context updateAddressSetForDatacenterWithId:1 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                [[MTDatacenterAddress alloc] initWithIp:@"149.154.175.10" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
            ]] forceUpdateSchemes:true];
            [_context updateAddressSetForDatacenterWithId:2 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[
                [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.40" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]
            ]] forceUpdateSchemes:true];
        } else {
#if DEBUG
#endif
        }
        
        MTSignal *discoverBackupAddressList = [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
            TGUser *user = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
            NSString *phoneNumber = @"";
            if (user != nil) {
                phoneNumber = [TGPhoneUtils cleanPhone:user.phoneNumber];
            }
            id<MTDisposable> disposable = [[MTBackupAddressSignals fetchBackupIps:_isTestingEnvironment currentContext:_context additionalSource:[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *internalSubscriber) {
                TGUser *user = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
                NSString *prefix = @"0";
                if (user != nil) {
                    NSString *phone = [TGPhoneUtils cleanPhone:user.phoneNumber];
                    if (phone.length > 0) {
                        prefix = [phone substringToIndex:1];
                    }
                }
                id<SDisposable> disposable = [[TGICloudEmergencyDataSignals fetchBackupAddressInfo:prefix phoneNumber:phoneNumber] startWithNext:^(MTBackupDatacenterData *result) {
                    [internalSubscriber putNext:result];
                    [internalSubscriber putCompletion];
                }];
                return [[MTBlockDisposable alloc] initWithBlock:^{
                    [disposable dispose];
                }];
            }] phoneNumber:phoneNumber] startWithNext:nil error:^(__unused id error) {
                [subscriber putCompletion];
            } completed:^{
                [subscriber putCompletion];
            }];
            return [[MTBlockDisposable alloc] initWithBlock:^{
                [disposable dispose];
            }];
        }];
        [_context setDiscoverBackupAddressListSignal:discoverBackupAddressList];
        
        __unused id<SDisposable> disposable = [[TGICloudEmergencyDataSignals updateSubscription] startWithNext:nil];

        
        bool foundAuthorizations = false;
        for (NSInteger i = 0; i < 5; i++)
        {
            if ([_context authInfoForDatacenterWithId:i] != nil)
            {
                foundAuthorizations = true;
                break;
            }
        }

        NSNumber *nDefaultDatacenterId = [_keychain objectForKey:@"defaultDatacenterId" group:@"persistent"];
        bool storedDefaultDatacenter = nDefaultDatacenterId != nil;

        if (nDefaultDatacenterId == nil)
        {
            if (foundAuthorizations)
                nDefaultDatacenterId = @(1);
            else
                nDefaultDatacenterId = @(2);
        }


        if (iosMajorVersion() < 5 && !foundAuthorizations && TGTelegraphInstance.clientUserId == 0)
        {
            NSTimeInterval localUnixTime = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval networkUnixTime = 0.0;
            if (TGIOS6FetchNetworkUnixTime(&networkUnixTime))
            {
                localUnixTime = [[NSDate date] timeIntervalSince1970];
                NSTimeInterval difference = networkUnixTime - localUnixTime;
                [_context setGlobalTimeDifference:difference];
                [_context globalTimeDifference];
            }
            else
            {
                TGLog(@"IOS6AUTH time bootstrap failed local=%.3f", [[NSDate date] timeIntervalSince1970]);
            }
        }

        [self moveToDatacenterId:[nDefaultDatacenterId integerValue]];

        MTDatacenterAuthInfo *masterAuthInfo = [_context authInfoForDatacenterWithId:[nDefaultDatacenterId integerValue]];
        TGLog(@"AUTH session.start userId=%d dc=%d storedDc=%d authorizations=%d authKeyId=%llx", TGTelegraphInstance.clientUserId, [nDefaultDatacenterId intValue], storedDefaultDatacenter ? 1 : 0, foundAuthorizations ? 1 : 0, (unsigned long long)masterAuthInfo.authKeyId);
        
        [ActionStageInstance() requestActor:@"/tg/datacenterWatchdog" options:nil flags:0 watcher:self];

        [TGDatabaseInstance() resetStartupTime:[self globalTime]];

        bool renewSchemes = networkSettings == nil;
#ifdef DEBUG
        renewSchemes = true;
#endif
        if (renewSchemes) {
            [_context invalidateTransportSchemesForKnownDatacenterIds];
        }


    }
    return self;
}

- (SMulticastSignalManager *)genericTasksSignalManager
{
    return TGTelegraphInstance.genericTasksSignalManager;
}

- (NSURL *)sharedAuthInfoPath
{
    if (iosMajorVersion() < 8)
        return nil;

    NSString *groupName = [@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]];
    NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupName];
    if (groupURL != nil)
    {
        NSURL *sharedAuthInfoPath = [groupURL URLByAppendingPathComponent:@"shared-auth-info" isDirectory:false];
        return sharedAuthInfoPath;
    }
    
    return nil;
}

- (void)removeCredentialsForExtensions
{
    TGLog(@"AUTH extensions.credentials.remove userId=%d activated=%d", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);
    
    if (iosMajorVersion() < 8)
        return;
    
    if ([self sharedAuthInfoPath] != nil)
        [[NSFileManager defaultManager] removeItemAtURL:[self sharedAuthInfoPath] error:nil];
}

- (NSData*)generateSalt256
{
    unsigned char salt[32];
    for (int i = 0; i < 32; i++)
    {
        salt[i] = (unsigned char)arc4random();
    }
    return [NSData dataWithBytes:salt length:32];
}

- (void)exportCredentialsForExtensions
{
    if (iosMajorVersion() < 8)
        return;
    
    NSURL *destination = [self sharedAuthInfoPath];
    if (destination == nil) return;

    [_context performBatchUpdates:^
    {
        int32_t exportingUserId = TGTelegraphInstance.clientUserId;
        if (exportingUserId == 0 || !TGTelegraphInstance.clientIsActivated) return;
        bool isStrong = false;
        bool passwordSet = [TGDatabaseInstance() isPasswordSet:&isStrong];
        NSString *password = nil;
        if (passwordSet)
        {
            password = [TGDatabaseInstance() currentPassword];

        }
        
        NSData *fingerprint = [TGDatabaseInstance() extensionPasswordFingerprint];
        if (passwordSet && fingerprint == nil) return;
        NSDictionary *protection = fingerprint == nil ? nil : TGShareReadProtection(exportingUserId, fingerprint);
        if (fingerprint != nil && protection == nil)
        {
            if (password == nil)
            {
                NSData *previous = [NSData dataWithContentsOfURL:destination];
                NSDictionary *container = nil;
                @try
                {
                    id decoded = previous == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:previous];
                    if ([decoded isKindOfClass:[NSDictionary class]]) container = decoded;
                }
                @catch (__unused NSException *exception)
                {
                    container = nil;
                }
                if (![container[@"fingerprint"] isEqual:fingerprint] || [container[@"userId"] intValue] != exportingUserId)
                    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
                return;
            }
            NSData *salt = [self generateSalt256];
            NSData *key = MTPBKDF2HMACSHA256([password dataUsingEncoding:NSUTF8StringEncoding], salt, 100000, 32);
            if (key == nil) return;
            protection = @{@"fingerprint": fingerprint, @"salt": salt, @"key": key, @"rounds": @100000};
            if (!TGShareWriteProtection(exportingUserId, protection)) return;
        }

        NSMutableDictionary *addressSets = [[NSMutableDictionary alloc] init];
        for (NSNumber *dcId in _context.knownDatacenterIds)
        {
            NSInteger datacenterId = dcId.integerValue;
            if (datacenterId > 0 && datacenterId < 10)
            {
                MTDatacenterAddressSet *addressSet = [_context addressSetForDatacenterWithId:_mtProto.datacenterId];
                if (addressSet != nil)
                    addressSets[dcId] = addressSet;
            }
        }

        MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_mtProto.datacenterId];
        if (authInfo != nil)
        {
            MTDatacenterAuthInfo *sharedAuthInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:@[] authKeyAttributes:@{} mainTempAuthKey:nil mediaTempAuthKey:nil];
            NSString *versionString = [[NSString alloc] initWithFormat:@"%@ (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{@"datacenterId":@(_mtProto.datacenterId), @"addressSets": addressSets, @"authInfo": sharedAuthInfo, @"version": versionString, @"clientUserId": @(TGTelegraphInstance.clientUserId), @"isTesting": @(_isTestingEnvironment) }];
            
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"protected"] = @(fingerprint != nil);
            dict[@"userId"] = @(exportingUserId);
            if (fingerprint != nil) dict[@"fingerprint"] = fingerprint;
            if (protection != nil)
            {
                NSMutableData *iv = [NSMutableData dataWithLength:32];
                arc4random_buf(iv.mutableBytes, 32);
                NSMutableData *encryptedData = [[NSMutableData alloc] init];
                int32_t plainLength = (int32_t)data.length;
                [encryptedData appendBytes:&plainLength length:4];
                [encryptedData appendData:data];
                while (encryptedData.length % 16 != 0)
                {
                    uint8_t random = (uint8_t)arc4random();
                    [encryptedData appendBytes:&random length:1];
                }
                MTAesEncryptInplace(encryptedData, protection[@"key"], iv);
                dict[@"data"] = encryptedData;
                dict[@"iv"] = iv;
                dict[@"checksum"] = MTSha1(data);
                dict[@"salt"] = protection[@"salt"];
                dict[@"rounds"] = protection[@"rounds"];
                dict[@"simple"] = @(!isStrong);
                dict[@"touchId"] = @([[[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_useTouchId"] boolValue]);
            }
            else
                dict[@"data"] = data;
            NSData *currentFingerprint = [TGDatabaseInstance() extensionPasswordFingerprint];
            if (!(currentFingerprint == nil && fingerprint == nil) && ![currentFingerprint isEqual:fingerprint]) return;
            if (TGTelegraphInstance.clientUserId != exportingUserId || !TGTelegraphInstance.clientIsActivated) return;

            NSData *storedData = [NSKeyedArchiver archivedDataWithRootObject:dict];
            [storedData writeToURL:destination atomically:true];
        }
    }];
}

static NSString *TGPushHelperDirectory(void)
{
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
    NSString *dir = [documentsPath stringByAppendingPathComponent:@OGPushHelperAuthInfoDirectoryName];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:true attributes:nil error:NULL];
    return dir;
}

static NSString *TGPushHelperDaemonFlagPath(void)
{
    return [TGPushHelperDirectory() stringByAppendingPathComponent:@OGPushHelperDaemonFlagFileName];
}

static NSString *TGPushHelperAppStatePath(void)
{
    return [TGPushHelperDirectory() stringByAppendingPathComponent:@OGPushHelperAppStateFileName];
}

static bool TGPushHelperDaemonAvailable(void)
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:TGPushHelperDaemonFlagPath() error:NULL];
    NSDate *modified = attributes[NSFileModificationDate];
    if (modified == nil)
        return false;
    return -[modified timeIntervalSinceNow] < OGPushHelperDaemonFlagFreshnessSeconds;
}

static NSDictionary *TGPushHelperApiEnvironmentDescription(MTApiEnvironment *apiEnvironment)
{
    if (apiEnvironment.appVersion == nil || apiEnvironment.layer == nil || apiEnvironment.langPack == nil || apiEnvironment.systemLangCode == nil)
        return nil;

    NSMutableDictionary *description = [[NSMutableDictionary alloc] init];
    description[@"apiId"] = @(apiEnvironment.apiId);
    description[@"appVersion"] = apiEnvironment.appVersion;
    description[@"layer"] = apiEnvironment.layer;
    description[@"langPack"] = apiEnvironment.langPack;
    description[@"systemLangCode"] = apiEnvironment.systemLangCode;
    if (apiEnvironment.langPackCode != nil)
        description[@"langPackCode"] = apiEnvironment.langPackCode;
    return description;
}

static void TGPushHelperDaemonStateChanged(__unused CFNotificationCenterRef center, __unused void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [[TGTelegramNetworking maybeInstance] exportHelperAuthInfo];
}

+ (void)ensurePushHelperObserver
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &TGPushHelperDaemonStateChanged, CFSTR(OGPushHelperDaemonStateNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

+ (bool)pushHelperAvailable
{
    return TGPushHelperDaemonAvailable();
}

static NSString *TGPushHelperApplicationStateName(TGPushHelperApplicationState state)
{
    switch (state)
    {
        case TGPushHelperApplicationStateReceiving:
            return @"receiving";
        case TGPushHelperApplicationStateFinishing:
            return @"finishing";
        case TGPushHelperApplicationStateSuspended:
            return @"suspended";
    }
    return @"receiving";
}

+ (void)updatePushHelperApplicationState:(TGPushHelperApplicationState)applicationState
{
    [self ensurePushHelperObserver];

    NSMutableDictionary *state = [[NSMutableDictionary alloc] init];
    state[@"state"] = TGPushHelperApplicationStateName(applicationState);
    state[@"pid"] = @(getpid());
    state[@"time"] = @([[NSDate date] timeIntervalSince1970]);
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier != nil)
        state[@"bundleIdentifier"] = bundleIdentifier;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:state];
    NSString *path = TGPushHelperAppStatePath();
    if (data != nil && [data writeToFile:path options:NSDataWritingAtomic error:NULL] && iosMajorVersion() >= 4)
        [[NSFileManager defaultManager] setAttributes:@{@"NSFileProtectionKey": @"NSFileProtectionNone"} ofItemAtPath:path error:NULL];
    notify_post(OGPushHelperApplicationStateNotification);

    [[TGTelegramNetworking maybeInstance] exportHelperAuthInfo];
}

+ (void)notifyPushHelperApplicationTerminating
{
    notify_post(OGPushHelperApplicationStateNotification);
}

+ (NSString *)helperAuthInfoPath
{
    return [TGPushHelperDirectory() stringByAppendingPathComponent:@OGPushHelperAuthInfoFileName];
}

- (void)removeHelperAuthInfo
{
    if ([[NSFileManager defaultManager] removeItemAtPath:[TGTelegramNetworking helperAuthInfoPath] error:NULL])
        notify_post(OGPushHelperAuthInfoChangedNotification);
}

- (void)exportHelperAuthInfo
{
    if (!TGPushHelperDaemonAvailable())
    {
        [self removeHelperAuthInfo];
        return;
    }

    NSString *path = [TGTelegramNetworking helperAuthInfoPath];

    [_context performBatchUpdates:^
    {
        int32_t exportingUserId = TGTelegraphInstance.clientUserId;
        if (exportingUserId == 0 || !TGTelegraphInstance.clientIsActivated)
        {
            [self removeHelperAuthInfo];
            return;
        }

        NSMutableDictionary *addressSets = [[NSMutableDictionary alloc] init];
        for (NSNumber *dcId in _context.knownDatacenterIds)
        {
            NSInteger datacenterId = dcId.integerValue;
            if (datacenterId > 0 && datacenterId < 10)
            {
                MTDatacenterAddressSet *addressSet = [_context addressSetForDatacenterWithId:datacenterId];
                if (addressSet != nil)
                    addressSets[dcId] = addressSet;
            }
        }

        MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_mtProto.datacenterId];
        if (authInfo == nil)
            return;

        NSDictionary *apiEnvironmentDescription = TGPushHelperApiEnvironmentDescription(_context.apiEnvironment);
        if (apiEnvironmentDescription == nil)
            return;

        NSString *apiInitializationHash = authInfo.authKeyAttributes[@"apiInitializationHash"];
        NSDictionary *sharedAuthKeyAttributes = apiInitializationHash != nil ? @{@"apiInitializationHash": apiInitializationHash} : @{};
        MTDatacenterAuthInfo *sharedAuthInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:@[] authKeyAttributes:sharedAuthKeyAttributes mainTempAuthKey:nil mediaTempAuthKey:nil];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{@"datacenterId": @(_mtProto.datacenterId), @"addressSets": addressSets, @"authInfo": sharedAuthInfo, @"apiEnvironment": apiEnvironmentDescription, @"clientUserId": @(exportingUserId), @"isTesting": @(_isTestingEnvironment)}];

        if (TGTelegraphInstance.clientUserId != exportingUserId || !TGTelegraphInstance.clientIsActivated)
            return;

        NSData *existing = [NSData dataWithContentsOfFile:path];
        if ([existing isEqualToData:data])
            return;
        if (![data writeToFile:path options:NSDataWritingAtomic error:NULL])
            return;
        if (iosMajorVersion() >= 5)
            [[NSFileManager defaultManager] setAttributes:@{@"NSFileProtectionKey": @"NSFileProtectionCompleteUntilFirstUserAuthentication"} ofItemAtPath:path error:NULL];
        notify_post(OGPushHelperAuthInfoChangedNotification);
    }];
}

- (MTContext *)context
{
    return _context;
}

- (MTProto *)mtProto
{
    return _mtProto;
}

- (void)resetMainMtProto:(NSInteger)datacenterId
{
    [self resetMainMtProto:datacenterId completion:nil];
}

- (void)resetMainMtProto:(NSInteger)datacenterId completion:(void (^)(void))completion
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_requestService != nil)
        {
            _requestService.delegate = nil;
            [_mtProto removeMessageService:_requestService];
            _requestService = nil;
        }
        
        if (_updateService != nil)
        {
            [_mtProto removeMessageService:_updateService];
            _updateService = nil;
        }
        
        if (_mtProto != nil)
        {
            _mtProto.delegate = nil;
            [_mtProto stop];
        }
        
        _masterDatacenterId = datacenterId;

        MTDatacenterAuthInfo *existingAuthInfo = [_context authInfoForDatacenterWithId:datacenterId];
        bool forceApiInitialization = TGTelegraphInstance.clientUserId != 0 && existingAuthInfo != nil && existingAuthInfo.authKeyAttributes[@"apiInitializationHash"] == nil;
        
        MTNetworkUsageCalculationInfo *dataUsageInfo = [self dataUsageInfo];
        dataUsageInfo.primaryConnection = true;
        _mtProto = [[MTProto alloc] initWithContext:_context datacenterId:datacenterId usageCalculationInfo:dataUsageInfo];
        _mtProto.delegate = self;
        if (forceApiInitialization)
        {
            [_mtProto pause];
        }
        _isNetworkAvailable = true;
        _isConnected = true;
        _mtProto.useTempAuthKeys = false;
        [self dispatchNetworkState];
        
        _requestService = [[MTRequestMessageService alloc] initWithContext:_context];
        _requestService.delegate = self;
        [_mtProto addMessageService:_requestService];
        
        _updateService = [[TGUpdateMessageService alloc] init];
        [_mtProto addMessageService:_updateService];
        
        [_context authInfoForDatacenterWithIdRequired:_mtProto.datacenterId isCdn:false];
        
        if (TGTelegraphInstance.clientUserId == 0) {
            [_context transportSchemeForDatacenterWithIdRequired:datacenterId media:false];
        }
        
        if (_postponedRequests.count > 0) {
            for (MTRequest *request in _postponedRequests) {
                [_requestService addRequest:request];
            }
            [_postponedRequests removeAllObjects];
        }

        if (forceApiInitialization)
            [_mtProto resume];
        
#if TARGET_IPHONE_SIMULATOR && false
        MTRequest *getSchemeRequest = [[MTRequest alloc] init];
        getSchemeRequest.body = [[TLRPChelp_getScheme$help_getScheme alloc] init];
        [getSchemeRequest setCompleted:^(TLScheme$scheme *result, __unused NSTimeInterval timestamp, __unused id error)
        {
        }];
        [self addRequest:getSchemeRequest];
        
#endif
        if (completion != nil)
            completion();
    }];
}

- (NSTimeInterval)globalTime
{
#if TGUseModernNetworking
    return [_context globalTime];
#else
    return (int)(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) + [[TGSession instance] timeDifference];
#endif
}

- (NSTimeInterval)timeOffset
{
#if TGUseModernNetworking
    return [_context globalTimeOffsetFromUTC];
#else
    return [[TGSession instance] timeOffsetFromUTC];
#endif
}

- (NSTimeInterval)approximateRemoteTime
{
#if TGUseModernNetworking
    return [_context globalTime];
#else
    return [[NSDate date] timeIntervalSince1970] + [[TGSession instance] timeOffsetFromUTC] - [[NSTimeZone localTimeZone] secondsFromGMT];
#endif
}

- (void)loadCredentials
{
#if TGUseModernNetworking
#else
    [[TGSession instance] loadSession];
#endif
}

- (void)start
{
#if TGUseModernNetworking
#else
    [[TGSession instance] takeOff];
#endif
}

- (void)pause
{
#if TGUseModernNetworking
    [_mtProto pause];
#else
    [[TGSession instance] suspendNetwork];
#endif
}

- (void)resume
{
#if TGUseModernNetworking
    [_mtProto resume];
#else
    [[TGSession instance] resumeNetwork];
#endif
}

- (void)prepareForUnauthorizedRequests
{
#if TGUseModernNetworking
    [_mtProto resume];
    NSInteger datacenterId = _mtProto.datacenterId;
    if (datacenterId != 0)
    {
        [_context authInfoForDatacenterWithIdRequired:datacenterId isCdn:false];
        [_context transportSchemeForDatacenterWithIdRequired:datacenterId media:false];
    }
#else
    [[TGSession instance] resumeNetwork];
#endif
}

- (void)moveToDatacenterId:(NSInteger)datacenterId
{
    [self moveToDatacenterId:datacenterId completion:nil];
}

- (void)moveToDatacenterId:(NSInteger)datacenterId completion:(void (^)(void))completion
{
#if TGUseModernNetworking
    if (_mtProto == nil || datacenterId != _mtProto.datacenterId)
    {
        _masterDatacenterId = datacenterId;
        [_keychain setObject:@(_masterDatacenterId) forKey:@"defaultDatacenterId" group:@"persistent"];
        [self resetMainMtProto:datacenterId completion:completion];
    }
    else if (completion != nil)
    {
        [ActionStageInstance() dispatchOnStageQueue:completion];
    }
#else
    if (completion != nil)
        completion();
#endif
}

- (void)restartWithCleanCredentials
{
#if TGUseModernNetworking
    TGLog(@"AUTH restartWithCleanCredentials.begin userId=%d activated=%d", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);
    
    if (_requestService != nil)
    {
        _requestService.delegate = nil;
        [_mtProto removeMessageService:_requestService];
    }
    
    _requestService = [[MTRequestMessageService alloc] initWithContext:_context];
    _requestService.delegate = self;
    [_mtProto addMessageService:_requestService];
    
    TGTelegraphInstance.clientUserId = 0;
    TGTelegraphInstance.clientIsActivated = false;
    [TGAppDelegateInstance saveSettings];
    TGLog(@"AUTH restartWithCleanCredentials.saved userId=%d activated=%d", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);
    
    [_context removeAllAuthTokens];
    [_context updateApiEnvironment:^MTApiEnvironment *(MTApiEnvironment *environment) {
        return [environment withUpdatedSocksProxySettings:nil];
    }];
    
    [TGKeychainImport clearLegacyKeychain];
    _authorizationRecoveryInProgress = false;
#else
    [[TGSession instance] clearSessionAndTakeOff];
#endif
}

- (void)clearExportedTokens
{
    NSInteger masterDatacenterId = _mtProto.datacenterId;
    [_context performBatchUpdates:^
    {
        for (NSNumber *nDatacenterId in [_context knownDatacenterIds])
        {
            if ([nDatacenterId integerValue] != masterDatacenterId)
                [_context updateAuthTokenForDatacenterWithId:[nDatacenterId integerValue] authToken:nil];
        }
    }];
}

- (void)mergeDatacenterAddress:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
#if TGUseModernNetworking
    [_context performBatchUpdates:^
    {
        [_context addAddressForDatacenterWithId:datacenterId address:address];
        
        MTTransportScheme *scheme = [_context transportSchemeForDatacenterWithId:datacenterId media:false isProxy:false];
        if (![scheme.address isEqualToAddress:address])
        {
            scheme = [[MTTransportScheme alloc] initWithTransportClass:scheme.transportClass address:address media:false];
            [_context updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:scheme media:false isProxy:false];
        }
    }];
    
    [self exportCredentialsForExtensions];
    [self exportHelperAuthInfo];
#else
    TGDatacenterContext *datacenter = datacenter = [[TGDatacenterContext alloc] init];
    datacenter.datacenterId = datacenterId;
    
    int64_t authSessionId = [[TGSession instance] generateSessionId];
    int64_t authUploadSessionId = [[TGSession instance] generateSessionId];
    int64_t authDownloadSessionId = [[TGSession instance] generateSessionId];
    
    datacenter.authSessionId = authSessionId;
    datacenter.authDownloadSessionId = authDownloadSessionId;
    datacenter.authUploadSessionId = authUploadSessionId;
    
    NSMutableArray *addressSet = datacenter.addressSet == nil ? [[NSMutableArray alloc] init] : [[NSMutableArray alloc] initWithArray:datacenter.addressSet];
    [addressSet addObject:[[NSDictionary alloc] initWithObjectsAndKeys:address.ip, @"address", [[NSNumber alloc] initWithInt:address.port], @"port", nil]];
    datacenter.addressSet = addressSet;
    
    [[TGSession instance] mergeDatacenterData:@[datacenter]];
#endif
}

- (void)performDeferredServiceTasks
{    
#if TGUseModernNetworking
#else
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/network/requestFutureSalts/(%d)", [[TGSession instance] datacenterWithId:TG_DEFAULT_DATACENTER_ID].datacenterId] options:nil flags:0 watcher:[TGSession instance]];
#endif
}

- (NSInteger)masterDatacenterId
{
    return _masterDatacenterId;
}

- (id)requestDownloadWorkerForDatacenterId:(NSInteger)datacenterId type:(TGNetworkMediaTypeTag)type completion:(void (^)(TGNetworkWorkerGuard *))completion {
    return [self requestDownloadWorkerForDatacenterId:datacenterId type:type isCdn:false completion:completion];
}
    
- (id)requestDownloadWorkerForDatacenterId:(NSInteger)datacenterId type:(TGNetworkMediaTypeTag)type isCdn:(bool)isCdn completion:(void (^)(TGNetworkWorkerGuard *))completion
{
    id token = [[MTInternalId(TGDownloadWorker) alloc] init];
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSMutableArray *awaitingWorkerTokenList = _awaitingWorkerTokensByDatacenterId[@(datacenterId)];
        if (awaitingWorkerTokenList == nil)
        {
            awaitingWorkerTokenList = [[NSMutableArray alloc] init];
            _awaitingWorkerTokensByDatacenterId[@(datacenterId)] = awaitingWorkerTokenList;
        }
        
        [awaitingWorkerTokenList addObject:@[token, [completion copy], @(type), @(isCdn)]];
        
        [self _processWorkerQueue];
    }];
    return token;
}

- (void)_processWorkerQueue
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [_awaitingWorkerTokensByDatacenterId enumerateKeysAndObjectsUsingBlock:^(__unused NSNumber *nDatacenterId, NSMutableArray *list, __unused BOOL *stop)
        {
            if (list.count != 0)
            {
                NSArray *desc = list[0];
                bool isCdn = [desc[3] boolValue];
                
                NSMutableArray *workerList = _workersByDatacenterId[nDatacenterId];
                if (workerList == nil)
                {
                    workerList = [[NSMutableArray alloc] init];
                    _workersByDatacenterId[nDatacenterId] = workerList;
                }
                
                TGNetworkWorker *selectedWorker = nil;
                for (TGNetworkWorker *worker in workerList)
                {
                    if (!worker.isBusy)
                    {
                        selectedWorker = worker;
                        break;
                    }
                }
                
                if (selectedWorker == nil && workerList.count < TGMaxWorkerCount())
                {
                    if ([nDatacenterId intValue] > 10) {
                        if (!isCdn) {
                            TGLog(@"missing cdn mark");
                            isCdn = true;
                        }
                    }
                    TGNetworkWorker *worker = [[TGNetworkWorker alloc] initWithContext:_context datacenterId:[nDatacenterId integerValue] masterDatacenterId:_masterDatacenterId isCdn:isCdn networkQueue:_mediaNetworkQueue stateQueue:nil];
                    worker.delegate = self;
                    [workerList addObject:worker];
                    
                    selectedWorker = worker;
                }
                
                if (selectedWorker != nil)
                {
                    [list removeObjectAtIndex:0];
                    
                    [selectedWorker setIsBusy:true];
                    [selectedWorker setUsageCalculationInfo:[self mediaUsageInfoForType:(TGNetworkMediaTypeTag)[desc[2] intValue]]];
                    TGNetworkWorkerGuard *guard = [[TGNetworkWorkerGuard alloc] initWithWorker:selectedWorker];
                    ((void (^)(TGNetworkWorkerGuard *))desc[1])(guard);
                }
            }
        }];
    }];
}

- (id)requestUploadWorkerForDatacenterId:(NSInteger)datacenterId type:(TGNetworkMediaTypeTag)type completion:(void (^)(TGNetworkWorkerGuard *))completion
{
    TGUploadWorkerRequest *request = [[TGUploadWorkerRequest alloc] init];
    request.token = [[MTInternalId(TGDownloadWorker) alloc] init];
    request.context = _context;
    request.datacenterId = datacenterId;
    request.masterDatacenterId = _masterDatacenterId;
    request.type = type;
    request.completion = completion;
    [_uploadWorkerPool enqueueRequest:request];
    return request.token;
}

- (void)cancelUploadWorkerRequestByToken:(id)token
{
    [_uploadWorkerPool cancelRequestByToken:token];
}

- (void)cancelDownloadWorkerRequestByToken:(id)token
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [_awaitingWorkerTokensByDatacenterId enumerateKeysAndObjectsUsingBlock:^(__unused NSNumber *nDatacenterId, NSMutableArray *list, __unused BOOL *stop)
        {
            NSInteger index = -1;
            for (NSArray *desc in list)
            {
                index++;
                if ([desc[0] isEqual:token])
                {
                    [list removeObjectAtIndex:(NSUInteger)index];
                    
                    break;
                }
            }
        }];
    }];
}

- (void)networkWorkerDidBecomeAvailable:(TGNetworkWorker *)__unused networkWorker
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [self _processWorkerQueue];
    }];
}

- (void)networkWorkerReadyToBeRemoved:(TGNetworkWorker *)networkWorker
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [_workersByDatacenterId enumerateKeysAndObjectsUsingBlock:^(__unused NSNumber *nDatacenterId, NSMutableArray *workers, __unused BOOL *stop)
        {
            NSInteger index = -1;
            for (TGNetworkWorker *worker in workers)
            {
                index++;
                
                if (worker == networkWorker)
                {
                    if (!worker.isBusy)
                    {
                        worker.delegate = nil;
                        [workers removeObjectAtIndex:(NSUInteger)index];
                    }
                    
                    break;
                }
            }
        }];
    }];
}

- (void)updatePts:(int)pts ptsCount:(int)ptsCount seq:(int)seq
{
#if TGUseModernNetworking
    [_updateService updatePts:pts ptsCount:ptsCount seq:seq];
#else
    [[TGSession instance] _updatePts:pts date:date seq:seq];
#endif
}

- (void)addUpdates:(id)updates
{
    [_updateService addUpdates:updates];
}

- (void)switchBackends
{
#if TGUseModernNetworking
    if (_isTestingEnvironment)
        [_settingsKeychain setObject:@"production" forKey:@"environmentId" group:@"environment"];
    else
        [_settingsKeychain setObject:@"testing" forKey:@"environmentId" group:@"environment"];
    
    [TGTelegraphInstance willSwitchBackends];
    _exit(0);
#else
    [[TGSession instance] switchBackends];
#endif
}

- (void)addRequest:(MTRequest *)request
{
    NSString *rpcClass = request.body != nil
    ? NSStringFromClass([request.body class])
    : @"nil";
    
    if (_requestService == nil)
    {
        
        [_postponedRequests addObject:request];
        
        
        
        return;
    }
    
    NSAssert(_requestService != nil, @"requestService should not be nil");
    
    
    [_requestService addRequest:request];
    
    
}

- (NSObject *)performRpc:(TLMetaRpc *)rpc completionBlock:(void (^)(id<TLObject> response, int64_t responseTime, MTRpcError *error))completionBlock progressBlock:(void (^)(int length, float progress))progressBlock requiresCompletion:(bool)requiresCompletion requestClass:(int)requestClass
{
    return [self performRpc:rpc
            completionBlock:completionBlock
              progressBlock:progressBlock
         requiresCompletion:requiresCompletion
               requestClass:requestClass
               datacenterId:INT_MAX];
}

- (NSObject *)performRpc:(TLMetaRpc *)rpc completionBlock:(void (^)(id<TLObject> response, int64_t responseTime, MTRpcError *error))completionBlock progressBlock:(void (^)(int length, float progress))progressBlock requiresCompletion:(bool)requiresCompletion requestClass:(int)requestClass datacenterId:(int)datacenterId
{
    return [self performRpc:rpc
            completionBlock:completionBlock
              progressBlock:progressBlock
              quickAckBlock:nil
         requiresCompletion:requiresCompletion
               requestClass:requestClass
               datacenterId:datacenterId];
}

- (int64_t)peerIdFromInputPeer:(TLInputPeer *)peer {
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]]) {
        return TGPeerIdFromChannelId(((TLInputPeer$inputPeerChannel *)peer).channel_id);
    } else if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]]) {
        return TGPeerIdFromGroupId(((TLInputPeer$inputPeerChat *)peer).chat_id);
    } else if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]]) {
        return ((TLInputPeer$inputPeerUser *)peer).user_id;
    } else if ([peer isKindOfClass:[TLInputPeer$inputPeerSelf class]]) {
        return TGTelegraphInstance.clientUserId;
    }
    
    return 0;
}

- (NSObject *)performRpc:(TLMetaRpc *)rpc completionBlock:(void (^)(id<TLObject> response, int64_t responseTime, MTRpcError *error))completionBlock progressBlock:(void (^)(int length, float progress))__unused progressBlock quickAckBlock:(void (^)())quickAckBlock requiresCompletion:(bool)__unused requiresCompletion requestClass:(int)requestClass datacenterId:(int)datacenterId
{
    CFAbsoluteTime rpcPerfStart = CFAbsoluteTimeGetCurrent();
    NSString *rpcPerfClass = NSStringFromClass([rpc class]);

#if TGUseModernNetworking
    if (datacenterId != INT_MAX && datacenterId != 1)
        return nil;
    

    TGIOS6NormalizeRpcForModernApi(rpc);


    
    static bool collectingForwardMessages = false;
    static NSMutableDictionary *collectedForwardMessagesByPeerIdsString = nil;
    static SDisposableSet *currentCollectedForwardMessagesDisposable = nil;
    
    if ([rpc isKindOfClass:[TLRPCmessages_forwardMessages class]])
    {
        TLRPCmessages_forwardMessages *concreteRpc = (TLRPCmessages_forwardMessages *)rpc;
        int64_t fromPeerId = [self peerIdFromInputPeer:concreteRpc.from_peer];
        int64_t toPeerId = [self peerIdFromInputPeer:concreteRpc.to_peer];
        NSString *key = [[NSString alloc] initWithFormat:@"%lld:%lld:%d", fromPeerId, toPeerId, concreteRpc.flags];
        
        NSDictionary *forwardMessages = @{@"rpc": rpc, @"completion": [completionBlock copy]};
        
        if (collectingForwardMessages)
        {
            NSMutableArray *collectedForwardMessages = collectedForwardMessagesByPeerIdsString[key];
            if (collectedForwardMessages == nil) {
                collectedForwardMessages = [[NSMutableArray alloc] init];
                collectedForwardMessagesByPeerIdsString[key] = collectedForwardMessages;
            }
            
            [collectedForwardMessages addObject:forwardMessages];
        }
        else
        {
            collectingForwardMessages = true;
            
            collectedForwardMessagesByPeerIdsString = [[NSMutableDictionary alloc] init];
            
            collectedForwardMessagesByPeerIdsString[key] = [[NSMutableArray alloc] initWithArray:@[forwardMessages]];
            
            currentCollectedForwardMessagesDisposable = [[SDisposableSet alloc] init];
            
            dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
            {
                collectingForwardMessages = false;
                [collectedForwardMessagesByPeerIdsString enumerateKeysAndObjectsUsingBlock:^(id key, NSArray *records, __unused BOOL *stop) {
                    if (records.count == 0) {
                        return;
                    }
                    
                    id fromPeer = nil;
                    id toPeer = nil;
                    int32_t flags = 0;
                    
                    NSMutableDictionary *messageDescsByKey = [[NSMutableDictionary alloc] init];
                    for (NSDictionary *desc in records)
                    {
                        TLRPCmessages_forwardMessages *rpc = desc[@"rpc"];

                        if (fromPeer == nil) {
                            fromPeer = rpc.from_peer;
                            toPeer = rpc.to_peer;
                            flags = rpc.flags;
                        }
                        
                        NSMutableDictionary *messageDescs = messageDescsByKey[key];
                        if (messageDescs == nil)
                        {
                            messageDescs = [[NSMutableDictionary alloc] init];
                            messageDescsByKey[key] = messageDescs;
                            messageDescs[@"to_peer"] = rpc.to_peer;
                            messageDescs[@"from_peer"] = rpc.from_peer;
                        }
                        
                        NSMutableArray *messageIds = messageDescs[@"messageIds"];
                        if (messageIds == nil)
                        {
                            messageIds = [[NSMutableArray alloc] init];
                            messageDescs[@"messageIds"] = messageIds;
                        }
                        NSMutableArray *messageRandomIds = messageDescs[@"messageRandomIds"];
                        if (messageRandomIds == nil)
                        {
                            messageRandomIds = [[NSMutableArray alloc] init];
                            messageDescs[@"messageRandomIds"] = messageRandomIds;
                        }
                        NSMutableArray *completions = messageDescs[@"completions"];
                        if (completions == nil)
                        {
                            completions = [[NSMutableArray alloc] init];
                            messageDescs[@"completions"] = completions;
                        }
                        [messageIds addObjectsFromArray:rpc.n_id];
                        [messageRandomIds addObjectsFromArray:rpc.random_id];
                        [completions addObject:desc[@"completion"]];
                    }
                    
                    for (id key in messageDescsByKey.allKeys)
                    {
                        NSDictionary *messageDescs = messageDescsByKey[key];
                        NSArray *messageIds = messageDescs[@"messageIds"];
                        NSArray *messageRandomIds = messageDescs[@"messageRandomIds"];
                        
                        TLRPCmessages_forwardMessages$messages_forwardMessages *forwardMessages = [[TLRPCmessages_forwardMessages$messages_forwardMessages alloc] init];
                        forwardMessages.n_id = messageIds;
                        forwardMessages.from_peer = fromPeer;
                        forwardMessages.to_peer = toPeer;
                        forwardMessages.random_id = messageRandomIds;
                        forwardMessages.flags = flags;
                        
                        MTRequest *request = [[MTRequest alloc] init];
                        request.body = forwardMessages;
                        [request setCompleted:^(TLUpdates *updates, NSTimeInterval timestamp, id error)
                         {
                             [ActionStageInstance() dispatchOnStageQueue:^
                              {
                                  NSUInteger index = 0;
                                  for (void (^messageCompletionBlock)(id, int64_t, id) in messageDescs[@"completions"])
                                  {
                                      TLUpdates$updates *syntheticUpdates = nil;
                                      
                                      if ([updates isKindOfClass:[TLUpdates$updates class]])
                                      {
                                          TLUpdates$updates *concreteUpdates = (TLUpdates$updates *)updates;
                                          
                                          int32_t pts = 0;
                                          int32_t pts_count = 0;
                                          TLMessage *message = [concreteUpdates messageAtIndex:index pts:&pts pts_count:&pts_count];
                                          
                                          syntheticUpdates = [[TLUpdates$updates alloc] init];
                                          if (message != nil)
                                          {
                                              syntheticUpdates.chats = concreteUpdates.chats;
                                              syntheticUpdates.users = concreteUpdates.users;
                                              
                                              if ([toPeer isKindOfClass:[TLPeer$peerChannel class]]) {
                                                  TLUpdate$updateNewChannelMessage *updateNewChannelMessage = [[TLUpdate$updateNewChannelMessage alloc] init];
                                                  updateNewChannelMessage.message = message;
                                                  updateNewChannelMessage.pts = pts;
                                                  updateNewChannelMessage.pts_count = pts_count;
                                                  syntheticUpdates.updates = @[updateNewChannelMessage];
                                              } else {
                                                  TLUpdate$updateNewMessage *updateNewMessage = [[TLUpdate$updateNewMessage alloc] init];
                                                  updateNewMessage.message = message;
                                                  updateNewMessage.pts = pts;
                                                  updateNewMessage.pts_count = pts_count;
                                                  syntheticUpdates.updates = @[updateNewMessage];
                                              }
                                          }
                                      }
                                      
                                      messageCompletionBlock(error == nil ? syntheticUpdates : nil, (int64_t)(timestamp * 4294967296.0), error);
                                      
                                      index++;
                                  }
                              }];
                         }];
                        
                        [self addRequest:request];
                        
                        id internalId = request.internalId;
                        [currentCollectedForwardMessagesDisposable add:[[SBlockDisposable alloc] initWithBlock:^
                        {
                            [_requestService removeRequestByInternalId:internalId];
                            
                            for (void (^messageCompletionBlock)(id, int64_t, id) in messageDescs[@"completions"])
                            {
                                messageCompletionBlock(nil, 0, [[TLRpcError$rpc_error alloc] init]);
                            }
                        }]];
                        
                        currentCollectedForwardMessagesDisposable = nil;
                    }
                }];
                [collectedForwardMessagesByPeerIdsString removeAllObjects];
            });
        }
        
        return currentCollectedForwardMessagesDisposable;
    }
    else
    {
        MTRequest *request = [[MTRequest alloc] init];
        request.passthroughPasswordEntryError = requestClass & TGRequestClassPassthroughPasswordNeeded;
        request.dependsOnPasswordEntry = (requestClass & TGRequestClassIgnorePasswordEntryRequired) == 0;
        request.body = rpc;
        [request setCompleted:^(id result, NSTimeInterval timestamp, id error)
        {
            CFAbsoluteTime responseReceivedAt = CFAbsoluteTimeGetCurrent();
            bool messageSend = [rpc isKindOfClass:[TLRPCmessages_sendMedia_manual class]] || [rpc isKindOfClass:[TLRPCmessages_sendMessage_manual class]] || [rpc isKindOfClass:[TLRPCmessages_forwardMessages class]] || [rpc isKindOfClass:[TLRPCmessages_sendInlineBotResult class]];
            if (messageSend)
                TGLog(@"SENDSTATE response rpc=%@ result=%@ error=%@ elapsed=%.0fms", rpcPerfClass, NSStringFromClass([result class]), error == nil ? @"none" : NSStringFromClass([error class]), (responseReceivedAt - rpcPerfStart) * 1000.0);
            if (error != nil)
                TGLog(@"TRACE rpc error path=performRpc rpc=%@ error=%@", TGIOS6DescribeRpcForError(rpc), error);
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                if (completionBlock != nil)
                    completionBlock(result, (int64_t)(timestamp * 4294967296.0), error);
            }];
        }];
        
        if (quickAckBlock != nil)
        {
            bool messageSend = [rpc isKindOfClass:[TLRPCmessages_sendMedia_manual class]] || [rpc isKindOfClass:[TLRPCmessages_sendMessage_manual class]];
            if (messageSend)
            {
                [request setAcknowledgementReceived:^
                {
                    TGLog(@"SENDSTATE quickack rpc=%@ elapsed=%.0fms", rpcPerfClass, (CFAbsoluteTimeGetCurrent() - rpcPerfStart) * 1000.0);
                    quickAckBlock();
                }];
            }
            else
                [request setAcknowledgementReceived:quickAckBlock];
        }
        
        static NSArray *sequentialMessageClasses = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            sequentialMessageClasses = @[
                [TLRPCmessages_sendMessage_manual class],
                [TLRPCmessages_sendMedia_manual class],
                [TLRPCmessages_forwardMessages class],
                [TLRPCmessages_sendEncrypted class],
                [TLRPCmessages_sendEncryptedFile class],
                [TLRPCmessages_sendInlineBotResult class]
            ];
        });
        
        for (Class sequentialClass in sequentialMessageClasses)
        {
            if ([rpc isKindOfClass:sequentialClass])
            {
                [request setShouldDependOnRequest:^bool (MTRequest *anotherRequest)
                {
                    for (Class sequentialClass in sequentialMessageClasses)
                    {
                        if ([anotherRequest.body isKindOfClass:sequentialClass])
                            return true;
                    }
                    
                    return false;
                }];
                
                break;
            }
        }
        
        NSString *requestClassName = NSStringFromClass([request.body class]);
        bool isAuthRequest = [request.body isKindOfClass:[TLRPCauth_sendCode class]] || [request.body isKindOfClass:[TLRPCauth_resendCode$auth_resendCode class]] || [requestClassName hasPrefix:@"TGIOS6Auth"] || [requestClassName hasPrefix:@"TLRPCauth_signIn"] || [requestClassName hasPrefix:@"TLRPCauth_signUp"];
        if (isAuthRequest)
            request.dependsOnPasswordEntry = false;
        
        if ([request.body isKindOfClass:[TLRPCmessages_sendMessage_manual class]] || [request.body isKindOfClass:[TLRPCmessages_sendMedia_manual class]] || [request.body isKindOfClass:[TLRPCmessages_forwardMessages class]] || [request.body isKindOfClass:[TLRPCmessages_sendEncrypted class]] || [request.body isKindOfClass:[TLRPCmessages_sendInlineBotResult class]] || isAuthRequest) {
            request.hasHighPriority = true;
        }
        
        bool continueOnFloodWait = true;
        if ([request.body isKindOfClass:[TLRPCauth_sendCode class]] || [request.body isKindOfClass:[TLRPCauth_resendCode$auth_resendCode class]] || [requestClassName isEqualToString:@"TGIOS6AuthSendCode"]) {
            continueOnFloodWait = false;
        }
        
        [request setShouldContinueExecutionWithErrorContext:^bool(MTRequestErrorContext *errorContext)
        {
            if (!continueOnFloodWait && errorContext.floodWaitSeconds > 0) {
                return false;
            }
            if (requestClass & TGRequestClassFailOnServerErrorsImmediately)
                return false;
            if (requestClass & 256)
                return errorContext.internalServerErrorCount < 5;
            if (requestClass & 512)
                return false;
            return true;
        }];
        

        [self addRequest:request];


        id internalId = request.internalId;



        return internalId;
    }
#else
    return [[TGSession instance] performRpc:rpc completionBlock:completionBlock progressBlock:progressBlock quickAckBlock:quickAckBlock requiresCompletion:requiresCompletion requestClass:requestClass datacenterId:datacenterId];
#endif
}

- (void)cancelRpc:(id)token
{
#if TGUseModernNetworking
    if ([token conformsToProtocol:@protocol(SDisposable)])
    {
        [(id<SDisposable>)token dispose];
        return;
    }

    for (NSInteger index = (NSInteger)_postponedRequests.count - 1; index >= 0; index--)
    {
        MTRequest *request = [_postponedRequests objectAtIndex:(NSUInteger)index];
        if ([request.internalId isEqual:token])
        {
            [_postponedRequests removeObjectAtIndex:(NSUInteger)index];
            return;
        }
    }

    [_requestService removeRequestByInternalId:token];
#else
    [[TGSession instance] cancelRpc:token notifyServer:true];
#endif
}

- (bool)isNetworkAvailable
{
#if TGUseModernNetworking
    return _isNetworkAvailable;
#else
    return ![[TGSession instance] isOffline];
#endif
}

- (bool)isConnecting
{
#if TGUseModernNetworking
    return !_isConnected;
#else
    return [[TGSession instance] isConnecting];
#endif
}

- (bool)isUpdating
{
#if TGUseModernNetworking
    return _isUpdatingConnectionContext || _isPerformingServiceTasks;
#else
    return [[TGSession instance] isWaitingForFirstData];
#endif
}

- (void)wakeUpWithCompletion:(void (^)())completion
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        
        
        [_currentWakeUpCompletions addObject:[completion copy]];
        
        _completeWakeUpToken++;
        int token = _completeWakeUpToken;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
        {
            if (token == _completeWakeUpToken)
            {
                if ([self _isReadyToBeSuspended])
                    [self completeWakeUpIfAny:@"2s match"];
            }
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
        {
            if (token == _completeWakeUpToken)
            {
                [self completeWakeUpIfAny:@"10s timeout"];
            }
        });
    }];
}

- (void)completeWakeUpIfAny:(NSString *)reason
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_currentWakeUpCompletions.count != 0)
        {
            _completeWakeUpToken++;
            
            
            for (dispatch_block_t block in _currentWakeUpCompletions)
            {
                block();
            }
            
            [_currentWakeUpCompletions removeAllObjects];
        }
    }];
}

- (void)requestMessageServiceAuthorizationRequired:(MTRequestMessageService *)__unused requestMessageService
{
    int32_t userId = TGTelegraphInstance.clientUserId;
    bool activated = TGTelegraphInstance.clientIsActivated;
    MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:_mtProto.datacenterId];
    TGLog(@"AUTH authorizationRequired userId=%d activated=%d dc=%d authKeyId=%llx", userId, activated ? 1 : 0, (int)_mtProto.datacenterId, (unsigned long long)authInfo.authKeyId);

    if (userId == 0 || !activated || _authorizationRecoveryInProgress)
        return;

    _authorizationRecoveryInProgress = true;
    [_mtProto resetSessionInfo];
    [_context removeAllAuthTokens];

    [ActionStageInstance() dispatchOnStageQueue:^
    {
        TGLog(@"AUTH authorizationRequired.logoutActor userId=%d", userId);
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/auth/logout/(%d)", userId] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:true] forKey:@"force"] watcher:TGTelegraphInstance];
    }];
}

- (void)mtProtoNetworkAvailabilityChanged:(MTProto *)__unused mtProto isNetworkAvailable:(bool)isNetworkAvailable
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _isNetworkAvailable = isNetworkAvailable;
        [self dispatchNetworkState];
    }];
}
- (void)mtProtoConnectionStateChanged:(MTProto *)__unused mtProto state:(MTProtoConnectionState *)state
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _isConnected = state.isConnected;
        _isUsingProxy = state.proxyAddress.length != 0;
        _proxyHasConnectionIssues = _isUsingProxy && state.proxyHasConnectionIssues;
        [self dispatchNetworkState];
    }];
}

- (void)mtProtoConnectionContextUpdateStateChanged:(MTProto *)__unused mtProto isUpdatingConnectionContext:(bool)isUpdatingConnectionContext
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _isUpdatingConnectionContext = isUpdatingConnectionContext;
        [self dispatchNetworkState];
    }];
}

- (void)mtProtoServiceTasksStateChanged:(MTProto *)__unused mtProto isPerformingServiceTasks:(bool)isPerformingServiceTasks
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _isPerformingServiceTasks = isPerformingServiceTasks;
        _serviceTasksWatchdogToken++;
        
        if (isPerformingServiceTasks)
        {
            int token = _serviceTasksWatchdogToken;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), [ActionStageInstance() globalStageDispatchQueue], ^
            {
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    if (token == _serviceTasksWatchdogToken && _isPerformingServiceTasks && !_isUpdatingConnectionContext)
                    {
                        _isPerformingServiceTasks = false;
                        _serviceTasksWatchdogToken++;
                        [self dispatchNetworkState];
                    }
                }];
            });
        }
        
        [self dispatchNetworkState];
    }];
}

- (bool)_isReadyToBeSuspended
{
    int state = [ActionStageInstance() requestActorStateNow:@"/tg/service/updatestate"] ? 1 : 0;
    if (_isUpdatingConnectionContext || _isPerformingServiceTasks)
        state |= 1;
    if (!_isConnected)
        state |= 2;
    if (!_isNetworkAvailable)
        state |= 4;
    
    return state == 0;
}

- (void)dispatchNetworkState
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _dispatchNetworkStateToken++;
        int token = _dispatchNetworkStateToken;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), [ActionStageInstance() globalStageDispatchQueue], ^
        {
            if (token != _dispatchNetworkStateToken)
                return;
            
            int state = [ActionStageInstance() requestActorStateNow:@"/tg/service/updatestate"] ? 1 : 0;
            if (_isUpdatingConnectionContext || _isPerformingServiceTasks)
                state |= 1;
            if (!_isConnected)
                state |= 2;
            if (!_isNetworkAvailable)
                state |= 4;
            if (_isUsingProxy)
                state |= 8;
            if (_proxyHasConnectionIssues)
                state |= 16;
            
            [ActionStageInstance() dispatchResource:@"/tg/service/synchronizationstate" resource:[[SGraphObjectNode alloc] initWithObject:[NSNumber numberWithInt:state]]];
        });
        
        int wakeupToken = _completeWakeUpToken;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
        {
            if (wakeupToken == _completeWakeUpToken)
            {
                if ([self _isReadyToBeSuspended])
                    [self completeWakeUpIfAny:@"state 1 match"];
            }
        });
    }];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        int state = [((SGraphObjectNode *)resource).object intValue];
        if (state == 0 && _isConnected && !_isUpdatingConnectionContext && !_isPerformingServiceTasks && _isNetworkAvailable)
            [self completeWakeUpIfAny:@"state 2 match"];
    }
}

- (SSignal *)downloadWorkerForDatacenterId:(NSInteger)datacenterId type:(TGNetworkMediaTypeTag)type {
    return [self downloadWorkerForDatacenterId:datacenterId type:type isCdn:false];
}

- (SSignal *)downloadWorkerForDatacenterId:(NSInteger)datacenterId type:(TGNetworkMediaTypeTag)type isCdn:(bool)isCdn {
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {   
        id token = [self requestDownloadWorkerForDatacenterId:datacenterId type:type isCdn:isCdn completion:^(TGNetworkWorkerGuard *worker)
        {
            [subscriber putNext:worker];
            [subscriber putCompletion];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [self cancelDownloadWorkerRequestByToken:token];
        }];
    }];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc
{
    return [self requestSignal:rpc continueOnServerErrors:false];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc continueOnServerErrors:(bool)continueOnServerErrors
{
    return [self requestSignal:rpc continueOnServerErrors:continueOnServerErrors failOnFloodErrors:false];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc continueOnServerErrors:(bool)continueOnServerErrors failOnFloodErrors:(bool)failOnFloodErrors {
    return [self requestSignal:rpc continueOnServerErrors:continueOnServerErrors failOnFloodErrors:failOnFloodErrors failOnServerErrorsImmediately:false];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc continueOnServerErrors:(bool)continueOnServerErrors failOnFloodErrors:(bool)failOnFloodErrors failOnServerErrorsImmediately:(bool)failOnServerErrorsImmediately {
    return [self requestSignal:rpc requestClass:(continueOnServerErrors ? 0 : TGRequestClassFailOnServerErrors) | (failOnFloodErrors ? TGRequestClassFailOnFloodErrors : 0) | (failOnServerErrorsImmediately ? TGRequestClassFailOnServerErrorsImmediately : 0)];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc requestClass:(int)requestClass
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        TGIOS6NormalizeRpcForModernApi(rpc);
        MTRequest *request = [[MTRequest alloc] init];
        request.body = rpc;
        [request setCompleted:^(id result, __unused NSTimeInterval timestamp, id error)
        {
            if (error == nil)
            {
                [subscriber putNext:result];
                [subscriber putCompletion];
            }
            else
            {
                TGLog(@"TRACE rpc error path=requestSignal rpc=%@ error=%@", TGIOS6DescribeRpcForError(rpc), error);
                NSString *errorText = [[NSString alloc] initWithFormat:@"%@", error];
                if ([errorText rangeOfString:@"CHANNEL_INVALID"].location != NSNotFound ||
                    [errorText rangeOfString:@"PEER_ID_INVALID"].location != NSNotFound ||
                    [errorText rangeOfString:@"FILE_REFERENCE"].location != NSNotFound ||
                    [errorText rangeOfString:@"MEDIA"].location != NSNotFound)
                {
                    TGLog(@"RPC error rpc=%@ error=%@", TGIOS6DescribeRpcForError(rpc), error);
                }
                [subscriber putError:error];
            }
        }];
        
        request.dependsOnPasswordEntry = (requestClass & TGRequestClassIgnorePasswordEntryRequired) == 0;
        
        static NSArray *sequentialMessageClasses = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            sequentialMessageClasses = @[
                [TLRPCmessages_sendMessage_manual class],
                [TLRPCmessages_sendMedia_manual class],
                [TLRPCmessages_forwardMessages class],
                [TLRPCmessages_sendEncrypted class],
                [TLRPCmessages_sendEncryptedFile class],
                [TLRPCmessages_sendInlineBotResult class]
            ];
        });
        
        for (Class sequentialClass in sequentialMessageClasses)
        {
            if ([rpc isKindOfClass:sequentialClass])
            {
                [request setShouldDependOnRequest:^bool (MTRequest *anotherRequest)
                {
                    for (Class sequentialClass in sequentialMessageClasses)
                    {
                        if ([anotherRequest.body isKindOfClass:sequentialClass])
                            return true;
                    }
                    
                    return false;
                }];
                
                break;
            }
        }
        
        if ([request.body isKindOfClass:[TLRPCmessages_sendMessage_manual class]] || [request.body isKindOfClass:[TLRPCmessages_forwardMessages class]] || [request.body isKindOfClass:[TLRPCmessages_sendEncrypted class]] || [request.body isKindOfClass:[TLRPCmessages_sendInlineBotResult class]]) {
            request.hasHighPriority = true;
        }
            
        [request setShouldContinueExecutionWithErrorContext:^bool(__unused MTRequestErrorContext *errorContext)
        {
            if (errorContext.floodWaitSeconds > 0)
            {
                if (requestClass & TGRequestClassFailOnFloodErrors)
                    return false;
            }
            
            if (requestClass & TGRequestClassFailOnServerErrorsImmediately) {
                return false;
            }
            
            if (!(requestClass & TGRequestClassFailOnServerErrors))
                return errorContext.internalServerErrorCount < 5;
            return true;
        }];
        
        [self addRequest:request];
        id requestToken = request.internalId;
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [_requestService removeRequestByInternalId:requestToken];
        }];
    }];
}

- (SSignal *)requestSignalWithResponseTimestamp:(TLMetaRpc *)rpc {
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        TGIOS6NormalizeRpcForModernApi(rpc);
        MTRequest *request = [[MTRequest alloc] init];
        request.body = rpc;
        [request setCompleted:^(id result, NSTimeInterval timestamp, id error)
        {
            if (error == nil && result != nil)
            {
                [subscriber putNext:@{@"result": result, @"timestamp": @(timestamp)}];
                [subscriber putCompletion];
            }
            else
            {
                TGLog(@"TRACE rpc error path=requestSignalTimestamp rpc=%@ error=%@", TGIOS6DescribeRpcForError(rpc), error);
                NSString *errorText = [[NSString alloc] initWithFormat:@"%@", error];
                if ([errorText rangeOfString:@"CHANNEL_INVALID"].location != NSNotFound ||
                    [errorText rangeOfString:@"PEER_ID_INVALID"].location != NSNotFound ||
                    [errorText rangeOfString:@"FILE_REFERENCE"].location != NSNotFound ||
                    [errorText rangeOfString:@"MEDIA"].location != NSNotFound)
                {
                    TGLog(@"RPC error rpc=%@ error=%@", TGIOS6DescribeRpcForError(rpc), error);
                }
                [subscriber putError:error];
            }
        }];
        
        int requestClass = 0;
        
        request.dependsOnPasswordEntry = (requestClass & TGRequestClassIgnorePasswordEntryRequired) == 0;
        
        static NSArray *sequentialMessageClasses = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            sequentialMessageClasses = @[
                                         [TLRPCmessages_sendMessage_manual class],
                                         [TLRPCmessages_sendMedia_manual class],
                                         [TLRPCmessages_forwardMessages class],
                                         [TLRPCmessages_sendEncrypted class],
                                         [TLRPCmessages_sendEncryptedFile class],
                                         [TLRPCmessages_sendInlineBotResult class]
                                         ];
        });
        
        for (Class sequentialClass in sequentialMessageClasses)
        {
            if ([rpc isKindOfClass:sequentialClass])
            {
                [request setShouldDependOnRequest:^bool (MTRequest *anotherRequest)
                {
                    for (Class sequentialClass in sequentialMessageClasses)
                    {
                        if ([anotherRequest.body isKindOfClass:sequentialClass])
                            return true;
                    }
                    
                    return false;
                }];
                
                break;
            }
        }
        
        if ([request.body isKindOfClass:[TLRPCmessages_sendMessage_manual class]] || [request.body isKindOfClass:[TLRPCmessages_forwardMessages class]] || [request.body isKindOfClass:[TLRPCmessages_sendEncrypted class]] || [request.body isKindOfClass:[TLRPCmessages_sendInlineBotResult class]]) {
            request.hasHighPriority = true;
        }
        
        [request setShouldContinueExecutionWithErrorContext:^bool(__unused MTRequestErrorContext *errorContext)
        {
            if (errorContext.floodWaitSeconds > 0)
            {
                if (requestClass & TGRequestClassFailOnFloodErrors)
                    return false;
            }
            
            if (!(requestClass & TGRequestClassFailOnServerErrors))
                return errorContext.internalServerErrorCount < 5;
            return true;
        }];
        
        [self addRequest:request];
        id requestToken = request.internalId;
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [_requestService removeRequestByInternalId:requestToken];
        }];
    }];
}

- (SSignal *)requestSignal:(TLMetaRpc *)rpc worker:(TGNetworkWorkerGuard *)worker
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        TGIOS6NormalizeRpcForModernApi(rpc);
        MTRequest *request = [[MTRequest alloc] init];
        request.body = rpc;
        [request setCompleted:^(id result, __unused NSTimeInterval timestamp, id error)
        {
            if (error == nil)
            {
                [subscriber putNext:result];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:error];
            }
        }];
        
        [request setProgressUpdated:^(float value, __unused NSUInteger completeSize)
        {
            [subscriber putNext:@(value)];
        }];
        
        [request setShouldContinueExecutionWithErrorContext:^bool(__unused MTRequestErrorContext *errorContext)
        {
            return true;
        }];
        
        [(TGNetworkWorker *)worker.worker addRequest:request];
        id requestToken = request.internalId;
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [(TGNetworkWorker *)worker.worker cancelRequestById:requestToken];
        }];
    }];
}

- (NSString *)extractNetworkErrorType:(id)error
{
    if ([error isKindOfClass:[TLError$richError class]])
    {
        if (((TLError$richError *)error).type.length != 0)
            return ((TLError$richError *)error).type;
        
        NSString *errorDescription = nil;
        if ([error isKindOfClass:[TLError$error class]])
            errorDescription = ((TLError$error *)error).text;
        else if ([error isKindOfClass:[TLError$richError class]])
            errorDescription = ((TLError$richError *)error).n_description;
        
        NSMutableString *errorString = [[NSMutableString alloc] init];
        for (int i = 0; i < (int)errorDescription.length; i++)
        {
            unichar c = [errorDescription characterAtIndex:i];
            if (c == ':')
                break;
            
            [errorString appendString:[[NSString alloc] initWithCharacters:&c length:1]];
        }
        
        if (errorString.length != 0)
            return errorString;
    }
    else if ([error isKindOfClass:[MTRpcError class]])
        return ((MTRpcError *)error).errorDescription;
    
    return nil;
}

- (int32_t)extractNetworkErrorCode:(id)error
{
    if ([error isKindOfClass:[TLError class]])
        return ((TLError *)error).code;
    else if ([error isKindOfClass:[MTRpcError class]])
        return ((MTRpcError *)error).errorCode;
    return 0;
}
    
- (MTSignal *)fetchContextDatacenterPublicKeys:(MTContext *)__unused context datacenterId:(NSInteger)datacenterId {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        TLRPChelp_getCdnConfig$help_getCdnConfig *getCdnConfig = [[TLRPChelp_getCdnConfig$help_getCdnConfig alloc] init];
        
        id<SDisposable> disposable = [[self requestSignal:getCdnConfig] startWithNext:^(TLCdnConfig *result) {
            NSMutableArray *publicKeys = [[NSMutableArray alloc] init];
            for (TLCdnPublicKey *publicKey in result.public_keys) {
                if (publicKey.dc_id == datacenterId) {
                    [publicKeys addObject:@{@"key": publicKey.public_key, @"fingerprint": @(MTRsaFingerprint(publicKey.public_key))}];
                }
            }
            [subscriber putNext:publicKeys];
            [subscriber putCompletion];
        }];
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [disposable dispose];
        }];
    }];
}

- (void)contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    if (context == _context && datacenterId == _mtProto.datacenterId)
    {
        bool passwordRequired = [context isPasswordInputRequiredForDatacenterWithId:datacenterId];
        TGDispatchOnMainThread(^
        {
            if (passwordRequired)
            {
                if (TGIOS6QRLoginFlowActive())
                {
                    return;
                }

                bool alreadyPresentedEntryController = false;
                
                if ([TGAppDelegateInstance.loginNavigationController.topViewController isKindOfClass:[TGLoginPasswordController class]])
                {
                    alreadyPresentedEntryController = true;
                }
                if (_currentPasswordEntryWindow != nil)
                    alreadyPresentedEntryController = true;
                
                if (!alreadyPresentedEntryController)
                {
                    if (TGAppDelegateInstance.loginNavigationController.presentingViewController != nil)
                    {
                        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:TGAppDelegateInstance.loginNavigationController.viewControllers];
                        [viewControllers removeLastObject];
                        [viewControllers addObject:[[TGLoginPasswordController alloc] init]];
                        [TGAppDelegateInstance.loginNavigationController setViewControllers:viewControllers animated:true];
                    }
                    else if (_currentPasswordEntryWindow == nil)
                    {
                        _currentPasswordEntryWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                        
                        TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[[[TGLoginPasswordController alloc] init]] navigationBarClass:[TGTransparentNavigationBar class]];
                        
                        _currentPasswordEntryWindow.rootViewController = navigationController;
                        _currentPasswordEntryWindow.hidden = false;
                        
                        CGRect defaultFrame = _currentPasswordEntryWindow.rootViewController.view.frame;
                        CGRect frame = defaultFrame;
                        frame.origin.y = defaultFrame.size.height;
                        _currentPasswordEntryWindow.rootViewController.view.frame = frame;
                        [UIView animateWithDuration:0.3 delay:0.0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                        {
                            _currentPasswordEntryWindow.rootViewController.view.frame = defaultFrame;
                        } completion:nil];
                    }
                }
            }
            else if (_currentPasswordEntryWindow != nil)
            {
                CGRect defaultFrame = _currentPasswordEntryWindow.rootViewController.view.frame;
                CGRect frame = defaultFrame;
                frame.origin.y = defaultFrame.size.height;
                UIWindow *window = _currentPasswordEntryWindow;
                _currentPasswordEntryWindow = nil;
                [UIView animateWithDuration:0.3 delay:0.0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                {
                    window.rootViewController.view.frame = frame;
                } completion:^(__unused BOOL finished)
                {
                    window.hidden = true;
                }];
            }
        });
    }
}

- (NSString *)baseUsagePath {
    return [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"network-usage"];
}

- (MTNetworkUsageCalculationInfo *)dataUsageInfo {
    return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyDataIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyDataOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyDataIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyDataOutgoingOther];
}

- (MTNetworkUsageCalculationInfo *)mediaUsageInfoForType:(TGNetworkMediaTypeTag)type {
    switch (type) {
        case TGNetworkMediaTypeTagGeneric:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaGenericIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaGenericOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaGenericIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaGenericOutgoingOther];
        case TGNetworkMediaTypeTagImage:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaImageIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaImageOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaImageIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaImageOutgoingOther];
        case TGNetworkMediaTypeTagVideo:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaVideoIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaVideoOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaVideoIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaVideoOutgoingOther];
        case TGNetworkMediaTypeTagAudio:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaAudioIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaAudioOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaAudioIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaAudioOutgoingOther];
        case TGNetworkMediaTypeTagDocument:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaDocumentIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaDocumentOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaDocumentIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaDocumentOutgoingOther];
        case TGNetworkMediaTypeTagCall:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyCallIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyCallOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyCallIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyCallOutgoingOther];
        default:
            return [[MTNetworkUsageCalculationInfo alloc] initWithFilePath:[self baseUsagePath] incomingWWANKey:TGTelegramNetworkUsageKeyMediaGenericIncomingWWAN outgoingWWANKey:TGTelegramNetworkUsageKeyMediaGenericOutgoingWWAN incomingOtherKey:TGTelegramNetworkUsageKeyMediaGenericIncomingOther outgoingOtherKey:TGTelegramNetworkUsageKeyMediaGenericOutgoingOther];
    }
}

- (NSString *)cellularUsageResetPath {
    return [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"cellular-usage-reset"];
}

- (NSString *)wifiUsageResetPath {
    return [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"wifi-usage-reset"];
}

- (OGOnegramCoreMode)onegramCoreMode
{
    return [OGOnegramCore sharedCore].mode;
}

- (void)setOnegramCoreMode:(OGOnegramCoreMode)mode
{
    [[OGOnegramCore sharedCore] setMode:mode];
    [self refreshOnegramCoreSettings];
}

- (bool)onegramWebSocketProxyEnabled
{
    return self.onegramCoreMode == OGOnegramCoreModeWebSocket;
}

- (void)setOnegramWebSocketProxyEnabled:(bool)enabled
{
    [self setOnegramCoreMode:enabled ? OGOnegramCoreModeWebSocket : OGOnegramCoreModeNone];
}

- (void)onegramCoreDidChange:(NSNotification *)notification
{
    [self refreshOnegramCoreSettings];
}

- (void)onegramWebSocketStatusChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    id connection = userInfo[MTTcpConnectionOnegramWebSocketConnectionKey];
    OGOnegramCore *core = [OGOnegramCore sharedCore];
    switch ((MTTcpConnectionOnegramWebSocketEvent)[userInfo[MTTcpConnectionOnegramWebSocketEventKey] intValue])
    {
        case MTTcpConnectionOnegramWebSocketEventOpened:
            [core webSocketConnectionOpened:connection];
            break;
        case MTTcpConnectionOnegramWebSocketEventClosed:
            [core webSocketConnectionClosed:connection];
            break;
        case MTTcpConnectionOnegramWebSocketEventUnavailable:
            [core webSocketUnavailableWithError:userInfo[MTTcpConnectionOnegramWebSocketErrorKey]];
            break;
    }
}

- (void)refreshOnegramCoreSettings
{
    OGOnegramCore *proxy = [OGOnegramCore sharedCore];
    OGOnegramCoreMode mode = proxy.mode;
    MTSocksProxySettings *settings = nil;
    if (mode == OGOnegramCoreModeDanteWARP || mode == OGOnegramCoreModeDantePower)
        settings = [[MTSocksProxySettings alloc] initWithIp:@"127.0.0.1" port:proxy.socksPort username:nil password:nil secret:nil];
    else if (mode == OGOnegramCoreModeNone)
        settings = TGOnegramStoredProxySettings();
    [_context updateApiEnvironment:^MTApiEnvironment *(MTApiEnvironment *environment)
    {
        MTApiEnvironment *updated = [environment withUpdatedOnegramWebSocketEnabled:mode == OGOnegramCoreModeWebSocket];
        updated = [updated withUpdatedPreferHttpTransport:OGPlatformMajorVersion() <= 3 && mode == OGOnegramCoreModeNone];
        return [updated withUpdatedSocksProxySettings:settings];
    }];
}

- (SSignal *)socksProxySettings {
    return _socksProxySettingsValue.signal;
}

- (void)contextApiEnvironmentUpdated:(MTContext *)__unused context apiEnvironment:(MTApiEnvironment *)apiEnvironment {
    [_socksProxySettingsValue set:[SSignal single:apiEnvironment.socksProxySettings]];
}

@end
