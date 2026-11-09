#import <Foundation/Foundation.h>

@interface TGCrashReportCenter : NSObject

+ (bool)reportsEnabled;
+ (void)setReportsEnabled:(bool)enabled;
+ (NSString *)pendingReportPath;
+ (void)startMonitoring;

+ (void)archiveDidFinish;
+ (void)mainInterfaceDidAppear;

@end
