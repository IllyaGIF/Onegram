#import "TGCrashReportCenter.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGAppDelegate.h"
#import "TGRootController.h"
#import "TGTelegraph.h"
#import "TGPresentation.h"
#import "TGTelegramNetworking.h"
#import "TL/TLMetaScheme.h"
#import "TGUser+Telegraph.h"
#import "TGUserDataRequestBuilder.h"
#import "TGSendMessageSignals.h"
#import "TGUploadFileSignals.h"
#import "TLInputMediaUploadedDocument.h"
#import "../legacy/TelegraphKit/TGCommon.h"
#import "TGOnegramCardOverlay.h"
#import "../OnegramRuntime/OGCrashSession.h"

#include <sys/sysctl.h>
#include <mach/mach.h>
#include <limits.h>
#include <time.h>
#include <stdio.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach_time.h>
#include <malloc/malloc.h>

static NSString *const TGCrashReportsEnabledKey = @"Onegram.CrashReports.Enabled";
static NSString *const TGCrashReportsHandledDateKey = @"Onegram.CrashReports.HandledDate";
static NSString *const TGCrashReportsHandledFilesKey = @"Onegram.CrashReports.HandledFiles";
static NSString *const TGCrashReportDeveloperUsername = @"IllyaGIF";
static const int64_t TGCrashReportDeveloperUserId = 1448306214;
static const NSUInteger TGCrashReportMaximumReports = 3;
static const NSUInteger TGCrashReportMaximumReportLength = 512 * 1024;
static const NSTimeInterval TGCrashReportInitialLookback = 3.0 * 24.0 * 60.0 * 60.0;
static OGCrashSessionRecord TGCrashSession;
static char TGCrashSessionPath[PATH_MAX];
static bool TGCrashSessionRecovered = false;
static dispatch_queue_t TGCrashSessionQueue;
static dispatch_source_t TGCrashSessionTimer;
static bool TGCrashSessionActive;
static bool TGCrashSessionProbePending;
static uint64_t TGCrashSessionProbeStarted;
static uint64_t TGCrashSessionProbeGeneration;
static uint64_t TGCrashSessionLastLog;

static uint64_t TGCrashMonotonicMilliseconds(void)
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    return (uint64_t)((long double)mach_absolute_time() * info.numer / info.denom / 1000000.0L);
}

static void TGCrashExecutableUUID(char *result, size_t capacity)
{
    const struct mach_header *header = _dyld_get_image_header(0);
    if (header == NULL)
        return;
    const uint8_t *cursor = (const uint8_t *)header + (header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t i = 0; i < header->ncmds && (size_t)(end - cursor) >= sizeof(struct load_command); i++)
    {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor))
            break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command))
        {
            const uint8_t *uuid = ((const struct uuid_command *)command)->uuid;
            snprintf(result, capacity, "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x", uuid[0], uuid[1], uuid[2], uuid[3], uuid[4], uuid[5], uuid[6], uuid[7], uuid[8], uuid[9], uuid[10], uuid[11], uuid[12], uuid[13], uuid[14], uuid[15]);
            return;
        }
        cursor += command->cmdsize;
    }
}

typedef enum {
    TGCrashReadComplete,
    TGCrashReadTail,
    TGCrashReadHead
} TGCrashTextReadMode;

static NSString *TGCrashReadText(NSString *path, NSUInteger maximumBytes, TGCrashTextReadMode position)
{
    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0)
        return nil;
    off_t size = lseek(fd, 0, SEEK_END);
    if (size < 0 || (position == TGCrashReadComplete && (uint64_t)size > maximumBytes))
    {
        close(fd);
        return nil;
    }
    off_t start = position == TGCrashReadTail && (uint64_t)size > maximumBytes ? size - maximumBytes : 0;
    if (lseek(fd, start, SEEK_SET) < 0)
    {
        close(fd);
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithLength:(NSUInteger)MIN((uint64_t)size, maximumBytes)];
    NSUInteger total = 0;
    while (total < data.length)
    {
        ssize_t count = read(fd, (uint8_t *)data.mutableBytes + total, data.length - total);
        if (count < 0 && errno == EINTR)
            continue;
        if (count < 0)
        {
            close(fd);
            return nil;
        }
        if (count == 0)
            break;
        total += (NSUInteger)count;
    }
    close(fd);
    [data setLength:total];
    if (start != 0)
    {
        const uint8_t *newline = memchr(data.bytes, '\n', data.length);
        if (newline == NULL)
            return @"";
        NSUInteger skipped = newline - (const uint8_t *)data.bytes + 1;
        [data replaceBytesInRange:NSMakeRange(0, skipped) withBytes:NULL length:0];
    }
    if (position == TGCrashReadHead && (uint64_t)size > total)
    {
        const uint8_t *bytes = data.bytes;
        while (total > 0 && bytes[total - 1] != '\n')
            total--;
        [data setLength:total];
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString *TGCrashReadReport(NSString *path)
{
    NSString *text = TGCrashReadText(path, TGCrashReportMaximumReportLength, TGCrashReadComplete);
    if (text != nil)
        return text;
    NSString *head = TGCrashReadText(path, TGCrashReportMaximumReportLength / 2, TGCrashReadHead);
    NSString *tail = TGCrashReadText(path, TGCrashReportMaximumReportLength / 2, TGCrashReadTail);
    if (head == nil || tail == nil)
        return nil;
    return [NSString stringWithFormat:@"%@\nCRASH report_truncated=middle_omitted\n%@", head, tail];
}

static uint64_t TGCrashReportNumber(NSString *text, NSString *name)
{
    NSString *prefix = [NSString stringWithFormat:@"CRASH %@=", name];
    for (NSString *line in [text componentsSeparatedByString:@"\n"])
    {
        if ([line hasPrefix:prefix])
            return strtoull([[line substringFromIndex:prefix.length] UTF8String], NULL, 10);
    }
    return 0;
}

static bool TGCrashSystemTextMatchesProcess(NSString *text, uint64_t pid)
{
    NSString *suffix = [NSString stringWithFormat:@"[%llu]", pid];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *line in [text componentsSeparatedByString:@"\n"])
    {
        if (![line hasPrefix:@"Process:"])
            continue;
        NSString *value = [[line substringFromIndex:8] stringByTrimmingCharactersInSet:whitespace];
        NSRange bracket = [value rangeOfString:@"["];
        if (bracket.location == NSNotFound || ![[value substringFromIndex:bracket.location] isEqualToString:suffix])
            continue;
        NSString *name = [[value substringToIndex:bracket.location] stringByTrimmingCharactersInSet:whitespace];
        return [name isEqualToString:@"Telegram"] || [name isEqualToString:@"Telegram.real"] || [name isEqualToString:@"Onegram"];
    }
    return false;
}

static NSString *TGCrashSystemReport(NSString *text)
{
    uint64_t pid = TGCrashReportNumber(text, @"session_pid");
    if (pid == 0)
        pid = TGCrashReportNumber(text, @"pid");
    uint64_t started = TGCrashReportNumber(text, @"session_started");
    uint64_t sampled = TGCrashReportNumber(text, @"memory_sample_time");
    if (pid == 0 || started == 0 || sampled == 0)
        return @"CRASH system_report_status=missing_session_identity\n";
    NSArray *directories = @[@"/var/mobile/Library/Logs/CrashReporter", @"/var/mobile/Library/Logs/CrashReporter/Retired", [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter"]];
    bool readable = false;
    NSUInteger inspected = 0;
    for (NSString *directory in directories)
    {
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
        if (names == nil)
            continue;
        readable = true;
        for (NSString *name in [names sortedArrayUsingSelector:@selector(compare:)])
        {
            NSString *lower = name.lowercaseString;
            if (![lower hasSuffix:@".crash"] && ![lower hasSuffix:@".ips"] && ![lower hasSuffix:@".plist"])
                continue;
            if (![lower hasPrefix:@"telegram"] && ![lower hasPrefix:@"onegram"] && ![lower hasPrefix:@"jetsam"] && ![lower hasPrefix:@"lowmemory"])
                continue;
            NSString *path = [directory stringByAppendingPathComponent:name];
            NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileModificationDate];
            NSTimeInterval timestamp = date.timeIntervalSince1970;
            if (timestamp < started || timestamp > sampled + 600)
                continue;
            if (++inspected > 64)
                return @"CRASH system_report_status=search_limit_reached\n";
            NSString *contents = TGCrashReadText(path, 1024 * 1024, TGCrashReadComplete);
            if (contents.length == 0)
                continue;
            if (TGCrashSystemTextMatchesProcess(contents, pid))
                return [NSString stringWithFormat:@"CRASH system_report_status=matched_pid_and_time\nCRASH system_report-begin %@\n%@\nCRASH system_report-end\n", name, TGCrashReadReport(path) ?: @"unreadable"];
            NSData *data = [contents dataUsingEncoding:NSUTF8StringEncoding];
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]])
            {
                NSRange newline = [contents rangeOfString:@"\n"];
                if (newline.location != NSNotFound)
                {
                    data = [[contents substringFromIndex:NSMaxRange(newline)] dataUsingEncoding:NSUTF8StringEncoding];
                    json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                }
            }
            if (![json isKindOfClass:[NSDictionary class]])
                continue;
            id processes = [json objectForKey:@"processes"];
            if (![processes isKindOfClass:[NSArray class]])
                continue;
            for (id process in processes)
            {
                if (![process isKindOfClass:[NSDictionary class]])
                    continue;
                id processId = [process objectForKey:@"pid"];
                id processName = [process objectForKey:@"name"];
                if (![processId isKindOfClass:[NSNumber class]] || [processId unsignedLongLongValue] != pid || (![processName isEqual:@"Telegram"] && ![processName isEqual:@"Telegram.real"] && ![processName isEqual:@"Onegram"]))
                    continue;
                NSMutableDictionary *details = [[NSMutableDictionary alloc] initWithObjectsAndKeys:process, @"process", nil];
                for (NSString *key in @[@"pageSize", @"memoryStatus", @"reason", @"date", @"bug_type", @"os_version"])
                {
                    id value = [json objectForKey:key];
                    if (value != nil)
                        [details setObject:value forKey:key];
                }
                NSData *encoded = [NSJSONSerialization dataWithJSONObject:details options:NSJSONWritingPrettyPrinted error:nil];
                if (encoded.length == 0)
                    continue;
                NSString *excerpt = [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
                if (excerpt.length != 0 && encoded.length <= 64 * 1024)
                    return [NSString stringWithFormat:@"CRASH system_report_status=matched_process_snapshot\nCRASH system_report-begin %@\n%@\nCRASH system_report-end\n", name, excerpt];
            }
        }
    }
    return readable ? @"CRASH system_report_status=no_matching_readable_report\n" : @"CRASH system_report_status=not_accessible\n";
}

static void TGCrashSampleSystemMemory(void)
{
    static mach_port_t host = MACH_PORT_NULL;
    static vm_size_t pageSize = 0;
    if (host == MACH_PORT_NULL)
    {
        host = mach_host_self();
        if (host_page_size(host, &pageSize) != KERN_SUCCESS)
            pageSize = 0;
    }
    vm_statistics_data_t statistics;
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    TGCrashSession.systemSampleResult = pageSize == 0 ? KERN_FAILURE : host_statistics(host, HOST_VM_INFO, (host_info_t)&statistics, &count);
    if (TGCrashSession.systemSampleResult == KERN_SUCCESS)
    {
        TGCrashSession.systemFreeBytes = (uint64_t)statistics.free_count * pageSize;
        TGCrashSession.systemInactiveBytes = (uint64_t)statistics.inactive_count * pageSize;
        TGCrashSession.systemWiredBytes = (uint64_t)statistics.wire_count * pageSize;
    }
}

static bool TGCrashAddressInSharedRegion(const void *address)
{
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t regionSize = 0;
    natural_t depth = 0;
    struct vm_region_submap_info_64 info;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    if (vm_region_recurse_64(mach_task_self(), &regionAddress, &regionSize, &depth, (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS)
        return false;
    return regionAddress <= (vm_address_t)address && info.is_submap;
}

static void TGCrashLogExternalImages(void)
{
    NSMutableArray *images = [[NSMutableArray alloc] init];
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t index = 0; index < imageCount; index++)
    {
        const struct mach_header *header = _dyld_get_image_header(index);
        const char *name = _dyld_get_image_name(index);
        if (header == NULL || name == NULL)
            continue;
        if (header->filetype == MH_EXECUTE)
            continue;
        if (TGCrashAddressInSharedRegion(header))
            continue;
        NSString *path = [[NSString alloc] initWithUTF8String:name];
        if (path != nil)
            [images addObject:path];
    }
    TGDiagnosticLog(@"IOS6 SESSION external_images count=%lu total=%u %@", (unsigned long)images.count, imageCount, [images componentsJoinedByString:@";"]);
}

static void TGCrashAppendHistorySample(void)
{
    OGCrashSessionSample *sample = &TGCrashSession.history[TGCrashSession.historyNext];
    sample->sampledAt = TGCrashSession.sampledAt;
    sample->residentBytes = TGCrashSession.residentBytes;
    sample->heapBytes = TGCrashSession.heapBytes;
    sample->systemFreeBytes = TGCrashSession.systemFreeBytes;
    strlcpy(sample->screen, TGCrashSession.visibleController, sizeof(sample->screen));
    TGCrashSession.historyNext = (TGCrashSession.historyNext + 1) % OG_CRASH_SESSION_HISTORY_CAPACITY;
    if (TGCrashSession.historyCount < OG_CRASH_SESSION_HISTORY_CAPACITY)
        TGCrashSession.historyCount++;
}

static void TGCrashSampleMemory(void)
{
    task_basic_info_data_t info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    TGCrashSession.memorySampleResult = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count);
    TGCrashSession.sampledAt = time(NULL);
    TGCrashSession.sampleCount++;
    if (TGCrashSession.memorySampleResult == KERN_SUCCESS)
    {
        TGCrashSession.residentBytes = info.resident_size;
        TGCrashSession.virtualBytes = info.virtual_size;
        TGCrashSession.peakResidentBytes = MAX(TGCrashSession.peakResidentBytes, TGCrashSession.residentBytes);
    }
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    TGCrashSession.heapBytes = heap.size_in_use;
    TGCrashSession.peakHeapBytes = MAX(TGCrashSession.peakHeapBytes, TGCrashSession.heapBytes);
    TGCrashSampleSystemMemory();
    TGCrashAppendHistorySample();
    if (TGCrashSessionProbePending)
    {
        TGCrashSession.mainThreadDelayMilliseconds = TGCrashMonotonicMilliseconds() - TGCrashSessionProbeStarted;
        TGCrashSession.maximumMainThreadDelayMilliseconds = MAX(TGCrashSession.maximumMainThreadDelayMilliseconds, TGCrashSession.mainThreadDelayMilliseconds);
    }
}

static NSString *TGCrashVisibleController(void)
{
    UIViewController *controller = TGAppDelegateInstance.rootController;
    for (NSUInteger i = 0; i < 16 && controller != nil; i++)
    {
        UIViewController *next = controller.modalViewController;
        if (next == nil && [controller isKindOfClass:[UINavigationController class]])
            next = [(UINavigationController *)controller visibleViewController];
        if (next == nil && [controller isKindOfClass:[UITabBarController class]])
            next = [(UITabBarController *)controller selectedViewController];
        if (next == nil || next == controller)
            break;
        controller = next;
    }
    return controller == nil ? @"unavailable" : NSStringFromClass([controller class]);
}

static NSString *TGCrashSessionHistoryDescription(const OGCrashSessionRecord *record)
{
    NSMutableString *text = [[NSMutableString alloc] init];
    uint32_t count = MIN(record->historyCount, (uint32_t)OG_CRASH_SESSION_HISTORY_CAPACITY);
    uint32_t first = (record->historyNext + OG_CRASH_SESSION_HISTORY_CAPACITY - count) % OG_CRASH_SESSION_HISTORY_CAPACITY;
    for (uint32_t index = 0; index < count; index++)
    {
        const OGCrashSessionSample *sample = &record->history[(first + index) % OG_CRASH_SESSION_HISTORY_CAPACITY];
        long long offset = sample->sampledAt >= record->startedAt ? (long long)(sample->sampledAt - record->startedAt) : -1;
        [text appendFormat:@"CRASH memory_history=+%llds resident=%llu heap=%llu system_free=%llu screen=%s\n", offset, sample->residentBytes, sample->heapBytes, sample->systemFreeBytes, sample->screen];
    }
    return text;
}

static NSString *TGCrashSessionDescription(const OGCrashSessionRecord *record)
{
    return [[NSString stringWithFormat:@"CRASH session_started=%llu\nCRASH last_foreground_activity=%llu\nCRASH memory_warnings=%u\nCRASH last_memory_warning=%llu\nCRASH resident_bytes=%llu\nCRASH virtual_bytes=%llu\nCRASH peak_sampled_resident_bytes=%llu\nCRASH memory_sample_time=%llu\nCRASH memory_sample_count=%llu\nCRASH memory_sample_result=%d\nCRASH memory_sample_valid=%d\nCRASH main_thread_delay_ms=%llu\nCRASH maximum_main_thread_delay_ms=%llu\nCRASH session_pid=%llu\nCRASH executable_uuid=%s\nCRASH system_build=%s\nCRASH last_screen=%s\nCRASH lifecycle=%s\n",
        record->startedAt, record->lastActiveAt, record->memoryWarnings, record->lastWarningAt, record->residentBytes, record->virtualBytes, record->peakResidentBytes, record->sampledAt, record->sampleCount, record->memorySampleResult, record->sampleCount != 0 && record->memorySampleResult == KERN_SUCCESS, record->mainThreadDelayMilliseconds, record->maximumMainThreadDelayMilliseconds, record->processId, record->executableUUID, record->systemBuild, record->visibleController, record->lifecycle] stringByAppendingFormat:@"CRASH heap_bytes=%llu\nCRASH peak_heap_bytes=%llu\nCRASH physical_memory_bytes=%llu\nCRASH system_free_bytes=%llu\nCRASH system_inactive_bytes=%llu\nCRASH system_wired_bytes=%llu\nCRASH system_sample_result=%d\n%@", record->heapBytes, record->peakHeapBytes, record->physicalMemoryBytes, record->systemFreeBytes, record->systemInactiveBytes, record->systemWiredBytes, record->systemSampleResult, TGCrashSessionHistoryDescription(record)];
}

@interface TGCrashReport : NSObject

@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSDate *newestDate;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSDictionary *files;

@end

@implementation TGCrashReport

- (instancetype)initWithText:(NSString *)text newestDate:(NSDate *)newestDate count:(NSUInteger)count files:(NSDictionary *)files
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _newestDate = newestDate;
        _count = count;
        _files = [files copy];
    }
    return self;
}

@end

static NSString *TGCrashReportArchitecture()
{
#if defined(__arm64__)
    return @"arm64";
#elif defined(__ARM_ARCH_7A__) || defined(__ARM_ARCH_7S__)
    return @"armv7";
#else
    return @"armv6";
#endif
}

static NSString *TGCrashReportMachine()
{
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0)
        return @"?";
    NSMutableData *data = [[NSMutableData alloc] initWithLength:size];
    if (sysctlbyname("hw.machine", data.mutableBytes, &size, NULL, 0) != 0)
        return @"?";
    return [[NSString alloc] initWithUTF8String:data.bytes] ?: @"?";
}

static NSString *TGCrashReportHeader(NSUInteger count)
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    UIDevice *device = [UIDevice currentDevice];
    return [[NSString alloc] initWithFormat:@"Exported by Onegram %@ (%@) %@\n%@ %@, %@\nreports=%lu\n", info[@"CFBundleShortVersionString"] ?: @"?", info[@"CFBundleVersion"] ?: @"?", TGCrashReportArchitecture(), device.systemName, device.systemVersion, TGCrashReportMachine(), (unsigned long)count];
}

static NSString *TGCrashReportFileIdentity(NSDictionary *attributes)
{
    NSDate *date = [attributes objectForKey:NSFileModificationDate];
    NSNumber *size = [attributes objectForKey:NSFileSize];
    if (date == nil || size == nil)
        return nil;
    return [NSString stringWithFormat:@"%.6f-%@", date.timeIntervalSince1970, size];
}

@interface TGCrashReportCardView : TGOnegramCardView
{
    TGCrashReport *_report;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_textLabel;
    TGModernButton *_previewButton;
    UITextView *_previewView;
    UILabel *_errorLabel;
    TGModernButton *_sendButton;
    UIActivityIndicatorView *_activityView;
    TGModernButton *_laterButton;
    bool _previewExpanded;
    bool _sending;
    bool _sent;
    id<SDisposable> _sendDisposable;
}

- (instancetype)initWithReport:(TGCrashReport *)report;

@end

@implementation TGCrashReportCenter

+ (NSString *)pendingReportPath
{
    NSString *directory = [TGAppDelegate documentsPath] ?: NSTemporaryDirectory();
    return [directory stringByAppendingPathComponent:@"ios6_last_crash.txt"];
}

+ (bool)recoverPreviousSession
{
    OGCrashSessionRecord previous;
    if (![self reportsEnabled] || !OGCrashSessionRead(TGCrashSessionPath, &previous))
    {
        unlink(TGCrashSessionPath);
        return true;
    }
    NSString *path = [self pendingReportPath];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if ([[attributes objectForKey:NSFileSize] unsignedLongLongValue] != 0 && previous.processId != 0)
    {
        NSString *header = TGCrashReadText(path, 16 * 1024, TGCrashReadHead);
        if (header == nil)
            return false;
        uint64_t pid = TGCrashReportNumber(header, @"pid");
        if (pid != 0 && pid != previous.processId)
        {
            unlink(TGCrashSessionPath);
            return true;
        }
    }
    NSMutableString *text = [[NSMutableString alloc] init];
    if ([[attributes objectForKey:NSFileSize] unsignedLongLongValue] == 0)
    {
        [text appendFormat:@"Onegram %s (%s) %s\niOS %s, %s\nCRASH type=unexpected_termination\nCRASH cause=unavailable\nCRASH stack_status=not_captured\n", previous.appVersion, previous.appBuild, previous.architecture, previous.systemVersion, previous.machine];
        NSString *breadcrumbs = TGCrashReadText(TGIOS6PreviousDiagnosticBreadcrumbPath(), 64 * 1024, TGCrashReadTail);
        [text appendFormat:@"CRASH previous_context-begin\n%@\nCRASH previous_context-end\n", breadcrumbs ?: @"unavailable"];
    }
    [text appendString:TGCrashSessionDescription(&previous)];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    int fd = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0600);
    bool recorded = fd >= 0;
    NSUInteger offset = 0;
    while (recorded && offset < data.length)
    {
        ssize_t count = write(fd, (const uint8_t *)data.bytes + offset, data.length - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            recorded = false;
        else
            offset += (NSUInteger)count;
    }
    if (recorded)
        recorded = fsync(fd) == 0;
    if (fd >= 0)
        close(fd);
    if (recorded)
        unlink(TGCrashSessionPath);
    return recorded;
}

+ (void)startMonitoring
{
    TGDispatchOnMainThread(^
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            NSString *path = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"crash-session"];
            const char *filePath = path.fileSystemRepresentation;
            if (filePath == NULL || strlen(filePath) >= sizeof(TGCrashSessionPath))
                return;
            memcpy(TGCrashSessionPath, filePath, strlen(filePath) + 1);
            TGCrashSessionRecovered = [self recoverPreviousSession];
            TGCrashSessionQueue = dispatch_queue_create("org.onegram.crash-session", DISPATCH_QUEUE_SERIAL);
            memset(&TGCrashSession, 0, sizeof(TGCrashSession));
            TGCrashSession.signature = OG_CRASH_SESSION_SIGNATURE;
            TGCrashSession.processId = getpid();
            TGCrashExecutableUUID(TGCrashSession.executableUUID, sizeof(TGCrashSession.executableUUID));
            size_t systemBuildSize = sizeof(TGCrashSession.systemBuild);
            if (sysctlbyname("kern.osversion", TGCrashSession.systemBuild, &systemBuildSize, NULL, 0) != 0)
                TGCrashSession.systemBuild[0] = 0;
            TGCrashSession.systemBuild[sizeof(TGCrashSession.systemBuild) - 1] = 0;
            TGCrashSession.startedAt = time(NULL);
            TGCrashSession.lastActiveAt = TGCrashSession.startedAt;
            NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
            snprintf(TGCrashSession.appVersion, sizeof(TGCrashSession.appVersion), "%s", [info[@"CFBundleShortVersionString"] UTF8String] ?: "?");
            snprintf(TGCrashSession.appBuild, sizeof(TGCrashSession.appBuild), "%s", [info[@"CFBundleVersion"] UTF8String] ?: "?");
            snprintf(TGCrashSession.architecture, sizeof(TGCrashSession.architecture), "%s", [TGCrashReportArchitecture() UTF8String]);
            snprintf(TGCrashSession.systemVersion, sizeof(TGCrashSession.systemVersion), "%s", [[UIDevice currentDevice].systemVersion UTF8String] ?: "?");
            snprintf(TGCrashSession.machine, sizeof(TGCrashSession.machine), "%s", [TGCrashReportMachine() UTF8String]);
            TGCrashSession.physicalMemoryBytes = [NSProcessInfo processInfo].physicalMemory;
            TGCrashLogExternalImages();
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center addObserver:self selector:@selector(applicationBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
            [center addObserver:self selector:@selector(applicationLeftForeground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
            [center addObserver:self selector:@selector(applicationLeftForeground:) name:UIApplicationWillTerminateNotification object:nil];
            [center addObserver:self selector:@selector(memoryWarningReceived:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
            [center addObserver:self selector:@selector(applicationResignedActive:) name:UIApplicationWillResignActiveNotification object:nil];
            TGCrashSessionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, TGCrashSessionQueue);
            dispatch_source_set_timer(TGCrashSessionTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 2 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
            dispatch_source_set_event_handler(TGCrashSessionTimer, ^
            {
                @autoreleasepool
                {
                    if (!TGCrashSessionActive)
                        return;
                    TGCrashSampleMemory();
                    OGCrashSessionWrite(TGCrashSessionPath, &TGCrashSession);
                    if (TGCrashSession.sampledAt - TGCrashSessionLastLog >= 30 || TGCrashSession.mainThreadDelayMilliseconds >= 5000)
                    {
                        TGCrashSessionLastLog = TGCrashSession.sampledAt;
                        TGDiagnosticLog(@"IOS6 SESSION sample resident=%llu peak=%llu heap=%llu system_free=%llu memory_result=%d main_delay_ms=%llu screen=%s state=%s", TGCrashSession.residentBytes, TGCrashSession.peakResidentBytes, TGCrashSession.heapBytes, TGCrashSession.systemFreeBytes, TGCrashSession.memorySampleResult, TGCrashSession.mainThreadDelayMilliseconds, TGCrashSession.visibleController, TGCrashSession.lifecycle);
                    }
                    if (!TGCrashSessionProbePending)
                    {
                        TGCrashSessionProbePending = true;
                        TGCrashSessionProbeStarted = TGCrashMonotonicMilliseconds();
                        uint64_t generation = ++TGCrashSessionProbeGeneration;
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            uint64_t acknowledged = TGCrashMonotonicMilliseconds();
                            NSString *screen = TGCrashVisibleController();
                            dispatch_async(TGCrashSessionQueue, ^
                            {
                                if (!TGCrashSessionActive || generation != TGCrashSessionProbeGeneration)
                                    return;
                                uint64_t delay = acknowledged - TGCrashSessionProbeStarted;
                                TGCrashSession.maximumMainThreadDelayMilliseconds = MAX(TGCrashSession.maximumMainThreadDelayMilliseconds, delay);
                                TGCrashSession.mainThreadDelayMilliseconds = 0;
                                TGCrashSessionProbePending = false;
                                bool screenChanged = strcmp(TGCrashSession.visibleController, screen.UTF8String) != 0;
                                snprintf(TGCrashSession.visibleController, sizeof(TGCrashSession.visibleController), "%s", screen.UTF8String);
                                if (screenChanged)
                                {
                                    TGCrashSampleMemory();
                                    OGCrashSessionWrite(TGCrashSessionPath, &TGCrashSession);
                                    TGDiagnosticLog(@"IOS6 SESSION screen=%@ resident=%llu heap=%llu system_free=%llu", screen, TGCrashSession.residentBytes, TGCrashSession.heapBytes, TGCrashSession.systemFreeBytes);
                                }
                            });
                        });
                    }
                }
            });
            dispatch_resume(TGCrashSessionTimer);
            [self applicationBecameActive:nil];
        });
    });
}

+ (void)applicationBecameActive:(NSNotification *)__unused notification
{
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        return;
    if (TGCrashSessionRecovered && TGCrashSessionPath[0] != 0 && [self reportsEnabled])
    {
        NSString *screen = TGCrashVisibleController();
        dispatch_async(TGCrashSessionQueue, ^
        {
            TGCrashSessionActive = true;
            TGCrashSession.lastActiveAt = time(NULL);
            strlcpy(TGCrashSession.lifecycle, "active", sizeof(TGCrashSession.lifecycle));
            snprintf(TGCrashSession.visibleController, sizeof(TGCrashSession.visibleController), "%s", screen.UTF8String);
            TGCrashSampleMemory();
            OGCrashSessionWrite(TGCrashSessionPath, &TGCrashSession);
            TGDiagnosticLog(@"IOS6 SESSION active uuid=%s pid=%llu screen=%@ resident=%llu", TGCrashSession.executableUUID, TGCrashSession.processId, screen, TGCrashSession.residentBytes);
        });
    }
    [self scheduleCheckAfter:1.0];
}

+ (void)applicationResignedActive:(NSNotification *)__unused notification
{
    if (TGCrashSessionQueue == NULL)
        return;
    dispatch_async(TGCrashSessionQueue, ^
    {
        if (!TGCrashSessionActive)
            return;
        strlcpy(TGCrashSession.lifecycle, "inactive", sizeof(TGCrashSession.lifecycle));
        TGCrashSampleMemory();
        OGCrashSessionWrite(TGCrashSessionPath, &TGCrashSession);
        TGDiagnosticLog(@"IOS6 SESSION inactive");
    });
}

+ (void)applicationLeftForeground:(NSNotification *)__unused notification
{
    if (TGCrashSessionQueue == NULL)
        return;
    dispatch_sync(TGCrashSessionQueue, ^
    {
        TGCrashSessionActive = false;
        TGCrashSessionProbePending = false;
        TGCrashSessionProbeGeneration++;
        TGCrashSession.mainThreadDelayMilliseconds = 0;
        if (TGCrashSessionRecovered && TGCrashSessionPath[0] != 0)
            unlink(TGCrashSessionPath);
        TGDiagnosticLog(@"IOS6 SESSION background_or_terminated");
    });
}

+ (void)memoryWarningReceived:(NSNotification *)__unused notification
{
    if (TGCrashSessionQueue == NULL)
        return;
    dispatch_async(TGCrashSessionQueue, ^
    {
        if (!TGCrashSessionActive)
            return;
        if (TGCrashSession.memoryWarnings != UINT32_MAX)
            TGCrashSession.memoryWarnings++;
        TGCrashSession.lastWarningAt = time(NULL);
        TGCrashSampleMemory();
        OGCrashSessionWrite(TGCrashSessionPath, &TGCrashSession);
        TGDiagnosticLog(@"IOS6 SESSION memory_warning count=%u resident=%llu peak=%llu screen=%s", TGCrashSession.memoryWarnings, TGCrashSession.residentBytes, TGCrashSession.peakResidentBytes, TGCrashSession.visibleController);
    });
}

+ (bool)reportsEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:TGCrashReportsEnabledKey];
    return value == nil ? true : [value boolValue];
}

+ (void)setReportsEnabled:(bool)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:TGCrashReportsEnabledKey];
    if (!enabled)
    {
        [self applicationLeftForeground:nil];
        [self markHandledUpToDate:[NSDate date]];
    }
    else
        [self applicationBecameActive:nil];
}

+ (NSMutableSet *)readiness
{
    static NSMutableSet *readiness = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        readiness = [[NSMutableSet alloc] init];
    });
    return readiness;
}

+ (void)markReady:(NSString *)stage
{
    TGDispatchOnMainThread(^
    {
        NSMutableSet *readiness = [self readiness];
        if ([readiness containsObject:@"checked"])
            return;
        [readiness addObject:stage];
        if ([readiness containsObject:@"archive"] && [readiness containsObject:@"interface"])
            [self scheduleCheckAfter:2.0];
    });
}

+ (void)archiveDidFinish
{
    [self markReady:@"archive"];
}

+ (void)mainInterfaceDidAppear
{
    [self markReady:@"interface"];
}

+ (bool)canPresentReport
{
    return [self reportsEnabled] && TGTelegraphInstance.clientUserId != 0 &&
        [UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
        ![TGAppDelegateInstance isCurrentlyLocked] && ![TGAppDelegateInstance isDisplayingPasscodeWindow] &&
        TGAppDelegateInstance.rootController.view.window != nil;
}

+ (void)scheduleCheckAfter:(NSTimeInterval)delay
{
    NSMutableSet *readiness = [self readiness];
    if (![readiness containsObject:@"archive"] || ![readiness containsObject:@"interface"] ||
        [readiness containsObject:@"checked"] || [readiness containsObject:@"checking"] ||
        [readiness containsObject:@"scheduled"] || [readiness containsObject:@"presented"] || ![self reportsEnabled])
        return;
    [readiness addObject:@"scheduled"];
    TGDispatchAfter(delay, dispatch_get_main_queue(), ^
    {
        [readiness removeObject:@"scheduled"];
        if (![self canPresentReport])
        {
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                [self scheduleCheckAfter:3.0];
            return;
        }
        [readiness addObject:@"checking"];
        [self collectPendingReport:^(TGCrashReport *report)
        {
            [readiness removeObject:@"checking"];
            if (report == nil)
            {
                [readiness addObject:@"checked"];
                return;
            }
            if (![self canPresentReport])
            {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                    [self scheduleCheckAfter:3.0];
                return;
            }
            TGOnegramCardOverlay *overlay = [TGOnegramCardOverlay presentCardView:[[TGCrashReportCardView alloc] initWithReport:report] placement:TGOnegramCardPlacementCenter];
            overlay.dismissesOnDimTap = false;
            [readiness addObject:@"presented"];
            overlay.onDismiss = ^
            {
                [readiness removeObject:@"presented"];
                [readiness addObject:@"checked"];
            };
        }];
    });
}

+ (void)collectPendingReport:(void (^)(TGCrashReport *))completion
{
    NSDate *handledDate = [[NSUserDefaults standardUserDefaults] objectForKey:TGCrashReportsHandledDateKey];
    if (![handledDate isKindOfClass:[NSDate class]])
        handledDate = [NSDate dateWithTimeIntervalSinceNow:-TGCrashReportInitialLookback];
    NSDictionary *handledFiles = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TGCrashReportsHandledFilesKey] ?: @{};
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        NSMutableArray *candidates = [[NSMutableArray alloc] init];
        NSMutableArray *paths = [[NSMutableArray alloc] initWithObjects:[self pendingReportPath], nil];
        for (NSString *path in TGGetArchivedLogFilePaths())
        {
            if ([[path lastPathComponent] hasPrefix:@"Crash-"])
                [paths addObject:path];
        }
        for (NSString *path in paths)
        {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            NSDate *date = [attributes objectForKey:NSFileModificationDate];
            NSString *identity = TGCrashReportFileIdentity(attributes);
            if (identity != nil && [date compare:handledDate] == NSOrderedDescending && ![identity isEqual:[handledFiles objectForKey:path.lastPathComponent]])
                [candidates addObject:@{@"path": path, @"date": date, @"identity": identity}];
        }
        [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right)
        {
            NSComparisonResult result = [[left objectForKey:@"date"] compare:[right objectForKey:@"date"]];
            return result == NSOrderedSame ? [[left objectForKey:@"path"] compare:[right objectForKey:@"path"]] : result;
        }];
        NSDate *newestDate = nil;
        NSUInteger count = 0;
        NSMutableString *body = [[NSMutableString alloc] init];
        NSMutableDictionary *files = [[NSMutableDictionary alloc] init];
        for (NSDictionary *candidate in candidates)
        {
            NSDate *date = [candidate objectForKey:@"date"];
            if (count >= TGCrashReportMaximumReports)
                break;
            NSString *path = [candidate objectForKey:@"path"];
            NSString *contents = TGCrashReadReport(path);
            if (contents.length == 0)
                continue;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            if (![[candidate objectForKey:@"identity"] isEqual:TGCrashReportFileIdentity(attributes)])
                continue;
            [body appendFormat:@"\n===== %@ =====\n%@\n%@", [[path lastPathComponent] stringByDeletingPathExtension], contents, TGCrashSystemReport(contents)];
            newestDate = date;
            [files setObject:[candidate objectForKey:@"identity"] forKey:path.lastPathComponent];
            count++;
        }
        TGCrashReport *report = count == 0 ? nil : [[TGCrashReport alloc] initWithText:[TGCrashReportHeader(count) stringByAppendingString:body] newestDate:newestDate count:count files:files];

        TGDispatchOnMainThread(^
        {
            completion(report);
        });
    });
}

+ (void)markReportHandled:(TGCrashReport *)report
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *handled = [[NSMutableDictionary alloc] initWithDictionary:[defaults dictionaryForKey:TGCrashReportsHandledFilesKey] ?: @{}];
    NSMutableSet *available = [[NSMutableSet alloc] initWithObjects:[[self pendingReportPath] lastPathComponent], nil];
    for (NSString *path in TGGetArchivedLogFilePaths())
        [available addObject:path.lastPathComponent];
    for (NSString *name in [handled allKeys])
    {
        if (![available containsObject:name])
            [handled removeObjectForKey:name];
    }
    [handled addEntriesFromDictionary:report.files];
    [defaults setObject:handled forKey:TGCrashReportsHandledFilesKey];
    [defaults synchronize];
}

+ (void)markHandledUpToDate:(NSDate *)date
{
    if (date == nil)
        return;
    NSDate *current = [[NSUserDefaults standardUserDefaults] objectForKey:TGCrashReportsHandledDateKey];
    if ([current isKindOfClass:[NSDate class]] && [current compare:date] != NSOrderedAscending)
        return;
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:TGCrashReportsHandledDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (SSignal *)developerUser
{
    TLRPCcontacts_resolveUsername$contacts_resolveUsername *resolveUsername = [[TLRPCcontacts_resolveUsername$contacts_resolveUsername alloc] init];
    resolveUsername.username = TGCrashReportDeveloperUsername;
    return [[[TGTelegramNetworking instance] requestSignal:resolveUsername] mapToSignal:^SSignal *(TLcontacts_ResolvedPeer *resolvedPeer)
    {
        for (TLUser *userDesc in resolvedPeer.users)
        {
            TGUser *user = [[TGUser alloc] initWithTelegraphUserDesc:userDesc];
            if (user.uid == TGCrashReportDeveloperUserId)
            {
                [TGUserDataRequestBuilder executeUserObjectsUpdate:@[user]];
                return [SSignal single:user];
            }
        }
        return [SSignal fail:nil];
    }];
}

+ (SSignal *)sendReport:(TGCrashReport *)report
{
    NSData *data = [report.text dataUsingEncoding:NSUTF8StringEncoding];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    NSString *fileName = [[NSString alloc] initWithFormat:@"onegram-%@-%@-crash-%@.txt", version, TGCrashReportArchitecture(), [formatter stringFromDate:report.newestDate ?: [NSDate date]]];

    return [[self developerUser] mapToSignal:^SSignal *(TGUser *user)
    {
        TGDocumentMediaAttachment *documentAttachment = [[TGDocumentMediaAttachment alloc] init];
        documentAttachment.attributes = @[[[TGDocumentAttributeFilename alloc] initWithFilename:fileName]];
        documentAttachment.mimeType = @"text/plain";
        documentAttachment.size = (int32_t)data.length;

        SSignal *uploadSignal = [[TGUploadFileSignals uploadedFileWithData:data mediaTypeTag:TGNetworkMediaTypeTagDocument] map:^id(TLInputFile *file)
        {
            return @{@"file": file};
        }];

        return [TGSendMessageSignals sendMediaWithPeerId:user.uid replyToMid:0 attachment:documentAttachment uploadSignal:uploadSignal mediaProducer:^TLInputMedia *(NSDictionary *uploadInfo)
        {
            TLInputMediaUploadedDocument *uploadedDocument = [[TLInputMediaUploadedDocument alloc] init];
            uploadedDocument.file = uploadInfo[@"file"];
            uploadedDocument.mime_type = @"text/plain";
            TLDocumentAttribute$documentAttributeFilename *filenameAttribute = [[TLDocumentAttribute$documentAttributeFilename alloc] init];
            filenameAttribute.file_name = fileName;
            uploadedDocument.attributes = @[filenameAttribute];
            return uploadedDocument;
        }];
    }];
}

@end

@implementation TGCrashReportCardView

- (instancetype)initWithReport:(TGCrashReport *)report
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _report = report;
        TGPresentationPallete *pallete = [TGPresentation current].pallete;
        self.backgroundColor = pallete.menuBackgroundColor;

        _iconView = [[UIImageView alloc] initWithImage:[self badgedAppIcon]];
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(20.0f);
        _titleLabel.textColor = pallete.menuTextColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 0;
        _titleLabel.text = TGLocalized(@"CrashReport.Title");
        [self addSubview:_titleLabel];

        _textLabel = [[UILabel alloc] init];
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.font = TGSystemFontOfSize(15.0f);
        _textLabel.textColor = pallete.menuSecondaryTextColor;
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.numberOfLines = 0;
        NSString *countText = report.count > 1 ? [[NSString alloc] initWithFormat:TGLocalized(@"CrashReport.TextMultiple"), (int)report.count] : TGLocalized(@"CrashReport.Text");
        _textLabel.text = [countText stringByAppendingFormat:@"\n\n%@", TGLocalized(@"CrashReport.Privacy")];
        [self addSubview:_textLabel];

        _previewButton = [[TGModernButton alloc] init];
        _previewButton.titleLabel.font = TGSystemFontOfSize(15.0f);
        [_previewButton setTitleColor:pallete.menuAccentColor];
        [_previewButton setTitle:TGLocalized(@"CrashReport.ShowReport") forState:UIControlStateNormal];
        [_previewButton addTarget:self action:@selector(previewPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_previewButton];

        _errorLabel = [[UILabel alloc] init];
        _errorLabel.backgroundColor = [UIColor clearColor];
        _errorLabel.font = TGSystemFontOfSize(14.0f);
        _errorLabel.textColor = pallete.menuDestructiveColor;
        _errorLabel.textAlignment = NSTextAlignmentCenter;
        _errorLabel.numberOfLines = 0;
        _errorLabel.hidden = true;
        [self addSubview:_errorLabel];

        _sendButton = [[TGModernButton alloc] init];
        _sendButton.backgroundColor = pallete.menuAccentColor;
        _sendButton.layer.cornerRadius = 12.0f;
        _sendButton.clipsToBounds = true;
        _sendButton.titleLabel.font = TGMediumSystemFontOfSize(17.0f);
        [_sendButton setTitleColor:pallete.accentContrastColor];
        [_sendButton setTitle:TGLocalized(@"CrashReport.Send") forState:UIControlStateNormal];
        _sendButton.highlightBackgroundColor = [pallete.menuAccentColor colorWithAlphaComponent:0.8f];
        [_sendButton addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_sendButton];

        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityView.hidesWhenStopped = true;
        [_sendButton addSubview:_activityView];

        _laterButton = [[TGModernButton alloc] init];
        _laterButton.layer.cornerRadius = 12.0f;
        _laterButton.clipsToBounds = true;
        _laterButton.titleLabel.font = TGSystemFontOfSize(17.0f);
        [_laterButton setTitleColor:pallete.menuAccentColor];
        _laterButton.highlightBackgroundColor = pallete.menuSelectionColor;
        [_laterButton setTitle:TGLocalized(@"CrashReport.Later") forState:UIControlStateNormal];
        [_laterButton addTarget:self action:@selector(laterPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_laterButton];
    }
    return self;
}

- (void)dealloc
{
    [_sendDisposable dispose];
}

- (UIImage *)badgedAppIcon
{
    UIImage *icon = [UIImage imageNamed:@"Icon-60@2x.png"] ?: [UIImage imageNamed:@"Icon@2x.png"] ?: [UIImage imageNamed:@"Icon.png"];
    CGFloat side = 64.0f;
    CGFloat badge = 24.0f;
    CGSize size = CGSizeMake(side + 6.0f, side + 6.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect iconRect = CGRectMake(0.0f, 6.0f, side, side);
    CGContextSaveGState(context);
    [[UIBezierPath bezierPathWithRoundedRect:iconRect cornerRadius:side * 0.225f] addClip];
    if (icon != nil)
        [icon drawInRect:iconRect];
    else
    {
        CGContextSetFillColorWithColor(context, [TGPresentation current].pallete.menuAccentColor.CGColor);
        CGContextFillRect(context, iconRect);
    }
    CGContextRestoreGState(context);

    CGRect badgeRect = CGRectMake(size.width - badge - 1.0f, 1.0f, badge, badge);
    CGContextSetFillColorWithColor(context, [TGPresentation current].pallete.menuBackgroundColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectInset(badgeRect, -2.0f, -2.0f));
    CGContextSetFillColorWithColor(context, UIColorRGB(0xff3b30).CGColor);
    CGContextFillEllipseInRect(context, badgeRect);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGFloat midX = CGRectGetMidX(badgeRect);
    CGContextFillRect(context, CGRectMake(midX - 1.25f, badgeRect.origin.y + 5.0f, 2.5f, 9.0f));
    CGContextFillEllipseInRect(context, CGRectMake(midX - 1.5f, badgeRect.origin.y + 16.0f, 3.0f, 3.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UITextView *)previewView
{
    if (_previewView == nil)
    {
        TGPresentationPallete *pallete = [TGPresentation current].pallete;
        _previewView = [[UITextView alloc] init];
        _previewView.editable = false;
        _previewView.backgroundColor = pallete.menuSelectionColor;
        _previewView.textColor = pallete.menuTextColor;
        _previewView.font = [UIFont fontWithName:@"Courier" size:11.0f] ?: TGSystemFontOfSize(11.0f);
        _previewView.layer.cornerRadius = 10.0f;
        _previewView.clipsToBounds = true;
        _previewView.text = _report.text;
        _previewView.alpha = 0.0f;
        [self addSubview:_previewView];
    }
    return _previewView;
}

- (CGFloat)textHeight:(UILabel *)label width:(CGFloat)width
{
    if (label.hidden || label.text.length == 0)
        return 0.0f;
    return CGCeil(OGPlatformTextSize(label.text, label.font, CGSizeMake(width, CGFLOAT_MAX), UILineBreakModeWordWrap).height);
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(bool)apply
{
    CGFloat inset = 20.0f;
    CGFloat contentWidth = width - inset * 2.0f;
    CGFloat y = 22.0f;

    CGSize iconSize = _iconView.image.size;
    if (apply)
        _iconView.frame = CGRectMake(CGFloor((width - iconSize.width) / 2.0f) + 3.0f, y, iconSize.width, iconSize.height);
    y += iconSize.height + 14.0f;

    CGFloat titleHeight = [self textHeight:_titleLabel width:contentWidth];
    if (apply)
        _titleLabel.frame = CGRectMake(inset, y, contentWidth, titleHeight);
    y += titleHeight + 8.0f;

    CGFloat textHeight = [self textHeight:_textLabel width:contentWidth];
    if (apply)
        _textLabel.frame = CGRectMake(inset, y, contentWidth, textHeight);
    y += textHeight;

    CGFloat errorHeight = [self textHeight:_errorLabel width:contentWidth];
    if (errorHeight > 0.0f)
    {
        y += 10.0f;
        if (apply)
            _errorLabel.frame = CGRectMake(inset, y, contentWidth, errorHeight);
        y += errorHeight;
    }

    y += 16.0f;
    if (apply)
    {
        _sendButton.frame = CGRectMake(inset, y, contentWidth, 48.0f);
        _activityView.center = CGPointMake(28.0f, 24.0f);
    }
    y += 48.0f + 6.0f;

    if (apply)
        _previewButton.frame = CGRectMake(inset, y, contentWidth, 32.0f);
    y += 32.0f;

    if (_previewExpanded)
    {
        y += 6.0f;
        if (apply)
        {
            self.previewView.frame = CGRectMake(inset, y, contentWidth, 170.0f);
            self.previewView.alpha = 1.0f;
        }
        y += 170.0f;
    }
    else if (apply && _previewView != nil)
    {
        _previewView.alpha = 0.0f;
        _previewView.frame = CGRectMake(inset, y, contentWidth, 0.0f);
    }
    y += 6.0f;

    if (apply)
        _laterButton.frame = CGRectMake(inset, y, contentWidth, 44.0f);
    y += 44.0f + 12.0f;
    return y;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
    return [self layoutForWidth:width apply:false];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self layoutForWidth:self.bounds.size.width apply:true];
}

- (void)previewPressed
{
    _previewExpanded = !_previewExpanded;
    [_previewButton setTitle:TGLocalized(_previewExpanded ? @"CrashReport.HideReport" : @"CrashReport.ShowReport") forState:UIControlStateNormal];
    [self setNeedsLayout];
    [self.overlay setNeedsCardLayoutAnimated:true];
}

- (void)setSending:(bool)sending
{
    _sending = sending;
    _sendButton.enabled = !sending;
    _laterButton.enabled = !sending;
    [_sendButton setTitle:TGLocalized(sending ? @"CrashReport.Sending" : @"CrashReport.Retry") forState:UIControlStateNormal];
    if (sending)
        [_activityView startAnimating];
    else
        [_activityView stopAnimating];
}

- (void)sendPressed
{
    if (_sending || _sent)
        return;
    _errorLabel.hidden = true;
    [self setSending:true];
    [self setNeedsLayout];
    [self.overlay setNeedsCardLayoutAnimated:true];

    __weak TGCrashReportCardView *weakSelf = self;
    TGCrashReport *report = _report;
    [_sendDisposable dispose];
    _sendDisposable = [[[TGCrashReportCenter sendReport:report] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        __strong TGCrashReportCardView *strongSelf = weakSelf;
        [strongSelf sendFailed];
    } completed:^
    {
        [TGCrashReportCenter markReportHandled:report];
        __strong TGCrashReportCardView *strongSelf = weakSelf;
        [strongSelf sendSucceeded];
    }];
}

- (void)sendFailed
{
    [self setSending:false];
    _errorLabel.text = TGLocalized(@"CrashReport.Failed");
    _errorLabel.hidden = false;
    [self setNeedsLayout];
    [self.overlay setNeedsCardLayoutAnimated:true];
}

- (void)sendSucceeded
{
    _sent = true;
    _sending = false;
    [_activityView stopAnimating];
    [_sendButton setTitle:TGLocalized(@"CrashReport.Sent") forState:UIControlStateNormal];
    TGOnegramCardOverlay *overlay = self.overlay;
    TGDispatchAfter(0.9, dispatch_get_main_queue(), ^
    {
        [overlay dismissAnimated:true completion:nil];
    });
}

- (void)laterPressed
{
    if (_sending)
        return;
    [TGCrashReportCenter markReportHandled:_report];
    [self.overlay dismissAnimated:true completion:nil];
}

- (void)cardDidDisappear
{
    [_sendDisposable dispose];
    _sendDisposable = nil;
}

@end
