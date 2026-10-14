#import <Foundation/Foundation.h>
@class OGMemberItem;
typedef OGMemberItem * (^OGTelegramGroupAdapterMapper)(id object);
@interface OGTelegramGroupAdapter : NSObject
+ (void)setMapper:(OGTelegramGroupAdapterMapper)mapper;
+ (OGMemberItem *)itemFromTelegramObject:(id)object;
@end
