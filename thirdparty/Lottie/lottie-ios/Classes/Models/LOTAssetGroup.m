#import "../OGLottieCompat.h"
//
//  LOTAssetGroup.m
//  Pods
//
//  Created by Brandon Withrow on 2/17/17.
//
//

#import "LOTAssetGroup.h"
#import "LOTAsset.h"

@implementation LOTAssetGroup {
  OG_COMPAT_GENERIC(NSMutableDictionary, NSString *, LOTAsset *) *_assetMap;
  OG_COMPAT_GENERIC(NSDictionary, NSString *, NSDictionary *) *_assetJSONMap;
}

- (instancetype _Nonnull)initWithJSON:(NSArray * _Nonnull)jsonArray
                      withAssetBundle:(NSBundle * _Nullable)bundle
                        withFramerate:(NSNumber * _Nonnull)framerate {
  self = [super init];
  if (self) {
    _assetBundle = bundle;
    _assetMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *assetJSONMap = [NSMutableDictionary dictionary];
    for (OG_COMPAT_GENERIC(NSDictionary, NSString *, NSString *) *assetDictionary in jsonArray) {
      NSString *referenceID = assetDictionary[@"id"];
      if (referenceID) {
        assetJSONMap[referenceID] = assetDictionary;
      }
    }
    _assetJSONMap = assetJSONMap;
  }
  return self;
}

- (void)buildAssetNamed:(NSString *)refID
          withFramerate:(NSNumber * _Nonnull)framerate {
  
  if ([self assetModelForID:refID]) {
    return;
  }
  
  NSDictionary *assetDictionary = _assetJSONMap[refID];
  if (assetDictionary) {
    LOTAsset *asset = [[LOTAsset alloc] initWithJSON:assetDictionary
                                      withAssetGroup:self
                                     withAssetBundle:_assetBundle
                                       withFramerate:framerate];
    _assetMap[refID] = asset;
  }
}

- (void)finalizeInitializationWithFramerate:(NSNumber * _Nonnull)framerate {
  for (NSString *refID in _assetJSONMap.allKeys) {
    [self buildAssetNamed:refID withFramerate:framerate];
  }
  _assetJSONMap = nil;
}

- (LOTAsset *)assetModelForID:(NSString *)assetID {
  return _assetMap[assetID];
}

- (void)setRootDirectory:(NSString *)rootDirectory {
    _rootDirectory = rootDirectory;
#if ONEGRAM_ARMV6
    for (NSString *key in _assetMap) {
        LOTAsset *obj = [_assetMap objectForKey:key];
        obj.rootDirectory = rootDirectory;
    }
#else
    [_assetMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, LOTAsset * _Nonnull obj, BOOL * _Nonnull stop) {
        obj.rootDirectory = rootDirectory;
    }];
#endif
}
@end
