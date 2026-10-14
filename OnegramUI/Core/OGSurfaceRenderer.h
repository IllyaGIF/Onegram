#import <UIKit/UIKit.h>

@class OGAssets;
@class OGSurfaceStyle;
@class OGSurfaceShadow;

@interface OGSurfaceRenderer : NSObject
- (instancetype)initWithAssets:(OGAssets *)assets;
- (UIImage *)imageWithStyle:(OGSurfaceStyle *)style size:(CGSize)size bodyFrame:(CGRect)bodyFrame;
- (UIImage *)glyphImageWithTemplate:(UIImage *)image opticalSize:(CGFloat)opticalSize;
- (UIImage *)glyphImageWithText:(NSString *)text font:(UIFont *)font opticalSize:(CGFloat)opticalSize;
- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadow:(OGSurfaceShadow *)shadow outsets:(UIEdgeInsets)outsets;
- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadows:(NSArray *)shadows outsets:(UIEdgeInsets)outsets;
@end
