#ifndef Telegraph_TGCommon_h
#define Telegraph_TGCommon_h

#import <UIKit/UIKit.h>
#include <inttypes.h>
#import <stddef.h>
#import "OGPlatformDispatch.h"

#define TGUseSocial true

#undef TG_ENABLE_AUDIO_NOTES
#define TG_ENABLE_AUDIO_NOTES true

#define TGAssert(expr) assert(expr)

#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])

#define TGRestrictedToMainThread {if(![[NSThread currentThread] isMainThread]) TGLog(@"***** Warning: main thread-bound operation is running in background! *****");}


extern int TGLocalizedStaticVersion;
FOUNDATION_EXPORT NSString *const TGStartupLocalizationUpdatedNotification;

#undef TG_TIMESTAMP_DEFINE
#undef TG_TIMESTAMP_MEASURE
#define TG_TIMESTAMP_DEFINE(s) CFAbsoluteTime tg_timestamp_##s = CFAbsoluteTimeGetCurrent(); int tg_timestamp_line_##s = __LINE__;
#define TG_TIMESTAMP_MEASURE(s) { CFAbsoluteTime tg_timestamp_current_time = CFAbsoluteTimeGetCurrent(); TGLog(@"%s %d-%d: %f ms", #s, tg_timestamp_line_##s, __LINE__, (tg_timestamp_current_time - tg_timestamp_##s) * 1000.0); tg_timestamp_##s = tg_timestamp_current_time; tg_timestamp_line_##s = __LINE__; }

#ifdef __cplusplus
extern "C" {
#endif
typedef enum {
    TGPerformanceClassConstrained = 0,
    TGPerformanceClassBalanced = 1,
    TGPerformanceClassFast = 2,
    TGPerformanceClassHigh = 3
} TGPerformanceClass;

int cpuCoreCount();
bool hasModernCpu();
int deviceMemorySize();
TGPerformanceClass devicePerformanceClass();
int performanceBackgroundWorkerCount();
    
void TGSetLocalizationFromFile(NSString *filePath);
NSString *TGLocalized(NSString *s);
NSString *TGStartupLocalized(NSString *s);
    
@class TGLocalization;

TGLocalization *effectiveLocalization();
NSString *currentLocalizationEnglishLanguageName();
TGLocalization *nativeEnglishLocalization();
TGLocalization *currentNativeLocalization();
NSString *currentNativeLocalizationCode();
TGLocalization *currentCustomLocalization();
void setCurrentNativeLocalization(TGLocalization *localization, bool switchIfCustom);
void setCurrentCustomLocalization(TGLocalization *localization);

bool TGObjectCompare(id obj1, id obj2);
bool TGStringCompare(NSString *s1, NSString *s2);
    
NSTimeInterval TGCurrentSystemTime();
    
NSString *TGStringMD5(NSString *string);
    
int iosMajorVersion();
int iosMinorVersion();
    
void printMemoryUsage(NSString *tag);
    
void TGDumpViews(UIView *view, NSString *indent);
    
NSString *TGEncodeText(NSString *string, int key);
    
inline void TGDispatchOnMainThread(dispatch_block_t block)
{
    OGPlatformDispatchOnMainThread(block);
}

inline void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}
    
void TGLogSetEnabled(bool enabled);
bool TGLogEnabled();
bool TGLogAvailable();
#if defined(ONEGRAM_DIAGNOSTICS) || defined(ONEGRAM_LOG_IMPLEMENTATION)
#undef TGLog
#undef TGLogv
void TGLog(NSString *format, ...);
void TGLogv(NSString *format, va_list args);
#else
#undef TGLog
#define TGLog(...) ((void)0)
#define TGLogv(...) ((void)0)
#endif

void TGLogSynchronize();
void TGLogClear();
bool TGDeleteLogFile(NSString *path, NSError **error);
NSString *TGIOS6DiagnosticBreadcrumbPath();
void TGIOS6PrepareDiagnosticBreadcrumbs();
void TGIOS6NativeDiagnosticWrite(const char *bytes, size_t length);
NSArray *TGGetLogFilePaths(int count);
NSArray *TGGetArchivedLogFilePaths();
NSString *TGSaveCurrentLogLines(int lineCount);
NSString *TGSaveCurrentLogLinesWithError(int lineCount, NSError **error);
NSString *TGArchiveCrashLogText(NSString *text, NSDate *date);
NSArray *TGGetPackedLogs();

#if defined(TG_PUBLIC_BUILD) && !defined(TGCOMMON_IMPLEMENTATION)
#undef TG_TIMESTAMP_DEFINE
#undef TG_TIMESTAMP_MEASURE
#define TG_TIMESTAMP_DEFINE(s)
#define TG_TIMESTAMP_MEASURE(s)
#endif
    
#ifdef __cplusplus
}
#endif

@interface NSNumber (IntegerTypes)

- (int32_t)int32Value;
- (int64_t)int64Value;

@end

#ifdef __LP64__
#   define CGFloor floor
#else
#   define CGFloor floorf
#endif

#ifdef __LP64__
#   define CGRound round
#   define CGCeil ceil
#   define CGPow pow
#   define CGSin sin
#   define CGCos cos
#   define CGSqrt sqrt
#else
#   define CGRound roundf
#   define CGCeil ceilf
#   define CGPow powf
#   define CGSin sinf
#   define CGCos cosf
#   define CGSqrt sqrtf
#endif

#define CGEven(x) ((((int)x) & 1) ? (x + 1) : x)
#define CGOdd(x) ((((int)x) & 1) ? x : (x + 1))

#import "TGTColor.h"

#endif
