#import "OGDanteSupport.h"

typedef NS_ENUM(NSInteger, PWSecurity) {
    PWSecurityNone = 0,   
    PWSecurityTLS,        
    PWSecurityReality,
    PWSecurityUnknown
};

typedef NS_ENUM(NSInteger, PWTransport) {
    PWTransportTCP = 0,
    PWTransportWS,        
    PWTransportXHTTP,
    PWTransportGRPC,
    PWTransportUnknown
};

@interface PowerConfig : NSObject

@property (nonatomic, copy)   NSString *name;      
@property (nonatomic, copy)   NSString *host;
@property (nonatomic, assign) uint16_t  port;
@property (nonatomic, copy)   NSString *uuid;
@property (nonatomic, assign) PWSecurity security;
@property (nonatomic, assign) PWTransport transport;
@property (nonatomic, copy)   NSString *sni;        
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
