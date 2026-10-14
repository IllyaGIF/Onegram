#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NSInteger ALAssetOrientation;
typedef NSUInteger ALAssetsGroupType;
typedef NSInteger ALAuthorizationStatus;

enum {
    ALAssetOrientationUp = 0,
    ALAssetOrientationDown = 1,
    ALAssetOrientationLeft = 2,
    ALAssetOrientationRight = 3,
    ALAssetOrientationUpMirrored = 4,
    ALAssetOrientationDownMirrored = 5,
    ALAssetOrientationLeftMirrored = 6,
    ALAssetOrientationRightMirrored = 7
};

enum {
    ALAssetsGroupLibrary = (1UL << 0),
    ALAssetsGroupAlbum = (1UL << 1),
    ALAssetsGroupEvent = (1UL << 2),
    ALAssetsGroupFaces = (1UL << 3),
    ALAssetsGroupSavedPhotos = (1UL << 4),
    ALAssetsGroupPhotoStream = (1UL << 5),
    ALAssetsGroupAll = 0xFFFFFFFFUL
};

enum {
    ALAuthorizationStatusNotDetermined = 0,
    ALAuthorizationStatusRestricted = 1,
    ALAuthorizationStatusDenied = 2,
    ALAuthorizationStatusAuthorized = 3
};

@class ALAsset;
@class ALAssetRepresentation;
@class ALAssetsGroup;
@class ALAssetsFilter;

FOUNDATION_EXPORT NSString *const ALAssetPropertyType;
FOUNDATION_EXPORT NSString *const ALAssetPropertyDate;
FOUNDATION_EXPORT NSString *const ALAssetPropertyDuration;
FOUNDATION_EXPORT NSString *const ALAssetTypePhoto;
FOUNDATION_EXPORT NSString *const ALAssetTypeVideo;
FOUNDATION_EXPORT NSString *const ALAssetsGroupPropertyName;
FOUNDATION_EXPORT NSString *const ALAssetsGroupPropertyType;
FOUNDATION_EXPORT NSString *const ALAssetsGroupPropertyPersistentID;
FOUNDATION_EXPORT NSString *const ALAssetsLibraryChangedNotification;

@interface ALAssetRepresentation : NSObject
@property (nonatomic, readonly) CGImageRef fullResolutionImage;
@property (nonatomic, readonly) CGImageRef fullScreenImage;
@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) NSString *UTI;
@property (nonatomic, readonly) NSDictionary *metadata;
@property (nonatomic, readonly) ALAssetOrientation orientation;
- (long long)size;
- (NSUInteger)getBytes:(uint8_t *)buffer fromOffset:(long long)offset length:(NSUInteger)length error:(NSError **)error;
@end

@interface ALAsset : NSObject
@property (nonatomic, readonly) ALAssetRepresentation *defaultRepresentation;
@property (nonatomic, readonly) CGImageRef thumbnail;
@property (nonatomic, readonly) CGImageRef aspectRatioThumbnail;
- (id)valueForProperty:(NSString *)property;
@end

@interface ALAssetsFilter : NSObject
+ (ALAssetsFilter *)allPhotos;
+ (ALAssetsFilter *)allVideos;
+ (ALAssetsFilter *)allAssets;
@end

@interface ALAssetsGroup : NSObject
@property (nonatomic, readonly) NSInteger numberOfAssets;
- (id)valueForProperty:(NSString *)property;
- (void)setAssetsFilter:(ALAssetsFilter *)filter;
- (void)enumerateAssetsUsingBlock:(void (^)(ALAsset *result, NSUInteger index, BOOL *stop))enumerationBlock;
- (void)enumerateAssetsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(ALAsset *result, NSUInteger index, BOOL *stop))enumerationBlock;
@end

@interface ALAssetsLibrary : NSObject
+ (ALAuthorizationStatus)authorizationStatus;
- (void)assetForURL:(NSURL *)assetURL resultBlock:(void (^)(ALAsset *asset))resultBlock failureBlock:(void (^)(NSError *error))failureBlock;
- (void)enumerateGroupsWithTypes:(ALAssetsGroupType)types usingBlock:(void (^)(ALAssetsGroup *group, BOOL *stop))enumerationBlock failureBlock:(void (^)(NSError *error))failureBlock;
- (void)writeImageToSavedPhotosAlbum:(CGImageRef)imageRef orientation:(ALAssetOrientation)orientation completionBlock:(void (^)(NSURL *assetURL, NSError *error))completionBlock;
- (void)writeVideoAtPathToSavedPhotosAlbum:(NSURL *)videoPathURL completionBlock:(void (^)(NSURL *assetURL, NSError *error))completionBlock;
@end
