#import "../OGLottieCompat.h"
//
//  LOTLayerContainer.h
//  Lottie
//
//  Created by brandon_withrow on 7/18/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import "LOTPlatformCompat.h"
#import "LOTLayer.h"
#import "LOTLayerGroup.h"
#import "LOTKeypath.h"
#import "LOTValueDelegate.h"

@class LOTValueCallback;

@interface LOTLayerContainer : CALayer

- (instancetype _Nonnull)initWithModel:(LOTLayer * _Nullable)layer
                 inLayerGroup:(LOTLayerGroup * _Nullable)layerGroup;

@property (nonatomic, readonly, strong) NSString *_Nullable layerName;
@property (nonatomic) NSNumber *_Nullable currentFrame;
@property (nonatomic, readonly) NSNumber *_Nonnull timeStretchFactor;
@property (nonatomic, assign) CGRect viewportBounds;
@property (nonatomic, readonly) CALayer *_Nonnull wrapperLayer;
@property (nonatomic, readonly) NSDictionary *_Nonnull valueInterpolators;

- (void)displayWithFrame:(NSNumber * _Nonnull)frame;
- (void)displayWithFrame:(NSNumber * _Nonnull)frame forceUpdate:(BOOL)forceUpdate;

- (void)searchNodesForKeypath:(LOTKeypath * _Nonnull)keypath;

- (void)setValueDelegate:(id<LOTValueDelegate> _Nonnull)delegate
              forKeypath:(LOTKeypath * _Nonnull)keypath;

@end
