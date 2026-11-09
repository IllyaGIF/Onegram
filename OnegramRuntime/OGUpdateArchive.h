#import <Foundation/Foundation.h>

typedef enum {
    OGUpdateArchiveStatusOK = 0,
    OGUpdateArchiveStatusIO,
    OGUpdateArchiveStatusFormat,
    OGUpdateArchiveStatusUnsupported,
    OGUpdateArchiveStatusUnsafeEntry,
    OGUpdateArchiveStatusLimit,
    OGUpdateArchiveStatusChecksum,
    OGUpdateArchiveStatusNoSpace,
    OGUpdateArchiveStatusNotWritable,
    OGUpdateArchiveStatusCancelled
} OGUpdateArchiveStatus;

@interface OGUpdateArchive : NSObject

+ (OGUpdateArchiveStatus)extractApplicationFromArchiveAtPath:(NSString *)archivePath toDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t completed, uint64_t total))progress;
+ (OGUpdateArchiveStatus)replaceBundleAtPath:(NSString *)bundlePath withStagedBundleAtPath:(NSString *)stagedPath executableName:(NSString *)executableName progress:(void (^)(uint64_t completed, uint64_t total))progress;
+ (OGUpdateArchiveStatus)prepareDirectoryAtPath:(NSString *)path;
+ (void)removeItemAtPath:(NSString *)path;

@end
