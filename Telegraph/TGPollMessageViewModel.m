#import "TGPollMessageViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"

#import "TGPollMediaAttachment.h"
#import "TGPollSignals.h"
#import "TGRichMessageTheme.h"
#import "TGRichMessageTextBuilder.h"
#import "TGModernViewContext.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernTextViewModel.h"
#import "TGTextMessageBackgroundViewModel.h"
#import "TGReplyHeaderModel.h"
#import "TGTelegraphConversationMessageAssetsSource.h"
#import "TGTelegramNetworking.h"
#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

typedef enum {
    TGPollDecorationRadio = 0,
    TGPollDecorationSeparator,
    TGPollDecorationBar,
    TGPollDecorationBadge
} TGPollDecorationKind;

@interface TGPollDecoration : NSObject

@property (nonatomic) TGPollDecorationKind kind;
@property (nonatomic) CGRect rect;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) bool selected;
@property (nonatomic) bool cross;

@end

@implementation TGPollDecoration

@end

@interface TGPollHitRegion : NSObject

@property (nonatomic) CGRect rect;
@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) id payload;

@end

@implementation TGPollHitRegion

@end

static UIColor *TGPollLighterColor(UIColor *color, CGFloat amount)
{
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f;
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    size_t count = CGColorGetNumberOfComponents(color.CGColor);
    if (components == NULL)
        return color;
    if (count >= 4)
    {
        red = components[0];
        green = components[1];
        blue = components[2];
        alpha = components[3];
    }
    else if (count >= 2)
    {
        red = green = blue = components[0];
        alpha = components[1];
    }
    return [UIColor colorWithRed:red + (1.0f - red) * amount green:green + (1.0f - green) * amount blue:blue + (1.0f - blue) * amount alpha:alpha];
}

static void TGPollDrawCheckmark(CGContextRef context, CGRect rect, UIColor *color, CGFloat lineWidth)
{
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x + rect.size.width * 0.28f, rect.origin.y + rect.size.height * 0.52f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.44f, rect.origin.y + rect.size.height * 0.68f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.74f, rect.origin.y + rect.size.height * 0.34f);
    CGContextStrokePath(context);
}

static void TGPollDrawCross(CGContextRef context, CGRect rect, UIColor *color, CGFloat lineWidth)
{
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x + rect.size.width * 0.33f, rect.origin.y + rect.size.height * 0.33f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.67f, rect.origin.y + rect.size.height * 0.67f);
    CGContextMoveToPoint(context, rect.origin.x + rect.size.width * 0.67f, rect.origin.y + rect.size.height * 0.33f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.33f, rect.origin.y + rect.size.height * 0.67f);
    CGContextStrokePath(context);
}

static NSArray *TGPollPercents(NSArray *counts, int32_t total, bool normalize)
{
    NSMutableArray *percents = [[NSMutableArray alloc] initWithCapacity:counts.count];
    if (total <= 0)
    {
        for (NSUInteger index = 0; index < counts.count; index++)
            [percents addObject:@0];
        return percents;
    }

    NSMutableArray *remainders = [[NSMutableArray alloc] initWithCapacity:counts.count];
    int32_t sum = 0;
    for (NSNumber *count in counts)
    {
        double exact = (double)[count intValue] * 100.0 / (double)total;
        int32_t value = normalize ? (int32_t)floor(exact) : (int32_t)lround(exact);
        sum += value;
        [percents addObject:@(value)];
        [remainders addObject:@(exact - floor(exact))];
    }

    if (normalize)
    {
        int32_t remaining = 100 - sum;
        while (remaining > 0)
        {
            NSInteger bestIndex = -1;
            double bestRemainder = 0.0;
            for (NSUInteger index = 0; index < remainders.count; index++)
            {
                double remainder = [remainders[index] doubleValue];
                if ([counts[index] intValue] > 0 && remainder > bestRemainder)
                {
                    bestRemainder = remainder;
                    bestIndex = (NSInteger)index;
                }
            }
            if (bestIndex < 0)
                break;
            percents[(NSUInteger)bestIndex] = @([percents[(NSUInteger)bestIndex] intValue] + 1);
            remainders[(NSUInteger)bestIndex] = @0.0;
            remaining--;
        }
    }
    return percents;
}

@interface TGPollDecorationViewModel : TGModernViewModel
{
    TGRichMessageTheme *_theme;
}

@property (nonatomic, strong) NSArray *decorations;

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme;

@end

@implementation TGPollDecorationViewModel

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme
{
    self = [super init];
    if (self != nil)
    {
        _theme = theme;
        self.hasNoView = true;
    }
    return self;
}

- (void)drawInContext:(CGContextRef)context
{
    if (self.hidden || self.alpha < FLT_EPSILON)
        return;

    CGRect clip = CGContextGetClipBoundingBox(context);
    for (TGPollDecoration *decoration in _decorations)
    {
        if (!CGRectIntersectsRect(CGRectInset(decoration.rect, -4.0f, -4.0f), clip))
            continue;
        CGContextSaveGState(context);
        if (_theme.branded && _theme.shadowColor != nil && decoration.kind != TGPollDecorationSeparator)
            CGContextSetShadowWithColor(context, _theme.shadowOffset, 0.0f, _theme.shadowColor.CGColor);
        [self drawDecoration:decoration context:context];
        CGContextRestoreGState(context);
    }
}

- (void)drawDecoration:(TGPollDecoration *)decoration context:(CGContextRef)context
{
    CGRect rect = decoration.rect;
    UIColor *color = decoration.color;
    switch (decoration.kind)
    {
        case TGPollDecorationRadio:
        {
            if (decoration.selected)
            {
                CGContextSetFillColorWithColor(context, color.CGColor);
                CGContextFillEllipseInRect(context, rect);
                CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
                TGPollDrawCheckmark(context, rect, [UIColor whiteColor], 1.5f);
            }
            else
            {
                CGFloat lineWidth = 1.0f;
                CGContextSetStrokeColorWithColor(context, color.CGColor);
                CGContextSetLineWidth(context, lineWidth);
                CGContextStrokeEllipseInRect(context, CGRectInset(rect, lineWidth / 2.0f, lineWidth / 2.0f));
            }
            break;
        }
        case TGPollDecorationSeparator:
        {
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillRect(context, rect);
            if (_theme.branded && _theme.shadowColor != nil)
            {
                CGContextSetFillColorWithColor(context, _theme.shadowColor.CGColor);
                CGContextFillRect(context, CGRectOffset(rect, 0.0f, rect.size.height));
            }
            break;
        }
        case TGPollDecorationBar:
        {
            CGFloat radius = rect.size.height / 2.0f;
            if (_theme.branded)
            {
                CGContextBeginPath(context);
                OGPlatformAddRoundedRectPath(context, rect, radius);
                CGContextSetFillColorWithColor(context, color.CGColor);
                CGContextFillPath(context);
                CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
                CGContextBeginPath(context);
                OGPlatformAddRoundedRectPath(context, rect, radius);
                CGContextClip(context);
                OGPlatformDrawVerticalGradient(context, rect, TGPollLighterColor(color, 0.35f), color);
            }
            else
            {
                CGContextBeginPath(context);
                OGPlatformAddRoundedRectPath(context, rect, radius);
                CGContextSetFillColorWithColor(context, color.CGColor);
                CGContextFillPath(context);
            }
            break;
        }
        case TGPollDecorationBadge:
        {
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillEllipseInRect(context, rect);
            CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
            if (decoration.cross)
                TGPollDrawCross(context, rect, [UIColor whiteColor], 1.5f);
            else
                TGPollDrawCheckmark(context, rect, [UIColor whiteColor], 1.5f);
            break;
        }
    }
}

@end

@interface TGPollMessageViewModel ()
{
    TGPollMediaAttachment *_poll;
    int64_t _peerId;
    TGPollMessageViewState *_state;
    NSString *_displaySignature;

    TGRichMessageTheme *_theme;
    TGRichMessageTextEnvironment *_environment;
    TGModernViewModel *_container;
    TGPollDecorationViewModel *_decorationModel;

    TGModernTextViewModel *_questionModel;
    TGModernTextViewModel *_subtitleModel;
    NSArray *_optionModels;
    NSArray *_percentModels;
    TGModernTextViewModel *_solutionModel;
    TGModernTextViewModel *_footerModel;

    bool _closed;
    bool _showResults;
    bool _interactive;
    bool _footerIsVoteButton;
    bool _voteButtonEnabled;
    NSArray *_selectedOptions;

    NSMutableArray *_hitRegions;
    CGFloat _layoutWidth;
    CGFloat _contentHeight;
    bool _layoutValid;
    bool _resultsRequested;

    NSArray *_currentSelectionViews;
}

@end

@implementation TGPollMessageViewModel

- (instancetype)initWithMessage:(TGMessage *)message poll:(TGPollMediaAttachment *)poll authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context
{
    self = [super initWithMessage:message authorPeer:authorPeer viaUser:viaUser context:context];
    if (self != nil)
    {
        _authorPeerId = message.fromUid;
        _peerId = message.cid;
        _poll = poll;
        _state = [context pollStateForMessageId:message.mid peerId:message.cid];
        _theme = [[TGRichMessageTheme alloc] initWithContext:context incoming:_incomingAppearance];
        [TGPollSignals registerPollId:poll.pollId peerId:message.cid messageId:message.mid];
        [self rebuildWithViewStorage:nil];
    }
    return self;
}

#pragma mark - Content

- (int32_t)currentTime
{
    return (int32_t)[[TGTelegramNetworking instance] approximateRemoteTime];
}

- (NSString *)displaySignature
{
    NSMutableString *signature = [[NSMutableString alloc] initWithFormat:@"%d|%d|%d|%@|%d|%d|%d", _mid, _poll.flags, [_poll isClosedAtTime:[self currentTime]] ? 1 : 0, _poll.question, _poll.results.totalVoters, _poll.results.voters != nil ? 1 : 0, _state.voting ? 1 : 0];
    for (TGPollAnswer *answer in _poll.answers)
    {
        TGPollAnswerVoters *voters = [_poll.results votersForOption:answer.option];
        [signature appendFormat:@"|%@:%d:%d:%d", answer.text, voters.voters, voters.chosen ? 1 : 0, voters.correct ? 1 : 0];
    }
    for (NSData *option in _state.selectedOptions)
        [signature appendFormat:@"|s%@", option];
    [signature appendFormat:@"|%@", _poll.results.solution ?: @""];
    return signature;
}

- (TGModernTextViewModel *)textModelWithString:(NSString *)string size:(CGFloat)size bold:(bool)bold colorKind:(TGRichMessageColorKind)colorKind alignment:(NSTextAlignment)alignment maxNumberOfLines:(NSUInteger)maxNumberOfLines
{
    TGRichMessageTextStyle *style = [TGRichMessageTextStyle styleWithSize:size];
    style.bold = bold;
    style.colorKind = colorKind;
    style.alignment = alignment;
    style.maxNumberOfLines = maxNumberOfLines;
    return [_environment textModelWithString:string.length != 0 ? string : @" " style:style];
}

- (NSString *)subtitleText
{
    if (_closed)
        return TGLocalized(@"MessagePoll.LabelClosed");
    if ([_poll quiz])
        return [_poll publicVoters] ? TGLocalized(@"MessagePoll.LabelQuiz") : TGLocalized(@"MessagePoll.LabelAnonymousQuiz");
    return [_poll publicVoters] ? TGLocalized(@"MessagePoll.LabelPoll") : TGLocalized(@"MessagePoll.LabelAnonymous");
}

- (int32_t)totalVoters
{
    if (_poll.results.hasTotalVoters)
        return _poll.results.totalVoters;
    int32_t total = 0;
    for (TGPollAnswerVoters *voters in _poll.results.voters)
        total += voters.voters;
    return total;
}

- (NSString *)votersText
{
    int32_t total = [self totalVoters];
    if (total <= 0)
        return [_poll quiz] ? TGLocalized(@"MessagePoll.QuizNoUsers") : TGLocalized(@"MessagePoll.NoVotes");
    return [effectiveLocalization() getPluralized:[_poll quiz] ? @"MessagePoll.QuizCount" : @"MessagePoll.VotedCount" count:total];
}

- (void)rebuildWithViewStorage:(TGModernViewStorage *)viewStorage
{
    [self clearSelection];
    if (_container != nil)
        [_contentModel removeSubmodel:_container viewStorage:viewStorage];

    _container = [[TGModernViewModel alloc] init];
    _container.hasNoView = true;
    _decorationModel = [[TGPollDecorationViewModel alloc] initWithTheme:_theme];
    [_container addSubmodel:_decorationModel];
    _environment = [[TGRichMessageTextEnvironment alloc] initWithTheme:_theme richMessage:nil spoilersRevealed:false];

    bool voted = [_poll hasVoted];
    _closed = [_poll isClosedAtTime:[self currentTime]];
    _showResults = (voted || _closed) && _poll.results.voters != nil && (_closed || ![_poll hideResultsUntilClose]);
    _interactive = !voted && !_closed && !_state.voting && _mid > 0 && _mid < TGMessageLocalMidBaseline;
    _selectedOptions = voted ? [_poll chosenOptions] : (_state.selectedOptions ?: @[]);
    _footerIsVoteButton = !voted && !_closed && [_poll multipleChoice];
    _voteButtonEnabled = _footerIsVoteButton && _interactive && _selectedOptions.count != 0;

    CGFloat fontSize = _theme.fontSize;
    NSMutableArray *textModels = [[NSMutableArray alloc] init];

    _questionModel = [self textModelWithString:_poll.question size:fontSize bold:true colorKind:TGRichMessageColorPrimary alignment:NSTextAlignmentLeft maxNumberOfLines:0];
    [textModels addObject:_questionModel];
    _subtitleModel = [self textModelWithString:[self subtitleText] size:fontSize - 3.0f bold:false colorKind:TGRichMessageColorSecondary alignment:NSTextAlignmentLeft maxNumberOfLines:1];
    [textModels addObject:_subtitleModel];

    NSMutableArray *optionModels = [[NSMutableArray alloc] initWithCapacity:_poll.answers.count];
    for (TGPollAnswer *answer in _poll.answers)
    {
        TGModernTextViewModel *model = [self textModelWithString:answer.text size:fontSize bold:false colorKind:TGRichMessageColorPrimary alignment:NSTextAlignmentLeft maxNumberOfLines:0];
        [optionModels addObject:model];
        [textModels addObject:model];
    }
    _optionModels = optionModels;

    NSMutableArray *percentModels = nil;
    if (_showResults)
    {
        NSMutableArray *counts = [[NSMutableArray alloc] initWithCapacity:_poll.answers.count];
        for (TGPollAnswer *answer in _poll.answers)
            [counts addObject:@([_poll.results votersForOption:answer.option].voters)];
        NSArray *percents = TGPollPercents(counts, [self totalVoters], ![_poll multipleChoice]);
        percentModels = [[NSMutableArray alloc] initWithCapacity:percents.count];
        for (NSNumber *percent in percents)
        {
            TGModernTextViewModel *model = [self textModelWithString:[[NSString alloc] initWithFormat:@"%d%%", [percent intValue]] size:fontSize - 2.0f bold:true colorKind:TGRichMessageColorPrimary alignment:NSTextAlignmentRight maxNumberOfLines:1];
            [percentModels addObject:model];
            [textModels addObject:model];
        }
    }
    _percentModels = percentModels;

    _solutionModel = nil;
    if ([_poll quiz] && voted && _poll.results.solution.length != 0)
    {
        _solutionModel = [self textModelWithString:_poll.results.solution size:fontSize - 3.0f bold:false colorKind:TGRichMessageColorSecondary alignment:NSTextAlignmentLeft maxNumberOfLines:0];
        [textModels addObject:_solutionModel];
    }

    if (_footerIsVoteButton)
        _footerModel = [self textModelWithString:TGLocalized(@"MessagePoll.SubmitVote") size:fontSize - 1.0f bold:true colorKind:_voteButtonEnabled ? TGRichMessageColorAccent : TGRichMessageColorSecondary alignment:NSTextAlignmentCenter maxNumberOfLines:1];
    else
        _footerModel = [self textModelWithString:[self votersText] size:fontSize - 3.0f bold:false colorKind:TGRichMessageColorSecondary alignment:NSTextAlignmentCenter maxNumberOfLines:1];
    [textModels addObject:_footerModel];

    for (TGModernTextViewModel *model in textModels)
        [_container addSubmodel:model];
    [_contentModel addSubmodel:_container];

    _displaySignature = [self displaySignature];
    _layoutValid = false;
    _layoutWidth = 0.0f;
}

#pragma mark - Layout

- (CGSize)layoutTextModel:(TGModernTextViewModel *)model width:(CGFloat)width
{
    [model layoutForContainerSize:CGSizeMake(MAX(1.0f, width), CGFLOAT_MAX)];
    return model.frame.size;
}

- (void)placeTextModel:(TGModernTextViewModel *)model x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    CGSize size = model.frame.size;
    CGFloat originX = x;
    if (model.alignment == NSTextAlignmentCenter)
        originX = x + CGFloor((width - size.width) / 2.0f);
    else if (model.alignment == NSTextAlignmentRight)
        originX = x + width - size.width;
    model.frame = CGRectMake(originX, y, size.width, size.height);
}

- (CGFloat)lineHeightForFontSize:(CGFloat)size
{
    UIFont *font = [_theme fontWithSize:size bold:false italic:false mono:false];
    return CGCeil(font.ascender - font.descender);
}

- (TGPollDecoration *)addDecoration:(TGPollDecorationKind)kind rect:(CGRect)rect color:(UIColor *)color to:(NSMutableArray *)decorations
{
    TGPollDecoration *decoration = [[TGPollDecoration alloc] init];
    decoration.kind = kind;
    decoration.rect = rect;
    decoration.color = color;
    [decorations addObject:decoration];
    return decoration;
}

- (void)addHitRegion:(CGRect)rect action:(NSString *)action payload:(id)payload
{
    TGPollHitRegion *region = [[TGPollHitRegion alloc] init];
    region.rect = rect;
    region.action = action;
    region.payload = payload;
    [_hitRegions addObject:region];
}

- (bool)isOptionSelected:(NSData *)option
{
    for (NSData *selected in _selectedOptions)
    {
        if ([selected isEqualToData:option])
            return true;
    }
    return false;
}

- (void)performLayoutWithWidth:(CGFloat)width
{
    NSMutableArray *decorations = [[NSMutableArray alloc] init];
    _hitRegions = [[NSMutableArray alloc] init];

    CGFloat fontSize = _theme.fontSize;
    CGFloat pixel = TGScreenPixel;
    CGFloat leftInset = 30.0f;
    CGFloat optionWidth = MAX(1.0f, width - leftInset);
    CGFloat lineHeight = [self lineHeightForFontSize:fontSize];
    UIColor *secondaryColor = _theme.secondaryColor;
    UIColor *accentColor = _theme.accentColor;
    UIColor *correctColor = UIColorRGB(0x34c759);
    UIColor *wrongColor = UIColorRGB(0xff3b30);
    bool quiz = [_poll quiz];

    CGFloat y = 0.0f;
    [self layoutTextModel:_questionModel width:width];
    [self placeTextModel:_questionModel x:0.0f y:y width:width];
    y += _questionModel.frame.size.height + 1.0f;

    [self layoutTextModel:_subtitleModel width:width];
    [self placeTextModel:_subtitleModel x:0.0f y:y width:width];
    y += _subtitleModel.frame.size.height + 8.0f;

    NSUInteger count = _poll.answers.count;
    for (NSUInteger index = 0; index < count; index++)
    {
        TGPollAnswer *answer = _poll.answers[index];
        TGModernTextViewModel *model = _optionModels[index];
        CGSize textSize = [self layoutTextModel:model width:optionWidth];
        TGPollAnswerVoters *voters = [_poll.results votersForOption:answer.option];
        bool selected = [self isOptionSelected:answer.option];

        if (_showResults)
        {
            CGFloat textY = y + 3.0f;
            [self placeTextModel:model x:leftInset y:textY width:optionWidth];

            TGModernTextViewModel *percentModel = index < _percentModels.count ? _percentModels[index] : nil;
            if (percentModel != nil)
            {
                CGSize percentSize = [self layoutTextModel:percentModel width:leftInset - 4.0f];
                [self placeTextModel:percentModel x:0.0f y:textY + CGFloor((lineHeight - percentSize.height) / 2.0f) width:leftInset - 6.0f];
            }

            CGFloat barY = textY + textSize.height + 4.0f;
            int32_t total = [self totalVoters];
            CGFloat fraction = total > 0 ? MIN(1.0f, (CGFloat)voters.voters / (CGFloat)total) : 0.0f;
            UIColor *barColor = accentColor;
            if (quiz)
            {
                if (voters.correct)
                    barColor = correctColor;
                else if (voters.chosen)
                    barColor = wrongColor;
                else
                    barColor = [secondaryColor colorWithAlphaComponent:0.5f];
            }
            [self addDecoration:TGPollDecorationBar rect:CGRectMake(leftInset, barY, MAX(4.0f, CGFloor(optionWidth * fraction)), 4.0f) color:barColor to:decorations];

            if (voters.chosen || (quiz && voters.correct))
            {
                UIColor *badgeColor = quiz ? (voters.correct ? correctColor : wrongColor) : accentColor;
                TGPollDecoration *badge = [self addDecoration:TGPollDecorationBadge rect:CGRectMake(leftInset - 19.0f, barY + 2.0f - 7.0f, 14.0f, 14.0f) color:badgeColor to:decorations];
                badge.cross = quiz && !voters.correct;
            }

            y = barY + 4.0f + 10.0f;
        }
        else
        {
            CGFloat contentHeight = MAX(textSize.height, 22.0f);
            CGFloat rowHeight = contentHeight + 16.0f;
            CGFloat textY = y + 8.0f + CGFloor((contentHeight - MAX(textSize.height, lineHeight)) / 2.0f);
            [self placeTextModel:model x:leftInset y:textY width:optionWidth];

            CGFloat radioY = textY + CGFloor((lineHeight - 22.0f) / 2.0f);
            TGPollDecoration *radio = [self addDecoration:TGPollDecorationRadio rect:CGRectMake(1.0f, radioY, 22.0f, 22.0f) color:selected ? accentColor : [secondaryColor colorWithAlphaComponent:0.6f] to:decorations];
            radio.selected = selected;

            if (index + 1 < count)
                [self addDecoration:TGPollDecorationSeparator rect:CGRectMake(leftInset, y + rowHeight - pixel, optionWidth, pixel) color:[secondaryColor colorWithAlphaComponent:0.25f] to:decorations];

            if (_interactive)
                [self addHitRegion:CGRectMake(0.0f, y, width, rowHeight) action:@"option" payload:answer.option];

            y += rowHeight;
        }
    }

    if (_solutionModel != nil)
    {
        y += 2.0f;
        [self layoutTextModel:_solutionModel width:width];
        [self placeTextModel:_solutionModel x:0.0f y:y width:width];
        y += _solutionModel.frame.size.height + 6.0f;
    }

    y += _showResults ? 2.0f : 6.0f;
    [self layoutTextModel:_footerModel width:width];
    [self placeTextModel:_footerModel x:0.0f y:y width:width];
    if (_voteButtonEnabled)
        [self addHitRegion:CGRectMake(0.0f, y - 8.0f, width, _footerModel.frame.size.height + 16.0f) action:@"vote" payload:nil];
    y += _footerModel.frame.size.height;

    _contentHeight = CGCeil(MAX(y, 1.0f));
    _layoutWidth = width;
    _layoutValid = true;
    _decorationModel.decorations = decorations;
    _decorationModel.frame = CGRectMake(0.0f, 0.0f, width, _contentHeight);
}

- (CGSize)contentSizeForContainerSize:(CGSize)containerSize needsContentsUpdate:(bool *)needsContentsUpdate infoWidth:(CGFloat)__unused infoWidth
{
    CGFloat width = CGFloor(containerSize.width);
    if (!_layoutValid || ABS(width - _layoutWidth) > FLT_EPSILON)
    {
        [self performLayoutWithWidth:width];
        if (needsContentsUpdate != NULL)
            *needsContentsUpdate = true;
    }
    CGSize size = CGSizeMake(_layoutWidth, _contentHeight);
    if ([TGPresentation brandedIOS6Style])
    {
        if (![self brandedReactionsShareTimeRow])
            size.height += [TGPresentation brandedIOS6ConversationAppearance].bubbleTimeRowHeight;
    }
    else
        size.height += 16.0f;
    size.height += 2.0f;
    return size;
}

- (void)layoutContentForHeaderHeight:(CGFloat)headerHeight containerSize:(CGSize)__unused containerSize
{
    _container.frame = CGRectMake(1.0f, headerHeight + TGGetMessageViewModelLayoutConstants()->textBubbleTextOffsetTop + 2.0f, _layoutWidth, _contentHeight);
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    [self requestResultsIfNeeded];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [self clearSelection];
    [super unbindView:viewStorage];
}

- (void)requestResultsIfNeeded
{
    if (_resultsRequested || _mid <= 0 || _mid >= TGMessageLocalMidBaseline || _closed)
        return;
    _resultsRequested = true;
    [_context.companionHandle requestAction:@"pollResultsRequested" options:@{@"mid": @(_mid), @"peerId": @(_peerId), @"pollHash": @(_poll.pollHash)}];
}

- (void)refreshMetrics
{
    _theme = [[TGRichMessageTheme alloc] initWithContext:_context incoming:_incomingAppearance];
    [self rebuildWithViewStorage:nil];
}

- (void)updateAssets
{
    [super updateAssets];
    CGFloat width = _layoutWidth;
    CGRect containerFrame = _container.frame;
    _theme = [[TGRichMessageTheme alloc] initWithContext:_context incoming:_incomingAppearance];
    [self rebuildWithViewStorage:nil];
    if (width > FLT_EPSILON)
    {
        [self performLayoutWithWidth:width];
        _container.frame = CGRectMake(containerFrame.origin.x, containerFrame.origin.y, _layoutWidth, _contentHeight);
        [_contentModel setNeedsSubmodelContentsUpdate];
        [_contentModel updateSubmodelContentsIfNeeded];
    }
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];

    TGPollMediaAttachment *poll = [TGPollMediaAttachment pollInMediaAttachments:message.mediaAttachments];
    if (poll != nil)
    {
        _poll = poll;
        [TGPollSignals registerPollId:poll.pollId peerId:message.cid messageId:message.mid];
    }
    _peerId = message.cid;
    _state = [_context pollStateForMessageId:message.mid peerId:message.cid];
    if (_state.voting && [_poll hasVoted])
        _state = nil;

    if (![[self displaySignature] isEqualToString:_displaySignature])
    {
        [self rebuildWithViewStorage:viewStorage];
        [_contentModel setNeedsSubmodelContentsUpdate];
        if (sizeUpdated != NULL)
            *sizeUpdated = true;
    }
}

#pragma mark - Interaction

- (CGPoint)containerPointFromContentPoint:(CGPoint)point
{
    return CGPointMake(point.x - _container.frame.origin.x, point.y - _container.frame.origin.y);
}

- (TGPollHitRegion *)hitRegionAtContainerPoint:(CGPoint)point
{
    for (TGPollHitRegion *region in _hitRegions)
    {
        if (CGRectContainsPoint(region.rect, point))
            return region;
    }
    return nil;
}

- (void)applyState:(TGPollMessageViewState *)state
{
    [_context setPollState:state forMessageId:_mid peerId:_peerId];
    [_context.companionHandle requestAction:@"pollStateChanged" options:@{@"mid": @(_mid), @"peerId": @(_peerId)}];
}

- (void)voteWithOptions:(NSArray *)options
{
    if (options.count == 0)
        return;
    [_context setPollState:[[TGPollMessageViewState alloc] initWithSelectedOptions:options voting:true] forMessageId:_mid peerId:_peerId];
    [_context.companionHandle requestAction:@"pollVote" options:@{@"mid": @(_mid), @"peerId": @(_peerId), @"options": options}];
}

- (void)activateRegion:(TGPollHitRegion *)region
{
    if ([region.action isEqualToString:@"option"])
    {
        NSData *option = region.payload;
        if ([_poll multipleChoice])
        {
            NSMutableArray *selected = [[NSMutableArray alloc] initWithArray:_state.selectedOptions ?: @[]];
            NSUInteger index = [selected indexOfObject:option];
            if (index == NSNotFound)
                [selected addObject:option];
            else
                [selected removeObjectAtIndex:index];
            [self applyState:[[TGPollMessageViewState alloc] initWithSelectedOptions:selected voting:false]];
        }
        else
            [self voteWithOptions:@[option]];
    }
    else if ([region.action isEqualToString:@"vote"])
        [self voteWithOptions:_state.selectedOptions];
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
        return;
    [self clearSelection];
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;

    TGPollHitRegion *region = [self hitRegionAtContainerPoint:[self containerPointFromContentPoint:[recognizer locationInView:[_contentModel boundView]]]];
    if (recognizer.longTapped || recognizer.doubleTapped)
        [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    else if (region != nil)
        [self activateRegion:region];
    else
        [super messageDoubleTapGesture:recognizer];
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer shouldFailTap:(CGPoint)__unused point
{
    CGPoint contentPoint = [recognizer locationInView:[_contentModel boundView]];
    if ([self hitRegionAtContainerPoint:[self containerPointFromContentPoint:contentPoint]] != nil)
        return 3;
    if ((_forwardedHeaderModel != nil && CGRectContainsPoint(_forwardedHeaderModel.frame, contentPoint)) || (_replyHeaderModel != nil && CGRectContainsPoint(_replyHeaderModel.frame, contentPoint)) || (_viaUserModel != nil && CGRectContainsPoint(_viaUserModel.frame, contentPoint)))
        return 3;
    return 0;
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)point
{
    CGPoint contentPoint = CGPointMake(point.x - (_contentModel.frame.origin.x - _backgroundModel.frame.origin.x), point.y - (_contentModel.frame.origin.y - _backgroundModel.frame.origin.y));
    [self updateSelection:[self containerPointFromContentPoint:contentPoint]];
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    [self clearSelection];
}

- (void)clearHighlights
{
    [self clearSelection];
}

- (void)clearSelection
{
    for (UIView *view in _currentSelectionViews)
        [view removeFromSuperview];
    _currentSelectionViews = nil;
}

- (void)updateSelection:(CGPoint)point
{
    UIView *contentView = [_contentModel boundView];
    if (contentView == nil)
        return;
    [self clearSelection];
    TGPollHitRegion *region = [self hitRegionAtContainerPoint:point];
    if (region == nil)
        return;
    UIImageView *view = [[UIImageView alloc] initWithImage:[[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull]];
    view.frame = CGRectOffset(region.rect, _container.frame.origin.x, _container.frame.origin.y);
    [contentView addSubview:view];
    _currentSelectionViews = @[view];
}

@end
