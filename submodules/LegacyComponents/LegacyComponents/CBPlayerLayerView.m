//
//  CBPlayerLayerView.m
//  Coub
//
//  Created by Tikhonenko Pavel on 23/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBPlayerLayerView.h"
#import <QuartzCore/QuartzCore.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#endif

@implementation CBPlayerLayerView

+ (Class)layerClass
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    return [CALayer class];
#else
	return [AVPlayerLayer class];
#endif
}

@end
