#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class UIEvent;

@interface TGRemoteControlsManager : NSObject

+ (TGRemoteControlsManager *)instance;

- (id<SDisposable>)requestControlsWithPrevious:(void (^)())previous next:(void (^)())next play:(void (^)())play pause:(void (^)())pause position:(void (^)(NSTimeInterval position))position;

- (void)handleLegacyRemoteControlEvent:(UIEvent *)event;

@end
