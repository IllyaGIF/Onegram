#import "OGMediaFileSource.h"

#import <QuartzCore/QuartzCore.h>

#import "TL/TLMetaScheme.h"
#import "TGTelegraph.h"
#import "TGNetworkWorker.h"
#import "TGNetworkTypeManager.h"
#import "TGCdnFileData.h"
#import "TGDownloadMessagesSignal.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"

static const NSTimeInterval OGMediaFileSourceStallTimeout = 30.0;
static const NSTimeInterval OGMediaFileSourceStallCheckInterval = 5.0;

dispatch_queue_t OGMediaFetchQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.media-fetch", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface OGMediaFilePartRequest : NSObject

@property (nonatomic, strong) id token;
@property (nonatomic) int64_t offset;
@property (nonatomic) int32_t limit;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval lastActivityTime;
@property (nonatomic) uint32_t transferGeneration;
@property (nonatomic, strong) TGNetworkWorkerGuard *worker;
@property (nonatomic) bool mainConnection;
@property (nonatomic) bool cdn;
@property (nonatomic, copy) void (^progress)(int32_t, int32_t);
@property (nonatomic, copy) void (^completion)(OGMediaPartResult, NSData *);

@end

@implementation OGMediaFilePartRequest

@end

@interface OGMediaFileHashVerification : NSObject

@property (nonatomic) int64_t offset;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, copy) void (^completion)(OGMediaPartResult, NSData *);

@end

@implementation OGMediaFileHashVerification

@end

@interface OGMediaFileSource ()
{
    TLInputFileLocation *_location;
    NSInteger _datacenterId;
    int64_t _size;
    TGNetworkMediaTypeTag _mediaTypeTag;
    TGMediaOriginInfo *_originInfo;
    int64_t _identifier;

    bool _mainConnection;
    bool _invalidated;
    bool _updatingReference;
    bool _referenceRefreshed;
    bool _peerIdAdjusted;
    bool _reuploading;
    bool _stallCheckScheduled;

    NSMutableArray *_workerTokens;
    TGNetworkWorkerGuard *_primaryWorker;
    TGNetworkWorkerGuard *_secondaryWorker;
    NSUInteger _nextWorker;

    TGCdnFileData *_cdnFileData;
    NSMutableDictionary *_cdnHashes;
    NSMutableSet *_cdnHashRequests;
    NSMutableArray *_pendingVerifications;

    NSMutableDictionary *_requests;

    SMetaDisposable *_referenceDisposable;
    SMetaDisposable *_reuploadDisposable;
    NSMutableDictionary *_hashDisposables;
}

@end

@implementation OGMediaFileSource

- (instancetype)initWithLocation:(TLInputFileLocation *)location datacenterId:(NSInteger)datacenterId size:(int64_t)size mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag originInfo:(TGMediaOriginInfo *)originInfo identifier:(int64_t)identifier
{
    self = [super init];
    if (self != nil)
    {
        _location = location;
        _datacenterId = datacenterId;
        _size = size;
        _mediaTypeTag = mediaTypeTag;
        _originInfo = originInfo;
        _identifier = identifier;
        _workerTokens = [[NSMutableArray alloc] init];
        _requests = [[NSMutableDictionary alloc] init];
        _cdnHashes = [[NSMutableDictionary alloc] init];
        _cdnHashRequests = [[NSMutableSet alloc] init];
        _pendingVerifications = [[NSMutableArray alloc] init];
        _hashDisposables = [[NSMutableDictionary alloc] init];
        _referenceDisposable = [[SMetaDisposable alloc] init];
        _reuploadDisposable = [[SMetaDisposable alloc] init];

        _mainConnection = datacenterId == [[TGTelegramNetworking instance] masterDatacenterId] && size < 1024 * 1024;
        if (!_mainConnection)
            [self requestWorkersForDatacenterId:datacenterId cdn:false];
    }
    return self;
}

- (void)dealloc
{
    [self invalidate];
}

- (bool)available
{
    return !_invalidated && !_updatingReference && !_reuploading && ((_mainConnection && _cdnFileData == nil) || _primaryWorker != nil);
}

- (bool)usesCdn
{
    return _cdnFileData != nil;
}

- (void)notifyAvailability
{
    if (self.available && _availabilityChanged != nil)
        _availabilityChanged();
}

- (void)requestWorkersForDatacenterId:(NSInteger)datacenterId cdn:(bool)cdn
{
    NSUInteger count = _size >= 4 * 1024 * 1024 ? 2 : 1;
    for (NSUInteger i = 0; i < count; i++)
    {
        __weak OGMediaFileSource *weakSelf = self;
        id token = [[TGTelegramNetworking instance] requestDownloadWorkerForDatacenterId:datacenterId type:_mediaTypeTag isCdn:cdn completion:^(TGNetworkWorkerGuard *worker)
        {
            dispatch_async(OGMediaFetchQueue(), ^
            {
                OGMediaFileSource *strongSelf = weakSelf;
                if (strongSelf == nil || strongSelf->_invalidated || (strongSelf->_cdnFileData != nil) != cdn)
                {
                    [worker releaseWorker];
                    return;
                }
                [strongSelf attachWorker:worker];
            });
        }];
        if (token != nil)
            [_workerTokens addObject:token];
    }
}

- (void)attachWorker:(TGNetworkWorkerGuard *)worker
{
    if (_primaryWorker == nil)
        _primaryWorker = worker;
    else if (_secondaryWorker == nil)
        _secondaryWorker = worker;
    else
    {
        [worker releaseWorker];
        return;
    }
    [self notifyAvailability];
}

- (void)releaseWorkers
{
    for (id token in _workerTokens)
        [[TGTelegramNetworking instance] cancelDownloadWorkerRequestByToken:token];
    [_workerTokens removeAllObjects];
    [_primaryWorker releaseWorker];
    [_secondaryWorker releaseWorker];
    _primaryWorker = nil;
    _secondaryWorker = nil;
}

- (TGNetworkWorkerGuard *)nextWorker
{
    if (_secondaryWorker != nil && (_nextWorker++ % 2) == 1)
        return _secondaryWorker;
    return _primaryWorker;
}

- (id)requestPartAtOffset:(int64_t)offset limit:(int32_t)limit progress:(void (^)(int32_t, int32_t))progress completion:(void (^)(OGMediaPartResult, NSData *))completion
{
    if (!self.available)
        return nil;

    MTRequest *request = [[MTRequest alloc] init];
    if (_cdnFileData != nil)
    {
        TLRPCupload_getCdnFile$upload_getCdnFile *getFile = [[TLRPCupload_getCdnFile$upload_getCdnFile alloc] init];
        getFile.file_token = _cdnFileData.token;
        getFile.offset = (int32_t)offset;
        getFile.limit = limit;
        [request setBody:getFile];
    }
    else
    {
        TLRPCupload_getFile$upload_getFile *getFile = [[TLRPCupload_getFile$upload_getFile alloc] init];
        getFile.location = _location;
        getFile.offset = offset;
        getFile.limit = limit;
        [request setBody:getFile];
    }

    OGMediaFilePartRequest *part = [[OGMediaFilePartRequest alloc] init];
    part.token = request.internalId;
    part.offset = offset;
    part.limit = limit;
    part.startTime = CACurrentMediaTime();
    part.lastActivityTime = part.startTime;
    part.transferGeneration = [TGNetworkTypeManager transferParametersForUpload:false].generation;
    part.mainConnection = _mainConnection && _cdnFileData == nil;
    part.cdn = _cdnFileData != nil;
    part.worker = part.mainConnection ? nil : [self nextWorker];
    part.progress = progress;
    part.completion = completion;
    _requests[part.token] = part;

    id token = part.token;
    __weak OGMediaFileSource *weakSelf = self;
    request.completed = ^(id result, __unused NSTimeInterval timestamp, MTRpcError *error)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf partCompleted:token result:result error:error];
        });
    };
    request.progressUpdated = ^(float value, NSUInteger packetLength)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf partProgressed:token received:(int32_t)(value * (float)packetLength) total:(int32_t)packetLength];
        });
    };

    if (part.mainConnection)
        [[TGTelegramNetworking instance] addRequest:request];
    else
        [part.worker.strongWorker addRequest:request];

    [self scheduleStallCheck];
    return token;
}

- (void)cancelRequest:(OGMediaFilePartRequest *)part
{
    if (part.mainConnection)
        [TGTelegraphInstance cancelRequestByToken:part.token];
    else
        [part.worker.strongWorker cancelRequestById:part.token];
}

- (void)cancelPart:(id)token
{
    if (token == nil)
        return;
    OGMediaFilePartRequest *part = _requests[token];
    if (part == nil)
        return;
    [_requests removeObjectForKey:token];
    [self cancelRequest:part];
}

- (void)invalidate
{
    if (_invalidated)
        return;
    _invalidated = true;
    for (OGMediaFilePartRequest *part in [_requests allValues])
        [self cancelRequest:part];
    [_requests removeAllObjects];
    [_pendingVerifications removeAllObjects];
    for (id<SDisposable> disposable in [_hashDisposables allValues])
        [disposable dispose];
    [_hashDisposables removeAllObjects];
    [_referenceDisposable dispose];
    [_reuploadDisposable dispose];
    [self releaseWorkers];
}

- (void)partProgressed:(id)token received:(int32_t)received total:(int32_t)total
{
    OGMediaFilePartRequest *part = _requests[token];
    if (part == nil)
        return;
    part.lastActivityTime = CACurrentMediaTime();
    if (part.progress != nil)
        part.progress(received, total);
}

- (void)finishPart:(OGMediaFilePartRequest *)part result:(OGMediaPartResult)result data:(NSData *)data
{
    void (^completion)(OGMediaPartResult, NSData *) = part.completion;
    if (completion != nil)
        completion(result, data);
}

- (void)partCompleted:(id)token result:(id)result error:(MTRpcError *)error
{
    OGMediaFilePartRequest *part = _requests[token];
    if (part == nil || _invalidated)
        return;
    [_requests removeObjectForKey:token];

    if (error != nil)
    {
        [self handleError:error part:part];
        return;
    }

    if ([result isKindOfClass:[TLupload_File$upload_file class]])
    {
        NSData *bytes = ((TLupload_File$upload_file *)result).bytes;
        [TGNetworkTypeManager recordTransferBytes:(int64_t)bytes.length started:part.startTime upload:false generation:part.transferGeneration];
        [self finishPart:part result:OGMediaPartResultData data:bytes != nil ? bytes : [NSData data]];
    }
    else if ([result isKindOfClass:[TLupload_File$upload_fileCdnRedirect class]])
    {
        TLupload_File$upload_fileCdnRedirect *redirect = (TLupload_File$upload_fileCdnRedirect *)result;
        [self switchToCdn:[[TGCdnFileData alloc] initWithCdnId:redirect.dc_id token:redirect.file_token encryptionKey:redirect.encryption_key encryptionIv:redirect.encryption_iv] hashes:redirect.file_hashes];
        [self finishPart:part result:OGMediaPartResultRestart data:nil];
    }
    else if ([result isKindOfClass:[TLupload_CdnFile$upload_cdnFile class]])
    {
        if (!part.cdn || _cdnFileData == nil)
        {
            [self finishPart:part result:OGMediaPartResultRestart data:nil];
            return;
        }
        NSData *bytes = ((TLupload_CdnFile$upload_cdnFile *)result).bytes;
        [TGNetworkTypeManager recordTransferBytes:(int64_t)bytes.length started:part.startTime upload:false generation:part.transferGeneration];
        NSData *data = [NSData data];
        if (bytes.length != 0)
        {
            NSMutableData *iv = [[NSMutableData alloc] initWithData:_cdnFileData.encryptionIv];
            uint32_t counter = NSSwapHostIntToBig((uint32_t)(part.offset / 16));
            memcpy((uint8_t *)iv.mutableBytes + iv.length - 4, &counter, 4);
            data = MTAesCtrDecrypt(bytes, _cdnFileData.encryptionKey, iv);
        }
        OGMediaFileHashVerification *verification = [[OGMediaFileHashVerification alloc] init];
        verification.offset = part.offset;
        verification.data = data;
        verification.completion = part.completion;
        [self verify:verification];
    }
    else if ([result isKindOfClass:[TLupload_CdnFile$upload_cdnFileReuploadNeeded class]])
    {
        [self reuploadWithRequestToken:((TLupload_CdnFile$upload_cdnFileReuploadNeeded *)result).request_token];
        [self finishPart:part result:OGMediaPartResultRestart data:nil];
    }
    else
    {
        [self finishPart:part result:OGMediaPartResultFailure data:nil];
    }
}

- (void)handleError:(MTRpcError *)error part:(OGMediaFilePartRequest *)part
{
    int32_t errorCode = [[TGTelegramNetworking instance] extractNetworkErrorCode:error];
    NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];

    if (errorCode <= 0 || errorCode >= 420)
        [TGNetworkTypeManager recordTransferFailureForUpload:false generation:part.transferGeneration];

    if (errorCode == 400 && [errorType hasPrefix:@"FILE_REFERENCE_"] && _originInfo != nil && !_referenceRefreshed && !part.cdn)
    {
        [self refreshFileReference];
        [self finishPart:part result:OGMediaPartResultRestart data:nil];
        return;
    }

    if (errorCode == 400 && ([errorType isEqualToString:@"PEER_ID_INVALID"] || [errorType isEqualToString:@"CHANNEL_INVALID"]) && !_peerIdAdjusted && [_location isKindOfClass:[TLInputFileLocation$inputPeerPhotoFileLocation class]])
    {
        TLInputFileLocation$inputPeerPhotoFileLocation *location = (TLInputFileLocation$inputPeerPhotoFileLocation *)_location;
        if (location.peer_id > 0 && location.peer_id < INT32_MAX)
        {
            _peerIdAdjusted = true;
            location.peer_id = location.peer_id + ((int64_t)UINT32_MAX + 1);
            [self finishPart:part result:OGMediaPartResultRestart data:nil];
            return;
        }
    }

    if (errorCode <= 0 || errorCode == 420 || errorCode >= 500)
        [self finishPart:part result:OGMediaPartResultRetry data:nil];
    else
        [self finishPart:part result:OGMediaPartResultFailure data:nil];
}

- (void)scheduleStallCheck
{
    if (_stallCheckScheduled || _invalidated || _requests.count == 0)
        return;
    _stallCheckScheduled = true;
    __weak OGMediaFileSource *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(OGMediaFileSourceStallCheckInterval * NSEC_PER_SEC)), OGMediaFetchQueue(), ^
    {
        OGMediaFileSource *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_stallCheckScheduled = false;
        [strongSelf checkStalledParts];
        [strongSelf scheduleStallCheck];
    });
}

- (void)checkStalledParts
{
    if (_invalidated)
        return;
    NSTimeInterval now = CACurrentMediaTime();
    NSMutableArray *stalled = [[NSMutableArray alloc] init];
    for (OGMediaFilePartRequest *part in [_requests allValues])
    {
        if (now - part.lastActivityTime >= OGMediaFileSourceStallTimeout)
            [stalled addObject:part];
    }
    for (OGMediaFilePartRequest *part in stalled)
    {
        [_requests removeObjectForKey:part.token];
        [self cancelRequest:part];
        [TGNetworkTypeManager recordTransferFailureForUpload:false generation:part.transferGeneration];
        [self finishPart:part result:OGMediaPartResultRetry data:nil];
    }
}

- (void)refreshFileReference
{
    if (_updatingReference)
        return;
    _updatingReference = true;
    __weak OGMediaFileSource *weakSelf = self;
    [_referenceDisposable setDisposable:[[TGDownloadMessagesSignal updatedOriginInfo:_originInfo identifier:_identifier] startWithNext:^(TGMediaOriginInfo *next)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf applyOriginInfo:next];
        });
    } error:^(__unused id error)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf applyOriginInfo:nil];
        });
    } completed:nil]];
}

- (void)applyOriginInfo:(TGMediaOriginInfo *)originInfo
{
    if (!_updatingReference || _invalidated)
        return;
    _updatingReference = false;
    _referenceRefreshed = true;

    NSData *fileReference = nil;
    if (originInfo != nil)
    {
        _originInfo = originInfo;
        if ([_location isKindOfClass:[TLInputFileLocation$inputDocumentFileLocation class]])
        {
            TLInputFileLocation$inputDocumentFileLocation *location = (TLInputFileLocation$inputDocumentFileLocation *)_location;
            fileReference = [originInfo fileReferenceForDocumentId:location.n_id accessHash:location.access_hash];
            if (fileReference.length == 0)
                fileReference = [originInfo fileReference];
            location.file_reference = fileReference;
        }
        else if ([_location isKindOfClass:[TLInputFileLocation$inputPhotoFileLocation class]])
        {
            TLInputFileLocation$inputPhotoFileLocation *location = (TLInputFileLocation$inputPhotoFileLocation *)_location;
            fileReference = [originInfo fileReference];
            location.file_reference = fileReference;
        }
        else if ([_location isKindOfClass:[TLInputFileLocation$inputFileLocation class]])
        {
            TLInputFileLocation$inputFileLocation *location = (TLInputFileLocation$inputFileLocation *)_location;
            fileReference = [originInfo fileReferenceForVolumeId:location.volume_id localId:location.local_id];
            location.file_reference = fileReference;
        }
    }
    if (fileReference.length == 0)
        _originInfo = nil;
    [self notifyAvailability];
}

- (void)switchToCdn:(TGCdnFileData *)fileData hashes:(NSArray *)hashes
{
    if (_cdnFileData != nil)
        return;
    _cdnFileData = fileData;
    [self mergeHashes:hashes];
    [self releaseWorkers];
    [self requestWorkersForDatacenterId:fileData.cdnId cdn:true];
}

- (void)reuploadWithRequestToken:(NSData *)requestToken
{
    if (_reuploading || _cdnFileData == nil)
        return;
    _reuploading = true;
    TLRPCupload_reuploadCdnFile$upload_reuploadCdnFile *reupload = [[TLRPCupload_reuploadCdnFile$upload_reuploadCdnFile alloc] init];
    reupload.file_token = _cdnFileData.token;
    reupload.request_token = requestToken;
    __weak OGMediaFileSource *weakSelf = self;
    void (^finished)(void) = ^
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            OGMediaFileSource *strongSelf = weakSelf;
            if (strongSelf == nil || !strongSelf->_reuploading)
                return;
            strongSelf->_reuploading = false;
            [strongSelf notifyAvailability];
        });
    };
    [_reuploadDisposable setDisposable:[[[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:_datacenterId type:TGNetworkMediaTypeTagGeneric] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker)
    {
        return [[TGTelegramNetworking instance] requestSignal:reupload worker:worker];
    }] startWithNext:^(__unused id next)
    {
        finished();
    } error:^(__unused id error)
    {
        finished();
    } completed:nil]];
}

- (void)mergeHashes:(NSArray *)hashes
{
    for (TLFileHash$fileHash *hash in hashes)
    {
        if ([hash isKindOfClass:[TLFileHash$fileHash class]] && hash.n_hash != nil)
            _cdnHashes[@((int64_t)hash.offset)] = hash;
    }
}

- (NSNumber *)missingHashOffsetForVerification:(OGMediaFileHashVerification *)verification
{
    int64_t end = verification.offset + (int64_t)verification.data.length;
    int64_t cursor = verification.offset;
    while (cursor < end)
    {
        TLFileHash$fileHash *hash = _cdnHashes[@(cursor)];
        if (hash == nil || hash.limit <= 0)
            return @(cursor);
        cursor += hash.limit;
    }
    return nil;
}

- (bool)hashesMatchVerification:(OGMediaFileHashVerification *)verification
{
    const uint8_t *bytes = (const uint8_t *)verification.data.bytes;
    int64_t length = (int64_t)verification.data.length;
    int64_t local = 0;
    while (local < length)
    {
        TLFileHash$fileHash *hash = _cdnHashes[@(verification.offset + local)];
        int64_t chunk = MIN((int64_t)hash.limit, length - local);
        NSData *digest = MTSha256([[NSData alloc] initWithBytesNoCopy:(void *)(bytes + local) length:(NSUInteger)chunk freeWhenDone:false]);
        if (![digest isEqualToData:hash.n_hash])
            return false;
        local += hash.limit;
    }
    return true;
}

- (void)verify:(OGMediaFileHashVerification *)verification
{
    NSNumber *missing = [self missingHashOffsetForVerification:verification];
    if (missing != nil)
    {
        [_pendingVerifications addObject:verification];
        [self requestHashesAtOffset:missing];
        return;
    }
    bool valid = [self hashesMatchVerification:verification];
    if (!valid)
        TGLog(@"[OGMediaFileSource CDN hash mismatch at %lld]", (long long)verification.offset);
    verification.completion(valid ? OGMediaPartResultData : OGMediaPartResultFailure, valid ? verification.data : nil);
}

- (void)requestHashesAtOffset:(NSNumber *)offset
{
    if ([_cdnHashRequests containsObject:offset] || _cdnFileData == nil)
        return;
    [_cdnHashRequests addObject:offset];
    TLRPCupload_getCdnFileHashes$upload_getCdnFileHashes *getHashes = [[TLRPCupload_getCdnFileHashes$upload_getCdnFileHashes alloc] init];
    getHashes.file_token = _cdnFileData.token;
    getHashes.offset = (int32_t)[offset longLongValue];
    __weak OGMediaFileSource *weakSelf = self;
    SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
    _hashDisposables[offset] = disposable;
    [disposable setDisposable:[[[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:_datacenterId type:TGNetworkMediaTypeTagGeneric] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker)
    {
        return [[TGTelegramNetworking instance] requestSignal:getHashes worker:worker];
    }] startWithNext:^(NSArray *hashes)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf hashesReceived:hashes offset:offset];
        });
    } error:^(__unused id error)
    {
        dispatch_async(OGMediaFetchQueue(), ^
        {
            [weakSelf hashesReceived:nil offset:offset];
        });
    } completed:nil]];
}

- (void)hashesReceived:(NSArray *)hashes offset:(NSNumber *)offset
{
    if (_invalidated)
        return;
    [_cdnHashRequests removeObject:offset];
    [_hashDisposables removeObjectForKey:offset];
    [self mergeHashes:hashes];

    NSArray *pending = [_pendingVerifications copy];
    [_pendingVerifications removeAllObjects];
    for (OGMediaFileHashVerification *verification in pending)
    {
        NSNumber *missing = [self missingHashOffsetForVerification:verification];
        if (missing == nil)
            [self verify:verification];
        else if ([missing isEqualToNumber:offset] || hashes.count == 0)
            verification.completion(OGMediaPartResultRetry, nil);
        else
        {
            [_pendingVerifications addObject:verification];
            [self requestHashesAtOffset:missing];
        }
    }
}

@end
