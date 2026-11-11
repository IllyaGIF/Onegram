#import "TGImageInfo+Telegraph.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGSchema.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGCache.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

static NSString *OGCompatPhotoUrl(TLPhoto$photo *photo, TLPhotoSize$photoSize *size)
{
    if (photo == nil || size == nil || photo.dc_id == 0 || photo.n_id == 0)
        return nil;

    NSString *reference = photo.file_reference.length != 0 ? [photo.file_reference stringByEncodingInHex] : @"";
    return [NSString stringWithFormat:@"photo:%d:%lld:%lld:%d:%@:%@", photo.dc_id, photo.n_id, photo.access_hash, size.size, size.type ?: @"", reference];
}

static void TGCacheEmbeddedPhotoSize(NSData *data, NSString *url)
{
    if (data.length == 0 || url.length == 0)
        return;
    dispatch_async([TGCache diskCacheQueue], ^
    {
        TGCache *cache = [TGRemoteImageView sharedCache];
        if (![[cache cachedDataForUrl:url] isEqualToData:data])
        {
            [cache removeFromMemoryCache:url matchEnd:false];
            [cache cacheImage:nil withData:data url:url availability:TGCacheDisk];
        }
    });
}

static NSString *OGCompatLocationKey(int32_t dcId, int64_t volumeId, int32_t localId, int64_t secret)
{
    return [NSString stringWithFormat:@"%d_%lld_%d_%lld", dcId, volumeId, localId, secret];
}

#define OG_COMPAT_SECRET_LOCATION_KEY(type, location) \
    if ([location isKindOfClass:[type class]]) \
    { \
        type *typed = location; \
        return OGCompatLocationKey(typed.dcId.intValue, typed.volumeId.longLongValue, typed.localId.intValue, typed.secret.longLongValue); \
    }

NSString *extractFileUrl(id fileLocation)
{
    if ([fileLocation isKindOfClass:[TLFileLocation$fileLocation class]])
    {
        TLFileLocation$fileLocation *typed = (TLFileLocation$fileLocation *)fileLocation;
        return OGCompatLocationKey(typed.dc_id, typed.volume_id, typed.local_id, typed.secret);
    }

    OG_COMPAT_SECRET_LOCATION_KEY(Secret23_FileLocation_fileLocation, fileLocation)
    OG_COMPAT_SECRET_LOCATION_KEY(Secret66_FileLocation_fileLocation, fileLocation)
    OG_COMPAT_SECRET_LOCATION_KEY(Secret73_FileLocation_fileLocation, fileLocation)

    return nil;
}

#undef OG_COMPAT_SECRET_LOCATION_KEY

@implementation TGImageInfo (Telegraph)

- (NSString *)imageUrlForPreviewWithSize:(CGSize *)size
{
    NSString *selected = nil;
    CGSize selectedSize = CGSizeZero;
    CGFloat targetSide = MIN(1024.0f, MAX(320.0f, 320.0f * TGScreenScaling()));
    CGFloat selectedSide = 0.0f;
    NSDictionary *sizes = [self allSizes];
    for (NSString *uri in sizes)
    {
        if ([uri hasPrefix:@"photo:"] || [uri hasPrefix:@"documentthumb:"])
        {
            NSArray *parts = [uri componentsSeparatedByString:@":"];
            if (parts.count < 7 || [parts[5] length] == 0 || [parts[5] isEqualToString:@"i"] || [parts[4] longLongValue] > 512 * 1024)
                continue;
        }
        CGSize candidate = [sizes[uri] CGSizeValue];
        CGFloat side = MAX(candidate.width, candidate.height);
        if (!(candidate.width > 0.0f && candidate.height > 0.0f && side <= 4096.0f) || [self fileSizeForUrl:uri] > 512 * 1024)
            continue;
        if (selected == nil || (selectedSide < targetSide && side > selectedSide) ||
            (side >= targetSide && side < selectedSide))
        {
            selected = uri;
            selectedSize = candidate;
            selectedSide = side;
        }
    }
    if (size != NULL)
        *size = selectedSize;
    return selected;
}

- (NSString *)imageUrlForStrippedPreview
{
    for (NSString *uri in [self allSizes])
    {
        if (![uri hasPrefix:@"photo:"])
            continue;
        NSArray *parts = [uri componentsSeparatedByString:@":"];
        if (parts.count >= 7 && [parts[5] isEqualToString:@"i"])
            return uri;
    }
    return nil;
}

- (id)initWithTelegraphSizesDescription:(NSArray *)sizesDesc
{
    return [self initWithTelegraphSizesDescription:sizesDesc cachedData:nil];
}

- (id)initWithTelegraphSizesDescription:(NSArray *)sizesDesc cachedData:(__autoreleasing NSData **)cachedData
{
    self = [super init];
    if (self != nil)
    {   
        for (TLPhotoSize *sizeDesc in sizesDesc)
        {
            if ([sizeDesc isKindOfClass:[TLPhotoSize$photoSize class]])
            {
                TLPhotoSize$photoSize *concreteSize = (TLPhotoSize$photoSize *)sizeDesc;
                NSString *urlLocation = extractFileUrl(concreteSize.location);
                
#ifdef DEBUG
                if ([concreteSize.type isEqualToString:@"s"])
                {
                    TGLog(@"***** Non-cached photo size received: %@", urlLocation);
                }
#endif
                
                [self addImageWithSize:CGSizeMake(concreteSize.w, concreteSize.h) url:urlLocation fileSize:concreteSize.size];
            }
            else if ([sizeDesc isKindOfClass:[TLPhotoSize$photoCachedSize class]])
            {
                TLPhotoSize$photoCachedSize *concreteSize = (TLPhotoSize$photoCachedSize *)sizeDesc;
                
                NSString *url = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w, concreteSize.h) url:url fileSize:(int32_t)concreteSize.bytes.length];
                
                if (concreteSize.bytes.length != 0)
                {
                    NSData *imageData = concreteSize.bytes;
                    if (cachedData != NULL)
                       *cachedData = imageData;
                    else
                        TGCacheEmbeddedPhotoSize(imageData, url);
                }
            }
        }
    }
    return self;
}

- (id)initWithModernTelegraphPhoto:(TLPhoto$photo *)photo cachedData:(__autoreleasing NSData **)cachedData
{
    self = [super init];
    if (self != nil)
    {
        for (TLPhotoSize *sizeDesc in photo.sizes)
        {
            if ([sizeDesc isKindOfClass:[TLPhotoSize$photoSize class]])
            {
                TLPhotoSize$photoSize *full = (TLPhotoSize$photoSize *)sizeDesc;
                NSString *url = extractFileUrl(full.location) ?: OGCompatPhotoUrl(photo, full);
                [self addImageWithSize:CGSizeMake(full.w, full.h) url:url fileSize:full.size];
            }
            else if ([sizeDesc isKindOfClass:[TLPhotoSize$photoCachedSize class]])
            {
                TLPhotoSize$photoCachedSize *embedded = (TLPhotoSize$photoCachedSize *)sizeDesc;
                int32_t byteCount = (int32_t)embedded.bytes.length;

                TLPhotoSize$photoSize *descriptor = [[TLPhotoSize$photoSize alloc] init];
                descriptor.type = embedded.type;
                descriptor.w = embedded.w;
                descriptor.h = embedded.h;
                descriptor.size = byteCount;

                NSString *url = extractFileUrl(embedded.location) ?: OGCompatPhotoUrl(photo, descriptor);
                [self addImageWithSize:CGSizeMake(embedded.w, embedded.h) url:url fileSize:byteCount];

                if (byteCount != 0)
                {
                    if (cachedData != NULL)
                        *cachedData = embedded.bytes;
                    else if (url != nil)
                        [[TGRemoteImageView sharedCache] cacheImage:nil withData:embedded.bytes url:url availability:TGCacheDisk];
                }
            }
        }
    }
    return self;
}

- (id)initWithSecret23SizesDescription:(NSArray *)sizesDesc cachedData:(__autoreleasing NSData **)cachedData
{
    self = [super init];
    if (self != nil)
    {
        for (id sizeDesc in sizesDesc)
        {
            if ([sizeDesc isKindOfClass:[Secret23_PhotoSize_photoSize class]])
            {
                Secret23_PhotoSize_photoSize *concreteSize = sizeDesc;
                NSString *urlLocation = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:urlLocation];
            }
            else if ([sizeDesc isKindOfClass:[Secret23_PhotoSize_photoCachedSize class]])
            {
                Secret23_PhotoSize_photoCachedSize *concreteSize = sizeDesc;
                
                NSString *url = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:url];
                
                if (concreteSize.bytes.length != 0)
                {
                    NSData *imageData = concreteSize.bytes;
                    if (cachedData != NULL)
                   *cachedData = imageData;
                    else
                        TGCacheEmbeddedPhotoSize(imageData, url);
                }
            }
        }
    }
    return self;
}

- (id)initWithSecret46SizesDescription:(NSArray *)sizesDesc cachedData:(__autoreleasing NSData **)cachedData {
    self = [super init];
    if (self != nil)
    {
        for (id sizeDesc in sizesDesc)
        {
            if ([sizeDesc isKindOfClass:[Secret46_PhotoSize_photoSize class]])
            {
                Secret46_PhotoSize_photoSize *concreteSize = sizeDesc;
                NSString *urlLocation = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:urlLocation];
            }
            else if ([sizeDesc isKindOfClass:[Secret46_PhotoSize_photoCachedSize class]])
            {
                Secret46_PhotoSize_photoCachedSize *concreteSize = sizeDesc;
                
                NSString *url = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:url];
                
                if (concreteSize.bytes.length != 0)
                {
                    NSData *imageData = concreteSize.bytes;
                    if (cachedData != NULL)
                       *cachedData = imageData;
                    else
                        TGCacheEmbeddedPhotoSize(imageData, url);
                }
            }
        }
    }
    return self;
}

- (id)initWithSecret66SizesDescription:(NSArray *)sizesDesc cachedData:(__autoreleasing NSData **)cachedData {
    self = [super init];
    if (self != nil)
    {
        for (id sizeDesc in sizesDesc)
        {
            if ([sizeDesc isKindOfClass:[Secret66_PhotoSize_photoSize class]])
            {
                Secret66_PhotoSize_photoSize *concreteSize = sizeDesc;
                NSString *urlLocation = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:urlLocation];
            }
            else if ([sizeDesc isKindOfClass:[Secret66_PhotoSize_photoCachedSize class]])
            {
                Secret66_PhotoSize_photoCachedSize *concreteSize = sizeDesc;
                
                NSString *url = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:url];
                
                if (concreteSize.bytes.length != 0)
                {
                    NSData *imageData = concreteSize.bytes;
                    if (cachedData != NULL)
                       *cachedData = imageData;
                    else
                        TGCacheEmbeddedPhotoSize(imageData, url);
                }
            }
        }
    }
    return self;
}

- (id)initWithSecret73SizesDescription:(NSArray *)sizesDesc cachedData:(__autoreleasing NSData **)cachedData {
    self = [super init];
    if (self != nil)
    {
        for (id sizeDesc in sizesDesc)
        {
            if ([sizeDesc isKindOfClass:[Secret73_PhotoSize_photoSize class]])
            {
                Secret73_PhotoSize_photoSize *concreteSize = sizeDesc;
                NSString *urlLocation = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:urlLocation];
            }
            else if ([sizeDesc isKindOfClass:[Secret73_PhotoSize_photoCachedSize class]])
            {
                Secret73_PhotoSize_photoCachedSize *concreteSize = sizeDesc;
                
                NSString *url = extractFileUrl(concreteSize.location);
                
                [self addImageWithSize:CGSizeMake(concreteSize.w.intValue, concreteSize.h.intValue) url:url];
                
                if (concreteSize.bytes.length != 0)
                {
                    NSData *imageData = concreteSize.bytes;
                    if (cachedData != NULL)
                       *cachedData = imageData;
                    else
                        TGCacheEmbeddedPhotoSize(imageData, url);
                }
            }
        }
    }
    return self;
}


@end
