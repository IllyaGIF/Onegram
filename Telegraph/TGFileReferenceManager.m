#import "TGFileReferenceManager.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"
#import "TGDownloadMessagesSignal.h"

@interface TGFileReferenceManager ()
{
    SQueue *_queue;
    NSMutableDictionary *_processedOriginInfos;
}
@end

@implementation TGFileReferenceManager

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _queue = [[SQueue alloc] init];
        _processedOriginInfos = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)releaseOriginInfoVariable:(SVariable *)variable forKey:(NSString *)key
{
    [_queue dispatch:^
    {
        if (_processedOriginInfos[key] == variable)
            [_processedOriginInfos removeObjectForKey:key];
    }];
}

- (SSignal *)updatedOriginInfo:(TGMediaOriginInfo *)originInfo
{
    if (originInfo == nil)
        return [SSignal fail:nil];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSString *key = originInfo.key;
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        [_queue dispatch:^
        {
            SVariable *info = _processedOriginInfos[key];
            if (info == nil)
            {
                info = [[SVariable alloc] init];
                [info set:[TGDownloadMessagesSignal remoteOriginInfo:originInfo]];
                _processedOriginInfos[key] = info;
            }
            
            [disposable setDisposable:[info.signal startWithNext:^(id next)
            {
                [self releaseOriginInfoVariable:info forKey:key];
                [subscriber putNext:next];
                [subscriber putCompletion];
            } error:^(id error)
            {
                [self releaseOriginInfoVariable:info forKey:key];
                [subscriber putError:error];
            } completed:nil]];
        }];
        return disposable;
    }];
}

@end
