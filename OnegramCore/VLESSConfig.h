#import "OGCoreSupport.h"

typedef NS_ENUM(NSInteger, VLSecurity) {
    VLSecurityNone = 0,   
    VLSecurityTLS,        
    VLSecurityReality,
    VLSecurityUnknown
};

typedef NS_ENUM(NSInteger, VLTransport) {
    VLTransportTCP = 0,
    VLTransportWS,        
    VLTransportXHTTP,
    VLTransportGRPC,
    VLTransportUnknown
};

@interface VLESSConfig : NSObject

@property (nonatomic, copy)   NSString *name;      
@property (nonatomic, copy)   NSString *host;
@property (nonatomic, assign) uint16_t  port;
@property (nonatomic, copy)   NSString *uuid;
@property (nonatomic, assign) VLSecurity security;
@property (nonatomic, assign) VLTransport transport;
@property (nonatomic, copy)   NSString *sni;        
@property (nonatomic, copy)   NSString *encryption;
@property (nonatomic, copy)   NSString *headerType;
@property (nonatomic, copy)   NSString *flow;       
@property (nonatomic, copy)   NSString *path;       
@property (nonatomic, copy)   NSString *hostHeader; 
@property (nonatomic, copy)   NSString *publicKey;  
@property (nonatomic, copy)   NSString *shortID;    
@property (nonatomic, copy)   NSString *fingerprint;
@property (nonatomic, copy)   NSArray  *alpn;
@property (nonatomic, assign) BOOL allowInsecure;

+ (instancetype)configFromURI:(NSString *)uri;

+ (NSArray *)linesFromText:(NSString *)text;

- (BOOL)isSupported;
- (NSString *)unsupportedReason;

- (NSString *)summary;

@end
