#import "TGStickerCreationSignals.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#endif
#import <dlfcn.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRpcError.h"

#import "TGTLDynamic.h"
#import "TGUploadFileSignals.h"
#import "TGStickersSignals.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGMediaOriginInfo+Telegraph.h"
#import "TGWebPEncoder.h"

#import "TL/TLMetaScheme.h"

static const CGFloat TGStickerCreationSide = 512.0f;
static const size_t TGStickerCreationMaxFileSize = 512 * 1024 - 1024;
static const int32_t TGStickerCreationPacksPageLimit = 100;

@protocol TGStickerCreationVisionRequestHandler <NSObject>

- (instancetype)initWithCGImage:(CGImageRef)image options:(NSDictionary *)options;
- (BOOL)performRequests:(NSArray *)requests error:(NSError **)error;

@end

@protocol TGStickerCreationVisionRequest <NSObject>

- (NSArray *)results;

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
@protocol TGStickerCreationVisionInstanceMaskObservation <NSObject>

- (NSIndexSet *)allInstances;
- (CVPixelBufferRef)generateMaskedImageOfInstances:(NSIndexSet *)instances fromRequestHandler:(id)requestHandler croppedToInstancesExtent:(BOOL)croppedToInstancesExtent error:(NSError **)error;

@end
#endif

@interface TGStickerCreationPack ()

- (instancetype)initWithPackId:(int64_t)packId accessHash:(int64_t)accessHash title:(NSString *)title shortName:(NSString *)shortName count:(int32_t)count;

@end

@implementation TGStickerCreationPack

- (instancetype)initWithPackId:(int64_t)packId accessHash:(int64_t)accessHash title:(NSString *)title shortName:(NSString *)shortName count:(int32_t)count
{
    self = [super init];
    if (self != nil)
    {
        _packId = packId;
        _accessHash = accessHash;
        _title = [title copy] ?: @"";
        _shortName = [shortName copy] ?: @"";
        _count = count;
    }
    return self;
}

@end

@implementation TGStickerCreationSignals

+ (Class)visionClassNamed:(NSString *)name
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (NSClassFromString(@"VNImageRequestHandler") == nil)
            dlopen("/System/Library/Frameworks/Vision.framework/Vision", RTLD_LAZY);
    });
    return NSClassFromString(name);
}

+ (bool)canRemoveBackground
{
    if (iosMajorVersion() < 17)
        return false;
    return [self visionClassNamed:@"VNGenerateForegroundInstanceMaskRequest"] != nil && [self visionClassNamed:@"VNImageRequestHandler"] != nil;
}

+ (UIImage *)normalizedImage:(UIImage *)image maxSide:(CGFloat)maxSide
{
    CGSize size = image.size;
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGFloat scale = MIN(1.0f, maxSide / MAX(size.width, size.height));
    CGSize targetSize = CGSizeMake(MAX(1.0f, (CGFloat)round(size.width * scale)), MAX(1.0f, (CGFloat)round(size.height * scale)));
    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0f);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (UIImage *)foregroundImageSyncFromImage:(UIImage *)image error:(NSError **)error
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    Class requestClass = [self visionClassNamed:@"VNGenerateForegroundInstanceMaskRequest"];
    Class handlerClass = [self visionClassNamed:@"VNImageRequestHandler"];
    UIImage *sourceImage = [self normalizedImage:image maxSide:2048.0f];
    if (requestClass == nil || handlerClass == nil || sourceImage.CGImage == NULL)
        return nil;

    id<TGStickerCreationVisionRequest> request = [[requestClass alloc] init];
    id<TGStickerCreationVisionRequestHandler> handler = [[handlerClass alloc] initWithCGImage:sourceImage.CGImage options:@{}];
    if (request == nil || handler == nil || ![handler performRequests:@[request] error:error])
        return nil;

    id<TGStickerCreationVisionInstanceMaskObservation> observation = [request results].firstObject;
    if (observation == nil || ![observation respondsToSelector:@selector(generateMaskedImageOfInstances:fromRequestHandler:croppedToInstancesExtent:error:)])
        return nil;
    NSIndexSet *instances = [observation allInstances];
    if (instances.count == 0)
        return nil;

    CVPixelBufferRef pixelBuffer = [observation generateMaskedImageOfInstances:instances fromRequestHandler:handler croppedToInstancesExtent:true error:error];
    if (pixelBuffer == NULL)
        return nil;

    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    if (cgImage == NULL)
        return nil;
    UIImage *result = [[UIImage alloc] initWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return result;
#else
    return nil;
#endif
}

+ (SSignal *)foregroundImageFromImage:(UIImage *)image
{
    if (image == nil || ![self canRemoveBackground])
        return [SSignal fail:nil];

    return [[SSignal defer:^SSignal *
    {
        NSError *error = nil;
        UIImage *result = nil;
        @autoreleasepool
        {
            result = [self foregroundImageSyncFromImage:image error:&error];
        }
        if (result == nil)
        {
            TGLog(@"Sticker background removal failed: %@", error);
            return [SSignal fail:error];
        }
        return [SSignal single:result];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

+ (UIImage *)stickerImageFromImage:(UIImage *)image
{
    CGSize size = image.size;
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGFloat scale = TGStickerCreationSide / MAX(size.width, size.height);
    CGSize targetSize = CGSizeMake(MIN(TGStickerCreationSide, MAX(1.0f, (CGFloat)round(size.width * scale))), MIN(TGStickerCreationSide, MAX(1.0f, (CGFloat)round(size.height * scale))));
    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0f);
    CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationHigh);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (NSData *)webpDataForStickerImage:(UIImage *)image
{
    CGImageRef cgImage = image.CGImage;
    if (cgImage == NULL)
        return nil;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0)
        return nil;

    size_t stride = width * 4;
    uint8_t *pixels = (uint8_t *)calloc(stride * height, 1);
    if (pixels == NULL)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        free(pixels);
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), cgImage);
    CGContextRelease(context);

    for (size_t i = 0; i < stride * height; i += 4)
    {
        uint32_t alpha = pixels[i + 3];
        if (alpha == 0)
        {
            pixels[i] = pixels[i + 1] = pixels[i + 2] = 0;
        }
        else if (alpha != 255)
        {
            for (size_t c = 0; c < 3; c++)
            {
                uint32_t value = (pixels[i + c] * 255 + alpha / 2) / alpha;
                pixels[i + c] = (uint8_t)MIN(value, 255u);
            }
        }
    }

    size_t size = 0;
    uint8_t *encoded = TGWebPEncodeRGBAWithSizeLimit(pixels, (int)width, (int)height, (int)stride, TGStickerCreationMaxFileSize, &size);
    free(pixels);
    if (encoded == NULL)
        return nil;
    return [[NSData alloc] initWithBytesNoCopy:encoded length:size freeWhenDone:true];
}

+ (SSignal *)stickerDataFromImage:(UIImage *)image
{
    if (image == nil)
        return [SSignal fail:nil];

    return [[SSignal defer:^SSignal *
    {
        NSData *data = nil;
        @autoreleasepool
        {
            data = [self webpDataForStickerImage:image];
        }
        if (data.length == 0 || data.length > TGStickerCreationMaxFileSize)
            return [SSignal fail:nil];
        return [SSignal single:data];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

+ (NSString *)normalizedEmoji:(NSString *)emoji
{
    NSString *result = [emoji stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return result.length != 0 ? result : @"\U0001F642";
}

+ (SSignal *)uploadStickerData:(NSData *)data size:(CGSize)size emoji:(NSString *)emoji
{
    NSString *alt = [self normalizedEmoji:emoji];
    return [[TGUploadFileSignals uploadedFileWithData:data mediaTypeTag:TGNetworkMediaTypeTagDocument] mapToSignal:^SSignal *(id inputFile)
    {
        if (inputFile == nil)
            return [SSignal fail:nil];

        NSArray *attributes = @[
            [TGTLDynamicObject objectWithConstructor:@"documentAttributeImageSize" fields:@{@"w": @((int32_t)size.width), @"h": @((int32_t)size.height)}],
            [TGTLDynamicObject objectWithConstructor:@"documentAttributeSticker" fields:@{@"alt": alt, @"stickerset": [TGTLDynamicObject objectWithConstructor:@"inputStickerSetEmpty" fields:@{}]}],
            [TGTLDynamicObject objectWithConstructor:@"documentAttributeFilename" fields:@{@"file_name": @"sticker.webp"}]
        ];
        TGTLDynamicObject *media = [TGTLDynamicObject objectWithConstructor:@"inputMediaUploadedDocument" fields:@{@"file": inputFile, @"mime_type": @"image/webp", @"attributes": attributes}];
        TGTLDynamicObject *peer = [TGTLDynamicObject objectWithConstructor:@"inputPeerSelf" fields:@{}];

        return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.uploadMedia" parameters:@{@"peer": peer, @"media": media}] mapToSignal:^SSignal *(id result)
        {
            TLDocument *document = nil;
            if ([result isKindOfClass:[TGTLDynamicObject class]])
                document = [(TGTLDynamicObject *)result field:@"document"];
            if (![document isKindOfClass:[TLDocument$document class]])
                return [SSignal fail:nil];

            TGDocumentMediaAttachment *attachment = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:document];
            attachment.originInfo = [TGMediaOriginInfo mediaOriginInfoForDocument:document];
            return [SSignal single:attachment];
        }];
    }];
}

+ (TGTLDynamicObject *)inputDocumentForDocument:(TGDocumentMediaAttachment *)document
{
    NSData *fileReference = [document.originInfo fileReferenceForDocumentId:document.documentId accessHash:document.accessHash] ?: document.originInfo.fileReference;
    return [TGTLDynamicObject objectWithConstructor:@"inputDocument" fields:@{@"id": @(document.documentId), @"access_hash": @(document.accessHash), @"file_reference": fileReference ?: [NSData data]}];
}

+ (TGTLDynamicObject *)inputStickerSetItemForDocument:(TGDocumentMediaAttachment *)document emoji:(NSString *)emoji
{
    return [TGTLDynamicObject objectWithConstructor:@"inputStickerSetItem" fields:@{@"document": [self inputDocumentForDocument:document], @"emoji": [self normalizedEmoji:emoji]}];
}

+ (SSignal *)myStickerPacksWithOffsetId:(int64_t)offsetId collected:(NSArray *)collected
{
    return [[TGTLDynamicRpc requestSignalWithMethod:@"messages.getMyStickers" parameters:@{@"offset_id": @(offsetId), @"limit": @(TGStickerCreationPacksPageLimit)}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]])
            return [SSignal fail:nil];

        NSMutableArray *packs = [[NSMutableArray alloc] initWithArray:collected];
        NSArray *sets = [result arrayField:@"sets"];
        int64_t lastId = 0;
        for (TGTLDynamicObject *covered in sets)
        {
            if (![covered isKindOfClass:[TGTLDynamicObject class]])
                continue;
            TGTLDynamicObject *set = [covered objectField:@"set"];
            if (set == nil)
                continue;
            lastId = [set int64Field:@"id"];
            if ([set flag:@"masks"] || [set flag:@"emojis"])
                continue;
            [packs addObject:[[TGStickerCreationPack alloc] initWithPackId:lastId accessHash:[set int64Field:@"access_hash"] title:[set stringField:@"title"] shortName:[set stringField:@"short_name"] count:[set int32Field:@"count"]]];
        }

        int32_t totalCount = [result int32Field:@"count"];
        bool hasMore = sets.count == (NSUInteger)TGStickerCreationPacksPageLimit && lastId != 0 && (NSInteger)(collected.count + sets.count) < (NSInteger)totalCount;
        if (hasMore)
            return [self myStickerPacksWithOffsetId:lastId collected:packs];
        return [SSignal single:packs];
    }];
}

+ (SSignal *)myStickerPacks
{
    return [self myStickerPacksWithOffsetId:0 collected:@[]];
}

+ (SSignal *)addSticker:(TGDocumentMediaAttachment *)document emoji:(NSString *)emoji toPack:(TGStickerCreationPack *)pack
{
    if (document == nil || pack == nil)
        return [SSignal fail:nil];

    TGTLDynamicObject *stickerSet = [TGTLDynamicObject objectWithConstructor:@"inputStickerSetID" fields:@{@"id": @(pack.packId), @"access_hash": @(pack.accessHash)}];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stickers.addStickerToSet" parameters:@{@"stickerset": stickerSet, @"sticker": [self inputStickerSetItemForDocument:document emoji:emoji]}] onNext:^(__unused id next)
    {
        [TGStickersSignals forceUpdateStickers];
    }];
}

+ (SSignal *)suggestShortNameForTitle:(NSString *)title
{
    if (title.length == 0)
        return [SSignal single:@""];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stickers.suggestShortName" parameters:@{@"title": title}] map:^id(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]])
            return @"";
        return [result stringField:@"short_name"] ?: @"";
    }];
}

+ (SSignal *)checkShortName:(NSString *)shortName
{
    if (shortName.length == 0)
        return [SSignal single:@false];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stickers.checkShortName" parameters:@{@"short_name": shortName}] map:^id(id result)
    {
        return @([result respondsToSelector:@selector(boolValue)] && [result boolValue]);
    }];
}

+ (SSignal *)createPackWithTitle:(NSString *)title shortName:(NSString *)shortName sticker:(TGDocumentMediaAttachment *)document emoji:(NSString *)emoji
{
    if (document == nil || title.length == 0 || shortName.length == 0)
        return [SSignal fail:nil];

    NSDictionary *parameters = @{
        @"user_id": [TGTLDynamicObject objectWithConstructor:@"inputUserSelf" fields:@{}],
        @"title": title,
        @"short_name": shortName,
        @"stickers": @[[self inputStickerSetItemForDocument:document emoji:emoji]],
        @"software": @"Onegram"
    };
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stickers.createStickerSet" parameters:parameters] onNext:^(__unused id next)
    {
        [TGStickersSignals forceUpdateStickers];
    }];
}

+ (NSString *)errorTypeForError:(id)error
{
    if ([error isKindOfClass:[MTRpcError class]])
        return ((MTRpcError *)error).errorDescription;
    return nil;
}

@end
