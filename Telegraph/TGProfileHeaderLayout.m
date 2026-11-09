#import "TGProfileHeaderLayout.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

const CGFloat TGProfileHeaderAvatarSize = 100.0f;

static const CGFloat TGProfileHeaderTopInset = 12.0f;
static const CGFloat TGProfileHeaderAvatarTitleSpacing = 12.0f;
static const CGFloat TGProfileHeaderTitleSubtitleSpacing = 1.0f;
static const CGFloat TGProfileHeaderAccessorySpacing = 12.0f;
static const CGFloat TGProfileHeaderBottomInset = 18.0f;
static const CGFloat TGProfileHeaderAccessoryBottomInset = 14.0f;

UIFont *TGProfileHeaderTitleFont(void)
{
    static UIFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = TGMediumSystemFontOfSize(22.0f);
    });
    return font;
}

UIFont *TGProfileHeaderSubtitleFont(void)
{
    static UIFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = TGSystemFontOfSize(15.0f);
    });
    return font;
}

NSString *TGProfileHeaderAvatarFilter(void)
{
    return [[NSString alloc] initWithFormat:@"circle:%.0fx%.0f", TGProfileHeaderAvatarSize, TGProfileHeaderAvatarSize];
}

CGRect TGProfileHeaderAvatarFrame(CGRect bounds)
{
    return CGRectMake(CGFloor((bounds.size.width - TGProfileHeaderAvatarSize) / 2.0f), TGProfileHeaderTopInset, TGProfileHeaderAvatarSize, TGProfileHeaderAvatarSize);
}

CGFloat TGProfileHeaderTitleTop(void)
{
    return TGProfileHeaderTopInset + TGProfileHeaderAvatarSize + TGProfileHeaderAvatarTitleSpacing;
}

CGFloat TGProfileHeaderTitleLineHeight(void)
{
    return CGCeil(OGPlatformFontLineHeight(TGProfileHeaderTitleFont()));
}

CGFloat TGProfileHeaderSubtitleTop(void)
{
    return TGProfileHeaderTitleTop() + TGProfileHeaderTitleLineHeight() + TGProfileHeaderTitleSubtitleSpacing;
}

CGFloat TGProfileHeaderSubtitleLineHeight(void)
{
    return CGCeil(OGPlatformFontLineHeight(TGProfileHeaderSubtitleFont()));
}

CGFloat TGProfileHeaderAccessoryTop(void)
{
    return TGProfileHeaderSubtitleTop() + TGProfileHeaderSubtitleLineHeight() + TGProfileHeaderAccessorySpacing;
}

CGFloat TGProfileHeaderHeight(CGFloat accessoryHeight)
{
    if (accessoryHeight > FLT_EPSILON)
        return TGProfileHeaderAccessoryTop() + accessoryHeight + TGProfileHeaderAccessoryBottomInset;
    return TGProfileHeaderSubtitleTop() + TGProfileHeaderSubtitleLineHeight() + TGProfileHeaderBottomInset;
}
