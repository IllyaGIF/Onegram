#import <Foundation/Foundation.h>
@class OGMessageItem;
typedef OGMessageItem * (^OGTelegramMessageAdapterMapper)(id object);
@interface OGTelegramMessageAdapter : NSObject
+ (void)setMapper:(OGTelegramMessageAdapterMapper)mapper;
+ (OGMessageItem *)itemFromTelegramObject:(id)object;
@end
