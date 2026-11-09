#import "TGMusicUtils.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#endif
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@interface TGMusicID3ArtworkReader : NSObject

+ (UIImage *)albumArtworkForURL:(NSURL *)url;

@end

static const CGFloat TGMusicAlbumArtworkThumbnailSide = 48.0f;

@implementation TGMusicUtils

+ (CGSize)albumArtworkPixelSize:(bool)thumbnail
{
    CGSize screenSize = TGScreenSize();
    CGFloat side = thumbnail ? TGMusicAlbumArtworkThumbnailSide : MIN(screenSize.width, screenSize.height);
    side = CGCeil(side * TGScreenScaling());
    return CGSizeMake(side, side);
}

+ (UIImage *)albumArtwork:(UIImage *)image thumbnail:(bool)thumbnail
{
    if (image == nil)
        return nil;
    
    CGSize imagePixelSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    CGSize fittedPixelSize = TGFitSize(imagePixelSize, [self albumArtworkPixelSize:thumbnail]);
    if (CGSizeEqualToSize(fittedPixelSize, imagePixelSize))
        return image;
    return TGScaleImageToPixelSize(image, fittedPixelSize);
}

+ (void)albumArtworkForURL:(NSURL *)url completion:(void (^)(UIImage *))completion
{
    if (completion == nil)
        return;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (asset == nil)
    {
        completion([self albumArtwork:[TGMusicID3ArtworkReader albumArtworkForURL:url] thumbnail:false]);
        return;
    }
    
    [asset loadValuesAsynchronouslyForKeys:@[@"commonMetadata"] completionHandler:^
    {
        UIImage *image = nil;
        for (AVMetadataItem *item in [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon])
        {
            id value = item.value;
            NSData *data = nil;
            if ([value isKindOfClass:[NSData class]])
                data = value;
            else if ([value respondsToSelector:@selector(objectForKey:)])
                data = [value objectForKey:@"data"];
            
            if (data.length != 0)
                image = [UIImage imageWithData:data];
            if (image != nil)
                break;
        }
        
        if (image == nil)
            image = [TGMusicID3ArtworkReader albumArtworkForURL:url];
        completion([self albumArtwork:image thumbnail:false]);
    }];
#else
    completion([self albumArtwork:[TGMusicID3ArtworkReader albumArtworkForURL:url] thumbnail:false]);
#endif
}

@end

static const uint8_t TGID3Magic[3] = {0x49, 0x44, 0x33};
static const NSUInteger TGID3HeaderLength = 10;
static const uint8_t TGID3UnsynchronisationFlag = 0x80;
static const uint8_t TGID3ExtendedHeaderFlag = 0x40;
static const uint8_t TGID3v23EncodedFrameFlags = 0x80 | 0x40;
static const uint8_t TGID3v24EncodedFrameFlags = 0x08 | 0x04;
static const uint8_t TGID3v24FrameUnsynchronisationFlag = 0x02;

static const uint8_t TGID3v2Artwork[3] = {0x50, 0x49, 0x43};
static const uint8_t TGID3v3Artwork[4] = {0x41, 0x50, 0x49, 0x43};

const uint8_t TGJPGMagic[3] = {0xff, 0xd8, 0xff};
const uint8_t TGPNGMagic[4] = {0x89, 0x50, 0x4e, 0x47};

#define BYTE                8
#define VERSION_OFFSET      3
#define TAG_SIZE_OFFSET     6
#define TAG_OFFSET          10
#define ART_FRAME_OFFSET    12
#define LYRICS_FRAME_OFFSET 11

#define V2_FRAME_OFFSET     6
#define V2_ALBUM            @[@((uint8)0x54), @((uint8)0x41), @((uint8)0x4C)]
#define V2_ARTIST           @[@((uint8)0x54), @((uint8)0x50), @((uint8)0x31)]
#define V2_HEADER           @[@((uint8)0x49), @((uint8)0x44), @((uint8)0x33), @((uint8)0x02), @((uint8)0x00), @((uint8)0x00)]
#define V2_LYRICS           @[@((uint8)0x55), @((uint8)0x4C), @((uint8)0x54)]
#define V2_TITLE            @[@((uint8)0x54), @((uint8)0x54), @((uint8)0x32)]

#define V3_FRAME_OFFSET     10
#define V3_ALBUM            @[@((uint8)0x54), @((uint8)0x41), @((uint8)0x4C), @((uint8)0x42)]
#define V3_ARTIST           @[@((uint8)0x54), @((uint8)0x50), @((uint8)0x45), @((uint8)0x31)]
#define V3_HEADER           @[@((uint8)0x49), @((uint8)0x44), @((uint8)0x33), @((uint8)0x03), @((uint8)0x00), @((uint8)0x00)]
#define V3_LYRICS           @[@((uint8)0x55), @((uint8)0x53), @((uint8)0x4C), @((uint8)0x54)]
#define V3_TITLE            @[@((uint8)0x54), @((uint8)0x49), @((uint8)0x54), @((uint8)0x32)]

@implementation TGMusicID3ArtworkReader

+ (UIImage *)albumArtworkForURL:(NSURL *)url
{
    NSData *data = [NSData dataWithContentsOfMappedFile:url.path];
    if (data.length < TGID3HeaderLength)
        return nil;
    
    const uint8_t *header = data.bytes;
    uint8_t version = header[3];
    uint8_t flags = header[5];
    if (memcmp(header, TGID3Magic, 3) != 0 || version < 2 || version > 4)
        return nil;
    
    NSUInteger tagLength = MIN((NSUInteger)[self syncsafeInteger:header + 6], data.length - TGID3HeaderLength);
    NSData *tag = [data subdataWithRange:NSMakeRange(TGID3HeaderLength, tagLength)];
    if (version < 4 && (flags & TGID3UnsynchronisationFlag))
        tag = [self resynchronisedData:tag];
    
    const uint8_t *bytes = tag.bytes;
    NSUInteger length = tag.length;
    NSUInteger position = 0;
    if (version > 2 && (flags & TGID3ExtendedHeaderFlag) && length >= 4)
        position = version == 4 ? [self syncsafeInteger:bytes] : [self bigEndianInteger:bytes] + 4;
    
    NSUInteger frameHeaderLength = version == 2 ? 6 : 10;
    while (position + frameHeaderLength <= length && bytes[position] != 0)
    {
        const uint8_t *frame = bytes + position;
        NSUInteger frameLength = 0;
        if (version == 2)
            frameLength = ((NSUInteger)frame[3] << 16) | ((NSUInteger)frame[4] << 8) | frame[5];
        else
            frameLength = version == 4 ? [self syncsafeInteger:frame + 4] : [self bigEndianInteger:frame + 4];
        
        position += frameHeaderLength;
        if (frameLength > length - position)
            break;
        
        if ([self isPictureFrame:frame version:version])
        {
            NSData *frameData = [tag subdataWithRange:NSMakeRange(position, frameLength)];
            if (version == 4 && ((flags & TGID3UnsynchronisationFlag) || (frame[9] & TGID3v24FrameUnsynchronisationFlag)))
                frameData = [self resynchronisedData:frameData];
            
            UIImage *image = [self imageInPictureFrameData:frameData];
            if (image != nil)
                return image;
        }
        
        position += frameLength;
    }
    
    return nil;
}

+ (bool)isPictureFrame:(const uint8_t *)frame version:(uint8_t)version
{
    if (version == 2)
        return memcmp(frame, TGID3v2Artwork, 3) == 0;
    
    uint8_t encodedFlags = version == 4 ? TGID3v24EncodedFrameFlags : TGID3v23EncodedFrameFlags;
    return memcmp(frame, TGID3v3Artwork, 4) == 0 && (frame[9] & encodedFlags) == 0;
}

+ (UIImage *)imageInPictureFrameData:(NSData *)frameData
{
    const uint8_t *bytes = frameData.bytes;
    NSUInteger length = frameData.length;
    for (NSUInteger i = 0; i + 4 <= length; i++)
    {
        if (memcmp(bytes + i, TGJPGMagic, 3) == 0 || memcmp(bytes + i, TGPNGMagic, 4) == 0)
            return [UIImage imageWithData:[frameData subdataWithRange:NSMakeRange(i, length - i)]];
    }
    return nil;
}

+ (NSData *)resynchronisedData:(NSData *)data
{
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:length];
    NSUInteger chunkStart = 0;
    for (NSUInteger i = 1; i < length; i++)
    {
        if (bytes[i - 1] == 0xff && bytes[i] == 0x00)
        {
            [result appendBytes:bytes + chunkStart length:i - chunkStart];
            chunkStart = i + 1;
        }
    }
    if (chunkStart < length)
        [result appendBytes:bytes + chunkStart length:length - chunkStart];
    return result;
}

+ (uint32_t)syncsafeInteger:(const uint8_t *)bytes
{
    return ((uint32_t)(bytes[0] & 0x7f) << 21) | ((uint32_t)(bytes[1] & 0x7f) << 14) | ((uint32_t)(bytes[2] & 0x7f) << 7) | (uint32_t)(bytes[3] & 0x7f);
}

+ (uint32_t)bigEndianInteger:(const uint8_t *)bytes
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

@end
