#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "OGMediaFileSource.h"

@class TLInputFileLocation;
@class TGMediaOriginInfo;

typedef enum {
    OGMediaFetchPriorityBackground = 0,
    OGMediaFetchPriorityDownload = 1,
    OGMediaFetchPriorityInteractive = 2,
    OGMediaFetchPriorityPlayback = 3
} OGMediaFetchPriority;

@interface OGMediaFetchDescriptor : NSObject

@property (nonatomic, strong) TLInputFileLocation *location;
@property (nonatomic) NSInteger datacenterId;
@property (nonatomic) int64_t size;
@property (nonatomic) int64_t decryptedSize;
@property (nonatomic, strong) NSData *encryptionKey;
@property (nonatomic, strong) NSData *encryptionIv;
@property (nonatomic) TGNetworkMediaTypeTag mediaTypeTag;
@property (nonatomic, strong) TGMediaOriginInfo *originInfo;
@property (nonatomic) int64_t identifier;
@property (nonatomic, strong) NSString *storePath;
@property (nonatomic) int64_t sizeLimit;
@property (nonatomic) int32_t preferredPartSize;

- (NSString *)resourceKey;

@end

@interface OGMediaFetchObserver : NSObject

@property (nonatomic) bool wantsData;
@property (nonatomic, copy) void (^progress)(float progress);
@property (nonatomic, copy) void (^completed)(NSString *path, NSData *data);
@property (nonatomic, copy) void (^failed)(void);
@property (nonatomic, copy) void (^updated)(void);

@end

@interface OGMediaFetchSession : NSObject

@property (nonatomic, strong, readonly) OGMediaFetchDescriptor *descriptor;

+ (OGMediaFetchSession *)acquireSessionForDescriptor:(OGMediaFetchDescriptor *)descriptor;
+ (void)removeStalePartialFilesInDirectories:(NSArray *)directories;
- (void)relinquish;

- (id)addObserver:(OGMediaFetchObserver *)observer;
- (void)removeObserver:(id)token;
- (void)addPublishPath:(NSString *)path;

- (id)addDemandFrom:(int64_t)start to:(int64_t)end priority:(OGMediaFetchPriority)priority;
- (void)updateDemand:(id)token from:(int64_t)start to:(int64_t)end priority:(OGMediaFetchPriority)priority;
- (void)removeDemand:(id)token;

- (int64_t)size;
- (float)progress;
- (double)downloadRate;
- (bool)isComplete;
- (int64_t)availableLengthAtOffset:(int64_t)offset;
- (ssize_t)readAtOffset:(int64_t)offset buffer:(uint8_t *)buffer length:(size_t)length;

@end

SSignal *OGMediaFetchSequentialSignal(OGMediaFetchDescriptor *descriptor, int64_t start, int64_t end, void (^progress)(float progress));
