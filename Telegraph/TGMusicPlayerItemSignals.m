#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGMusicPlayerItemSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGPreparedLocalDocumentMessage.h"

#import "TGDownloadManager.h"
#import "TGVideoDownloadActor.h"
#import "TGSharedFileSignals.h"
#import "TGSharedMediaUtils.h"
#import "TGMusicUtils.h"

#import "TGBotContextResult.h"
#import "TGBotContextExternalResult.h"
#import "TGBotContextMediaResult.h"

#import "TGMediaStoreContext.h"

#import "TL/TLMetaScheme.h"

#import "TGTelegramNetworking.h"
#import "TGTLDynamic.h"
#import "TGDatabase.h"

#import "TGAudioMediaAttachment+Telegraph.h"

static TLInputFileLocation$inputDocumentFileLocation *fileLocationForDocument(TGDocumentMediaAttachment *document) {
    TLInputFileLocation$inputDocumentFileLocation *location = [[TLInputFileLocation$inputDocumentFileLocation alloc] init];
    location.n_id = document.documentId;
    location.access_hash = document.accessHash;
    return location;
}

NSString *cacheKeyForDocument(TGDocumentMediaAttachment *document) {
    TLInputFileLocation$inputDocumentFileLocation *location = fileLocationForDocument(document);
    return [[NSString alloc] initWithFormat:@"inputDocumentFileLocation-%lld", location.n_id];
}

TGMusicPlayerItemAvailability TGMusicPlayerItemAvailabilityUnpack(int64_t value)
{
    TGMusicPlayerItemAvailability result;
    result.downloaded = value & 1;
    result.downloading = value & 2;
    int32_t progress = (value >> 32) & 0xffffffff;
    Float32 floatProgress = 0;
    memcpy(&floatProgress, &progress, 4);
    result.progress = floatProgress;
    
    return result;
}

static int64_t TGMusicPlayerItemAvailabilityPack(TGMusicPlayerItemAvailability value)
{
    int64_t result = 0;
    if (value.downloaded)
        result |= 1;
    if (value.downloading)
        result |= 2;
    Float32 floatProgress = (Float32)value.progress;
    int32_t progress = 0;
    memcpy(&progress, &floatProgress, 4);
    result |= (((int64_t)progress) << 32);
    
    return result;
}

@interface TGMusicPlayerItemDownloadHelper : NSObject <ASWatcher>
{
    TGMusicPlayerItem *_item;
    void (^_updated)(TGMusicPlayerItemAvailability);
    
    TGMediaId *_mediaId;
    NSString *_downloadPath;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGMusicPlayerItemDownloadHelper

- (TGMediaId *)mediaIdForItem:(TGMusicPlayerItem *)item
{
    if ([item.media isKindOfClass:[TGDocumentMediaAttachment class]]) {
        TGDocumentMediaAttachment *document = item.media;
        if (document.documentId != 0)
            return [[TGMediaId alloc] initWithType:3 itemId:document.documentId];
        else if (document.localDocumentId != 0 && document.documentUri.length != 0)
            return [[TGMediaId alloc] initWithType:3 itemId:document.localDocumentId];
    } else if ([item.media isKindOfClass:[TGAudioMediaAttachment class]]) {
        TGAudioMediaAttachment *audio = item.media;
        return [[TGMediaId alloc] initWithType:4 itemId:audio.audioId != 0 ? audio.audioId : audio.localAudioId];
    } else if ([item.media isKindOfClass:[TGVideoMediaAttachment class]]) {
        TGVideoMediaAttachment *video = item.media;
        return [[TGMediaId alloc] initWithType:1 itemId:video.videoId != 0 ? video.videoId : video.localVideoId];
    }
    return nil;
}

- (instancetype)initWithItem:(TGMusicPlayerItem *)item priority:(bool)priority updated:(void (^)(TGMusicPlayerItemAvailability))updated
{
    self = [super init];
    if (self != nil)
    {
        _item = item;
        _updated = [updated copy];
        _mediaId = [self mediaIdForItem:_item];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        
        [ActionStageInstance() watchForPaths:@[
            @"downloadManagerStateChanged"
        ] watcher:self];
        
        if (_mediaId != nil && [(NSNumber *)_item.key intValue] != 0) {
            [[TGDownloadManager instance] requestState:self.actionHandle];
            [self requestDownloadItem:priority];
        } else {
            if ([item.media isKindOfClass:[TGBotContextExternalResult class]]) {
                TGBotContextExternalResult *externalResult = item.media;
                _downloadPath = [[NSString alloc] initWithFormat:@"/temporaryDownload/(%@,%@)", [TGStringUtils stringByEscapingForActorURL:externalResult.originalUrl], @"path"];
                [ActionStageInstance() requestActor:_downloadPath options:@{@"url": externalResult.originalUrl, @"cache": [[TGMediaStoreContext instance] temporaryFilesCache], @"returnPath": @true, @"mediaTypeTag": @(TGNetworkMediaTypeTagAudio)} flags:0 watcher:self];
            } else if ([item.media isKindOfClass:[TGBotContextMediaResult class]]) {
                TGBotContextMediaResult *mediaResult = item.media;
                if (mediaResult.document != nil) {
                    _downloadPath = [[NSString alloc] initWithFormat:@"/temporaryDownload/(%@,%@)", [TGStringUtils stringByEscapingForActorURL:cacheKeyForDocument(mediaResult.document)], @"path"];
                    [ActionStageInstance() requestActor:_downloadPath options:@{@"cacheKey": [cacheKeyForDocument(mediaResult.document) dataUsingEncoding:NSUTF8StringEncoding], @"cache": [[TGMediaStoreContext instance] temporaryFilesCache], @"returnPath": @true, @"inputLocation": fileLocationForDocument(mediaResult.document), @"datacenterId": @(mediaResult.document.datacenterId), @"size": @(mediaResult.document.size), @"mediaTypeTag": @(TGNetworkMediaTypeTagAudio)} flags:0 watcher:self];
                }
            } else if ([item.media isKindOfClass:[TGDocumentMediaAttachment class]]) {
                TGDocumentMediaAttachment *document = ((TGDocumentMediaAttachment *)item.media);
                _downloadPath = [[NSString alloc] initWithFormat:@"/temporaryDownload/(%@,%@)", [TGStringUtils stringByEscapingForActorURL:cacheKeyForDocument(document)], @"path"];
                [ActionStageInstance() requestActor:_downloadPath options:@{@"cacheKey": [cacheKeyForDocument(document) dataUsingEncoding:NSUTF8StringEncoding], @"cache": [[TGMediaStoreContext instance] temporaryFilesCache], @"returnPath": @true, @"inputLocation": fileLocationForDocument(document), @"datacenterId": @(document.datacenterId), @"size": @(document.size), @"mediaTypeTag": @(TGNetworkMediaTypeTagAudio)} flags:0 watcher:self];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    [[TGDownloadManager instance] cancelItem:_mediaId];
}

- (void)requestDownloadItem:(bool)priority
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([_item.media isKindOfClass:[TGDocumentMediaAttachment class]]) {
            TGDocumentMediaAttachment *documentAttachment = _item.media;
            if (documentAttachment.documentId != 0 || documentAttachment.documentUri.length != 0)
            {
                id mediaId = [[TGMediaId alloc] initWithType:3 itemId:documentAttachment.documentId != 0 ? documentAttachment.documentId : documentAttachment.localDocumentId];
                [[TGDownloadManager instance] requestItem:[NSString stringWithFormat:@"/tg/media/document/(%d:%" PRId64 ":%@)", documentAttachment.datacenterId, documentAttachment.documentId, documentAttachment.documentUri.length != 0 ? documentAttachment.documentUri : @""] options:[[NSDictionary alloc] initWithObjectsAndKeys:documentAttachment, @"documentAttachment", nil] changePriority:priority messageId:[(NSNumber *)_item.key intValue] itemId:mediaId groupId:[_item conversationId] itemClass:TGDownloadItemClassDocument];
            }
        } else if ([_item.media isKindOfClass:[TGAudioMediaAttachment class]]) {
            TGAudioMediaAttachment *audio = _item.media;
            if (audio.audioId != 0 || audio.audioUri.length != 0) {
                id mediaId = [[TGMediaId alloc] initWithType:4 itemId:audio.audioId != 0 ? audio.audioId : audio.localAudioId];
                
                [[TGDownloadManager instance] requestItem:[NSString stringWithFormat:@"/tg/media/audio/(%" PRId32 ":%" PRId64 ":%@)", audio.datacenterId, audio.audioId, audio.audioUri.length != 0 ? audio.audioUri : @""] options:[[NSDictionary alloc] initWithObjectsAndKeys:audio, @"audioAttachment", nil] changePriority:priority messageId:[(NSNumber *)_item.key intValue] itemId:mediaId groupId:[_item conversationId] itemClass:TGDownloadItemClassAudio];
            }
        } else if ([_item.media isKindOfClass:[TGVideoMediaAttachment class]]) {
            TGVideoMediaAttachment *video = _item.media;
            if (video.videoId != 0) {
                id mediaId = [[TGMediaId alloc] initWithType:1 itemId:video.videoId];
            
                NSString *videoUri = [video.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:NULL];
                if (videoUri != nil)
                {
                    [[TGDownloadManager instance] requestItem:[NSString stringWithFormat:@"/as/media/video/(%@)", videoUri] options:[[NSDictionary alloc] initWithObjectsAndKeys:video, @"videoAttachment", nil] changePriority:priority messageId:[(NSNumber *)_item.key intValue] itemId:mediaId groupId:[_item conversationId]  itemClass:TGDownloadItemClassVideo];
                }
            }
        }
    }];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"downloadManagerStateChanged"])
    {
        NSDictionary *mediaList = resource;
        [mediaList enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, TGDownloadItem *item, __unused BOOL *stop)
        {
            if ([item.itemId isEqual:_mediaId])
            {
                TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = true, .progress = (CGFloat)item.progress};
                if (_updated)
                    _updated(availability);
                if (stop)
                    *stop = true;
            }
        }];
        
        for (id mediaId in [arguments objectForKey:@"completedItemIds"])
        {
            if ([_mediaId isEqual:mediaId])
            {
                TGMusicPlayerItemAvailability availability = {.downloaded = true, .downloading = false, .progress = 1.0f};
                if (_updated)
                    _updated(availability);
            }
        }
        
        for (id mediaId in [arguments objectForKey:@"failedItemIds"])
        {
            if ([_mediaId isEqual:mediaId])
            {
                TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = false, .progress = 0.0f};
                if (_updated)
                    _updated(availability);
            }
        }
    }
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message {
    if ([messageType isEqualToString:@"progress"]) {
        if ([path isEqualToString:_downloadPath]) {
            TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = true, .progress = (CGFloat)[message floatValue]};
            if (_updated)
                _updated(availability);
        }
    }
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result {
    if ([path isEqualToString:_downloadPath]) {
        if (status == ASStatusSuccess) {
            TGMusicPlayerItemAvailability availability = {.downloaded = true, .downloading = false, .progress = 1.0f};
            if (_updated)
                _updated(availability);
        } else {
            TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = false, .progress = 0.0f};
            if (_updated)
                _updated(availability);
        }
    }
}

@end

@implementation TGMusicPlayerItemSignals

+ (NSString *)pathForItem:(TGMusicPlayerItem *)item
{
    if ([item.media isKindOfClass:[TGDocumentMediaAttachment class]]) {
        TGDocumentMediaAttachment *document = item.media;
        
        if ([(NSNumber *)item.key intValue] != 0) {            
            NSString *path = nil;
            if (document.documentId != 0)
                path = [TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:document.documentId version:document.version];
            else
            {
                path = [TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:document.localDocumentId version:document.version];
            }
            
            path = [path stringByAppendingPathComponent:[document safeFileName]];
            return path;
        } else {
            NSString *cacheKey = cacheKeyForDocument(document);
            return [[[TGMediaStoreContext instance] temporaryFilesCache] _filePathForKey:[cacheKey dataUsingEncoding:NSUTF8StringEncoding]];
        }
    } else if ([item.media isKindOfClass:[TGAudioMediaAttachment class]]) {
        TGAudioMediaAttachment *audio = item.media;
        NSString *path = nil;
        if (audio.audioId != 0)
            path = [TGAudioMediaAttachment localAudioFilePathForRemoteAudioId:audio.audioId];
        else
        {
            path = [TGAudioMediaAttachment localAudioFilePathForLocalAudioId:audio.localAudioId];
        }
        
        return path;
    } else if ([item.media isKindOfClass:[TGBotContextResult class]]) {
        TGBotContextResult *result = item.media;
        if ([result isKindOfClass:[TGBotContextMediaResult class]]) {
            TGDocumentMediaAttachment *document = ((TGBotContextMediaResult *)result).document;
            NSString *cacheKey = cacheKeyForDocument(document);
            return [[[TGMediaStoreContext instance] temporaryFilesCache] _filePathForKey:[cacheKey dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([result isKindOfClass:[TGBotContextExternalResult class]]) {
            TGBotContextExternalResult *externalResult = (TGBotContextExternalResult *)result;
            if (externalResult.originalUrl.length != 0) {
                NSString *path = [[[TGMediaStoreContext instance] temporaryFilesCache] _filePathForKey:[externalResult.originalUrl dataUsingEncoding:NSUTF8StringEncoding]];
                return path;
            }
        }
    } else if ([item.media isKindOfClass:[TGVideoMediaAttachment class]]) {
        return [TGVideoDownloadActor localPathForVideoUrl:[((TGVideoMediaAttachment *)item.media).videoInfo urlWithQuality:0 actualQuality:NULL actualSize:NULL]];
    }
    return nil;
}

+ (NSString *)pathForDocument:(TGDocumentMediaAttachment *)media messageId:(int32_t)messageId
{
    if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
        TGDocumentMediaAttachment *document = media;
        
        if (messageId != 0) {
            NSString *path = nil;
            if (document.documentId != 0)
                path = [TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:document.documentId version:document.version];
            else
            {
                path = [TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:document.localDocumentId version:document.version];
            }
            
            path = [path stringByAppendingPathComponent:[document safeFileName]];
            return path;
        } else {
            NSString *cacheKey = cacheKeyForDocument(document);
            return [[[TGMediaStoreContext instance] temporaryFilesCache] _filePathForKey:[cacheKey dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    return nil;
}

+ (SSignal *)downloadItem:(TGMusicPlayerItem *)item priority:(bool)priority
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = true, .progress = 0.0f};
        [subscriber putNext:@(TGMusicPlayerItemAvailabilityPack(availability))];
        
        TGMusicPlayerItemDownloadHelper *helper = [[TGMusicPlayerItemDownloadHelper alloc] initWithItem:item priority:priority updated:^(TGMusicPlayerItemAvailability availability)
        {
            [subscriber putNext:@(TGMusicPlayerItemAvailabilityPack(availability))];
        }];
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [helper description];
        }];
    }];
}

+ (SSignal *)itemAvailability:(TGMusicPlayerItem *)item priority:(bool)priority
{
    return [self itemAvailability:item priority:priority allowDownload:true];
}

+ (SSignal *)itemAvailability:(TGMusicPlayerItem *)item priority:(bool)priority allowDownload:(bool)allowDownload
{
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSString *path = [self pathForItem:item];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            TGMusicPlayerItemAvailability availability = {.downloaded = true, .downloading = false, .progress = 1.0f};
            [subscriber putNext:@(TGMusicPlayerItemAvailabilityPack(availability))];
        }
        else
            [subscriber putError:nil];
        return nil;
    }] catch:^SSignal *(__unused id error)
    {
        if (!allowDownload)
        {
            TGMusicPlayerItemAvailability availability = {.downloaded = false, .downloading = false, .progress = 0.0f};
            return [SSignal single:@(TGMusicPlayerItemAvailabilityPack(availability))];
        }
        return [self downloadItem:item priority:priority];
    }];
}

static NSUInteger const TGMusicAlbumArtRequestLimit = 512 * 1024;

static NSData *TGMusicAlbumArtCacheKey(TGDocumentMediaAttachment *document, bool thumbnail, bool final)
{
    NSString *key = nil;
    if (document.documentId != 0)
        key = [[NSString alloc] initWithFormat:@"musicAlbumArt-%lld", document.documentId];
    else
        key = [[NSString alloc] initWithFormat:@"musicAlbumArt-local%lld", document.localDocumentId];
    
    if (thumbnail)
        key = [key stringByAppendingString:@"-thumb"];
    if (final)
        key = [key stringByAppendingString:@"-final"];
    
    return [key dataUsingEncoding:NSUTF8StringEncoding];
}

static bool TGMusicAlbumArtFileIsComplete(TGDocumentMediaAttachment *document, NSString *path)
{
    NSDictionary *attributes = path.length == 0 ? nil : [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attributes == nil)
        return false;
    return document.size <= 0 || [attributes fileSize] >= (unsigned long long)document.size;
}

static bool TGMusicAlbumArtQueryIsValid(NSString *performer, NSString *song)
{
    NSString *normalizedPerformer = [[performer lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return normalizedPerformer.length != 0 && ![normalizedPerformer isEqualToString:@"unknown artist"] && song.length != 0;
}

+ (SSignal *)albumArtForItem:(TGMusicPlayerItem *)item thumbnail:(bool)thumbnail
{
    TGDocumentMediaAttachment *attachment = item.media;
    if (![attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        return [SSignal fail:nil];
    
    return [self albumArtForMedia:attachment path:[self pathForItem:item] performer:item.performer song:item.title thumbnail:thumbnail];
}

+ (SSignal *)albumArtForDocument:(TGDocumentMediaAttachment *)document messageId:(int32_t)messageId thumbnail:(bool)thumbnail
{
    NSString *performer = nil;
    NSString *song = nil;
    
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            TGDocumentAttributeAudio *audioAttribute = (TGDocumentAttributeAudio *)attribute;
            performer = audioAttribute.performer;
            song = audioAttribute.title;
        }
    }
    
    return [self albumArtForMedia:document path:[self pathForDocument:document messageId:messageId] performer:performer song:song thumbnail:thumbnail];
}

+ (SSignal *)albumArtForMedia:(TGDocumentMediaAttachment *)document path:(NSString *)path performer:(NSString *)performer song:(NSString *)song thumbnail:(bool)thumbnail
{
    NSData *finalKey = TGMusicAlbumArtCacheKey(document, thumbnail, true);
    NSData *remoteKey = TGMusicAlbumArtCacheKey(document, thumbnail, false);
    
    SSignal *remoteSignal = [[self _cachedAlbumArtForKey:remoteKey] catch:^SSignal *(__unused id error)
    {
        return [self _albumArt:[self _remoteAlbumArtForDocument:document performer:performer song:song thumbnail:thumbnail] storedForKey:remoteKey];
    }];
    
    return [[self _cachedAlbumArtForKey:finalKey] catch:^SSignal *(__unused id error)
    {
        if (!TGMusicAlbumArtFileIsComplete(document, path))
            return remoteSignal;
        
        SSignal *embeddedSignal = [[self _albumArtForUrl:[NSURL fileURLWithPath:path] multicastManager:nil] map:^UIImage *(UIImage *image)
        {
            return [TGMusicUtils albumArtwork:image thumbnail:thumbnail];
        }];
        return [self _albumArt:[embeddedSignal catch:^SSignal *(__unused id error)
        {
            return remoteSignal;
        }] storedForKey:finalKey];
    }];
}

+ (SSignal *)_cachedAlbumArtForKey:(NSData *)key
{
    return [[[[TGMediaStoreContext instance] temporaryFilesCache] cachedItemForKey:key] mapToSignal:^SSignal *(NSData *data)
    {
        UIImage *image = data.length == 0 ? nil : [[UIImage alloc] initWithData:data];
        return image == nil ? [SSignal fail:nil] : [SSignal single:image];
    }];
}

+ (SSignal *)_albumArt:(SSignal *)signal storedForKey:(NSData *)key
{
    return [signal onNext:^(UIImage *image)
    {
        NSData *data = UIImageJPEGRepresentation(image, 0.9f);
        if (data.length != 0)
            [[[TGMediaStoreContext instance] temporaryFilesCache] setValue:data forKey:key];
    }];
}

+ (SSignal *)_albumArtFromDataSignal:(SSignal *)signal thumbnail:(bool)thumbnail
{
    return [signal mapToSignal:^SSignal *(NSData *data)
    {
        UIImage *image = data.length == 0 ? nil : [TGMusicUtils albumArtwork:[[UIImage alloc] initWithData:data] thumbnail:thumbnail];
        return image == nil ? [SSignal fail:nil] : [SSignal single:image];
    }];
}

+ (SSignal *)_remoteAlbumArtForDocument:(TGDocumentMediaAttachment *)document performer:(NSString *)performer song:(NSString *)song thumbnail:(bool)thumbnail
{
    SSignal *documentThumbnailSignal = [[[TGSharedFileSignals fileThumbnail:document] map:^UIImage *(UIImage *image)
    {
        return [TGMusicUtils albumArtwork:image thumbnail:thumbnail];
    }] startOnThreadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool]];
    
    SSignal *webSignal = [SSignal fail:nil];
    if (!OGPlatformMediaDownloadsRequireUserAction())
    {
        webSignal = [[self _albumArtFromDataSignal:[self _telegramAlbumArtForPerformer:performer song:song thumbnail:thumbnail] thumbnail:thumbnail] catch:^SSignal *(__unused id error)
        {
            return [self _albumArtFromDataSignal:[self _iTunesAlbumArtForPerformer:performer song:song thumbnail:thumbnail] thumbnail:thumbnail];
        }];
    }
    
    CGSize documentThumbnailSize = CGSizeZero;
    [document.thumbnailInfo imageUrlForLargestSize:&documentThumbnailSize];
    bool preferDocumentThumbnail = MAX(documentThumbnailSize.width, documentThumbnailSize.height) * 2.0f >= [TGMusicUtils albumArtworkPixelSize:thumbnail].width;
    
    SSignal *fallbackSignal = preferDocumentThumbnail ? webSignal : documentThumbnailSignal;
    return [(preferDocumentThumbnail ? documentThumbnailSignal : webSignal) catch:^SSignal *(__unused id error)
    {
        return fallbackSignal;
    }];
}

+ (SSignal *)_telegramAlbumArtForPerformer:(NSString *)performer song:(NSString *)song thumbnail:(bool)thumbnail
{
    if (!TGMusicAlbumArtQueryIsValid(performer, song))
        return [SSignal fail:nil];
    
    int32_t datacenterId = 0;
    NSData *datacenterData = [TGDatabaseInstance() customProperty:@"webFileDatacenterId"];
    if (datacenterData.length == 4)
        [datacenterData getBytes:&datacenterId length:4];
    if (datacenterId <= 0)
        return [SSignal fail:nil];
    
    TGTLDynamicObject *location = [TGTLDynamicObject objectWithConstructor:@"inputWebFileAudioAlbumThumbLocation" fields:@{@"small": @(thumbnail), @"title": song, @"performer": performer}];
    return [[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:datacenterId type:TGNetworkMediaTypeTagImage] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker)
    {
        TGTLDynamicRpc *request = [[TGTLDynamicRpc alloc] initWithMethod:@"upload.getWebFile" parameters:@{@"location": location, @"offset": @0, @"limit": @(TGMusicAlbumArtRequestLimit)}];
        if (request.encodingError != nil)
            return [SSignal fail:request.encodingError];
        
        return [[[[TGTelegramNetworking instance] requestSignal:request worker:worker] filter:^bool(id next)
        {
            return ![next isKindOfClass:[NSNumber class]];
        }] mapToSignal:^SSignal *(id result)
        {
            NSData *bytes = [result isKindOfClass:[TGTLDynamicObject class]] ? [(TGTLDynamicObject *)result dataField:@"bytes"] : nil;
            return bytes.length == 0 ? [SSignal fail:nil] : [SSignal single:bytes];
        }];
    }];
}

NSString *TGURLEncodedStringFromString(NSString *string)
{
    NSStringEncoding encoding = NSUTF8StringEncoding;
    static NSString * const kAFLegalCharactersToBeEscaped = @"?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ ";
    NSString *unescapedString = [string stringByReplacingPercentEscapesUsingEncoding:encoding];
    if (unescapedString)
        string = unescapedString;

    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding));
}

+ (SSignal *)_iTunesAlbumArtForPerformer:(NSString *)performer song:(NSString *)song thumbnail:(bool)thumbnail
{
    if (!TGMusicAlbumArtQueryIsValid(performer, song))
        return [SSignal fail:nil];
    
    NSArray *badWords =
    @[
      @" vs. ",
      @" vs ",
      @" versus ",
      @" ft. ",
      @" ft ",
      @" featuring ",
      @" feat. ",
      @" feat ",
      @" presents ",
      @" pres. ",
      @" pres ",
      @" and ",
      @" & ",
      @" . "
    ];
    for (NSString *word in badWords)
        performer = [performer stringByReplacingOccurrencesOfString:word withString:@" "];
    
    NSString *metaUrl = [[NSString alloc] initWithFormat:@"https://itunes.apple.com/search?term=%@&entity=song&limit=4", TGURLEncodedStringFromString([NSString stringWithFormat:@"%@ %@", performer, song])];
    CGSize pixelSize = [TGMusicUtils albumArtworkPixelSize:thumbnail];
    NSString *artworkSize = [[NSString alloc] initWithFormat:@"%dx%d", (int)pixelSize.width, (int)pixelSize.height];
    
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:metaUrl] mapToSignal:^SSignal *(NSDictionary *json)
    {
        NSDictionary *result = [json[@"results"] firstObject];
        NSString *artworkUrl = [result[@"artworkUrl100"] stringByReplacingOccurrencesOfString:@"100x100" withString:artworkSize];
        if (artworkUrl.length == 0)
            return [SSignal fail:nil];
        
        return [[LegacyComponentsGlobals provider] dataForHttpLocation:artworkUrl];
    }];
}

+ (SSignal *)_albumArtSyncForUrl:(NSURL *)url
{
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (asset == nil)
            [subscriber putError:nil];
        
        NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
        if (artworks == nil)
            [subscriber putError:nil];
        else
        {
            UIImage *image = nil;
            for (AVMetadataItem *item in artworks)
            {
                if ([item.keySpace isEqualToString:AVMetadataKeySpaceID3])
                {
                    if ([item.value respondsToSelector:@selector(objectForKey:)])
                        image = [UIImage imageWithData:[(id)item.value objectForKey:@"data"]];
                    else if ([item.value isKindOfClass:[NSData class]])
                        image = [UIImage imageWithData:(id)item.value];
                }
                else if ([item.keySpace isEqualToString:AVMetadataKeySpaceiTunes])
                    image = [UIImage imageWithData:(id)item.value];
            }
            
            if (image != nil)
            {
                [subscriber putNext:[TGMusicUtils albumArtwork:image thumbnail:false]];
                [subscriber putCompletion];
            }
            else
                [subscriber putError:nil];
        }
#else
        [TGMusicUtils albumArtworkForURL:url completion:^(UIImage *image)
        {
            if (image != nil)
            {
                [subscriber putNext:image];
                [subscriber putCompletion];
            }
            else
                [subscriber putError:nil];
        }];
#endif
        
        return nil;
    }] catch:^SSignal *(__unused id error)
    {
        return [self _albumArtForUrl:url multicastManager:nil];
    }];
}

+ (SSignal *)_albumArtForUrl:(NSURL *)url multicastManager:(SMulticastSignalManager *)__unused multicastManager
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [TGMusicUtils albumArtworkForURL:url completion:^(UIImage *image)
        {
            if (image != nil)
            {
                [subscriber putNext:image];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        }];
        
        return nil;
    }];
}

@end
