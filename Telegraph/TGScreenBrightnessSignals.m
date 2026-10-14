#import "TGScreenBrightnessSignals.h"
#import "../OnegramPlatform/OGPlatformVersion.h"

@implementation TGScreenBrightnessSignals

+ (SSignal *)brightnessSignal
{
    SSignal *updateSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __block CGFloat lastBrightness = OGPlatformScreenBrightness();
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:OGPlatformScreenBrightnessDidChangeNotification() object:nil queue:nil usingBlock:^(__unused NSNotification * _Nonnull note)
        {
            lastBrightness = OGPlatformScreenBrightness();
            [subscriber putNext:@(lastBrightness)];
        }];
        STimer *timer = [[STimer alloc] initWithTimeout:1.0 repeat:true completion:^{
            CGFloat brightness = OGPlatformScreenBrightness();
            if (fabs(brightness - lastBrightness) > FLT_EPSILON)
            {
                lastBrightness = brightness;
                [subscriber putNext:@(brightness)];
            }
        } nativeQueue:dispatch_get_main_queue()];
        [timer start];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }];
    }];
    
    return [[SSignal defer:^SSignal *{
        return [SSignal single:@(OGPlatformScreenBrightness())];
    }] then:updateSignal];
}

@end
