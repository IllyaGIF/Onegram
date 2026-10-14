#import <Foundation/Foundation.h>
#import "OGUserItem.h"
@interface OGMemberItem : NSObject
@property (nonatomic, retain) OGUserItem *user;
@property (nonatomic, copy) NSString *roleText;
@end
