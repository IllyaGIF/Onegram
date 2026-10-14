#import "TGMessageViewsView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

@interface TGMessageViewsView () {
    TGMessageViewsViewType _type;
    
    UIImageView *_iconView;
    UILabel *_label;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGMessageViewsView

- (void)willBecomeRecycled {
}

+ (UIImage *)iconImageForType:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    switch (type) {
        case TGMessageViewsViewTypeIncoming:
        {
            return presentation.images.chatIncomingMessageViewsIcon;
        }
        case TGMessageViewsViewTypeOutgoing:
        {
            return presentation.images.chatOutgoingMessageViewsIcon;
        }
        case TGMessageViewsViewTypeMedia:
        {
            return presentation.images.chatMediaMessageViewsIcon;
        }
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

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _iconView = [[UIImageView alloc] init];
        [self addSubview:_iconView];
        
        _label = [[UILabel alloc] init];
        _label.font = [TGMessageViewsView labelFont];
        _label.backgroundColor = [UIColor clearColor];
        [self addSubview:_label];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _iconView.image = [TGMessageViewsView iconImageForType:_type presentation:presentation];
    _label.textColor = [TGMessageViewsView textColorForType:_type presentation:presentation];
}

- (void)setType:(TGMessageViewsViewType)type {
    _type = type;
    if (self.presentation != nil)
    {
        _iconView.image = [TGMessageViewsView iconImageForType:type presentation:self.presentation];
        [_iconView sizeToFit];
        _label.textColor = [TGMessageViewsView textColorForType:type presentation:self.presentation];
    }
}

+ (UIFont *)labelFont {
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6ConversationAppearance].timeFont;
    return TGItalicSystemFontOfSize(11.0f);
}

+ (CGFloat)iconSpacing {
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6ConversationAppearance].viewsIconSpacing;
    return 3.0f;
}

+ (CGFloat)labelTopForHeight:(CGFloat)height font:(UIFont *)font {
    if ([TGPresentation brandedIOS6Style])
        return height - font.ascender;
    return 0.0f;
}

+ (CGFloat)iconTopForHeight:(CGFloat)height iconHeight:(CGFloat)iconHeight font:(UIFont *)font {
    if ([TGPresentation brandedIOS6Style])
        return TGRetinaFloor(height - (font.capHeight + iconHeight) / 2.0f);
    return 2.0f;
}

+ (CGSize)sizeForCount:(int32_t)count type:(TGMessageViewsViewType)type presentation:(TGPresentation *)presentation {
    CGSize size = [[self stringForCount:count] sizeWithFont:[self labelFont]];
    size.width = CGCeil(size.width);
    size.height = CGCeil(size.height);
    
    if ([TGPresentation brandedIOS6Style])
    {
        UIImage *image = [self iconImageForType:type presentation:presentation];
        return CGSizeMake(size.width + [self iconSpacing] + CGCeil(image.size.width), size.height);
    }
    
    size.width += ((int)size.width) % 3;
    return CGSizeMake(size.width + 19.0f, size.height);
}

+ (NSString *)stringForCount:(int32_t)count {
    if (count < 1000) {
        return [[NSString alloc] initWithFormat:@"%d", (int)count];
    } else if (count < 1000 * 1000) {
        return [[NSString alloc] initWithFormat:@"%.1fk", (float)count / 1000.0f];
    } else {
        return [[NSString alloc] initWithFormat:@"%.1fm", (float)count / (1000.0f * 1000.0f)];
    }
}

- (void)setCount:(int32_t)count {
    _count = count;
    
    _label.font = [TGMessageViewsView labelFont];
    _label.text = [TGMessageViewsView stringForCount:MAX(1, count)];
    [_label sizeToFit];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGSize size = self.bounds.size;
    CGSize labelSize = _label.bounds.size;
    _label.frame = CGRectMake(size.width - labelSize.width, [TGMessageViewsView labelTopForHeight:size.height font:_label.font], labelSize.width, labelSize.height);
    _iconView.frame = CGRectOffset(_iconView.bounds, _label.frame.origin.x - _iconView.bounds.size.width - [TGMessageViewsView iconSpacing], [TGMessageViewsView iconTopForHeight:size.height iconHeight:_iconView.bounds.size.height font:_label.font]);
}

static void TGMessageViewsViewDrawOperation(CGContextRef context, TGModernDrawingOperation *operation) {
    NSString *text = operation.object;
    NSArray *resources = operation.secondaryObject;
    UIFont *font = resources[0];
    UIImage *image = resources.count > 1 ? resources[1] : nil;
    CGRect frame = operation.rect;
    bool branded = operation.flags != 0;
    
    CGSize labelSize = [text sizeWithFont:font];
    labelSize.width = CGCeil(labelSize.width);
    labelSize.height = CGCeil(labelSize.height);
    
    CGContextSetFillColorWithColor(context, operation.color.CGColor);
    
    CGFloat horizontalOffset = branded ? 0.0f : (1.0f - TGRetinaPixel);
    CGFloat labelX = CGRectGetMaxX(frame) - labelSize.width + horizontalOffset;
    CGFloat labelTop = branded ? frame.size.height - font.ascender : 0.0f;
    CGFloat iconTop = branded ? TGRetinaFloor(frame.size.height - (font.capHeight + image.size.height) / 2.0f) : 2.0f;
    [text drawInRect:CGRectMake(labelX, frame.origin.y + labelTop, labelSize.width, labelSize.height) withFont:font];
    [image drawInRect:CGRectMake(labelX - image.size.width - operation.value, frame.origin.y + iconTop, image.size.width, image.size.height)];
}

+ (void)recordDrawing:(TGModernDrawingRecording *)recording frame:(CGRect)frame type:(TGMessageViewsViewType)type count:(int32_t)count presentation:(TGPresentation *)presentation {
    UIImage *image = [self iconImageForType:type presentation:presentation];
    UIFont *font = [self labelFont];
    NSArray *resources = image != nil ? @[font, image] : @[font];
    [recording addOperationWithFunction:&TGMessageViewsViewDrawOperation rect:frame object:[self stringForCount:MAX(1, count)] secondaryObject:resources color:[self textColorForType:type presentation:presentation] size:CGSizeZero value:[self iconSpacing] flags:[TGPresentation brandedIOS6Style] ? 1 : 0];
}

+ (void)drawInContext:(CGContextRef)context frame:(CGRect)frame type:(TGMessageViewsViewType)type count:(int32_t)count presentation:(TGPresentation *)presentation {
    UIImage *image = [self iconImageForType:type presentation:presentation];
    UIFont *font = [self labelFont];
    
    NSString *text = [self stringForCount:MAX(1, count)];
    CGSize labelSize = [text sizeWithFont:font];
    labelSize.width = CGCeil(labelSize.width);
    labelSize.height = CGCeil(labelSize.height);
    
    CGContextSetFillColorWithColor(context, [self textColorForType:type presentation:presentation].CGColor);
    
    CGFloat horizontalOffset = [TGPresentation brandedIOS6Style] ? 0.0f : (1.0f - TGRetinaPixel);
    CGFloat labelX = CGRectGetMaxX(frame) - labelSize.width + horizontalOffset;
    [text drawInRect:CGRectMake(labelX, frame.origin.y + [self labelTopForHeight:frame.size.height font:font], labelSize.width, labelSize.height) withFont:font];
    [image drawInRect:CGRectMake(labelX - image.size.width - [self iconSpacing], frame.origin.y + [self iconTopForHeight:frame.size.height iconHeight:image.size.height font:font], image.size.width, image.size.height)];
}

@end
