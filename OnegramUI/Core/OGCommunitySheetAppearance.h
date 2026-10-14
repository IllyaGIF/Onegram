#import <UIKit/UIKit.h>

@class OGSurfaceStyle;
@class OGNavigationAppearance;

@interface OGCommunitySheetAppearance : NSObject
@property (nonatomic, retain) UIColor *dimColor;
@property (nonatomic) CGFloat collapsedHeightFraction;
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic, retain) OGSurfaceStyle *headerSurfaceStyle;
@property (nonatomic, retain) UIColor *indicatorColor;
@property (nonatomic) CGFloat indicatorSpacing;
+ (OGCommunitySheetAppearance *)brandedAppearanceDark:(BOOL)dark navigationAppearance:(OGNavigationAppearance *)navigationAppearance;
@end
