/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMultipartFileDownloadActor.h"

#import "TL/TLMetaScheme.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegramNetworking.h"
#import "OGMediaFetchSession.h"

static const int64_t TGMultipartFileThumbnailLimit = 512 * 1024;

@interface TGMultipartFileDownloadActor ()
{
    OGMediaFetchSession *_session;
    OGMediaFetchObserver *_observer;
    id _demand;
    id _lifetimeToken;
}

- (bool)isCurrentLifetimeToken:(id)token;
- (void)releaseSession;

@end

static TGMultipartFileDownloadActor *TGMultipartFileDownloadActorResolve(NSString *path, id token)
{
    TGMultipartFileDownloadActor *actor = (TGMultipartFileDownloadActor *)[ActionStageInstance() executingActorWithPath:path];
    if (actor == nil || ![actor isCurrentLifetimeToken:token])
        return nil;
    return actor;
}

@implementation TGMultipartFileDownloadActor

+ (NSString *)genericPath
{
    return @"/tg/multipart-file/@";
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _lifetimeToken = [[NSObject alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self releaseSession];
}

- (bool)isCurrentLifetimeToken:(id)token
{
    return _lifetimeToken == token;
}

- (void)execute:(NSDictionary *)options
{
    TLInputFileLocation *location = options[@"fileLocation"];
    NSString *storeFilePath = options[@"storeFilePath"];
    bool thumbnailOnly = [options[@"thumbnailOnly"] boolValue];
    int64_t size = [options[@"encryptedSize"] longLongValue];

    if (location == nil || storeFilePath.length == 0 || (thumbnailOnly && size > TGMultipartFileThumbnailLimit))
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
        return;
    }

    OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
    descriptor.location = location;
    descriptor.datacenterId = [options[@"datacenterId"] integerValue];
    descriptor.size = size;
    descriptor.decryptedSize = [options[@"decryptedSize"] longLongValue];
    descriptor.encryptionKey = options[@"encryptionArgs"][@"key"];
    descriptor.encryptionIv = options[@"encryptionArgs"][@"iv"];
    descriptor.mediaTypeTag = (TGNetworkMediaTypeTag)[options[@"mediaTypeTag"] intValue];
    descriptor.originInfo = options[@"originInfo"];
    descriptor.identifier = [options[@"identifier"] longLongValue];
    NSString *tempStoreFilePath = options[@"tempStoreFilePath"];
    descriptor.storePath = tempStoreFilePath.length != 0 ? tempStoreFilePath : [storeFilePath stringByAppendingString:@".parts"];
    descriptor.sizeLimit = thumbnailOnly ? TGMultipartFileThumbnailLimit : 0;

    NSString *actorPath = [self.path copy];
    id lifetimeToken = _lifetimeToken;
    OGMediaFetchObserver *observer = [[OGMediaFetchObserver alloc] init];
    observer.wantsData = [options[@"completeWithData"] boolValue];
    observer.progress = ^(float progress)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (TGMultipartFileDownloadActorResolve(actorPath, lifetimeToken) != nil)
                [ActionStageInstance() dispatchMessageToWatchers:actorPath messageType:@"progress" message:[[NSNumber alloc] initWithFloat:progress]];
        }];
    };
    bool completeWithData = observer.wantsData;
    observer.completed = ^(__unused NSString *path, NSData *data)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGMultipartFileDownloadActor *actor = TGMultipartFileDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil)
                return;
            [actor releaseSession];
            if (completeWithData && data == nil)
                [ActionStageInstance() actionFailed:actorPath reason:-1];
            else
                [ActionStageInstance() actionCompleted:actorPath result:data];
        }];
    };
    observer.failed = ^
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGMultipartFileDownloadActor *actor = TGMultipartFileDownloadActorResolve(actorPath, lifetimeToken);
            if (actor == nil)
                return;
            [actor releaseSession];
            [ActionStageInstance() actionFailed:actorPath reason:-1];
        }];
    };

    OGMediaFetchPriority priority = descriptor.mediaTypeTag == TGNetworkMediaTypeTagImage ? OGMediaFetchPriorityInteractive : OGMediaFetchPriorityDownload;
    _session = [OGMediaFetchSession acquireSessionForDescriptor:descriptor];
    _observer = observer;
    [_session addPublishPath:storeFilePath];
    [_session addObserver:observer];
    _demand = [_session addDemandFrom:0 to:INT64_MAX priority:priority];
}

- (void)watcherJoined:(ASHandle *)watcherHandle options:(NSDictionary *)options waitingInActorQueue:(bool)waitingInActorQueue
{
    [super watcherJoined:watcherHandle options:options waitingInActorQueue:waitingInActorQueue];

    NSString *storeFilePath = options[@"storeFilePath"];
    if (storeFilePath.length != 0)
        [_session addPublishPath:storeFilePath];
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

- (void)cancel
{
    [self releaseSession];

    [super cancel];
}

@end
