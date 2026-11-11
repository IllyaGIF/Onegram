#import <Foundation/Foundation.h>
#import <stdarg.h>
#import <sys/time.h>
#import <time.h>
#import <unistd.h>
#import "../OnegramPlatform/OGPlatformVersion.h"

#define OG_COMPAT_PROBE_ENABLED 0


#if OG_COMPAT_PROBE_ENABLED
static inline NSString *OGCompatProbeLogPath()
{
    NSArray *roots = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *root = roots.count == 0 ? NSTemporaryDirectory() : [roots objectAtIndex:0];
    return [root stringByAppendingPathComponent:@"ios6-notification-probe.log"];
}

static inline NSString *OGCompatProbeFlatten(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return [text stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
}

static inline NSString *OGCompatProbeTimestamp()
{
    struct timeval now;
    gettimeofday(&now, NULL);
    struct tm broken;
    localtime_r(&now.tv_sec, &broken);
    char clock[32] = {0};
    strftime(clock, sizeof(clock), "%Y-%m-%d %H:%M:%S", &broken);
    return [NSString stringWithFormat:@"%s.%03d", clock, (int)(now.tv_usec / 1000)];
}

static inline void OGCompatProbeAppend(NSData *data)
{
    @synchronized([NSFileHandle class])
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = OGCompatProbeLogPath();
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
        if ([[attributes objectForKey:NSFileSize] unsignedLongLongValue] > 256 * 1024)
        {
            NSString *rotatedPath = [path stringByAppendingString:@".previous"];
            [fileManager removeItemAtPath:rotatedPath error:nil];
            [fileManager moveItemAtPath:path toPath:rotatedPath error:nil];
        }

        if (![fileManager fileExistsAtPath:path])
            [fileManager createFileAtPath:path contents:nil attributes:nil];

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle synchronizeFile];
        [handle closeFile];
    }
}

static inline void OGCompatProbeWrite(NSString *stage, NSString *format, ...) __attribute__((format(__NSString__, 2, 3)));

static inline void OGCompatProbeWrite(NSString *stage, NSString *format, ...)
{
    if (stage.length == 0)
        return;

    @autoreleasepool
    {
        @try
        {
            NSString *details = @"";
            if (format != nil)
            {
                va_list arguments;
                va_start(arguments, format);
                NSString *rendered = [[NSString alloc] initWithFormat:format arguments:arguments];
                va_end(arguments);
                details = rendered ?: @"";
#if !__has_feature(objc_arc)
                [rendered autorelease];
#endif
            }

            NSString *line = [NSString stringWithFormat:@"%@ pid=%d up=%.1f %@ %@\n", OGCompatProbeTimestamp(), getpid(), OGPlatformSystemUptime(), stage, OGCompatProbeFlatten(details)];
            NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
            if (data.length == 0)
                return;

            OGCompatProbeAppend(data);
        }
        @catch (__unused NSException *exception)
        {
        }
    }
}

#define OGCompatProbe(...) OGCompatProbeWrite(__VA_ARGS__)
#else
#define OGCompatProbe(...) do { } while (0)
#endif

#define OGNotificationProbe(...) OGCompatProbe(__VA_ARGS__)
