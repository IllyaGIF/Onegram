#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"

@class TGModernViewContext;

typedef enum {
    TGRichMessageColorPrimary = 0,
    TGRichMessageColorSecondary,
    TGRichMessageColorAccent,
    TGRichMessageColorRemoved,
    TGRichMessageColorAdded,
    TGRichMessageColorInverted
} TGRichMessageColorKind;

@interface TGRichMessageTheme : NSObject

@property (nonatomic, readonly) bool branded;
@property (nonatomic, readonly) bool incoming;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, strong, readonly) UIFont *baseFont;
@property (nonatomic, strong, readonly) UIColor *textColor;
@property (nonatomic, strong, readonly) UIColor *secondaryColor;
@property (nonatomic, strong, readonly) UIColor *accentColor;
@property (nonatomic, strong, readonly) UIColor *linkColor;
@property (nonatomic, strong, readonly) UIColor *lineColor;
@property (nonatomic, strong, readonly) UIColor *shadowColor;
@property (nonatomic, readonly) CGSize shadowOffset;

- (instancetype)initWithContext:(TGModernViewContext *)context incoming:(bool)incoming;

- (UIColor *)colorForKind:(TGRichMessageColorKind)kind;
- (UIColor *)markedColor;
- (UIColor *)addedColor;
- (UIColor *)inlineCodeColor;
- (UIColor *)inlineCodeBorderColor;

- (UIFont *)fontWithSize:(CGFloat)size bold:(bool)bold italic:(bool)italic mono:(bool)mono;
- (CTFontRef)coreTextFontWithSize:(CGFloat)size bold:(bool)bold italic:(bool)italic mono:(bool)mono;

@end
