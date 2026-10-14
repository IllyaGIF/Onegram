#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponentsGlobals.h"
#import "TGPlaceholderImageDataSource.h"
#import "../OnegramPlatform/OGPlatformVersion.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGInterfaceAssets.h"
#import <math.h>

static TG_SYNCHRONIZED_DEFINE(imageCache) = PTHREAD_MUTEX_INITIALIZER;

typedef struct
{
    int top;
    int bottom;
} TGTwoColors;

static const TGTwoColors colors[] = {
    { .top = 0xff516a, .bottom = 0xff885e },
    { .top = 0xffa85c, .bottom = 0xffcd6a },
    { .top = 0x665fff, .bottom = 0x82b1ff },
    { .top = 0x54cb68, .bottom = 0xa0de7e },
    { .top = 0x28c9b7, .bottom = 0x53edd6 },
    { .top = 0x2a9ef1, .bottom = 0x72d5fd },
    { .top = 0xd669ed, .bottom = 0xe0a2f3 },
};


#if defined(ONEGRAM_ARMV6)
typedef struct
{
    CGContextRef context;
    void *data;
    size_t width;
    size_t height;
    size_t rowBytes;
} TGIOS3PlaceholderBitmap;

static bool TGIOS3PlaceholderBegin(CGSize size, TGIOS3PlaceholderBitmap *bitmap)
{
    if (bitmap == NULL || !isfinite(size.width) || !isfinite(size.height) || size.width < 1.0f || size.height < 1.0f)
        return false;
    memset(bitmap, 0, sizeof(TGIOS3PlaceholderBitmap));
    size_t width = (size_t)ceilf(size.width);
    size_t height = (size_t)ceilf(size.height);
    size_t rowBytes = ((width * 4) + 15) & ~((size_t)15);
    if (width == 0 || height == 0 || width > 1024 || height > 1024 || height > ((size_t)-1) / rowBytes)
        return false;
    void *data = calloc(height, rowBytes);
    if (data == NULL)
        return false;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = colorSpace == NULL ? NULL : CGBitmapContextCreate(data, width, height, 8, rowBytes, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        free(data);
        return false;
    }
    CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    bitmap->context = context;
    bitmap->data = data;
    bitmap->width = width;
    bitmap->height = height;
    bitmap->rowBytes = rowBytes;
    return true;
}

static void TGIOS3PlaceholderReleaseData(void *info, __unused const void *data, __unused size_t size)
{
    if (info != NULL)
        free(info);
}

static UIImage *TGIOS3PlaceholderFinish(TGIOS3PlaceholderBitmap *bitmap)
{
    if (bitmap == NULL || bitmap->context == NULL || bitmap->data == NULL)
        return nil;

    CGContextFlush(bitmap->context);
    CGContextRelease(bitmap->context);
    bitmap->context = NULL;

    size_t length = bitmap->rowBytes * bitmap->height;
    void *data = bitmap->data;
    CGDataProviderRef provider = CGDataProviderCreateWithData(data, data, length, TGIOS3PlaceholderReleaseData);
    if (provider == NULL)
    {
        free(data);
        memset(bitmap, 0, sizeof(TGIOS3PlaceholderBitmap));
        return nil;
    }

    bitmap->data = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = colorSpace == NULL ? NULL : CGImageCreate(bitmap->width, bitmap->height, 8, 32, bitmap->rowBytes, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host, provider, NULL, false, kCGRenderingIntentDefault);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    UIImage *image = imageRef == NULL ? nil : [[UIImage alloc] initWithCGImage:imageRef];
    if (imageRef != NULL)
        CGImageRelease(imageRef);
    memset(bitmap, 0, sizeof(TGIOS3PlaceholderBitmap));
    return image;
}

static void TGIOS3PlaceholderDrawImage(CGContextRef context, UIImage *image, CGRect rect)
{
    if (context == NULL || image == nil || image.CGImage == NULL)
        return;
    CGContextDrawImage(context, rect, image.CGImage);
}
#endif

static bool TGClassicIOS6StyleEnabled(void)
{
    return (TGCurrentInterfaceStyle() != 0);
}

static UIImage *TGClassicIOS6AvatarResource(NSString *name)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString *resourceName = scale > 1.5f ? [name stringByAppendingFormat:@"%c2x", 64] : name;
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    if (path.length == 0 && scale > 1.5f)
        path = [[NSBundle mainBundle] pathForResource:name ofType:@"png" inDirectory:@"ClassicIOS6"];
    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && scale > 1.5f && [resourceName hasSuffix:@"@2x"] && image.CGImage != NULL)
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
    return image;
}

static UIImage *TGClassicIOS6AvatarPlaceholder(NSDictionary *args, CGSize size)
{
    if (!TGClassicIOS6StyleEnabled())
        return nil;

    NSString *type = args[@"type"];
    NSString *name = nil;

    if ([type isEqualToString:@"saved-messages"])
    {
        name = @"OnegramiumSavedMessagesAvatar";
    }
    else if ([type isEqualToString:@"user-avatar"])
    {
        int32_t uid = [args[@"uid"] intValue];
        if (uid == 0)
            name = @"DialogListAvatarSystem";
        else
            name = [NSString stringWithFormat:@"%@%d", size.width <= 40.0f ? @"SmallAvatar" : @"DialogListAvatar", [[TGInterfaceAssets instance] userColorIndex:uid] + 1];
    }
    else if ([type isEqualToString:@"group-avatar"])
    {
        int64_t gid = [args[@"cid"] longLongValue];
        int index = [[TGInterfaceAssets instance] groupColorIndex:gid] % 4 + 1;
        name = [NSString stringWithFormat:@"%@%d", size.width <= 40.0f ? @"DialogListGroupAvatarSmall" : @"DialogListGroupAvatar", index];
    }

    UIImage *source = name.length == 0 ? nil : TGClassicIOS6AvatarResource(name);
    if (source == nil)
        return nil;

#if defined(ONEGRAM_ARMV6)
    TGIOS3PlaceholderBitmap bitmap;
    if (!TGIOS3PlaceholderBegin(size, &bitmap))
        return source;
    TGIOS3PlaceholderDrawImage(bitmap.context, source, CGRectMake(0.0f, 0.0f, size.width, size.height));
    return TGIOS3PlaceholderFinish(&bitmap);
#else
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    [source drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
#endif
}

@implementation TGPlaceholderImageDataSource

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[TGPlaceholderImageDataSource alloc] init]];
    }
}

+ (NSMutableDictionary *)imageCache
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:@"placeholder://"];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:@"placeholder://"];
}

- (NSValue *)groupGradient:(int64_t)gid
{
    return [NSValue valueWithBytes:&colors[[[TGInterfaceAssets instance] groupColorIndex:gid]] objCType:@encode(TGTwoColors)];
}

- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute
{
    if ([uri hasPrefix:@"placeholder://"] && [attribute hasPrefix:@"groupGradient-"])
    {
        return [self groupGradient:[[attribute substringFromIndex:@"groupGradient-".length] longLongValue]];
    }
    
    return nil;
}

- (id)cacheKeyForArgs:(NSDictionary *)args
{
    if ([args[@"type"] isEqualToString:@"user-avatar"])
    {
        int uid = [args[@"uid"] intValue];
        int colorIndex = [[TGInterfaceAssets instance] userColorIndex:uid];
        
        return [[NSString alloc] initWithFormat:@"%@:%d:%@x%@:%d", args[@"type"], uid == 0 ? -1 : colorIndex, args[@"w"], args[@"h"], TGClassicIOS6StyleEnabled() ? 1 : 0];
    }
    else
    {
        int64_t gid = [args[@"cid"] longLongValue];
        int colorIndex = [[TGInterfaceAssets instance] groupColorIndex:gid];
        
        return [[NSString alloc] initWithFormat:@"%@:%d:%@x%@:%d", args[@"type"], gid == 0 ? -1 : colorIndex, args[@"w"], args[@"h"], TGClassicIOS6StyleEnabled() ? 1 : 0];
    }
}

- (TGDataResource *)loadDataSyncWithUri:(NSString *)uri canWait:(bool)canWait acceptPartialData:(bool)__unused acceptPartialData asyncTaskId:(__autoreleasing id *)__unused asyncTaskId progress:(void (^)(float))__unused progress partialCompletion:(void (^)(TGDataResource *))__unused partialCompletion completion:(void (^)(TGDataResource *))__unused completion
{
    if (uri == nil)
        return nil;
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"placeholder://?".length]];
    
    TG_SYNCHRONIZED_BEGIN(imageCache);
    UIImage *cachedImage = [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]];
    TG_SYNCHRONIZED_END(imageCache);
    
    if (cachedImage != nil)
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    
    if (!canWait)
        return nil;
    
    return [self _createAndCachePlaceholderWithArgs:args];
}

- (TGTwoColors)_colorsForUid:(int32_t)uid
{
    if (uid == 0)
        return (TGTwoColors){.top = 0xb1b1b1, .bottom = 0xcdcdcd };

    int colorIndex = [[TGInterfaceAssets instance] userColorIndex:uid];
    return colors[colorIndex];
}

- (TGTwoColors)_colorsForGroupId:(int64_t)groupId
{
    if (groupId == 0)
        return (TGTwoColors){.top = 0x8a8d91, .bottom = 0xbfc1c3};
    
    int colorIndex = [[TGInterfaceAssets instance] groupColorIndex:groupId];
    return colors[colorIndex];
}

- (TGDataResource *)_createAndCachePlaceholderWithArgs:(NSDictionary *)args
{
    CGSize size = CGSizeZero;
    size.width = [args[@"w"] intValue];
    size.height = [args[@"h"] intValue];
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    
    NSString *type = args[@"type"];
    UIImage *classicPlaceholder = TGClassicIOS6AvatarPlaceholder(args, size);
    if (classicPlaceholder != nil)
    {
        TG_SYNCHRONIZED_BEGIN(imageCache);
        [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]] = classicPlaceholder;
        TG_SYNCHRONIZED_END(imageCache);
        return [[TGDataResource alloc] initWithImage:classicPlaceholder decoded:true];
    }
#if defined(ONEGRAM_ARMV6)
    if ([type isEqualToString:@"user-avatar"] || [type isEqualToString:@"group-avatar"] || [type isEqualToString:@"saved-messages"])
    {
        TGIOS3PlaceholderBitmap bitmap;
        if (!TGIOS3PlaceholderBegin(size, &bitmap))
            return nil;

        CGContextRef context = bitmap.context;
        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
        CGContextClip(context);

        TGTwoColors twoColors;
        if ([type isEqualToString:@"user-avatar"])
            twoColors = [self _colorsForUid:[args[@"uid"] intValue]];
        else if ([type isEqualToString:@"group-avatar"])
            twoColors = [self _colorsForGroupId:[args[@"cid"] longLongValue]];
        else
            twoColors = colors[5];

        CGFloat topComponents[4] = { ((twoColors.top >> 16) & 0xff) / 255.0f, ((twoColors.top >> 8) & 0xff) / 255.0f, (twoColors.top & 0xff) / 255.0f, 1.0f };
        CGFloat bottomComponents[4] = { ((twoColors.bottom >> 16) & 0xff) / 255.0f, ((twoColors.bottom >> 8) & 0xff) / 255.0f, (twoColors.bottom & 0xff) / 255.0f, 1.0f };
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef bottomColor = colorSpace == NULL ? NULL : CGColorCreate(colorSpace, bottomComponents);
        CGColorRef topColor = colorSpace == NULL ? NULL : CGColorCreate(colorSpace, topComponents);
        const void *gradientColors[2] = { bottomColor, topColor };
        CFArrayRef colorsArray = bottomColor == NULL || topColor == NULL ? NULL : CFArrayCreate(kCFAllocatorDefault, gradientColors, 2, &kCFTypeArrayCallBacks);
        CGFloat locations[2] = { 0.0f, 1.0f };
        CGGradientRef gradient = colorsArray == NULL || colorSpace == NULL ? NULL : CGGradientCreateWithColors(colorSpace, colorsArray, locations);
        if (gradient != NULL)
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        if (gradient != NULL)
            CGGradientRelease(gradient);
        if (colorsArray != NULL)
            CFRelease(colorsArray);
        if (bottomColor != NULL)
            CGColorRelease(bottomColor);
        if (topColor != NULL)
            CGColorRelease(topColor);
        if (colorSpace != NULL)
            CGColorSpaceRelease(colorSpace);

        if ([type isEqualToString:@"saved-messages"])
        {
            UIImage *icon = TGImageNamed(@"SavedMessagesIcon");
            CGSize ratios = CGSizeMake(22.0f / 60.0f, 27.0f / 60.0f);
            CGSize iconSize = CGSizeMake(round(size.width * ratios.width), round(size.height * ratios.height));
            TGIOS3PlaceholderDrawImage(context, icon, CGRectMake((size.width - iconSize.width) / 2.0f, ceil((size.height - iconSize.height) / 2.0f) + 1.0f, iconSize.width, iconSize.height));
        }

        UIImage *image = TGIOS3PlaceholderFinish(&bitmap);
        if (image != nil)
        {
            TG_SYNCHRONIZED_BEGIN(imageCache);
            [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]] = image;
            TG_SYNCHRONIZED_END(imageCache);
        }
        return image == nil ? nil : [[TGDataResource alloc] initWithImage:image decoded:true];
    }
#endif

    if ([type isEqualToString:@"user-avatar"])
    {
        int32_t uid = [args[@"uid"] intValue];
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
        CGContextClip(context);
        
        TGTwoColors twoColors = [self _colorsForUid:uid];
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(twoColors.bottom).CGColor),
            CGColorRetain(UIColorRGB(twoColors.top).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        if (context != NULL)
        {
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        }

        
        CFRelease(gradient);
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (image != nil)
        {
            TG_SYNCHRONIZED_BEGIN(imageCache);
            [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]] = image;
            TG_SYNCHRONIZED_END(imageCache);
        }
    }
    else if ([type isEqualToString:@"group-avatar"])
    {
        int64_t gid = [args[@"cid"] longLongValue];
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
        CGContextClip(context);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        TGTwoColors twoColors = [self _colorsForGroupId:gid];
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(twoColors.bottom).CGColor),
            CGColorRetain(UIColorRGB(twoColors.top).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        if (context != NULL)
        {
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        }

        CFRelease(gradient);
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (image != nil)
        {
            TG_SYNCHRONIZED_BEGIN(imageCache);
            [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]] = image;
            TG_SYNCHRONIZED_END(imageCache);
        }
    }
    else if ([type isEqualToString:@"saved-messages"])
    {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
        CGContextClip(context);
        
        TGTwoColors twoColors = colors[5];
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(twoColors.bottom).CGColor),
            CGColorRetain(UIColorRGB(twoColors.top).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        if (context != NULL)
        {
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        }

        
        CFRelease(gradient);
        
        UIImage *icon = TGImageNamed(@"SavedMessagesIcon");
        CGSize ratios = CGSizeMake(22.0f / 60.0f, 27.0f / 60.0f);
        CGSize iconSize = CGSizeMake(round(size.width * ratios.width), round(size.height * ratios.height));
        [icon drawInRect:CGRectMake((size.width - iconSize.width) / 2.0f, ceil((size.height - iconSize.height) / 2.0f) + 1.0f, iconSize.width, iconSize.height)];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (image != nil)
        {
            TG_SYNCHRONIZED_BEGIN(imageCache);
            [TGPlaceholderImageDataSource imageCache][[self cacheKeyForArgs:args]] = image;
            TG_SYNCHRONIZED_END(imageCache);
        }
    }
    
    return nil;
}

@end
