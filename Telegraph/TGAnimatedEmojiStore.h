#import <Foundation/Foundation.h>

@class TGDocumentMediaAttachment;

extern NSString *const TGAnimatedEmojiStoreDidUpdateNotification;

@interface TGAnimatedEmojiStore : NSObject

+ (void)preload;
+ (TGDocumentMediaAttachment *)documentForText:(NSString *)text;

@end
