#import <UIKit/UIKit.h>

@class TGPresentation;

@interface TGCommunityAppearance : NSObject

+ (CGFloat)indicatorWidthForContainerWidth:(CGFloat)containerWidth;
+ (CGFloat)contentInsetForContainerWidth:(CGFloat)containerWidth avatarInset:(CGFloat)avatarInset;
+ (UIImage *)indicatorImageWithWidth:(CGFloat)width presentation:(TGPresentation *)presentation;

+ (UIColor *)swipeButtonColorWithWidth:(CGFloat)width presentation:(TGPresentation *)presentation;

@end
