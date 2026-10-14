#import <UIKit/UIKit.h>

@class OGSurfaceStyle;
@class OGSearchBarAppearance;

@interface OGContactListAppearance : NSObject
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic, retain) UIColor *rowBackgroundColor;
@property (nonatomic, retain) UIColor *rowTitleColor;
@property (nonatomic, retain) UIFont *rowTitleFont;
@property (nonatomic, retain) UIFont *rowTitleBoldFont;
@property (nonatomic) CGFloat rowTitleRightInset;
@property (nonatomic, retain) OGSurfaceStyle *navigationSurfaceStyle;
@property (nonatomic, retain) UIColor *navigationStitchColor;
@property (nonatomic, retain) OGSearchBarAppearance *searchBarAppearance;
@property (nonatomic) CGFloat sectionHeaderHeight;
@property (nonatomic) CGFloat searchBarOverlap;
@property (nonatomic, retain) OGSurfaceStyle *sectionHeaderSurfaceStyle;
@property (nonatomic, retain) UIFont *sectionTitleFont;
@property (nonatomic, retain) UIColor *sectionTitleColor;
@property (nonatomic, retain) UIColor *sectionTitleShadowColor;
@property (nonatomic) CGSize sectionTitleShadowOffset;
@property (nonatomic) CGFloat sectionTitleLeftInset;
@property (nonatomic) CGFloat sectionTitleBottomInset;
@property (nonatomic, retain) UIColor *separatorColor;
@property (nonatomic) CGFloat separatorHeight;
@property (nonatomic) BOOL hidesSeparatorAboveSectionHeader;
@property (nonatomic) BOOL showsSectionIndex;
@property (nonatomic, retain) UIColor *indexColor;
@property (nonatomic, retain) UIColor *indexTrackingBackgroundColor;
@property (nonatomic) UIEdgeInsets searchFieldInsets;
@property (nonatomic) CGFloat searchIndexInset;
+ (OGContactListAppearance *)brandedAppearanceDark:(BOOL)dark;
@end
