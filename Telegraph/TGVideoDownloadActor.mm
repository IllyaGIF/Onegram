#import "TGVideoDownloadActor.h"
#import "../OnegramPlatform/OGPlatformMedia.h"


#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegraph.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGCache.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGFileDownloadActor.h"

#import "TGTelegramNetworking.h"
#import "OGMediaFetchDescriptor+Telegraph.h"

#import "TGDownloadManager.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>

#import <CommonCrypto/CommonDigest.h>

#import "TGAppDelegate.h"


static NSMutableDictionary *rewriteDict()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

@interface TGVideoDownloadActor ()
{
    NSData *_encryptionKey;
    NSData *_encryptionIv;
    int32_t _finalSize;
    TGMediaOriginInfo *_originInfo;
    NSString *_videoUrl;
    
    OGMediaFetchSession *_session;
    OGMediaFetchObserver *_observer;
    id _demand;
    id _lifetimeToken;
}

- (bool)isCurrentLifetimeToken:(id)token;

@property (nonatomic, strong) NSString *storeFilePath;
@property (nonatomic, strong) NSString *tempStoreFilePath;
@property (nonatomic, strong) NSString *thumbnailFilePath;

@property (nonatomic) int64_t videoId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int datacenterId;
@property (nonatomic) int videoFileLength;

@property (nonatomic, strong) TGVideoMediaAttachment *videoAttachment;

@property (nonatomic) float progress;

@property (nonatomic, strong) NSDictionary *additionalOptions;

@end

static TGVideoDownloadActor *TGVideoDownloadActorResolve(NSString *path, id token)
{
    TGVideoDownloadActor *actor = (TGVideoDownloadActor *)[ActionStageInstance() executingActorWithPath:path];
    if (actor == nil || ![actor isCurrentLifetimeToken:token])
        return nil;
    return actor;
}

@implementation TGVideoDownloadActor

+ (NSString *)genericPath
{
    return @"/as/media/video/@";
}

+ (void)reloadForAccountSwitch
{
    [rewriteDict() removeAllObjects];
}

+ (void)rewriteLocalFilePath:(NSString *)localFilePath remoteUrl:(NSString *)remoteUrl
{
    if (localFilePath != nil && remoteUrl != nil)
        [rewriteDict() setObject:remoteUrl forKey:localFilePath];
}

+ (NSString *)rewrittenUrlForLocalPath:(NSString *)localFilePath
{
    if (localFilePath == nil)
        return nil;
    
    return [rewriteDict() objectForKey:localFilePath];
}

+ (bool)isVideoDownloaded:(NSFileManager *)fileManager url:(NSString *)url
{
    if ([url hasPrefix:@"local-video:"])
        return true;
    
    static NSString *videosPath = nil;
    if (videosPath == nil)
    {
        videosPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"video"];
    }
    
    if ([url hasPrefix:@"video"])
    {
        NSArray *urlComponents = [url componentsSeparatedByString:@":"];
        if (urlComponents.count != 5)
            return false;
        else
        {
            int64_t videoId = [[urlComponents objectAtIndex:1] longLongValue];
            NSString *storeFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", videoId]];
            if ([fileManager fileExistsAtPath:storeFilePath])
                return true;
        }
    }
    else if ([url hasPrefix:@"mt-encrypted-file://"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[url substringFromIndex:@"mt-encrypted-file://?".length]];
        
        if (args[@"id"] != nil)
        {
            int64_t videoId = [args[@"id"] longLongValue];
            NSString *storeFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", videoId]];
            if ([fileManager fileExistsAtPath:storeFilePath])
                return true;
        }
    }
    
    return false;
}

+ (NSString *)localPathForVideoUrl:(NSString *)url
{
    static NSString *videosPath = nil;
    if (videosPath == nil)
    {
        videosPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"video"];
    }
    
    if ([url hasPrefix:@"video"])
    {
        NSArray *urlComponents = [url componentsSeparatedByString:@":"];
        if (urlComponents.count != 5)
            return nil;
        else
        {
            int64_t videoId = [[urlComponents objectAtIndex:1] longLongValue];
            NSString *storeFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", videoId]];
            return storeFilePath;
        }
    }
    else if ([url hasPrefix:@"local-video:"])
    {
        NSString *videoFileName = [url substringFromIndex:@"local-video:".length];
        NSString *storeFilePath = [videosPath stringByAppendingPathComponent:videoFileName];
        return storeFilePath;
    }
    else if ([url hasPrefix:@"mt-encrypted-file://"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[url substringFromIndex:@"mt-encrypted-file://?".length]];
        
        if (args[@"id"] != nil)
        {
            int64_t videoId = [args[@"id"] longLongValue];
            NSString *storeFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", videoId]];
            return storeFilePath;
        }
    }
    
    return nil;
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        _lifetimeToken = [[NSObject alloc] init];
        
        if ([path hasSuffix:@"+download)"])
        {
            self.requestQueueName = @"videoDownload";
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self releaseSession];
}

- (void)prepare:(NSDictionary *)options
{
    [super prepare:options];
}

- (void)execute:(NSDictionary *)options
{
    bool cachedOnly = false;
    
    _videoAttachment = [options objectForKey:@"videoAttachment"];
    _additionalOptions = options[@"additionalOptions"];
    
    NSString *videoUrl = [self.path substringWithRange:NSMakeRange(17, self.path.length - 1 - 17)];
    if ([videoUrl hasPrefix:@"cached:"])
    {
        cachedOnly = true;
        videoUrl = [videoUrl substringFromIndex:@"cached:".length];
    }
    
    NSFileManager *fileManager = [ActionStageInstance() globalFileManager];
    
    static NSString *videosPath = nil;
    if (videosPath == nil)
    {
        videosPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"video"];
        if (![fileManager fileExistsAtPath:videosPath])
        {
            NSError *error = nil;
            [fileManager createDirectoryAtPath:videosPath withIntermediateDirectories:true attributes:nil error:&error];
            if (error != nil)
            {
                
                [ActionStageInstance() actionFailed:self.path reason:-1];
                return;
            }
        }
    }
    
    if ([videoUrl hasPrefix:@"local-video:"])
    {
        NSString *rewrittenUrl = [TGVideoDownloadActor rewrittenUrlForLocalPath:videoUrl];
        if (rewrittenUrl != nil)
            videoUrl = rewrittenUrl;
    }
    
    if ([videoUrl hasPrefix:@"video:"] || [videoUrl hasPrefix:@"mt-encrypted-file://"])
    {
        _videoUrl = videoUrl;
        NSMutableDictionary *videoArgs = [[NSMutableDictionary alloc] init];
        
        if ([videoUrl hasPrefix:@"mt-encrypted-file://"])
        {
            NSString *parseUrl = videoUrl;
            if ([videoUrl hasSuffix:@"+download"])
                parseUrl = [videoUrl substringToIndex:videoUrl.length - @"+download".length];
            
            NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[parseUrl substringFromIndex:@"mt-encrypted-file://?".length]];

            if (args[@"id"] != nil)
                videoArgs[@"videoId"] = args[@"id"];
            if (args[@"accessHash"] != nil)
                videoArgs[@"accessHash"] = args[@"accessHash"];
            if (args[@"dc"] != nil)
                videoArgs[@"datacenterId"] = args[@"dc"];
            if (args[@"size"] != nil)
                videoArgs[@"videoFileLength"] = args[@"size"];
            
            NSData *key = [args[@"key"] dataByDecodingHexString];
            
            _finalSize = [args[@"decryptedSize"] intValue];
            
            if (key.length != 64)
            {
                TGLog(@"***** Invalid file key length");
                [videoArgs removeAllObjects];
            }
            else
            {
                _encryptionKey = [key subdataWithRange:NSMakeRange(0, 32)];
                _encryptionIv = [key subdataWithRange:NSMakeRange(32, 32)];
                
                unsigned char digest[CC_MD5_DIGEST_LENGTH];
                CC_MD5(key.bytes, 32 + 32, digest);
                
                int32_t digestHigh = 0;
                int32_t digestLow = 0;
                memcpy(&digestHigh, digest, 4);
                memcpy(&digestLow, digest + 4, 4);
                
                int32_t key_fingerprint = digestHigh ^ digestLow;
                if (args[@"fingerprint"] != nil && [args[@"fingerprint"] intValue] != key_fingerprint)
                {
                    TGLog(@"***** Invalid file key fingerprint");
                    [videoArgs removeAllObjects];
                }
            }
        }
        else
        {
            NSArray *urlComponents = [videoUrl componentsSeparatedByString:@":"];
            if (urlComponents.count >= 5)
            {
                videoArgs[@"videoId"] = [urlComponents objectAtIndex:1];
                videoArgs[@"accessHash"] = [urlComponents objectAtIndex:2];
                videoArgs[@"datacenterId"] = [urlComponents objectAtIndex:3];
                videoArgs[@"videoFileLength"] = [urlComponents objectAtIndex:4];
            }
            
            _originInfo = _videoAttachment.originInfo;
        }
        
        if (videoArgs[@"videoId"] == nil || videoArgs[@"accessHash"] == nil || videoArgs[@"datacenterId"] == nil || videoArgs[@"videoFileLength"] == nil)
        {
            [ActionStageInstance() actionFailed:self.path reason:-1];
        }
        else
        {
            _videoId = [videoArgs[@"videoId"] longLongValue];
            _accessHash = [videoArgs[@"accessHash"] longLongValue];
            _datacenterId = [videoArgs[@"datacenterId"] intValue];
            _videoFileLength = [videoArgs[@"videoFileLength"] intValue];
            
            if (_videoFileLength == 0)
            {
                [ActionStageInstance() actionFailed:self.path reason:-1];
            }
            else
            {
                _storeFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", _videoId]];
                _tempStoreFilePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.part", _videoId]];
                _thumbnailFilePath = [[NSString alloc] initWithFormat:@"video-thumbnail-remote%llx.jpg", _videoId];
                
                if ([fileManager fileExistsAtPath:_storeFilePath])
                {
                    [ActionStageInstance() actionCompleted:self.path result:[[NSDictionary alloc] initWithObjectsAndKeys:_storeFilePath, @"filePath", nil]];
                }
                else if (!cachedOnly)
                {
                    if ([self.path hasSuffix:@"+download)"])
                    {
                        [self startDownload];
                    }
                    else
                    {
                        if (_additionalOptions[@"peerId"] != nil && _additionalOptions[@"messageId"] != nil)
                        {
                            [[TGDownloadManager instance] enqueueItem:self.path messageId:[_additionalOptions[@"messageId"] intValue] itemId:[[TGMediaId alloc] initWithType:1 itemId:_videoId] groupId:[_additionalOptions[@"peerId"] longLongValue] itemClass:TGDownloadItemClassVideo];
                        }
                        
                        [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"willDownloadVideo" message:[[NSDictionary alloc] initWithObjectsAndKeys:[[TGMediaId alloc] initWithType:1 itemId:_videoId], @"mediaId", nil]];
                        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"%@+download)", [self.path substringToIndex:self.path.length - 1]] options:options watcher:self];
                    }
                }
                else
                {
                    [ActionStageInstance() actionFailed:self.path reason:-1];
                }
            }
        }
    }
    else if ([videoUrl hasPrefix:@"local-video:"])
    {
        NSString *filePath = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%@", [videoUrl substringFromIndex:@"local-video:".length]]];
        [ActionStageInstance() actionCompleted:self.path result:[[NSDictionary alloc] initWithObjectsAndKeys:filePath, @"filePath", nil]];
    }
    else
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
    }
}

- (void)startDownload
{
    OGMediaFetchDescriptor *descriptor = [OGMediaFetchDescriptor descriptorForVideoUrl:_videoUrl originInfo:_originInfo publishPath:NULL];
    if (descriptor == nil)
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
        return;
    }

    NSString *actorPath = [self.path copy];
    id lifetimeToken = _lifetimeToken;
    OGMediaFetchObserver *observer = [[OGMediaFetchObserver alloc] init];
    observer.progress = ^(float progress)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGVideoDownloadActor *actor = TGVideoDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil)
                return;
            actor.progress = progress;
            [ActionStageInstance() dispatchMessageToWatchers:actorPath messageType:@"progress" message:[[NSNumber alloc] initWithFloat:progress]];
        }];
    };
    observer.completed = ^(__unused NSString *path, __unused NSData *data)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGVideoDownloadActor *actor = TGVideoDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil)
                return;
            [actor releaseSession];
            [actor completeDownload];
        }];
    };
    observer.failed = ^
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGVideoDownloadActor *actor = TGVideoDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil)
                return;
            [actor releaseSession];
            [ActionStageInstance() actionFailed:actorPath reason:-1];
        }];
    };

    _session = [OGMediaFetchSession acquireSessionForDescriptor:descriptor];
    _observer = observer;
    [_session addPublishPath:_storeFilePath];
    [_session addObserver:observer];
    _demand = [_session addDemandFrom:0 to:INT64_MAX priority:OGMediaFetchPriorityDownload];
}

- (bool)isCurrentLifetimeToken:(id)token
{
    return _lifetimeToken == token;
}

- (void)releaseSession
{
    if (_session == nil)
        return;
    [_session removeDemand:_demand];
    [_session removeObserver:_observer];
    [_session relinquish];
    _session = nil;
    _observer = nil;
    _demand = nil;
}

- (void)completeDownload
{
    if (_videoAttachment.roundMessage && _encryptionKey != nil)
    {
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        [result setObject:_storeFilePath forKey:@"filePath"];

        [ActionStageInstance() actionCompleted:self.path result:result];
    }
    else
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            
            UIImage *image = OGPlatformVideoThumbnailAtURL([NSURL fileURLWithPath:_storeFilePath], 0.0, CGSizeMake(800.0f, 800.0f));
            UIImage *thumbnailImage = nil;
            
            if (image != nil)
            {
                if (_videoAttachment != nil)
                {
                    NSString *thumbnailUrl = [_videoAttachment.thumbnailInfo closestImageUrlWithSize:CGSizeMake(90, 90) resultingSize:NULL];
                    thumbnailImage = TGScaleImageToPixelSize(image, TGFitSize(CGSizeMake(image.size.width * image.scale, image.size.height * image.scale), CGSizeMake(200, 200)));
                    NSData *thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.85f);
                    
                    if (thumbnailData != nil)
                    {
                        [[TGRemoteImageView sharedCache] removeFromMemoryCache:thumbnailUrl matchEnd:true];
                        [[TGRemoteImageView sharedCache] cacheImage:nil withData:thumbnailData url:thumbnailUrl availability:TGCacheDisk];
                        
                        [ActionStageInstance() dispatchOnStageQueue:^
                        {
                            TGFileDownloadActor *fileActor = (TGFileDownloadActor *)[ActionStageInstance() executingActorWithPath:[[NSString alloc] initWithFormat:@"/tg/file/(%@)", thumbnailUrl]];
                            if (fileActor != nil)
                            {
                                [fileActor completeWithData:thumbnailData];
                            }
                            else
                            {
                                [ActionStageInstance() dispatchResource:[[NSString alloc] initWithFormat:@"/as/media/imageThumbnailUpdated"] resource:thumbnailUrl];
                            }
                        }];
                    }
                }
                
                [[TGRemoteImageView sharedCache] cacheImage:nil withData:UIImageJPEGRepresentation(image, 0.87f) url:_thumbnailFilePath availability:TGCacheDisk];
                
            }
            
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            [result setObject:_storeFilePath forKey:@"filePath"];
            if (image != nil)
                [result setObject:_thumbnailFilePath forKey:@"thumbnailPath"];
            
            if (image != nil)
                [ActionStageInstance() dispatchResource:@"/as/media/previewReady" resource:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:_videoId], @"videoId", image, @"image", nil]];
            
            
            [ActionStageInstance() actionCompleted:self.path result:result];
        });
    }
}

- (void)cancel
{
    [ActionStageInstance() removeWatcher:self];
    
    [self releaseSession];
    
    [super cancel];
}

#pragma mark -

- (void)watcherJoined:(ASHandle *)watcherHandle options:(NSDictionary *)options waitingInActorQueue:(bool)waitingInActorQueue
{
    [watcherHandle receiveActorMessage:self.path messageType:@"progress" message:[[NSNumber alloc] initWithFloat:_progress]];
    
    [super watcherJoined:watcherHandle options:options waitingInActorQueue:waitingInActorQueue];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/as/media/video/"])
    {
        if (status == ASStatusSuccess)
            [ActionStageInstance() actionCompleted:self.path result:result];
        else
            [ActionStageInstance() actionFailed:self.path reason:status];
    }
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path hasPrefix:@"/as/media/video/"])
    {
        if ([messageType isEqualToString:@"progress"])
        {
            _progress = [message floatValue];
            [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"progress" message:[[NSNumber alloc] initWithFloat:_progress]];
        }
    }
}

@end
