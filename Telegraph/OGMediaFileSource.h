#import <Foundation/Foundation.h>

#import "TGTelegramNetworking.h"

@class TLInputFileLocation;
@class TGMediaOriginInfo;

typedef enum {
    OGMediaPartResultData,
    OGMediaPartResultRestart,
    OGMediaPartResultRetry,
    OGMediaPartResultFailure
} OGMediaPartResult;

dispatch_queue_t OGMediaFetchQueue(void);

@interface OGMediaFileSource : NSObject

@property (nonatomic, copy) void (^availabilityChanged)(void);
@property (nonatomic, readonly) bool available;
@property (nonatomic, readonly) bool usesCdn;

- (instancetype)initWithLocation:(TLInputFileLocation *)location datacenterId:(NSInteger)datacenterId size:(int64_t)size mediaTypeTag:(TGNetworkMediaTypeTag)mediaTypeTag originInfo:(TGMediaOriginInfo *)originInfo identifier:(int64_t)identifier;

- (id)requestPartAtOffset:(int64_t)offset limit:(int32_t)limit progress:(void (^)(int32_t receivedBytes, int32_t totalBytes))progress completion:(void (^)(OGMediaPartResult result, NSData *data))completion;
- (void)cancelPart:(id)token;
- (void)invalidate;

@end
