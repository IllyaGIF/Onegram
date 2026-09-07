#import "TGFuckDPILog.h"

static NSMutableArray *g_logBuffer = nil;
static dispatch_queue_t g_logQueue = nil;

static void FDPILogInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_logBuffer = [[NSMutableArray alloc] init];
        g_logQueue = dispatch_queue_create("org.onegram.fuckdpi.log", DISPATCH_QUEUE_SERIAL);
    });
}

#define FDPI_FORCE_LOG 0

void FDPILog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[FuckDPI] %@", msg);

    BOOL loggingEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuckDPILoggingEnabled_v5"];
    if (!loggingEnabled && !FDPI_FORCE_LOG) return;

    FDPILogInit();

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timeStr = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@", timeStr, msg];

    dispatch_async(g_logQueue, ^{
        [g_logBuffer addObject:line];
        if (g_logBuffer.count > 500) {
            [g_logBuffer removeObjectAtIndex:0];
        }
    });

    const char *cLine = [[line stringByAppendingString:@"\n"] UTF8String];
    NSString *home = NSHomeDirectory();
    if (home != nil) {
        NSString *p1 = [home stringByAppendingPathComponent:@"Documents/fuckdpi.log"];
        FILE *f1 = fopen([p1 UTF8String], "a");
        if (f1 != NULL) { fputs(cLine, f1); fclose(f1); }
    }
}

NSArray *FDPIGetLogs(void)
{
    FDPILogInit();
    __block NSArray *copy = nil;
    dispatch_sync(g_logQueue, ^{
        copy = [g_logBuffer copy];
    });
    return copy;
}

void FDPIClearLogs(void)
{
    FDPILogInit();
    dispatch_async(g_logQueue, ^{
        [g_logBuffer removeAllObjects];
    });
}
