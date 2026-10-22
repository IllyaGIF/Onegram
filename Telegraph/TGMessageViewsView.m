#import "TGMessageViewsView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGPresentation.h"
#import "TGModernDateViewModel.h"
#import "TGMessageViewModel.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

@interface TGMessageViewsView () {
    TGMessageViewsViewType _type;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

static CTLineRef TGMessageViewsViewCreateLine(NSString *text)
{
    NSDictionary *attributes = @{(__bridge id)kCTFontAttributeName: (__bridge id)[TGModernDateViewModel dateFont], (__bridge id)kCTForegroundColorFromContextAttributeName: (__bridge id)kCFBooleanTrue};
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    return OGPlatformTextCreateLine((__bridge CFAttributedStringRef)string);
}

static CGSize TGMessageViewsIconSize(UIImage *image)
{
    if (image == nil || image.size.width <= FLT_EPSILON)
        return CGSizeZero;
    if ([TGPresentation brandedIOS6Style])
        return image.size;
    CGFloat width = TGMessageFontMetric(15.0f);
    return CGSizeMake(width, TGRetinaFloor(image.size.height * width / image.size.width));
}

typedef struct {
    CGFloat baselineOffset;
    CGFloat height;
} TGMessageViewsVerticalMetrics;

static TGMessageViewsVerticalMetrics TGMessageViewsViewVerticalMetrics(UIImage *image)
{
    CTFontRef font = [TGModernDateViewModel dateFont];
    CGFloat halfLeading = CTFontGetLeading(font) / 2.0f;
    CGFloat iconHeight = TGMessageViewsIconSize(image).height;
    CGFloat capHeight = CTFontGetCapHeight(font);
    CGFloat ascent = CGCeil(MAX(CTFontGetAscent(font) + halfLeading, (capHeight + iconHeight) / 2.0f));
    CGFloat descent = CGCeil(MAX(CTFontGetDescent(font) + halfLeading, (iconHeight - capHeight) / 2.0f));
    return (TGMessageViewsVerticalMetrics){ascent, ascent + descent};
}

static void TGMessageViewsViewDraw(CGContextRef context, CGRect frame, NSString *text, UIColor *color, UIImage *image, CGFloat iconSlotWidth)
{
    CTLineRef line = TGMessageViewsViewCreateLine(text);
    if (line == NULL)
        return;

    CGFloat textWidth = CGCeil((CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL));
    CGFloat textX = CGRectGetMaxX(frame) - textWidth;
    CGFloat baselineY = CGRectGetMinY(frame) + TGMessageViewsViewVerticalMetrics(image).baselineOffset;

    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetTextMatrix(context, CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f));
    CGContextSetTextPosition(context, textX, baselineY);
    CTLineDraw(line, context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CFRelease(line);

    if (image != nil)
    {
        CGSize iconSize = TGMessageViewsIconSize(image);
        CGFloat capHeight = CTFontGetCapHeight([TGModernDateViewModel dateFont]);
        CGFloat iconY = TGRetinaFloor(baselineY - (capHeight + iconSize.height) / 2.0f);
        [image drawInRect:CGRectMake(textX - iconSlotWidth, iconY, iconSize.width, iconSize.height)];
    }
}

static void TGMessageViewsViewDrawOperation(CGContextRef context, TGModernDrawingOperation *operation)
{
    TGMessageViewsViewDraw(context, operation.rect, operation.object, operation.color, operation.secondaryObject, operation.value);
}

@implementation TGMessageViewsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)willBecomeRecycled {
}

+ (UIImage *)iconImageForType:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    switch (type) {
        case TGMessageViewsViewTypeIncoming:
            return presentation.images.chatIncomingMessageViewsIcon;
        case TGMessageViewsViewTypeOutgoing:
            return presentation.images.chatOutgoingMessageViewsIcon;
        case TGMessageViewsViewTypeMedia:
            return presentation.images.chatMediaMessageViewsIcon;
    }
}

+ (UIColor *)textColorForType:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    switch (type) {
        case TGMessageViewsViewTypeIncoming:
            return presentation.pallete.chatIncomingDateColor;
        case TGMessageViewsViewTypeOutgoing:
            return presentation.pallete.chatOutgoingDateColor;
        case TGMessageViewsViewTypeMedia:
            return [UIColor whiteColor];
    }
}

+ (CGFloat)iconSlotWidthForImage:(UIImage *)image {
    if (image == nil)
        return 0.0f;
    if ([TGPresentation brandedIOS6Style])
        return CGCeil(image.size.width) + [TGPresentation brandedIOS6ConversationAppearance].viewsIconSpacing;
    return CGCeil(TGMessageViewsIconSize(image).width) + TGMessageFontMetric(3.0f);
}

+ (NSString *)stringForCount:(int32_t)count {
    int64_t value = MAX(0, (int64_t)count);
    int64_t divider = 0;
    NSString *suffix = nil;
    if (value >= 1000000) {
        divider = 1000000;
        suffix = @"M";
    } else if (value >= 1000) {
        divider = 1000;
        suffix = @"K";
    } else {
        return [[NSString alloc] initWithFormat:@"%lld", value];
    }
    int64_t rounded = value / (divider / 10);
    if (rounded % 10 != 0)
        return [[NSString alloc] initWithFormat:@"%lld.%lld%@", rounded / 10, rounded % 10, suffix];
    return [[NSString alloc] initWithFormat:@"%lld%@", rounded / 10, suffix];
}

+ (CGSize)sizeForCount:(int32_t)count type:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    CTLineRef line = TGMessageViewsViewCreateLine([self stringForCount:MAX(1, count)]);
    if (line == NULL)
        return CGSizeZero;
    UIImage *image = [self iconImageForType:type presentation:presentation];
    CGSize size = CGSizeMake(CGCeil((CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL)), TGMessageViewsViewVerticalMetrics(image).height);
    CFRelease(line);

    size.width += [self iconSlotWidthForImage:image];
    return size;
}

+ (CGFloat)baselineOffsetForType:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    return TGMessageViewsViewVerticalMetrics([self iconImageForType:type presentation:presentation]).baselineOffset;
}

+ (void)drawInContext:(CGContextRef)context frame:(CGRect)frame type:(TGMessageViewsViewType)type count:(int32_t)count presentation:(TGPresentation *)presentation {
    UIImage *image = [self iconImageForType:type presentation:presentation];
    TGMessageViewsViewDraw(context, frame, [self stringForCount:MAX(1, count)], [self textColorForType:type presentation:presentation], image, [self iconSlotWidthForImage:image]);
}

+ (void)recordDrawing:(TGModernDrawingRecording *)recording frame:(CGRect)frame type:(TGMessageViewsViewType)type count:(int32_t)count presentation:(TGPresentation *)presentation {
    UIImage *image = [self iconImageForType:type presentation:presentation];
    [recording addOperationWithFunction:&TGMessageViewsViewDrawOperation rect:frame object:[self stringForCount:MAX(1, count)] secondaryObject:image color:[self textColorForType:type presentation:presentation] size:CGSizeZero value:[self iconSlotWidthForImage:image] flags:0];
}

- (void)setPresentation:(TGPresentation *)presentation {
    _presentation = presentation;
    [self setNeedsDisplay];
}

- (void)setType:(TGMessageViewsViewType)type {
    _type = type;
    [self setNeedsDisplay];
}

- (void)setCount:(int32_t)count {
    _count = count;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect {
    if (_presentation == nil)
        return;
    [TGMessageViewsView drawInContext:UIGraphicsGetCurrentContext() frame:self.bounds type:_type count:_count presentation:_presentation];
}

@end
