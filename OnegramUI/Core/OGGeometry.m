#import "OGGeometry.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"

CGFloat OGPixelFloor(CGFloat value)
{
    return OGPlatformPixelFloor(value);
}

CGFloat OGPixelCeil(CGFloat value)
{
    return OGPlatformPixelCeil(value);
}

CGFloat OGPixelRound(CGFloat value)
{
    return OGPlatformPixelRound(value);
}

CGRect OGRectInsetEdges(CGRect rect, UIEdgeInsets insets)
{
    rect.origin.x += insets.left;
    rect.origin.y += insets.top;
    rect.size.width = MAX(0.0f, rect.size.width - insets.left - insets.right);
    rect.size.height = MAX(0.0f, rect.size.height - insets.top - insets.bottom);
    return rect;
}

CGRect OGRectCenterSize(CGRect bounds, CGSize size)
{
    return CGRectMake(OGPixelFloor(CGRectGetMidX(bounds) - size.width * 0.5f), OGPixelFloor(CGRectGetMidY(bounds) - size.height * 0.5f), size.width, size.height);
}

CGFloat OGClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(value, minimum), maximum);
}
