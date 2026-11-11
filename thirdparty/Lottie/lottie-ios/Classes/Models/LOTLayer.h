#import "../OGLottieCompat.h"
//
//  LOTLayer.h
//  LottieAnimator
//
//  Created by Brandon Withrow on 12/14/15.
//  Copyright © 2015 Brandon Withrow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOTPlatformCompat.h"
#import "LOTKeyframe.h"

@class LOTShapeGroup;
@class LOTMask;
@class LOTAsset;
@class LOTAssetGroup;

typedef enum : NSInteger {
  LOTLayerTypePrecomp,
  LOTLayerTypeSolid,
  LOTLayerTypeImage,
  LOTLayerTypeNull,
  LOTLayerTypeShape,
  LOTLayerTypeUnknown
} LOTLayerType;

typedef enum : NSInteger {
  LOTMatteTypeNone,
  LOTMatteTypeAdd,
  LOTMatteTypeInvert,
  LOTMatteTypeUnknown
} LOTMatteType;



@interface LOTLayer : NSObject

- (instancetype)initWithJSON:(NSDictionary *)jsonDictionary
              withAssetGroup:(LOTAssetGroup * _Nullable)assetGroup
               withFramerate:(NSNumber *)framerate;

@property (nonatomic, readonly) NSString *layerName;
@property (nonatomic, readonly) NSString *_Nullable referenceID;
@property (nonatomic, readonly) NSNumber *layerID;
@property (nonatomic, readonly) LOTLayerType layerType;
@property (nonatomic, readonly) NSNumber *_Nullable parentID;
@property (nonatomic, readonly) NSNumber *startFrame;
@property (nonatomic, readonly) NSNumber *inFrame;
@property (nonatomic, readonly) NSNumber *outFrame;
@property (nonatomic, readonly) NSNumber *timeStretch;
@property (nonatomic, readonly) CGRect layerBounds;

@property (nonatomic, readonly) OG_COMPAT_GENERIC(NSArray, LOTShapeGroup *) *_Nullable shapes;
@property (nonatomic, readonly) OG_COMPAT_GENERIC(NSArray, LOTMask *) *_Nullable masks;

@property (nonatomic, readonly) NSNumber *_Nullable layerWidth;
@property (nonatomic, readonly) NSNumber *_Nullable layerHeight;
@property (nonatomic, readonly) UIColor *_Nullable solidColor;
@property (nonatomic, readonly) LOTAsset *_Nullable imageAsset;

@property (nonatomic, readonly) LOTKeyframeGroup *opacity;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable timeRemapping;
@property (nonatomic, readonly) LOTKeyframeGroup *rotation;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable position;

@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable positionX;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable positionY;

@property (nonatomic, readonly) LOTKeyframeGroup *anchor;
@property (nonatomic, readonly) LOTKeyframeGroup *scale;

@property (nonatomic, readonly) LOTMatteType matteType;

@end


