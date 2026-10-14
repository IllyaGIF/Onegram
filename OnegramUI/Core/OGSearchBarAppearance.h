#import <UIKit/UIKit.h>

@class OGSurfaceStyle;

@interface OGSearchBarAppearance : NSObject
@property (nonatomic, retain) OGSurfaceStyle *backgroundSurfaceStyle;
@property (nonatomic, retain) UIColor *backdropColor;
@property (nonatomic, retain) OGSurfaceStyle *fieldSurfaceStyle;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) UIColor *placeholderColor;
@property (nonatomic, retain) UIColor *iconColor;
@property (nonatomic) CGFloat iconSize;
@property (nonatomic) CGFloat iconCircleDiameter;
@property (nonatomic) CGFloat iconLineWidth;
@property (nonatomic) UIOffset iconOffset;
@property (nonatomic) UIOffset placeholderOffset;
+ (OGSearchBarAppearance *)brandedAppearanceDark:(BOOL)dark;
+ (OGSearchBarAppearance *)contactAppearanceDark:(BOOL)dark;
@end
