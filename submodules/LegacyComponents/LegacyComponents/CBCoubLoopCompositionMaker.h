//
// Created by Tikhonenko Pavel on 26/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "CBCoubAsset.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#endif

@class CBCoubLoopCompositionMaker;
@protocol CBCoubAsset;

@protocol CBCoubLoopDelegate<NSObject>

@required
- (void)coubLoopDidFinishPreparing:(CBCoubLoopCompositionMaker *)loop;
- (void)coubLoop:(CBCoubLoopCompositionMaker *)loop didFailToLoadWithError:(NSError *)error;

@end

@interface CBCoubLoopCompositionMaker : NSObject

@property (nonatomic, weak) id<CBCoubLoopDelegate> delegate;
@property (nonatomic, strong) id<CBCoubAsset> asset;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@property (nonatomic, strong) NSURL *videoURL;
#else
@property (nonatomic, strong) AVAsset *videoAsset;
#endif
@property (nonatomic, strong) NSError *error;
@property (nonatomic, readonly) BOOL hasAudio;

@property (nonatomic, assign, getter=isLoopReady) BOOL loopReady;

- (void)prepareLoop;
- (void)cancelPrepareLoop;

- (void)notifyObservers;

+ (instancetype)coubLoopWithAsset:(id<CBCoubAsset>)asset;

@end