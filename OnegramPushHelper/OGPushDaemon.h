#import <Foundation/Foundation.h>

#import "../submodules/MtProtoKit/MTProtoKit/MTMessageService.h"

@interface OGPushDaemon : NSObject <MTMessageService>

- (bool)start;
- (void)stop;

@end
