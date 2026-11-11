#import "TGGroupAvatarGalleryItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGGroupAvatarGalleryItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStringUtils.h"

@interface TGGroupAvatarGalleryItem ()
{
    NSString *_legacyUrl;
}

@end

static void OGCompatResolveAvatarUrls(NSString **thumbnailUrl, NSString **fullUrl)
{
    NSString *full = [*fullUrl length] != 0 ? *fullUrl : *thumbnailUrl;
    NSString *thumbnail = [*thumbnailUrl length] != 0 ? *thumbnailUrl : full;
    *fullUrl = full ?: @"";
    *thumbnailUrl = thumbnail ?: @"";
}

@implementation TGGroupAvatarGalleryItem

- (Class)viewClass
{
    return [TGGroupAvatarGalleryItemView class];
}

- (instancetype)initWithMessageId:(int32_t)messageId legacyThumbnailUrl:(NSString *)legacyThumbnailUrl legacyUrl:(NSString *)legacyUrl imageId:(int64_t)imageId imageSize:(CGSize)imageSize
{
    return [self initWithMessageId:messageId legacyThumbnailUrl:legacyThumbnailUrl legacyUrl:legacyUrl imageId:imageId imageSize:imageSize originInfo:nil];
}

- (instancetype)initWithMessageId:(int32_t)messageId legacyThumbnailUrl:(NSString *)legacyThumbnailUrl legacyUrl:(NSString *)legacyUrl imageId:(int64_t)imageId imageSize:(CGSize)imageSize originInfo:(TGMediaOriginInfo *)originInfo
{
    OGCompatResolveAvatarUrls(&legacyThumbnailUrl, &legacyUrl);
    
    NSMutableArray *query = [[NSMutableArray alloc] initWithObjects:[@"legacy-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyUrl]], [@"legacy-thumbnail-cache-url=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:legacyThumbnailUrl]], nil];
    if (originInfo != nil)
        [query addObject:[@"origin_info=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:[originInfo stringRepresentation]]]];
    [query addObject:[[NSString alloc] initWithFormat:@"width=%d&height=%d", (int)imageSize.width, (int)imageSize.height]];
    if (imageId != 0)
        [query addObject:[[NSString alloc] initWithFormat:@"imageId=%lld", imageId]];
    NSString *imageUri = [@"peer-avatar://?" stringByAppendingString:[query componentsJoinedByString:@"&"]];
    
    self = [super initWithUri:imageUri imageSize:imageSize];
    if (self != nil)
    {
        self.imageId = imageId;
        _messageId = messageId;
        _legacyUrl = legacyUrl;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object])
        return false;
    
    if ([object isKindOfClass:[TGGroupAvatarGalleryItem class]] && _messageId == ((TGGroupAvatarGalleryItem *)object).messageId)
    {
        return true;
    }
    
    return false;
}

- (NSString *)filePath
{
    return [[TGRemoteImageView sharedCache] pathForCachedData:_legacyUrl];
}

@end
