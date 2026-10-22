#import "AWGIPStack.h"
#import "AWGTunnel.h"
#import "OGDanteSupport.h"
#import <dispatch/dispatch.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <string.h>

#pragma pack(push, 1)
typedef struct {
    uint8_t  version_ihl;
    uint8_t  tos;
    uint16_t total_length;
    uint16_t identification;
    uint16_t flags_fragment;
    uint8_t  ttl;
    uint8_t  protocol;
    uint16_t checksum;
    uint32_t source_addr;
    uint32_t dest_addr;
} AWGIPv4Header;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct {
    uint16_t source_port;
    uint16_t dest_port;
    uint16_t length;
    uint16_t checksum;
} AWGUDPHeader;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct {
    uint16_t source_port;
    uint16_t dest_port;
    uint32_t seq;
    uint32_t ack;
    uint8_t  data_offset_reserved;
    uint8_t  flags;
    uint16_t window;
    uint16_t checksum;
    uint16_t urgent;
} AWGTCPHeader;
#pragma pack(pop)

static const size_t kIPv4HeaderLen = sizeof(AWGIPv4Header);
static const size_t kTCPHeaderLen = sizeof(AWGTCPHeader);
static const size_t kUDPHeaderLen = sizeof(AWGUDPHeader);

static const uint8_t kTCPFin = 0x01;
static const uint8_t kTCPSyn = 0x02;
static const uint8_t kTCPRst = 0x04;
static const uint8_t kTCPPsh = 0x08;
static const uint8_t kTCPAck = 0x10;

static const NSTimeInterval kRetransmitTick = 0.1;
static const NSTimeInterval kRetransmitInitialRTO = 0.5;
static const int kRetransmitMaxTries = 6;

static const uint32_t kAckEvery = 2;

volatile uint32_t gAWGRxOutOfOrder, gAWGRxDuplicate;

volatile uint32_t gAWGRecvWindow = 524288;

typedef struct { uint32_t start, end; } AWGSackRange;

static int awgSackRangeCompare(const void *a, const void *b) {
    uint32_t x = ((const AWGSackRange *)a)->start, y = ((const AWGSackRange *)b)->start;
    return x < y ? -1 : x > y ? 1 : 0;
}

static inline BOOL seqLE(uint32_t a, uint32_t b) { return (int32_t)(a - b) <= 0; }
static inline BOOL seqLT(uint32_t a, uint32_t b) { return (int32_t)(a - b) < 0; }

@interface AWGTCPPendingSegment : NSObject
@property (nonatomic, assign) uint32_t seq;
@property (nonatomic, retain) NSData *payload;
@property (nonatomic, assign) NSTimeInterval sentAt;
@property (nonatomic, assign) int tries;

@property (nonatomic, assign) BOOL sacked;
@end

@implementation AWGTCPPendingSegment
- (void)dealloc {
    [_payload release];
    [super dealloc];
}
@end

@interface AWGTCPConnectionState : NSObject
{
    NSCondition *_stateCondition;
    uint8_t _state;
}
@property (nonatomic, assign) uint32_t connectionID;
@property (nonatomic, assign) int clientFd;
@property (nonatomic, assign) uint32_t localSeq;
@property (nonatomic, assign) uint32_t remoteSeq;
@property (nonatomic, assign) uint16_t localPort;
@property (nonatomic, assign) uint16_t remotePort;
@property (nonatomic, assign) uint32_t remoteIP;
@property (nonatomic, assign) uint8_t state;
@property (nonatomic, retain) NSMutableData *receiveBuffer;
@property (nonatomic, retain) NSMutableDictionary *outOfOrder;
@property (nonatomic, assign) NSUInteger outOfOrderBytes;
@property (nonatomic, assign) uint32_t lastOutOfOrderSeq;
@property (nonatomic, retain) NSCondition *deliveryCondition;
@property (nonatomic, assign) NSUInteger deliveryTasks;
@property (nonatomic, assign) dispatch_queue_t deliveryQueue;
@property (nonatomic, retain) NSMutableArray *unacked;
@property (nonatomic, assign) NSTimeInterval synSentAt;
@property (nonatomic, assign) int synTries;
@property (nonatomic, assign) NSTimeInterval establishedAt;
@property (nonatomic, assign) uint64_t bytesIn;
@property (nonatomic, assign) uint64_t bytesHanded;
@property (nonatomic, assign) BOOL stallReported;
@property (nonatomic, assign) uint8_t ourWindowScale;
@property (nonatomic, assign) uint8_t peerWindowScale;
@property (nonatomic, assign) BOOL windowScaleActive;
@property (nonatomic, assign) BOOL sackPermitted;
@property (nonatomic, assign) uint32_t unackedPackets;
@property (nonatomic, assign) uint32_t unackedBytes;
@property (nonatomic, retain) NSMutableData *pendingDeliverData;

@property (nonatomic, assign) NSUInteger undeliveredBytes;
@property (nonatomic, assign) BOOL windowClosed;

@property (nonatomic, retain) NSMutableData *sendQueue;
@property (nonatomic, assign) NSUInteger sendQueueOffset;
@property (nonatomic, assign) NSUInteger inFlight;
@property (nonatomic, assign) NSUInteger cwnd;
@property (nonatomic, assign) NSUInteger ssthresh;
@property (nonatomic, assign) uint32_t peerWindow;
@property (nonatomic, assign) uint32_t lastAckNo;
@property (nonatomic, assign) int dupAcks;

@property (nonatomic, assign) NSTimeInterval srtt;
@property (nonatomic, assign) NSTimeInterval rttvar;
@property (nonatomic, assign) NSTimeInterval rto;
- (BOOL)waitForEstablishmentUntilDate:(NSDate *)deadline;
@end

@implementation AWGTCPConnectionState

- (instancetype)init {
    self = [super init];
    if (self) _stateCondition = [[NSCondition alloc] init];
    return self;
}

- (uint8_t)state {
    [_stateCondition lock];
    uint8_t value = _state;
    [_stateCondition unlock];
    return value;
}

- (void)setState:(uint8_t)state {
    [_stateCondition lock];
    _state = state;
    [_stateCondition broadcast];
    [_stateCondition unlock];
}

- (BOOL)waitForEstablishmentUntilDate:(NSDate *)deadline {
    [_stateCondition lock];
    while (_state == 1) {
        if (![_stateCondition waitUntilDate:deadline]) break;
    }
    BOOL established = _state == 2;
    [_stateCondition unlock];
    return established;
}

- (void)dealloc {
    [_stateCondition release];
    [_receiveBuffer release];
    [_outOfOrder release];
    [_deliveryCondition release];
    if (_deliveryQueue != NULL) dispatch_release(_deliveryQueue);
    [_unacked release];
    [_pendingDeliverData release];
    [_sendQueue release];
    [super dealloc];
}
@end

@interface AWGDeliveryTask : NSObject
@property (nonatomic, retain) AWGTCPConnectionState *connection;
@property (nonatomic, retain) NSData *data;
@property (nonatomic, assign) int fd;
@property (nonatomic, assign) uint32_t connectionID;
@property (nonatomic, assign) BOOL closeAfter;
@end

@implementation AWGDeliveryTask
- (void)dealloc {
    [_connection release];
    [_data release];
    [super dealloc];
}
@end

@interface AWGIPStack () {
    AWGTunnel *_tunnel;
    NSString *_localIPv4;
    NSString *_localIPv6;
    uint32_t _nextConnectionID;
    uint32_t _portBase;
    NSUInteger _tunnelMTU;
    NSMutableDictionary *_connections;
    NSMutableDictionary *_connectionMap;
    AWGTCPConnectionState *_portTable[16384];

    volatile uint64_t _portOwner[16384];
    NSRecursiveLock *_lock;
    NSTimeInterval _nextRetransmitAt;
    uint16_t _ipID;

    NSMutableDictionary *_dnsCache;
    NSMutableDictionary *_dnsPending;
    NSLock *_dnsLock;
    uint16_t _dnsNextID;

    uint16_t _dnsSrcPort;

    NSMutableSet *_ackPending;
    NSMutableSet *_deliverPending;
}
@end

@implementation AWGIPStack

- (NSUInteger)tunnelMTU { return _tunnelMTU ?: 1280; }
@synthesize hasPendingWork = _hasPendingWork;

- (void)setTunnelMTU:(NSUInteger)mtu { _tunnelMTU = (mtu >= 576 && mtu <= 1500) ? mtu : 1280; }

- (instancetype)initWithTunnel:(AWGTunnel *)tunnel localIPv4:(NSString *)ipv4 localIPv6:(NSString *)ipv6 {
    self = [super init];
    if (self) {
        _tunnel = tunnel;
        NSArray *ipv4Parts = [(ipv4 ?: @"10.2.0.2") componentsSeparatedByString:@"/"];
        _localIPv4 = [[ipv4Parts objectAtIndex:0] copy];
        NSArray *ipv6Parts = [ipv6 componentsSeparatedByString:@"/"];
        _localIPv6 = ([ipv6Parts count] > 0) ? [[ipv6Parts objectAtIndex:0] copy] : nil;
        _nextConnectionID = 1;

        _portBase = DanteRandomUniform(16384);
        _dnsSrcPort = (uint16_t)(20000 + DanteRandomUniform(20000));
        _connections = [[NSMutableDictionary alloc] init];
        _connectionMap = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < 16384; i++) _portTable[i] = nil;
        _lock = [[NSRecursiveLock alloc] init];
        _nextRetransmitAt = [NSDate timeIntervalSinceReferenceDate] + kRetransmitTick;
        _ipID = 0;
        _dnsCache = [[NSMutableDictionary alloc] init];
        _dnsPending = [[NSMutableDictionary alloc] init];
        _dnsLock = [[NSLock alloc] init];
        _dnsNextID = (uint16_t)arc4random();
        _dnsServerIPv4 = [@"1.1.1.1" copy];
        _tunnelMTU = 1280;
        _ackPending = [[NSMutableSet alloc] init];
        _deliverPending = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    for (int i = 0; i < 16384; i++) _portTable[i] = nil;
    [_localIPv4 release];
    [_localIPv6 release];
    [_connections release];
    [_connectionMap release];
    [_lock release];
    [_dnsCache release];
    [_dnsPending release];
    [_dnsLock release];
    [_dnsServerIPv4 release];
    [_ackPending release];
    [_deliverPending release];
    [super dealloc];
}


static uint16_t ipChecksum(const void *data, size_t len) {
    const uint16_t *w = (const uint16_t *)data;
    uint32_t sum = 0;
    while (len > 1) {
        sum += ntohs(*w++);
        len -= 2;
    }
    if (len) sum += (*(const uint8_t *)w) << 8;
    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return htons(~sum);
}

static uint16_t transportChecksum(const AWGIPv4Header *ip, uint8_t protocol,
                                  const uint8_t *header, size_t headerLen,
                                  const uint8_t *payload, size_t payloadLen) {
    uint32_t sum = 0;
    const uint8_t *s = (const uint8_t *)&ip->source_addr;
    const uint8_t *d = (const uint8_t *)&ip->dest_addr;
    size_t i;

    sum += (uint32_t)((s[0] << 8) | s[1]);
    sum += (uint32_t)((s[2] << 8) | s[3]);
    sum += (uint32_t)((d[0] << 8) | d[1]);
    sum += (uint32_t)((d[2] << 8) | d[3]);
    sum += protocol;
    sum += (uint32_t)(headerLen + payloadLen);

    for (i = 0; i + 1 < headerLen; i += 2) sum += (uint32_t)((header[i] << 8) | header[i + 1]);
    if (headerLen & 1) sum += (uint32_t)(header[headerLen - 1] << 8);

    for (i = 0; i + 1 < payloadLen; i += 2) sum += (uint32_t)((payload[i] << 8) | payload[i + 1]);
    if (payloadLen & 1) sum += (uint32_t)(payload[payloadLen - 1] << 8);

    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return htons((uint16_t)~sum);
}


static uint16_t udpChecksum(const AWGIPv4Header *ip, const AWGUDPHeader *udp,
                            const uint8_t *payload, size_t payloadLen) {
    uint16_t result = transportChecksum(ip, AWGIPProtocolUDP, (const uint8_t *)udp, kUDPHeaderLen,
                                        payload, payloadLen);
    return result ? result : 0xffff;
}

- (void)sendUDPTo:(uint32_t)dstIP port:(uint16_t)port payload:(NSData *)payload {
    size_t total = kIPv4HeaderLen + kUDPHeaderLen + payload.length;
    NSMutableData *packet = [NSMutableData dataWithLength:total];
    uint8_t *bytes = packet.mutableBytes;

    AWGIPv4Header *ip = (AWGIPv4Header *)bytes;
    ip->version_ihl = 0x45;
    ip->tos = 0;
    ip->total_length = htons((uint16_t)total);
    ip->identification = htons(++_ipID);
    ip->flags_fragment = htons(0x4000);
    ip->ttl = 64;
    ip->protocol = AWGIPProtocolUDP;
    ip->checksum = 0;
    inet_pton(AF_INET, [_localIPv4 UTF8String], &ip->source_addr);
    ip->dest_addr = dstIP;
    ip->checksum = ipChecksum(ip, kIPv4HeaderLen);

    AWGUDPHeader *udp = (AWGUDPHeader *)(bytes + kIPv4HeaderLen);
    udp->source_port = htons(_dnsSrcPort);
    udp->dest_port = htons(port);
    udp->length = htons((uint16_t)(kUDPHeaderLen + payload.length));
    udp->checksum = 0;
    memcpy(bytes + kIPv4HeaderLen + kUDPHeaderLen, payload.bytes, payload.length);
    udp->checksum = udpChecksum(ip, udp, bytes + kIPv4HeaderLen + kUDPHeaderLen, payload.length);

    [self sendIPPacket:packet];
}

static NSData *dnsQueryForHost(NSString *host, uint16_t txid) {
    NSMutableData *q = [NSMutableData data];
    uint16_t v;
    v = htons(txid);    [q appendBytes:&v length:2];
    v = htons(0x0100);  [q appendBytes:&v length:2];
    v = htons(1);       [q appendBytes:&v length:2];
    v = 0;              [q appendBytes:&v length:2];
                        [q appendBytes:&v length:2];
                        [q appendBytes:&v length:2];

    for (NSString *label in [host componentsSeparatedByString:@"."]) {
        NSData *l = [label dataUsingEncoding:NSUTF8StringEncoding];
        if (l.length == 0 || l.length > 63) continue;
        uint8_t len = (uint8_t)l.length;
        [q appendBytes:&len length:1];
        [q appendData:l];
    }
    uint8_t zero = 0;
    [q appendBytes:&zero length:1];
    v = htons(1); [q appendBytes:&v length:2];
    v = htons(1); [q appendBytes:&v length:2];
    return q;
}

static size_t dnsSkipName(const uint8_t *buf, size_t len, size_t at) {
    while (at < len) {
        uint8_t l = buf[at];
        if (l == 0) return at + 1;
        if ((l & 0xc0) == 0xc0) return at + 2;
        at += 1 + l;
    }
    return len;
}

static uint32_t dnsParseAnswer(const uint8_t *buf, size_t len, uint16_t expectID) {
    if (len < 12) return 0;
    if (ntohs(*(const uint16_t *)buf) != expectID) return 0;
    uint16_t qdcount = ntohs(*(const uint16_t *)(buf + 4));
    uint16_t ancount = ntohs(*(const uint16_t *)(buf + 6));
    if (ancount == 0) return 0;

    size_t at = 12;
    uint16_t i;
    for (i = 0; i < qdcount && at < len; i++) {
        at = dnsSkipName(buf, len, at);
        at += 4;
    }
    for (i = 0; i < ancount && at + 10 <= len; i++) {
        at = dnsSkipName(buf, len, at);
        if (at + 10 > len) break;
        uint16_t type = ntohs(*(const uint16_t *)(buf + at));
        uint16_t rdlen = ntohs(*(const uint16_t *)(buf + at + 8));
        at += 10;
        if (at + rdlen > len) break;
        if (type == 1 && rdlen == 4) {
            uint32_t addr;
            memcpy(&addr, buf + at, 4);
            return addr;
        }
        at += rdlen;
    }
    return 0;
}

- (uint32_t)resolveIPv4:(NSString *)host {
    if (host.length == 0) return 0;

    struct in_addr literal;
    if (inet_pton(AF_INET, [host UTF8String], &literal) == 1) return literal.s_addr;

    [_dnsLock lock];
    NSNumber *cached = [_dnsCache objectForKey:host];
    uint32_t cachedAddress = cached != nil ? (uint32_t)[cached unsignedIntValue] : 0;
    [_dnsLock unlock];
    if (cached != nil) return cachedAddress;

    uint32_t serverIP = 0;
    if (inet_pton(AF_INET, [(self.dnsServerIPv4 ?: @"1.1.1.1") UTF8String], &serverIP) != 1) {
        inet_pton(AF_INET, "1.1.1.1", &serverIP);
    }

    int attempt;
    for (attempt = 0; attempt < 2; attempt++) {
        [_dnsLock lock];
        uint16_t txid = _dnsNextID++;

        NSCondition *cond = [[NSCondition alloc] init];
        NSMutableDictionary *slot = [NSMutableDictionary dictionary];
        [slot setObject:cond forKey:@"cond"];
        [_dnsPending setObject:slot forKey:[NSNumber numberWithUnsignedInt:txid]];
        [_dnsLock unlock];

        [self sendUDPTo:serverIP port:53 payload:dnsQueryForHost(host, txid)];

        [cond lock];
        [cond waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [cond unlock];

        [_dnsLock lock];
        NSNumber *answer = [slot objectForKey:@"addr"];
        [_dnsPending removeObjectForKey:[NSNumber numberWithUnsignedInt:txid]];
        if (answer) [_dnsCache setObject:answer forKey:host];
        [_dnsLock unlock];
        [cond release];

        if (answer) {
            uint32_t a = (uint32_t)[answer unsignedIntValue];
            DLog(@"[AWG IP] %@ -> %u.%u.%u.%u (via the tunnel)", host,
                 a & 0xff, (a >> 8) & 0xff, (a >> 16) & 0xff, (a >> 24) & 0xff);
            return a;
        }
    }

    DLog(@"[AWG IP] DNS timed out for %@ (server %@)", host, self.dnsServerIPv4);
    return 0;
}

- (NSData *)relayDNSQuery:(NSData *)query timeout:(NSTimeInterval)timeout {
    if (query.length < 12) return nil;
    uint32_t serverIP = 0;
    if (inet_pton(AF_INET, [(self.dnsServerIPv4 ?: @"1.1.1.1") UTF8String], &serverIP) != 1) {
        inet_pton(AF_INET, "1.1.1.1", &serverIP);
    }

    uint16_t clientID;
    memcpy(&clientID, query.bytes, 2);
    [_dnsLock lock];
    uint16_t txid = _dnsNextID++;
    NSCondition *cond = [[NSCondition alloc] init];
    NSMutableDictionary *slot = [NSMutableDictionary dictionary];
    [slot setObject:cond forKey:@"cond"];
    [slot setObject:[NSNumber numberWithBool:YES] forKey:@"raw"];
    [_dnsPending setObject:slot forKey:[NSNumber numberWithUnsignedInt:txid]];
    [_dnsLock unlock];

    NSMutableData *q = [query mutableCopy];
    uint16_t be = htons(txid);
    [q replaceBytesInRange:NSMakeRange(0, 2) withBytes:&be];
    [self sendUDPTo:serverIP port:53 payload:q];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSMutableData *reply = nil;
    [cond lock];
    while (!(reply = [slot objectForKey:@"reply"]) && [cond waitUntilDate:deadline]) {}
    [cond unlock];

    [reply retain];
    [_dnsLock lock];
    [_dnsPending removeObjectForKey:[NSNumber numberWithUnsignedInt:txid]];
    [_dnsLock unlock];
    [cond release];
    [q release];

    if ([reply length] < 2) {
        [reply release];
        return nil;
    }
    [reply replaceBytesInRange:NSMakeRange(0, 2) withBytes:&clientID];
    return [reply autorelease];
}

- (BOOL)handleUDPPacket:(const uint8_t *)bytes length:(size_t)len ipHeaderLen:(size_t)ipHeaderLen {
    if (len < ipHeaderLen + kUDPHeaderLen) return NO;
    const AWGUDPHeader *udp = (const AWGUDPHeader *)(bytes + ipHeaderLen);
    if (ntohs(udp->source_port) != 53) return NO;

    const uint8_t *dns = bytes + ipHeaderLen + kUDPHeaderLen;
    size_t dnsLen = len - ipHeaderLen - kUDPHeaderLen;
    if (dnsLen < 12) return YES;

    uint16_t txid = ntohs(*(const uint16_t *)dns);
    [_dnsLock lock];
    NSMutableDictionary *slot = [_dnsPending objectForKey:[NSNumber numberWithUnsignedInt:txid]];
    if (slot && [[slot objectForKey:@"raw"] boolValue]) {
        NSCondition *cond = [slot objectForKey:@"cond"];
        [cond lock];
        [slot setObject:[NSMutableData dataWithBytes:dns length:dnsLen] forKey:@"reply"];
        [cond signal];
        [cond unlock];
    } else if (slot) {
        uint32_t addr = dnsParseAnswer(dns, dnsLen, txid);
        if (!addr) {
            NSMutableString *hex = [NSMutableString string];
            for (size_t i = 0; i < dnsLen && i < 128; i++) {
                [hex appendFormat:@"%02x", dns[i]];
            }
            DLog(@"[AWG IP] DNS raw: %@", hex);
        }
        if (addr) [slot setObject:[NSNumber numberWithUnsignedInt:addr] forKey:@"addr"];
        NSCondition *cond = [slot objectForKey:@"cond"];
        [cond lock];
        [cond signal];
        [cond unlock];
    } else {
        DLog(@"[AWG IP] DNS reply с чужим txid %u (ждём другие)", txid);
    }
    [_dnsLock unlock];
    return YES;
}


- (uint32_t)openTCPToHost:(NSString *)host port:(uint16_t)port {

    uint32_t remoteIP = [self resolveIPv4:host];
    if (remoteIP == 0) {
        DLog(@"[AWG IP] Cannot resolve %@", host);
        return 0;
    }

    uint32_t connID = 0;
    [_lock lock];
    @try {
        connID = _nextConnectionID++;
        AWGTCPConnectionState *conn = [[AWGTCPConnectionState alloc] init];
        conn.connectionID = connID;
        conn.localSeq = arc4random();
        conn.remoteSeq = 0;
        conn.localPort = (uint16_t)(49152 + ((connID + self->_portBase) % 16384));
        conn.remotePort = port;
        conn.state = 1;
        conn.receiveBuffer = [NSMutableData data];
        conn.outOfOrder = [NSMutableDictionary dictionary];
        conn.unacked = [NSMutableArray array];
        conn.sendQueue = [NSMutableData data];
        conn.cwnd = 10 * (self.tunnelMTU - kIPv4HeaderLen - kTCPHeaderLen);

        conn.ssthresh = 131072;
        conn.rto = kRetransmitInitialRTO;
        conn.peerWindow = 65535;

        conn.deliveryCondition = [[[NSCondition alloc] init] autorelease];
        conn.deliveryQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.warp.delivery", DISPATCH_QUEUE_SERIAL);
        conn.ourWindowScale = 7;
        conn.clientFd = -1;
        _portTable[conn.localPort - 49152] = conn;
        _portOwner[conn.localPort - 49152] = ((uint64_t)remoteIP << 16) | port;
        [_connections setObject:conn forKey:[NSNumber numberWithUnsignedInt:connID]];

        conn.remoteIP = remoteIP;

        NSString *key = [NSString stringWithFormat:@"%@:%u:%u.%u.%u.%u:%u",
                         _localIPv4, conn.localPort,
                         conn.remoteIP & 0xff, (conn.remoteIP >> 8) & 0xff,
                         (conn.remoteIP >> 16) & 0xff, (conn.remoteIP >> 24) & 0xff,
                         conn.remotePort];
        [_connectionMap setObject:[NSNumber numberWithUnsignedInt:connID] forKey:key];

        conn.synSentAt = [NSDate timeIntervalSinceReferenceDate];
        conn.synTries = 1;
        DLog(@"[AWG IP] conn %u -> %@:%u (%u.%u.%u.%u) from port %u",
             connID, host, port,
             conn.remoteIP & 0xff, (conn.remoteIP >> 8) & 0xff,
             (conn.remoteIP >> 16) & 0xff, (conn.remoteIP >> 24) & 0xff,
             conn.localPort);
        [self sendTCPPacketForConnection:conn flags:kTCPSyn payload:nil];
        [conn release];
    }
    @finally {
        [_lock unlock];
    }
    return connID;
}

- (BOOL)waitForConnection:(uint32_t)connectionID timeout:(NSTimeInterval)timeout {

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    [_lock lock];
    AWGTCPConnectionState *dead = [[_connections objectForKey:[NSNumber numberWithUnsignedInt:connectionID]] retain];
    [_lock unlock];
    if ([dead waitForEstablishmentUntilDate:deadline]) {
        [dead release];
        return YES;
    }
    DLog(@"[AWG IP] connection %u never established (%u.%u.%u.%u:%u from port %u)", connectionID,
         dead.remoteIP & 0xff, (dead.remoteIP >> 8) & 0xff,
         (dead.remoteIP >> 16) & 0xff, (dead.remoteIP >> 24) & 0xff,
         dead.remotePort, dead.localPort);
    [dead release];
    return NO;
}

- (void)sendTCPData:(NSData *)data connectionID:(uint32_t)connectionID {
    [_lock lock];
    @try {
        AWGTCPConnectionState *conn = [_connections objectForKey:[NSNumber numberWithUnsignedInt:connectionID]];
        if (!conn || conn.state != 2) {
            DLog(@"[AWG IP] tx %lu bytes on conn %u DROPPED (state %d)",
                 (unsigned long)[data length], connectionID, conn ? conn.state : -1);
            return;
        }
        DLogVerbose(@"[AWG IP] conn %u: tx %lu bytes (localSeq %u, unacked %lu)",
             connectionID, (unsigned long)[data length], conn.localSeq, (unsigned long)[conn.unacked count]);
        if (!conn.sendQueue) conn.sendQueue = [NSMutableData data];
        [conn.sendQueue appendData:data];
        [self pumpSendLocked:conn];
    }
    @finally {
        [_lock unlock];
    }
}

- (void)pumpSendLocked:(AWGTCPConnectionState *)conn {
    if (conn.state != 2 || conn.sendQueue.length <= conn.sendQueueOffset) return;
    NSUInteger mss = self.tunnelMTU - kIPv4HeaderLen - kTCPHeaderLen;
    NSUInteger limit = MIN(conn.cwnd, (NSUInteger)conn.peerWindow);
    while (conn.sendQueue.length > conn.sendQueueOffset && conn.inFlight < limit) {
        NSUInteger available = conn.sendQueue.length - conn.sendQueueOffset;
        NSUInteger len = MIN(mss, available);
        if (conn.inFlight + len > limit) {

            len = limit - conn.inFlight;
            if (len == 0) break;
        }

        NSData *chunk = [NSData dataWithBytes:(const uint8_t *)conn.sendQueue.bytes + conn.sendQueueOffset
                                       length:len];
        conn.sendQueueOffset += len;
        if (conn.sendQueueOffset >= conn.sendQueue.length) {
            [conn.sendQueue setLength:0];
            conn.sendQueueOffset = 0;
        } else if (conn.sendQueueOffset >= 65536) {
            [conn.sendQueue replaceBytesInRange:NSMakeRange(0, conn.sendQueueOffset)
                                      withBytes:NULL length:0];
            conn.sendQueueOffset = 0;
        }
        AWGTCPPendingSegment *seg = [[AWGTCPPendingSegment alloc] init];
        seg.seq = conn.localSeq;
        seg.payload = chunk;
        seg.sentAt = [NSDate timeIntervalSinceReferenceDate];
        seg.tries = 1;
        [conn.unacked addObject:seg];
        [seg release];
        [self sendTCPPacketForConnection:conn flags:kTCPAck | kTCPPsh payload:chunk];
        conn.localSeq += (uint32_t)len;
        conn.inFlight += len;
    }
}

- (void)closeTCPConnection:(uint32_t)connectionID {
    [_lock lock];
    @try {
        AWGTCPConnectionState *conn = [_connections objectForKey:[NSNumber numberWithUnsignedInt:connectionID]];
        if (!conn) return;
        [self sendTCPPacketForConnection:conn flags:kTCPFin | kTCPAck payload:nil];
        conn.state = 3;
        if (conn.localPort >= 49152) {
            _portTable[conn.localPort - 49152] = nil;
            _portOwner[conn.localPort - 49152] = 0;
        }
        [_connections removeObjectForKey:[NSNumber numberWithUnsignedInt:connectionID]];
    }
    @finally {
        [_lock unlock];
    }
}



- (void)setClientFd:(int)fd forConnectionID:(uint32_t)connID {
    [_lock lock];
    AWGTCPConnectionState *conn = [_connections objectForKey:[NSNumber numberWithUnsignedInt:connID]];
    if (conn) conn.clientFd = fd;
    [_lock unlock];
}

- (NSUInteger)sendBacklogForConnection:(uint32_t)connID {
    [_lock lock];
    AWGTCPConnectionState *conn = [_connections objectForKey:[NSNumber numberWithUnsignedInt:connID]];
    NSUInteger n = conn ? ([conn.sendQueue length] - conn.sendQueueOffset) : 0;
    [_lock unlock];
    return n;
}

- (void)closeTCPConnectionAndDrain:(uint32_t)connID {
    [_lock lock];
    AWGTCPConnectionState *conn = [[_connections objectForKey:[NSNumber numberWithUnsignedInt:connID]] retain];
    [_lock unlock];
    [self closeTCPConnection:connID];
    if (!conn) return;
    [conn.deliveryCondition lock];
    while (conn.deliveryTasks > 0) {
        [conn.deliveryCondition wait];
    }
    [conn.deliveryCondition unlock];
    [conn release];
}

- (void)queueDeliveryForConnection:(AWGTCPConnectionState *)conn data:(NSData *)data closeAfter:(BOOL)closeAfter {
    if (!conn || (!data && !closeAfter)) return;
    AWGDeliveryTask *task = [[AWGDeliveryTask alloc] init];
    task.connection = conn;
    task.data = data;
    task.fd = conn.clientFd;
    task.connectionID = conn.connectionID;
    task.closeAfter = closeAfter;
    [conn.deliveryCondition lock];
    conn.deliveryTasks += 1;
    dispatch_async(conn.deliveryQueue, ^{
        [self deliverTask:task];
    });
    [conn.deliveryCondition unlock];
    [task release];
}

- (void)deliverTask:(AWGDeliveryTask *)task {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AWGTCPConnectionState *conn = task.connection;

    NSData *data = task.data;
    NSUInteger len = [data length];
    if (data) [_tunnel deliverData:data toFd:task.fd connectionID:task.connectionID];
    if (task.closeAfter) [_tunnel deliverData:nil toFd:task.fd connectionID:task.connectionID];

    [_lock lock];
    if (data) {
        conn.bytesHanded += len;
        conn.undeliveredBytes = (conn.undeliveredBytes > len) ? (conn.undeliveredBytes - len) : 0;
        if (conn.windowClosed && conn.state == 2 &&
            conn.undeliveredBytes + conn.outOfOrderBytes < gAWGRecvWindow / 2) {
            conn.windowClosed = NO;
            [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
        }
    }
    [_lock unlock];

    [conn.deliveryCondition lock];
    if (conn.deliveryTasks > 0) conn.deliveryTasks -= 1;
    [conn.deliveryCondition broadcast];
    [conn.deliveryCondition unlock];
    [pool drain];
}

- (void)deliverPendingLocked:(AWGTCPConnectionState *)conn {
    NSMutableData *data = [conn.pendingDeliverData retain];
    if ([data length] == 0) {
        [data release];
        return;
    }
    conn.pendingDeliverData = nil;
    NSUInteger len = [data length];
    conn.undeliveredBytes += len;
    [self queueDeliveryForConnection:conn data:data closeAfter:NO];
    [data release];
}

- (void)flushPendingLocked {
    _hasPendingWork = NO;
    for (AWGTCPConnectionState *conn in _deliverPending) [self deliverPendingLocked:conn];
    [_deliverPending removeAllObjects];
    for (AWGTCPConnectionState *conn in _ackPending) {
        if (conn.state != 2 || conn.unackedPackets == 0) continue;
        conn.unackedPackets = 0;
        conn.unackedBytes = 0;
        [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
    }
    [_ackPending removeAllObjects];
}

- (void)flushPendingWork {
    [_lock lock];
    [self flushPendingLocked];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now >= _nextRetransmitAt) {
        _nextRetransmitAt = now + kRetransmitTick;
        [self retransmitTickLocked:now];
    }
    [_lock unlock];
}

- (void)retransmitTickLocked:(NSTimeInterval)now {
    NSMutableArray *dead = nil;

    for (NSNumber *connID in [_connections allKeys]) {
        AWGTCPConnectionState *conn = [_connections objectForKey:connID];
        if (!conn) continue;

        if (conn.state == 2 && conn.unackedPackets > 0) {
            conn.unackedPackets = 0;
            conn.unackedBytes = 0;
            [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
        }

        if (conn.state == 1) {
            NSTimeInterval rto = kRetransmitInitialRTO * (1 << (conn.synTries - 1));
            if (now - conn.synSentAt >= rto) {
                if (conn.synTries >= kRetransmitMaxTries) {
                    conn.state = 4;
                    if (!dead) dead = [NSMutableArray array];
                    [dead addObject:connID];
                    continue;
                }
                conn.synTries += 1;
                conn.synSentAt = now;
                DLog(@"[AWG IP] connection %u: SYN retry %d to %u.%u.%u.%u:%u from port %u",
                     conn.connectionID, conn.synTries,
                     conn.remoteIP & 0xff, (conn.remoteIP >> 8) & 0xff,
                     (conn.remoteIP >> 16) & 0xff, (conn.remoteIP >> 24) & 0xff,
                     conn.remotePort, conn.localPort);
                [self sendTCPPacketForConnection:conn flags:kTCPSyn payload:nil];
            }
            continue;
        }

        if (conn.state == 2 && !conn.stallReported && conn.establishedAt > 0 &&
            now - conn.establishedAt > 10.0 && conn.bytesHanded == 0) {
            conn.stallReported = YES;
            DLog(@"[AWG IP] connection %u open %.0fs with nothing delivered "
                 @"(in %llu, handed %llu, held %lu, unacked %lu)",
                 conn.connectionID, now - conn.establishedAt,
                 conn.bytesIn, conn.bytesHanded,
                 (unsigned long)conn.outOfOrder.count, (unsigned long)conn.unacked.count);
        }

        if (conn.state != 2 || conn.unacked.count == 0) continue;

        AWGTCPPendingSegment *seg = [conn.unacked objectAtIndex:0];
        NSTimeInterval base = conn.rto > 0 ? conn.rto : kRetransmitInitialRTO;
        NSTimeInterval rto = base * (1 << (seg.tries - 1));
        if (now - seg.sentAt < rto) continue;

        if (seg.tries >= kRetransmitMaxTries) {
            DLog(@"[AWG IP] connection %u: giving up after %d retries of %lu bytes",
                 conn.connectionID, seg.tries, (unsigned long)seg.payload.length);
            conn.state = 4;
            if (!dead) dead = [NSMutableArray array];
            [dead addObject:connID];
            continue;
        }

        seg.tries += 1;
        seg.sentAt = now;
        DLog(@"[AWG IP] connection %u: resending %lu bytes (try %d)",
             conn.connectionID, (unsigned long)seg.payload.length, seg.tries);

        NSUInteger mss = self.tunnelMTU - kIPv4HeaderLen - kTCPHeaderLen;
        conn.ssthresh = MAX(conn.cwnd / 2, 2 * mss);
        conn.cwnd = mss;
        conn.dupAcks = 0;
        [self sendTCPPacketForConnection:conn
                                   flags:kTCPAck | kTCPPsh
                                 payload:seg.payload
                                     seq:seg.seq];
    }

    for (NSNumber *connID in dead) {
        AWGTCPConnectionState *conn = [_connections objectForKey:connID];
        if (conn && conn.localPort >= 49152) {
            _portTable[conn.localPort - 49152] = nil;
            _portOwner[conn.localPort - 49152] = 0;
        }
        [_connections removeObjectForKey:connID];
        [_tunnel deliverData:nil toConnection:[connID unsignedIntValue]];
    }
}


- (void)sendTCPPacketForConnection:(AWGTCPConnectionState *)conn flags:(uint8_t)flags payload:(NSData *)payload {
    [self sendTCPPacketForConnection:conn flags:flags payload:payload seq:conn.localSeq];
}

- (void)sendTCPPacketForConnection:(AWGTCPConnectionState *)conn
                             flags:(uint8_t)flags
                           payload:(NSData *)payload
                               seq:(uint32_t)sequence {
    uint32_t srcIP = 0;
    inet_pton(AF_INET, [_localIPv4 UTF8String], &srcIP);

    BOOL isSyn = (flags & kTCPSyn) != 0;
    uint8_t options[40];
    size_t optionsLen = 0;
    if (isSyn) {
        uint16_t mss = (uint16_t)(self.tunnelMTU - kIPv4HeaderLen - kTCPHeaderLen);

        options[0] = 2; options[1] = 4;
        options[2] = (uint8_t)(mss >> 8);
        options[3] = (uint8_t)(mss & 0xff);

        options[4] = 4; options[5] = 2;

        options[6] = 3; options[7] = 3;
        options[8] = conn.ourWindowScale ?: 7;

        options[9] = 1; options[10] = 1; options[11] = 1;
        optionsLen = 12;
    } else if (conn.sackPermitted && conn.outOfOrder.count > 0 && !payload) {

        NSUInteger n = conn.outOfOrder.count;
        AWGSackRange *rs = malloc(n * sizeof(AWGSackRange));
        NSUInteger k = 0;
        uint32_t base = conn.remoteSeq;
        for (NSNumber *seqKey in conn.outOfOrder) {

            rs[k].start = [seqKey unsignedIntValue] - base;
            rs[k].end = rs[k].start + (uint32_t)[[conn.outOfOrder objectForKey:seqKey] length];
            k++;
        }
        qsort(rs, k, sizeof(AWGSackRange), awgSackRangeCompare);
        uint32_t blkL[64], blkR[64];
        NSUInteger nb = 0;
        for (NSUInteger a = 0; a < k && nb < 64; a++) {
            if (nb > 0 && rs[a].start <= blkR[nb - 1]) {
                if (rs[a].end > blkR[nb - 1]) blkR[nb - 1] = rs[a].end;
            } else {
                blkL[nb] = rs[a].start; blkR[nb] = rs[a].end; nb++;
            }
        }
        free(rs);

        uint32_t fresh = conn.lastOutOfOrderSeq - base;
        NSUInteger order[3], no = 0;
        for (NSUInteger a = 0; a < nb; a++) {
            if (fresh >= blkL[a] && fresh < blkR[a]) { order[no++] = a; break; }
        }
        for (NSUInteger a = 0; a < nb && no < 3; a++) {
            if (no > 0 && order[0] == a) continue;
            order[no++] = a;
        }
        if (no > 0) {
            options[0] = 1; options[1] = 1;
            options[2] = 5; options[3] = (uint8_t)(2 + 8 * no);
            size_t o = 4;
            for (NSUInteger a = 0; a < no; a++) {
                uint32_t l = blkL[order[a]] + base, r = blkR[order[a]] + base;
                options[o++] = (uint8_t)(l >> 24); options[o++] = (uint8_t)(l >> 16);
                options[o++] = (uint8_t)(l >> 8);  options[o++] = (uint8_t)l;
                options[o++] = (uint8_t)(r >> 24); options[o++] = (uint8_t)(r >> 16);
                options[o++] = (uint8_t)(r >> 8);  options[o++] = (uint8_t)r;
            }
            optionsLen = o;
        }
    }

    NSUInteger held = conn.outOfOrderBytes + conn.undeliveredBytes;
    NSUInteger targetWindow = gAWGRecvWindow;
    NSUInteger winBytes = (held >= targetWindow) ? 0 : (targetWindow - held);
    uint16_t tcpWindow = 0;
    if (isSyn) {
        tcpWindow = (uint16_t)MIN(winBytes, 65535);
    } else if (conn.windowScaleActive) {
        uint32_t scaled = (uint32_t)(winBytes >> conn.ourWindowScale);
        if (scaled > 65535) scaled = 65535;
        tcpWindow = (uint16_t)scaled;
    } else {
        tcpWindow = (uint16_t)MIN(winBytes, 65535);
    }

    if (tcpWindow == 0 && !isSyn) conn.windowClosed = YES;

    if (!payload) {

        uint8_t pktBuf[128];
        AWGIPv4Header *ipPtr = (AWGIPv4Header *)pktBuf;
        memset(ipPtr, 0, sizeof(*ipPtr));
        ipPtr->version_ihl = 0x45;
        ipPtr->tos = 0;
        ipPtr->total_length = htons((uint16_t)(kIPv4HeaderLen + kTCPHeaderLen + optionsLen));
        ipPtr->identification = htons(_ipID++);
        ipPtr->flags_fragment = htons(0x4000);
        ipPtr->ttl = 64;
        ipPtr->protocol = AWGIPProtocolTCP;
        ipPtr->source_addr = srcIP;
        ipPtr->dest_addr = conn.remoteIP;
        ipPtr->checksum = ipChecksum(ipPtr, kIPv4HeaderLen);

        uint8_t *segment = pktBuf + kIPv4HeaderLen;
        AWGTCPHeader *tcpPtr = (AWGTCPHeader *)segment;
        memset(tcpPtr, 0, sizeof(*tcpPtr));
        tcpPtr->source_port = htons(conn.localPort);
        tcpPtr->dest_port = htons(conn.remotePort);
        tcpPtr->seq = htonl(sequence);
        tcpPtr->ack = htonl(conn.remoteSeq);
        tcpPtr->data_offset_reserved = (uint8_t)(((kTCPHeaderLen + optionsLen) / 4) << 4);
        tcpPtr->flags = flags;
        tcpPtr->window = htons(tcpWindow);
        tcpPtr->checksum = 0;
        tcpPtr->urgent = 0;
        if (optionsLen) memcpy(segment + kTCPHeaderLen, options, optionsLen);

        tcpPtr->checksum = transportChecksum(ipPtr, AWGIPProtocolTCP, segment, kTCPHeaderLen + optionsLen, NULL, 0);

        [_tunnel sendTunnelPacketBytes:pktBuf length:(kIPv4HeaderLen + kTCPHeaderLen + optionsLen)];
        return;
    }

    NSMutableData *pkt = [NSMutableData data];

    AWGIPv4Header ip;
    memset(&ip, 0, sizeof(ip));
    ip.version_ihl = 0x45;
    ip.tos = 0;
    ip.total_length = htons(kIPv4HeaderLen + kTCPHeaderLen + optionsLen + payload.length);
    ip.identification = htons(_ipID++);
    ip.flags_fragment = htons(0x4000);
    ip.ttl = 64;
    ip.protocol = AWGIPProtocolTCP;
    ip.checksum = 0;
    ip.source_addr = srcIP;
    ip.dest_addr = conn.remoteIP;
    ip.checksum = ipChecksum(&ip, kIPv4HeaderLen);
    [pkt appendBytes:&ip length:kIPv4HeaderLen];

    AWGTCPHeader tcp;
    memset(&tcp, 0, sizeof(tcp));
    tcp.source_port = htons(conn.localPort);
    tcp.dest_port = htons(conn.remotePort);
    tcp.seq = htonl(sequence);
    tcp.ack = htonl(conn.remoteSeq);
    tcp.data_offset_reserved = (uint8_t)(((kTCPHeaderLen + optionsLen) / 4) << 4);
    tcp.flags = flags;
    tcp.window = htons(tcpWindow);
    tcp.checksum = 0;
    tcp.urgent = 0;
    [pkt appendBytes:&tcp length:kTCPHeaderLen];
    if (optionsLen) [pkt appendBytes:options length:optionsLen];
    [pkt appendData:payload];

    AWGIPv4Header *ipPtr = (AWGIPv4Header *)pkt.mutableBytes;
    uint8_t *segment = (uint8_t *)pkt.mutableBytes + kIPv4HeaderLen;
    AWGTCPHeader *tcpPtr = (AWGTCPHeader *)segment;
    tcpPtr->checksum = transportChecksum(ipPtr, AWGIPProtocolTCP, segment, kTCPHeaderLen + optionsLen,
                                         payload.bytes, payload.length);

    [self sendIPPacket:pkt];
}

- (void)sendIPPacket:(NSData *)packet {
    [_tunnel sendTunnelPacket:packet];
}


- (BOOL)claimsIncomingPacket:(const uint8_t *)bytes length:(size_t)len {
    if (len < kIPv4HeaderLen || (bytes[0] >> 4) != 4) return NO;
    size_t ihl = (size_t)(bytes[0] & 0x0f) * 4;
    if (ihl < kIPv4HeaderLen || len < ihl + 8) return NO;
    const AWGIPv4Header *ip = (const AWGIPv4Header *)bytes;
    uint16_t srcPort = (uint16_t)((bytes[ihl] << 8) | bytes[ihl + 1]);
    uint16_t dstPort = (uint16_t)((bytes[ihl + 2] << 8) | bytes[ihl + 3]);
    if (ip->protocol == AWGIPProtocolUDP) {

        if (srcPort != 53 || dstPort != _dnsSrcPort || len < ihl + 8 + 12) return NO;
        uint16_t txid = (uint16_t)((bytes[ihl + 8] << 8) | bytes[ihl + 9]);
        [_dnsLock lock];
        BOOL ours = [_dnsPending objectForKey:[NSNumber numberWithUnsignedInt:txid]] != nil;
        [_dnsLock unlock];
        return ours;
    }
    if (ip->protocol != AWGIPProtocolTCP || dstPort < 49152) return NO;
    return _portOwner[dstPort - 49152] == (((uint64_t)ip->source_addr << 16) | srcPort);
}

- (void)handleIPPacket:(NSData *)packet {
    [self handleIPPacketBytes:(const uint8_t *)packet.bytes length:packet.length];
}

- (void)handleIPPacketBytes:(const uint8_t *)packetBytes length:(size_t)packetLen {
    if (packetLen < kIPv4HeaderLen) return;
    const AWGIPv4Header *ip = (const AWGIPv4Header *)packetBytes;
    uint8_t version = ip->version_ihl >> 4;
    if (version != 4) return;
    uint8_t ihl = ip->version_ihl & 0x0f;
    if (ihl < 5) return;
    size_t ipHeaderLen = ihl * 4;
    if (ip->protocol == AWGIPProtocolUDP) {
        [self handleUDPPacket:packetBytes length:packetLen ipHeaderLen:ipHeaderLen];
        return;
    }
    if (packetLen < ipHeaderLen + kTCPHeaderLen) return;
    if (ip->protocol != AWGIPProtocolTCP) return;

    uint32_t srcIP = ip->source_addr;
    uint32_t dstIP = ip->dest_addr;
    const AWGTCPHeader *tcp = (const AWGTCPHeader *)(packetBytes + ipHeaderLen);
    uint16_t srcPort = ntohs(tcp->source_port);
    uint16_t dstPort = ntohs(tcp->dest_port);
    uint32_t seq = ntohl(tcp->seq);
    uint32_t ackNo = ntohl(tcp->ack);
    uint8_t flags = tcp->flags;
    size_t tcpHeaderLen = (size_t)((tcp->data_offset_reserved >> 4) * 4);
    if (tcpHeaderLen < kTCPHeaderLen) tcpHeaderLen = kTCPHeaderLen;
    if (packetLen < ipHeaderLen + tcpHeaderLen) return;
    size_t payloadLen = packetLen - ipHeaderLen - tcpHeaderLen;
    const uint8_t *payloadBytes = packetBytes + ipHeaderLen + tcpHeaderLen;

    BOOL isSynAck = (flags & kTCPSyn) && (flags & kTCPAck);
    uint8_t synPeerWscale = 0;
    BOOL synHasWscale = NO;
    BOOL synSackPermitted = NO;
    if (isSynAck && tcpHeaderLen > kTCPHeaderLen) {
        const uint8_t *optPtr = (const uint8_t *)tcp + kTCPHeaderLen;
        const uint8_t *optEnd = (const uint8_t *)tcp + tcpHeaderLen;
        while (optPtr < optEnd) {
            uint8_t kind = *optPtr;
            if (kind == 0) break;
            if (kind == 1) { optPtr++; continue; }
            if (optPtr + 1 >= optEnd) break;
            uint8_t len = *(optPtr + 1);
            if (len < 2 || optPtr + len > optEnd) break;

            if (kind == 3 && len == 3) {
                synPeerWscale = *(optPtr + 2);
                synHasWscale = YES;
            } else if (kind == 4 && len == 2) {
                synSackPermitted = YES;
            }
            optPtr += len;
        }
    }

    if (dstPort < 49152) return;
    uint16_t portIdx = dstPort - 49152;

    [_lock lock];
    @try {
        AWGTCPConnectionState *conn = _portTable[portIdx];
        if (!conn || conn.remotePort != srcPort || conn.remoteIP != srcIP) {
            DLogVerbose(@"[AWG IP] DROP on port %u: conn=%u (remPort %u vs %u, remIP %u.%u.%u.%u vs %u.%u.%u.%u)",
                 dstPort, conn ? conn.connectionID : 0,
                 conn ? conn.remotePort : 0, srcPort,
                 conn ? (conn.remoteIP & 0xff) : 0, conn ? ((conn.remoteIP >> 8) & 0xff) : 0,
                 conn ? ((conn.remoteIP >> 16) & 0xff) : 0, conn ? ((conn.remoteIP >> 24) & 0xff) : 0,
                 srcIP & 0xff, (srcIP >> 8) & 0xff, (srcIP >> 16) & 0xff, (srcIP >> 24) & 0xff);
            return;
        }

        if (conn.windowScaleActive && !(flags & kTCPSyn)) {
            conn.peerWindow = (uint32_t)ntohs(tcp->window) << conn.peerWindowScale;
        } else {
            conn.peerWindow = ntohs(tcp->window);
        }

        if ((flags & kTCPAck) && conn.state == 2) {
            NSUInteger acked = 0;
            NSTimeInterval nowT = [NSDate timeIntervalSinceReferenceDate];
            while (conn.unacked.count) {
                AWGTCPPendingSegment *seg = [conn.unacked objectAtIndex:0];
                if (seqLE(seg.seq + (uint32_t)seg.payload.length, ackNo)) {
                    acked += seg.payload.length;

                    if (seg.tries == 1) {
                        NSTimeInterval r = nowT - seg.sentAt;
                        if (r > 0 && r < 10.0) {
                            if (conn.srtt <= 0) {
                                conn.srtt = r;
                                conn.rttvar = r / 2;
                            } else {
                                NSTimeInterval d = conn.srtt - r;
                                if (d < 0) d = -d;
                                conn.rttvar = 0.75 * conn.rttvar + 0.25 * d;
                                conn.srtt = 0.875 * conn.srtt + 0.125 * r;
                            }
                            NSTimeInterval rto = conn.srtt + 4 * conn.rttvar;
                            if (rto < 0.25) rto = 0.25;
                            if (rto > 2.0) rto = 2.0;
                            conn.rto = rto;
                        }
                    }
                    [conn.unacked removeObjectAtIndex:0];
                } else {
                    break;
                }
            }
            NSUInteger mss = self.tunnelMTU - kIPv4HeaderLen - kTCPHeaderLen;
            if (acked > 0) {
                conn.inFlight = (conn.inFlight > acked) ? (conn.inFlight - acked) : 0;
                conn.dupAcks = 0;

                if (conn.cwnd < conn.ssthresh) {
                    conn.cwnd += acked;
                } else {
                    conn.cwnd += MAX((NSUInteger)1, mss * mss / MAX((NSUInteger)1, conn.cwnd));
                }
                if (conn.cwnd > 524288) conn.cwnd = 524288;
                [self pumpSendLocked:conn];
            } else if (payloadLen == 0 && ackNo == conn.lastAckNo && conn.unacked.count > 0) {

                if (++conn.dupAcks == 3) {
                    AWGTCPPendingSegment *seg = [conn.unacked objectAtIndex:0];
                    conn.ssthresh = MAX(conn.inFlight / 2, 2 * mss);
                    conn.cwnd = conn.ssthresh;
                    seg.sentAt = [NSDate timeIntervalSinceReferenceDate];
                    seg.tries += 1;
                    [self sendTCPPacketForConnection:conn flags:kTCPAck | kTCPPsh
                                             payload:seg.payload seq:seg.seq];
                }
            }
            conn.lastAckNo = ackNo;

            if (conn.sackPermitted && conn.unacked.count > 0 && tcpHeaderLen > kTCPHeaderLen) {
                uint32_t highest = ackNo;
                BOOL haveSack = NO;
                const uint8_t *op = (const uint8_t *)tcp + kTCPHeaderLen;
                const uint8_t *oe = (const uint8_t *)tcp + tcpHeaderLen;
                while (op < oe) {
                    uint8_t kind = *op;
                    if (kind == 0) break;
                    if (kind == 1) { op++; continue; }
                    if (op + 1 >= oe) break;
                    uint8_t olen = *(op + 1);
                    if (olen < 2 || op + olen > oe) break;
                    if (kind == 5 && olen >= 10) {
                        haveSack = YES;
                        for (const uint8_t *b = op + 2; b + 8 <= op + olen; b += 8) {
                            uint32_t l = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
                                         ((uint32_t)b[2] << 8) | b[3];
                            uint32_t r = ((uint32_t)b[4] << 24) | ((uint32_t)b[5] << 16) |
                                         ((uint32_t)b[6] << 8) | b[7];
                            if (seqLT(highest, r)) highest = r;
                            for (AWGTCPPendingSegment *sg in conn.unacked) {
                                uint32_t end = sg.seq + (uint32_t)sg.payload.length;
                                if (!seqLT(sg.seq, l) && seqLE(end, r)) sg.sacked = YES;
                            }
                        }
                    }
                    op += olen;
                }
                if (haveSack) {

                    NSUInteger live = 0;
                    for (AWGTCPPendingSegment *sg in conn.unacked) {
                        if (!sg.sacked) live += sg.payload.length;
                    }
                    conn.inFlight = live;

                    NSTimeInterval t = [NSDate timeIntervalSinceReferenceDate];
                    int resent = 0;
                    for (AWGTCPPendingSegment *sg in conn.unacked) {
                        if (resent >= 8) break;
                        if (sg.sacked) continue;
                        uint32_t end = sg.seq + (uint32_t)sg.payload.length;
                        if (!seqLE(end, highest)) break;
                        if (t - sg.sentAt < conn.srtt / 2) continue;
                        sg.sentAt = t;
                        sg.tries += 1;
                        [self sendTCPPacketForConnection:conn flags:kTCPAck | kTCPPsh
                                                 payload:sg.payload seq:sg.seq];
                        resent++;
                    }
                    if (resent > 0) [self pumpSendLocked:conn];
                }
            }
        }
        if (flags & kTCPRst) {
            conn.pendingDeliverData = nil;
            conn.state = 4;
            _portTable[portIdx] = nil;
            _portOwner[portIdx] = 0;
            [self queueDeliveryForConnection:conn data:nil closeAfter:YES];
            [_connections removeObjectForKey:[NSNumber numberWithUnsignedInt:conn.connectionID]];
            return;
        }
        if (isSynAck) {
            if (conn.state == 1) {
                conn.remoteSeq = seq + 1;
                conn.localSeq += 1;
                conn.state = 2;
                conn.establishedAt = [NSDate timeIntervalSinceReferenceDate];

                if (synHasWscale) {
                    conn.peerWindowScale = synPeerWscale;
                    conn.windowScaleActive = YES;
                    DLogVerbose(@"[AWG IP] conn %u: WSCALE active (peer shift %u, our shift %u)",
                         conn.connectionID, conn.peerWindowScale, conn.ourWindowScale);
                }
                if (synSackPermitted) {
                    conn.sackPermitted = YES;
                    DLogVerbose(@"[AWG IP] conn %u: SACK permitted", conn.connectionID);
                }

                DLog(@"[AWG IP] connection %u established", conn.connectionID);
                [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];

                [self pumpSendLocked:conn];
            }
            return;
        }
        if (flags & kTCPFin) {

            if (seq != conn.remoteSeq) {
                [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
                return;
            }
            NSData *tail = payloadLen > 0 ? [NSData dataWithBytes:payloadBytes length:payloadLen] : nil;
            AWGTCPConnectionState *c = conn;
            conn.remoteSeq = seq + (uint32_t)tail.length + 1;
            conn.bytesIn += tail.length;
            conn.state = 4;
            _portTable[portIdx] = nil;
            _portOwner[portIdx] = 0;
            conn.unackedPackets = 0;
            conn.unackedBytes = 0;
            [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
            [self deliverPendingLocked:conn];
            if (tail) conn.undeliveredBytes += [tail length];
            [self queueDeliveryForConnection:c data:tail closeAfter:YES];
            return;
        }
        if (payloadLen > 0) {
            DLogVerbose(@"[AWG IP] conn %u: rx %lu bytes (seq %u vs exp %u, ack %u, flags 0x%02x)",
                 conn.connectionID, (unsigned long)payloadLen, seq, conn.remoteSeq, ackNo, flags);
            if (seq == conn.remoteSeq) {
                conn.remoteSeq += (uint32_t)payloadLen;
                if (!conn.pendingDeliverData) {
                    conn.pendingDeliverData = [NSMutableData dataWithCapacity:65536];
                }
                [conn.pendingDeliverData appendBytes:payloadBytes length:payloadLen];

                while (conn.outOfOrder.count > 0) {
                    NSNumber *nextKey = [NSNumber numberWithUnsignedInt:conn.remoteSeq];
                    NSData *next = [[conn.outOfOrder objectForKey:nextKey] retain];
                    if (!next) break;
                    [conn.outOfOrder removeObjectForKey:nextKey];
                    NSUInteger nextLen = next.length;
                    if (conn.outOfOrderBytes >= nextLen) {
                        conn.outOfOrderBytes -= nextLen;
                    } else {
                        conn.outOfOrderBytes = 0;
                    }
                    conn.remoteSeq += (uint32_t)nextLen;
                    [conn.pendingDeliverData appendData:next];
                    conn.bytesIn += nextLen;
                    [next release];
                }

                conn.bytesIn += payloadLen;
                [self->_deliverPending addObject:conn];
                self->_hasPendingWork = YES;

                uint32_t ackThreshold = (conn.bytesIn < 131072) ? 2 : 16;
                conn.unackedPackets++;
                conn.unackedBytes += (uint32_t)payloadLen;
                if (conn.unackedPackets >= ackThreshold || conn.unackedBytes >= 24576) {
                    conn.unackedPackets = 0;
                    conn.unackedBytes = 0;
                    [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
                    [self->_ackPending removeObject:conn];
                } else {
                    [self->_ackPending addObject:conn];
                    self->_hasPendingWork = YES;
                }
            } else if (seqLT(conn.remoteSeq, seq)) {

                gAWGRxOutOfOrder++;

                if ([conn.outOfOrder count] < 2048 && ![conn.outOfOrder objectForKey:[NSNumber numberWithUnsignedInt:seq]]) {
                    NSData *payloadData = [NSData dataWithBytes:payloadBytes length:payloadLen];
                    [conn.outOfOrder setObject:payloadData forKey:[NSNumber numberWithUnsignedInt:seq]];
                    conn.outOfOrderBytes += payloadLen;
                }
                conn.lastOutOfOrderSeq = seq;
                conn.unackedPackets = 0;
                conn.unackedBytes = 0;
                [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
            } else {
                gAWGRxDuplicate++;
                conn.unackedPackets = 0;
                conn.unackedBytes = 0;
                [self sendTCPPacketForConnection:conn flags:kTCPAck payload:nil];
            }
        }
    }
    @finally {
        [_lock unlock];
    }
}

@end
