#import "TGICloudFileDownloadActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGFileUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

const NSTimeInterval TGICloudFileDownloadProgressTimerInterval = 1.0f;

@interface TGICloudFileDownloadRequest : NSObject
{
    bool _addedProgressObserver;
    bool _discardedMetadataQuery;
}

@property (nonatomic, copy) void(^progressBlock)(CGFloat progress);
@property (nonatomic, copy) void(^completionBlock)(bool succeed);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
@property (nonatomic, readonly) NSFileCoordinator *fileCoordinator;
@property (nonatomic, readonly) NSMetadataQuery *metadataQuery;
#else
@property (nonatomic, readonly) id fileCoordinator;
@property (nonatomic, readonly) id metadataQuery;
#endif

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *path;
@property (nonatomic, assign) bool downloaded;
@property (nonatomic, assign) bool cancelled;

- (void)cancel;
- (void)dispose;

+ (TGICloudFileDownloadRequest *)downloadFileAtUrl:(NSURL *)url path:(NSURL *)path progressBlock:(void (^)(CGFloat progress))progressBlock completionBlock:(void (^)(bool succeed))completionBlock;

@end

@implementation TGICloudFileDownloadRequest

+ (TGICloudFileDownloadRequest *)downloadFileAtUrl:(NSURL *)url path:(NSURL *)path progressBlock:(void (^)(CGFloat progress))progressBlock completionBlock:(void (^)(bool succeed))completionBlock
{
    TGICloudFileDownloadRequest *request = [[TGICloudFileDownloadRequest alloc] init];
    request.url = url;
    request.path = path;
    
    request.progressBlock = progressBlock;
    request.completionBlock = completionBlock;
    
    [request start];
    
    return request;
}

- (void)start
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
    NSString *sourcePath = self.url.path;
    NSString *targetPath = self.path.path;
    if (sourcePath.length == 0 || targetPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
    {
        if (self.completionBlock != nil)
            self.completionBlock(false);
        return;
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:[targetPath stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:nil];
    NSError *copyError = nil;
    bool succeed = [sourcePath isEqualToString:targetPath];
    if (!succeed)
    {
        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
        succeed = [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:targetPath error:&copyError];
    }
    if (succeed)
    {
        self.downloaded = true;
        if (self.progressBlock != nil)
            self.progressBlock(1.0f);
    }
    if (self.completionBlock != nil)
        self.completionBlock(succeed);
    return;
#else
    NSError *error;
    bool isRemoteFile = false;
    bool isCurrent = true;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    NSDictionary *fileAttributes = [self.url resourceValuesForKeys:@[ NSURLUbiquitousItemDownloadingStatusKey ] error:&error];
    
    if (fileAttributes != nil)
    {
        NSString *downloadingStatusAttribute = fileAttributes[NSURLUbiquitousItemDownloadingStatusKey];
        
        if (downloadingStatusAttribute != nil)
        {
            isRemoteFile = true;
            if (![downloadingStatusAttribute isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent])
                isCurrent = false;
        }
    }
#else
    NSDictionary *fileAttributes = [self.url resourceValuesForKeys:@[ NSURLUbiquitousItemIsDownloadingKey ] error:&error];
    if (fileAttributes != nil)
    {
        NSNumber *isDownloading = fileAttributes[NSURLUbiquitousItemIsDownloadingKey];
        if (isDownloading != nil)
        {
            isRemoteFile = true;
            isCurrent = ![isDownloading boolValue];
        }
    }
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    bool succeed = [self.url startAccessingSecurityScopedResource];
    if (!succeed)
    {
        TGLog(@"Cloud ERROR: failed to start accessing security scoped resource: %@", self.url);
        if (self.completionBlock != nil)
            self.completionBlock(false);
        return;
    }
#endif
    
    void (^downloadCompletionBlock)(NSURL *) = ^(NSURL *url)
    {
        if (self.progressBlock != nil)
            self.progressBlock(1.0f);
        
        self.downloaded = true;
        
        [[NSFileManager defaultManager] createDirectoryAtPath:[self.path.path stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:nil];
        
        
        NSError *fileCopyError;
        if (![[NSFileManager defaultManager] copyItemAtPath:url.path toPath:self.path.path error:&fileCopyError])
        {
            TGLog(@"Cloud ERROR: failed to copy security scoped resource from %@ to %@ with error: %@", url, self.path, fileCopyError);
            if (self.completionBlock != nil)
            self.completionBlock(false);
            return;
        }
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        [url stopAccessingSecurityScopedResource];
#endif
        
        if (self.completionBlock != nil)
            self.completionBlock(true);
    };
    
    if (!isRemoteFile || isCurrent)
    {
        downloadCompletionBlock(self.url);
    }
    else
    {
        
        __weak TGICloudFileDownloadRequest *weakSelf = self;
        _fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        NSFileAccessIntent *fileAccessIntent = [NSFileAccessIntent readingIntentWithURL:self.url options:NSFileCoordinatorReadingWithoutChanges];
        [_fileCoordinator coordinateAccessWithIntents:@[fileAccessIntent]
                                               queue:[TGICloudFileDownloadRequest
                                                      fileCoordinatorOperationQueue] byAccessor:^(NSError *error)
        {
            __strong TGICloudFileDownloadRequest *strongSelf = weakSelf;
            @synchronized (self)
            {
                if (strongSelf->_metadataQuery != nil)
                {
                    strongSelf->_discardedMetadataQuery = true;
                    if (strongSelf->_addedProgressObserver)
                        [strongSelf->_metadataQuery removeObserver:self forKeyPath:@"results"];
                    if ([strongSelf->_metadataQuery isStarted])
                        [strongSelf->_metadataQuery stopQuery];
                    strongSelf->_metadataQuery = nil;
                }
            }
            
            if (error != nil)
            {
                TGLog(@"Cloud ERROR: failed to download file with error: %@", error);
                if (self.completionBlock != nil)
                    self.completionBlock(false);
                return;
            }
            
            downloadCompletionBlock(fileAccessIntent.URL);
        }];
#else
        [_fileCoordinator coordinateReadingItemAtURL:self.url options:NSFileCoordinatorReadingWithoutChanges error:&error byAccessor:^(NSURL *newURL)
        {
            __strong TGICloudFileDownloadRequest *strongSelf = weakSelf;
            @synchronized (self)
            {
                if (strongSelf->_metadataQuery != nil)
                {
                    strongSelf->_discardedMetadataQuery = true;
                    if (strongSelf->_addedProgressObserver)
                        [strongSelf->_metadataQuery removeObserver:self forKeyPath:@"results"];
                    if ([strongSelf->_metadataQuery isStarted])
                        [strongSelf->_metadataQuery stopQuery];
                    strongSelf->_metadataQuery = nil;
                }
            }
            
            downloadCompletionBlock(newURL);
        }];
        if (error != nil)
        {
            TGLog(@"Cloud ERROR: failed to download file with error: %@", error);
            if (self.completionBlock != nil)
                self.completionBlock(false);
            return;
        }
#endif
        
        if (self.progressBlock != nil)
        {
            NSString *fileName = self.url.lastPathComponent;
            _metadataQuery = [[NSMetadataQuery alloc] init];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            [_metadataQuery setSearchScopes:@[ NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope ]];
#else
            [_metadataQuery setSearchScopes:@[ NSMetadataQueryUbiquitousDocumentsScope ]];
#endif
            [_metadataQuery setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", NSMetadataItemFSNameKey, fileName]];
            [_metadataQuery setValueListAttributes:@[NSMetadataUbiquitousItemPercentDownloadedKey]];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                @synchronized (self)
                {
                    if (!_discardedMetadataQuery)
                    {
                        [_metadataQuery startQuery];
                        [_metadataQuery addObserver:self forKeyPath:@"results" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
                        _addedProgressObserver = true;
                    }
                }
            });
        }
    }
#endif
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)__unused object change:(NSDictionary *)change context:(void *)__unused context
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    if ([keyPath isEqualToString:@"results"])
    {
        NSUInteger changeKind = [[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue];
        if (changeKind == NSKeyValueChangeReplacement)
        {
            NSArray *changedItems = [change objectForKey:NSKeyValueChangeNewKey];
            for (NSMetadataItem *item in changedItems)
            {
                NSNumber *percentDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
                if (percentDownloaded != nil)
                {
                    CGFloat progress = [percentDownloaded floatValue] / 100.0f;
                    if (self.progressBlock != nil)
                        self.progressBlock(progress);
                }
            }
        }
    }
#endif
}

- (void)cancel
{
    self.cancelled = true;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    [self.metadataQuery stopQuery];
    [self.fileCoordinator cancel];
#endif
    [self dispose];
}

- (void)dispose
{
    self.url = nil;
    self.path = nil;
    self.progressBlock = nil;
    self.completionBlock = nil;
    _fileCoordinator = nil;
    _metadataQuery = nil;
}

+ (NSOperationQueue *)fileCoordinatorOperationQueue
{
    static NSOperationQueue *fileCoordinatorOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        fileCoordinatorOperationQueue = [[NSOperationQueue alloc] init];
    });
    
    return fileCoordinatorOperationQueue;
}

@end

@interface TGICloudFileDownloadActor ()
{
    NSURL *_url;
    NSString *_path;
}
@end

@implementation TGICloudFileDownloadActor

+ (NSString *)genericPath
{
    return @"/iCloudDownload/@";
}

- (void)prepare:(NSDictionary *)options
{
    [super prepare:options];
    
    if (options[@"queue"] != nil)
        self.requestQueueName = options[@"queue"];
}

- (void)execute:(NSDictionary *)options
{
    _url = options[@"url"];
    _path = options[@"path"];
    
    __weak TGICloudFileDownloadActor *weakSelf = self;
    self.cancelToken = [TGICloudFileDownloadRequest downloadFileAtUrl:_url path:[NSURL fileURLWithPath:_path] progressBlock:^(CGFloat progress)
    {
        __strong TGICloudFileDownloadActor *strongSelf = weakSelf;
        [ActionStageInstance() dispatchMessageToWatchers:strongSelf.path messageType:@"progress" message:@(progress)];
    } completionBlock:^(bool succeed)
    {
        __strong TGICloudFileDownloadActor *strongSelf = weakSelf;
        if (succeed)
            [ActionStageInstance() actionCompleted:strongSelf.path result:nil];
        else
            [ActionStageInstance() actionFailed:strongSelf.path reason:-1];
    }];
}

@end
