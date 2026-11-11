#import "TGUserAvatarGalleryItem.h"

#import "TGUserAvatarGalleryItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStringUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"

static void OGCompatResolveAvatarUrls(NSString **thumbnailUrl, NSString **fullUrl)
{
    NSString *full = [*fullUrl length] != 0 ? *fullUrl : *thumbnailUrl;
    NSString *thumbnail = [*thumbnailUrl length] != 0 ? *thumbnailUrl : full;
    *fullUrl = full ?: @"";
    *thumbnailUrl = thumbnail ?: @"";
}

@implementation TGUserAvatarGalleryItem

- (instancetype)initWithLegacyThumbnailUrl:(NSString *)legacyThumbnailUrl legacyUrl:(NSString *)legacyUrl imageId:(int64_t)imageId imageSize:(CGSize)imageSize isCurrent:(bool)isCurrent
{
    return [self initWithLegacyThumbnailUrl:legacyThumbnailUrl legacyUrl:legacyUrl imageId:imageId imageSize:imageSize isCurrent:isCurrent originInfo:nil];
}

- (instancetype)initWithLegacyThumbnailUrl:(NSString *)legacyThumbnailUrl legacyUrl:(NSString *)legacyUrl imageId:(int64_t)imageId imageSize:(CGSize)imageSize isCurrent:(bool)isCurrent originInfo:(TGMediaOriginInfo *)originInfo
{
    OGCompatResolveAvatarUrls(&legacyThumbnailUrl, &legacyUrl);
    
    NSString *originQuery = originInfo != nil ? [TGStringUtils stringByEscapingForURL:[originInfo stringRepresentation]] : nil;
    NSMutableArray *query = [[NSMutableArray alloc] init];
    NSString *scheme = nil;
    if (imageId != 0)
    {
        scheme = @"media-gallery-image://?&";
        NSString *cachedPath = [[TGRemoteImageView sharedCache] pathForCachedData:legacyUrl];
        [query addObject:[[NSString alloc] initWithFormat:@"id=%lld", imageId]];
        [query addObject:[@"legacy-file-path=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:cachedPath ?: @""]]];
        [query addObject:[@"legacy-thumbnail-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyThumbnailUrl]]];
        [query addObject:[[NSString alloc] initWithFormat:@"width=%d&height=%d&renderWidth=%d&renderHeight=%d", (int)imageSize.width, (int)imageSize.height, (int)imageSize.width, (int)imageSize.height]];
        [query addObject:@"messageId=0&conversationId=0"];
        if (originQuery != nil)
            [query addObject:[@"origin_info=" stringByAppendingString:originQuery]];
        [query addObject:[@"legacy-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyUrl]]];
    }
    else
    {
        scheme = @"peer-avatar://?";
        [query addObject:[@"legacy-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyUrl]]];
        [query addObject:[@"legacy-thumbnail-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyThumbnailUrl]]];
        if (originQuery != nil)
            [query addObject:[@"origin_info=" stringByAppendingString:originQuery]];
        [query addObject:[[NSString alloc] initWithFormat:@"width=%d&height=%d", (int)imageSize.width, (int)imageSize.height]];
    }
    NSString *imageUri = [scheme stringByAppendingString:[query componentsJoinedByString:@"&"]];
    
    self = [super initWithUri:imageUri imageSize:imageSize];
    if (self != nil)
    {
        self.imageId = imageId;
        _legacyThumbnailUrl = legacyThumbnailUrl;
        _legacyUrl = legacyUrl;
        _isCurrent = isCurrent;
    }
    return self;
}

- (Class)viewClass
{
    return [TGUserAvatarGalleryItemView class];
}

- (NSString *)filePath
{
    return [[TGRemoteImageView sharedCache] pathForCachedData:_legacyUrl];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[TGUserAvatarGalleryItem class]] == false)
        return false;
    
    TGUserAvatarGalleryItem *other = (TGUserAvatarGalleryItem *)object;
    if (self.imageId != 0 || other.imageId != 0)
        return self.imageId == other.imageId;
    
    return (_isCurrent && other->_isCurrent) || [super isEqual:object];
}

@end
