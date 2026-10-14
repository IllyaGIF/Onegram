#import <Foundation/Foundation.h>

@class AWGTunnel;

typedef NS_ENUM(uint8_t, AWGIPProtocol) {
    AWGIPProtocolTCP = 6,
    AWGIPProtocolUDP = 17
};

@interface AWGIPStack : NSObject

@property (nonatomic, readonly) NSString *localIPv4;
@property (nonatomic, readonly) NSString *localIPv6;

- (instancetype)initWithTunnel:(AWGTunnel *)tunnel localIPv4:(NSString *)ipv4 localIPv6:(NSString *)ipv6;

@property (nonatomic, copy) NSString *dnsServerIPv4;

@property (nonatomic, assign) NSUInteger tunnelMTU;

- (uint32_t)resolveIPv4:(NSString *)host;

- (NSData *)relayDNSQuery:(NSData *)query timeout:(NSTimeInterval)timeout;

- (uint32_t)openTCPToHost:(NSString *)host port:(uint16_t)port;

- (BOOL)waitForConnection:(uint32_t)connectionID timeout:(NSTimeInterval)timeout;

- (void)sendTCPData:(NSData *)data connectionID:(uint32_t)connectionID;

- (void)closeTCPConnection:(uint32_t)connectionID;

- (void)flushPendingWork;
@property (atomic, assign) BOOL hasPendingWork;

- (BOOL)claimsIncomingPacket:(const uint8_t *)bytes length:(size_t)len;

- (void)handleIPPacket:(NSData *)packet;
- (void)handleIPPacketBytes:(const uint8_t *)bytes length:(size_t)len;

- (void)setClientFd:(int)fd forConnectionID:(uint32_t)connID;

- (void)closeTCPConnectionAndDrain:(uint32_t)connID;

- (NSUInteger)sendBacklogForConnection:(uint32_t)connID;

- (void)sendIPPacket:(NSData *)packet;

@end
