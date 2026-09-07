#import <Foundation/Foundation.h>

typedef enum
{
    TGRouteStateDisabled,
    TGRouteStateSearching,
    TGRouteStateConnecting,
    TGRouteStateConnected,
    TGRouteStateFailed
} TGRouteState;

FOUNDATION_EXPORT NSString *const TGRouteStateChangedNotification;

@interface TGRouteCoordinator : NSObject

@property (nonatomic, copy) void (^stateChanged)(TGRouteState state, NSString *message);

+ (BOOL)isSupported;
+ (NSString *)unsupportedReason;

+ (BOOL)canBeOffered;

+ (void)checkAndAutoStart;
+ (void)stopForBackground;

+ (void)forgetRememberedRoute;
- (void)refreshState;
- (void)enable;
- (void)disable;

@end
