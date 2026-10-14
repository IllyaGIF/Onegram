#import <Foundation/Foundation.h>
@class OGDialogItem;
typedef OGDialogItem * (^OGTelegramDialogAdapterMapper)(id object);
@interface OGTelegramDialogAdapter : NSObject
+ (void)setMapper:(OGTelegramDialogAdapterMapper)mapper;
+ (OGDialogItem *)itemFromTelegramObject:(id)object;
@end
