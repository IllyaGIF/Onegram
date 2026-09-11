

#import "MTTcpConnection.h"

#import "MTLogging.h"
#import "MTQueue.h"
#import "MTTimer.h"
#import "MTNetworkUsageCalculationInfo.h"

#import "GCDAsyncSocket.h"
#import "MTOnegramProxyTLSRoots.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <errno.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import "../../../Telegraph/IOS6NotificationProbe.h"
#endif

#import "MTInternalId.h"

#import "MTContext.h"
#import "MTApiEnvironment.h"
#import "MTDatacenterAddress.h"

#import "MTAes.h"
#import "MTEncryption.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTSignal.h>
#   import <MTProtoKitDynamic/MTDNS.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTSignal.h>
#   import <MTProtoKitMac/MTDNS.h>
#else
#   import <MTProtoKit/MTSignal.h>
#   import <MTProtoKit/MTDNS.h>
#endif

@interface MTTcpConnectionData : NSObject

@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, readonly) bool isSocks;

@end

@implementation MTTcpConnectionData

- (instancetype)initWithIp:(NSString *)ip port:(int32_t)port isSocks:(bool)isSocks {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _port = port;
        _isSocks = isSocks;
    }
    return self;
}

@end

MTInternalIdClass(MTTcpConnection)

struct socks5_ident_req
{
    unsigned char Version;
    unsigned char NumberOfMethods;
    unsigned char Methods[256];
};

struct socks5_ident_resp
{
    unsigned char Version;
    unsigned char Method;
};

struct socks5_req
{
    unsigned char Version;
    unsigned char Cmd;
    unsigned char Reserved;
    unsigned char AddrType;
    union {
        struct in_addr IPv4;
        struct in6_addr IPv6;
        struct {
            unsigned char DomainLen;
            char Domain[256];
        };
    } DestAddr;
    unsigned short DestPort;
};

struct socks5_resp
{
    unsigned char Version;
    unsigned char Reply;
    unsigned char Reserved;
    unsigned char AddrType;
    union {
        struct in_addr IPv4;
        struct in6_addr IPv6;
        struct {
            unsigned char DomainLen;
            char Domain[256];
        };
    } BindAddr;
    unsigned short BindPort;
};

typedef enum {
    MTTcpReadTagPacketShortLength,
    MTTcpReadTagPacketLongLength,
    MTTcpReadTagPacketFullLength,
    MTTcpReadTagPacketBody,
    MTTcpReadTagPacketHead,
    MTTcpReadTagQuickAck,
    MTTcpReadTagFullQuickAck,
    MTTcpSocksLogin,
    MTTcpSocksRequest,
    MTTcpSocksReceiveBindAddr4,
    MTTcpSocksReceiveBindAddr6,
    MTTcpSocksReceiveBindAddrDomainNameLength,
    MTTcpSocksReceiveBindAddrDomainName,
    MTTcpSocksReceiveBindAddrPort,
    MTTcpSocksReceiveAuthResponse,
    MTTcpOnegramWebSocketHttpHeader = 1000,
    MTTcpOnegramWebSocketFrameHeader,
    MTTcpOnegramWebSocketFrameLength16,
    MTTcpOnegramWebSocketFrameLength64,
    MTTcpOnegramWebSocketFramePayload
} MTTcpReadTags;

static const NSTimeInterval MTMinTcpResponseTimeout = 12.0;
static const NSUInteger MTTcpProgressCalculationThreshold = 4096;
static const NSUInteger MTOnegramWebSocketMaxMessageLength = 16 * 1024 * 1024;
static NSString *const MTOnegramCfProxyDomains[] =
{
    @"pclead.co.uk",
    @"offshor.co.uk",
    @"cakeisalie.co.uk",
    @"noskomnadzor.co.uk",
    @"lovetrue.co.uk",
    @"sorokdva.co.uk",
    @"pyatdesyatdva.co.uk",
    @"kartoshka.co.uk",
    @"sorokodin.co.uk",
    @"pyatdesyatodin.co.uk",
    @"notelega.co.uk",
    @"ebally.co.uk",
    @"nebally.co.uk",
    @"havegreatday.co.uk",
    @"pomogite.co.uk",
    @"fixtelega.co.uk",
    @"sadnews.co.uk",
    @"onedaychamp.co.uk",
    @"stopblocking.co.uk",
    @"nothingthere.co.uk"
};
static const NSInteger MTOnegramCfProxyDomainCount = sizeof(MTOnegramCfProxyDomains) / sizeof(MTOnegramCfProxyDomains[0]);
static const NSInteger MTOnegramCfProxyAttemptCount = MTOnegramCfProxyDomainCount;

static NSString *MTOnegramBase64(NSData *data)
{
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    if (data.length == 0)
        return @"";

    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:((length + 2) / 3) * 4];
    for (NSUInteger index = 0; index < length; index += 3)
    {
        uint32_t value = ((uint32_t)bytes[index]) << 16;
        if (index + 1 < length)
            value |= ((uint32_t)bytes[index + 1]) << 8;
        if (index + 2 < length)
            value |= bytes[index + 2];

        [result appendFormat:@"%c", table[(value >> 18) & 63]];
        [result appendFormat:@"%c", table[(value >> 12) & 63]];
        if (index + 1 < length)
            [result appendFormat:@"%c", table[(value >> 6) & 63]];
        else
            [result appendString:@"="];
        if (index + 2 < length)
            [result appendFormat:@"%c", table[value & 63]];
        else
            [result appendString:@"="];
    }
    return result;
}

static NSData *MTOnegramWebSocketFrame(NSData *payload, uint8_t opcode)
{
    NSUInteger length = payload.length;
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:length + 14];
    uint8_t first = (uint8_t)(0x80 | (opcode & 0x0f));
    [result appendBytes:&first length:1];

    if (length < 126)
    {
        uint8_t second = (uint8_t)(0x80 | length);
        [result appendBytes:&second length:1];
    }
    else if (length <= 0xffff)
    {
        uint8_t second = 0x80 | 126;
        uint16_t value = htons((uint16_t)length);
        [result appendBytes:&second length:1];
        [result appendBytes:&value length:2];
    }
    else
    {
        uint8_t second = 0x80 | 127;
        uint64_t value = (uint64_t)length;
        uint8_t encoded[8];
        for (int index = 0; index < 8; index++)
            encoded[index] = (uint8_t)((value >> ((7 - index) * 8)) & 0xff);
        [result appendBytes:&second length:1];
        [result appendBytes:encoded length:8];
    }

    uint8_t mask[4];
    arc4random_buf(mask, sizeof(mask));
    [result appendBytes:mask length:4];

    if (length != 0)
    {
        NSMutableData *masked = [[NSMutableData alloc] initWithLength:length];
        const uint8_t *source = payload.bytes;
        uint8_t *destination = masked.mutableBytes;
        for (NSUInteger index = 0; index < length; index++)
            destination[index] = source[index] ^ mask[index & 3];
        [result appendData:masked];
    }
    return result;
}

static bool MTOnegramControlBytesAllowed(const uint8_t *bytes)
{
    if (bytes[0] == 0xef)
        return false;

    uint32_t first = 0;
    memcpy(&first, bytes, 4);
    if (first == 0x44414548 || first == 0x54534f50 || first == 0x20544547 || first == 0xeeeeeeee || first == 0xdddddddd)
        return false;
    if (bytes[0] == 0x16 && bytes[1] == 0x03 && bytes[2] == 0x01 && bytes[3] == 0x02)
        return false;

    uint32_t second = 0;
    memcpy(&second, bytes + 4, 4);
    return second != 0;
}

struct ctr_state {
    unsigned char ivec[16];  /* ivec[0..7] is the IV, ivec[8..15] is the big-endian counter */
    unsigned int num;
    unsigned char ecount[16];
};


@interface MTTcpConnection () <GCDAsyncSocketDelegate>
{   
    GCDAsyncSocket *_socket;
    bool _closed;
    
    bool _useIntermediateFormat;
    
    int32_t _datacenterTag;
    
    uint8_t _quickAckByte;
    
    MTTimer *_responseTimeoutTimer;
    
    bool _readingPartialData;
    NSData *_packetHead;
    NSUInteger _packetRestLength;
    NSUInteger _packetRestReceivedLength;
    
    bool _delegateImplementsProgressUpdated;
    NSData *_firstPacketControlByte;
    
    bool _addedControlHeader;
    
    MTAesCtr *_outgoingAesCtr;
    MTAesCtr *_incomingAesCtr;
    
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
    
    NSString *_socksIp;
    int32_t _socksPort;
    NSString *_socksUsername;
    NSString *_socksPassword;
    
    NSString *_mtpIp;
    int32_t _mtpPort;
    NSData *_mtpSecret;

    __weak MTContext *_context;
    bool _onegramWebSocket;
    bool _onegramWebSocketReady;
    NSInteger _onegramWebSocketAttempt;
    NSString *_onegramWebSocketDomain;
    NSString *_onegramWebSocketPath;
    NSString *_onegramWebSocketKey;
    uint8_t _onegramWebSocketFrameOpcode;
    uint8_t _onegramWebSocketFragmentOpcode;
    bool _onegramWebSocketFrameFin;
    NSUInteger _onegramWebSocketFrameLength;
    NSMutableData *_onegramWebSocketFragment;
    NSMutableData *_onegramWebSocketTransportBuffer;
    
    MTMetaDisposable *_resolveDisposable;
}

@property (nonatomic) int64_t packetHeadDecodeToken;
@property (nonatomic, strong) id packetProgressToken;

- (NSInteger)onegramWebSocketDatacenterId;
- (bool)onegramWebSocketTesting;
- (NSInteger)onegramWebSocketDirectAttemptCount;
- (bool)onegramWebSocketCfAttempt:(NSInteger)attempt;
- (NSString *)onegramWebSocketDomainForAttempt:(NSInteger)attempt;
- (NSString *)onegramWebSocketTargetForAttempt:(NSInteger)attempt;
- (void)onegramPrepareSocket;
- (void)onegramWebSocketAttemptsExhausted;
- (void)onegramStartWebSocketAttempt;
- (void)onegramWebSocketAttemptFailed;
- (void)onegramWebSocketOpened;
- (void)onegramReadNextWebSocketFrame;
- (void)onegramReadWebSocketPayload;
- (void)onegramSendWebSocketPayload:(NSData *)payload opcode:(uint8_t)opcode;
- (void)onegramDeliverPacketData:(NSData *)packetData;
- (void)onegramProcessTransportFrame:(NSData *)rawData;
- (void)onegramHandleWebSocketFramePayload:(NSData *)payload;

@end

@implementation MTTcpConnection

+ (MTQueue *)tcpQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.tcpQueue"];
    });
    return queue;
}

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address interface:(NSString *)interface usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo
{
#ifdef DEBUG
    NSAssert(address != nil, @"address should not be nil");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTTcpConnection) alloc] init];
        
        _address = address;
        _context = context;
        
        _interface = interface;
        _usageCalculationInfo = usageCalculationInfo;
        
        if (context.apiEnvironment.datacenterAddressOverrides[@(datacenterId)] != nil) {
            _firstPacketControlByte = [context.apiEnvironment tcpPayloadPrefix];
        }
        
        if (context.apiEnvironment.onegramWebSocketEnabled) {
            _onegramWebSocket = true;
        } else if (context.apiEnvironment.socksProxySettings != nil) {
            if (context.apiEnvironment.socksProxySettings.secret != nil) {
                _mtpIp = context.apiEnvironment.socksProxySettings.ip;
                _mtpPort = context.apiEnvironment.socksProxySettings.port;
                _mtpSecret = context.apiEnvironment.socksProxySettings.secret;
            } else {
                _socksIp = context.apiEnvironment.socksProxySettings.ip;
                _socksPort = context.apiEnvironment.socksProxySettings.port;
                _socksUsername = context.apiEnvironment.socksProxySettings.username;
                _socksPassword = context.apiEnvironment.socksProxySettings.password;
            }
        }
        
        if (_mtpSecret != nil) {
            if ([MTSocksProxySettings secretSupportsExtendedPadding:_mtpSecret]) {
                _useIntermediateFormat = true;
            }
        } else if ([MTSocksProxySettings secretSupportsExtendedPadding:_address.secret]) {
            _useIntermediateFormat = true;
        }
        if (_onegramWebSocket)
            _useIntermediateFormat = false;
        
        _resolveDisposable = [[MTMetaDisposable alloc] init];
        
        if (context.isTestingEnvironment) {
            if (address.preferForMedia) {
                _datacenterTag = -(int32_t)(10000 + datacenterId);
            } else {
                _datacenterTag = (int32_t)(10000 + datacenterId);
            }
        } else {
            if (address.preferForMedia) {
                _datacenterTag = -(int32_t)datacenterId;
            } else {
                _datacenterTag = (int32_t)datacenterId;
            }
        }
    }
    return self;
}

- (void)dealloc
{
    GCDAsyncSocket *socket = _socket;
    socket.delegate = nil;
    _socket = nil;
    
    MTTimer *responseTimeoutTimer = _responseTimeoutTimer;
    
    MTMetaDisposable *resolveDisposable = _resolveDisposable;
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        [responseTimeoutTimer invalidate];
        
        [socket disconnect];
        [resolveDisposable dispose];
    }];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
        _usageCalculationInfo = usageCalculationInfo;
        _socket.usageCalculationInfo = usageCalculationInfo;
    }];
}

- (void)setDelegate:(id<MTTcpConnectionDelegate>)delegate
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
        _delegate = delegate;
        
        _delegateImplementsProgressUpdated = [delegate respondsToSelector:@selector(tcpConnectionProgressUpdated:packetProgressToken:packetLength:progress:)];
    } synchronous:true];
}

- (NSInteger)onegramWebSocketDatacenterId
{
    NSInteger value = _datacenterTag;
    if (value < 0)
        value = -value;
    if (value >= 10000)
        value -= 10000;
    return value;
}

- (bool)onegramWebSocketTesting
{
    NSInteger value = _datacenterTag;
    if (value < 0)
        value = -value;
    return value >= 10000;
}

- (NSInteger)onegramWebSocketDirectAttemptCount
{
    NSInteger dc = [self onegramWebSocketDatacenterId];
    return dc == 2 || dc == 4 ? 2 : 0;
}

- (bool)onegramWebSocketCfAttempt:(NSInteger)attempt
{
    if ([self onegramWebSocketTesting])
        return false;
    return attempt >= [self onegramWebSocketDirectAttemptCount];
}

- (NSString *)onegramWebSocketDomainForAttempt:(NSInteger)attempt
{
    NSInteger dc = [self onegramWebSocketDatacenterId];
    NSInteger directAttemptCount = [self onegramWebSocketDirectAttemptCount];
    if (attempt < directAttemptCount)
    {
        bool media = _datacenterTag < 0;
        bool alternate = (attempt & 1) != 0;
        bool suffix = media ? !alternate : alternate;
        if (suffix)
            return [NSString stringWithFormat:@"kws%d-1.web.telegram.org", (int)dc];
        return [NSString stringWithFormat:@"kws%d.web.telegram.org", (int)dc];
    }

    if ([self onegramWebSocketTesting])
        return nil;

    NSInteger cfAttempt = attempt - directAttemptCount;
    if (cfAttempt < 0 || cfAttempt >= MTOnegramCfProxyAttemptCount || MTOnegramCfProxyDomainCount == 0)
        return nil;

    NSInteger domainIndex = (dc * 3 + cfAttempt) % MTOnegramCfProxyDomainCount;
    return [NSString stringWithFormat:@"kws%d.%@", (int)dc, MTOnegramCfProxyDomains[domainIndex]];
}

- (NSString *)onegramWebSocketTargetForAttempt:(NSInteger)attempt
{
    NSInteger dc = [self onegramWebSocketDatacenterId];
    if (attempt < [self onegramWebSocketDirectAttemptCount])
        return dc == 2 || dc == 4 ? @"149.154.167.220" : nil;
    return [self onegramWebSocketDomainForAttempt:attempt];
}

- (void)onegramPrepareSocket
{
    GCDAsyncSocket *oldSocket = _socket;
    if (oldSocket != nil)
    {
        oldSocket.delegate = nil;
        [oldSocket disconnect];
    }

    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[[MTTcpConnection tcpQueue] nativeQueue]];
    _socket.usageCalculationInfo = _usageCalculationInfo;
}

- (void)onegramWebSocketAttemptsExhausted
{
    if (_closed)
        return;

    [self closeAndNotify];
}

- (void)onegramStartWebSocketAttempt
{
    if (_closed)
        return;

    NSInteger dc = [self onegramWebSocketDatacenterId];
    bool testing = [self onegramWebSocketTesting];
    NSString *domain = [self onegramWebSocketDomainForAttempt:_onegramWebSocketAttempt];
    NSString *target = [self onegramWebSocketTargetForAttempt:_onegramWebSocketAttempt];
    if (domain == nil || target == nil)
    {
        [self onegramWebSocketAttemptsExhausted];
        return;
    }

    _onegramWebSocketDomain = domain;
    _onegramWebSocketPath = testing ? @"/apiws_test" : @"/apiws";
    _onegramWebSocketReady = false;
    _onegramWebSocketKey = nil;
    _onegramWebSocketFragment = nil;
    _onegramWebSocketTransportBuffer = nil;
    [self onegramPrepareSocket];

    NSError *error = nil;
    if (![_socket connectToHost:target onPort:443 viaInterface:_interface withTimeout:5 error:&error] || error != nil)
        [self onegramWebSocketAttemptFailed];
}

- (void)onegramWebSocketAttemptFailed
{
    if (_closed || !_onegramWebSocket)
        return;

    _onegramWebSocketAttempt++;
    if ([self onegramWebSocketDomainForAttempt:_onegramWebSocketAttempt] != nil && [self onegramWebSocketTargetForAttempt:_onegramWebSocketAttempt] != nil)
        [self onegramStartWebSocketAttempt];
    else
        [self onegramWebSocketAttemptsExhausted];
}

- (void)onegramWebSocketOpened
{
    _onegramWebSocketReady = true;
    if (_connectionOpened)
        _connectionOpened();
    id<MTTcpConnectionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
        [delegate tcpConnectionOpened:self];
    [self onegramReadNextWebSocketFrame];
}

- (void)onegramReadNextWebSocketFrame
{
    if (_closed || !_onegramWebSocketReady || _socket == nil)
        return;
    [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpOnegramWebSocketFrameHeader];
}

- (void)onegramReadWebSocketPayload
{
    if (_onegramWebSocketFrameLength > MTOnegramWebSocketMaxMessageLength)
    {
        [self closeAndNotify];
        return;
    }

    if (_onegramWebSocketFrameLength == 0)
        [self onegramHandleWebSocketFramePayload:[NSData data]];
    else
        [_socket readDataToLength:_onegramWebSocketFrameLength withTimeout:-1 tag:MTTcpOnegramWebSocketFramePayload];
}

- (void)onegramSendWebSocketPayload:(NSData *)payload opcode:(uint8_t)opcode
{
    if (_socket == nil || !_onegramWebSocketReady)
        return;
    [_socket writeData:MTOnegramWebSocketFrame(payload ?: [NSData data], opcode) withTimeout:-1 tag:0];
}

- (void)onegramDeliverPacketData:(NSData *)packetData
{
    [_responseTimeoutTimer invalidate];
    _responseTimeoutTimer = nil;
    _packetHeadDecodeToken = -1;
    _packetProgressToken = nil;

    if (packetData.length % 4 != 0)
    {
        int32_t realLength = ((int32_t)packetData.length) & (~3);
        packetData = [packetData subdataWithRange:NSMakeRange(0, (NSUInteger)realLength)];
    }

    bool ignorePacket = false;
    if (packetData.length >= 4)
    {
        int32_t header = 0;
        [packetData getBytes:&header length:4];
        if (header == 0xffffffff)
        {
            if (packetData.length >= 8)
            {
                int32_t ackId = 0;
                [packetData getBytes:&ackId range:NSMakeRange(4, 4)];
                ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
                ackId = (int32_t)OSSwapInt32(ackId);
                id<MTTcpConnectionDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
                    [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
                ignorePacket = true;
            }
        }
        else if (header == 0 && packetData.length < 16)
        {
            ignorePacket = true;
        }
    }

    if (!ignorePacket)
    {
        if (_connectionReceivedData)
            _connectionReceivedData(packetData);
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionReceivedData:data:)])
            [delegate tcpConnectionReceivedData:self data:packetData];
    }
}

- (void)onegramProcessTransportFrame:(NSData *)rawData
{
    if (_incomingAesCtr == nil || rawData.length == 0)
        return;

    NSMutableData *decryptedData = [[NSMutableData alloc] initWithLength:rawData.length];
    [_incomingAesCtr encryptIn:rawData.bytes out:decryptedData.mutableBytes len:rawData.length];
    if (_onegramWebSocketTransportBuffer == nil)
        _onegramWebSocketTransportBuffer = [[NSMutableData alloc] init];
    [_onegramWebSocketTransportBuffer appendData:decryptedData];
    if (_onegramWebSocketTransportBuffer.length > MTOnegramWebSocketMaxMessageLength)
    {
        [self closeAndNotify];
        return;
    }

    const uint8_t *bytes = _onegramWebSocketTransportBuffer.bytes;
    NSUInteger totalLength = _onegramWebSocketTransportBuffer.length;
    NSUInteger offset = 0;

    while (offset < totalLength)
    {
        NSUInteger remaining = totalLength - offset;
        if (_useIntermediateFormat)
        {
            if (remaining < 4)
                break;

            int32_t length = 0;
            memcpy(&length, bytes + offset, 4);
            if ((length & 0x80000000) != 0)
            {
                int32_t ackId = length & 0x7fffffff;
                ackId = (int32_t)OSSwapInt32(ackId);
                id<MTTcpConnectionDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
                    [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
                offset += 4;
                continue;
            }

            if (length <= 0 || (NSUInteger)length > MTOnegramWebSocketMaxMessageLength)
            {
                [self closeAndNotify];
                return;
            }
            if ((NSUInteger)length > remaining - 4)
                break;

            NSData *packet = [_onegramWebSocketTransportBuffer subdataWithRange:NSMakeRange(offset + 4, (NSUInteger)length)];
            [self onegramDeliverPacketData:packet];
            offset += 4 + (NSUInteger)length;
        }
        else
        {
            if (remaining < 1)
                break;

            uint8_t marker = bytes[offset];
            if ((marker & 0x80) != 0)
            {
                if (remaining < 4)
                    break;
                int32_t ackId = 0;
                ((uint8_t *)&ackId)[0] = bytes[offset];
                memcpy(((uint8_t *)&ackId) + 1, bytes + offset + 1, 3);
                ackId = (int32_t)OSSwapInt32(ackId);
                ackId &= 0x7fffffff;
                id<MTTcpConnectionDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
                    [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
                offset += 4;
                continue;
            }

            NSUInteger headerLength = 1;
            NSUInteger packetLength = 0;
            if (marker == 0x7f)
            {
                if (remaining < 4)
                    break;
                uint32_t quarterLength = 0;
                memcpy(&quarterLength, bytes + offset + 1, 3);
                packetLength = (NSUInteger)quarterLength * 4;
                headerLength = 4;
            }
            else if (marker >= 1 && marker <= 0x7e)
            {
                packetLength = (NSUInteger)marker * 4;
            }
            else
            {
                [self closeAndNotify];
                return;
            }

            if (packetLength == 0 || packetLength > MTOnegramWebSocketMaxMessageLength)
            {
                [self closeAndNotify];
                return;
            }
            if (packetLength > remaining - headerLength)
                break;

            NSData *packet = [_onegramWebSocketTransportBuffer subdataWithRange:NSMakeRange(offset + headerLength, packetLength)];
            [self onegramDeliverPacketData:packet];
            offset += headerLength + packetLength;
        }
    }

    if (offset != 0)
        [_onegramWebSocketTransportBuffer replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
}

- (void)onegramHandleWebSocketFramePayload:(NSData *)payload
{
    NSData *effectivePayload = payload;

    uint8_t opcode = _onegramWebSocketFrameOpcode;
    if (opcode == 0x8)
    {
        if (_socket != nil && _onegramWebSocketReady)
            [_socket writeData:MTOnegramWebSocketFrame(effectivePayload.length <= 125 ? effectivePayload : [NSData data], 0x8) withTimeout:2 tag:0];
        [self closeAndNotify];
        return;
    }
    if (opcode == 0x9)
    {
        [self onegramSendWebSocketPayload:effectivePayload opcode:0xA];
        [self onegramReadNextWebSocketFrame];
        return;
    }
    if (opcode == 0xA)
    {
        [self onegramReadNextWebSocketFrame];
        return;
    }

    if (opcode == 0x1 || opcode == 0x2)
    {
        if (_onegramWebSocketFrameFin)
        {
            [self onegramProcessTransportFrame:effectivePayload];
        }
        else
        {
            _onegramWebSocketFragmentOpcode = opcode;
            _onegramWebSocketFragment = [[NSMutableData alloc] initWithData:effectivePayload];
        }
    }
    else if (opcode == 0x0 && _onegramWebSocketFragment != nil)
    {
        [_onegramWebSocketFragment appendData:effectivePayload];
        if (_onegramWebSocketFragment.length > MTOnegramWebSocketMaxMessageLength)
        {
            [self closeAndNotify];
            return;
        }
        if (_onegramWebSocketFrameFin)
        {
            NSData *message = [_onegramWebSocketFragment copy];
            uint8_t fragmentOpcode = _onegramWebSocketFragmentOpcode;
            _onegramWebSocketFragment = nil;
            _onegramWebSocketFragmentOpcode = 0;
            if (fragmentOpcode == 0x1 || fragmentOpcode == 0x2)
                [self onegramProcessTransportFrame:message];
        }
    }

    if (!_closed)
        [self onegramReadNextWebSocketFrame];
}

- (void)start
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (_socket == nil)
        {
            if (_onegramWebSocket)
            {
                _onegramWebSocketAttempt = 0;
                [self onegramStartWebSocketAttempt];
                return;
            }

            _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[[MTTcpConnection tcpQueue] nativeQueue]];
            _socket.usageCalculationInfo = _usageCalculationInfo;
            
            NSString *addressIp = _address.ip;
            MTSignal *resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:addressIp port:_address.port isSocks:false]];
            
            if (_socksIp != nil) {
                bool isHostname = true;
                struct in_addr ip4;
                struct in6_addr ip6;
                if (inet_aton(_socksIp.UTF8String, &ip4) != 0) {
                    isHostname = false;
                } else if (inet_pton(AF_INET6, _socksIp.UTF8String, &ip6) != 0) {
                    isHostname = false;
                }
                
                /*if (isHostname) {
                    resolveSignal = [MTDNS resolveHostname:_socksIp];
                } else {*/
                    resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:_socksIp port:_socksPort isSocks:true]];
                //}
            } else if (_mtpIp != nil) {
                bool isHostname = true;
                struct in_addr ip4;
                struct in6_addr ip6;
                if (inet_aton(_mtpIp.UTF8String, &ip4) != 0) {
                    isHostname = false;
                } else if (inet_pton(AF_INET6, _mtpIp.UTF8String, &ip6) != 0) {
                    isHostname = false;
                }
                
                /*if (isHostname) {
                    resolveSignal = [MTDNS resolveHostname:_mtpIp];
                } else {*/
                    resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:_mtpIp port:_mtpPort isSocks:false]];
                //}
            }
            
            MTTcpConnection *connection = self;
            [_resolveDisposable setDisposable:[resolveSignal startWithNext:^(MTTcpConnectionData *connectionData) {
                [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
                    MTTcpConnection *strongSelf = connection;
                    if (connectionData == nil) {
                        return;
                    }
                    if (![connectionData.ip respondsToSelector:@selector(characterAtIndex:)]) {
                        return;
                    }
                    
                    if (connectionData.isSocks) {
                        strongSelf->_socksIp = connectionData.ip;
                        strongSelf->_socksPort = connectionData.port;
                    }
                    
                    if (MTLogEnabled()) {
                        if (strongSelf->_socksIp != nil) {
                            if (strongSelf->_socksUsername.length == 0) {
                                MTLog(@"[MTTcpConnection#%x connecting to %@:%d via %@:%d]", (int)self, strongSelf->_address.ip, (int)strongSelf->_address.port, strongSelf->_socksIp, (int)strongSelf->_socksPort);
                            } else {
                                MTLog(@"[MTTcpConnection#%x connecting to %@:%d via %@:%d using %@:%@]", (int)self, strongSelf->_address.ip, (int)strongSelf->_address.port, strongSelf->_socksIp, (int)_socksPort, strongSelf->_socksUsername, strongSelf->_socksPassword);
                            }
                        } else if (strongSelf->_mtpIp != nil) {
                            MTLog(@"[MTTcpConnection#%x connecting to %@:%d via mtp://%@:%d:%@]", (int)self, strongSelf->_address.ip, (int)strongSelf->_address.port, strongSelf->_mtpIp, (int)strongSelf->_mtpPort, strongSelf->_mtpSecret);
                        } else if (strongSelf->_address.secret != nil) {
                            MTLog(@"[MTTcpConnection#%x connecting to %@:%d with secret %@]", (int)self, strongSelf->_address.ip, (int)strongSelf->_address.port, strongSelf->_address.secret);
                        } else {
                            MTLog(@"[MTTcpConnection#%x connecting to %@:%d]", (int)self, strongSelf->_address.ip, (int)strongSelf->_address.port);
                        }
                    }
                    
                    __autoreleasing NSError *error = nil;
                    if (![strongSelf->_socket connectToHost:connectionData.ip onPort:connectionData.port viaInterface:strongSelf->_interface withTimeout:12 error:&error] || error != nil) {
                        [strongSelf closeAndNotify];
                    } else if (strongSelf->_socksIp == nil) {
                        if (_useIntermediateFormat) {
                            [strongSelf->_socket readDataToLength:4 withTimeout:-1 tag:MTTcpReadTagPacketFullLength];
                        } else {
                            [strongSelf->_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
                        }
                    } else {
                        struct socks5_ident_req req;
                        req.Version = 5;
                        req.NumberOfMethods = 1;
                        req.Methods[0] = 0x00;
                        
                        if (_socksUsername != nil) {
                            req.NumberOfMethods += 1;
                            req.Methods[1] = 0x02;
                        }
                        [strongSelf->_socket writeData:[NSData dataWithBytes:&req length:2 + req.NumberOfMethods] withTimeout:-1 tag:0];
                        [strongSelf->_socket readDataToLength:sizeof(struct socks5_ident_resp) withTimeout:-1 tag:MTTcpSocksLogin];
                    }
                }];
            }]];
        }
    }];
}

- (void)stop
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
            [self closeAndNotify];
    }];
}

- (void)closeAndNotify
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
        {
            _closed = true;
            
            [_socket disconnect];
            _socket.delegate = nil;
            _socket = nil;
            
            if (_connectionClosed)
                _connectionClosed();
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionClosed:)])
                [delegate tcpConnectionClosed:self];
        }
    }];
}

- (void)sendDatas:(NSArray *)datas completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse
{
    if (datas.count == 0)
    {
        completion(false);
        
        return;
    }
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
        {
            if (_socket != nil && (!_onegramWebSocket || _onegramWebSocketReady))
            {
                NSUInteger completeDataLength = 0;
                
                for (NSData *data in datas)
                {
                    NSMutableData *packetData = [[NSMutableData alloc] initWithCapacity:data.length + 8];
                    
                    uint8_t padding[16];
                    uint32_t paddingSize = 0;
                    
                    if (_useIntermediateFormat) {
                        int32_t length = (int32_t)data.length;
                        
                        paddingSize = arc4random_uniform(16);
                        if (paddingSize != 0) {
                            arc4random_buf(padding, paddingSize);
                        }
                        length += (int32_t)paddingSize;
                        
                        if (requestQuickAck) {
                            length |= 0x80000000;
                        }
                        [packetData appendBytes:&length length:4];
                    } else {
                        int32_t quarterLength = (int32_t)(data.length / 4);
                        
                        if (quarterLength <= 0x7e)
                        {
                            uint8_t quarterLengthMarker = (uint8_t)quarterLength;
                            if (requestQuickAck)
                                quarterLengthMarker |= 0x80;
                            [packetData appendBytes:&quarterLengthMarker length:1];
                        }
                        else
                        {
                            uint8_t quarterLengthMarker = 0x7f;
                            if (requestQuickAck)
                                quarterLengthMarker |= 0x80;
                            [packetData appendBytes:&quarterLengthMarker length:1];
                            [packetData appendBytes:((uint8_t *)&quarterLength) length:3];
                        }
                    }
                    
                    [packetData appendData:data];
                    
                    if (paddingSize != 0) {
                        [packetData appendBytes:padding length:paddingSize];
                    }
                    
                    completeDataLength += packetData.length;
                    
                    if (!_addedControlHeader) {
                        _addedControlHeader = true;
                        uint8_t controlBytes[64];
                        do
                        {
                            arc4random_buf(controlBytes, 64);
                        } while (_onegramWebSocket && !MTOnegramControlBytesAllowed(controlBytes));
                        
                        int32_t controlVersion;
                        if (_useIntermediateFormat) {
                            controlVersion = 0xdddddddd;
                        } else {
                            controlVersion = 0xefefefef;
                        }
                        
                        memcpy(controlBytes + 56, &controlVersion, 4);
                        NSInteger datacenterValue = _datacenterTag;
                        if (_onegramWebSocket)
                        {
                            datacenterValue = [self onegramWebSocketDatacenterId];
                            if (_datacenterTag < 0)
                                datacenterValue = -datacenterValue;
                        }
                        int16_t datacenterTag = (int16_t)datacenterValue;
                        memcpy(controlBytes + 60, &datacenterTag, 2);
                        
                        uint8_t controlBytesReversed[64];
                        for (int i = 0; i < 64; i++) {
                            controlBytesReversed[i] = controlBytes[64 - 1 - i];
                        }
                        
                        NSData *aesKey = [[NSData alloc] initWithBytes:controlBytes + 8 length:32];
                        NSData *aesIv = [[NSData alloc] initWithBytes:controlBytes + 8 + 32 length:16];
                        
                        NSData *incomingAesKey = [[NSData alloc] initWithBytes:controlBytesReversed + 8 length:32];
                        NSData *incomingAesIv = [[NSData alloc] initWithBytes:controlBytesReversed + 8 + 32 length:16];

                        NSData *effectiveSecret = nil;
                        if (!_onegramWebSocket) {
                            if (_mtpSecret != nil) {
                                effectiveSecret = _mtpSecret;
                            } else if (_address.secret != nil) {
                                effectiveSecret = _address.secret;
                            }
                        }
                        if (effectiveSecret.length != 16 && effectiveSecret.length != 17) {
                            effectiveSecret = nil;
                        }
                        
                        if (effectiveSecret) {
                            NSMutableData *aesKeyData = [[NSMutableData alloc] init];
                            [aesKeyData appendData:aesKey];
                            if (effectiveSecret.length == 16) {
                                [aesKeyData appendData:effectiveSecret];
                            } else if (effectiveSecret.length == 17) {
                                [aesKeyData appendData:[effectiveSecret subdataWithRange:NSMakeRange(1, effectiveSecret.length - 1)]];
                            }
                            NSData *aesKeyHash = MTSha256(aesKeyData);
                            aesKey = [aesKeyHash subdataWithRange:NSMakeRange(0, 32)];
                            
                            NSMutableData *incomingAesKeyData = [[NSMutableData alloc] init];
                            [incomingAesKeyData appendData:incomingAesKey];
                            if (effectiveSecret.length == 16) {
                                [incomingAesKeyData appendData:effectiveSecret];
                            } else if (effectiveSecret.length == 17) {
                                [incomingAesKeyData appendData:[effectiveSecret subdataWithRange:NSMakeRange(1, effectiveSecret.length - 1)]];
                            }
                            NSData *incomingAesKeyHash = MTSha256(incomingAesKeyData);
                            incomingAesKey = [incomingAesKeyHash subdataWithRange:NSMakeRange(0, 32)];
                         }
                        
                        _outgoingAesCtr = [[MTAesCtr alloc] initWithKey:aesKey.bytes keyLength:32 iv:aesIv.bytes decrypt:false];
                        _incomingAesCtr = [[MTAesCtr alloc] initWithKey:incomingAesKey.bytes keyLength:32 iv:incomingAesIv.bytes decrypt:false];
                        
                        uint8_t encryptedControlBytes[64];
                        [_outgoingAesCtr encryptIn:controlBytes out:encryptedControlBytes len:64];
                        
                        NSMutableData *outData = [[NSMutableData alloc] initWithLength:64 + packetData.length];
                        memcpy(outData.mutableBytes, controlBytes, 56);
                        memcpy(outData.mutableBytes + 56, encryptedControlBytes + 56, 8);
                        
                        [_outgoingAesCtr encryptIn:packetData.bytes out:outData.mutableBytes + 64 len:packetData.length];
                        
                        if (_onegramWebSocket)
                        {
                            NSData *controlData = [outData subdataWithRange:NSMakeRange(0, 64)];
                            [self onegramSendWebSocketPayload:controlData opcode:0x2];
                            if (outData.length > 64)
                            {
                                NSData *bodyData = [outData subdataWithRange:NSMakeRange(64, outData.length - 64)];
                                [self onegramSendWebSocketPayload:bodyData opcode:0x2];
                            }
                        }
                        else
                        {
                            [_socket writeData:outData withTimeout:-1 tag:0];
                        }
                    } else {
                        NSMutableData *encryptedData = [[NSMutableData alloc] initWithLength:packetData.length];
                        [_outgoingAesCtr encryptIn:packetData.bytes out:encryptedData.mutableBytes len:packetData.length];
                        
                        if (_onegramWebSocket)
                            [self onegramSendWebSocketPayload:encryptedData opcode:0x2];
                        else
                            [_socket writeData:encryptedData withTimeout:-1 tag:0];
                    }
                }
                
                if (expectDataInResponse && _responseTimeoutTimer == nil)
                {
                    MTTcpConnection *connection = self;
                    _responseTimeoutTimer = [[MTTimer alloc] initWithTimeout:MTMinTcpResponseTimeout + completeDataLength / (12.0 * 1024) repeat:false completion:^
                    {
                        [connection responseTimeout];
                    } queue:[MTTcpConnection tcpQueue].nativeQueue];
                    [_responseTimeoutTimer start];
                }
                
                if (completion)
                    completion(true);
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: can't send data: connection is not opened", __PRETTY_FUNCTION__);
                }
                
                if (completion)
                    completion(false);
            }
        }
        else
        {
            if (completion)
                completion(false);
        }
    }];
}

- (void)responseTimeout
{
    [_responseTimeoutTimer invalidate];
    _responseTimeoutTimer = nil;
    
    if (MTLogEnabled()) {
        MTLog(@"[MTTcpConnection#%x response timeout]", (int)self);
    }
    [self stop];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)__unused tag
{
    if (_closed)
        return;
    
    [_responseTimeoutTimer resetTimeout:MTMinTcpResponseTimeout];
    
    if (_packetRestLength != 0)
    {
        NSUInteger previousApproximateProgress = _packetRestReceivedLength * 100 / _packetRestLength;
        _packetRestReceivedLength = MIN(_packetRestReceivedLength + partialLength, _packetRestLength);
        NSUInteger currentApproximateProgress = _packetRestReceivedLength * 100 / _packetRestLength;
        
        if (previousApproximateProgress != currentApproximateProgress && _packetProgressToken != nil && _delegateImplementsProgressUpdated)
        {
            id<MTTcpConnectionDelegate> delegate = _delegate;
            [delegate tcpConnectionProgressUpdated:self packetProgressToken:_packetProgressToken packetLength:_packetRestLength progress:currentApproximateProgress / 100.0f];
        }
    }
}

- (void)requestSocksConnection {
    struct socks5_req req;
    
    req.Version = 5;
    req.Cmd = 1;
    req.Reserved = 0;
    req.AddrType = 1;
    
    struct in_addr ip4;
    inet_aton(_address.ip.UTF8String, &ip4);
    req.DestAddr.IPv4 = ip4;
    req.DestPort = _address.port;
    
    NSMutableData *reqData = [[NSMutableData alloc] init];
    [reqData appendBytes:&req length:4];
    
    switch (req.AddrType) {
        case 1: {
            [reqData appendBytes:&req.DestAddr.IPv4 length:sizeof(struct in_addr)];
            break;
        }
        case 3: {
            [reqData appendBytes:&req.DestAddr.DomainLen length:1];
            [reqData appendBytes:&req.DestAddr.Domain length:req.DestAddr.DomainLen];
            break;
        }
        case 4: {
            [reqData appendBytes:&req.DestAddr.IPv6 length:sizeof(struct in6_addr)];
            break;
        }
        default: {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks request address type", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
    }
    
    unsigned short port = htons(req.DestPort);
    [reqData appendBytes:&port length:2];
    
    [_socket writeData:reqData withTimeout:-1 tag:0];
    [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpSocksRequest];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadData:(NSData *)rawData withTag:(long)tag
{
    if (_closed)
        return;

#if TARGET_OS_IPHONE
    BOOL isPrimaryDataConnection = _usageCalculationInfo != nil &&
        [_usageCalculationInfo incomingWWANKey] == 0 &&
        [_usageCalculationInfo outgoingWWANKey] == 1 &&
        [_usageCalculationInfo incomingOtherKey] == 2 &&
        [_usageCalculationInfo outgoingOtherKey] == 3;
    if ([[UIDevice currentDevice].systemVersion intValue] <= 6 && isPrimaryDataConnection)
    {
        static CFAbsoluteTime lastPrimaryActivitySignalTime = 0.0;
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (lastPrimaryActivitySignalTime == 0.0 || now - lastPrimaryActivitySignalTime >= 30.0)
        {
            lastPrimaryActivitySignalTime = now;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6PrimaryTransportReceivedData" object:nil];
        }
    }
#endif
    
    if (tag == MTTcpOnegramWebSocketHttpHeader)
    {
        NSString *response = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
        NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
        NSString *statusLine = lines.count == 0 ? @"" : [lines objectAtIndex:0];
        NSString *accept = nil;
        for (NSString *line in lines)
        {
            NSRange separator = [line rangeOfString:@":"];
            if (separator.location == NSNotFound)
                continue;
            NSString *name = [[line substringToIndex:separator.location] lowercaseString];
            if ([name isEqualToString:@"sec-websocket-accept"])
                accept = [[line substringFromIndex:separator.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }

        NSString *source = [NSString stringWithFormat:@"%@258EAFA5-E914-47DA-95CA-C5AB0DC85B11", _onegramWebSocketKey ?: @""];
        NSData *expectedDigest = MTSha1([source dataUsingEncoding:NSUTF8StringEncoding]);
        NSString *expectedAccept = MTOnegramBase64(expectedDigest);
        bool valid = [statusLine rangeOfString:@" 101 "].location != NSNotFound && accept.length != 0 && [accept isEqualToString:expectedAccept];
        if (!valid)
        {
            [self onegramWebSocketAttemptFailed];
            return;
        }

        [self onegramWebSocketOpened];
        return;
    }
    else if (tag == MTTcpOnegramWebSocketFrameHeader)
    {
        if (rawData.length != 2)
        {
            [self closeAndNotify];
            return;
        }
        const uint8_t *bytes = rawData.bytes;
        if ((bytes[0] & 0x70) != 0 || (bytes[1] & 0x80) != 0)
        {
            [self closeAndNotify];
            return;
        }

        _onegramWebSocketFrameFin = (bytes[0] & 0x80) != 0;
        _onegramWebSocketFrameOpcode = bytes[0] & 0x0f;
        uint8_t opcode = _onegramWebSocketFrameOpcode;
        if (opcode != 0x0 && opcode != 0x1 && opcode != 0x2 && opcode != 0x8 && opcode != 0x9 && opcode != 0xA)
        {
            [self closeAndNotify];
            return;
        }
        if ((opcode == 0x0 && _onegramWebSocketFragment == nil) || ((opcode == 0x1 || opcode == 0x2) && _onegramWebSocketFragment != nil))
        {
            [self closeAndNotify];
            return;
        }

        uint8_t length = bytes[1] & 0x7f;
        if (opcode >= 0x8 && (!_onegramWebSocketFrameFin || length >= 126))
        {
            [self closeAndNotify];
            return;
        }
        if (length < 126)
        {
            _onegramWebSocketFrameLength = length;
            [self onegramReadWebSocketPayload];
        }
        else if (length == 126)
        {
            [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpOnegramWebSocketFrameLength16];
        }
        else
        {
            [_socket readDataToLength:8 withTimeout:-1 tag:MTTcpOnegramWebSocketFrameLength64];
        }
        return;
    }
    else if (tag == MTTcpOnegramWebSocketFrameLength16)
    {
        if (rawData.length != 2)
        {
            [self closeAndNotify];
            return;
        }
        uint16_t value = 0;
        memcpy(&value, rawData.bytes, 2);
        _onegramWebSocketFrameLength = ntohs(value);
        [self onegramReadWebSocketPayload];
        return;
    }
    else if (tag == MTTcpOnegramWebSocketFrameLength64)
    {
        if (rawData.length != 8)
        {
            [self closeAndNotify];
            return;
        }
        const uint8_t *bytes = rawData.bytes;
        if ((bytes[0] & 0x80) != 0)
        {
            [self closeAndNotify];
            return;
        }
        uint64_t value = 0;
        for (int index = 0; index < 8; index++)
            value = (value << 8) | bytes[index];
        if (value > MTOnegramWebSocketMaxMessageLength)
        {
            [self closeAndNotify];
            return;
        }
        _onegramWebSocketFrameLength = (NSUInteger)value;
        [self onegramReadWebSocketPayload];
        return;
    }
    else if (tag == MTTcpOnegramWebSocketFramePayload)
    {
        [self onegramHandleWebSocketFramePayload:rawData];
        return;
    }

    if (tag == MTTcpSocksLogin) {
        if (rawData.length != sizeof(struct socks5_ident_resp)) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 login response length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        
        struct socks5_ident_resp resp;
        [rawData getBytes:&resp length:sizeof(struct socks5_ident_resp)];
        if (resp.Version != 5) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks response version", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        
        if (resp.Method == 0xFF)
        {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks response method", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        
        if (resp.Method == 0x02) {
            NSMutableData *reqData = [[NSMutableData alloc] init];
            uint8_t version = 1;
            [reqData appendBytes:&version length:1];
            
            NSData *usernameData = [_socksUsername dataUsingEncoding:NSUTF8StringEncoding];
            NSData *passwordData = [_socksPassword dataUsingEncoding:NSUTF8StringEncoding];
            
            uint8_t usernameLength = (uint8_t)(MIN(usernameData.length, 255));
            [reqData appendBytes:&usernameLength length:1];
            [reqData appendData:usernameData];
            
            uint8_t passwordLength = (uint8_t)(MIN(passwordData.length, 255));
            [reqData appendBytes:&passwordLength length:1];
            [reqData appendData:passwordData];
            
            [_socket writeData:reqData withTimeout:-1 tag:0];
            [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpSocksReceiveAuthResponse];
        } else {
            [self requestSocksConnection];
        }
        
        return;
    } else if (tag == MTTcpSocksRequest) {
        struct socks5_resp resp;
        if (rawData.length != 4) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 response length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        [rawData getBytes:&resp length:4];
        
        if (resp.Reply != 0x00) {
            if (MTLogEnabled()) {
                MTLog(@"***** %x %s: socks5 connect failed, error 0x%02x", (int)self, __PRETTY_FUNCTION__, resp.Reply);
            }
            [self closeAndNotify];
            return;
        }
        
        switch (resp.AddrType) {
            case 1: {
                [_socket readDataToLength:sizeof(struct in_addr) withTimeout:-1 tag:MTTcpSocksReceiveBindAddr4];
                break;
            }
            case 3: {
                [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpSocksReceiveBindAddrDomainNameLength];
                break;
            }
            case 4: {
                [_socket readDataToLength:sizeof(struct in6_addr) withTimeout:-1 tag:MTTcpSocksReceiveBindAddr6];
                break;
            }
            default: {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: socks bound to unknown address type", __PRETTY_FUNCTION__);
                }
                [self closeAndNotify];
                return;
            }
        }
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrDomainNameLength) {
        if (rawData.length != 1) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 response domain name data length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        
        uint8_t length = 0;
        [rawData getBytes:&length length:1];
        
        [_socket readDataToLength:(int)length withTimeout:-1 tag:MTTcpSocksReceiveBindAddrDomainName];
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrDomainName || tag == MTTcpSocksReceiveBindAddr4 || tag == MTTcpSocksReceiveBindAddr6) {
        [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpSocksReceiveBindAddrPort];
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrPort) {
        if (_connectionOpened)
            _connectionOpened();
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
            [delegate tcpConnectionOpened:self];
        
        if (_useIntermediateFormat) {
            [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpReadTagPacketFullLength];
        } else {
            [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
        }
        
        return;
    } else if (tag == MTTcpSocksReceiveAuthResponse) {
        int8_t version = 0;
        int8_t status = 0;
        [rawData getBytes:&version range:NSMakeRange(0, 1)];
        [rawData getBytes:&status range:NSMakeRange(1, 1)];
        
        if (version != 1 || status != 0) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 auth response", __PRETTY_FUNCTION__);
            }
            [self closeAndNotify];
            return;
        }
        
        [self requestSocksConnection];
        
        return;
    }
    
    NSMutableData *decryptedData = [[NSMutableData alloc] initWithLength:rawData.length];
    [_incomingAesCtr encryptIn:rawData.bytes out:decryptedData.mutableBytes len:rawData.length];
    
    NSData *data = decryptedData;
    
    if (tag == MTTcpReadTagPacketShortLength)
    {
#ifdef DEBUG
        NSAssert(data.length == 1, @"data length should be equal to 1");
#endif
        
        uint8_t quarterLengthMarker = 0;
        [data getBytes:&quarterLengthMarker length:1];
        
        if ((quarterLengthMarker & 0x80) == 0x80)
        {
            _quickAckByte = quarterLengthMarker;
            [_socket readDataToLength:3 withTimeout:-1 tag:MTTcpReadTagQuickAck];
        }
        else
        {
            if (quarterLengthMarker >= 0x01 && quarterLengthMarker <= 0x7e)
            {
                NSUInteger packetBodyLength = ((NSUInteger)quarterLengthMarker) * 4;
                if (packetBodyLength >= MTTcpProgressCalculationThreshold)
                {
                    _packetRestLength = packetBodyLength - 128;
                    _packetRestReceivedLength = 0;
                    [_socket readDataToLength:128 withTimeout:-1 tag:MTTcpReadTagPacketHead];
                }
                else
                    [_socket readDataToLength:packetBodyLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
            }
            else if (quarterLengthMarker == 0x7f)
                [_socket readDataToLength:3 withTimeout:-1 tag:MTTcpReadTagPacketLongLength];
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: invalid quarter length marker (%" PRIu8 ")", __PRETTY_FUNCTION__, quarterLengthMarker);
                }
                [self closeAndNotify];
            }
        }
    }
    else if (tag == MTTcpReadTagPacketLongLength)
    {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        uint32_t quarterLength = 0;
        [data getBytes:(((uint8_t *)&quarterLength)) length:3];
        
        if (quarterLength <= 0 || quarterLength > (4 * 1024 * 1024) / 4)
        {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid quarter length (%" PRIu32 ")", __PRETTY_FUNCTION__, quarterLength);
            }
            [self closeAndNotify];
        }
        else
        {
            NSUInteger packetBodyLength = quarterLength * 4;
            if (packetBodyLength >= MTTcpProgressCalculationThreshold)
            {
                _packetRestLength = packetBodyLength - 128;
                _packetRestReceivedLength = 0;
                [_socket readDataToLength:128 withTimeout:-1 tag:MTTcpReadTagPacketHead];
            }
            else
                [_socket readDataToLength:packetBodyLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
        }
    } else if (tag == MTTcpReadTagPacketFullLength) {
#ifdef DEBUG
        NSAssert(data.length == 4, @"data length should be equal to 4");
#endif
        
        int32_t length = 0;
        [data getBytes:&length length:4];
        
        if ((length & 0x80000000) == 0x80000000) {
            int32_t ackId = length;
            ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
            ackId = (int32_t)OSSwapInt32(ackId);
            
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
                [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
            
            if (_useIntermediateFormat) {
                [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpReadTagPacketFullLength];
            } else {
                [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
            }
        } else {
            if (length > 16 * 1024 * 1024) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTTcpConnection#%x received invalid length %d]", (int)self, length);
                }
                [self closeAndNotify];
            } else {
                NSUInteger packetBodyLength = (NSUInteger)length;
                
                if (packetBodyLength >= MTTcpProgressCalculationThreshold) {
                    _packetRestLength = packetBodyLength - 128;
                    _packetRestReceivedLength = 0;
                    [_socket readDataToLength:128 withTimeout:-1 tag:MTTcpReadTagPacketHead];
                } else {
                    [_socket readDataToLength:packetBodyLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
                }
            }
        }
    }
    else if (tag == MTTcpReadTagPacketHead)
    {
        _packetHead = data;
        
        static int64_t nextToken = 0;
        _packetHeadDecodeToken = nextToken;
        nextToken++;
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionDecodePacketProgressToken:data:token:completion:)])
        {
            MTTcpConnection *connection = self;
            [delegate tcpConnectionDecodePacketProgressToken:self data:data token:_packetHeadDecodeToken completion:^(int64_t token, id packetProgressToken)
            {
                [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
                    if (token == connection.packetHeadDecodeToken)
                        connection.packetProgressToken = packetProgressToken;
                }];
            }];
        }
        
        [_socket readDataToLength:_packetRestLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
    }
    else if (tag == MTTcpReadTagPacketBody)
    {
        [_responseTimeoutTimer invalidate];
        _responseTimeoutTimer = nil;
        
        _packetHeadDecodeToken = -1;
        _packetProgressToken = nil;
        
        NSData *packetData = data;
        if (_packetHead != nil)
        {
            NSMutableData *combinedData = [[NSMutableData alloc] initWithCapacity:_packetHead.length + data.length];
            [combinedData appendData:_packetHead];
            [combinedData appendData:data];
            packetData = combinedData;
            _packetHead = nil;
        }
        
        if (packetData.length % 4 != 0) {
            int32_t realLength = ((int32_t)packetData.length) & (~3);
            packetData = [packetData subdataWithRange:NSMakeRange(0, (NSUInteger)realLength)];
        }
        
        bool ignorePacket = false;
        if (packetData.length >= 4) {
            int32_t header = 0;
            [packetData getBytes:&header length:4];
            if (header == 0xffffffff) {
                if (packetData.length >= 8) {
                    int32_t ackId = 0;
                    [packetData getBytes:&ackId range:NSMakeRange(4, 4)];
                    ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
                    ackId = (int32_t)OSSwapInt32(ackId);
                    
                    id<MTTcpConnectionDelegate> delegate = _delegate;
                    if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)]) {
                        [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
                    }
                    
                    ignorePacket = true;
                }
            } else if (header == 0 && packetData.length < 16) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTTcpConnection#%x received nop packet]", (int)self);
                }
                ignorePacket = true;
            }
        }
        
        if (!ignorePacket) {
            if (_connectionReceivedData)
                _connectionReceivedData(packetData);
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionReceivedData:data:)])
                [delegate tcpConnectionReceivedData:self data:packetData];
        }
        
        if (_useIntermediateFormat) {
            [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpReadTagPacketFullLength];
        } else {
            [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
        }
    }
    else if (tag == MTTcpReadTagQuickAck)
    {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        int32_t ackId = 0;
        ((uint8_t *)&ackId)[0] = _quickAckByte;
        memcpy(((uint8_t *)&ackId) + 1, data.bytes, 3);
        ackId = (int32_t)OSSwapInt32(ackId);
        ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
            [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
        
        if (_useIntermediateFormat) {
            [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpReadTagPacketFullLength];
        } else {
            [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
        }
    }
}
             
- (void)socket:(GCDAsyncSocket *)__unused socket didConnectToHost:(NSString *)__unused host port:(uint16_t)__unused port
{
#if TARGET_OS_IPHONE
    BOOL isPrimaryDataConnection = _usageCalculationInfo != nil &&
        [_usageCalculationInfo incomingWWANKey] == 0 &&
        [_usageCalculationInfo outgoingWWANKey] == 1 &&
        [_usageCalculationInfo incomingOtherKey] == 2 &&
        [_usageCalculationInfo outgoingOtherKey] == 3;
    if ([[UIDevice currentDevice].systemVersion intValue] <= 6 && isPrimaryDataConnection) {
        __block BOOL backgroundingEnabled = NO;
        __block int socketFd = -1;
        __block int keepAliveResult = -2;
        __block int keepAliveError = 0;
        __block int keepAliveIdleResult = -2;
        __block int keepAliveIdleError = 0;
        [_socket performBlock:^{
            if ([[UIDevice currentDevice].systemVersion intValue] <= 4)
                backgroundingEnabled = [_socket enableBackgroundingOnSocketWithCaveat];
            else
                backgroundingEnabled = [_socket enableBackgroundingOnSocket];

            socketFd = [_socket socketFD];
            if (socketFd >= 0) {
                int keepAlive = 1;
                keepAliveResult = setsockopt(socketFd, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive));
                if (keepAliveResult != 0)
                    keepAliveError = errno;
#ifdef TCP_KEEPALIVE
                int keepAliveIdle = 60;
                keepAliveIdleResult = setsockopt(socketFd, IPPROTO_TCP, TCP_KEEPALIVE, &keepAliveIdle, sizeof(keepAliveIdle));
                if (keepAliveIdleResult != 0)
                    keepAliveIdleError = errno;
#endif
            }
        }];
        IOS6NotificationProbe(@"SOCKET", @"primary_connected host=%@ port=%d background=%d fd=%d soKeepAlive=%d/%d tcpKeepAlive=%d/%d",
                              host ?: @"none", (int)port, backgroundingEnabled ? 1 : 0, socketFd,
                              keepAliveResult, keepAliveError, keepAliveIdleResult, keepAliveIdleError);
        NSLog(@"PUSH voipSocket enabled=%d host=%@ port=%d", backgroundingEnabled ? 1 : 0, host, (int)port);
    }
#endif
    
    if (_onegramWebSocket)
    {
        NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithObject:_onegramWebSocketDomain forKey:(NSString *)kCFStreamSSLPeerName];
#if TARGET_OS_IPHONE
        if ([[UIDevice currentDevice].systemVersion intValue] <= 6)
        {
            NSData *trustedCertificates = [NSData dataWithBytes:MTOnegramProxyTLSRoots length:sizeof(MTOnegramProxyTLSRoots) - 1];
            [settings setObject:@YES forKey:GCDAsyncSocketUseOpenSSL];
            [settings setObject:trustedCertificates forKey:GCDAsyncSocketOpenSSLTrustedCertificates];
            [settings setObject:@([_context globalTime]) forKey:GCDAsyncSocketOpenSSLVerificationTime];
        }
#endif
        [_socket startTLS:settings];
        return;
    }

    if (_socksIp != nil) {
        
    } else {
        if (_connectionOpened)
            _connectionOpened();
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
            [delegate tcpConnectionOpened:self];
    }
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    if (!_onegramWebSocket || sock != _socket || _closed)
        return;

    uint8_t randomBytes[16];
    arc4random_buf(randomBytes, sizeof(randomBytes));
    _onegramWebSocketKey = MTOnegramBase64([NSData dataWithBytes:randomBytes length:sizeof(randomBytes)]);

    NSString *request = [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %@\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: binary\r\n\r\n", _onegramWebSocketPath, _onegramWebSocketDomain, _onegramWebSocketKey];
    [_socket writeData:[request dataUsingEncoding:NSUTF8StringEncoding] withTimeout:5 tag:0];
    NSData *headerTerminator = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    [_socket readDataToData:headerTerminator withTimeout:5 maxLength:32768 tag:MTTcpOnegramWebSocketHttpHeader];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)__unused socket withError:(NSError *)error
{
#if TARGET_OS_IPHONE
    BOOL isPrimaryDataConnection = _usageCalculationInfo != nil &&
        [_usageCalculationInfo incomingWWANKey] == 0 &&
        [_usageCalculationInfo outgoingWWANKey] == 1 &&
        [_usageCalculationInfo incomingOtherKey] == 2 &&
        [_usageCalculationInfo outgoingOtherKey] == 3;
    if ([[UIDevice currentDevice].systemVersion intValue] <= 6 && isPrimaryDataConnection)
    {
        IOS6NotificationProbe(@"SOCKET", @"primary_disconnected domain=%@ code=%ld description=%@",
                              error.domain ?: @"none", (long)error.code, error.localizedDescription ?: @"none");
    }
#endif

    if (_onegramWebSocket && !_onegramWebSocketReady && !_closed)
    {
        [self onegramWebSocketAttemptFailed];
        return;
    }

    if (error != nil) {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%x disconnected from %@ (%@)]", (int)self, _address.ip, error);
        }
    }
    else {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%x disconnected from %@]", (int)self, _address.ip);
        }
    }
    
    [self closeAndNotify];
}

@end
