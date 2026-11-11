#import "../OGLottieCompat.h"
//
//  LOTLayerGroup.h
//  Pods
//
//  Created by Brandon Withrow on 2/16/17.
//
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>



@class LOTLayer;
@class LOTAssetGroup;

@interface LOTLayerGroup : NSObject

- (instancetype)initWithLayerJSON:(NSArray *)layersJSON
                   withAssetGroup:(LOTAssetGroup * _Nullable)assetGroup
                    withFramerate:(NSNumber *)framerate;

@property (nonatomic, readonly) OG_COMPAT_GENERIC(NSArray, LOTLayer *) *layers;

- (LOTLayer *)layerModelForID:(NSNumber *)layerID;
- (LOTLayer *)layerForReferenceID:(NSString *)referenceID;

@end


