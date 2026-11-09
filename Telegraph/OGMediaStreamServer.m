#import "OGMediaStreamServer.h"

#import <UIKit/UIKit.h>

#import "../submodules/MtProtoKit/thirdparty/AsyncSocket/GCDAsyncSocket.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

static const NSUInteger OGMediaStreamChunkSize = 32 * 1024;
static const NSUInteger OGMediaStreamMaximumPendingWrites = 2;
static const NSUInteger OGMediaStreamMaximumRequestLength = 16 * 1024;
static const int64_t OGMediaStreamProbeLength = 64 * 1024;

enum {
    OGMediaStreamTagRequest = 1,
    OGMediaStreamTagHeader = 2,
    OGMediaStreamTagBody = 3
};

static dispatch_queue_t OGMediaStreamServerQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.media-stream", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static inline uint32_t OGMediaStreamReadUInt32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static inline uint64_t OGMediaStreamReadUInt64(const uint8_t *bytes)
{
    return ((uint64_t)OGMediaStreamReadUInt32(bytes) << 32) | (uint64_t)OGMediaStreamReadUInt32(bytes + 4);
}

@interface OGMediaStreamServer ()

- (OGMediaStream *)streamForIdentifier:(NSString *)identifier;
- (void)removeStreamWithIdentifier:(NSString *)identifier;
- (void)removeConnection:(id)connection;

@end

@interface OGMediaStream ()
{
    __weak OGMediaStreamServer *_server;
    OGMediaFetchDescriptor *_descriptor;
    NSString *_publishPath;
    OGMediaFetchObserver *_observer;
    id _backgroundDemand;
    id _probeDemand;
    id _movieDemand;
    bool _probing;
    bool _invalidated;
}

@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) NSString *mimeType;

@end

@implementation OGMediaStream

- (instancetype)initWithServer:(OGMediaStreamServer *)server identifier:(NSString *)identifier URL:(NSURL *)URL descriptor:(OGMediaFetchDescriptor *)descriptor publishPath:(NSString *)publishPath mimeType:(NSString *)mimeType
{
    self = [super init];
    if (self != nil)
    {
        _server = server;
        _identifier = identifier;
        _URL = URL;
        _descriptor = descriptor;
        _publishPath = publishPath;
        _mimeType = mimeType;
    }
    return self;
}

- (void)start
{
    _session = [OGMediaFetchSession acquireSessionForDescriptor:_descriptor];
    if (_publishPath.length != 0)
        [_session addPublishPath:_publishPath];

    _probing = [_mimeType hasPrefix:@"video/"] || [_mimeType isEqualToString:@"audio/mp4"];
    __weak OGMediaStream *weakSelf = self;
    _observer = [[OGMediaFetchObserver alloc] init];
    _observer.updated = ^
    {
        [weakSelf probeMovieLayout];
    };
    [_session addObserver:_observer];
    if (_probing)
        _probeDemand = [_session addDemandFrom:0 to:OGMediaStreamProbeLength priority:OGMediaFetchPriorityPlayback];
    _backgroundDemand = [_session addDemandFrom:0 to:INT64_MAX priority:OGMediaFetchPriorityDownload];
    dispatch_async(OGMediaFetchQueue(), ^
    {
        [weakSelf probeMovieLayout];
    });
}

- (int64_t)size
{
    return [_session size];
}

- (double)downloadRate
{
    return [_session downloadRate];
}

- (bool)isComplete
{
    return [_session isComplete];
}

- (void)probeMovieLayout
{
    if (!_probing || _invalidated)
        return;
    int64_t size = [_session size];
    if (size <= 0)
        return;
    int64_t head = MIN(OGMediaStreamProbeLength, size);
    if ([_session availableLengthAtOffset:0] < head)
        return;

    _probing = false;
    [_session removeDemand:_probeDemand];
    _probeDemand = nil;

    uint8_t *buffer = (uint8_t *)malloc((size_t)head);
    if (buffer == NULL)
        return;
    int64_t read = 0;
    while (read < head)
    {
        ssize_t result = [_session readAtOffset:read buffer:buffer + read length:(size_t)(head - read)];
        if (result <= 0)
            break;
        read += result;
    }

    int64_t movieStart = -1;
    int64_t movieEnd = -1;
    if (read >= 8 && OGMediaStreamReadUInt32(buffer + 4) == 'ftyp')
    {
        int64_t offset = 0;
        while (offset + 8 <= read)
        {
            uint64_t boxSize = OGMediaStreamReadUInt32(buffer + offset);
            uint32_t type = OGMediaStreamReadUInt32(buffer + offset + 4);
            uint64_t headerSize = 8;
            if (boxSize == 1)
            {
                if (offset + 16 > read)
                    break;
                boxSize = OGMediaStreamReadUInt64(buffer + offset + 8);
                headerSize = 16;
            }
            else if (boxSize == 0)
                boxSize = (uint64_t)(size - offset);
            if (boxSize < headerSize || boxSize > (uint64_t)(size - offset))
                break;
            if (type == 'moov')
            {
                movieStart = offset;
                movieEnd = offset + (int64_t)boxSize;
                break;
            }
            offset += (int64_t)boxSize;
        }
        if (movieStart < 0 && offset >= read && offset < size)
        {
            movieStart = offset;
            movieEnd = size;
        }
    }
    free(buffer);

    if (movieStart >= 0 && movieEnd > head)
        _movieDemand = [_session addDemandFrom:movieStart to:movieEnd priority:OGMediaFetchPriorityPlayback];
}

- (void)invalidate
{
    if (_invalidated)
        return;
    _invalidated = true;
    if (_session != nil)
    {
        [_session removeObserver:_observer];
        if (_probeDemand != nil)
            [_session removeDemand:_probeDemand];
        if (_movieDemand != nil)
            [_session removeDemand:_movieDemand];
        [_session removeDemand:_backgroundDemand];
        [_session relinquish];
    }
    [_server removeStreamWithIdentifier:_identifier];
}

@end

@interface OGMediaStreamConnection : NSObject <GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *_socket;
    __weak OGMediaStreamServer *_server;
    OGMediaStream *_stream;
    OGMediaFetchSession *_session;
    OGMediaFetchObserver *_observer;
    id _demand;
    int64_t _offset;
    int64_t _end;
    NSUInteger _pendingWrites;
    bool _sendingBody;
    bool _keepAlive;
    bool _closed;
}

@property (nonatomic, strong, readonly) OGMediaStream *stream;

@end

@implementation OGMediaStreamConnection

- (instancetype)initWithSocket:(GCDAsyncSocket *)socket server:(OGMediaStreamServer *)server
{
    self = [super init];
    if (self != nil)
    {
        _socket = socket;
        _server = server;
        [_socket setDelegate:self delegateQueue:OGMediaStreamServerQueue()];
    }
    return self;
}

- (void)start
{
    [self readRequest];
}

- (void)readRequest
{
    static NSData *terminator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        terminator = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
    });
    [_socket readDataToData:terminator withTimeout:120.0 maxLength:OGMediaStreamMaximumRequestLength tag:OGMediaStreamTagRequest];
}

- (void)close
{
    if (_closed)
        return;
    _closed = true;
    [self releaseResponse];
    [_socket setDelegate:nil delegateQueue:NULL];
    [_socket disconnect];
    [_server removeConnection:self];
}

- (void)closeIfStreamIdentifier:(NSString *)identifier
{
    if ([_stream.identifier isEqualToString:identifier])
        [self close];
}

- (void)releaseResponse
{
    _sendingBody = false;
    if (_observer != nil)
        [_session removeObserver:_observer];
    if (_demand != nil)
        [_session removeDemand:_demand];
    _observer = nil;
    _demand = nil;
    _session = nil;
}

- (void)sendStatus:(NSString *)status headers:(NSString *)headers
{
    NSString *response = [[NSString alloc] initWithFormat:@"HTTP/1.1 %@\r\n%@Connection: %@\r\n\r\n", status, headers, _keepAlive ? @"keep-alive" : @"close"];
    _pendingWrites++;
    [_socket writeData:[response dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1.0 tag:OGMediaStreamTagHeader];
}

- (void)sendEmptyStatus:(NSString *)status headers:(NSString *)headers
{
    _keepAlive = false;
    [self sendStatus:status headers:[headers stringByAppendingString:@"Content-Length: 0\r\n"]];
    [_socket disconnectAfterWriting];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadData:(NSData *)data withTag:(long)tag
{
    if (tag != OGMediaStreamTagRequest || _closed)
        return;

    NSString *request = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    NSArray *lines = [request componentsSeparatedByString:@"\r\n"];
    NSArray *requestLine = [lines.firstObject componentsSeparatedByString:@" "];
    if (requestLine.count < 3)
    {
        [self sendEmptyStatus:@"400 Bad Request" headers:@""];
        return;
    }
    NSString *method = requestLine[0];
    NSString *target = requestLine[1];
    _keepAlive = ![requestLine[2] isEqualToString:@"HTTP/1.0"];

    NSString *range = nil;
    for (NSUInteger i = 1; i < lines.count; i++)
    {
        NSString *line = lines[i];
        NSRange separator = [line rangeOfString:@":"];
        if (separator.location == NSNotFound)
            continue;
        NSString *name = [[line substringToIndex:separator.location] lowercaseString];
        NSString *value = [[line substringFromIndex:separator.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([name isEqualToString:@"range"])
            range = value;
        else if ([name isEqualToString:@"connection"])
            _keepAlive = [[value lowercaseString] rangeOfString:@"close"].location == NSNotFound && _keepAlive;
    }

    bool head = [method isEqualToString:@"HEAD"];
    if (!head && ![method isEqualToString:@"GET"])
    {
        [self sendEmptyStatus:@"405 Method Not Allowed" headers:@"Allow: GET, HEAD\r\n"];
        return;
    }

    NSArray *components = [target componentsSeparatedByString:@"/"];
    OGMediaStream *stream = components.count == 3 ? [_server streamForIdentifier:[components[2] stringByDeletingPathExtension]] : nil;
    if (stream == nil || ![components[1] isEqualToString:[[stream.URL pathComponents] objectAtIndex:1]])
    {
        [self sendEmptyStatus:@"404 Not Found" headers:@""];
        return;
    }
    _stream = stream;

    int64_t size = [stream size];
    if (size <= 0)
    {
        [self sendEmptyStatus:@"503 Service Unavailable" headers:@"Retry-After: 1\r\n"];
        return;
    }

    int64_t start = 0;
    int64_t end = size;
    bool partial = false;
    if ([range hasPrefix:@"bytes="])
    {
        NSString *specification = [[[range substringFromIndex:6] componentsSeparatedByString:@","] firstObject];
        NSRange dash = [specification rangeOfString:@"-"];
        if (dash.location == NSNotFound)
        {
            [self sendEmptyStatus:@"416 Range Not Satisfiable" headers:[[NSString alloc] initWithFormat:@"Content-Range: bytes */%lld\r\n", (long long)size]];
            return;
        }
        NSString *first = [[specification substringToIndex:dash.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *last = [[specification substringFromIndex:dash.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (first.length == 0)
            start = MAX((int64_t)0, size - [last longLongValue]);
        else
        {
            start = [first longLongValue];
            if (last.length != 0)
                end = MIN(size, [last longLongValue] + 1);
        }
        if (start < 0 || start >= size || start >= end)
        {
            [self sendEmptyStatus:@"416 Range Not Satisfiable" headers:[[NSString alloc] initWithFormat:@"Content-Range: bytes */%lld\r\n", (long long)size]];
            return;
        }
        partial = true;
    }

    NSMutableString *headers = [[NSMutableString alloc] init];
    [headers appendFormat:@"Content-Type: %@\r\n", stream.mimeType];
    [headers appendString:@"Accept-Ranges: bytes\r\n"];
    [headers appendFormat:@"Content-Length: %lld\r\n", (long long)(end - start)];
    if (partial)
        [headers appendFormat:@"Content-Range: bytes %lld-%lld/%lld\r\n", (long long)start, (long long)(end - 1), (long long)size];
    [self sendStatus:partial ? @"206 Partial Content" : @"200 OK" headers:headers];

    _offset = start;
    _end = head ? start : end;
    _sendingBody = true;
    _session = stream.session;
    if (!head)
    {
        __weak OGMediaStreamConnection *weakSelf = self;
        dispatch_block_t pump = ^
        {
            dispatch_async(OGMediaStreamServerQueue(), ^
            {
                [weakSelf pumpBody];
            });
        };
        _observer = [[OGMediaFetchObserver alloc] init];
        _observer.updated = pump;
        _observer.completed = ^(__unused NSString *path, __unused NSData *result)
        {
            pump();
        };
        _observer.failed = ^
        {
            dispatch_async(OGMediaStreamServerQueue(), ^
            {
                [weakSelf close];
            });
        };
        [_session addObserver:_observer];
        _demand = [_session addDemandFrom:start to:end priority:OGMediaFetchPriorityPlayback];
    }
    [self pumpBody];
}

- (void)pumpBody
{
    while (_sendingBody && !_closed && _pendingWrites < OGMediaStreamMaximumPendingWrites && _offset < _end)
    {
        int64_t available = [_session availableLengthAtOffset:_offset];
        if (available <= 0)
            break;
        size_t length = (size_t)MIN(MIN(available, _end - _offset), (int64_t)OGMediaStreamChunkSize);
        NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
        ssize_t result = [_session readAtOffset:_offset buffer:(uint8_t *)data.mutableBytes length:length];
        if (result < 0)
        {
            [self close];
            return;
        }
        if (result == 0)
            break;
        [data setLength:(NSUInteger)result];
        _offset += result;
        _pendingWrites++;
        [_socket writeData:data withTimeout:-1.0 tag:OGMediaStreamTagBody];
    }
    if (_sendingBody && !_closed && _offset >= _end && _pendingWrites == 0)
    {
        [self releaseResponse];
        if (_keepAlive)
            [self readRequest];
        else
            [_socket disconnectAfterWriting];
    }
}

- (void)socket:(GCDAsyncSocket *)__unused socket didWriteDataWithTag:(long)tag
{
    if (tag == OGMediaStreamTagHeader || tag == OGMediaStreamTagBody)
    {
        if (_pendingWrites > 0)
            _pendingWrites--;
        [self pumpBody];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)__unused socket withError:(NSError *)__unused error
{
    [self close];
}

@end

@interface OGMediaStreamServer () <GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *_listenSocket;
    uint16_t _port;
    NSString *_token;
    NSMutableDictionary *_streams;
    NSMutableArray *_connections;
    NSUInteger _nextIdentifier;
    OGPlatformBackgroundTaskIdentifier _backgroundTask;
}

@end

@implementation OGMediaStreamServer

+ (OGMediaStreamServer *)sharedServer
{
    static OGMediaStreamServer *server = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        server = [[OGMediaStreamServer alloc] init];
    });
    return server;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _streams = [[NSMutableDictionary alloc] init];
        _connections = [[NSMutableArray alloc] init];
        NSMutableString *token = [[NSMutableString alloc] init];
        for (int i = 0; i < 4; i++)
            [token appendFormat:@"%08x", arc4random()];
        _token = token;
        _backgroundTask = OGPlatformBackgroundTaskInvalid;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:@"UIApplicationWillEnterForegroundNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)endBackgroundTask
{
    if (_backgroundTask == OGPlatformBackgroundTaskInvalid)
        return;
    OGPlatformEndBackgroundTask([UIApplication sharedApplication], _backgroundTask);
    _backgroundTask = OGPlatformBackgroundTaskInvalid;
}

- (void)applicationDidEnterBackground:(NSNotification *)__unused notification
{
    __block bool active = false;
    dispatch_sync(OGMediaStreamServerQueue(), ^
    {
        for (OGMediaStream *stream in [_streams allValues])
        {
            if (![stream isComplete])
            {
                active = true;
                break;
            }
        }
    });
    if (!active || _backgroundTask != OGPlatformBackgroundTaskInvalid)
        return;
    __weak OGMediaStreamServer *weakSelf = self;
    _backgroundTask = OGPlatformBeginBackgroundTask([UIApplication sharedApplication], ^
    {
        [weakSelf endBackgroundTask];
    });
}

- (void)applicationWillEnterForeground:(NSNotification *)__unused notification
{
    [self endBackgroundTask];
    dispatch_async(OGMediaStreamServerQueue(), ^
    {
        if (_streams.count != 0)
            [self ensureListening];
    });
}

- (bool)ensureListening
{
    if (_listenSocket != nil && ![_listenSocket isDisconnected])
        return true;
    [_listenSocket setDelegate:nil delegateQueue:NULL];
    [_listenSocket disconnect];
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:OGMediaStreamServerQueue()];
    NSError *error = nil;
    if (_port != 0 && [_listenSocket acceptOnInterface:@"loopback" port:_port error:&error])
        return true;
    if ([_listenSocket acceptOnInterface:@"loopback" port:0 error:&error])
    {
        _port = [_listenSocket localPort];
        return true;
    }
    TGLog(@"[OGMediaStreamServer listen failed: %@]", error);
    _listenSocket = nil;
    return false;
}

- (OGMediaStream *)streamWithDescriptor:(OGMediaFetchDescriptor *)descriptor publishPath:(NSString *)publishPath mimeType:(NSString *)mimeType pathExtension:(NSString *)pathExtension
{
    if (descriptor == nil)
        return nil;
    __block OGMediaStream *stream = nil;
    dispatch_sync(OGMediaStreamServerQueue(), ^
    {
        if (![self ensureListening])
            return;
        NSString *identifier = [[NSString alloc] initWithFormat:@"%lu", (unsigned long)(++_nextIdentifier)];
        NSString *extension = pathExtension.length != 0 ? pathExtension : @"mp4";
        NSURL *URL = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"http://127.0.0.1:%u/%@/%@.%@", (unsigned)_port, _token, identifier, extension]];
        stream = [[OGMediaStream alloc] initWithServer:self identifier:identifier URL:URL descriptor:descriptor publishPath:publishPath mimeType:mimeType.length != 0 ? mimeType : @"video/mp4"];
        _streams[identifier] = stream;
    });
    [stream start];
    return stream;
}

- (OGMediaStream *)streamForIdentifier:(NSString *)identifier
{
    return identifier != nil ? _streams[identifier] : nil;
}

- (void)removeStreamWithIdentifier:(NSString *)identifier
{
    dispatch_async(OGMediaStreamServerQueue(), ^
    {
        [_streams removeObjectForKey:identifier];
        for (OGMediaStreamConnection *connection in [_connections copy])
            [connection closeIfStreamIdentifier:identifier];
        if (_streams.count == 0)
        {
            [_listenSocket setDelegate:nil delegateQueue:NULL];
            [_listenSocket disconnect];
            _listenSocket = nil;
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self endBackgroundTask];
            });
        }
    });
}

- (void)removeConnection:(id)connection
{
    [_connections removeObjectIdenticalTo:connection];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    OGMediaStreamConnection *connection = [[OGMediaStreamConnection alloc] initWithSocket:newSocket server:self];
    [_connections addObject:connection];
    [connection start];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)__unused error
{
    if (socket == _listenSocket && _streams.count != 0)
        [self ensureListening];
}

@end
