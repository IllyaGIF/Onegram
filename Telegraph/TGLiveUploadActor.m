/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGLiveUploadActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegramNetworking.h"
#import "TGNetworkWorker.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "TL/TLMetaScheme.h"

#import <CommonCrypto/CommonDigest.h>

#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"

#import "TGDataItem.h"

#import "../OnegramRuntime/OGRuntime.h"

static NSMutableDictionary *TGLiveUploadActiveActors(void)
{
    static NSMutableDictionary *actors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        actors = [[NSMutableDictionary alloc] init];
    });
    return actors;
}

@interface TGLiveUploadActorData () <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGLiveUploadActorData

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    [ActionStageInstance() removeWatcher:self];
}

@end

@interface TGLiveUploadPart ()

@property (nonatomic, strong) id cancelToken;

@end

@implementation TGLiveUploadPart

@end

@interface TGLiveUploadActor ()
{
    TGDataItem *_fileItem;
    bool _encryptFile;
    
    int64_t _fileId;
    NSUInteger _availableSize;
    
    id _workerToken;
    TGNetworkWorkerGuard *_worker;
    
    NSMutableArray *_doneParts;
    NSMutableArray *_uploadingParts;
    
    bool _lateHeaderMode;
    NSData *(^_dataProvider)(NSUInteger offset, NSUInteger length);
    NSData *_unfinishedHeaderData;
    
    bool _liveMode;
    bool _canComplete;
    
    NSData *_aesKey;
    NSData *_aesIv;
    NSMutableData *_aesRunningIv;
    int32_t _keyFingerprint;
    
    dispatch_queue_t _transferQueue;
    bool _transferFinished;
    volatile float _progressValue;
}

@end

@implementation TGLiveUploadActor

+ (void)reloadForAccountSwitch
{
    NSMutableDictionary *actors = TGLiveUploadActiveActors();
    @synchronized (actors)
    {
        [actors removeAllObjects];
    }
}

+ (void)load
{
    @autoreleasepool
    {
        [ASActor registerActorClass:self];
    }
}

- (void)dealloc
{
    if (_workerToken != nil)
        [[TGTelegramNetworking instance] cancelUploadWorkerRequestByToken:_workerToken];
    
    [_worker releaseWorker];
}

+ (TGLiveUploadActor *)liveUploadActorForPath:(NSString *)path
{
    if (path == nil)
        return nil;
    
    NSMutableDictionary *actors = TGLiveUploadActiveActors();
    @synchronized (actors)
    {
        return actors[path];
    }
}

+ (void)updateSize:(NSUInteger)availableSize forActorPath:(NSString *)path
{
    TGLiveUploadActor *actor = [self liveUploadActorForPath:path];
    if (actor != nil)
    {
        [actor updateSize:availableSize];
        return;
    }
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [(TGLiveUploadActor *)[ActionStageInstance() executingActorWithPath:path] updateSize:availableSize];
    }];
}

+ (TGLiveUploadActorData *)finishForActorPath:(NSString *)path finish:(TGLiveUploadActorData *(^)(TGLiveUploadActor *))finish
{
    TGLiveUploadActor *actor = [self liveUploadActorForPath:path];
    if (actor != nil)
        return finish(actor);
    
    __block TGLiveUploadActorData *data = nil;
    dispatch_block_t block = ^
    {
        TGLiveUploadActor *executingActor = (TGLiveUploadActor *)[ActionStageInstance() executingActorWithPath:path];
        if (executingActor != nil)
            data = finish(executingActor);
    };
    
    if ([ActionStageInstance() isCurrentQueueStageQueue])
        block();
    else
        dispatch_sync([ActionStageInstance() globalStageDispatchQueue], block);
    
    return data;
}

+ (TGLiveUploadActorData *)finishRestOfFile:(NSUInteger)finalSize forActorPath:(NSString *)path
{
    return [self finishForActorPath:path finish:^TGLiveUploadActorData *(TGLiveUploadActor *actor)
    {
        return [actor finishRestOfFile:finalSize];
    }];
}

+ (TGLiveUploadActorData *)finishRestOfFileWithHeader:(NSData *)header finalSize:(NSUInteger)finalSize forActorPath:(NSString *)path
{
    return [self finishForActorPath:path finish:^TGLiveUploadActorData *(TGLiveUploadActor *actor)
    {
        return [actor finishRestOfFileWithHeader:header finalSize:finalSize];
    }];
}

- (void)registerActive
{
    NSMutableDictionary *actors = TGLiveUploadActiveActors();
    @synchronized (actors)
    {
        actors[self.path] = self;
    }
}

- (void)unregisterActive
{
    NSMutableDictionary *actors = TGLiveUploadActiveActors();
    @synchronized (actors)
    {
        if (actors[self.path] == self)
            [actors removeObjectForKey:self.path];
    }
}

+ (NSString *)genericPath
{
    return @"/tg/liveUpload/@";
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _doneParts = [[NSMutableArray alloc] init];
        _uploadingParts = [[NSMutableArray alloc] init];
        _transferQueue = OGRuntimeTransferQueue();
    }
    return self;
}

- (void)_finishTransfer
{
    if (_transferFinished)
        return;
    
    _transferFinished = true;
    [self unregisterActive];
    
    [_worker releaseWorker];
    _worker = nil;
}

- (void)_complete:(id)result
{
    [self _finishTransfer];
    
    [ActionStageInstance() actionCompleted:self.path result:result];
}

- (void)_fail
{
    if (_transferFinished)
        return;
    
    [self _finishTransfer];
    
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)execute:(NSDictionary *)options
{
    arc4random_buf(&_fileId, 8);
    
    _fileItem = options[@"fileItem"];
    if (_fileItem == nil && options[@"filePath"] != nil)
        _fileItem = [[TGDataItem alloc] initWithFilePath:options[@"filePath"]];
    
    _encryptFile = [options[@"encryptFile"] boolValue];
    _lateHeaderMode = [options[@"lateHeader"] boolValue];
    _dataProvider = [options[@"dataProvider"] copy];
    
    _liveMode = true;
    
    if (_fileItem == nil)
        [ActionStageInstance() actionFailed:self.path reason:-1];
    else
    {
        if (_encryptFile)
        {
            uint8_t rawKey[32];
            __unused int result = SecRandomCopyBytes(kSecRandomDefault, 32, rawKey);
            _aesKey = [[NSData alloc] initWithBytes:rawKey length:32];
            uint8_t rawIv[32];
            result = SecRandomCopyBytes(kSecRandomDefault, 32, rawIv);
            _aesIv = [[NSData alloc] initWithBytes:rawIv length:32];
            _aesRunningIv = [[NSMutableData alloc] initWithData:_aesIv];
            
            uint8_t keyPlusIv[32 + 32];
            [_aesKey getBytes:keyPlusIv range:NSMakeRange(0, 32)];
            [_aesIv getBytes:keyPlusIv + 32 range:NSMakeRange(0, 32)];
            
            unsigned char digest[CC_MD5_DIGEST_LENGTH];
            CC_MD5(keyPlusIv, 32 + 32, digest);
            
            int32_t digestHigh = 0;
            int32_t digestLow = 0;
            memcpy(&digestHigh, digest, 4);
            memcpy(&digestLow, digest + 4, 4);
            
            _keyFingerprint = digestHigh ^ digestLow;
        }
        
        TGNetworkMediaTypeTag mediaTypeTag = (TGNetworkMediaTypeTag)([options[@"mediaTypeTag"] intValue]);
        
        [self registerActive];
        
        __weak TGLiveUploadActor *weakSelf = self;
        _workerToken = [[TGTelegramNetworking instance] requestUploadWorkerForDatacenterId:[TGTelegramNetworking instance].masterDatacenterId type:mediaTypeTag completion:^(TGNetworkWorkerGuard *worker)
        {
            __strong TGLiveUploadActor *strongSelf = weakSelf;
            [strongSelf _beginWithWorker:worker];
        }];
    }
}

- (void)_beginWithWorker:(TGNetworkWorkerGuard *)worker
{
    dispatch_async(_transferQueue, ^
    {
        if (_transferFinished)
        {
            [worker releaseWorker];
            return;
        }
        
        _worker = worker;
        
        [_worker.strongWorker ensureConnection];
        
        [self _dequeuePartIfAny];
    });
}

- (void)updateSize:(NSUInteger)availableSize
{
    dispatch_async(_transferQueue, ^
    {
        if (availableSize > _availableSize)
            _availableSize = availableSize;
        
        [self _updateProgressValue];
        [self _dequeuePartIfAny];
    });
}

- (NSUInteger)doneSize
{
    NSUInteger value = 0;
    
    for (TGLiveUploadPart *part in _doneParts)
    {
        value += part.length;
    }
    
    return value;
}

- (void)_updateProgressValue
{
    _progressValue = _availableSize > 0 ? MAX(0.0f, MIN(1.0f, [self doneSize] / (float)_availableSize)) : 0.0f;
}

- (void)_dequeuePartIfAny
{
    if (_transferFinished || _worker == nil)
        return;
    
    if (!_liveMode && [self doneSize] >= _availableSize)
    {
        if (_canComplete)
        {
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            
            result[@"fileId"] = @(_fileId);
            result[@"partCount"] = @(_doneParts.count);
            result[@"fileSize"] = @(_availableSize);
            
            if (_encryptFile && _aesKey != nil &&_aesIv != nil)
            {
                result[@"aesKey"] = _aesKey;
                result[@"aesIv"] = _aesIv;
                result[@"aesKeyFingerprint"] = @(_keyFingerprint);
            }
            
            if (_fileItem != nil)
            {
                CC_MD5_CTX ctx;
                CC_MD5_Init(&ctx);
                NSUInteger bufferSize = 4 * 1024;
                for (NSUInteger i = 0; i < _availableSize; i += bufferSize)
                {
                    NSUInteger currentBufferSize = MIN(bufferSize, _availableSize - i);
                    NSData *data = [_fileItem readDataAtOffset:i length:currentBufferSize];
                    CC_MD5_Update(&ctx, data.bytes, (CC_LONG)data.length);
                }
                unsigned char md5Buffer[16];
                CC_MD5_Final(md5Buffer, &ctx);
                NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
                result[@"md5"] = hash;
            }
            
            [self _complete:result];
        }
    }
    else
    {
        NSInteger availableUploadSlots = MAX(0, (_liveMode ? (_lateHeaderMode ? 8 : 2) : 8) - (NSInteger)_uploadingParts.count);

        for (NSInteger slotIndex = 0; slotIndex < availableUploadSlots; slotIndex++)
        {
            NSUInteger processedSize = 0;
            for (TGLiveUploadPart *part in _uploadingParts)
            {
                processedSize = MAX(processedSize, part.offset + part.length);
            }
            for (TGLiveUploadPart *part in _doneParts)
            {
                processedSize = MAX(processedSize, part.offset + part.length);
            }
            
            NSUInteger nextPartSize = 16 * 1024;
            NSInteger minPartSize = 1024;
            
            bool takePart = false;
            if (_liveMode)
            {
                if (processedSize + minPartSize <= _availableSize)
                {
                    NSInteger calculatedPartSize = _availableSize - processedSize;
                    
                    if (_encryptFile)
                    {
                        while (calculatedPartSize % 16 != 0)
                        {
                            calculatedPartSize--;
                        }
                    }
                    
                    if (calculatedPartSize > 0)
                        takePart = true;
                }
            }
            else
            {
                if (processedSize < _availableSize || _unfinishedHeaderData != nil)
                    takePart = true;
            }
            
            if (takePart)
            {
                NSInteger currentPartSize = 0;
                NSData *partData = nil;
                bool isHeader = false;
                
                if (_unfinishedHeaderData != nil)
                {
                    partData = _unfinishedHeaderData;
                    _unfinishedHeaderData = nil;
                    currentPartSize = partData.length;
                    isHeader = true;
                }
                else
                {
                    currentPartSize = MIN((NSInteger)nextPartSize, MAX(0, (NSInteger)_availableSize - (NSInteger)processedSize));
                    
                    if (_encryptFile)
                    {
                        if (_liveMode || processedSize + currentPartSize < _availableSize)
                        {
                            while (currentPartSize % 16 != 0)
                            {
                                currentPartSize--;
                            }
                        }
                    }
                    
                    if (_dataProvider != nil)
                        partData = _dataProvider(processedSize, currentPartSize);
                    else
                        partData = [_fileItem readDataAtOffset:processedSize length:currentPartSize];
                }
                
                if (partData.length == (NSUInteger)currentPartSize)
                {
                    NSData *alignedPartData = partData;
                    if (_encryptFile)
                    {
                        NSMutableData *tempData = [[NSMutableData alloc] initWithData:partData];
                        
                        while (tempData.length == 0 || (NSInteger)tempData.length % 16 != 0)
                        {
                            uint8_t zero = 0;
                            [tempData appendBytes:&zero length:1];
                        }
                        
                        MTAesEncryptInplaceAndModifyIv(tempData, _aesKey, _aesRunningIv);
                        
                        alignedPartData = tempData;
                    }
                    
                    MTRequest *request = [[MTRequest alloc] init];
                    
                    TLRPCupload_saveFilePart$upload_saveFilePart *saveFilePart = [[TLRPCupload_saveFilePart$upload_saveFilePart alloc] init];
                    saveFilePart.file_id = _fileId;
                    saveFilePart.file_part = (int32_t)(isHeader ? 0 : ((_lateHeaderMode ? 1 : 0) + _doneParts.count + _uploadingParts.count));
                    saveFilePart.bytes = alignedPartData;
                    request.body = saveFilePart;
                    
                    int32_t partIndex = saveFilePart.file_part;
                    
                    TGLiveUploadPart *part = [[TGLiveUploadPart alloc] init];
                    part.partIndex = partIndex;
                    part.offset = isHeader ? 0 : processedSize;
                    part.length = currentPartSize;
                    part.cancelToken = request.internalId;
                    [_uploadingParts addObject:part];
                    
                    
                    __weak TGLiveUploadActor *weakSelf = self;
                    dispatch_queue_t transferQueue = _transferQueue;
                    [request setCompleted:^(__unused id result, __unused NSTimeInterval timestamp, id error)
                    {
                        dispatch_async(transferQueue, ^
                        {
                            __strong TGLiveUploadActor *strongSelf = weakSelf;
                            if (error == nil)
                                [strongSelf partUploadSuccess:partIndex];
                            else
                                [strongSelf partUploadFailed];
                        });
                    }];
                    
                    [_worker.strongWorker addRequest:request];
                }
                else
                {
                    [self _fail];
                    
                    return;
                }
            }
        }
    }
}

- (void)partUploadSuccess:(int32_t)partIndex
{
    if (_transferFinished)
        return;
    
    
    NSInteger index = -1;
    for (TGLiveUploadPart *part in _uploadingParts)
    {
        index++;
        if (part.partIndex == partIndex)
        {
            [_doneParts addObject:part];
            [_uploadingParts removeObjectAtIndex:(NSUInteger)index];
            
            break;
        }
    }
    
    [self _updateProgressValue];
    
    if (!_liveMode)
        [self notifyAboutProgress];
    
    [self _dequeuePartIfAny];
}

- (void)notifyAboutProgress
{
    [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"progress" message:@(_progressValue)];
}

- (void)partUploadFailed
{
    [self _fail];
}

- (TGLiveUploadActorData *)finishRestOfFile:(NSUInteger)finalSize
{
    NSUInteger alignedFinalSize = finalSize;
    
    if (_encryptFile)
    {
        while (alignedFinalSize % 16 != 0)
        {
            alignedFinalSize++;
        }
    }
    
    TGLiveUploadActorData *data = [[TGLiveUploadActorData alloc] init];
    [ActionStageInstance() requestActor:self.path options:nil flags:-1 watcher:data];
    data.path = self.path;
    
    dispatch_async(_transferQueue, ^
    {
        _liveMode = false;
        _availableSize = finalSize;
        
        [self _updateProgressValue];
        [self _dequeuePartIfAny];
    });
    
    return data;
}

- (TGLiveUploadActorData *)finishRestOfFileWithHeader:(NSData *)header finalSize:(NSUInteger)finalSize
{
    TGLiveUploadActorData *data = [[TGLiveUploadActorData alloc] init];
    [ActionStageInstance() requestActor:self.path options:nil flags:-1 watcher:data];
    data.path = self.path;
    
    dispatch_async(_transferQueue, ^
    {
        _liveMode = false;
        _lateHeaderMode = false;
        
        _availableSize = finalSize;
        _unfinishedHeaderData = header;
        
        for (TGLiveUploadPart *part in _uploadingParts)
        {
            part.offset += header.length;
        }
        
        for (TGLiveUploadPart *part in _doneParts)
        {
            part.offset += header.length;
        }
        
        _dataProvider = nil;
        
        [self _updateProgressValue];
        [self _dequeuePartIfAny];
    });
    
    return data;
}

- (void)completeWhenReady
{
    dispatch_async(_transferQueue, ^
    {
        _canComplete = true;
        
        [self _dequeuePartIfAny];
    });
}

- (float)progress
{
    return _progressValue;
}

- (void)cancel
{
    if (_workerToken != nil)
    {
        [[TGTelegramNetworking instance] cancelUploadWorkerRequestByToken:_workerToken];
        _workerToken = nil;
    }
    
    dispatch_async(_transferQueue, ^
    {
        for (TGLiveUploadPart *part in _uploadingParts)
        {
            [_worker.strongWorker cancelRequestByIdSoft:part.cancelToken];
        }
        [_uploadingParts removeAllObjects];
        
        [self _finishTransfer];
    });
    
    [super cancel];
}

@end
