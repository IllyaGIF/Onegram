#import "TGRemoteHttpLocationSignal.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTHttpRequestOperation.h"
#import "MTSignal.h"
#import "MTDisposable.h"
#import "../submodules/MtProtoKit/thirdparty/AFNetworking/AFJSONUtilities.h"

@implementation TGRemoteHttpLocationSignal

+ (SSignal *)dataForHttpLocation:(NSString *)httpLocation
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        id<MTDisposable> disposable = [[MTHttpRequestOperation dataForHttpUrl:[[NSURL alloc] initWithString:httpLocation]] startWithNext:^(id next) {
            [subscriber putNext:next];
        } error:^(id error) {
            [subscriber putError:error];
        } completed:^{
            [subscriber putCompletion];
        }];
        return [[SBlockDisposable alloc] initWithBlock:^{
            [disposable dispose];
        }];
    }];
}

+ (SSignal *)jsonForHttpLocation:(NSString *)httpLocation
{
    return [[self dataForHttpLocation:httpLocation] mapToSignal:^SSignal *(NSData *response)
    {
        if (response == nil)
            return [SSignal fail:nil];
        
        @try
        {
            NSError *error = nil;
#if ONEGRAM_ARMV6
            id json = AFJSONDecode(response, &error);
#else
            id json = [NSJSONSerialization JSONObjectWithData:response options:kNilOptions error:&error];
#endif
            if (error == nil)
                return [SSignal single:json];
            else
                return [SSignal fail:error];
        }
        @catch (NSException *exception)
        {
            return [SSignal fail:nil];
        }
    }];
}

@end
