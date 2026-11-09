#import <Foundation/Foundation.h>

@protocol OGHelperTimerReceiver <NSObject>
- (void)refreshTimerFired:(NSTimer *)timer;
@end

@interface OGHelperTimerTarget : NSObject

+ (NSTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval target:(id<OGHelperTimerReceiver>)target;

@end
