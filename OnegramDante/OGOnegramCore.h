#import "OGDanteSupport.h"

typedef NS_ENUM(NSInteger, OGOnegramCoreMode) {
    OGOnegramCoreModeNone,
    OGOnegramCoreModeWebSocket,
    OGOnegramCoreModeDanteWARP,
    OGOnegramCoreModeDantePower
};

typedef NS_ENUM(NSInteger, OGOnegramCoreState) {
    OGOnegramCoreStateDisabled,
    OGOnegramCoreStateConnecting,
    OGOnegramCoreStateConnected,
    OGOnegramCoreStateFailed
};

extern NSString * const OGOnegramCoreDidChangeNotification;

@interface OGOnegramCore : NSObject
+ (OGOnegramCore *)sharedCore;
@property (nonatomic, readonly) OGOnegramCoreMode mode;
@property (nonatomic, readonly) OGOnegramCoreMode preferredMode;
@property (nonatomic, readonly) OGOnegramCoreState state;
@property (nonatomic, readonly) uint16_t socksPort;
@property (nonatomic, readonly) NSError *lastError;
- (void)setMode:(OGOnegramCoreMode)mode;
- (void)reconnect;
- (void)webSocketConnectionOpened:(id)connection;
- (void)webSocketConnectionClosed:(id)connection;
- (void)webSocketUnavailableWithError:(NSError *)error;
@end
