#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import <AVFoundation/AVFoundation.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponentsGlobals.h"

typedef enum {
    TGAudioSessionRouteChangePause,
    TGAudioSessionRouteChangeResume
} TGAudioSessionRouteChange;

@class TGAudioRoute;

@interface TGAudioSessionManager : NSObject

+ (TGAudioSessionManager *)instance;
+ (Float64)callPreferredSampleRate;
+ (NSTimeInterval)callPreferredIOBufferDuration;

- (id<SDisposable>)requestSessionWithType:(TGAudioSessionType)type interrupted:(void (^)())interrupted;
- (void)cancelCurrentSession;
- (id<SDisposable>)suppressNotificationSounds;
- (bool)notificationSoundsSuppressed;
+ (SSignal *)routeChange;

- (void)applyRoute:(TGAudioRoute *)route;

@end


@interface TGAudioRoute : NSObject

@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) bool isBuiltIn;
@property (nonatomic, readonly) bool isLoudspeaker;
@property (nonatomic, readonly) bool isBluetooth;
@property (nonatomic, readonly) bool isHeadphones;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
@property (nonatomic, readonly) AVAudioSessionPortDescription *device;

+ (instancetype)routeWithDescription:(AVAudioSessionPortDescription *)description;
#else
@property (nonatomic, readonly) id device;

+ (instancetype)routeWithDescription:(id)description;
#endif
+ (instancetype)routeForBuiltIn:(bool)headphones;
+ (instancetype)routeForSpeaker;

@end
