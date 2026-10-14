#import <Foundation/Foundation.h>
@class OGMediaItem;
typedef OGMediaItem * (^OGTelegramMediaAdapterMapper)(id object);
@interface OGTelegramMediaAdapter : NSObject
+ (void)setMapper:(OGTelegramMediaAdapterMapper)mapper;
+ (OGMediaItem *)itemFromTelegramObject:(id)object;
@end
