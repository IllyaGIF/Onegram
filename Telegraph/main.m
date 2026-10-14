#include <mach/mach_time.h>
#import "../OnegramRuntime/OGStartupDiagnostics.h"
#import <UIKit/UIKit.h>

#import "TGAppDelegate.h"
#import "TGApplication.h"

#import "TGDatabase.h"
#import "../OnegramRuntime/OGRuntime.h"

int main(int argc, char *argv[])
{
#if defined(ONEGRAM_DIAGNOSTICS)
    uint64_t startupTicks = mach_absolute_time();
    NSTimeInterval startupUnixTime = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
#endif
    OGRuntimeConfigureMainThread();
    mainLaunchTimestamp = CFAbsoluteTimeGetCurrent();
    applicationStartupTimestamp = mainLaunchTimestamp;
    @autoreleasepool
    {
#if defined(ONEGRAM_DIAGNOSTICS)
        OGStartupDiagnosticsInitialize(startupTicks, startupUnixTime);
#endif
        [TGDatabase setDatabaseName:@"tgdata"];
        
        return UIApplicationMain(argc, argv, @"TGApplication", @"TGAppDelegate");
    }
}