#import <UIKit/UIKit.h>

@interface TGRichMessageMathLayout : NSObject

@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat ascent;
@property (nonatomic, readonly) CGFloat descent;

+ (instancetype)layoutWithSource:(NSString *)source fontSize:(CGFloat)fontSize display:(bool)display;

- (void)drawInContext:(CGContextRef)context baselineOrigin:(CGPoint)origin color:(UIColor *)color;

@end
