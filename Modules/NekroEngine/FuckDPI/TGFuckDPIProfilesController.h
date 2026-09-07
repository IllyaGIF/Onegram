#import <UIKit/UIKit.h>

@interface TGFuckDPIProfilesController : UITableViewController
@property (nonatomic, copy) void (^profileChanged)(NSInteger newIndex, NSString *newProfileName);
@end
