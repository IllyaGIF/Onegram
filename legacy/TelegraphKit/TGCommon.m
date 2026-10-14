#define TGCOMMON_IMPLEMENTATION 1
#define ONEGRAM_LOG_IMPLEMENTATION 1
#import "TGCommon.h"
#include <fcntl.h>
#include <unistd.h>
#include <sys/time.h>
#include <time.h>
#include <string.h>
#include <limits.h>


#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

#import <UIKit/UIKit.h>

#import <CommonCrypto/CommonDigest.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#import <CoreMotion/CoreMotion.h>
#endif

#import "OGPlatformVersion.h"
#import "../../OnegramPlatform/OGPlatformDispatch.h"

#import "TGAppDelegate.h"

#import <sys/time.h>

#import <pthread.h>

int cpuCoreCount()
{
    static int count = 0;
    if (count == 0)
    {
        size_t len;
        unsigned int ncpu;
        
        len = sizeof(ncpu);
        if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0 || ncpu == 0)
            ncpu = 1;
        count = (int)ncpu;
    }
    
    return count;
}

bool hasModernCpu()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    return iosMajorVersion() >= 7 && [CMMotionActivityManager isActivityAvailable];
#else
    return false;
#endif
}

int deviceMemorySize()
{
    static int memorySize = 0;
    if (memorySize == 0)
    {
        size_t len;
        __int64_t nmem;
        
        len = sizeof(nmem);
        if (sysctlbyname("hw.memsize", &nmem, &len, NULL, 0) != 0 || nmem <= 0)
            nmem = 512LL * 1024LL * 1024LL;
        memorySize = (int)(nmem / (1024 * 1024));
    }
    return memorySize;
}

TGPerformanceClass devicePerformanceClass()
{
    static TGPerformanceClass performanceClass = (TGPerformanceClass)-1;
    if ((int)performanceClass < 0)
    {
        int cores = cpuCoreCount();
        int memorySize = deviceMemorySize();
        if (cores <= 1 || memorySize <= 512)
            performanceClass = TGPerformanceClassConstrained;
        else if (memorySize <= 1024)
            performanceClass = TGPerformanceClassBalanced;
        else if (memorySize <= 2048 || cores <= 2)
            performanceClass = TGPerformanceClassFast;
        else
            performanceClass = TGPerformanceClassHigh;
    }
    return performanceClass;
}

int performanceBackgroundWorkerCount()
{
    int cores = MAX(cpuCoreCount(), 1);
    switch (devicePerformanceClass())
    {
        case TGPerformanceClassConstrained:
            return 1;
        case TGPerformanceClassBalanced:
            return MIN(2, cores);
        case TGPerformanceClassFast:
            return MIN(3, cores);
        case TGPerformanceClassHigh:
        default:
            return MIN(4, MAX(cores - 1, 1));
    }
}

bool TGObjectCompare(id obj1, id obj2)
{
    if (obj1 == nil && obj2 == nil)
        return true;
    
    return [obj1 isEqual:obj2];
}

bool TGStringCompare(NSString *s1, NSString *s2)
{
    if (s1.length == 0 && s2.length == 0)
        return true;
    
    if ((s1 == nil) != (s2 == nil))
        return false;
    
    return s1 == nil || [s1 isEqualToString:s2];
}

NSTimeInterval TGCurrentSystemTime()
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    
    return ((double)mach_absolute_time()) * ((double)timebase.numer) / ((double)timebase.denom) / 1e9;
}

int iosMajorVersion()
{
    return (int)OGPlatformMajorVersion();
}

int iosMinorVersion()
{
    static bool initialized = false;
    static int version = 0;
    if (!initialized)
    {
        NSString *versionString = [[UIDevice currentDevice] systemVersion];
        NSRange range = [versionString rangeOfString:@"."];
        if (range.location != NSNotFound)
            version = [[versionString substringFromIndex:range.location + 1] intValue];
        
        initialized = true;
    }
    return version;
}

void printMemoryUsage(NSString *tag)
{
    struct task_basic_info info;
    
    mach_msg_type_number_t size = sizeof(info);
    
    kern_return_t kerr = task_info(mach_task_self(),
                                   
                                   TASK_BASIC_INFO,
                                   
                                   (task_info_t)&info,
                                   
                                   &size);
    if (kerr != KERN_SUCCESS)
    {
        TGLog(@"===== %@: Error: %s", tag, mach_error_string(kerr));
    }
}

void TGDumpViews(UIView *view, NSString *indent)
{
    NSString *newIndent = [[NSString alloc] initWithFormat:@"%@    ", indent];
    for (UIView *child in view.subviews)
        TGDumpViews(child, newIndent);
}

NSString *TGEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

NSString *TGStringMD5(NSString *string)
{
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];

    return output;
}

@implementation NSNumber (IntegerTypes)

- (int32_t)int32Value
{
    return (int32_t)[self intValue];
}

- (int64_t)int64Value
{
    return (int64_t)[self longLongValue];
}

@end

static pthread_mutex_t _currentLocalizationMutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t _nativeLocalizationLoadMutex = PTHREAD_MUTEX_INITIALIZER;
static NSString *const TGNativeLocalizationCodeDefaultsKey = @"TGNativeLocalizationCode";

int TGLocalizedStaticVersion = 0;
NSString *const TGStartupLocalizationUpdatedNotification = @"TGStartupLocalizationUpdatedNotification";

static NSArray *TGStartupLocalizationKeys()
{
    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keys = @[
            @"Contacts.TabTitle",
            @"DialogList.TabTitle",
            @"Settings.TabTitle",
            @"Calls.TabTitle",
            @"DialogList.Title",
            @"DialogList.SearchLabel",
            @"Common.Back",
            @"Common.Edit",
            @"Common.Done",
            @"Common.OK",
            @"DialogList.PinLimitError",
            @"DialogList.SavedMessages",
            @"DialogList.SavedMessagesHelp",
            @"DialogList.You",
            @"Message.ImageExpired",
            @"Message.Photo",
            @"Message.VideoExpired",
            @"Message.VideoMessage",
            @"Message.Video",
            @"Message.LiveLocation",
            @"Message.Location",
            @"Message.Contact",
            @"Message.Sticker",
            @"Message.Animation",
            @"Message.Audio",
            @"Message.File",
            @"DialogList.AwaitingEncryption",
            @"DialogList.EncryptionProcessing",
            @"DialogList.EncryptionRejected",
            @"DialogList.EncryptedChatStartedOutgoing",
            @"DialogList.EncryptedChatStartedIncoming"
        ];
    });
    return keys;
}

static NSDictionary *_startupLocalizationCache = nil;
static bool _startupLocalizationCacheInitialized = false;
static TGLocalization *_startupLocalizationSource = nil;

static NSString *currentStartupLocalizationPath()
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] stringByAppendingPathComponent:@"localization-startup"];
    });
    return path;
}

static NSDictionary *TGParseStartupLocalizationFile(NSString *path)
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0)
        return nil;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text.length == 0)
        return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (NSString *line in [text componentsSeparatedByString:@"\n"])
    {
        NSRange separator = [line rangeOfString:@"\t"];
        if (separator.location == NSNotFound)
            continue;
        NSString *key = [line substringToIndex:separator.location];
        NSString *value = [line substringFromIndex:separator.location + separator.length];
        if (key.length != 0)
            result[key] = value;
    }
    return result.count == 0 ? nil : result;
}

static NSDictionary *TGDefaultStartupLocalization()
{
    NSString *code = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"dev.IllyaGIF.Onegram"] ? @"ru" : @"en";
    NSString *directory = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lproj", code]];
    NSDictionary *dict = TGParseStartupLocalizationFile([directory stringByAppendingPathComponent:@"OnegramStartup.txt"]);
    if (dict.count == 0 && ![code isEqualToString:@"en"])
    {
        directory = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"en.lproj"];
        dict = TGParseStartupLocalizationFile([directory stringByAppendingPathComponent:@"OnegramStartup.txt"]);
    }
    return dict ?: @{};
}

static void TGStoreStartupLocalization(TGLocalization *localization)
{
    if (localization == nil)
        return;

    pthread_mutex_lock(&_currentLocalizationMutex);
    bool alreadyStored = _startupLocalizationSource == localization;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (alreadyStored)
        return;

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    for (NSString *key in TGStartupLocalizationKeys())
    {
        NSString *value = [localization get:key];
        if (value.length == 0)
            continue;
        if ([value rangeOfString:@"\n"].location != NSNotFound || [value rangeOfString:@"\r"].location != NSNotFound || [value rangeOfString:@"\t"].location != NSNotFound)
            continue;
        dict[key] = value;
        [lines addObject:[[key stringByAppendingString:@"\t"] stringByAppendingString:value]];
    }

    pthread_mutex_lock(&_currentLocalizationMutex);
    _startupLocalizationCache = [dict copy];
    _startupLocalizationCacheInitialized = true;
    _startupLocalizationSource = localization;
    pthread_mutex_unlock(&_currentLocalizationMutex);

    NSString *text = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    NSString *path = currentStartupLocalizationPath();
    OGPlatformDispatchOnMainThread(^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGStartupLocalizationUpdatedNotification object:nil];
    });
    dispatch_async(OGPlatformBackgroundQueue(), ^
    {
        [text writeToFile:path atomically:true encoding:NSUTF8StringEncoding error:nil];
    });
}

NSString *TGStartupLocalized(NSString *s)
{
    if (s == nil)
        return nil;

    pthread_mutex_lock(&_currentLocalizationMutex);
    if (!_startupLocalizationCacheInitialized)
    {
        NSDictionary *dict = TGParseStartupLocalizationFile(currentStartupLocalizationPath());
        if (dict.count == 0)
            dict = TGDefaultStartupLocalization();
        _startupLocalizationCache = dict ?: @{};
        _startupLocalizationCacheInitialized = true;
    }
    NSString *value = _startupLocalizationCache[s];
    pthread_mutex_unlock(&_currentLocalizationMutex);

    if (value.length != 0)
        return value;

    NSDictionary *fallback = TGDefaultStartupLocalization();
    value = fallback[s];
    return value.length != 0 ? value : s;
}

void TGSetLocalizationFromFile(NSString *filePath) {
    if (filePath != nil) {
        NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:filePath];
        if (dict != nil) {
            setCurrentCustomLocalization([[TGLocalization alloc] initWithVersion:0 code:@"custom" dict:dict isActive:true]);
        }
    }
}

static TGLocalization *_safeCurrentNativeLocalization;
static bool _currentCustomLocalizationInitialized = false;
static TGLocalization *_safeCurrentCustomLocalization;

static NSString *currentNativeLocalizationPath() {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] stringByAppendingPathComponent:@"localization"];
    });
    return path;
}

static NSString *currentNativeExtensionLocalizationPath() {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"localization"];
    });
    return path;
}

static NSString *currentCustomLocalizationPath() {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] stringByAppendingPathComponent:@"localization-custom-active"];
    });
    return path;
}

NSString *currentLocalizationEnglishLanguageName() {
    if ([currentNativeLocalization().code isEqualToString:@"en"]) {
        return [currentNativeLocalization() get:@"Localization.EnglishLanguageName"];
    } else {
        TGLocalization *localization = [[TGLocalization alloc] initWithVersion:0 code:@"en" dict:@{} isActive:true];
        return [localization get:@"Localization.EnglishLanguageName"];
    }
}

TGLocalization *nativeEnglishLocalization() {
    if ([currentNativeLocalization().code isEqualToString:@"en"]) {
        return currentNativeLocalization();
    } else {
        TGLocalization *localization = [[TGLocalization alloc] initWithVersion:0 code:@"en" dict:@{} isActive:true];
        return localization;
    }
}

static NSString *currentNativeLocalizationCachePath() {
    return [currentNativeLocalizationPath() stringByAppendingString:@".meta"];
}

static NSArray *TGLocalizationSourceStamp(NSString *path) {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attributes == nil)
        return nil;
    return @[@([attributes fileSize]), @([[attributes fileModificationDate] timeIntervalSinceReferenceDate])];
}

typedef struct {
    uint32_t keyOffset;
    uint32_t keyLength;
    uint32_t valueOffset;
    uint32_t valueLength;
} TGLocalizationIndexEntry;

static const uint32_t TGLocalizationIndexMagic = 0x4f474c31;

@interface TGLocalizationIndexDictionary : NSDictionary
{
    NSData *_data;
    const TGLocalizationIndexEntry *_entries;
    const uint8_t *_strings;
    NSUInteger _count;
    NSMutableDictionary *_resolved;
    pthread_mutex_t _lock;
}

- (instancetype)initWithIndexData:(NSData *)data;

@end

@implementation TGLocalizationIndexDictionary

- (instancetype)initWithIndexData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        const uint8_t *bytes = (const uint8_t *)data.bytes;
        NSUInteger length = data.length;
        if (length < 8)
            return nil;
        uint32_t magic = 0;
        uint32_t count = 0;
        memcpy(&magic, bytes, 4);
        memcpy(&count, bytes + 4, 4);
        NSUInteger stringsOffset = 8 + (NSUInteger)count * sizeof(TGLocalizationIndexEntry);
        if (magic != TGLocalizationIndexMagic || stringsOffset > length)
            return nil;
        _data = data;
        _entries = (const TGLocalizationIndexEntry *)(bytes + 8);
        _strings = bytes + stringsOffset;
        _count = count;
        NSUInteger stringsLength = length - stringsOffset;
        for (NSUInteger i = 0; i < _count; i++)
        {
            if ((NSUInteger)_entries[i].keyOffset + _entries[i].keyLength > stringsLength || (NSUInteger)_entries[i].valueOffset + _entries[i].valueLength > stringsLength)
                return nil;
        }
        _resolved = [[NSMutableDictionary alloc] init];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc
{
    if (_resolved != nil)
        pthread_mutex_destroy(&_lock);
}

- (NSUInteger)count
{
    return _count;
}

- (NSString *)keyAtIndex:(NSUInteger)index
{
    return [[NSString alloc] initWithBytes:_strings + _entries[index].keyOffset length:_entries[index].keyLength encoding:NSUTF8StringEncoding];
}

- (id)objectForKey:(id)key
{
    if (![key isKindOfClass:[NSString class]])
        return nil;

    pthread_mutex_lock(&_lock);
    id cached = _resolved[key];
    pthread_mutex_unlock(&_lock);
    if (cached != nil)
        return cached == [NSNull null] ? nil : cached;

    const char *utf8 = [(NSString *)key UTF8String];
    size_t keyLength = utf8 != NULL ? strlen(utf8) : 0;
    NSString *value = nil;
    NSUInteger low = 0;
    NSUInteger high = _count;
    while (utf8 != NULL && low < high)
    {
        NSUInteger middle = low + (high - low) / 2;
        const TGLocalizationIndexEntry *entry = &_entries[middle];
        size_t common = MIN(keyLength, (size_t)entry->keyLength);
        int result = memcmp(utf8, _strings + entry->keyOffset, common);
        if (result == 0)
            result = keyLength < entry->keyLength ? -1 : (keyLength > entry->keyLength ? 1 : 0);
        if (result == 0)
        {
            value = [[NSString alloc] initWithBytes:_strings + entry->valueOffset length:entry->valueLength encoding:NSUTF8StringEncoding];
            break;
        }
        if (result < 0)
            high = middle;
        else
            low = middle + 1;
    }

    pthread_mutex_lock(&_lock);
    _resolved[key] = value ?: [NSNull null];
    pthread_mutex_unlock(&_lock);
    return value;
}

- (NSEnumerator *)keyEnumerator
{
    NSMutableArray *keys = [[NSMutableArray alloc] initWithCapacity:_count];
    for (NSUInteger i = 0; i < _count; i++)
    {
        NSString *key = [self keyAtIndex:i];
        if (key != nil)
            [keys addObject:key];
    }
    return [keys objectEnumerator];
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    return self;
}

@end

static NSData *TGLocalizationIndexData(NSDictionary *dict)
{
    NSMutableArray *pairs = [[NSMutableArray alloc] initWithCapacity:dict.count];
    for (id key in dict.keyEnumerator)
    {
        id value = dict[key];
        if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]])
            continue;
        NSData *keyData = [(NSString *)key dataUsingEncoding:NSUTF8StringEncoding];
        NSData *valueData = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
        if (keyData != nil && valueData != nil)
            [pairs addObject:@[keyData, valueData]];
    }
    [pairs sortUsingComparator:^NSComparisonResult(NSArray *lhs, NSArray *rhs)
    {
        NSData *a = lhs[0];
        NSData *b = rhs[0];
        int result = memcmp(a.bytes, b.bytes, MIN(a.length, b.length));
        if (result == 0)
            return a.length < b.length ? NSOrderedAscending : (a.length > b.length ? NSOrderedDescending : NSOrderedSame);
        return result < 0 ? NSOrderedAscending : NSOrderedDescending;
    }];

    uint32_t count = (uint32_t)pairs.count;
    NSMutableData *header = [[NSMutableData alloc] initWithCapacity:8 + count * sizeof(TGLocalizationIndexEntry)];
    NSMutableData *strings = [[NSMutableData alloc] init];
    [header appendBytes:&TGLocalizationIndexMagic length:4];
    [header appendBytes:&count length:4];
    for (NSArray *pair in pairs)
    {
        NSData *keyData = pair[0];
        NSData *valueData = pair[1];
        TGLocalizationIndexEntry entry;
        entry.keyOffset = (uint32_t)strings.length;
        entry.keyLength = (uint32_t)keyData.length;
        [strings appendData:keyData];
        entry.valueOffset = (uint32_t)strings.length;
        entry.valueLength = (uint32_t)valueData.length;
        [strings appendData:valueData];
        [header appendBytes:&entry length:sizeof(entry)];
    }
    [header appendData:strings];
    return header;
}

static NSString *currentNativeLocalizationIndexPath() {
    return [currentNativeLocalizationPath() stringByAppendingString:@".index"];
}

static TGLocalization *TGLoadCachedNativeLocalization(NSArray *stamp) {
    if (stamp == nil)
        return nil;
    NSData *metaData = [NSData dataWithContentsOfFile:currentNativeLocalizationCachePath()];
    if (metaData.length == 0)
        return nil;
    NSDictionary *meta = [NSPropertyListSerialization propertyListFromData:metaData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    if (![meta isKindOfClass:[NSDictionary class]] || ![meta[@"stamp"] isEqual:stamp] || ![meta[@"code"] isKindOfClass:[NSString class]])
        return nil;
    NSData *indexData = [NSData dataWithContentsOfFile:currentNativeLocalizationIndexPath() options:NSDataReadingMappedIfSafe error:nil];
    if (indexData.length == 0)
        return nil;
    NSDictionary *dict = [[TGLocalizationIndexDictionary alloc] initWithIndexData:indexData];
    if (dict == nil)
        return nil;
    return [[TGLocalization alloc] initWithVersion:[meta[@"version"] intValue] code:meta[@"code"] preparedDict:dict isActive:[meta[@"isActive"] boolValue]];
}

static void TGStoreCachedNativeLocalization(TGLocalization *localization, NSArray *stamp) {
    if (localization == nil || stamp == nil)
        return;
    NSDictionary *meta = @{@"stamp": stamp, @"version": @(localization.version), @"code": localization.code ?: @"", @"isActive": @(localization.isActive)};
    NSString *metaPath = currentNativeLocalizationCachePath();
    NSString *indexPath = currentNativeLocalizationIndexPath();
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.localization-index", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, OGPlatformBackgroundLowQueue());
    });
    dispatch_async(queue, ^{
        @autoreleasepool
        {
            if (![TGLocalizationSourceStamp(currentNativeLocalizationPath()) isEqual:stamp])
                return;
            NSData *indexData = TGLocalizationIndexData([localization dictionaryRepresentation]);
            NSData *metaData = [NSPropertyListSerialization dataFromPropertyList:meta format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
            if (indexData == nil || metaData == nil)
                return;
            [[NSFileManager defaultManager] removeItemAtPath:metaPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[currentNativeLocalizationPath() stringByAppendingString:@".cache"] error:nil];
            if ([indexData writeToFile:indexPath atomically:true] && [TGLocalizationSourceStamp(currentNativeLocalizationPath()) isEqual:stamp])
                [metaData writeToFile:metaPath atomically:true];
        }
    });
}

TGLocalization *currentNativeLocalization() {
    TGLocalization *value = nil;
    pthread_mutex_lock(&_currentLocalizationMutex);
    value = _safeCurrentNativeLocalization;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (value != nil)
        return value;

    pthread_mutex_lock(&_nativeLocalizationLoadMutex);
    pthread_mutex_lock(&_currentLocalizationMutex);
    value = _safeCurrentNativeLocalization;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (value == nil) {
        CFAbsoluteTime totalStart = CFAbsoluteTimeGetCurrent();
        CFAbsoluteTime phaseStart = totalStart;
        NSArray *stamp = TGLocalizationSourceStamp(currentNativeLocalizationPath());
        value = TGLoadCachedNativeLocalization(stamp);
        if (value == nil && stamp != nil) {
            phaseStart = CFAbsoluteTimeGetCurrent();
            NSData *data = [NSData dataWithContentsOfFile:currentNativeLocalizationPath()];
            if (data.length != 0) {
                phaseStart = CFAbsoluteTimeGetCurrent();
                value = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                if ([value isKindOfClass:[TGLocalization class]])
                    TGStoreCachedNativeLocalization(value, stamp);
            }
        }
        if (value == nil) {
            phaseStart = CFAbsoluteTimeGetCurrent();
            NSString *nativeLanguage = @"en";
            NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
            if ([bundleIdentifier isEqualToString:@"dev.IllyaGIF.Onegram"]) {
                nativeLanguage = @"ru";
            }
            value = [[TGLocalization alloc] initWithVersion:0 code:nativeLanguage dict:@{} isActive:true];
        }
        if (value != nil) {
            pthread_mutex_lock(&_currentLocalizationMutex);
            _safeCurrentNativeLocalization = value;
            pthread_mutex_unlock(&_currentLocalizationMutex);
            if (value.code.length != 0 && ![[[NSUserDefaults standardUserDefaults] stringForKey:TGNativeLocalizationCodeDefaultsKey] isEqualToString:value.code])
                [[NSUserDefaults standardUserDefaults] setObject:value.code forKey:TGNativeLocalizationCodeDefaultsKey];
        }
    }
    pthread_mutex_unlock(&_nativeLocalizationLoadMutex);
    return value;
}

NSString *currentNativeLocalizationCode() {
    pthread_mutex_lock(&_currentLocalizationMutex);
    TGLocalization *value = _safeCurrentNativeLocalization;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (value != nil)
        return value.code;

    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:TGNativeLocalizationCodeDefaultsKey];
    if (code.length != 0)
        return code;

    return currentNativeLocalization().code;
}

static NSString *legacyCustomLocalizationBundlePath() {
    return [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"CustomLocalization.bundle"];
}

TGLocalization *currentCustomLocalization() {
    TGLocalization *value = nil;
    bool initialized = false;
    pthread_mutex_lock(&_currentLocalizationMutex);
    value = _safeCurrentCustomLocalization;
    initialized = _currentCustomLocalizationInitialized;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (!initialized) {
        CFAbsoluteTime totalStart = CFAbsoluteTimeGetCurrent();
        CFAbsoluteTime phaseStart = totalStart;
        NSData *data = [NSData dataWithContentsOfFile:currentCustomLocalizationPath()];
        if (data.length != 0) {
            phaseStart = CFAbsoluteTimeGetCurrent();
            value = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } else {
            phaseStart = CFAbsoluteTimeGetCurrent();
            NSBundle *bundle = [NSBundle bundleWithPath:legacyCustomLocalizationBundlePath()];
            NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"];
            if (path != nil) {
                phaseStart = CFAbsoluteTimeGetCurrent();
                NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:path];
                if (dict != nil) {
                    [[NSFileManager defaultManager] removeItemAtPath:legacyCustomLocalizationBundlePath() error:nil];
                    TGLocalization *localization = [[TGLocalization alloc] initWithVersion:0 code:@"custom" dict:dict isActive:true];
                    setCurrentCustomLocalization(localization);
                    value = localization;
                }
            }
        }
        
        pthread_mutex_lock(&_currentLocalizationMutex);
        _safeCurrentCustomLocalization = value;
        _currentCustomLocalizationInitialized = true;
        pthread_mutex_unlock(&_currentLocalizationMutex);
    }
    return value;
}

TGLocalization *effectiveLocalization() {
    TGLocalization *custom = currentCustomLocalization();
    if (custom.isActive) {
        TGStoreStartupLocalization(custom);
        return custom;
    }
    TGLocalization *native = currentNativeLocalization();
    TGStoreStartupLocalization(native);
    return native;
}

void setCurrentNativeLocalization(TGLocalization *localization, bool switchIfCustom) {
    pthread_mutex_lock(&_currentLocalizationMutex);
    _safeCurrentNativeLocalization = localization;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    if (localization.code.length != 0)
        [[NSUserDefaults standardUserDefaults] setObject:localization.code forKey:TGNativeLocalizationCodeDefaultsKey];
    else
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGNativeLocalizationCodeDefaultsKey];
    
    NSString *nativePath = currentNativeLocalizationPath();
    NSString *extensionPath = currentNativeExtensionLocalizationPath();
    NSString *cachePath = currentNativeLocalizationCachePath();
    NSString *indexPath = currentNativeLocalizationIndexPath();
    static dispatch_queue_t persistenceQueue = NULL;
    static dispatch_once_t persistenceOnceToken;
    dispatch_once(&persistenceOnceToken, ^
    {
        persistenceQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.localization-persistence", DISPATCH_QUEUE_SERIAL);
    });
    dispatch_async(persistenceQueue, ^
    {
        @autoreleasepool
        {
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            [fileManager removeItemAtPath:nativePath error:nil];
            [fileManager removeItemAtPath:cachePath error:nil];
            [fileManager removeItemAtPath:indexPath error:nil];
            if (![extensionPath isEqualToString:nativePath])
                [fileManager removeItemAtPath:extensionPath error:nil];
            if ([NSKeyedArchiver archiveRootObject:localization toFile:nativePath])
                TGStoreCachedNativeLocalization(localization, TGLocalizationSourceStamp(nativePath));
            if (![extensionPath isEqualToString:nativePath])
                [fileManager copyItemAtPath:nativePath toPath:extensionPath error:nil];
        }
    });
    TGLocalizedStaticVersion++;
    
    if (switchIfCustom) {
        setCurrentCustomLocalization([currentCustomLocalization() withUpdatedIsActive:false]);
    }
}

void setCurrentCustomLocalization(TGLocalization *localization) {
    pthread_mutex_lock(&_currentLocalizationMutex);
    _safeCurrentCustomLocalization = localization;
    _currentCustomLocalizationInitialized = true;
    pthread_mutex_unlock(&_currentLocalizationMutex);
    
    [[NSFileManager defaultManager] removeItemAtPath:currentCustomLocalizationPath() error:nil];
    if (localization != nil) {
        [NSKeyedArchiver archiveRootObject:localization toFile:currentCustomLocalizationPath()];
    }
    TGLocalizedStaticVersion++;
}

NSString *TGLocalized(NSString *s)
{
    TGLocalization *localization = effectiveLocalization();
    NSString *result = [localization get:s];
    return result;
}

static const void *TGLogQueueSpecificKey = &TGLogQueueSpecificKey;

static dispatch_queue_t TGLogQueue()
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.telegraphkit.logging", 0);
        dispatch_queue_set_specific(queue, TGLogQueueSpecificKey, (void *)TGLogQueueSpecificKey, NULL);
    });
    return queue;
}

NSString *TGIOS6DiagnosticBreadcrumbPath()
{
    return [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"ios6_diagnostic_breadcrumbs.log"];
}

static int TGIOS6DiagnosticBreadcrumbFd = -1;
static pthread_mutex_t TGIOS6DiagnosticBreadcrumbMutex = PTHREAD_MUTEX_INITIALIZER;
static char TGIOS6DiagnosticPreparedPath[PATH_MAX];

static bool TGIOS6MessageIsDiagnosticBreadcrumb(NSString *message)
{
    if (message.length == 0)
        return false;

    if ([message hasPrefix:@"IOS6"])
        return true;

    NSArray *tokens = @[
        @"phone_requestCall", @"phone_acceptCall", @"phone_confirmCall",
        @"phone_discardCall", @"phone_receivedCall", @"phone_sendSignalingData",
        @"CALL ", @"CALL_", @"PHONE_", @"PEER_ID_INVALID", @"error:", @"rpcError"
    ];
    for (NSString *token in tokens)
    {
        if ([message rangeOfString:token options:NSCaseInsensitiveSearch].location != NSNotFound)
            return true;
    }
    return false;
}

static bool TGIOS6NativeMessageIsUseful(const char *bytes)
{
    if (bytes == NULL || bytes[0] == 0)
        return false;

    const char *tokens[] = {
        "IOS6",
        "phone_requestCall", "phone_acceptCall", "phone_confirmCall",
        "phone_discardCall", "phone_receivedCall", "phone_sendSignalingData",
        "CALL ", "CALL_", "PHONE_", "PEER_ID_INVALID", "error:", "rpcError",
        "SIGSEGV", "SIGABRT", "exception", "fatal"
    };
    const size_t tokenCount = sizeof(tokens) / sizeof(tokens[0]);
    for (size_t i = 0; i < tokenCount; i++)
    {
        if (strstr(bytes, tokens[i]) != NULL)
            return true;
    }
    return false;
}

void TGIOS6NativeDiagnosticWrite(const char *bytes, size_t length)
{
    if (bytes == NULL || length == 0 || !TGIOS6NativeMessageIsUseful(bytes))
        return;

    char line[4096];
    struct timeval tv;
    gettimeofday(&tv, NULL);
    time_t rawtime = tv.tv_sec;
    struct tm timeinfo;
    localtime_r(&rawtime, &timeinfo);

    int prefixLength = snprintf(line, sizeof(line),
        "%04d-%02d-%02d %02d:%02d:%02d.%03d ",
        timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
        timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec,
        (int)(tv.tv_usec / 1000));
    if (prefixLength < 0)
        prefixLength = 0;
    if ((size_t)prefixLength >= sizeof(line))
        prefixLength = (int)sizeof(line) - 1;

    size_t available = sizeof(line) - (size_t)prefixLength - 2;
    size_t copyLength = length < available ? length : available;
    memcpy(line + prefixLength, bytes, copyLength);
    size_t total = (size_t)prefixLength + copyLength;
    while (total > 0 && (line[total - 1] == '\n' || line[total - 1] == '\r'))
        total--;
    line[total++] = '\n';

    pthread_mutex_lock(&TGIOS6DiagnosticBreadcrumbMutex);
    if (TGIOS6DiagnosticBreadcrumbFd < 0 && TGIOS6DiagnosticPreparedPath[0] != 0)
        TGIOS6DiagnosticBreadcrumbFd = open(TGIOS6DiagnosticPreparedPath, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (TGIOS6DiagnosticBreadcrumbFd >= 0)
        write(TGIOS6DiagnosticBreadcrumbFd, line, total);
    pthread_mutex_unlock(&TGIOS6DiagnosticBreadcrumbMutex);
}

static void TGIOS6WriteDiagnosticBreadcrumb(NSString *message)
{
    const char *utf8 = [message UTF8String];
    if (utf8 != NULL)
        TGIOS6NativeDiagnosticWrite(utf8, strlen(utf8));
}

void TGIOS6PrepareDiagnosticBreadcrumbs()
{
#if !defined(ONEGRAM_DIAGNOSTICS)
    return;
#endif
    void (^block)(void) = ^
    {
        NSString *path = TGIOS6DiagnosticBreadcrumbPath();
        pthread_mutex_lock(&TGIOS6DiagnosticBreadcrumbMutex);
        const char *filePath = [path fileSystemRepresentation];
        TGIOS6DiagnosticPreparedPath[0] = 0;
        if (filePath != NULL)
            strlcpy(TGIOS6DiagnosticPreparedPath, filePath, sizeof(TGIOS6DiagnosticPreparedPath));
        if (TGIOS6DiagnosticBreadcrumbFd >= 0)
        {
            close(TGIOS6DiagnosticBreadcrumbFd);
            TGIOS6DiagnosticBreadcrumbFd = -1;
        }
        if (filePath != NULL)
            TGIOS6DiagnosticBreadcrumbFd = open(filePath, O_WRONLY | O_CREAT | O_TRUNC | O_APPEND, 0644);
        pthread_mutex_unlock(&TGIOS6DiagnosticBreadcrumbMutex);
    };

    if (dispatch_get_specific(TGLogQueueSpecificKey) != NULL)
        block();
    else
        dispatch_sync(TGLogQueue(), block);
}

static NSFileHandle *TGCurrentLogFileHandle;

static NSFileHandle *TGLogFileHandle()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        NSString *documentsDirectory = [TGAppDelegate documentsPath];
        
        NSString *currentFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-0.log"];
        NSString *oldestFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-30.log"];
        
        if ([fileManager fileExistsAtPath:oldestFilePath])
            [fileManager removeItemAtPath:oldestFilePath error:nil];
        
        for (int i = 60 - 1; i >= 0; i--)
        {
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i]];
            NSString *nextFilePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i + 1]];
            if ([fileManager fileExistsAtPath:filePath])
            {
                [fileManager moveItemAtPath:filePath toPath:nextFilePath error:nil];
            }
        }
        
        [fileManager createFileAtPath:currentFilePath contents:nil attributes:nil];
        TGCurrentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:currentFilePath];
        [TGCurrentLogFileHandle truncateFileAtOffset:0];
    });
    
    if (TGCurrentLogFileHandle == nil) {
        NSString *path = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"application-0.log"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:path])
            [fileManager createFileAtPath:path contents:nil attributes:nil];
        TGCurrentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        [TGCurrentLogFileHandle seekToEndOfFile];
    }
    return TGCurrentLogFileHandle;
}

bool TGDeleteLogFile(NSString *path, NSError **error)
{
    NSString *target = [path stringByStandardizingPath];
    NSString *documents = [[TGAppDelegate documentsPath] stringByStandardizingPath];
    NSString *parent = [target stringByDeletingLastPathComponent];
    NSString *name = [target lastPathComponent];
    bool valid = [parent isEqualToString:[documents stringByAppendingPathComponent:@"OnegramLogs"]] && [[name pathExtension] isEqualToString:@"log"];
    if ([parent isEqualToString:documents]) {
        valid = [name isEqualToString:@"ios6_diagnostic_breadcrumbs.log"] || [name isEqualToString:@"ios6_last_crash.txt"];
        for (int i = 0; !valid && i <= 60; i++)
            valid = [name isEqualToString:[NSString stringWithFormat:@"application-%d.log", i]];
    }
    if (!valid) {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
        return false;
    }
    __block bool removed = false;
    __block NSError *removalError = nil;
    void (^block)(void) = ^{
        bool liveLog = [target isEqualToString:[documents stringByAppendingPathComponent:@"application-0.log"]];
        bool breadcrumbs = [target isEqualToString:TGIOS6DiagnosticBreadcrumbPath()];
        if (breadcrumbs)
            pthread_mutex_lock(&TGIOS6DiagnosticBreadcrumbMutex);
        BOOL isDirectory = false;
        if ([[NSFileManager defaultManager] fileExistsAtPath:target isDirectory:&isDirectory] && isDirectory)
            removalError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
        else
            removed = [[NSFileManager defaultManager] removeItemAtPath:target error:&removalError];
        if (removed && liveLog) {
            [TGCurrentLogFileHandle closeFile];
            TGCurrentLogFileHandle = nil;
        }
        if (breadcrumbs) {
            if (removed && TGIOS6DiagnosticBreadcrumbFd >= 0) {
                close(TGIOS6DiagnosticBreadcrumbFd);
                TGIOS6DiagnosticBreadcrumbFd = -1;
            }
            pthread_mutex_unlock(&TGIOS6DiagnosticBreadcrumbMutex);
        }
    };
    if (dispatch_get_specific(TGLogQueueSpecificKey) != NULL)
        block();
    else
        dispatch_sync(TGLogQueue(), block);
    if (error != NULL)
        *error = removalError;
    return removed;
}

void TGLogSynchronize()
{
#if !defined(ONEGRAM_DIAGNOSTICS)
    return;
#endif
    dispatch_async(TGLogQueue(), ^
    {
        [TGLogFileHandle() synchronizeFile];
    });
}

void TGLogClear()
{
    dispatch_sync(TGLogQueue(), ^
    {
        NSFileHandle *output = TGLogFileHandle();
        if (output != nil)
        {
            [output synchronizeFile];
            [output truncateFileAtOffset:0];
            [output seekToFileOffset:0];
        }
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSString *documentsDirectory = [TGAppDelegate documentsPath];
        for (int i = 1; i <= 60; i++)
        {
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i]];
            if ([fileManager fileExistsAtPath:filePath])
                [fileManager removeItemAtPath:filePath error:nil];
        }

        NSString *crashPath = [documentsDirectory stringByAppendingPathComponent:@"ios6_last_crash.txt"];
        if ([fileManager fileExistsAtPath:crashPath])
            [fileManager removeItemAtPath:crashPath error:nil];
        NSString *breadcrumbsPath = [documentsDirectory stringByAppendingPathComponent:@"ios6_diagnostic_breadcrumbs.log"];
        if ([fileManager fileExistsAtPath:breadcrumbsPath])
            [fileManager removeItemAtPath:breadcrumbsPath error:nil];

        TGIOS6PrepareDiagnosticBreadcrumbs();
    });
}

static bool logEnabled =
#if (defined(DEBUG) || defined(INTERNAL_RELEASE)) && !defined(DISABLE_LOGGING)
    true;
#else
    false;
#endif

void TGLogSetEnabled(bool enabled)
{
    logEnabled = enabled;
}

bool TGLogEnabled()
{
    return logEnabled;
}

bool TGLogAvailable()
{
#if defined(ONEGRAM_DIAGNOSTICS)
    return true;
#else
    return false;
#endif
}

#undef TGLog
#undef TGLogv
void TGLog(NSString *format, ...);
void TGLogv(NSString *format, va_list args);

void TGLog(NSString *format, ...)
{
#if !defined(ONEGRAM_DIAGNOSTICS)
    (void)format;
    return;
#endif

    if (!logEnabled && !TGIOS6MessageIsDiagnosticBreadcrumb(format))
        return;

    va_list L;
    va_start(L, format);
    TGLogv(format, L);
    va_end(L);
}

static void TGWriteLogMessage(NSString *message, bool synchronize)
{
    NSFileHandle *output = TGLogFileHandle();
    if (output == nil)
        return;

    time_t rawtime;
    struct tm timeinfo;
    char buffer[64];
    time(&rawtime);
    localtime_r(&rawtime, &timeinfo);
    struct timeval curTime;
    gettimeofday(&curTime, NULL);
    int milliseconds = curTime.tv_usec / 1000;
    strftime(buffer, 64, "%Y-%m-%d %H:%M", &timeinfo);
    char fullBuffer[128] = { 0 };
    snprintf(fullBuffer, 128, "%s:%2d.%.3d ", buffer, timeinfo.tm_sec, milliseconds);

    [output writeData:[[[NSString alloc] initWithCString:fullBuffer encoding:NSASCIIStringEncoding] dataUsingEncoding:NSUTF8StringEncoding]];
    [output writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];

    static NSData *returnData = nil;
    if (returnData == nil)
        returnData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    [output writeData:returnData];

    if (synchronize)
        [output synchronizeFile];
}

static double TGLogProcessUptime(void)
{
    static double processStartTime = 0.0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        struct kinfo_proc info;
        size_t size = sizeof(info);
        int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
        memset(&info, 0, sizeof(info));
        if (sysctl(mib, 4, &info, &size, NULL, 0) == 0 && size > 0)
            processStartTime = info.kp_proc.p_starttime.tv_sec + info.kp_proc.p_starttime.tv_usec / 1000000.0;
    });

    struct timeval now;
    gettimeofday(&now, NULL);
    double nowTime = now.tv_sec + now.tv_usec / 1000000.0;
    return processStartTime > 0.0 ? nowTime - processStartTime : 0.0;
}

void TGLogv(NSString *format, va_list args)
{
#if !defined(ONEGRAM_DIAGNOSTICS)
    (void)format;
    (void)args;
    return;
#endif
    if (!logEnabled && !TGIOS6MessageIsDiagnosticBreadcrumb(format))
        return;

    double uptime = TGLogProcessUptime();
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    bool diagnosticBreadcrumb = TGIOS6MessageIsDiagnosticBreadcrumb(message);
    if (!logEnabled && !diagnosticBreadcrumb)
        return;

    if (diagnosticBreadcrumb)
        TGIOS6WriteDiagnosticBreadcrumb(message);

    dispatch_async(TGLogQueue(), ^
    {
        TGWriteLogMessage(message, diagnosticBreadcrumb);
    });
}

NSArray *TGGetLogFilePaths(int count)
{
    NSMutableArray *filePaths = [[NSMutableArray alloc] init];
    
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    
    for (int i = 0; i <= count; i++)
    {
        NSString *fileName = [NSString stringWithFormat:@"application-%d.log", i];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            [filePaths addObject:filePath];
        }
    }
    
    return filePaths;
}

static NSString *TGArchivedLogsDirectoryPath()
{
    NSString *path = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"OnegramLogs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:nil];
    return path;
}

static NSString *TGArchivedLogPath(NSString *prefix, NSDate *date)
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:date ?: [NSDate date]];
    NSString *directory = TGArchivedLogsDirectoryPath();
    NSString *path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.log", prefix, timestamp]];
    int suffix = 1;
    while ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-%d.log", prefix, timestamp, suffix]];
        suffix++;
    }
    return path;
}

NSArray *TGGetArchivedLogFilePaths()
{
    NSString *directory = TGArchivedLogsDirectoryPath();
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    for (NSString *entry in entries)
    {
        if (![[[entry pathExtension] lowercaseString] isEqualToString:@"log"])
            continue;
        NSString *path = [directory stringByAppendingPathComponent:entry];
        BOOL isDirectory = false;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory)
            [paths addObject:path];
    }
    [paths sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2)
    {
        NSDate *date1 = [[[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil] objectForKey:NSFileModificationDate];
        NSDate *date2 = [[[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:nil] objectForKey:NSFileModificationDate];
        if (date1 == nil && date2 == nil)
            return [path2 compare:path1];
        if (date1 == nil)
            return NSOrderedDescending;
        if (date2 == nil)
            return NSOrderedAscending;
        return [date2 compare:date1];
    }];
    return paths;
}

NSString *TGArchiveCrashLogText(NSString *text, NSDate *date)
{
    if (text.length == 0)
        return nil;
    NSString *path = TGArchivedLogPath(@"Crash", date ?: [NSDate date]);
    if (![text writeToFile:path atomically:true encoding:NSUTF8StringEncoding error:nil])
        return nil;
    return path;
}

NSString *TGSaveCurrentLogLines(int lineCount)
{
    if (lineCount <= 0)
        return nil;

    __block NSString *resultText = nil;
    void (^readBlock)(void) = ^
    {
        [TGLogFileHandle() synchronizeFile];
        NSMutableArray *lines = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)lineCount];
        NSArray *paths = TGGetLogFilePaths(60);
        for (NSString *path in paths)
        {
            if ((int)lines.count >= lineCount)
                break;

            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            unsigned long long fileSize = [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
            if (fileSize == 0)
                continue;

            const unsigned long long maximumReadSize = 1024 * 1024;
            unsigned long long readSize = MIN(fileSize, maximumReadSize);
            unsigned long long startOffset = fileSize - readSize;
            NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
            if (handle == nil)
                continue;

            [handle seekToFileOffset:startOffset];
            NSData *data = [handle readDataToEndOfFile];
            [handle closeFile];

            if (startOffset != 0 && data.length != 0)
            {
                const uint8_t *bytes = data.bytes;
                NSUInteger skip = 0;
                while (skip < data.length && bytes[skip] != '\n')
                    skip++;
                if (skip < data.length)
                    skip++;
                if (skip >= data.length)
                    continue;
                if (skip != 0)
                    data = [data subdataWithRange:NSMakeRange(skip, data.length - skip)];
            }

            NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (contents == nil)
                contents = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
            if (contents.length == 0)
                continue;

            NSArray *fileLines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            for (NSInteger index = (NSInteger)fileLines.count - 1; index >= 0 && (int)lines.count < lineCount; index--)
            {
                NSString *line = fileLines[(NSUInteger)index];
                if (line.length == 0)
                    continue;
                [lines insertObject:line atIndex:0];
            }
        }

        if (lines.count != 0)
            resultText = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    };

    if (dispatch_get_specific(TGLogQueueSpecificKey) != NULL)
        readBlock();
    else
        dispatch_sync(TGLogQueue(), readBlock);

    if (resultText.length == 0)
        return nil;

    NSString *path = TGArchivedLogPath(@"Live", [NSDate date]);
    if (![resultText writeToFile:path atomically:true encoding:NSUTF8StringEncoding error:nil])
        return nil;
    return path;
}

NSArray *TGGetPackedLogs()
{
    NSMutableArray *resultFiles = [[NSMutableArray alloc] init];
    
    dispatch_sync(TGLogQueue(), ^
    {
        [TGLogFileHandle() synchronizeFile];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        NSString *documentsDirectory = [TGAppDelegate documentsPath];
        
        for (int i = 0; i <= 4; i++)
        {
            NSString *fileName = [NSString stringWithFormat:@"application-%d.log", i];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            if ([fileManager fileExistsAtPath:filePath])
            {
                NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
                if (fileData != nil)
                    [resultFiles addObject:fileData];
            }
        }
    });
    
    return resultFiles;
}
