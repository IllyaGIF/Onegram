#import "TGMessageGroupedLayout.h"

#import "TGImageMessageViewModel.h"
#import "TGPresentation.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessageViewCountContentProperty.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"

@interface TGMessagePhotoInfo : NSObject

@property (nonatomic, readonly) int32_t mid;
@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, readonly) CGFloat aspectRatio;
@property (nonatomic, readonly) bool document;

@property (nonatomic, assign) CGRect layoutFrame;
@property (nonatomic, assign) TGMessageGroupPositionFlags positionFlags;

- (instancetype)initWithMessage:(TGMessage *)message;

@end

@interface TGMessageGroupedLayoutAttempt : NSObject

@property (nonatomic, readonly) NSArray *rowCounts;
@property (nonatomic, readonly) NSArray *rowHeights;

- (instancetype)initWithRowCounts:(NSArray *)rowCounts rowHeights:(NSArray *)rowHeights;

@end

@interface TGMessageGroupedLayout ()
{
    NSMutableDictionary *_infoByMessageId;
    int32_t _leadMessageId;
    NSString *_groupCaption;
    NSArray *_groupCaptionLinks;
    int32_t _groupCaptionOwnerId;
    NSString *_groupReactionText;
    NSString *_groupChosenReaction;
    TGMessageDiscussionContentProperty *_discussion;
    int32_t _discussionMessageId;
}

- (void)og_compat_adoptCaptionOfMessage:(TGMessage *)message;

@end

static NSString *OGCompatReactionSummaryText(id value)
{
    if ([value isKindOfClass:[NSString class]])
        return value;
    return [value isKindOfClass:[TGMessageReactionSummaryContentProperty class]] ? [(TGMessageReactionSummaryContentProperty *)value summary] : nil;
}

static TGMessageDiscussionContentProperty *TGMessageGroupedLayoutDiscussion(TGMessage *message)
{
    id property = message.contentProperties[@"ios6Discussion"];
    if ([property isKindOfClass:[TGMessageDiscussionContentProperty class]] && ((TGMessageDiscussionContentProperty *)property).comments)
        return property;
    return nil;
}

@implementation TGMessageGroupedLayout

@synthesize mainMessageId = _leadMessageId;
@synthesize caption = _groupCaption;
@synthesize captionTextCheckingResults = _groupCaptionLinks;
@synthesize captionMessageId = _groupCaptionOwnerId;
@synthesize reactionSummary = _groupReactionText;
@synthesize chosenReaction = _groupChosenReaction;

- (instancetype)initWithMessages:(NSArray *)messages larger:(bool)larger
{
    self = [super init];
    if (self != nil)
    {
        CGSize maxSize;
        [TGImageMessageViewModel calculateImageSizesForImageSize:CGSizeMake(720.0f, 660.0f) thumbnailSize:NULL renderSize:&maxSize squareAspect:false larger:larger];
        const CGFloat spacing = [TGPresentation classicThemeStyle] ? 0.0f : 1.0f;
        
        NSString *proportions = @"";
        CGFloat averageAspectRatio = 0.0f;
        bool forceCalc = false;
        NSMutableArray *photoInfos = [NSMutableArray array];
        CGFloat (^ratioOf)(NSUInteger) = ^CGFloat(NSUInteger index)
        {
            return ((TGMessagePhotoInfo *)[photoInfos objectAtIndex:index]).aspectRatio;
        };
        void (^placePhoto)(NSUInteger, CGRect, TGMessageGroupPositionFlags) = ^(NSUInteger index, CGRect frame, TGMessageGroupPositionFlags flags)
        {
            TGMessagePhotoInfo *target = [photoInfos objectAtIndex:index];
            target.layoutFrame = frame;
            target.positionFlags = flags;
        };
        for (TGMessage *message in messages)
        {
            if (message.caption.length != 0 && _groupCaption.length == 0)
                [self og_compat_adoptCaptionOfMessage:message];

            TGMessagePhotoInfo *photo = [[TGMessagePhotoInfo alloc] initWithMessage:message];
            if (photo != nil)
            {
                [photoInfos addObject:photo];
                
                CGFloat aspectRatio = photo.aspectRatio;
                if (aspectRatio > 1.2f)
                    proportions = [proportions stringByAppendingString:@"w"];
                else if (aspectRatio < 0.8f)
                    proportions = [proportions stringByAppendingString:@"n"];
                else
                    proportions = [proportions stringByAppendingString:@"q"];
                
                averageAspectRatio += photo.aspectRatio;
                
                if (photo.aspectRatio > 2.0f)
                    forceCalc = true;
            }
        }
        
        if (photoInfos.count < 2)
            return nil;

        const CGFloat minWidth = 68.0f;
        CGFloat maxAspectRatio = maxSize.width / maxSize.height;
        if (photoInfos.count > 0)
            averageAspectRatio = averageAspectRatio / photoInfos.count;
        bool documentGroup = photoInfos.count == messages.count && photoInfos.count > 1;
        for (TGMessagePhotoInfo *info in photoInfos)
            documentGroup = documentGroup && info.document;
        bool containsDocument = false;
        for (TGMessagePhotoInfo *info in photoInfos)
            containsDocument = containsDocument || info.document;
        if (containsDocument && !documentGroup)
            return nil;
        _documentGroup = documentGroup;

        if (documentGroup)
        {
            CGFloat y = 0.0f;
            for (NSUInteger index = 0; index < photoInfos.count; index++)
            {
                TGMessagePhotoInfo *info = photoInfos[index];
                info.layoutFrame = CGRectMake(0.0f, y, maxSize.width, info.imageSize.height);
                info.positionFlags = TGMessageGroupPositionLeft | TGMessageGroupPositionRight;
                if (index == 0)
                    info.positionFlags |= TGMessageGroupPositionTop;
                if (index + 1 == photoInfos.count)
                    info.positionFlags |= TGMessageGroupPositionBottom;
                y += info.imageSize.height;
            }
            _statusMessage = messages.lastObject;
        }
        
        if (!documentGroup && !forceCalc)
        {
            if (photoInfos.count == 2)
            {
                if ([proportions isEqualToString:@"ww"] && averageAspectRatio > 1.4 * maxAspectRatio && ratioOf(1) - ratioOf(0) < 0.2)
                {
                    CGFloat width = maxSize.width;
                    CGFloat height = TGScreenPixelFloor(MIN(width / ratioOf(0), MIN(width / ratioOf(1), (maxSize.height - spacing) / 2.0f)));
                    
                    placePhoto(0, CGRectMake(0.0f, 0.0f, width, height), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionRight);
                    
                    placePhoto(1, CGRectMake(0.0f, height + spacing, width, height), TGMessageGroupPositionBottom | TGMessageGroupPositionLeft | TGMessageGroupPositionRight);
                }
                else if ([proportions isEqualToString:@"ww"] || [proportions isEqualToString:@"qq"])
                {
                    CGFloat width = (maxSize.width - spacing) / 2.0f;
                    CGFloat height = TGScreenPixelFloor(MIN(width / ratioOf(0), MIN(width / ratioOf(1), maxSize.height)));
                    
                    placePhoto(0, CGRectMake(0.0f, 0.0f, width, height), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    placePhoto(1, CGRectMake(width + spacing, 0.0f, width, height), TGMessageGroupPositionTop | TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
                else
                {
                    CGFloat minimalWidth = TGScreenPixelFloor(minWidth * 1.5f);
                    CGFloat secondWidth = TGScreenPixelFloor(MAX(0.4 * (maxSize.width - spacing), round((maxSize.width - spacing) / ratioOf(0) / (1.0f / ratioOf(0) + 1.0f / ratioOf(1)))));
                    CGFloat firstWidth = maxSize.width - secondWidth - spacing;
                    if (firstWidth < minimalWidth)
                    {
                        CGFloat diff = minimalWidth - firstWidth;
                        firstWidth = minimalWidth;
                        secondWidth -= diff;
                    }
                    
                    CGFloat height = TGScreenPixelFloor(MIN(maxSize.height, round(MIN(firstWidth / ratioOf(0), secondWidth / ratioOf(1)))));
                    
                    placePhoto(0, CGRectMake(0.0f, 0.0f, firstWidth, height), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    placePhoto(1, CGRectMake(firstWidth + spacing, 0.0f, secondWidth, height), TGMessageGroupPositionTop | TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
            }
            else if (photoInfos.count == 3)
            {
                if ([proportions hasPrefix:@"n"])
                {
                    CGFloat firstHeight = maxSize.height;
                    
                    CGFloat thirdHeight = MIN((maxSize.height - spacing) * 0.5f, round(ratioOf(1) * (maxSize.width - spacing) / (ratioOf(2) + ratioOf(1))));
                    CGFloat secondHeight = maxSize.height - thirdHeight - spacing;
                    CGFloat rightWidth = MAX(minWidth, MIN((maxSize.width - spacing) * 0.5f, round(MIN(thirdHeight * ratioOf(2), secondHeight * ratioOf(1)))));
                    
                    CGFloat leftWidth = round(MIN(firstHeight * ratioOf(0), (maxSize.width - spacing - rightWidth)));
                    placePhoto(0, CGRectMake(0.0f, 0.0f, leftWidth, firstHeight), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    placePhoto(1, CGRectMake(leftWidth + spacing, 0.0f, rightWidth, secondHeight), TGMessageGroupPositionRight | TGMessageGroupPositionTop);
                    
                    placePhoto(2, CGRectMake(leftWidth + spacing, secondHeight + spacing, rightWidth, thirdHeight), TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
                else
                {
                    CGFloat width = maxSize.width;
                    CGFloat firstHeight = TGScreenPixelFloor(MIN(width / ratioOf(0), (maxSize.height - spacing) * 0.66f));
                    placePhoto(0, CGRectMake(0.0f, 0.0f, width, firstHeight), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionRight);
                    
                    width = (maxSize.width - spacing) / 2.0f;
                    CGFloat secondHeight = MIN(maxSize.height - firstHeight - spacing, round(MIN(width / ratioOf(1), width / ratioOf(2))));
                    placePhoto(1, CGRectMake(0.0f, firstHeight + spacing, width, secondHeight), TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    placePhoto(2, CGRectMake(width + spacing, firstHeight + spacing, width, secondHeight), TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
            }
            else if (photoInfos.count == 4)
            {
                if ([proportions isEqualToString:@"wwww"] || [proportions hasPrefix:@"w"])
                {
                    CGFloat w = maxSize.width;
                    CGFloat h0 = round(MIN(w / ratioOf(0), (maxSize.height - spacing) * 0.66f));
                    placePhoto(0, CGRectMake(0.0f, 0.0f, w, h0), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionRight);
                    
                    CGFloat h = round((maxSize.width - 2 * spacing) / (ratioOf(1) + ratioOf(2) + ratioOf(3)));
                    CGFloat w0 = MAX(minWidth, MIN((maxSize.width - 2 * spacing) * 0.4f, h * ratioOf(1)));
                    CGFloat w2 = MAX(MAX(minWidth, (maxSize.width - 2 * spacing) * 0.33f), h * ratioOf(3));
                    CGFloat w1 = w - w0 - w2 - 2 * spacing;
                    h = MIN(maxSize.height - h0 - spacing, h);
                    placePhoto(1, CGRectMake(0.0f, h0 + spacing, w0, h), TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    placePhoto(2, CGRectMake(w0 + spacing, h0 + spacing, w1, h), TGMessageGroupPositionBottom);
                    
                    placePhoto(3, CGRectMake(w0 + w1 + 2 * spacing, h0 + spacing, w2, h), TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
                else
                {
                    CGFloat h = maxSize.height;
                    CGFloat w0 = round(MIN(h * ratioOf(0), (maxSize.width - spacing) * 0.6f));
                    placePhoto(0, CGRectMake(0.0f, 0.0f, w0, h), TGMessageGroupPositionTop | TGMessageGroupPositionLeft | TGMessageGroupPositionBottom);
                    
                    CGFloat w = round((maxSize.height - 2 * spacing) / (1.0f / ratioOf(1) + 1.0f /  ratioOf(2) + 1.0f / ratioOf(3)));
                    CGFloat h0 = TGScreenPixelFloor(w / ratioOf(1));
                    CGFloat h1 = TGScreenPixelFloor(w / ratioOf(2));
                    CGFloat h2 = h - h0 - h1 - 2 * spacing;
                    w = MAX(minWidth, MIN(maxSize.width - w0 - spacing, w));
                    placePhoto(1, CGRectMake(w0 + spacing, 0.0f, w, h0), TGMessageGroupPositionRight | TGMessageGroupPositionTop);
                    
                    placePhoto(2, CGRectMake(w0 + spacing, h0 + spacing, w, h1), TGMessageGroupPositionRight);
                    
                    placePhoto(3, CGRectMake(w0 + spacing, h0 + h1 + 2 * spacing, w, h2), TGMessageGroupPositionRight | TGMessageGroupPositionBottom);
                }
            }
        }
        
        if (!documentGroup && (forceCalc || photoInfos.count >= 5))
        {
            NSMutableArray *clampedRatios = [NSMutableArray array];
            for (TGMessagePhotoInfo *photo in photoInfos)
            {
                CGFloat aspectRatio = photo.aspectRatio;
                CGFloat croppedRatio = aspectRatio;
                if (averageAspectRatio > 1.1f)
                    croppedRatio = MAX(1.0f, aspectRatio);
                else
                    croppedRatio = MIN(1.0f, aspectRatio);
                
                croppedRatio = MAX(0.66667f, MIN(2.75f, croppedRatio));
                [clampedRatios addObject:@(croppedRatio)];
            }
            
            NSNumber *(^multiHeight)(NSArray *) = ^NSNumber *(NSArray *ratios)
            {
                CGFloat ratioSum = 0.0f;
                for (NSNumber *ratio in ratios)
                    ratioSum += ratio.floatValue;
                if (ratioSum < FLT_EPSILON)
                    ratioSum = 1.0f;
                return @((maxSize.width - (ratios.count - 1) * spacing) / ratioSum);
            };
 
            NSMutableArray *attempts = [[NSMutableArray alloc] init];
            void (^addAttempt)(NSArray *, NSArray *) = ^(NSArray *rowCounts, NSArray *rowHeights)
            {
                [attempts addObject:[[TGMessageGroupedLayoutAttempt alloc] initWithRowCounts:rowCounts rowHeights:rowHeights]];
            };
            
            NSUInteger firstLine = 0;
            NSUInteger secondLine = 0;
            NSUInteger thirdLine = 0;
            NSUInteger fourthLine = 0;
            
            for (firstLine = 1; firstLine < clampedRatios.count; firstLine++)
            {
                secondLine = clampedRatios.count - firstLine;
                if (firstLine > 3 || secondLine > 3)
                    continue;

                addAttempt(@[@(firstLine), @(clampedRatios.count - firstLine)], @[multiHeight([clampedRatios subarrayWithRange:NSMakeRange(0, firstLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine, clampedRatios.count - firstLine)])]);
            }

            for (firstLine = 1; firstLine < clampedRatios.count - 1; firstLine++)
            {
                for (secondLine = 1; secondLine < clampedRatios.count - firstLine; secondLine++)
                {
                    thirdLine = clampedRatios.count - firstLine - secondLine;
                    if (firstLine > 3 || secondLine > (averageAspectRatio < 0.85f ? 4 : 3) || thirdLine > 3)
                        continue;
                    
                    addAttempt(@[@(firstLine), @(secondLine), @(thirdLine)], @[multiHeight([clampedRatios subarrayWithRange:NSMakeRange(0, firstLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine, clampedRatios.count - firstLine - thirdLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine + secondLine, clampedRatios.count - firstLine - secondLine)])]);
                }
            }
            
            for (firstLine = 1; firstLine < clampedRatios.count - 2; firstLine++)
            {
                for (secondLine = 1; secondLine < clampedRatios.count - firstLine; secondLine++)
                {
                    for (thirdLine = 1; thirdLine < clampedRatios.count - firstLine - secondLine; thirdLine++)
                    {
                        fourthLine = clampedRatios.count - firstLine - secondLine - thirdLine;
                        if (firstLine > 3 || secondLine > 3 || thirdLine > 3 || fourthLine > 3)
                            continue;
                        
                        addAttempt(@[@(firstLine), @(secondLine), @(thirdLine), @(fourthLine)], @[multiHeight([clampedRatios subarrayWithRange:NSMakeRange(0, firstLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine, clampedRatios.count - firstLine - thirdLine - fourthLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine + secondLine, clampedRatios.count - firstLine - secondLine - fourthLine)]), multiHeight([clampedRatios subarrayWithRange:NSMakeRange(firstLine + secondLine + thirdLine, clampedRatios.count - firstLine - secondLine - thirdLine)])]);
                    }
                }
            }

            CGFloat maxHeight = maxSize.width / 3 * 4;
            TGMessageGroupedLayoutAttempt *optimal = nil;
            CGFloat optimalDiff = 0.0f;
            for (TGMessageGroupedLayoutAttempt *attempt in attempts)
            {
                CGFloat totalHeight = spacing * (attempt.rowHeights.count - 1);
                CGFloat minLineHeight = FLT_MAX;
                CGFloat maxLineHeight = 0.0f;
                for (NSNumber *h in attempt.rowHeights)
                {
                    CGFloat lineHeight = h.floatValue;
                    totalHeight += lineHeight;
                    if (lineHeight < minLineHeight)
                        minLineHeight = lineHeight;
                    if (lineHeight > maxLineHeight)
                        maxLineHeight = lineHeight;
                }
                
                CGFloat diff = fabs(totalHeight - maxHeight);
                
                NSArray *rowCounts = attempt.rowCounts;
                for (NSUInteger pairIndex = 0; pairIndex < 3 && pairIndex + 1 < rowCounts.count; pairIndex++)
                {
                    if ([[rowCounts objectAtIndex:pairIndex] integerValue] > [[rowCounts objectAtIndex:pairIndex + 1] integerValue])
                    {
                        diff *= 1.5f;
                        break;
                    }
                }
                
                if (minLineHeight < minWidth)
                    diff *= 1.5f;
                
                if (optimal == nil || diff < optimalDiff)
                {
                    optimal = attempt;
                    optimalDiff = diff;
                }
            }
            
            NSInteger index = 0;
            CGFloat y = 0.0f;
            for (NSUInteger i = 0; i < optimal.rowCounts.count; i++)
            {
                CGFloat lineHeight = [[optimal.rowHeights objectAtIndex:i] floatValue];
                NSInteger count = [[optimal.rowCounts objectAtIndex:i] integerValue];
                CGFloat x = 0.0f;
                
                TGMessageGroupPositionFlags positionFlags = TGMessageGroupPositionNone;
                if (i == 0)
                    positionFlags |= TGMessageGroupPositionTop;
                if (i == optimal.rowCounts.count - 1)
                    positionFlags |= TGMessageGroupPositionBottom;
                
                for (NSInteger k = 0; k < count; k++)
                {
                    TGMessageGroupPositionFlags innerPositionFlags = positionFlags;
                    
                    if (k == 0)
                        innerPositionFlags |= TGMessageGroupPositionLeft;
                    if (k == count - 1)
                        innerPositionFlags |= TGMessageGroupPositionRight;
                    
                    if (positionFlags == TGMessageGroupPositionNone)
                        innerPositionFlags = TGMessageGroupPositionInside;
                    
                    CGFloat ratio = [[clampedRatios objectAtIndex:index] floatValue];
                    CGFloat width = ratio * lineHeight;
                    placePhoto(index, CGRectMake(x, y, width, lineHeight), innerPositionFlags);
                    
                    x += width + spacing;
                    index++;
                }
                
                y += lineHeight + spacing;
            }
        }
        
        CGSize dimensions = CGSizeZero;
        _infoByMessageId = [[NSMutableDictionary alloc] init];
        for (TGMessagePhotoInfo *photo in photoInfos)
        {
            _infoByMessageId[@(photo.mid)] = photo;

            TGMessageGroupPositionFlags photoFlags = photo.positionFlags;
            if ((photoFlags & TGMessageGroupPositionLeft) && (photoFlags & TGMessageGroupPositionTop))
                _leadMessageId = photo.mid;
            
            if (CGRectGetMaxX(photo.layoutFrame) > dimensions.width)
                dimensions.width = CGRectGetMaxX(photo.layoutFrame);
            if (CGRectGetMaxY(photo.layoutFrame) > dimensions.height)
                dimensions.height = CGRectGetMaxY(photo.layoutFrame);
        }
        _dimensions = dimensions;

        TGMessage *reactionSource = nil;
        for (TGMessage *message in messages)
        {
            bool carriesSummary = OGCompatReactionSummaryText([message.contentProperties objectForKey:@"ios6ReactionSummary"]).length != 0;
            bool isLead = message.mid == _leadMessageId;

            if (carriesSummary && (isLead || reactionSource == nil))
                reactionSource = message;
            if (carriesSummary && isLead)
                break;
        }

        id summaryProperty = [reactionSource.contentProperties objectForKey:@"ios6ReactionSummary"];
        if ([summaryProperty isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
            _groupChosenReaction = [((TGMessageReactionSummaryContentProperty *)summaryProperty).chosenReaction copy];
        _groupReactionText = [OGCompatReactionSummaryText(summaryProperty) copy];

        for (TGMessage *message in messages)
        {
            TGMessageDiscussionContentProperty *discussion = TGMessageGroupedLayoutDiscussion(message);
            if (discussion == nil)
                continue;
            if (_discussion == nil || message.mid == _leadMessageId)
            {
                _discussion = discussion;
                _discussionMessageId = message.mid;
            }
            if (message.mid == _leadMessageId)
                break;
        }
    }
    return self;
}

- (NSUInteger)count
{
    return _infoByMessageId.count;
}

- (void)updateDocumentMessage:(TGMessage *)message
{
    if (!_documentGroup || _infoByMessageId[@(message.mid)] == nil)
        return;
    if (message.mid == _groupCaptionOwnerId || message.caption.length != 0)
        [self og_compat_adoptCaptionOfMessage:message];
    if (message.mid == _statusMessage.mid)
        _statusMessage = message;
    id reaction = message.contentProperties[@"ios6ReactionSummary"];
    if (message.mid == _leadMessageId || _groupReactionText.length == 0) {
        if ([reaction isKindOfClass:[TGMessageReactionSummaryContentProperty class]]) {
            _groupReactionText = [((TGMessageReactionSummaryContentProperty *)reaction).summary copy];
            _groupChosenReaction = [((TGMessageReactionSummaryContentProperty *)reaction).chosenReaction copy];
        } else if ([reaction isKindOfClass:[NSString class]]) {
            _groupReactionText = [reaction copy];
        } else if (message.mid == _leadMessageId) {
            _groupReactionText = nil;
            _groupChosenReaction = nil;
        }
    }
    [self updateDiscussion:TGMessageGroupedLayoutDiscussion(message) messageId:message.mid];
}

- (void)setMediaOrigin:(CGPoint)mediaOrigin
{
    _mediaOrigin = mediaOrigin;
    _hasMediaOrigin = true;
}

- (CGRect)frameForMessageId:(int32_t)messageId
{
    TGMessagePhotoInfo *info = _infoByMessageId[@(messageId)];
    if (info != nil)
        return info.layoutFrame;
    
    return CGRectNull;
}

- (TGMessageGroupPositionFlags)positionForMessageId:(int32_t)messageId
{
    TGMessagePhotoInfo *info = _infoByMessageId[@(messageId)];
    if (info != nil)
        return info.positionFlags;
    
    return 0;
}

- (int32_t)messageIdForPosition:(TGMessageGroupPositionFlags)position
{
    for (TGMessagePhotoInfo *info in [_infoByMessageId allValues])
    {
        if (info.positionFlags == position)
            return info.mid;
    }
    return 0;
}

- (void)enumerateMessageFrames:(void (^)(int32_t, CGRect))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    for (TGMessagePhotoInfo *info in [_infoByMessageId allValues])
    {
        enumerationBlock(info.mid, info.layoutFrame);
    }
}

- (TGMessageGroupedLayout *)groupedLayoutAfterMessageUpdate:(TGMessage *)message previousMessage:(TGMessage *)previousMessage
{
    TGMessageGroupedLayout *groupedLayout = [[TGMessageGroupedLayout alloc] init];
    NSMutableDictionary *newLayouts = [_infoByMessageId mutableCopy];
    groupedLayout->_infoByMessageId = newLayouts;
    groupedLayout->_dimensions = _dimensions;
    groupedLayout->_documentGroup = _documentGroup;
    groupedLayout->_documentContentWidth = _documentContentWidth;
    groupedLayout->_statusMessage = _statusMessage.mid == previousMessage.mid ? message : _statusMessage;
    groupedLayout->_leadMessageId = _leadMessageId;
    groupedLayout->_groupCaption = [_groupCaption copy];
    groupedLayout->_groupCaptionLinks = [_groupCaptionLinks copy];
    groupedLayout->_groupCaptionOwnerId = _groupCaptionOwnerId;
    groupedLayout->_groupReactionText = [_groupReactionText copy];
    groupedLayout->_groupChosenReaction = [_groupChosenReaction copy];
    groupedLayout->_discussion = _discussion;
    groupedLayout->_discussionMessageId = _discussionMessageId;
    groupedLayout->_headerVisible = _headerVisible;
    groupedLayout->_topCornersHidden = _topCornersHidden;
    
    TGMessagePhotoInfo *info = newLayouts[@(previousMessage.mid)];
    if (info != nil)
    {
        newLayouts[@(message.mid)] = info;
        [newLayouts removeObjectForKey:@(previousMessage.mid)];
        if (groupedLayout->_leadMessageId == previousMessage.mid)
            groupedLayout->_leadMessageId = message.mid;
        if (groupedLayout->_discussionMessageId == previousMessage.mid)
            groupedLayout->_discussionMessageId = message.mid;
    }
    [groupedLayout updateDiscussion:TGMessageGroupedLayoutDiscussion(message) messageId:message.mid];

    if (message.caption.length != 0 || previousMessage.mid == _groupCaptionOwnerId)
        [groupedLayout og_compat_adoptCaptionOfMessage:message];

    return groupedLayout;
}

- (void)og_compat_adoptCaptionOfMessage:(TGMessage *)message
{
    _groupCaptionLinks = [message.textCheckingResults copy];
    _groupCaption = [message.caption copy];
    _groupCaptionOwnerId = message.caption.length == 0 ? 0 : message.mid;
}

- (void)updateReactionSummary:(NSString *)reactionSummary chosenReaction:(NSString *)chosenReaction messageId:(int32_t)messageId
{
    if (messageId == _leadMessageId)
    {
        _groupChosenReaction = [chosenReaction copy];
        _groupReactionText = [reactionSummary copy];
    }
}

- (void)updateDiscussion:(TGMessageDiscussionContentProperty *)discussion messageId:(int32_t)messageId
{
    if (discussion == nil || !discussion.comments)
    {
        if (messageId == _discussionMessageId)
        {
            _discussion = nil;
            _discussionMessageId = 0;
        }
        return;
    }

    if (_discussion == nil || messageId == _discussionMessageId || messageId == _leadMessageId)
    {
        _discussion = discussion;
        _discussionMessageId = messageId;
    }
}

@end


@implementation TGMessagePhotoInfo

- (instancetype)initWithMessage:(TGMessage *)message
{
    self = [super init];
    if (self != nil)
    {
        _mid = message.mid;
        
        TGImageMediaAttachment *imageAttachment = nil;
        TGVideoMediaAttachment *videoAttachment = nil;
        TGDocumentMediaAttachment *documentAttachment = nil;
        
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGImageMediaAttachmentType)
            {
                imageAttachment = (TGImageMediaAttachment *)attachment;
                break;
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                videoAttachment = (TGVideoMediaAttachment *)attachment;
                break;
            }
            else if (attachment.type == TGDocumentMediaAttachmentType)
            {
                TGDocumentMediaAttachment *document = (TGDocumentMediaAttachment *)attachment;
                bool specialized = document.isSticker || document.isAnimated || document.isVoice || [document.mimeType isEqualToString:@"image/gif"] || [[[document safeFileName] pathExtension].lowercaseString isEqualToString:@"gif"];
                for (id attribute in document.attributes)
                    specialized = specialized || [attribute isKindOfClass:[TGDocumentAttributeAudio class]] || [attribute isKindOfClass:[TGDocumentAttributeVideo class]];
                if (!specialized)
                    documentAttachment = document;
                break;
            }
        }
        
        if (imageAttachment != nil)
        {
            CGSize dimensions = CGSizeZero;
            [imageAttachment.imageInfo closestImageUrlWithSize:CGSizeMake(1136, 1136) resultingSize:&dimensions pickLargest:true];
            if (dimensions.width <= 90.0f + FLT_EPSILON || dimensions.height <= 90.0f + FLT_EPSILON)
                [imageAttachment.imageInfo imageUrlForSizeLargerThanSize:CGSizeMake(1000.0f, 1000.0f) actualSize:&dimensions];
            
            _imageSize = dimensions;
            _aspectRatio = _imageSize.height > 0 ? _imageSize.width / _imageSize.height : 1.0f;
        }
        else if (videoAttachment != nil)
        {
            _imageSize = videoAttachment.dimensions;
            _aspectRatio = _imageSize.height > 0 ? _imageSize.width / _imageSize.height : 1.0f;
        }
        else if (documentAttachment != nil)
        {
            _document = true;
            bool hasPreview = (documentAttachment.thumbnailInfo != nil && !documentAttachment.thumbnailInfo.empty) || documentAttachment.isImageFile;
            _imageSize = CGSizeMake(74.0f, hasPreview ? 78.0f : 64.0f);
            _aspectRatio = 1.0f;
        }
        else
        {
            return nil;
        }
    }
    return self;
}

@end


@implementation TGMessageGroupedLayoutAttempt

- (instancetype)initWithRowCounts:(NSArray *)rowCounts rowHeights:(NSArray *)rowHeights
{
    self = [super init];
    if (self != nil)
    {
        _rowHeights = rowHeights;
        _rowCounts = rowCounts;
    }
    return self;
}

@end
