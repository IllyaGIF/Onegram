#import "OGMediaFetchDescriptor+Telegraph.h"

#import <CommonCrypto/CommonDigest.h>
#import <sys/sysctl.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TL/TLMetaScheme.h"
#import "TGAppDelegate.h"
#import "TGPreparedLocalDocumentMessage.h"
#import "TGTelegraph.h"
#import "TGNetworkTypeManager.h"
#import "../OnegramPlatform/OGPlatformMedia.h"

static NSDictionary *OGMediaEncryptedFileArguments(NSString *url, NSData **encryptionKey, NSData **encryptionIv)
{
    NSString *prefix = @"mt-encrypted-file://?";
    if (![url hasPrefix:prefix])
        return nil;
    NSString *query = [url substringFromIndex:prefix.length];
    if ([query hasSuffix:@"+download"])
        query = [query substringToIndex:query.length - @"+download".length];
    NSDictionary *arguments = [TGStringUtils argumentDictionaryInUrlString:query];
    NSData *key = [arguments[@"key"] dataByDecodingHexString];
    if (key.length != 64 || arguments[@"id"] == nil || arguments[@"accessHash"] == nil || arguments[@"dc"] == nil)
        return nil;

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(key.bytes, 64, digest);
    int32_t digestHigh = 0;
    int32_t digestLow = 0;
    memcpy(&digestHigh, digest, 4);
    memcpy(&digestLow, digest + 4, 4);
    if (arguments[@"fingerprint"] != nil && [arguments[@"fingerprint"] intValue] != (digestHigh ^ digestLow))
        return nil;

    *encryptionKey = [key subdataWithRange:NSMakeRange(0, 32)];
    *encryptionIv = [key subdataWithRange:NSMakeRange(32, 32)];
    return arguments;
}

@implementation OGMediaFetchDescriptor (Telegraph)

+ (NSString *)storeDirectoryForDocument:(TGDocumentMediaAttachment *)document
{
    if (document.documentId != 0)
        return [TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:document.documentId version:document.version];
    return [TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:document.localDocumentId version:document.version];
}

+ (instancetype)descriptorForDocument:(TGDocumentMediaAttachment *)document publishPath:(NSString **)publishPath
{
    if (document == nil)
        return nil;

    OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
    descriptor.size = document.size;
    descriptor.decryptedSize = document.size;

    if (document.documentUri.length != 0)
    {
        NSData *encryptionKey = nil;
        NSData *encryptionIv = nil;
        NSDictionary *arguments = OGMediaEncryptedFileArguments(document.documentUri, &encryptionKey, &encryptionIv);
        if (arguments == nil)
            return nil;
        TLInputFileLocation$inputEncryptedFileLocation *location = [[TLInputFileLocation$inputEncryptedFileLocation alloc] init];
        location.n_id = [arguments[@"id"] longLongValue];
        location.access_hash = [arguments[@"accessHash"] longLongValue];
        descriptor.location = location;
        descriptor.datacenterId = [arguments[@"dc"] intValue];
        descriptor.size = [arguments[@"size"] longLongValue];
        descriptor.decryptedSize = [arguments[@"decryptedSize"] longLongValue];
        descriptor.encryptionKey = encryptionKey;
        descriptor.encryptionIv = encryptionIv;
    }
    else
    {
        if (document.documentId == 0 || document.datacenterId == 0)
            return nil;
        TLInputFileLocation$inputDocumentFileLocation *location = [[TLInputFileLocation$inputDocumentFileLocation alloc] init];
        location.n_id = document.documentId;
        location.access_hash = document.accessHash;
        location.file_reference = [document.originInfo fileReference] ?: [NSData data];
        descriptor.location = location;
        descriptor.datacenterId = document.datacenterId;
        descriptor.originInfo = document.originInfo;
    }

    descriptor.mediaTypeTag = TGNetworkMediaTypeTagDocument;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            descriptor.mediaTypeTag = TGNetworkMediaTypeTagAudio;
            break;
        }
    }
    descriptor.identifier = document.documentId;

    NSString *directory = [self storeDirectoryForDocument:document];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:NULL];
    NSString *storeFilePath = [directory stringByAppendingPathComponent:document.safeFileName];
    descriptor.storePath = [storeFilePath stringByAppendingString:@".parts"];
    if (publishPath != NULL)
        *publishPath = storeFilePath;
    return descriptor;
}

+ (instancetype)descriptorForVideoUrl:(NSString *)url originInfo:(TGMediaOriginInfo *)originInfo publishPath:(NSString **)publishPath
{
    OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
    int64_t videoId = 0;

    if ([url hasPrefix:@"mt-encrypted-file://"])
    {
        NSData *encryptionKey = nil;
        NSData *encryptionIv = nil;
        NSDictionary *arguments = OGMediaEncryptedFileArguments(url, &encryptionKey, &encryptionIv);
        if (arguments == nil || [arguments[@"size"] longLongValue] <= 0)
            return nil;
        videoId = [arguments[@"id"] longLongValue];
        TLInputFileLocation$inputEncryptedFileLocation *location = [[TLInputFileLocation$inputEncryptedFileLocation alloc] init];
        location.n_id = videoId;
        location.access_hash = [arguments[@"accessHash"] longLongValue];
        descriptor.location = location;
        descriptor.datacenterId = [arguments[@"dc"] intValue];
        descriptor.size = [arguments[@"size"] longLongValue];
        descriptor.decryptedSize = [arguments[@"decryptedSize"] longLongValue];
        descriptor.encryptionKey = encryptionKey;
        descriptor.encryptionIv = encryptionIv;
    }
    else if ([url hasPrefix:@"video:"])
    {
        NSArray *components = [url componentsSeparatedByString:@":"];
        if (components.count < 5 || [components[4] longLongValue] <= 0)
            return nil;
        videoId = [components[1] longLongValue];
        TLInputFileLocation$inputDocumentFileLocation *location = [[TLInputFileLocation$inputDocumentFileLocation alloc] init];
        location.n_id = videoId;
        location.access_hash = [components[2] longLongValue];
        NSData *fileReference = [originInfo fileReferenceForDocumentId:location.n_id accessHash:location.access_hash];
        location.file_reference = fileReference.length != 0 ? fileReference : ([originInfo fileReference] ?: [NSData data]);
        descriptor.location = location;
        descriptor.datacenterId = [components[3] intValue];
        descriptor.size = [components[4] longLongValue];
        descriptor.originInfo = originInfo;
    }
    else
        return nil;

    descriptor.mediaTypeTag = TGNetworkMediaTypeTagVideo;
    descriptor.identifier = videoId;

    NSString *videosPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"video"];
    [[NSFileManager defaultManager] createDirectoryAtPath:videosPath withIntermediateDirectories:true attributes:nil error:NULL];
    descriptor.storePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.part", videoId]];
    if (publishPath != NULL)
        *publishPath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", videoId]];
    return descriptor;
}

+ (instancetype)descriptorForVideoAttachment:(TGVideoMediaAttachment *)video publishPath:(NSString **)publishPath
{
    NSString *url = [video.videoInfo urlWithQuality:1 actualQuality:NULL actualSize:NULL];
    if (url.length == 0)
        return nil;
    return [self descriptorForVideoUrl:url originInfo:video.originInfo publishPath:publishPath];
}

+ (int)maximumDecodableShortSide
{
    static int maximum = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        char machine[64];
        size_t length = sizeof(machine);
        memset(machine, 0, sizeof(machine));
        NSString *model = sysctlbyname("hw.machine", machine, &length, NULL, 0) == 0 ? [[NSString alloc] initWithUTF8String:machine] : @"";
        if ([model isEqualToString:@"iPhone1,1"] || [model isEqualToString:@"iPhone1,2"] || [model isEqualToString:@"iPod1,1"] || [model isEqualToString:@"iPod2,1"])
            maximum = 320;
        else if ([model isEqualToString:@"iPhone2,1"] || [model isEqualToString:@"iPod3,1"])
            maximum = 480;
        else if ([model hasPrefix:@"iPhone3,"] || [model isEqualToString:@"iPod4,1"] || [model isEqualToString:@"iPad1,1"])
            maximum = 720;
        else
            maximum = INT_MAX;
    });
    return maximum;
}

+ (int)preferredShortSideForNetwork
{
    switch (TGTelegraphInstance.networkTypeManager.networkType)
    {
        case TGNetworkTypeGPRS:
        case TGNetworkTypeEdge:
            return 0;
        case TGNetworkType3G:
            return 480;
        default:
            return INT_MAX;
    }
}

+ (bool)isDecodableVideoCodec:(NSString *)codec
{
    if (codec.length == 0)
        return true;
    NSString *normalized = [codec lowercaseString];
    if ([normalized isEqualToString:@"h264"] || [normalized isEqualToString:@"avc"] || [normalized hasPrefix:@"avc1"])
        return true;
    if ([normalized isEqualToString:@"h265"] || [normalized isEqualToString:@"hevc"] || [normalized hasPrefix:@"hvc1"] || [normalized hasPrefix:@"hev1"])
        return OGPlatformHEVCHardwareDecodeAvailable();
    return false;
}

+ (NSString *)originalCodecOfVideoAttachment:(TGVideoMediaAttachment *)video
{
    __block NSString *originalCodec = nil;
    [video.videoInfo enumerateVideos:^(int quality, __unused NSString *url, __unused int size, NSString *codec)
    {
        if (quality == 1)
            originalCodec = codec;
    }];
    return originalCodec;
}

+ (bool)isDecodableOriginalOfVideoAttachment:(TGVideoMediaAttachment *)video
{
    return [self isDecodableVideoCodec:[self originalCodecOfVideoAttachment:video]];
}

+ (instancetype)descriptorForStreamingVideoAttachment:(TGVideoMediaAttachment *)video publishPath:(NSString **)publishPath
{
    NSString *mainUrl = [video.videoInfo urlWithQuality:1 actualQuality:NULL actualSize:NULL];
    if (mainUrl.length == 0)
        return nil;
    bool mainDecodable = [self isDecodableOriginalOfVideoAttachment:video];
    int mainShortSide = (int)MIN(video.dimensions.width, video.dimensions.height);
    int limit = MIN([self maximumDecodableShortSide], [self preferredShortSideForNetwork]);

    __block NSString *bestUrl = nil;
    __block int bestShortSide = -1;
    __block NSString *smallestUrl = mainDecodable ? mainUrl : nil;
    __block int smallestShortSide = mainDecodable && mainShortSide > 0 ? mainShortSide : INT_MAX;
    void (^consider)(NSString *, int) = ^(NSString *url, int shortSide)
    {
        if (url.length == 0 || shortSide <= 0)
            return;
        if (shortSide <= limit && shortSide > bestShortSide)
        {
            bestShortSide = shortSide;
            bestUrl = url;
        }
        if (shortSide < smallestShortSide)
        {
            smallestShortSide = shortSide;
            smallestUrl = url;
        }
    };
    if (mainDecodable)
        consider(mainUrl, mainShortSide);
    [video.videoInfo enumerateVideos:^(int quality, NSString *url, __unused int size, NSString *codec)
    {
        if (quality > TGVideoInfoAlternativeQualityBase && [self isDecodableVideoCodec:codec])
            consider(url, quality - TGVideoInfoAlternativeQualityBase);
    }];

    NSString *url = bestUrl != nil ? bestUrl : smallestUrl;
    if (url == nil || (mainDecodable && mainShortSide <= 0 && bestUrl == nil && limit == INT_MAX))
        url = mainUrl;
    return [self descriptorForVideoUrl:url originInfo:video.originInfo publishPath:publishPath];
}

+ (NSString *)streamMimeTypeForDocument:(TGDocumentMediaAttachment *)document pathExtension:(NSString **)pathExtension
{
    NSString *extension = [[document.fileName pathExtension] lowercaseString];
    NSString *mimeType = [document.mimeType lowercaseString];
    static NSDictionary *types = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        types = @{@"mp4": @"video/mp4", @"m4v": @"video/x-m4v", @"mov": @"video/quicktime", @"3gp": @"video/3gpp", @"m4a": @"audio/mp4", @"mp3": @"audio/mpeg", @"aac": @"audio/aac", @"wav": @"audio/wav", @"caf": @"audio/x-caf", @"aif": @"audio/aiff", @"aiff": @"audio/aiff", @"ogg": @"audio/ogg", @"oga": @"audio/ogg", @"opus": @"audio/ogg", @"flac": @"audio/flac"};
    });
    if (extension.length == 0 || types[extension] == nil)
    {
        bool isVideo = [mimeType hasPrefix:@"video/"];
        for (id attribute in document.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]])
                isVideo = true;
        }
        if ([mimeType isEqualToString:@"audio/mpeg"] || [mimeType isEqualToString:@"audio/mp3"])
            extension = @"mp3";
        else if ([mimeType isEqualToString:@"audio/ogg"] || [mimeType isEqualToString:@"audio/opus"])
            extension = @"ogg";
        else if ([mimeType isEqualToString:@"audio/flac"] || [mimeType isEqualToString:@"audio/x-flac"])
            extension = @"flac";
        else if ([mimeType hasPrefix:@"audio/"])
            extension = @"m4a";
        else if (isVideo)
            extension = [mimeType isEqualToString:@"video/quicktime"] ? @"mov" : @"mp4";
        else
            return nil;
    }
    if (pathExtension != NULL)
        *pathExtension = extension;
    return types[extension];
}

+ (bool)isStreamableVideoAttachment:(TGVideoMediaAttachment *)video
{
    NSString *url = [video.videoInfo urlWithQuality:1 actualQuality:NULL actualSize:NULL];
    if ([url hasPrefix:@"video:"])
    {
        NSArray *components = [url componentsSeparatedByString:@":"];
        return components.count >= 5 && [components[4] longLongValue] > 0;
    }
    return [url hasPrefix:@"mt-encrypted-file://"];
}

+ (bool)isStreamableDocument:(TGDocumentMediaAttachment *)document
{
    if (document == nil || document.size <= 0)
        return false;
    if (document.documentUri.length == 0 && (document.documentId == 0 || document.datacenterId == 0))
        return false;
    return [self streamMimeTypeForDocument:document pathExtension:NULL] != nil;
}

@end
