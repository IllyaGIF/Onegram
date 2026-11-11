#import "TGCustomEmojiTextAttributes.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGReusableLabel.h"
#import "TGRichMessageInlineImageStore.h"

NSArray *TGCustomEmojiEntities(NSArray *entities)
{
    NSMutableArray *result = nil;
    for (id entity in entities)
    {
        if (![entity isKindOfClass:[TGMessageEntityCustomEmoji class]] || ((TGMessageEntityCustomEmoji *)entity).documentId == 0)
            continue;
        if (result == nil)
            result = [[NSMutableArray alloc] init];
        [result addObject:entity];
    }
    return result;
}

static void TGCustomEmojiAppendAttribute(NSMutableArray *attributes, NSRange range, id value, NSString *name)
{
    if (value == nil || range.length == 0)
        return;
    [attributes addObject:[NSValue valueWithRange:range]];
    [attributes addObject:@[value, name]];
}

NSArray *TGCustomEmojiAdditionalAttributes(NSString *text, NSArray *entities, CTFontRef font, NSMutableSet *imageKeys)
{
    NSArray *customEmojiEntities = TGCustomEmojiEntities(entities);
    if (customEmojiEntities.count == 0 || text.length == 0 || font == NULL)
        return nil;

    CGFloat ascent = (CGFloat)CTFontGetAscent(font);
    CGFloat descent = (CGFloat)CTFontGetDescent(font);
    CGFloat side = CGFloor((ascent + descent) * 0.92f);
    if (side < 1.0f)
        return nil;
    CGSize imageSize = CGSizeMake(side, side);
    id clearColor = (__bridge id)[UIColor clearColor].CGColor;

    NSMutableArray *attributes = [[NSMutableArray alloc] init];
    NSUInteger length = text.length;
    NSUInteger lastEnd = 0;
    for (TGMessageEntityCustomEmoji *entity in customEmojiEntities)
    {
        NSRange range = entity.range;
        if (range.length == 0 || range.location < lastEnd || range.location + range.length > length)
            continue;
        lastEnd = NSMaxRange(range);

        NSRange firstRange = [text rangeOfComposedCharacterSequenceAtIndex:range.location];
        firstRange = NSIntersectionRange(firstRange, range);
        if (firstRange.length == 0)
            continue;

        int64_t documentId = entity.documentId;
        NSString *key = [TGRichMessageInlineImageStore customEmojiKey:documentId];
        [imageKeys addObject:key];
        SSignal *(^generator)(void) = ^SSignal *
        {
            return [TGRichMessageInlineImageStore customEmojiImageSignal:documentId];
        };
        [TGRichMessageInlineImageStore requestImageForKey:key signalGenerator:generator];
        NSString *fallback = [text substringWithRange:range];

        CTRunDelegateRef delegate = TGReusableLabelCreateAttachmentRunDelegate(ascent, descent, side + 2.0f);
        if (delegate != NULL)
            TGCustomEmojiAppendAttribute(attributes, firstRange, (__bridge_transfer id)delegate, (__bridge NSString *)kCTRunDelegateAttributeName);
        TGCustomEmojiAppendAttribute(attributes, range, clearColor, (__bridge NSString *)kCTForegroundColorAttributeName);

        TGReusableLabelRunDecoration *decoration = [[TGReusableLabelRunDecoration alloc] init];
        decoration.drawContent = ^(CGContextRef context, CGRect rect)
        {
            CGRect imageRect = CGRectMake(rect.origin.x + 1.0f, rect.origin.y + ascent - imageSize.height + MIN(descent, imageSize.height * 0.18f), imageSize.width, imageSize.height);
            UIImage *image = [TGRichMessageInlineImageStore imageForKey:key];
            if (image == nil)
            {
                [TGRichMessageInlineImageStore requestImageForKey:key signalGenerator:generator];
                image = TGEmojiCachedImageOfSize(fallback, imageSize.height) ?: TGEmojiImageOfSize(fallback, imageSize.height);
            }
            if (image == nil)
                return;
            UIGraphicsPushContext(context);
            CGSize fitted = TGFitSize(image.size, imageRect.size);
            [image drawInRect:CGRectMake(imageRect.origin.x + (imageRect.size.width - fitted.width) / 2.0f, imageRect.origin.y + (imageRect.size.height - fitted.height) / 2.0f, fitted.width, fitted.height)];
            UIGraphicsPopContext();
        };
        TGCustomEmojiAppendAttribute(attributes, firstRange, decoration, TGReusableLabelRunDecorationAttributeName);

        if (NSMaxRange(firstRange) < NSMaxRange(range))
        {
            NSRange restRange = NSMakeRange(NSMaxRange(firstRange), NSMaxRange(range) - NSMaxRange(firstRange));
            CTRunDelegateRef emptyDelegate = TGReusableLabelCreateAttachmentRunDelegate(ascent, descent, 0.0f);
            if (emptyDelegate != NULL)
                TGCustomEmojiAppendAttribute(attributes, restRange, (__bridge_transfer id)emptyDelegate, (__bridge NSString *)kCTRunDelegateAttributeName);
        }
    }
    return attributes.count == 0 ? nil : attributes;
}
