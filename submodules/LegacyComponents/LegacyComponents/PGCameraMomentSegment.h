#import <Foundation/Foundation.h>
#if __has_include(<CoreMedia/CoreMedia.h>)
#import <CoreMedia/CoreMedia.h>
#endif
#import <AVFoundation/AVFoundation.h>

@interface PGCameraMomentSegment : NSObject

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) AVAsset *asset;
@property (nonatomic, readonly) NSTimeInterval duration;

- (instancetype)initWithURL:(NSURL *)url duration:(NSTimeInterval)duration;

@end
