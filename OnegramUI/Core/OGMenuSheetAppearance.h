#import <UIKit/UIKit.h>

@class OGSurfaceStyle;

@interface OGMenuSheetAppearance : NSObject
@property (nonatomic, retain) OGSurfaceStyle *surfaceStyle;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, retain) UIColor *selectionColor;
@property (nonatomic, retain) UIColor *separatorColor;
@property (nonatomic, retain) UIColor *accentColor;
@property (nonatomic, retain) UIColor *destructiveColor;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) UIColor *secondaryTextColor;
@property (nonatomic, retain) UIColor *textShadowColor;
@property (nonatomic) CGSize textShadowOffset;
@property (nonatomic, retain) UIFont *buttonFont;
@property (nonatomic, retain) UIFont *cancelButtonFont;
+ (OGMenuSheetAppearance *)brandedAppearanceDark:(BOOL)dark;
@end
