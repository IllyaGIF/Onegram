#import <UIKit/UIKit.h>

#import "TGPresentationCustomColors.h"

@class TGPresentationPallete;

FOUNDATION_EXPORT CGFloat TGOnegramColorPreviewHeight(TGPresentationColorPreview preview);
FOUNDATION_EXPORT UIImage *TGOnegramColorPreviewImage(TGPresentationColorPreview preview, TGPresentationPallete *pallete, UIColor *color, CGSize size);
FOUNDATION_EXPORT UIImage *TGOnegramColorSwatchImage(UIColor *color, CGFloat diameter, UIColor *borderColor);
FOUNDATION_EXPORT void TGOnegramColorGetHSB(UIColor *color, CGFloat *hue, CGFloat *saturation, CGFloat *brightness);
FOUNDATION_EXPORT NSString *TGOnegramColorHexString(UIColor *color);
