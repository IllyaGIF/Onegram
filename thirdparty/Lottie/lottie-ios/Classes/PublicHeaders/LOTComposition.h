#import "../OGLottieCompat.h"
//
//  LOTScene.h
//  LottieAnimator
//
//  Created by Brandon Withrow on 12/14/15.
//  Copyright © 2015 Brandon Withrow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class LOTLayerGroup;
@class LOTLayer;
@class LOTAssetGroup;

@interface LOTComposition : NSObject

/// Load animation by name from the default bundle, Images are also loaded from the bundle
+ (instancetype _Nullable)animationNamed:(NSString *_Nonnull)animationName NS_SWIFT_NAME(init(name:));

/// Loads animation by name from specified bundle, Images are also loaded from the bundle
+ (instancetype _Nullable)animationNamed:(NSString *_Nonnull)animationName
                              inBundle:(NSBundle *_Nonnull)bundle NS_SWIFT_NAME(init(name:bundle:));

/// Loads an animation from a specific file path. WARNING Do not use a web URL for file path.
+ (instancetype _Nullable)animationWithFilePath:(NSString *_Nonnull)filePath NS_SWIFT_NAME(init(filePath:));

/// Creates an animation from the deserialized JSON Dictionary
+ (instancetype _Nonnull)animationFromJSON:(NSDictionary *_Nonnull)animationJSON NS_SWIFT_NAME(init(json:));

/// Creates an animation from the deserialized JSON Dictionary, images are loaded from the specified bundle
+ (instancetype _Nonnull)animationFromJSON:(NSDictionary *_Nullable)animationJSON
                                 inBundle:(NSBundle *_Nullable)bundle NS_SWIFT_NAME(init(json:bundle:));

- (instancetype _Nonnull)initWithJSON:(NSDictionary * _Nullable)jsonDictionary
                      withAssetBundle:(NSBundle * _Nullable)bundle;

@property (nonatomic, readonly) CGRect compBounds;
@property (nonatomic, readonly) NSNumber *_Nullable startFrame;
@property (nonatomic, readonly) NSNumber *_Nullable endFrame;
@property (nonatomic, readonly) NSNumber *_Nullable framerate;
@property (nonatomic, readonly) NSTimeInterval timeDuration;
@property (nonatomic, readonly) LOTLayerGroup *_Nullable layerGroup;
@property (nonatomic, readonly) LOTAssetGroup *_Nullable assetGroup;
@property (nonatomic, readwrite) NSString *_Nullable rootDirectory;
@property (nonatomic, readonly) NSBundle *_Nullable assetBundle;
@property (nonatomic, copy) NSString *_Nullable cacheKey;

@end
