#import "TGMediaPreviewTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/ASWatcher.h"

#import "TGWorkerPool.h"
#import "TGWorkerTask.h"

#import "TGImageInfo+Telegraph.h"

#import "TL/TLMetaScheme.h"

#import "TGMediaStoreContext.h"

#import "TGMapSnapshotterActor.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGTelegramNetworking.h"
#import "TGImageDownloadActor.h"
#import "TGDownloadMessagesSignal.h"
#import "TGTelegraph.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SMulticastSignalManager.h"

static SSignal *TGThumbnailMessageSignal(TGDownloadMessage *request)
{
    static NSArray *queues = nil;
    static SMulticastSignalManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queues = @[[[SSignalQueue alloc] init], [[SSignalQueue alloc] init]];
        manager = [[SMulticastSignalManager alloc] init];
    });
    NSString *key = [NSString stringWithFormat:@"%lld:%d", request.peerId, request.messageId];
    NSUInteger lane = OGPlatformUsesConstrainedBackgroundExecution() || OGRuntimeSingleCoreDevice() ? 0 : [key hash] % queues.count;
    return [manager multicastedSignalForKey:key producer:^SSignal *
    {
        return [queues[lane] enqueue:[TGDownloadMessagesSignal downloadMessages:@[request]]];
    }];
}

@interface TGMediaPreviewTask () <ASWatcher>
{
    volatile bool _idCancelled;
    
    TGWorkerPool *_workerPool;
    TGWorkerTask *_workerTask;
    SThreadPoolTask *_task;
    NSString *_uri;
    NSString *_targetFilePath;
    SMetaDisposable *_thumbnailMetadataDisposable;
    bool _thumbnailOnly;
}

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, copy) void (^completion)(bool);
@property (nonatomic, copy) void (^completionWithData)(NSData *);
@property (nonatomic, copy) void (^completionWithImage)(UIImage *);
@property (nonatomic, copy) void (^progress)(float);

@end

@implementation TGMediaPreviewTask

- (void)executeThumbnailWithTargetFilePath:(NSString *)targetFilePath uri:(NSString *)uri options:(NSDictionary *)options completion:(void (^)(bool))completion workerTask:(TGWorkerTask *)workerTask
{
    if (_idCancelled)
        return;
    NSDictionary *context = options[@"thumbnailContext"];
    if (uri.length == 0)
    {
        int64_t peerId = [context[@"cid"] longLongValue];
        int32_t messageId = [context[@"mid"] intValue];
        int64_t mediaId = [context[@"id"] longLongValue];
        if (peerId == 0 || messageId == 0 || mediaId == 0)
        {
            if (completion != nil)
                completion(false);
            return;
        }
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
        TGDownloadMessage *request = [[TGDownloadMessage alloc] initWithPeerId:peerId accessHash:conversation.accessHash messageId:messageId];
        _workerTask = workerTask;
        _thumbnailMetadataDisposable = [[SMetaDisposable alloc] init];
        __weak TGMediaPreviewTask *weakSelf = self;
        __block bool receivedMessages = false;
        [_thumbnailMetadataDisposable setDisposable:[[[TGThumbnailMessageSignal(request) take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *messages)
        {
            receivedMessages = true;
            TGMediaPreviewTask *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_idCancelled)
                return;
            NSString *thumbnailUri = nil;
            TGMediaOriginInfo *origin = nil;
            for (TGMessage *message in messages)
            {
                if (message.mid != messageId)
                    continue;
                for (TGMediaAttachment *attachment in message.mediaAttachments)
                {
                    TGImageInfo *info = nil;
                    if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]] && ((TGDocumentMediaAttachment *)attachment).documentId == mediaId)
                    {
                        info = ((TGDocumentMediaAttachment *)attachment).thumbnailInfo;
                        origin = ((TGDocumentMediaAttachment *)attachment).originInfo;
                    }
                    else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]] && ((TGVideoMediaAttachment *)attachment).videoId == mediaId)
                    {
                        info = ((TGVideoMediaAttachment *)attachment).thumbnailInfo;
                        origin = ((TGVideoMediaAttachment *)attachment).originInfo;
                    }
                    else if ([attachment isKindOfClass:[TGImageMediaAttachment class]] && ((TGImageMediaAttachment *)attachment).imageId == mediaId)
                    {
                        info = ((TGImageMediaAttachment *)attachment).imageInfo;
                        origin = ((TGImageMediaAttachment *)attachment).originInfo;
                    }
                    thumbnailUri = [info imageUrlForPreviewWithSize:NULL];
                    if (thumbnailUri.length != 0)
                        break;
                }
                if (thumbnailUri.length != 0)
                    break;
            }
            if (thumbnailUri.length == 0)
            {
                if (completion != nil)
                    completion(false);
                return;
            }
            NSMutableDictionary *updatedOptions = [options mutableCopy];
            if (origin != nil)
                updatedOptions[@"originInfo"] = origin;
            [strongSelf executeThumbnailWithTargetFilePath:targetFilePath uri:thumbnailUri options:updatedOptions completion:completion workerTask:workerTask];
        } error:^(__unused id error)
        {
            TGMediaPreviewTask *strongSelf = weakSelf;
            if (strongSelf != nil && !strongSelf->_idCancelled && completion != nil)
                completion(false);
        } completed:^
        {
            TGMediaPreviewTask *strongSelf = weakSelf;
            if (!receivedMessages && strongSelf != nil && !strongSelf->_idCancelled && completion != nil)
                completion(false);
        }]];
        return;
    }
    NSArray *parts = [uri componentsSeparatedByString:@":"];
    if (([uri hasPrefix:@"documentthumb:"] || [uri hasPrefix:@"photo:"]) && (parts.count < 7 || [parts[5] length] == 0 || [parts[4] longLongValue] > 512 * 1024))
    {
        if (completion != nil)
            completion(false);
        return;
    }
    NSMutableDictionary *thumbnailOptions = options == nil ? [[NSMutableDictionary alloc] init] : [options mutableCopy];
    thumbnailOptions[@"thumbnailOnly"] = @true;
    thumbnailOptions[@"useCache"] = @false;
    thumbnailOptions[@"allowThumbnailCache"] = @false;
    _thumbnailOnly = true;
    [self executeWithTargetFilePath:targetFilePath uri:uri options:thumbnailOptions completion:completion workerTask:workerTask];
}

- (void)executeWithWorkerTask:(TGWorkerTask *)workerTask workerPool:(TGWorkerPool *)workerPool
{
    _workerTask = workerTask;
    _workerPool = workerPool;
    
    [_workerPool addTask:_workerTask];
}

- (void)executeWithWorkerTask:(TGWorkerTask *)workerTask threadPool:(SThreadPool *)threadPool
{
    _task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)()) {
        if (!cancelled())
            [workerTask execute];
    }];
    [threadPool addTask:_task];
}

- (void)executeWithTargetFilePath:(NSString *)targetFilePath uri:(NSString *)uri options:(NSDictionary *)options completion:(void (^)(bool))completion workerTask:(TGWorkerTask *)workerTask
{
    [self executeWithTargetFilePath:targetFilePath uri:uri options:options progress:nil completion:completion workerTask:workerTask];
}

- (void)executeWithTargetFilePath:(NSString *)targetFilePath uri:(NSString *)uri options:(NSDictionary *)options progress:(void (^)(float))progress completion:(void (^)(bool))completion workerTask:(TGWorkerTask *)workerTask
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    _targetFilePath = targetFilePath;
    _uri = uri;
    _completion = completion;
    _workerTask = workerTask;
    _progress = progress;
    
    if (options == nil)
        options = @{};
    
    if (([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) && ![options[@"thumbnailOnly"] boolValue])
    {
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/temporaryDownload/(%@)", [TGStringUtils stringByEscapingForActorURL:uri]] options:@{@"url": uri, @"path": targetFilePath == nil ? @"" : targetFilePath, @"cache": [[TGMediaStoreContext instance] temporaryFilesCache], @"mediaTypeTag": @(TGNetworkMediaTypeTagImage)} flags:0 watcher:self];
    }
    else
    {
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/img/(download:%@)", [TGStringUtils stringByEscapingForActorURL:uri]] options:options flags:0 watcher:self];
    }
}

- (void)executeWithTargetFilePath:(NSString *)targetFilePath document:(TGDocumentMediaAttachment *)document progress:(void (^)(float))progress completion:(void (^)(bool))completion workerTask:(TGWorkerTask *)workerTask
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    _targetFilePath = targetFilePath;
    _completion = completion;
    _workerTask = workerTask;
    _progress = progress;
    
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/media/document/(%d:%" PRId64 ":%@)", document.datacenterId, document.documentId, document.documentUri.length != 0 ? document.documentUri : @""] options:[[NSDictionary alloc] initWithObjectsAndKeys:document, @"documentAttachment", nil] flags:0 watcher:self];
}

- (void)executeTempDownloadWithTargetFilePath:(NSString *)targetFilePath uri:(NSString *)uri progress:(void (^)(float))progress completionWithData:(void (^)(NSData *))completionWithData workerTask:(TGWorkerTask *)workerTask
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    _targetFilePath = targetFilePath;
    _uri = uri;
    _completionWithData = completionWithData;
    _workerTask = workerTask;
    _progress = progress;
    
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/temporaryDownload/(%@)", [TGStringUtils stringByEscapingForActorURL:uri]] options:@{@"url": uri, @"mediaTypeTag": @(TGNetworkMediaTypeTagImage)} flags:0 watcher:self];
}

- (void)executeMultipartWithImageUri:(NSString *)imageUri identifier:(int64_t)identifier originInfo:(TGMediaOriginInfo *)originInfo targetFilePath:(NSString *)targetFilePath progress:(void (^)(float))progress completion:(void (^)(bool))completion
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    _progress = progress;
    _completion = completion;
    
    int datacenterId = 0;
    int64_t thumbnailIdentifier = identifier;
    TLInputFileLocation *thumbnailLocation = OGInputLocationFromImageUrl(imageUri, originInfo, &datacenterId, &thumbnailIdentifier);
    if (thumbnailLocation != nil)
    {
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                            @"identifier": @(thumbnailIdentifier),
                                                                                            @"fileLocation": thumbnailLocation,
                                                                                            @"storeFilePath": targetFilePath,
                                                                                            @"datacenterId": @(datacenterId),
                                                                                            @"encryptionArgs": @{},
                                                                                            @"mediaTypeTag": @(TGNetworkMediaTypeTagImage)
                                                                                            }];
        if (originInfo != nil)
            options[@"originInfo"] = originInfo;
        
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/multipart-file/(modern-preview:%" PRId64 ":%d:%lu)", thumbnailIdentifier, datacenterId, (unsigned long)[imageUri hash]] options:options watcher:self];
        return;
    }
    
    int64_t volumeId = 0;
    int localId = 0;
    int64_t secret = 0;
    if (extractFileUrlComponents(imageUri, &datacenterId, &volumeId, &localId, &secret))
    {
        TLInputFileLocation$inputFileLocation *fileLocation = [[TLInputFileLocation$inputFileLocation alloc] init];
        fileLocation.volume_id = volumeId;
        fileLocation.local_id = (int32_t)localId;
        fileLocation.secret = secret;
        fileLocation.file_reference = [originInfo fileReferenceForVolumeId:volumeId localId:localId];
        
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                            @"identifier": @(identifier),
                                                                                            @"fileLocation": fileLocation,
                                                                                            @"storeFilePath": targetFilePath,
                                                                                            @"datacenterId": @(datacenterId),
                                                                                            @"encryptionArgs": @{},
                                                                                            @"mediaTypeTag": @(TGNetworkMediaTypeTagImage)
                                                                                            }];
        if (originInfo != nil)
            options[@"originInfo"] = originInfo;
        
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/multipart-file/(image:%" PRId64 ":%d:%d)", volumeId, localId, datacenterId] options:options watcher:self];
    }
    else if (completion)
    {
        completion(false);
    }
}

- (void)executeWithMapSnapshotOptions:(TGMapSnapshotOptions *)snapshotOptions completionWithImage:(void (^)(UIImage *image))completionWithImage workerTask:(TGWorkerTask *)workerTask
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    _completionWithImage = completionWithImage;
    _workerTask = workerTask;
    
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/mapSnapshot/(%@)", [snapshotOptions uniqueIdentifier]] options:@{ @"options":snapshotOptions, @"cache": [[TGMediaStoreContext instance] temporaryFilesCache] } watcher:self];
}

- (void)dealloc
{
    [_thumbnailMetadataDisposable dispose];
    if (_actionHandle != nil)
    {
        [_actionHandle reset];
        [ActionStageInstance() removeWatcherByHandle:_actionHandle];
    }
}

- (void)cancel
{
    _idCancelled = true;
    [_thumbnailMetadataDisposable dispose];
    
    if (_workerTask != nil)
    {
        [_workerTask cancel];
        [_workerPool removeTask:_workerTask];
    }
    
    [_task cancel];
    
    if (_actionHandle != nil)
        [ActionStageInstance() removeWatcherByHandle:_actionHandle];
}

- (bool)isCancelled
{
    return _idCancelled;
}

- (void)actorCompleted:(int)status path:(NSString *)__unused path result:(id)result
{
    if (_idCancelled)
        return;
    if (_thumbnailOnly && status == ASStatusSuccess && _targetFilePath.length != 0)
    {
        dispatch_async([TGCache diskCacheQueue], ^
        {
            if (_idCancelled)
                return;
            NSData *data = [_uri hasPrefix:@"file://"] ? [NSData dataWithContentsOfFile:[_uri substringFromIndex:7]] : [[TGRemoteImageView sharedCache] cachedDataForUrl:_uri];
            bool videoData = data.length >= 12 && memcmp((const uint8_t *)data.bytes + 4, "ftyp", 4) == 0;
            if ((data.length == 0 || videoData) && [result isKindOfClass:[SGraphObjectNode class]])
            {
                id image = ((SGraphObjectNode *)result).object;
                if ([image isKindOfClass:[UIImage class]])
                    data = UIImageJPEGRepresentation(image, 0.85f);
            }
            bool success = false;
            if (data.length != 0 && data.length <= 512 * 1024)
            {
                NSData *stored = [NSData dataWithContentsOfFile:_targetFilePath];
                success = [stored isEqualToData:data] || [data writeToFile:_targetFilePath atomically:true];
            }
            if (!_idCancelled && _completion != nil)
                _completion(success);
        });
        return;
    }
    if (_completion != nil)
        _completion(status == ASStatusSuccess);
    if (_completionWithData != nil)
        _completionWithData(status == ASStatusSuccess ? result : nil);
    if (_completionWithImage != nil)
        _completionWithImage(status == ASStatusSuccess ? result : nil);
}

- (void)actorMessageReceived:(NSString *)__unused path messageType:(NSString *)messageType message:(id)message
{
    if ([messageType isEqualToString:@"progress"])
    {
        if (_progress)
            _progress([message floatValue]);
    }
}

@end
