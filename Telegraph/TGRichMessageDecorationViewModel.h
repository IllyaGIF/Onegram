#import "TGModernViewModel.h"

@class TGRichMessageTheme;

typedef enum {
    TGRichDecorationQuote = 0,
    TGRichDecorationQuoteIcon,
    TGRichDecorationCodePanel,
    TGRichDecorationCopyIcon,
    TGRichDecorationDivider,
    TGRichDecorationBullet,
    TGRichDecorationCheckbox,
    TGRichDecorationSeparator,
    TGRichDecorationChevron,
    TGRichDecorationDetailsHeader,
    TGRichDecorationTableCell,
    TGRichDecorationTableBorder,
    TGRichDecorationTableLine,
    TGRichDecorationMediaFrame,
    TGRichDecorationMediaSpoiler,
    TGRichDecorationAudioButton,
    TGRichDecorationFileIcon,
    TGRichDecorationButton,
    TGRichDecorationMath,
    TGRichDecorationPullquote,
    TGRichDecorationCard
} TGRichDecorationKind;

typedef enum {
    TGRichDecorationFlagChecked = 1 << 0,
    TGRichDecorationFlagExpanded = 1 << 1,
    TGRichDecorationFlagHeader = 1 << 2,
    TGRichDecorationFlagStripe = 1 << 3,
    TGRichDecorationFlagVertical = 1 << 4
} TGRichDecorationFlags;

@interface TGRichDecoration : NSObject

@property (nonatomic, readonly) TGRichDecorationKind kind;
@property (nonatomic) CGRect rect;
@property (nonatomic) CGFloat value;
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) id object;
@property (nonatomic) CGRect clipRect;

+ (instancetype)decorationWithKind:(TGRichDecorationKind)kind rect:(CGRect)rect;

@end

@interface TGRichMessageDecorationViewModel : TGModernViewModel

@property (nonatomic, strong) NSArray *decorations;

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme;

@end
