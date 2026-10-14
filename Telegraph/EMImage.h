#import <UIKit/UIKit.h>

@interface EMImage : UIImage

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (instancetype)initWithCGImage:(CGImageRef)image data:(NSMutableData *)data;
#else
- (instancetype)initWithCGImage:(CGImageRef)image data:(NSPurgeableData *)data;
#endif

@end
