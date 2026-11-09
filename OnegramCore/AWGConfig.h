#import <Foundation/Foundation.h>

@interface AWGConfig : NSObject <NSCoding>

@property (nonatomic, copy) NSString *privateKey;
@property (nonatomic, copy) NSString *publicKey;
@property (nonatomic, copy) NSString *presharedKey;

@property (nonatomic, copy) NSString *ipv4Address;
@property (nonatomic, copy) NSString *ipv6Address;
@property (nonatomic, copy) NSString *dnsServers;
@property (nonatomic, assign) NSUInteger mtu;

@property (nonatomic, copy) NSString *peerPublicKey;
@property (nonatomic, copy) NSString *peerEndpoint;
@property (nonatomic, copy) NSString *allowedIPs;

@property (nonatomic, assign) NSUInteger junkCount;
@property (nonatomic, assign) NSUInteger junkMin;
@property (nonatomic, assign) NSUInteger junkMax;
@property (nonatomic, assign) NSUInteger s1;
@property (nonatomic, assign) NSUInteger s2;
@property (nonatomic, assign) NSUInteger s3;
@property (nonatomic, assign) NSUInteger s4;
@property (nonatomic, assign) NSUInteger h1;
@property (nonatomic, assign) NSUInteger h2;
@property (nonatomic, assign) NSUInteger h3;
@property (nonatomic, assign) NSUInteger h4;
@property (nonatomic, copy) NSString *i1;
@property (nonatomic, copy) NSString *i2;
@property (nonatomic, copy) NSString *i3;
@property (nonatomic, copy) NSString *i4;
@property (nonatomic, copy) NSString *i5;

@property (nonatomic, copy) NSString *warpClientID;

@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *preferredSNI;
@property (nonatomic, copy) NSArray *preferredPorts;

- (BOOL)hasReservedBytes;
- (void)copyReservedBytes:(uint8_t *)out;

- (NSString *)wireguardConfigString;
- (NSString *)obfuscatedConfigString;

+ (instancetype)configWithDefaults;
+ (instancetype)configFromWireguardString:(NSString *)string;

@end
