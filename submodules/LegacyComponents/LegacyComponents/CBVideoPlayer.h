//
//  CBVideoPlayer.h
//  Coub
//
//  Created by Pavel Tikhonenko on 12/08/14.
//  Copyright (c) 2014 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@class CALayer;
#else
#import <AVFoundation/AVFoundation.h>
#endif

typedef enum
{
	CBVideoPlayerStatusInited,
	CBVideoPlayerStatusPrepairing = 1,
	CBVideoPlayerStatusReadyToPlay = 1 << 1,
	CBVideoPlayerStatusFailed = 1 << 2,
	CBVideoPlayerStatusUnknown = NSNotFound

}
CBVideoPlayerStatus;

@interface CBVideoPlayer : NSObject

@property (nonatomic, assign) CBVideoPlayerStatus status;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (id)initWithVideoLayer:(CALayer *)layer;
- (void)prepareWithURL:(NSURL *)url completion:(void (^)(NSError *error))completion;
#else
- (id)initWithVideoLayer:(AVPlayerLayer *)layer;
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
- (void)prepareWithAVAsset:(AVAsset *)asset completion:(void (^)(NSError *error))completion;
#endif
- (void)stopPrepairing;

- (void)play;
- (void)pause;
- (void)stop;

@end
