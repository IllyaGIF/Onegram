#import <Foundation/Foundation.h>
@class OGCallItem;
typedef OGCallItem * (^OGTelegramCallAdapterMapper)(id object);
@interface OGTelegramCallAdapter : NSObject
+ (void)setMapper:(OGTelegramCallAdapterMapper)mapper;
+ (OGCallItem *)itemFromTelegramObject:(id)object;
@end
