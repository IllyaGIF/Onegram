#import "EMImage.h"

@interface EMImage ()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    NSMutableData *_data;
#else
    NSPurgeableData *_data;
#endif
}

@end

@implementation EMImage

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (instancetype)initWithCGImage:(CGImageRef)image data:(NSMutableData *)data
#else
- (instancetype)initWithCGImage:(CGImageRef)image data:(NSPurgeableData *)data
#endif
{
    self = [super initWithCGImage:image];
    if (self != nil)
    {
        _data = data;
    }
    return self;
}

- (void)dealloc
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    [_data endContentAccess];
#endif
}

@end
