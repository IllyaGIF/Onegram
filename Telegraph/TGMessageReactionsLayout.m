#import "TGMessageReactionsLayout.h"

@interface TGMessageReactionsLayout ()
{
    NSArray *_frames;
}

@end

@implementation TGMessageReactionsLayout

+ (instancetype)layoutWithItemSizes:(NSArray *)itemSizes maximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight itemSpacing:(CGFloat)itemSpacing lineSpacing:(CGFloat)lineSpacing trailingSpacing:(CGFloat)trailingSpacing
{
    if (itemSizes.count == 0)
        return nil;

    CGFloat availableWidth = MAX(1.0f, maximumWidth);
    bool hasTrailing = trailingWidth > FLT_EPSILON;

    NSMutableArray *lines = [[NSMutableArray alloc] init];
    NSMutableArray *lineWidths = [[NSMutableArray alloc] init];
    NSMutableArray *currentLine = nil;
    CGFloat currentWidth = 0.0f;
    for (NSUInteger index = 0; index < itemSizes.count; index++)
    {
        CGFloat itemWidth = MIN([itemSizes[index] CGSizeValue].width, availableWidth);
        if (currentLine == nil || currentWidth + itemSpacing + itemWidth > availableWidth)
        {
            if (currentLine != nil)
            {
                [lines addObject:currentLine];
                [lineWidths addObject:@(currentWidth)];
            }
            currentLine = [[NSMutableArray alloc] init];
            currentWidth = 0.0f;
        }
        currentWidth += (currentLine.count != 0 ? itemSpacing : 0.0f) + itemWidth;
        [currentLine addObject:@(index)];
    }
    [lines addObject:currentLine];
    [lineWidths addObject:@(currentWidth)];

    CGFloat lastLineWidth = [[lineWidths lastObject] floatValue];
    bool trailingOnLastLine = !hasTrailing || lastLineWidth + trailingSpacing + trailingWidth <= availableWidth;

    NSMutableArray *frames = [[NSMutableArray alloc] initWithCapacity:itemSizes.count];
    for (NSUInteger index = 0; index < itemSizes.count; index++)
        [frames addObject:[NSValue valueWithCGRect:CGRectZero]];

    CGFloat y = 0.0f;
    CGFloat width = 0.0f;
    for (NSUInteger lineIndex = 0; lineIndex < lines.count; lineIndex++)
    {
        NSArray *line = lines[lineIndex];
        bool isLastLine = lineIndex == lines.count - 1;
        CGFloat lineHeight = 0.0f;
        for (NSNumber *itemIndex in line)
            lineHeight = MAX(lineHeight, [itemSizes[[itemIndex unsignedIntegerValue]] CGSizeValue].height);
        if (isLastLine && trailingOnLastLine && hasTrailing)
            lineHeight = MAX(lineHeight, trailingHeight);

        CGFloat x = 0.0f;
        for (NSNumber *itemIndex in line)
        {
            CGSize itemSize = [itemSizes[[itemIndex unsignedIntegerValue]] CGSizeValue];
            itemSize.width = MIN(itemSize.width, availableWidth);
            frames[[itemIndex unsignedIntegerValue]] = [NSValue valueWithCGRect:CGRectMake(x, y + floorf((lineHeight - itemSize.height) / 2.0f), itemSize.width, itemSize.height)];
            x += itemSize.width + itemSpacing;
        }

        CGFloat lineWidth = [lineWidths[lineIndex] floatValue];
        if (isLastLine && trailingOnLastLine && hasTrailing)
            lineWidth += trailingSpacing + trailingWidth;
        width = MAX(width, lineWidth);

        y += lineHeight;
        if (!isLastLine)
            y += lineSpacing;
    }

    if (!trailingOnLastLine)
    {
        y += lineSpacing + trailingHeight;
        width = MAX(width, trailingWidth);
    }

    TGMessageReactionsLayout *layout = [[TGMessageReactionsLayout alloc] init];
    layout->_frames = frames;
    layout->_size = CGSizeMake(ceilf(width), ceilf(y));
    return layout;
}

- (CGRect)frameForItemAtIndex:(NSUInteger)index
{
    if (index >= _frames.count)
        return CGRectZero;
    return [_frames[index] CGRectValue];
}

@end
