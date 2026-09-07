#import <UIKit/UIKit.h>

@class TGPresentation;

@interface TGWallpaperItemsBackgroundDecorationAttributes : PSUICollectionViewLayoutAttributes

@property (nonatomic, strong) TGPresentation *presentation;

@end

@interface TGWallpaperItemsBackgroundDecorationView : PSUICollectionReusableView

+ (NSString *)kind;

@end
