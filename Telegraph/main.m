#include <mach/mach_time.h>
#import "../OnegramRuntime/OGStartupDiagnostics.h"
#import <UIKit/UIKit.h>

#import "TGAppDelegate.h"
#import "TGApplication.h"

#import "TGDatabase.h"
#import "TGAccountManager.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../OnegramRuntime/OGDiagnostics.h"

int main(int argc, char *argv[])
{
    uint64_t startupTicks = mach_absolute_time();
    NSTimeInterval startupUnixTime = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
    @autoreleasepool
    {
        OGDiagnosticsActivate(OGDiagnosticsComponentOnegram, [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"OGOnegramBuildDiagnostics"] boolValue]);
        OGDiagnosticsTimingBegin("cold_start");
    }
    OGRuntimeConfigureMainThread();
    mainLaunchTimestamp = CFAbsoluteTimeGetCurrent();
    applicationStartupTimestamp = mainLaunchTimestamp;
    @autoreleasepool
    {
        if (OGDiagnosticsEnabled())
            OGStartupDiagnosticsInitialize(startupTicks, startupUnixTime);
        [TGAccountManager performLaunchRecovery];
        [TGDatabase setDatabaseName:@"tgdata"];
        
        return UIApplicationMain(argc, argv, @"TGApplication", @"TGAppDelegate");
    }
}
