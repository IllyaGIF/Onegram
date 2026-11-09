#import <Foundation/Foundation.h>

typedef enum {
    TGOnegramUpdaterStateIdle = 0,
    TGOnegramUpdaterStateChecking,
    TGOnegramUpdaterStateUpToDate,
    TGOnegramUpdaterStateAvailable,
    TGOnegramUpdaterStateDownloading,
    TGOnegramUpdaterStateInstalling,
    TGOnegramUpdaterStateInstalled,
    TGOnegramUpdaterStateFailed
} TGOnegramUpdaterState;

typedef enum {
    TGOnegramUpdaterErrorNone = 0,
    TGOnegramUpdaterErrorNetwork,
    TGOnegramUpdaterErrorCertificate,
    TGOnegramUpdaterErrorRelease,
    TGOnegramUpdaterErrorChecksum,
    TGOnegramUpdaterErrorArchive,
    TGOnegramUpdaterErrorPackage,
    TGOnegramUpdaterErrorStorage,
    TGOnegramUpdaterErrorNotWritable,
    TGOnegramUpdaterErrorInstall
} TGOnegramUpdaterError;

extern NSString *const TGOnegramUpdaterStateChangedNotification;

@interface TGOnegramRelease : NSObject

@property (nonatomic, strong, readonly) NSString *version;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *notes;
@property (nonatomic, strong, readonly) NSURL *pageURL;
@property (nonatomic, strong, readonly) NSURL *packageURL;
@property (nonatomic, strong, readonly) NSURL *checksumURL;
@property (nonatomic, readonly) uint64_t packageSize;

@end

@interface TGOnegramUpdater : NSObject

@property (nonatomic, readonly) TGOnegramUpdaterState state;
@property (nonatomic, readonly) TGOnegramUpdaterError error;
@property (nonatomic, strong, readonly) TGOnegramRelease *latestRelease;
@property (nonatomic, readonly) float progress;
@property (nonatomic, strong, readonly) NSDate *lastCheckDate;

+ (TGOnegramUpdater *)sharedUpdater;
+ (NSString *)currentVersion;
+ (NSURL *)releasesPageURL;

- (bool)hasNewerRelease;
- (bool)canInstallInPlace;
- (bool)canCancel;
- (void)checkForUpdates;
- (void)checkForUpdatesIfNeeded;
- (void)installLatestRelease;
- (void)cancel;

@end
