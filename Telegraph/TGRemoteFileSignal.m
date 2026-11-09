#import "TGRemoteFileSignal.h"

#import "TGTelegramNetworking.h"
#import "TGNetworkWorker.h"
#import "TGCommon.h"

#import "OGMediaFetchSession.h"

@implementation TGRemoteFileDataEvent

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
    }
    return self;
}

@end

@implementation TGRemoteFileProgressEvent

- (instancetype)initWithProgress:(CGFloat)progress
{
    self = [super init];
    if (self != nil)
    {
        _progress = progress;
    }
    return self;
}

@end

@implementation TGRemoteFileSignal

+ (SSignal *)partsForWebLocation:(TLInputWebFileLocation *)location datacenterId:(NSInteger)datacenterId size:(NSUInteger)size mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag
{
    if (datacenterId <= 0) {
        return [SSignal fail:nil];
    }

    TLRPCupload_getWebFile$upload_getWebFile *getFile = [[TLRPCupload_getWebFile$upload_getWebFile alloc] init];
    getFile.location = location;
    getFile.offset = 0;
    getFile.limit = size == 0 ? (1024 * 1024) : (int32_t)size;
    
    return [[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:datacenterId type:mediaTypeTag] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker)
    {
        return [[[TGTelegramNetworking instance] requestSignal:getFile worker:worker] map:^id (id next)
        {
            if ([next isKindOfClass:[TLupload_WebFile class]])
            {
                TLupload_WebFile *part = next;
                return [[TGRemoteFileDataEvent alloc] initWithData:part.bytes];
            }
            else
                return [[TGRemoteFileProgressEvent alloc] initWithProgress:[next floatValue]];
        }];
}];
}

+ (SSignal *)multipartDownload:(TLInputFileLocation *)location datacenterId:(NSInteger)datacenterId originInfo:(TGMediaOriginInfo *)originInfo identifier:(int64_t)identifier size:(NSUInteger)size mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag
{
    if (datacenterId <= 0 || location == nil) {
        return [SSignal fail:nil];
    }

    OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
    descriptor.location = location;
    descriptor.datacenterId = datacenterId;
    descriptor.size = (int64_t)size;
    descriptor.mediaTypeTag = mediaTypeTag;
    descriptor.originInfo = originInfo;
    descriptor.identifier = identifier;

    return [OGMediaFetchSequentialSignal(descriptor, 0, INT64_MAX, nil) map:^id(NSData *data) {
        return [[TGRemoteFileDataEvent alloc] initWithData:data];
    }];
}

+ (SSignal *)multipartWebDownload:(TLInputWebFileLocation *)location datacenterId:(NSInteger)datacenterId size:(NSUInteger)size mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag
{
    NSUInteger partSize = 0;
    if (size >= 2 * 1024 * 1024)
        partSize = 512 * 1024;
    else
        partSize = 12 * 1024;
    
    NSUInteger numberOfParts = size / partSize + (size % partSize == 0 ? 0 : 1);
    
    SSignal *downloadSignal = [[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:datacenterId type:mediaTypeTag] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker) {
        SSignal *parts = [SSignal complete];
        for (NSUInteger index = 0; index < numberOfParts; index++) {
            TLRPCupload_getWebFile$upload_getWebFile *getFile = [[TLRPCupload_getWebFile$upload_getWebFile alloc] init];
            getFile.location = location;
            getFile.offset = (int32_t)(index * partSize);
            getFile.limit = (int32_t)partSize;
            
            SSignal *part = [[[TGTelegramNetworking instance] requestSignal:getFile worker:worker] map:^id (id next) {
                if ([next isKindOfClass:[TLupload_WebFile class]]) {
                    TLupload_WebFile *part = next;
                    return [[TGRemoteFileDataEvent alloc] initWithData:part.bytes];
                } else {
                    float baseProgress = (float)(index * partSize) / (float)size;
                    float partProgress = ([next floatValue] * partSize) / size;
                    return [[TGRemoteFileProgressEvent alloc] initWithProgress:MIN(1.0f, baseProgress + partProgress)];
                }
            }];
            
            parts = [parts then:part];
        }
        
        return parts;
    }];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SAtomic *data = [[SAtomic alloc] initWithValue:[[NSMutableData alloc] init]];
        return [downloadSignal startWithNext:^(id next) {
            if ([next isKindOfClass:[TGRemoteFileProgressEvent class]]) {
                [subscriber putNext:@(((TGRemoteFileProgressEvent *)next).progress)];
            } else if ([next isKindOfClass:[TGRemoteFileDataEvent class]]) {
                [data modify:^id(NSMutableData *data) {
                    [data appendData:((TGRemoteFileDataEvent *)next).data];
                    return data;
                }];
            }
        } error:^(id error) {
            [subscriber putError:error];
        } completed:^{
            NSData *result = [data with:^id(NSData *data) {
                return data;
            }];
            [subscriber putNext:result];
            [subscriber putCompletion];
        }];
    }];
}

+ (SSignal *)indefiniteMultipartWebDownload:(TLInputWebFileLocation *)location datacenterId:(NSInteger)datacenterId mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag
{
    NSUInteger initialPartSize = 64 * 1024;
    SSignal *signal = [[[TGTelegramNetworking instance] downloadWorkerForDatacenterId:datacenterId type:mediaTypeTag] mapToSignal:^SSignal *(TGNetworkWorkerGuard *worker) {
        
        SSignal *initialPart = [SSignal defer:^SSignal *
        {
            TLRPCupload_getWebFile$upload_getWebFile *getFile = [[TLRPCupload_getWebFile$upload_getWebFile alloc] init];
            getFile.location = location;
            getFile.offset = 0;
            getFile.limit = (int32_t)initialPartSize;
            
            return [[TGTelegramNetworking instance] requestSignal:getFile worker:worker];
        }];
        
        return [initialPart mapToSignal:^SSignal *(id next)
        {
            if ([next isKindOfClass:[TLupload_WebFile class]]) {
                TLupload_WebFile *part = next;
                if ((int32_t)part.bytes.length >= part.size)
                {
                    return [SSignal single:[[TGRemoteFileDataEvent alloc] initWithData:part.bytes]];
                }
                else
                {
                    NSUInteger size = part.size;
                    SSignal *parts = [SSignal single:[[TGRemoteFileDataEvent alloc] initWithData:part.bytes]];
                    NSUInteger partSize = 0;
                    if (size >= 2 * 1024 * 1024)
                        partSize = 512 * 1024;
                    else
                        partSize = 12 * 1024;
                    
                    NSUInteger remainingSize = size - initialPartSize;
                    NSUInteger numberOfParts = remainingSize / partSize + (remainingSize % partSize == 0 ? 0 : 1);
                    for (NSUInteger index = 0; index < numberOfParts; index++) {
                        TLRPCupload_getWebFile$upload_getWebFile *getFile = [[TLRPCupload_getWebFile$upload_getWebFile alloc] init];
                        getFile.location = location;
                        getFile.offset = (int32_t)(index * partSize + initialPartSize);
                        getFile.limit = (int32_t)partSize;
                        
                        SSignal *part = [[[TGTelegramNetworking instance] requestSignal:getFile worker:worker] map:^id (id next) {
                            if ([next isKindOfClass:[TLupload_WebFile class]]) {
                                TLupload_WebFile *part = next;
                                return [[TGRemoteFileDataEvent alloc] initWithData:part.bytes];
                            } else {
                                float baseProgress = (float)(index * partSize) / (float)remainingSize;
                                float partProgress = ([next floatValue] * partSize) / remainingSize;
                                return [[TGRemoteFileProgressEvent alloc] initWithProgress:MIN(1.0f, baseProgress + partProgress)];
                            }
                        }];
                        
                        parts = [parts then:part];
                    }
                    
                    return parts;
                }
            } else {
                return [SSignal single:[[TGRemoteFileProgressEvent alloc] initWithProgress:0.0f]];
            }
        }];
    }];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SAtomic *data = [[SAtomic alloc] initWithValue:[[NSMutableData alloc] init]];
        return [signal startWithNext:^(id next) {
            if ([next isKindOfClass:[TGRemoteFileProgressEvent class]]) {
                [subscriber putNext:@(((TGRemoteFileProgressEvent *)next).progress)];
            } else if ([next isKindOfClass:[TGRemoteFileDataEvent class]]) {
                [data modify:^id(NSMutableData *data) {
                    [data appendData:((TGRemoteFileDataEvent *)next).data];
                    return data;
                }];
            }
        } error:^(id error) {
            [subscriber putError:error];
        } completed:^{
            NSData *result = [data with:^id(NSData *data) {
                return data;
            }];
            [subscriber putNext:result];
            [subscriber putCompletion];
        }];
    }];
}


+ (SSignal *)dataForLocation:(TLInputFileLocation *)location datacenterId:(NSInteger)datacenterId originInfo:(TGMediaOriginInfo *)originInfo identifier:(int64_t)identifier size:(NSUInteger)size reportProgress:(bool)reportProgress mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag
{
        return [[[self multipartDownload:location datacenterId:datacenterId originInfo:originInfo identifier:identifier size:size mediaTypeTag:mediaTypeTag] filter:^bool(id next) {
            if (!reportProgress) {
                return ![next respondsToSelector:@selector(floatValue)];
            } else {
                return true;
            }
        }] reduceLeft:[[NSMutableData alloc] init] with:^id(NSMutableData *current, id event) {
            if ([event isKindOfClass:[TGRemoteFileDataEvent class]] && ((TGRemoteFileDataEvent *)event).data != nil) {
                [current appendData:((TGRemoteFileDataEvent *)event).data];
            }
            return current;
        }];
}

+ (SSignal *)dataForWebLocation:(TLInputWebFileLocation *)location datacenterId:(NSInteger)datacenterId size:(NSUInteger)size reportProgress:(bool)reportProgress mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag {
    if (size == 0) {
        return [[self indefiniteMultipartWebDownload:location datacenterId:datacenterId mediaTypeTag:mediaTypeTag] filter:^bool(id next) {
            if (!reportProgress) {
                return ![next respondsToSelector:@selector(floatValue)];
            } else {
                return true;
            }
        }];
    }
    else if (size >= 1 * 1024 * 1024) {
        return [[self multipartWebDownload:location datacenterId:datacenterId size:size mediaTypeTag:mediaTypeTag] filter:^bool(id next) {
            if (!reportProgress) {
                return ![next respondsToSelector:@selector(floatValue)];
            } else {
                return true;
            }
        }];
    } else {
        return [[[self partsForWebLocation:location datacenterId:datacenterId size:size mediaTypeTag:mediaTypeTag] map:^id(id next)
        {
            if ([next isKindOfClass:[TGRemoteFileDataEvent class]])
                return [next data];
            else if (reportProgress && [next isKindOfClass:[TGRemoteFileProgressEvent class]])
                return @([(TGRemoteFileProgressEvent *)next progress]);
            
            return nil;
        }] filter:^bool(id value)
        {
            return value != nil;
        }];
    }
}

@end
