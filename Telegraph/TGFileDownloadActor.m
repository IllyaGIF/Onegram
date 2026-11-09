#import "TGFileDownloadActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTelegraph.h"

#import "TGTelegramNetworking.h"
#import "OGMediaFetchSession.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGImageInfo+Telegraph.h"

#import "TGAppDelegate.h"

@interface TGFileDownloadActor () <TGRawHttpActor>
{
    NSData *_encryptionKey;
    NSData *_encryptionIv;
    
    int _finalFileSize;
    bool _thumbnailOnly;
    
    SMetaDisposable *_disposable;
    id _lifetimeToken;
}

@property (nonatomic) bool alreadyCompleted;

- (bool)isCurrentLifetimeToken:(id)token;

@end

static TGFileDownloadActor *TGFileDownloadActorResolve(NSString *path, id token)
{
    TGFileDownloadActor *actor = (TGFileDownloadActor *)[ActionStageInstance() executingActorWithPath:path];
    if (actor == nil || ![actor isCurrentLifetimeToken:token])
        return nil;
    return actor;
}

@implementation TGFileDownloadActor

+ (NSString *)genericPath
{
    return @"/tg/file/@";
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
        _lifetimeToken = [[NSObject alloc] init];
    return self;
}

- (bool)isCurrentLifetimeToken:(id)token
{
    return _lifetimeToken == token;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)prepare:(NSDictionary *)options
{
    NSString *queueName = [options objectForKey:@"queueName"];
    if ([queueName isKindOfClass:[NSString class]])
        self.requestQueueName = queueName;
}

- (void)execute:(NSDictionary *)options
{
    _thumbnailOnly = [options[@"thumbnailOnly"] boolValue];
    NSString *url = [options objectForKey:@"url"];
    
    if ([url hasPrefix:@"upload/"])
    {
        NSString *localFileUrl = [url substringFromIndex:7];
        NSString *imagePath = [[[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"upload"] stringByAppendingPathComponent:localFileUrl];
        
        NSData *data = [[NSData alloc] initWithContentsOfFile:imagePath];
        
        if (data == nil)
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        else
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
        
        return;
    }
    else if ([url hasPrefix:@"file://"])
    {
        NSData *data = [[NSData alloc] initWithContentsOfFile:[url substringFromIndex:@"file://".length]];
        
        if (data == nil)
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        else
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
        
        return;
    }
    else if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.001f];
        self.cancelToken = [TGTelegraphInstance doRequestRawHttp:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] maxRetryCount:3 acceptCodes:nil actor:self];
        return;
    }
    else if ([url hasPrefix:@"mt-encrypted-file://?"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[url substringFromIndex:@"mt-encrypted-file://?".length]];
        
        if (args[@"dc"] == nil || args[@"id"] == nil || args[@"accessHash"] == nil || args[@"key"] == nil)
        {
            [ActionStageInstance() actionFailed:self.path reason:-1];
            return;
        }
        else
        {
            int dcId = [args[@"dc"] intValue];
            int64_t fileId = [args[@"id"] longLongValue];
            int64_t accessHash = [args[@"accessHash"] longLongValue];
            
            NSData *key = [args[@"key"] dataByDecodingHexString];
            
            int64_t size = [args[@"size"] intValue];
            
            _finalFileSize = [args[@"decryptedSize"] intValue];
            
            if (key.length != 64)
            {
                TGLog(@"***** Invalid file key length");
                [ActionStageInstance() actionFailed:self.path reason:-1];
            }
            else
            {
                _encryptionKey = [key subdataWithRange:NSMakeRange(0, 32)];
                _encryptionIv = [key subdataWithRange:NSMakeRange(32, 32)];
                
                TLInputFileLocation$inputEncryptedFileLocation *location = [[TLInputFileLocation$inputEncryptedFileLocation alloc] init];
                location.n_id = fileId;
                location.access_hash = accessHash;
                
                [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.001f];
                
                OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
                descriptor.location = location;
                descriptor.datacenterId = dcId;
                descriptor.size = size;
                descriptor.encryptionKey = _encryptionKey;
                descriptor.encryptionIv = _encryptionIv;
                descriptor.decryptedSize = _finalFileSize;
                descriptor.mediaTypeTag = (TGNetworkMediaTypeTag)[options[@"mediaTypeTag"] intValue];
                [self fetchDescriptor:descriptor encrypted:true];
            }
        }
        
        return;
    }
    
    int64_t volumeId = 0;
    int fileId = 0;
    int64_t secret = 0;
    int datacenterId = 0;
    NSString *fileReferenceStr = nil;
    
    if (extractFileUrlComponentsWithFileRef(url, &datacenterId, &volumeId, &fileId, &secret, &fileReferenceStr) && datacenterId != 0)
    {
        [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.001f];
        
        TGMediaOriginInfo *originInfo = options[@"originInfo"];
        if (originInfo == nil && fileReferenceStr != nil)
        {
            NSString *decoded = (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (__bridge CFStringRef)fileReferenceStr, CFSTR(""), kCFStringEncodingUTF8);
            fileReferenceStr = decoded;
            
            if ([fileReferenceStr hasPrefix:@"o"]) {
                NSString *originStr = [fileReferenceStr substringFromIndex:1];
                originInfo = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:originStr];
            } else {
                NSData *fileReference = [NSData dataWithHexString:fileReferenceStr];
                NSString *key = [NSString stringWithFormat:@"%lld_%d", volumeId, fileId];
                originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:fileReference fileReferences:@{key: fileReference}];
            }
        }
        
        TLInputFileLocation$inputFileLocation *location = [[TLInputFileLocation$inputFileLocation alloc] init];
        location.volume_id = volumeId;
        location.local_id = fileId;
        location.secret = secret;
        location.file_reference = [originInfo fileReferenceForVolumeId:volumeId localId:fileId] ?: [NSData data];
        
        OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
        descriptor.location = location;
        descriptor.datacenterId = datacenterId;
        descriptor.originInfo = originInfo;
        descriptor.mediaTypeTag = (TGNetworkMediaTypeTag)[options[@"mediaTypeTag"] intValue];
        [self fetchDescriptor:descriptor encrypted:false];
    }
    else
    {
        [ActionStageInstance() nodeRetrieveFailed:self.path];
    }
}
    
- (void)fetchDescriptor:(OGMediaFetchDescriptor *)descriptor encrypted:(bool)encrypted
{
    int64_t limit = _thumbnailOnly ? 512 * 1024 : 1024 * 1024;
    descriptor.preferredPartSize = (int32_t)limit;
    int64_t finalSize = _finalFileSize;
    NSString *actorPath = [self.path copy];
    id lifetimeToken = _lifetimeToken;
    NSMutableData *data = [[NSMutableData alloc] init];
    SSignal *signal = OGMediaFetchSequentialSignal(descriptor, 0, _thumbnailOnly ? limit : INT64_MAX, ^(float progress)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [TGFileDownloadActorResolve(actorPath, lifetimeToken) fileDownloadProgress:progress];
        }];
    });
    if (_disposable == nil)
        _disposable = [[SMetaDisposable alloc] init];
    [_disposable setDisposable:[signal startWithNext:^(NSData *chunk)
    {
        [data appendData:chunk];
    } error:^(__unused id error)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGFileDownloadActor *actor = TGFileDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil || actor.alreadyCompleted)
                return;
            if (encrypted)
                [ActionStageInstance() actionFailed:actorPath reason:-1];
            else
                [ActionStageInstance() nodeRetrieveFailed:actorPath];
        }];
    } completed:^
    {
        if (finalSize > 0 && (int64_t)data.length > finalSize)
            [data setLength:(NSUInteger)finalSize];
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGFileDownloadActor *actor = TGFileDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil || actor.alreadyCompleted)
                return;
            [ActionStageInstance() nodeRetrieved:actorPath node:[[SGraphObjectNode alloc] initWithObject:data]];
        }];
    }]];
}

- (void)completeWithData:(NSData *)data
{
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    [_disposable dispose];
    
    _alreadyCompleted = true;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
}

- (void)fileDownloadProgress:(float)progress
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveProgress:self.path progress:MAX(0.001f, progress)];
}

- (void)httpRequestSuccess:(NSString *)__unused url response:(NSData *)response
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:response]];
}

- (void)httpRequestProgress:(NSString *)__unused url progress:(float)progress
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveProgress:self.path progress:MAX(0.001f, progress)];
}

- (void)httpRequestFailed:(NSString *)__unused url
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)cancel
{
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    
    [_disposable dispose];
    
    [super cancel];
}

@end
