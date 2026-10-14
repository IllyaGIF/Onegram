#import "OGAssets.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"
#import "../../OnegramPlatform/OGMemoryCache.h"

static NSInteger OGAssetsPreferredScale(void)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale > 2.5f)
        return 3;
    if (scale > 1.5f)
        return 2;
    return 1;
}

@implementation OGAssets

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _imageCache = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:8 * 1024 * 1024];
    return self;
}

- (UIImage *)imageNamed:(NSString *)name
{
    return [self imageNamed:name inDirectory:nil];
}

- (UIImage *)imageNamed:(NSString *)name inDirectory:(NSString *)directory
{
    if ([name length] == 0)
        return nil;

    NSString *fullName = [_resourcePrefix length] == 0 ? name : [_resourcePrefix stringByAppendingString:name];
    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@|%d", directory ?: @"", fullName, (int)OGAssetsPreferredScale()];
    UIImage *cachedImage = [_imageCache objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;

    UIImage *image = [self uncachedImageNamed:name inDirectory:directory];
    if (image == nil)
    {
        NSString *qualifiedName = [directory length] == 0 ? fullName : [directory stringByAppendingPathComponent:fullName];
        image = [UIImage imageNamed:qualifiedName];
    }
    if (image != nil)
    {
        uint64_t cost = image.CGImage == NULL ? 64 : (uint64_t)CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage);
        [_imageCache setObject:image forKey:cacheKey cost:(NSUInteger)MIN((uint64_t)NSUIntegerMax, cost)];
    }
    return image;
}

- (NSString *)pathForImageNamed:(NSString *)name inDirectory:(NSString *)directory scale:(CGFloat *)scale
{
    if ([name length] == 0)
        return nil;

    NSString *fullName = [_resourcePrefix length] == 0 ? name : [_resourcePrefix stringByAppendingString:name];
    NSString *extension = [fullName pathExtension];
    NSString *baseName = [extension length] == 0 ? fullName : [fullName stringByDeletingPathExtension];
    NSArray *extensions = [extension length] == 0 ? @[@"png", @"jpg", @"jpeg"] : @[extension];
    NSInteger preferredScale = OGAssetsPreferredScale();

    for (NSString *candidateExtension in extensions)
    {
        for (NSInteger candidateScale = preferredScale; candidateScale >= 1; candidateScale--)
        {
            NSString *resourceName = candidateScale == 1 ? baseName : [baseName stringByAppendingFormat:@"@%dx", (int)candidateScale];
            NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:candidateExtension inDirectory:directory];
            if ([path length] != 0)
            {
                if (scale != NULL)
                    *scale = (CGFloat)candidateScale;
                return path;
            }
        }
    }
    return nil;
}

- (UIImage *)uncachedImageNamed:(NSString *)name inDirectory:(NSString *)directory
{
    CGFloat scale = 1.0f;
    NSString *path = [self pathForImageNamed:name inDirectory:directory scale:&scale];
    if ([path length] == 0)
        return nil;

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (scale > 1.0f && image != nil && image.CGImage != NULL)
        return [UIImage imageWithCGImage:image.CGImage scale:scale orientation:UIImageOrientationUp];
    return image;
}

- (UIImage *)uncachedImageNamed:(NSString *)name inDirectory:(NSString *)directory maximumPixelSize:(size_t)maximumPixelSize
{
    NSString *path = [self pathForImageNamed:name inDirectory:directory scale:NULL];
    if ([path length] == 0)
        return nil;
    return OGPlatformThumbnailFromImageFile(path, maximumPixelSize);
}

- (UIImage *)resizableImageNamed:(NSString *)name leftCap:(NSInteger)leftCap topCap:(NSInteger)topCap
{
    return [self resizableImageNamed:name inDirectory:nil leftCap:leftCap topCap:topCap];
}

- (UIImage *)resizableImageNamed:(NSString *)name inDirectory:(NSString *)directory leftCap:(NSInteger)leftCap topCap:(NSInteger)topCap
{
    UIImage *image = [self imageNamed:name inDirectory:directory];
    if (image == nil)
        return nil;
    return [image stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
}

@end
