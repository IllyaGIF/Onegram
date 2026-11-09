#import <Foundation/Foundation.h>

#import "../submodules/MtProtoKit/MTProtoKit/MTMessageService.h"

@interface OGHelperDaemon : NSObject <MTMessageService>

- (bool)start;
- (void)stop;

@end
