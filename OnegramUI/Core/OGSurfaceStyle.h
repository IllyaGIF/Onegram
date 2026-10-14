#import <UIKit/UIKit.h>

typedef enum {
    OGSurfaceShapeBand = 0,
    OGSurfaceShapeRoundedRect = 1,
    OGSurfaceShapeBackArrow = 2,
    OGSurfaceShapeBubbleLeft = 3,
    OGSurfaceShapeBubbleRight = 4,
    OGSurfaceShapeSheet = 5,
    OGSurfaceShapeSheetBottom = 6
} OGSurfaceShape;

typedef enum {
    OGSurfaceBlendModeNormal = 0,
    OGSurfaceBlendModeSoftLight = 1,
    OGSurfaceBlendModeHardLight = 2
} OGSurfaceBlendMode;

@interface OGSurfaceShadow : NSObject
@property (nonatomic, retain, readonly) UIColor *color;
@property (nonatomic, readonly) CGSize offset;
@property (nonatomic, readonly) CGFloat blur;
@property (nonatomic, readonly) BOOL inset;
@property (nonatomic, readonly) CGFloat spread;
+ (OGSurfaceShadow *)dropShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur;
+ (OGSurfaceShadow *)insetShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur;
+ (OGSurfaceShadow *)insetShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur spread:(CGFloat)spread;
- (UIEdgeInsets)outsets;
- (NSString *)renderIdentity;
@end

@interface OGSurfaceLayer : NSObject <NSCopying>
@property (nonatomic) UIEdgeInsets insets;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic) BOOL anchoredToRight;
@property (nonatomic) BOOL anchoredToBottom;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL elliptical;
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray *locations;
@property (nonatomic) CGFloat gradientAngle;
@property (nonatomic) BOOL conicGradient;
@property (nonatomic) OGSurfaceBlendMode blendMode;
@property (nonatomic, copy) NSArray *shadows;
- (CGRect)frameInBodySize:(CGSize)bodySize;
- (NSString *)renderIdentity;
@end

@interface OGSurfaceStyle : NSObject <NSCopying>
@property (nonatomic, copy) NSString *textureResourceDirectory;
@property (nonatomic, copy) NSString *textureAssetName;
@property (nonatomic) CGFloat textureReferenceWidth;
@property (nonatomic) BOOL textureTiled;
@property (nonatomic) CGRect textureContentsRect;
@property (nonatomic) CGFloat textureContrast;
@property (nonatomic) CGFloat textureBias;
@property (nonatomic, retain) UIColor *textureTintColor;
@property (nonatomic, retain) UIColor *fillColor;
@property (nonatomic, retain) UIColor *overlayColor;
@property (nonatomic) OGSurfaceShape shape;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat arrowWidth;
@property (nonatomic) CGFloat arrowTipRadius;
@property (nonatomic) CGSize tailSize;
@property (nonatomic) CGFloat tailBottomInset;
@property (nonatomic, copy) NSArray *layers;
@property (nonatomic) CGFloat opacity;
@property (nonatomic, copy) NSArray *shadows;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic, copy) NSArray *strokeColors;
- (UIEdgeInsets)dropShadowOutsets;
- (UIEdgeInsets)horizontalCapInsets;
- (NSString *)renderIdentity;
@end
