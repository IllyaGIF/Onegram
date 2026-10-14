#import <Foundation/Foundation.h>
@class OGUserItem;
typedef OGUserItem * (^OGTelegramUserAdapterMapper)(id object);
@interface OGTelegramUserAdapter : NSObject
+ (void)setMapper:(OGTelegramUserAdapterMapper)mapper;
+ (OGUserItem *)itemFromTelegramObject:(id)object;
@end
