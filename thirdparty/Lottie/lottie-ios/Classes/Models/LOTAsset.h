#import "../OGLottieCompat.h"
//
//  LOTAsset.h
//  Pods
//
//  Created by Brandon Withrow on 2/16/17.
//
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>



@class LOTLayerGroup;
@class LOTLayer;
@class LOTAssetGroup;

@interface LOTAsset : NSObject

- (instancetype)initWithJSON:(NSDictionary *)jsonDictionary
              withAssetGroup:(LOTAssetGroup * _Nullable)assetGroup
             withAssetBundle:(NSBundle *_Nonnull)bundle
               withFramerate:(NSNumber *)framerate;

@property (nonatomic, readonly) NSString *_Nullable referenceID;
@property (nonatomic, readonly) NSNumber *_Nullable assetWidth;
@property (nonatomic, readonly) NSNumber *_Nullable assetHeight;

@property (nonatomic, readonly) NSString *_Nullable imageName;
@property (nonatomic, readonly) NSString *_Nullable imageDirectory;

@property (nonatomic, readonly) LOTLayerGroup *_Nullable layerGroup;

@property (nonatomic, readwrite) NSString *rootDirectory;
@property (nonatomic, readonly) NSBundle *assetBundle;
@end


