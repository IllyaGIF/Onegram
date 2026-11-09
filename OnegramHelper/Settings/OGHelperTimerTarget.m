#import "OGHelperTimerTarget.h"

@interface OGHelperTimerTarget ()
{
    __unsafe_unretained id<OGHelperTimerReceiver> _target;
}

@end

@implementation OGHelperTimerTarget

+ (NSTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval target:(id<OGHelperTimerReceiver>)target
{
    OGHelperTimerTarget *timerTarget = [[OGHelperTimerTarget alloc] init];
    timerTarget->_target = target;
    return [NSTimer scheduledTimerWithTimeInterval:interval target:timerTarget selector:@selector(timerFired:) userInfo:nil repeats:true];
}

- (void)timerFired:(NSTimer *)timer
{
    if (_target == nil)
    {
        [timer invalidate];
        return;
    }
    [_target refreshTimerFired:timer];
}

@end
