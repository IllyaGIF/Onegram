#import "OGMediaStreamReader.h"

#import <pthread.h>
#import <sys/time.h>

#import "OGMediaStreamServer.h"

const ssize_t OGMediaStreamReaderInterrupted = -2;

static int OGMediaStreamReaderFileRead(void *cookie, char *buffer, int length)
{
    OGMediaStreamReader *reader = (__bridge OGMediaStreamReader *)cookie;
    ssize_t result = [reader read:buffer length:(size_t)MAX(0, length)];
    return result < 0 ? -1 : (int)result;
}

static fpos_t OGMediaStreamReaderFileSeek(void *cookie, fpos_t offset, int whence)
{
    OGMediaStreamReader *reader = (__bridge OGMediaStreamReader *)cookie;
    int64_t base = 0;
    if (whence == SEEK_CUR)
        base = [reader position];
    else if (whence == SEEK_END)
        base = [reader size];
    int64_t target = base + (int64_t)offset;
    if (target < 0 || ![reader seekToOffset:target])
        return -1;
    return (fpos_t)target;
}

static int OGMediaStreamReaderFileClose(void *cookie)
{
    CFRelease((CFTypeRef)cookie);
    return 0;
}

@interface OGMediaStreamReader ()
{
    pthread_mutex_t _lock;
    pthread_cond_t _condition;
    OGMediaFetchSession *_session;
    OGMediaFetchObserver *_observer;
    id _demand;
    int64_t _position;
    uint64_t _generation;
    uint64_t _interruptions;
    bool _cancelled;
    bool _failed;
}

@end

@implementation OGMediaStreamReader

- (instancetype)initWithStream:(OGMediaStream *)stream
{
    self = [super init];
    if (self != nil)
    {
        _stream = stream;
        _session = stream.session;
        _blocking = true;
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_condition, NULL);

        __weak OGMediaStreamReader *weakSelf = self;
        _observer = [[OGMediaFetchObserver alloc] init];
        _observer.updated = ^
        {
            [weakSelf signalWithFailure:false];
        };
        _observer.completed = ^(__unused NSString *path, __unused NSData *data)
        {
            [weakSelf signalWithFailure:false];
        };
        _observer.failed = ^
        {
            [weakSelf signalWithFailure:true];
        };
        [_session addObserver:_observer];
        _demand = [_session addDemandFrom:0 to:INT64_MAX priority:OGMediaFetchPriorityPlayback];
    }
    return self;
}

- (void)dealloc
{
    [_session removeObserver:_observer];
    [_session removeDemand:_demand];
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_lock);
}

- (void)signalWithFailure:(bool)failure
{
    pthread_mutex_lock(&_lock);
    _generation++;
    if (failure)
        _failed = true;
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);
}

- (void)cancel
{
    pthread_mutex_lock(&_lock);
    _cancelled = true;
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);
}

- (void)interrupt
{
    pthread_mutex_lock(&_lock);
    _interruptions++;
    _generation++;
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);
}

- (bool)isFailed
{
    pthread_mutex_lock(&_lock);
    bool failed = _failed || _cancelled;
    pthread_mutex_unlock(&_lock);
    return failed;
}

- (int64_t)size
{
    return [_stream size];
}

- (int64_t)position
{
    pthread_mutex_lock(&_lock);
    int64_t position = _position;
    pthread_mutex_unlock(&_lock);
    return position;
}

- (int64_t)availableAhead
{
    return [_session availableLengthAtOffset:[self position]];
}

- (bool)hasBufferedAhead:(int64_t)length
{
    int64_t position = [self position];
    int64_t size = [self size];
    int64_t available = [_session availableLengthAtOffset:position];
    return available >= length || (size > 0 && position + available >= size);
}

- (uint64_t)currentGeneration
{
    pthread_mutex_lock(&_lock);
    uint64_t generation = _generation;
    pthread_mutex_unlock(&_lock);
    return generation;
}

- (bool)waitAfterGeneration:(uint64_t)generation
{
    pthread_mutex_lock(&_lock);
    if (_generation == generation && !_cancelled && !_failed)
    {
        struct timeval now;
        gettimeofday(&now, NULL);
        struct timespec deadline;
        deadline.tv_sec = now.tv_sec + 1;
        deadline.tv_nsec = (long)now.tv_usec * 1000;
        pthread_cond_timedwait(&_condition, &_lock, &deadline);
    }
    bool alive = !_cancelled && !_failed;
    pthread_mutex_unlock(&_lock);
    return alive;
}

- (ssize_t)read:(void *)buffer length:(size_t)length
{
    if (length == 0)
        return 0;
    pthread_mutex_lock(&_lock);
    uint64_t interruptions = _interruptions;
    pthread_mutex_unlock(&_lock);
    while (true)
    {
        uint64_t generation = [self currentGeneration];
        int64_t position = [self position];
        int64_t size = [self size];
        if (size > 0 && position >= size)
            return 0;
        int64_t available = [_session availableLengthAtOffset:position];
        if (available > 0)
        {
            size_t chunk = (size_t)MIN((int64_t)length, available);
            ssize_t result = [_session readAtOffset:position buffer:(uint8_t *)buffer length:chunk];
            if (result > 0)
            {
                pthread_mutex_lock(&_lock);
                if (_position == position)
                    _position = position + result;
                pthread_mutex_unlock(&_lock);
                return result;
            }
            if (result < 0)
                return -1;
        }
        if (!self.blocking)
            return 0;
        if (![self waitAfterGeneration:generation])
            return -1;
        pthread_mutex_lock(&_lock);
        bool interrupted = _interruptions != interruptions;
        pthread_mutex_unlock(&_lock);
        if (interrupted)
            return OGMediaStreamReaderInterrupted;
    }
}

- (bool)seekToOffset:(int64_t)offset
{
    int64_t size = [self size];
    if (offset < 0 || (size > 0 && offset > size))
        return false;
    pthread_mutex_lock(&_lock);
    bool moved = _position != offset;
    _position = offset;
    pthread_mutex_unlock(&_lock);
    if (moved)
        [_session updateDemand:_demand from:offset to:INT64_MAX priority:OGMediaFetchPriorityPlayback];
    return true;
}

- (bool)waitForRangeFrom:(int64_t)start length:(int64_t)length
{
    int64_t size = [self size];
    if (size > 0)
        length = MIN(length, size - start);
    if (length <= 0)
        return true;
    id demand = [_session addDemandFrom:start to:start + length priority:OGMediaFetchPriorityPlayback];
    bool result = true;
    while (true)
    {
        uint64_t generation = [self currentGeneration];
        if ([_session availableLengthAtOffset:start] >= length)
            break;
        if (![self waitAfterGeneration:generation])
        {
            result = false;
            break;
        }
    }
    [_session removeDemand:demand];
    return result;
}

- (FILE *)openFile
{
    void *cookie = (__bridge_retained void *)self;
    FILE *file = funopen(cookie, OGMediaStreamReaderFileRead, NULL, OGMediaStreamReaderFileSeek, OGMediaStreamReaderFileClose);
    if (file == NULL)
    {
        CFRelease((CFTypeRef)cookie);
        return NULL;
    }
    setvbuf(file, NULL, _IOFBF, 16 * 1024);
    return file;
}

@end
