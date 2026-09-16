#import "TGModernDateViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <CoreText/CoreText.h>
#import "TGPresentation.h"

@interface TGModernDateViewModel ()
{
}

@end

@implementation TGModernDateViewModel

- (instancetype)initWithText:(NSString *)text textColor:(UIColor *)textColor daytimeVariant:(int)__unused daytimeVariant
{
    static CTFontRef dateFont = NULL;
    static CTFontRef brandedDateFont = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 7) {
            dateFont = TGIos6CreateCTFontFromUIFont(TGItalicSystemFontOfSize(11.0f));
            brandedDateFont = TGIos6CreateCTFontFromUIFont(TGSystemFontOfSize(11.0f));
        } else {
            UIFont *font = TGItalicSystemFontOfSize(11.0f);
            dateFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
            UIFont *brandedFont = TGSystemFontOfSize(11.0f);
            brandedDateFont = CTFontCreateWithName((__bridge CFStringRef)brandedFont.fontName, brandedFont.pointSize, nil);
        }
    });
    
    self = [super initWithText:text textColor:textColor font:[TGPresentation brandedIOS6Style] ? brandedDateFont : dateFont maxWidth:CGFLOAT_MAX];
    if (self != nil)
    {
        self.hasNoView = true;
    }
    return self;
}

- (void)setText:(NSString *)text daytimeVariant:(int)__unused daytimeVariant
{
    [self setText:text maxWidth:CGFLOAT_MAX];
}

@end
