#import "TGOnegramUpdater.h"

#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramCore/OGCoreHTTPSFetch.h"
#import "../OnegramCore/OGCoreJSON.h"
#import "../OnegramRuntime/OGUpdateArchive.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

NSString *const TGOnegramUpdaterStateChangedNotification = @"TGOnegramUpdaterStateChangedNotification";

static NSString *const TGOnegramUpdaterRepository = @"IllyaGIF/Onegram";
static NSString *const TGOnegramUpdaterUniversalMarker = @"armv6-armv7-arm64";
static NSString *const TGOnegramUpdaterLastCheckKey = @"TGOnegramUpdaterLastCheck";
static NSString *const TGOnegramUpdaterStagingName = @".onegram-update";
static NSString *const TGOnegramUpdaterPackageName = @"onegram-update.ipa";
static const NSTimeInterval TGOnegramUpdaterCheckInterval = 6.0 * 60.0 * 60.0;
static const uint64_t TGOnegramUpdaterMetadataLimit = 2ULL * 1024ULL * 1024ULL;
static const uint64_t TGOnegramUpdaterChecksumLimit = 4096ULL;
static const uint64_t TGOnegramUpdaterPackageLimit = 256ULL * 1024ULL * 1024ULL;
static const uint64_t TGOnegramUpdaterSpaceReserve = 16ULL * 1024ULL * 1024ULL;
static const int TGOnegramUpdaterRedirectLimit = 5;
static const int TGOnegramUpdaterIdleTimeoutSeconds = 30;
static const float TGOnegramUpdaterDownloadShare = 0.6f;
static const float TGOnegramUpdaterExtractShare = 0.35f;

static NSArray *TGOnegramUpdaterVersionComponents(NSString *text)
{
    NSUInteger index = 0;
    while (index < text.length && ([text characterAtIndex:index] == 'v' || [text characterAtIndex:index] == 'V'))
        index++;

    NSUInteger end = index;
    while (end < text.length)
    {
        unichar character = [text characterAtIndex:end];
        if (!((character >= '0' && character <= '9') || character == '.'))
            break;
        end++;
    }

    NSString *numeric = [text substringWithRange:NSMakeRange(index, end - index)];
    NSMutableArray *components = [[NSMutableArray alloc] init];
    for (NSString *component in [numeric componentsSeparatedByString:@"."])
    {
        if (component.length == 0)
            return nil;
        [components addObject:@([component longLongValue])];
    }
    return components.count == 0 ? nil : components;
}

static NSComparisonResult TGOnegramUpdaterCompareVersions(NSArray *lhs, NSArray *rhs)
{
    NSUInteger count = MAX(lhs.count, rhs.count);
    for (NSUInteger index = 0; index < count; index++)
    {
        long long left = index < lhs.count ? [lhs[index] longLongValue] : 0;
        long long right = index < rhs.count ? [rhs[index] longLongValue] : 0;
        if (left != right)
            return left < right ? NSOrderedAscending : NSOrderedDescending;
    }
    return NSOrderedSame;
}

static bool TGOnegramUpdaterHostIsTrusted(NSString *host)
{
    NSString *lowercaseHost = [host lowercaseString];
    return [lowercaseHost isEqualToString:@"github.com"] || [lowercaseHost isEqualToString:@"api.github.com"] || [lowercaseHost hasSuffix:@".githubusercontent.com"];
}

static NSData *TGOnegramUpdaterDigestFromChecksumText(NSData *data)
{
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSCharacterSet *separators = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *token in [text componentsSeparatedByCharactersInSet:separators])
    {
        if (token.length != CC_SHA256_DIGEST_LENGTH * 2)
            continue;
        NSMutableData *digest = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
        uint8_t *bytes = digest.mutableBytes;
        bool valid = true;
        for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH && valid; index++)
        {
            unsigned int value = 0;
            NSScanner *scanner = [NSScanner scannerWithString:[token substringWithRange:NSMakeRange(index * 2, 2)]];
            valid = [scanner scanHexInt:&value] && [scanner isAtEnd];
            bytes[index] = (uint8_t)value;
        }
        if (valid)
            return digest;
    }
    return nil;
}

@interface TGOnegramRelease ()

@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *notes;
@property (nonatomic, strong) NSURL *pageURL;
@property (nonatomic, strong) NSURL *packageURL;
@property (nonatomic, strong) NSURL *checksumURL;
@property (nonatomic) uint64_t packageSize;

@end

@implementation TGOnegramRelease

+ (NSString *)stringFromObject:(id)object
{
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

+ (TGOnegramRelease *)releaseWithObject:(id)object
{
    if (![object isKindOfClass:[NSDictionary class]])
        return nil;
    NSDictionary *dictionary = object;
    if ([dictionary[@"draft"] respondsToSelector:@selector(boolValue)] && [dictionary[@"draft"] boolValue])
        return nil;
    if ([dictionary[@"prerelease"] respondsToSelector:@selector(boolValue)] && [dictionary[@"prerelease"] boolValue])
        return nil;

    NSString *tag = [self stringFromObject:dictionary[@"tag_name"]];
    NSArray *versionComponents = TGOnegramUpdaterVersionComponents(tag);
    if (versionComponents == nil)
        return nil;

    NSMutableDictionary *assetsByName = [[NSMutableDictionary alloc] init];
    NSArray *assets = [dictionary[@"assets"] isKindOfClass:[NSArray class]] ? dictionary[@"assets"] : nil;
    for (id asset in assets)
    {
        if (![asset isKindOfClass:[NSDictionary class]])
            continue;
        NSString *name = [self stringFromObject:asset[@"name"]];
        if (name.length != 0)
            assetsByName[name] = asset;
    }

    NSDictionary *package = nil;
    NSDictionary *checksum = nil;
    for (NSString *name in [[assetsByName allKeys] sortedArrayUsingSelector:@selector(compare:)])
    {
        if (![[[name pathExtension] lowercaseString] isEqualToString:@"ipa"])
            continue;
        NSDictionary *candidateChecksum = assetsByName[[name stringByAppendingString:@".sha256"]];
        if (candidateChecksum == nil)
            continue;
        bool universal = [name rangeOfString:TGOnegramUpdaterUniversalMarker].location != NSNotFound;
        if (package == nil || universal)
        {
            package = assetsByName[name];
            checksum = candidateChecksum;
            if (universal)
                break;
        }
    }
    if (package == nil)
        return nil;

    NSURL *packageURL = [NSURL URLWithString:[self stringFromObject:package[@"browser_download_url"]] ?: @""];
    NSURL *checksumURL = [NSURL URLWithString:[self stringFromObject:checksum[@"browser_download_url"]] ?: @""];
    if (packageURL == nil || checksumURL == nil || ![[packageURL scheme] isEqualToString:@"https"] || ![[checksumURL scheme] isEqualToString:@"https"])
        return nil;

    TGOnegramRelease *release = [[TGOnegramRelease alloc] init];
    release.version = [versionComponents componentsJoinedByString:@"."];
    release.title = [self stringFromObject:dictionary[@"name"]].length != 0 ? [self stringFromObject:dictionary[@"name"]] : tag;
    release.notes = [self stringFromObject:dictionary[@"body"]];
    release.pageURL = [NSURL URLWithString:[self stringFromObject:dictionary[@"html_url"]] ?: @""] ?: [TGOnegramUpdater releasesPageURL];
    release.packageURL = packageURL;
    release.checksumURL = checksumURL;
    release.packageSize = [package[@"size"] respondsToSelector:@selector(unsignedLongLongValue)] ? [package[@"size"] unsignedLongLongValue] : 0;
    return release;
}

@end

@interface TGOnegramUpdaterTransfer : NSObject
{
@public
    NSMutableData *_data;
    int _fd;
    bool _digesting;
    CC_SHA256_CTX _digest;
    uint64_t _received;
    volatile int *_cancelled;
    void (^_progress)(uint64_t received, int64_t expected);
}

@end

@implementation TGOnegramUpdaterTransfer

@end

static int TGOnegramUpdaterTransferIsCancelled(void *context)
{
    TGOnegramUpdaterTransfer *transfer = (__bridge TGOnegramUpdaterTransfer *)context;
    return transfer->_cancelled != NULL && *transfer->_cancelled != 0;
}

static int TGOnegramUpdaterTransferReceive(void *context, const uint8_t *bytes, size_t length, int64_t expectedLength)
{
    TGOnegramUpdaterTransfer *transfer = (__bridge TGOnegramUpdaterTransfer *)context;
    if (transfer->_data != nil)
        [transfer->_data appendBytes:bytes length:length];
    else
    {
        const uint8_t *cursor = bytes;
        size_t remaining = length;
        while (remaining > 0)
        {
            ssize_t written = write(transfer->_fd, cursor, remaining);
            if (written < 0 && errno == EINTR)
                continue;
            if (written <= 0)
                return 1;
            cursor += written;
            remaining -= (size_t)written;
        }
    }
    if (transfer->_digesting)
        CC_SHA256_Update(&transfer->_digest, bytes, (CC_LONG)length);
    transfer->_received += length;
    if (transfer->_progress != nil)
        transfer->_progress(transfer->_received, expectedLength);
    return 0;
}

@interface TGOnegramUpdater ()
{
    dispatch_queue_t _queue;
    volatile int _cancelled;
    volatile int _committing;
    OGPlatformBackgroundTaskIdentifier _backgroundTask;
}

@property (nonatomic) TGOnegramUpdaterState state;
@property (nonatomic) TGOnegramUpdaterError error;
@property (nonatomic, strong) TGOnegramRelease *latestRelease;
@property (nonatomic) float progress;
@property (nonatomic, strong) NSDate *lastCheckDate;

@end

@implementation TGOnegramUpdater

+ (TGOnegramUpdater *)sharedUpdater
{
    static TGOnegramUpdater *updater = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        updater = [[TGOnegramUpdater alloc] init];
    });
    return updater;
}

+ (NSString *)currentVersion
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [version isKindOfClass:[NSString class]] ? version : @"";
}

+ (NSURL *)releasesPageURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@/releases/latest", TGOnegramUpdaterRepository]];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queue = dispatch_queue_create("org.onegram.updater", NULL);
        _backgroundTask = OGPlatformBackgroundTaskInvalid;
        id lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:TGOnegramUpdaterLastCheckKey];
        _lastCheckDate = [lastCheck isKindOfClass:[NSDate class]] ? lastCheck : nil;
    }
    return self;
}

- (void)setState:(TGOnegramUpdaterState)state error:(TGOnegramUpdaterError)error
{
    _state = state;
    _error = error;
    [[NSNotificationCenter defaultCenter] postNotificationName:TGOnegramUpdaterStateChangedNotification object:self];
}

- (void)publishProgress:(float)progress
{
    TGDispatchOnMainThread(^
    {
        if (_state != TGOnegramUpdaterStateDownloading && _state != TGOnegramUpdaterStateInstalling)
            return;
        if (fabsf(progress - _progress) < 0.005f && progress < 1.0f)
            return;
        _progress = progress;
        [[NSNotificationCenter defaultCenter] postNotificationName:TGOnegramUpdaterStateChangedNotification object:self];
    });
}

- (bool)hasNewerRelease
{
    return _latestRelease != nil && TGOnegramUpdaterCompareVersions(TGOnegramUpdaterVersionComponents(_latestRelease.version), TGOnegramUpdaterVersionComponents([TGOnegramUpdater currentVersion])) == NSOrderedDescending;
}

- (bool)canInstallInPlace
{
    return access([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation], W_OK | X_OK) == 0;
}

- (bool)canCancel
{
    return (_state == TGOnegramUpdaterStateDownloading || _state == TGOnegramUpdaterStateInstalling) && _committing == 0;
}

- (void)cancel
{
    if ([self canCancel])
        _cancelled = 1;
}

- (bool)isBusy
{
    return _state == TGOnegramUpdaterStateChecking || _state == TGOnegramUpdaterStateDownloading || _state == TGOnegramUpdaterStateInstalling || _state == TGOnegramUpdaterStateInstalled;
}

#pragma mark - Transport

- (TGOnegramUpdaterError)fetchURL:(NSURL *)url accept:(NSString *)accept limit:(uint64_t)limit transfer:(TGOnegramUpdaterTransfer *)transfer
{
    NSString *userAgent = [NSString stringWithFormat:@"User-Agent: Onegram/%@", [TGOnegramUpdater currentVersion]];
    NSString *acceptHeader = [@"Accept: " stringByAppendingString:accept];
    NSURL *current = url;

    for (int hop = 0; hop <= TGOnegramUpdaterRedirectLimit; hop++)
    {
        if (![[[current scheme] lowercaseString] isEqualToString:@"https"] || !TGOnegramUpdaterHostIsTrusted([current host]) || ([current port] != nil && [[current port] intValue] != 443))
            return TGOnegramUpdaterErrorNetwork;

        NSString *path = (__bridge_transfer NSString *)CFURLCopyPath((__bridge CFURLRef)current);
        NSString *query = (__bridge_transfer NSString *)CFURLCopyQueryString((__bridge CFURLRef)current, NULL);
        NSString *resource = path.length == 0 ? @"/" : path;
        if (query.length != 0)
            resource = [resource stringByAppendingFormat:@"?%@", query];

        const char *headers[] = {[userAgent UTF8String], [acceptHeader UTF8String], NULL};
        OGCoreFetchRequest request;
        memset(&request, 0, sizeof(request));
        request.host = [[current host] UTF8String];
        request.port = 443;
        request.path = [resource UTF8String];
        request.headers = headers;
        request.idleTimeoutSeconds = TGOnegramUpdaterIdleTimeoutSeconds;
        request.maximumBodyLength = limit;
        request.isCancelled = TGOnegramUpdaterTransferIsCancelled;
        request.receiveBody = TGOnegramUpdaterTransferReceive;
        request.context = (__bridge void *)transfer;

        OGCoreFetchHead head;
        OGCoreFetchStatus status = OGCoreHTTPSFetch(&request, &head);
        if (status != OGCoreFetchStatusOK)
        {
            TGLog(@"UPDATE fetch.failed host=%@ status=%d", [current host], (int)status);
            if (status == OGCoreFetchStatusCertificate)
                return TGOnegramUpdaterErrorCertificate;
            if (status == OGCoreFetchStatusTooLarge)
                return TGOnegramUpdaterErrorRelease;
            if (status == OGCoreFetchStatusRejected)
                return TGOnegramUpdaterErrorStorage;
            return TGOnegramUpdaterErrorNetwork;
        }

        if (head.statusCode == 200)
            return TGOnegramUpdaterErrorNone;

        if ((head.statusCode == 301 || head.statusCode == 302 || head.statusCode == 303 || head.statusCode == 307 || head.statusCode == 308) && head.location[0] != 0)
        {
            NSString *location = [[NSString alloc] initWithUTF8String:head.location];
            current = location == nil ? nil : [[NSURL URLWithString:location relativeToURL:current] absoluteURL];
            if (current == nil)
                return TGOnegramUpdaterErrorNetwork;
            continue;
        }

        TGLog(@"UPDATE fetch.status host=%@ code=%d", [url host], head.statusCode);
        return head.statusCode == 404 ? TGOnegramUpdaterErrorRelease : TGOnegramUpdaterErrorNetwork;
    }
    return TGOnegramUpdaterErrorNetwork;
}

#pragma mark - Checking

- (void)checkForUpdatesIfNeeded
{
    if (_lastCheckDate != nil && -[_lastCheckDate timeIntervalSinceNow] < TGOnegramUpdaterCheckInterval)
        return;
    [self checkForUpdates];
}

- (void)checkForUpdates
{
    TGDispatchOnMainThread(^
    {
        if ([self isBusy])
            return;
        [self setState:TGOnegramUpdaterStateChecking error:TGOnegramUpdaterErrorNone];

        dispatch_async(_queue, ^
        {
            TGOnegramUpdaterTransfer *transfer = [[TGOnegramUpdaterTransfer alloc] init];
            transfer->_data = [[NSMutableData alloc] init];
            transfer->_fd = -1;

            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/latest", TGOnegramUpdaterRepository]];
            TGOnegramUpdaterError error = [self fetchURL:url accept:@"application/vnd.github+json" limit:TGOnegramUpdaterMetadataLimit transfer:transfer];
            TGOnegramRelease *release = nil;
            bool noRelease = error == TGOnegramUpdaterErrorRelease;
            if (error == TGOnegramUpdaterErrorNone)
            {
                release = [TGOnegramRelease releaseWithObject:OGCoreJSONObjectWithData(transfer->_data, NULL)];
                if (release == nil)
                    noRelease = true;
            }

            TGDispatchOnMainThread(^
            {
                NSDate *now = [NSDate date];
                if (error == TGOnegramUpdaterErrorNone || noRelease)
                {
                    _lastCheckDate = now;
                    [[NSUserDefaults standardUserDefaults] setObject:now forKey:TGOnegramUpdaterLastCheckKey];
                }

                _latestRelease = release;
                if ([self hasNewerRelease])
                    [self setState:TGOnegramUpdaterStateAvailable error:TGOnegramUpdaterErrorNone];
                else if (error == TGOnegramUpdaterErrorNone || noRelease)
                    [self setState:TGOnegramUpdaterStateUpToDate error:TGOnegramUpdaterErrorNone];
                else
                    [self setState:TGOnegramUpdaterStateFailed error:error];
                TGLog(@"UPDATE check current=%@ latest=%@ state=%d error=%d", [TGOnegramUpdater currentVersion], release.version, (int)_state, (int)error);
            });
        });
    });
}

#pragma mark - Installation

- (void)installLatestRelease
{
    TGDispatchOnMainThread(^
    {
        TGOnegramRelease *release = _latestRelease;
        if ((_state != TGOnegramUpdaterStateAvailable && _state != TGOnegramUpdaterStateFailed) || ![self hasNewerRelease])
            return;

        _cancelled = 0;
        _committing = 0;
        _progress = 0.0f;
        [UIApplication sharedApplication].idleTimerDisabled = true;
        __weak TGOnegramUpdater *weakSelf = self;
        _backgroundTask = OGPlatformBeginBackgroundTask([UIApplication sharedApplication], ^
        {
            __strong TGOnegramUpdater *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (strongSelf->_committing == 0)
                strongSelf->_cancelled = 1;
            OGPlatformBackgroundTaskIdentifier task = strongSelf->_backgroundTask;
            strongSelf->_backgroundTask = OGPlatformBackgroundTaskInvalid;
            OGPlatformEndBackgroundTask([UIApplication sharedApplication], task);
        });
        [self setState:TGOnegramUpdaterStateDownloading error:TGOnegramUpdaterErrorNone];

        dispatch_async(_queue, ^
        {
            TGOnegramUpdaterError error = [self performInstallationOfRelease:release];
            bool cancelled = _cancelled != 0 && error != TGOnegramUpdaterErrorNone;

            TGDispatchOnMainThread(^
            {
                [UIApplication sharedApplication].idleTimerDisabled = false;
                if (_backgroundTask != OGPlatformBackgroundTaskInvalid)
                {
                    OGPlatformEndBackgroundTask([UIApplication sharedApplication], _backgroundTask);
                    _backgroundTask = OGPlatformBackgroundTaskInvalid;
                }
                _committing = 0;
                if (error == TGOnegramUpdaterErrorNone)
                {
                    _progress = 1.0f;
                    [self setState:TGOnegramUpdaterStateInstalled error:TGOnegramUpdaterErrorNone];
                }
                else if (cancelled)
                    [self setState:TGOnegramUpdaterStateAvailable error:TGOnegramUpdaterErrorNone];
                else
                    [self setState:TGOnegramUpdaterStateFailed error:error];
                TGLog(@"UPDATE install version=%@ error=%d cancelled=%d", release.version, (int)error, (int)cancelled);
            });
        });
    });
}

- (TGOnegramUpdaterError)errorForArchiveStatus:(OGUpdateArchiveStatus)status
{
    switch (status)
    {
        case OGUpdateArchiveStatusOK:
            return TGOnegramUpdaterErrorNone;
        case OGUpdateArchiveStatusNoSpace:
            return TGOnegramUpdaterErrorStorage;
        case OGUpdateArchiveStatusNotWritable:
            return TGOnegramUpdaterErrorNotWritable;
        case OGUpdateArchiveStatusIO:
            return TGOnegramUpdaterErrorInstall;
        default:
            return TGOnegramUpdaterErrorArchive;
    }
}

- (bool)hasFreeSpace:(uint64_t)required atPath:(NSString *)path
{
    struct statfs volume;
    if (statfs([path fileSystemRepresentation], &volume) != 0)
        return true;
    return (uint64_t)volume.f_bavail * (uint64_t)volume.f_bsize >= required + TGOnegramUpdaterSpaceReserve;
}

- (TGOnegramUpdaterError)downloadRelease:(TGOnegramRelease *)release toPath:(NSString *)packagePath
{
    TGOnegramUpdaterTransfer *checksumTransfer = [[TGOnegramUpdaterTransfer alloc] init];
    checksumTransfer->_data = [[NSMutableData alloc] init];
    checksumTransfer->_fd = -1;
    checksumTransfer->_cancelled = &_cancelled;
    TGOnegramUpdaterError error = [self fetchURL:release.checksumURL accept:@"application/octet-stream" limit:TGOnegramUpdaterChecksumLimit transfer:checksumTransfer];
    if (error != TGOnegramUpdaterErrorNone)
        return error;

    NSData *expectedDigest = TGOnegramUpdaterDigestFromChecksumText(checksumTransfer->_data);
    if (expectedDigest == nil)
        return TGOnegramUpdaterErrorRelease;
    if (release.packageSize > TGOnegramUpdaterPackageLimit)
        return TGOnegramUpdaterErrorRelease;
    if (![self hasFreeSpace:release.packageSize atPath:[packagePath stringByDeletingLastPathComponent]])
        return TGOnegramUpdaterErrorStorage;

    unlink([packagePath fileSystemRepresentation]);
    int fd = open([packagePath fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0)
        return TGOnegramUpdaterErrorStorage;

    TGOnegramUpdaterTransfer *packageTransfer = [[TGOnegramUpdaterTransfer alloc] init];
    packageTransfer->_fd = fd;
    packageTransfer->_digesting = true;
    CC_SHA256_Init(&packageTransfer->_digest);
    packageTransfer->_cancelled = &_cancelled;
    uint64_t announcedSize = release.packageSize;
    __weak TGOnegramUpdater *weakSelf = self;
    packageTransfer->_progress = ^(uint64_t received, int64_t expected)
    {
        uint64_t total = announcedSize != 0 ? announcedSize : (expected > 0 ? (uint64_t)expected : 0);
        if (total != 0)
            [weakSelf publishProgress:TGOnegramUpdaterDownloadShare * (float)MIN(1.0, (double)received / (double)total)];
    };

    error = [self fetchURL:release.packageURL accept:@"application/octet-stream" limit:TGOnegramUpdaterPackageLimit transfer:packageTransfer];
    if (close(fd) != 0 && error == TGOnegramUpdaterErrorNone)
        error = TGOnegramUpdaterErrorStorage;
    if (error != TGOnegramUpdaterErrorNone)
        return error;

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &packageTransfer->_digest);
    if (memcmp(digest, expectedDigest.bytes, CC_SHA256_DIGEST_LENGTH) != 0)
        return TGOnegramUpdaterErrorChecksum;
    return TGOnegramUpdaterErrorNone;
}

- (NSString *)validatedExecutableInStagedBundle:(NSString *)stagingPath release:(TGOnegramRelease *)release
{
    NSDictionary *stagedInfo = [NSDictionary dictionaryWithContentsOfFile:[stagingPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *bundleIdentifier = stagedInfo[@"CFBundleIdentifier"];
    NSString *executable = stagedInfo[@"CFBundleExecutable"];
    NSString *version = stagedInfo[@"CFBundleShortVersionString"];

    if (![bundleIdentifier isKindOfClass:[NSString class]] || ![bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]])
        return nil;
    if (![executable isKindOfClass:[NSString class]] || executable.length == 0 || [executable rangeOfString:@"/"].location != NSNotFound)
        return nil;
    if (![version isKindOfClass:[NSString class]] || TGOnegramUpdaterCompareVersions(TGOnegramUpdaterVersionComponents(version), TGOnegramUpdaterVersionComponents(release.version)) != NSOrderedSame)
        return nil;
    const char *executablePath = [[stagingPath stringByAppendingPathComponent:executable] fileSystemRepresentation];
    struct stat executableInfo;
    if (lstat(executablePath, &executableInfo) != 0 || !S_ISREG(executableInfo.st_mode))
        return nil;
    if ((executableInfo.st_mode & 0111) != 0111 && chmod(executablePath, 0755) != 0)
        return nil;
    return executable;
}

- (TGOnegramUpdaterError)performInstallationOfRelease:(TGOnegramRelease *)release
{
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *packagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:TGOnegramUpdaterPackageName];
    NSString *stagingPath = [bundlePath stringByAppendingPathComponent:TGOnegramUpdaterStagingName];

    if (![self canInstallInPlace])
        return TGOnegramUpdaterErrorNotWritable;

    TGOnegramUpdaterError error = [self downloadRelease:release toPath:packagePath];
    if (error != TGOnegramUpdaterErrorNone)
    {
        unlink([packagePath fileSystemRepresentation]);
        return error;
    }

    TGDispatchOnMainThread(^
    {
        if (_state == TGOnegramUpdaterStateDownloading)
            [self setState:TGOnegramUpdaterStateInstalling error:TGOnegramUpdaterErrorNone];
    });

    OGUpdateArchiveStatus status = [OGUpdateArchive prepareDirectoryAtPath:stagingPath];
    if (status == OGUpdateArchiveStatusOK)
    {
        volatile int *cancelled = &_cancelled;
        __weak TGOnegramUpdater *weakSelf = self;
        status = [OGUpdateArchive extractApplicationFromArchiveAtPath:packagePath toDirectory:stagingPath isCancelled:^bool
        {
            return *cancelled != 0;
        } progress:^(uint64_t completed, uint64_t total)
        {
            if (total != 0)
                [weakSelf publishProgress:TGOnegramUpdaterDownloadShare + TGOnegramUpdaterExtractShare * (float)((double)completed / (double)total)];
        }];
    }
    unlink([packagePath fileSystemRepresentation]);

    NSString *executable = nil;
    if (status == OGUpdateArchiveStatusOK)
    {
        executable = [self validatedExecutableInStagedBundle:stagingPath release:release];
        if (executable == nil)
        {
            [OGUpdateArchive removeItemAtPath:stagingPath];
            return TGOnegramUpdaterErrorPackage;
        }
    }
    if (status == OGUpdateArchiveStatusOK && _cancelled != 0)
        status = OGUpdateArchiveStatusCancelled;
    if (status != OGUpdateArchiveStatusOK)
    {
        [OGUpdateArchive removeItemAtPath:stagingPath];
        return [self errorForArchiveStatus:status];
    }

    _committing = 1;
    __weak TGOnegramUpdater *weakSelf = self;
    float committedShare = TGOnegramUpdaterDownloadShare + TGOnegramUpdaterExtractShare;
    status = [OGUpdateArchive replaceBundleAtPath:bundlePath withStagedBundleAtPath:stagingPath executableName:executable progress:^(uint64_t completed, uint64_t total)
    {
        if (total != 0)
            [weakSelf publishProgress:committedShare + (1.0f - committedShare) * (float)((double)completed / (double)total)];
    }];
    if (status != OGUpdateArchiveStatusOK)
    {
        TGLog(@"UPDATE commit.failed status=%d", (int)status);
        return TGOnegramUpdaterErrorInstall;
    }

    [self refreshHomeScreen];
    return TGOnegramUpdaterErrorNone;
}

- (void)refreshHomeScreen
{
    static const char *path = "/usr/bin/uicache";
    if (access(path, X_OK) != 0)
        return;

    char *const arguments[] = {(char *)"uicache", NULL};
    pid_t process = 0;
    if (posix_spawn(&process, path, NULL, NULL, arguments, environ) != 0)
        return;

    int status = 0;
    while (waitpid(process, &status, 0) < 0 && errno == EINTR)
    {
    }
}

@end
