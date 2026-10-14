//
//  CBPlayerView.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 17/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#endif

#import "CBCoubPlayer.h"
#import "CBPlayerLayerView.h"

@interface CBPlayerView : UIView <CBCoubPlayerDelegate>

@property (nonatomic, readonly) UIImageView *preview;
@property (nonatomic, readonly) CBPlayerLayerView *videoPlayerView;

- (void)play;
- (void)stop;

@end

//@interface CBPlayerLayerView : UIView
//@end