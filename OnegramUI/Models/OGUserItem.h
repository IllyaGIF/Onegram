#import <Foundation/Foundation.h>
@interface OGUserItem : NSObject
@property (nonatomic) int64_t userId;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, copy) NSString *avatarUri;
@end
