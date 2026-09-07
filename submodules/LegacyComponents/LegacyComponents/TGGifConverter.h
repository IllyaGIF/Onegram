#import <Foundation/Foundation.h>
#import "SSignalKitCompat/SSignalKit.h"

@interface TGGifConverter : NSObject

+ (SSignal *)convertGifToMp4:(NSData *)data;

@end
