#import "TGCollectionItemDescription.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGPresentation.h"
#import "TGFlatControls.h"

UIFont *TGCollectionItemDescriptionFont(void)
{
    static UIFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = TGSystemFontOfSize(13.0f);
    });
    return font;
}

UILabel *TGCollectionItemDescriptionLabel(void)
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.font = TGCollectionItemDescriptionFont();
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentLeft;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

CGFloat TGCollectionItemDescriptionTextHeight(NSString *text, CGFloat width)
{
    if (text.length == 0 || width <= 0.0f)
        return 0.0f;
    CGSize size = OGPlatformTextSize(text, TGCollectionItemDescriptionFont(), CGSizeMake(width, CGFLOAT_MAX), UILineBreakModeWordWrap);
    return CGCeil(size.height);
}

CGFloat TGCollectionItemDescriptionHorizontalInset(void)
{
    return [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
}

CGFloat TGCollectionItemSwitchDescriptionWidth(CGFloat containerWidth)
{
    CGFloat inset = TGCollectionItemDescriptionHorizontalInset();
    CGFloat switchWidth = TGFlatControlsEnabled() || iosMajorVersion() >= 7 ? 51.0f : 79.0f;
    return containerWidth - (15.0f + inset) - (switchWidth + 20.0f) - 8.0f;
}

CGFloat TGCollectionItemVariantDescriptionWidth(CGFloat containerWidth)
{
    CGFloat inset = TGCollectionItemDescriptionHorizontalInset();
    return containerWidth - (15.0f + inset) * 2.0f;
}

CGFloat TGCollectionItemSwitchHeightWithDescription(NSString *text, CGFloat containerWidth)
{
    CGFloat textHeight = TGCollectionItemDescriptionTextHeight(text, TGCollectionItemSwitchDescriptionWidth(containerWidth));
    if (textHeight <= 0.0f)
        return 44.0f;
    return MAX(44.0f, TGCollectionItemDescriptionTitleTop + TGCollectionItemDescriptionTitleHeight + TGCollectionItemDescriptionSpacing + textHeight + TGCollectionItemDescriptionBottom);
}

CGFloat TGCollectionItemVariantHeightWithDescription(NSString *text, CGFloat containerWidth)
{
    CGFloat textHeight = TGCollectionItemDescriptionTextHeight(text, TGCollectionItemVariantDescriptionWidth(containerWidth));
    if (textHeight <= 0.0f)
        return 44.0f;
    return TGCollectionItemDescriptionVariantTop + textHeight + TGCollectionItemDescriptionBottom;
}
