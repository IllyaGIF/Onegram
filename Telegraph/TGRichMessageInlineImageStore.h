#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

extern NSString *const TGRichMessageInlineImageLoadedNotification;

@interface TGRichMessageInlineImageStore : NSObject

+ (void)performWithoutStartingRequests:(dispatch_block_t)block;

+ (UIImage *)imageForKey:(NSString *)key;
+ (void)requestImageForKey:(NSString *)key signalGenerator:(SSignal *(^)(void))signalGenerator;

+ (NSString *)customEmojiKey:(int64_t)documentId;
+ (SSignal *)customEmojiImageSignal:(int64_t)documentId;
+ (SSignal *)imageSignalForUri:(NSString *)uri;

@end
