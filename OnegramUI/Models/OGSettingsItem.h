#import <Foundation/Foundation.h>
@interface OGSettingsItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic) BOOL enabled;
@end
