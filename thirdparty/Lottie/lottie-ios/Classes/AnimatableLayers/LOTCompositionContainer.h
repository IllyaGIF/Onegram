#import "../OGLottieCompat.h"
//
//  LOTCompositionContainer.h
//  Lottie
//
//  Created by brandon_withrow on 7/18/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import "LOTLayerContainer.h"
#import "LOTAssetGroup.h"

@interface LOTCompositionContainer : LOTLayerContainer

- (instancetype _Nonnull)initWithModel:(LOTLayer * _Nullable)layer
                          inLayerGroup:(LOTLayerGroup * _Nullable)layerGroup
                        withLayerGroup:(LOTLayerGroup * _Nullable)childLayerGroup
                       withAssestGroup:(LOTAssetGroup * _Nullable)assetGroup;

- (NSArray *_Nullable)keysForKeyPath:(LOTKeypath *_Nonnull)keypath;

- (CGPoint)convertPoint:(CGPoint)point
         toKeypathLayer:(LOTKeypath *_Nonnull)keypath
        withParentLayer:(CALayer *_Nonnull)parent;

- (CGRect)convertRect:(CGRect)rect
       toKeypathLayer:(LOTKeypath *_Nonnull)keypath
      withParentLayer:(CALayer *_Nonnull)parent;

- (CGPoint)convertPoint:(CGPoint)point
       fromKeypathLayer:(LOTKeypath *_Nonnull)keypath
        withParentLayer:(CALayer *_Nonnull)parent;

- (CGRect)convertRect:(CGRect)rect
     fromKeypathLayer:(LOTKeypath *_Nonnull)keypath
      withParentLayer:(CALayer *_Nonnull)parent;

- (void)addSublayer:(CALayer *_Nonnull)subLayer
    toKeypathLayer:(LOTKeypath *_Nonnull)keypath;

- (void)maskSublayer:(CALayer *_Nonnull)subLayer
     toKeypathLayer:(LOTKeypath *_Nonnull)keypath;

@property (nonatomic, readonly) OG_COMPAT_GENERIC(NSArray, LOTLayerContainer *) *_Nonnull childLayers;
@property (nonatomic, readonly)  NSDictionary *_Nonnull childMap;

@end
