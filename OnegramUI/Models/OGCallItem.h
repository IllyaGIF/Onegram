#import <Foundation/Foundation.h>
#import "OGUserItem.h"
@interface OGCallItem : NSObject
@property (nonatomic, retain) OGUserItem *user;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, copy) NSString *dateText;
@property (nonatomic) BOOL outgoing;
@end
