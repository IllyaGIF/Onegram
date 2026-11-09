#import "MultipartFetch.h"

#import "MediaBoxContexts.h"
#import "OGMediaFetchSession.h"

SSignal *multipartFetch(id<TelegramCloudMediaResource> resource, NSNumber *size, NSRange range, TGNetworkMediaTypeTag mediaTypeTag) {
    if ([resource datacenterId] <= 0) {
        return [SSignal single:[[MediaResourceDataFetchResult alloc] initWithData:[NSData data] complete:true]];
    }

    OGMediaFetchDescriptor *descriptor = [[OGMediaFetchDescriptor alloc] init];
    descriptor.location = [resource apiInputLocation];
    descriptor.datacenterId = [resource datacenterId];
    descriptor.size = [size longLongValue];
    descriptor.mediaTypeTag = mediaTypeTag;
    descriptor.originInfo = [resource originInfo];
    descriptor.identifier = [resource identifier];

    int64_t start = (int64_t)range.location;
    int64_t end = range.length >= (NSUInteger)INT32_MAX ? INT64_MAX : start + (int64_t)range.length;

    SSignal *chunks = [OGMediaFetchSequentialSignal(descriptor, start, end, nil) map:^id(NSData *data) {
        return [[MediaResourceDataFetchResult alloc] initWithData:data complete:false];
    }];
    return [chunks then:[SSignal single:[[MediaResourceDataFetchResult alloc] initWithData:[NSData data] complete:true]]];
}
