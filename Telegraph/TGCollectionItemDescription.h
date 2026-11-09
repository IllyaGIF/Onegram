#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

UIFont *TGCollectionItemDescriptionFont(void);
UILabel *TGCollectionItemDescriptionLabel(void);
CGFloat TGCollectionItemDescriptionTextHeight(NSString *text, CGFloat width);
CGFloat TGCollectionItemDescriptionHorizontalInset(void);
CGFloat TGCollectionItemSwitchDescriptionWidth(CGFloat containerWidth);
CGFloat TGCollectionItemVariantDescriptionWidth(CGFloat containerWidth);
CGFloat TGCollectionItemSwitchHeightWithDescription(NSString *text, CGFloat containerWidth);
CGFloat TGCollectionItemVariantHeightWithDescription(NSString *text, CGFloat containerWidth);

#ifdef __cplusplus
}
#endif

static const CGFloat TGCollectionItemDescriptionTitleTop = 11.0f;
static const CGFloat TGCollectionItemDescriptionTitleHeight = 22.0f;
static const CGFloat TGCollectionItemDescriptionSpacing = 2.0f;
static const CGFloat TGCollectionItemDescriptionBottom = 11.0f;
static const CGFloat TGCollectionItemDescriptionVariantTop = 36.0f;
