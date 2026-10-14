#import "../Base/OGButton.h"
@class OGBadgeView;
@interface OGTabBarItem : OGButton
@property (nonatomic, retain, readonly) OGBadgeView *badgeView;
@property (nonatomic) NSInteger badgeCount;
@end
