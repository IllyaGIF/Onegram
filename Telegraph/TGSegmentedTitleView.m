#import "TGSegmentedTitleView.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"

#import "TGPresentation.h"

@interface TGSegmentedTitleView ()
{
    TGPresentation *_presentation;
    
    UILabel *_label;
    UISegmentedControl *_segmentedControl;
}
@end

@implementation TGSegmentedTitleView

- (instancetype)initWithTitle:(NSString *)title segments:(NSArray *)segments
{
    self = [super init];
    if (self != nil)
    {
        if (iosMajorVersion() >= 11)
            OGPlatformSetViewTranslatesAutoresizingMaskIntoConstraints(self, false);
        
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = TGBoldSystemFontOfSize(17.0f);
        _label.text = title;
        _label.textAlignment = NSTextAlignmentCenter;
        [_label sizeToFit];
        [self addSubview:_label];

        _segmentedControl = [[UISegmentedControl alloc] initWithItems:segments];
        _segmentedControl.alpha = 0.0f;
        _segmentedControl.userInteractionEnabled = false;
        CGFloat width = 0.0f;
        for (NSString *itemName in segments)
        {
            CGSize size = [itemName sizeWithFont:TGSystemFontOfSize(13)];
            if (size.width > width)
                width = size.width;
        }
        width = (width + 34.0f) * 2.0f;
        
        _segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        
        [_segmentedControl setSelectedSegmentIndex:0];
        [_segmentedControl addTarget:self action:@selector(segmentedControlChanged) forControlEvents:UIControlEventValueChanged];
        
        [self addSubview:_segmentedControl];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    CGRect frame = _segmentedControl.frame;
    if (CGRectContainsPoint(frame, point))
        return _segmentedControl;
    
    return nil;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(_segmentedControl.frame.size.width,1);
}

- (CGFloat)innerWidth
{
    return _segmentedControl.frame.size.width;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    _label.textColor = presentation.pallete.navigationTitleColor;
    
    OGPlatformSetSegmentedControlBackgroundImage(_segmentedControl, _presentation.images.segmentedControlBackgroundImage, UIControlStateNormal, UIBarMetricsDefault);
    OGPlatformSetSegmentedControlBackgroundImage(_segmentedControl, _presentation.images.segmentedControlSelectedImage, UIControlStateSelected, UIBarMetricsDefault);
    OGPlatformSetSegmentedControlBackgroundImage(_segmentedControl, _presentation.images.segmentedControlSelectedImage, UIControlStateSelected | UIControlStateHighlighted, UIBarMetricsDefault);
    OGPlatformSetSegmentedControlBackgroundImage(_segmentedControl, _presentation.images.segmentedControlHighlightedImage, UIControlStateHighlighted, UIBarMetricsDefault);
    OGPlatformSetSegmentedControlDividerImage(_segmentedControl, _presentation.images.segmentedControlDividerImage, UIControlStateNormal, UIControlStateNormal, UIBarMetricsDefault);
    
    OGPlatformSetSegmentedControlTitleTextAttributes(_segmentedControl, @{UITextAttributeTextColor:_presentation.pallete.navigationButtonColor, UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)}, UIControlStateNormal);
    OGPlatformSetSegmentedControlTitleTextAttributes(_segmentedControl, @{UITextAttributeTextColor:_presentation.pallete.accentContrastColor, UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)}, UIControlStateSelected);
}

- (void)segmentedControlChanged
{
    if (self.segmentChanged != nil)
        self.segmentChanged(_segmentedControl.selectedSegmentIndex);
}

- (void)setSegmentedControlHidden:(bool)hidden animated:(bool)animated
{
    _segmentedControl.userInteractionEnabled = !hidden;
    
    void (^changeBlock)(void) = ^
    {
        _segmentedControl.alpha = hidden ? 0.0f : 1.0f;
        _label.alpha = hidden ? 1.0f : 0.0f;
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (hidden)
            _segmentedControl.selectedSegmentIndex = 0;
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:changeBlock completion:completionBlock];
    }
    else
    {
        changeBlock();
        completionBlock(true);
    }
}

- (void)layoutSubviews
{
    _label.frame = CGRectMake(TGScreenPixelFloor((self.frame.size.width - _label.frame.size.width) / 2.0f), TGScreenPixelFloor((self.frame.size.height - _label.frame.size.height) / 2.0f), _label.frame.size.width, _label.frame.size.height);
    _segmentedControl.frame = CGRectMake(TGScreenPixelFloor((self.frame.size.width - _segmentedControl.frame.size.width) / 2.0f), TGScreenPixelFloor((self.frame.size.height - _segmentedControl.frame.size.height) / 2.0f), _segmentedControl.frame.size.width, _segmentedControl.frame.size.height);
}

@end
