#import <Foundation/Foundation.h>
#include <time.h>

@interface TGDateUtils : NSObject

+ (void)reset;
+ (void)prepare;

+ (void)setShowsSeconds:(bool)showsSeconds;
+ (void)setPrefersExactLastSeen:(bool)prefersExactLastSeen;
+ (void)setTimeZoneOffsetOverride:(bool)enabled minutes:(NSInteger)minutes;

+ (NSString *)stringForShortTime:(int)time;
+ (NSString *)stringForShortTime:(int)time daytimeVariant:(int *)daytimeVariant;
+ (NSString *)stringForShortTimeWithHours:(int)hours minutes:(int)minutes;
+ (NSString *)stringForDialogTime:(int)time;
+ (NSString *)stringForDayOfWeek:(int)date;
+ (NSString *)stringForMonthOfYear:(int)date;
+ (NSString *)stringForPreciseDate:(int)date;
+ (NSString *)stringForMessageListDate:(int)date;
+ (NSString *)stringForMessageListDate:(int)date relativeToDate:(int)currentDate;
+ (NSString *)stringForLastSeen:(int)date;
+ (NSString *)stringForApproximateDate:(int)date;
+ (NSString *)stringForRelativeLastSeen:(int)date;
+ (NSString *)stringForRelativeUpdate:(int)date;
+ (NSString *)stringForFullDate:(int)date;
+ (NSString *)stringForCallsListDate:(int)date;

@end

#ifdef __cplusplus
extern "C" {
#endif

bool TGUse12hDateFormat();
void TGDateUtilsLocalTime(time_t time, struct tm *result);
    
NSString *TGWeekdayNameFull(int number);
NSString *TGMonthNameFull(int number);
NSString *TGMonthNameShort(int number);
    
#ifdef __cplusplus
}
#endif
