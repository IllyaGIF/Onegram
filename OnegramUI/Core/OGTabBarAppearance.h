#import <UIKit/UIKit.h>

@class OGSurfaceStyle;

@interface OGTabBarSegmentStyle : NSObject
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray *locations;
@property (nonatomic, copy) NSArray *shadows;
@property (nonatomic, retain) UIColor *trailingEdgeColor;
@property (nonatomic) BOOL trailingEdgeAboveNeighbor;
@end

@interface OGTabBarLayout : NSObject
@property (nonatomic, retain) OGTabBarSegmentStyle *segmentStyle;
@property (nonatomic, retain) OGTabBarSegmentStyle *selectedSegmentStyle;
@property (nonatomic) CGFloat iconTopInset;
@property (nonatomic) CGFloat titleBottomInset;
@property (nonatomic) CGFloat titleHeight;
@end

@interface OGTabBarAppearance : NSObject
@property (nonatomic, retain) UIFont *titleFont;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *titleShadowColor;
@property (nonatomic) CGSize titleShadowOffset;
@property (nonatomic) CGFloat titleShadowRadius;
@property (nonatomic, copy) NSArray *iconGradientColors;
@property (nonatomic, copy) NSArray *iconGradientLocations;
@property (nonatomic, copy) NSArray *iconShadows;
@property (nonatomic, copy) NSArray *selectedIconGradientColors;
@property (nonatomic, copy) NSArray *selectedIconGradientLocations;
@property (nonatomic, copy) NSArray *selectedIconShadows;
@property (nonatomic, retain) OGTabBarLayout *compactLayout;
@property (nonatomic, retain) OGTabBarLayout *regularLayout;
@property (nonatomic) NSUInteger regularLayoutMinimumItemCount;
- (OGTabBarLayout *)layoutForItemCount:(NSUInteger)itemCount;
- (UIEdgeInsets)iconOutsets;
- (OGSurfaceStyle *)backgroundStyleWithSegmentFrames:(NSArray *)segmentFrames selectedIndex:(NSInteger)selectedIndex;
+ (OGTabBarAppearance *)brandedAppearance;
@end
