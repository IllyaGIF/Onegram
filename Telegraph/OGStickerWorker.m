#import "OGStickerWorker.h"

#import <pthread.h>
#import <sched.h>

#import "../OnegramPlatform/OGPlatformDispatch.h"

static const int OGStickerWorkerPriority = 33;

@interface OGStickerWorker ()
{
    NSString *_name;
    pthread_mutex_t _lock;
    pthread_cond_t _condition;
    NSMutableArray *_blocks;
}

- (void)run;

@end

static void *OGStickerWorkerMain(void *context)
{
    OGStickerWorker *worker = (__bridge_transfer OGStickerWorker *)context;
    [worker run];
    return NULL;
}

@implementation OGStickerWorker

+ (OGStickerWorker *)preparationWorker
{
    static OGStickerWorker *worker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        worker = [[OGStickerWorker alloc] initWithName:@"preparation"];
    });
    return worker;
}

+ (OGStickerWorker *)auxiliaryWorker
{
    static OGStickerWorker *worker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        worker = [[OGStickerWorker alloc] initWithName:@"auxiliary"];
    });
    return worker;
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self != nil)
    {
        _name = name;
        _blocks = [[NSMutableArray alloc] init];
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_condition, NULL);
        pthread_attr_t attributes;
        pthread_attr_init(&attributes);
        pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
        pthread_t thread;
        void *context = (__bridge_retained void *)self;
        if (pthread_create(&thread, &attributes, OGStickerWorkerMain, context) != 0)
        {
            (void)(__bridge_transfer OGStickerWorker *)context;
            pthread_attr_destroy(&attributes);
            return nil;
        }
        pthread_attr_destroy(&attributes);
    }
    return self;
}

- (void)configureThread
{
    int policy = 0;
    struct sched_param parameters;
    memset(&parameters, 0, sizeof(parameters));
    int result = -1;
    if (pthread_getschedparam(pthread_self(), &policy, &parameters) == 0)
    {
        parameters.sched_priority = MIN(OGStickerWorkerPriority, sched_get_priority_max(policy));
        result = pthread_setschedparam(pthread_self(), policy, &parameters);
    }
    OGPlatformDiagnosticLog(@"STICKERWORKER name=%@ priority=%d result=%d", _name, parameters.sched_priority, result);
}

- (void)run
{
    @autoreleasepool
    {
        [self configureThread];
    }
    while (true)
    {
        pthread_mutex_lock(&_lock);
        while (_blocks.count == 0)
            pthread_cond_wait(&_condition, &_lock);
        dispatch_block_t block = _blocks[0];
        [_blocks removeObjectAtIndex:0];
        pthread_mutex_unlock(&_lock);
        @autoreleasepool
        {
            block();
        }
    }
}

- (void)perform:(dispatch_block_t)block
{
    if (block == nil)
        return;
    dispatch_block_t copiedBlock = [block copy];
    pthread_mutex_lock(&_lock);
    [_blocks addObject:copiedBlock];
    pthread_cond_signal(&_condition);
    pthread_mutex_unlock(&_lock);
}

@end
