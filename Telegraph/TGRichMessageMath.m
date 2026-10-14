#import "TGRichMessageMath.h"

typedef enum {
    TGMathStyleDisplay = 0,
    TGMathStyleText = 1,
    TGMathStyleScript = 2,
    TGMathStyleScriptScript = 3
} TGMathStyle;

typedef enum {
    TGMathClassOrd = 0,
    TGMathClassOp,
    TGMathClassBin,
    TGMathClassRel,
    TGMathClassOpen,
    TGMathClassClose,
    TGMathClassPunct,
    TGMathClassInner
} TGMathClass;

typedef enum {
    TGMathFontItalic = 0,
    TGMathFontRoman,
    TGMathFontBold,
    TGMathFontBoldItalic,
    TGMathFontSans,
    TGMathFontMono,
    TGMathFontDoubleStruck
} TGMathFontKind;

typedef enum {
    TGMathStopEnd = 0,
    TGMathStopBrace,
    TGMathStopBracket,
    TGMathStopRight,
    TGMathStopCell,
    TGMathStopRow,
    TGMathStopEnvironmentEnd
} TGMathStop;

@interface TGMathBox : NSObject
{
@public
    CGFloat _width;
    CGFloat _ascent;
    CGFloat _descent;
    TGMathClass _mathClass;
    NSString *_text;
    UIFont *_font;
    NSMutableArray *_children;
    NSMutableArray *_childOffsets;
    void (^_drawPaths)(CGContextRef context, CGFloat x, CGFloat baseline);
    bool _largeOperator;
    int _limits;
    CGFloat _size;
}

@end

@implementation TGMathBox

- (void)addChild:(TGMathBox *)child x:(CGFloat)x shift:(CGFloat)shift
{
    if (child == nil)
        return;
    if (_children == nil)
    {
        _children = [[NSMutableArray alloc] init];
        _childOffsets = [[NSMutableArray alloc] init];
    }
    [_children addObject:child];
    [_childOffsets addObject:[NSValue valueWithCGPoint:CGPointMake(x, shift)]];
}

- (void)drawInContext:(CGContextRef)context x:(CGFloat)x baseline:(CGFloat)baseline
{
    if (_text.length != 0 && _font != nil)
        [_text drawAtPoint:CGPointMake(x, baseline - _font.ascender) withFont:_font];
    NSUInteger index = 0;
    for (TGMathBox *child in _children)
    {
        CGPoint offset = [_childOffsets[index] CGPointValue];
        [child drawInContext:context x:x + offset.x baseline:baseline - offset.y];
        index++;
    }
    if (_drawPaths)
        _drawPaths(context, x, baseline);
}

@end

static TGMathStyle TGMathScriptStyle(TGMathStyle style)
{
    return style <= TGMathStyleText ? TGMathStyleScript : TGMathStyleScriptScript;
}

static TGMathStyle TGMathFractionStyle(TGMathStyle style)
{
    switch (style)
    {
        case TGMathStyleDisplay:
            return TGMathStyleText;
        case TGMathStyleText:
            return TGMathStyleScript;
        default:
            return TGMathStyleScriptScript;
    }
}

static UIFont *TGMathFont(TGMathFontKind kind, CGFloat size)
{
    size = MAX(6.0f, size);
    NSString *name = nil;
    switch (kind)
    {
        case TGMathFontItalic:
            name = @"TimesNewRomanPS-ItalicMT";
            break;
        case TGMathFontRoman:
        case TGMathFontDoubleStruck:
            name = @"TimesNewRomanPSMT";
            break;
        case TGMathFontBold:
            name = @"TimesNewRomanPS-BoldMT";
            break;
        case TGMathFontBoldItalic:
            name = @"TimesNewRomanPS-BoldItalicMT";
            break;
        case TGMathFontSans:
            name = @"Helvetica";
            break;
        case TGMathFontMono:
            name = @"Courier";
            break;
    }
    UIFont *font = [UIFont fontWithName:name size:size];
    if (font != nil)
        return font;
    switch (kind)
    {
        case TGMathFontItalic:
            return [UIFont italicSystemFontOfSize:size];
        case TGMathFontBold:
        case TGMathFontBoldItalic:
            return [UIFont boldSystemFontOfSize:size];
        default:
            return [UIFont systemFontOfSize:size];
    }
}

static CGFloat TGMathTextWidth(NSString *text, UIFont *font)
{
    if (text.length == 0)
        return 0.0f;
    return [text sizeWithFont:font].width;
}

static TGMathBox *TGMathGlyph(NSString *text, UIFont *font, TGMathClass mathClass)
{
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_text = text;
    box->_font = font;
    box->_width = ceil(TGMathTextWidth(text, font));
    box->_ascent = font.ascender * 0.86f;
    box->_descent = MAX(0.0f, -font.descender);
    box->_mathClass = mathClass;
    box->_size = font.pointSize;
    return box;
}

static TGMathBox *TGMathSpace(CGFloat width)
{
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_width = width;
    box->_mathClass = TGMathClassOrd;
    return box;
}

static CGFloat TGMathSpacing(TGMathClass left, TGMathClass right, TGMathStyle style, CGFloat size)
{
    CGFloat thin = size * 3.0f / 18.0f;
    CGFloat medium = size * 4.0f / 18.0f;
    CGFloat thick = size * 5.0f / 18.0f;
    bool tight = style >= TGMathStyleScript;
    if (left == TGMathClassOp && (right == TGMathClassOrd || right == TGMathClassOp))
        return thin;
    if (left == TGMathClassOrd && right == TGMathClassOp)
        return thin;
    if (left == TGMathClassClose && right == TGMathClassOp)
        return thin;
    if (tight)
        return 0.0f;
    if (left == TGMathClassBin || right == TGMathClassBin)
        return medium;
    if (left == TGMathClassRel || right == TGMathClassRel)
        return (left == TGMathClassRel && right == TGMathClassRel) ? 0.0f : thick;
    if (left == TGMathClassPunct)
        return thin;
    if (left == TGMathClassInner || right == TGMathClassInner)
        return thin;
    return 0.0f;
}

static TGMathBox *TGMathHList(NSArray *atoms, TGMathStyle style, CGFloat size)
{
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = TGMathClassOrd;
    box->_size = size;
    NSMutableArray *classes = [[NSMutableArray alloc] init];
    TGMathClass previous = TGMathClassOpen;
    bool hasPrevious = false;
    for (TGMathBox *atom in atoms)
    {
        TGMathClass mathClass = atom->_mathClass;
        if (mathClass == TGMathClassBin && (!hasPrevious || previous == TGMathClassBin || previous == TGMathClassOp || previous == TGMathClassRel || previous == TGMathClassOpen || previous == TGMathClassPunct))
            mathClass = TGMathClassOrd;
        [classes addObject:@(mathClass)];
        previous = mathClass;
        hasPrevious = true;
    }
    for (NSUInteger index = 0; index < classes.count; index++)
    {
        TGMathClass mathClass = (TGMathClass)[classes[index] intValue];
        if (mathClass == TGMathClassBin)
        {
            bool nextValid = index + 1 < classes.count;
            TGMathClass next = nextValid ? (TGMathClass)[classes[index + 1] intValue] : TGMathClassClose;
            if (!nextValid || next == TGMathClassRel || next == TGMathClassClose || next == TGMathClassPunct)
                classes[index] = @(TGMathClassOrd);
        }
    }

    CGFloat x = 0.0f;
    for (NSUInteger index = 0; index < atoms.count; index++)
    {
        TGMathBox *atom = atoms[index];
        if (index != 0)
            x += TGMathSpacing((TGMathClass)[classes[index - 1] intValue], (TGMathClass)[classes[index] intValue], style, size);
        [box addChild:atom x:x shift:0.0f];
        x += atom->_width;
        box->_ascent = MAX(box->_ascent, atom->_ascent);
        box->_descent = MAX(box->_descent, atom->_descent);
    }
    box->_width = x;
    if (atoms.count == 1)
    {
        TGMathBox *single = atoms[0];
        box->_mathClass = single->_mathClass;
        box->_largeOperator = single->_largeOperator;
        box->_limits = single->_limits;
    }
    return box;
}

static void TGMathStrokeLine(CGContextRef context, CGPoint from, CGPoint to, CGFloat width)
{
    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, from.x, from.y);
    CGContextAddLineToPoint(context, to.x, to.y);
    CGContextStrokePath(context);
}

@interface TGMathParser : NSObject
{
    NSString *_source;
    NSUInteger _index;
    CGFloat _baseSize;
    NSString *_environmentEnd;
    NSInteger _depth;
}

@end

@implementation TGMathParser

- (instancetype)initWithSource:(NSString *)source baseSize:(CGFloat)baseSize
{
    self = [super init];
    if (self != nil)
    {
        NSString *string = source ?: @"";
        if (string.length > 1500)
            string = [string substringToIndex:1500];
        _source = string;
        _baseSize = baseSize;
    }
    return self;
}

- (CGFloat)sizeForStyle:(TGMathStyle)style
{
    switch (style)
    {
        case TGMathStyleScript:
            return MAX(7.0f, _baseSize * 0.7f);
        case TGMathStyleScriptScript:
            return MAX(6.0f, _baseSize * 0.52f);
        default:
            return _baseSize;
    }
}

- (CGFloat)axisForStyle:(TGMathStyle)style
{
    return [self sizeForStyle:style] * 0.25f;
}

- (CGFloat)ruleForStyle:(TGMathStyle)style
{
    return MAX(0.5f, [self sizeForStyle:style] * 0.055f);
}

- (bool)atEnd
{
    return _index >= _source.length;
}

- (unichar)peek
{
    return [self atEnd] ? 0 : [_source characterAtIndex:_index];
}

- (void)skipWhitespace
{
    while (![self atEnd])
    {
        unichar c = [self peek];
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
            break;
        _index++;
    }
}

- (NSString *)readCommandName
{
    _index++;
    if ([self atEnd])
        return @"";
    NSUInteger start = _index;
    unichar c = [self peek];
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
    {
        while (![self atEnd])
        {
            unichar d = [self peek];
            if (!((d >= 'a' && d <= 'z') || (d >= 'A' && d <= 'Z')))
                break;
            _index++;
        }
        return [_source substringWithRange:NSMakeRange(start, _index - start)];
    }
    _index++;
    return [_source substringWithRange:NSMakeRange(start, 1)];
}

- (NSString *)readRawGroup
{
    [self skipWhitespace];
    if ([self peek] != '{')
    {
        if ([self atEnd])
            return @"";
        if ([self peek] == '\\')
            return [@"\\" stringByAppendingString:[self readCommandName]];
        NSString *single = [_source substringWithRange:NSMakeRange(_index, 1)];
        _index++;
        return single;
    }
    _index++;
    NSUInteger start = _index;
    int depth = 1;
    while (![self atEnd])
    {
        unichar c = [self peek];
        if (c == '\\')
        {
            _index = MIN(_source.length, _index + 2);
            continue;
        }
        if (c == '{')
            depth++;
        else if (c == '}')
        {
            depth--;
            if (depth == 0)
            {
                NSString *result = [_source substringWithRange:NSMakeRange(start, _index - start)];
                _index++;
                return result;
            }
        }
        _index++;
    }
    return [_source substringFromIndex:start];
}

- (NSString *)readDelimiter
{
    [self skipWhitespace];
    if ([self atEnd])
        return @".";
    unichar c = [self peek];
    if (c == '\\')
    {
        NSString *name = [self readCommandName];
        static NSDictionary *names = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            names = @{@"{": @"{", @"}": @"}", @"|": @"‖", @"lbrace": @"{", @"rbrace": @"}", @"langle": @"⟨", @"rangle": @"⟩", @"lfloor": @"⌊", @"rfloor": @"⌋", @"lceil": @"⌈", @"rceil": @"⌉", @"vert": @"|", @"Vert": @"‖", @"lvert": @"|", @"rvert": @"|", @"lVert": @"‖", @"rVert": @"‖"};
        });
        return names[name] ?: @".";
    }
    _index++;
    if (c == '<')
        return @"⟨";
    if (c == '>')
        return @"⟩";
    return [NSString stringWithCharacters:&c length:1];
}

- (TGMathBox *)delimiter:(NSString *)delimiter forAscent:(CGFloat)contentAscent descent:(CGFloat)contentDescent style:(TGMathStyle)style left:(bool)left
{
    CGFloat size = [self sizeForStyle:style];
    if ([delimiter isEqualToString:@"."])
        return TGMathSpace(size * 0.12f);

    UIFont *font = TGMathFont(TGMathFontRoman, size);
    CGFloat axis = [self axisForStyle:style];
    CGFloat half = MAX(contentAscent - axis, contentDescent + axis);
    if (half * 2.0f <= (font.ascender - font.descender) * 0.92f)
    {
        TGMathBox *glyph = TGMathGlyph(delimiter, font, left ? TGMathClassOpen : TGMathClassClose);
        return glyph;
    }

    half += size * 0.08f;
    CGFloat rule = [self ruleForStyle:style] * 1.3f;
    bool isBar = [delimiter isEqualToString:@"|"] || [delimiter isEqualToString:@"‖"];
    CGFloat width = isBar ? size * 0.3f : MIN(size * 0.75f, MAX(size * 0.38f, half * 0.28f));

    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = left ? TGMathClassOpen : TGMathClassClose;
    box->_width = width;
    box->_ascent = axis + half;
    box->_descent = half - axis;
    box->_size = size;
    NSString *kind = delimiter;
    box->_drawPaths = ^(CGContextRef context, CGFloat x, CGFloat baseline)
    {
        CGFloat top = baseline - axis - half;
        CGFloat bottom = baseline - axis + half;
        CGFloat mid = baseline - axis;
        CGContextSetLineCap(context, kCGLineCapButt);
        CGContextSetLineJoin(context, kCGLineJoinMiter);
        bool mirrored = [kind isEqualToString:@")"] || [kind isEqualToString:@"]"] || [kind isEqualToString:@"}"] || [kind isEqualToString:@"⟩"] || [kind isEqualToString:@"⌋"] || [kind isEqualToString:@"⌉"];
        CGFloat (^px)(CGFloat) = ^CGFloat(CGFloat fraction)
        {
            return mirrored ? x + width * (1.0f - fraction) : x + width * fraction;
        };
        if ([kind isEqualToString:@"("] || [kind isEqualToString:@")"])
        {
            CGContextMoveToPoint(context, px(0.85f), top);
            CGContextAddQuadCurveToPoint(context, px(-0.05f), mid, px(0.85f), bottom);
            CGContextAddQuadCurveToPoint(context, px(0.3f), mid, px(0.85f), top);
            CGContextFillPath(context);
        }
        else if ([kind isEqualToString:@"["] || [kind isEqualToString:@"]"] || [kind isEqualToString:@"⌊"] || [kind isEqualToString:@"⌋"] || [kind isEqualToString:@"⌈"] || [kind isEqualToString:@"⌉"])
        {
            bool hasTop = ![kind isEqualToString:@"⌊"] && ![kind isEqualToString:@"⌋"];
            bool hasBottom = ![kind isEqualToString:@"⌈"] && ![kind isEqualToString:@"⌉"];
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, hasTop ? px(0.85f) : px(0.3f), top + rule / 2.0f);
            if (hasTop)
                CGContextAddLineToPoint(context, px(0.3f), top + rule / 2.0f);
            CGContextAddLineToPoint(context, px(0.3f), bottom - rule / 2.0f);
            if (hasBottom)
                CGContextAddLineToPoint(context, px(0.85f), bottom - rule / 2.0f);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"{"] || [kind isEqualToString:@"}"])
        {
            CGFloat curl = MIN(width * 0.45f, (mid - top) * 0.3f);
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, px(0.9f), top + rule / 2.0f);
            CGContextAddQuadCurveToPoint(context, px(0.5f), top + rule / 2.0f, px(0.5f), top + curl);
            CGContextAddLineToPoint(context, px(0.5f), mid - curl);
            CGContextAddQuadCurveToPoint(context, px(0.5f), mid, px(0.1f), mid);
            CGContextAddQuadCurveToPoint(context, px(0.5f), mid, px(0.5f), mid + curl);
            CGContextAddLineToPoint(context, px(0.5f), bottom - curl);
            CGContextAddQuadCurveToPoint(context, px(0.5f), bottom - rule / 2.0f, px(0.9f), bottom - rule / 2.0f);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"⟨"] || [kind isEqualToString:@"⟩"])
        {
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, px(0.85f), top);
            CGContextAddLineToPoint(context, px(0.2f), mid);
            CGContextAddLineToPoint(context, px(0.85f), bottom);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"‖"])
        {
            TGMathStrokeLine(context, CGPointMake(x + width * 0.3f, top), CGPointMake(x + width * 0.3f, bottom), rule);
            TGMathStrokeLine(context, CGPointMake(x + width * 0.7f, top), CGPointMake(x + width * 0.7f, bottom), rule);
        }
        else
        {
            TGMathStrokeLine(context, CGPointMake(x + width * 0.5f, top), CGPointMake(x + width * 0.5f, bottom), rule);
        }
    };
    return box;
}

- (TGMathBox *)fractionWithNumerator:(TGMathBox *)numerator denominator:(TGMathBox *)denominator style:(TGMathStyle)style rule:(bool)hasRule
{
    CGFloat size = [self sizeForStyle:style];
    CGFloat axis = [self axisForStyle:style];
    CGFloat rule = hasRule ? [self ruleForStyle:style] : 0.0f;
    CGFloat gap = style == TGMathStyleDisplay ? MAX(rule * 3.0f, size * 0.16f) : MAX(rule * 1.5f, size * 0.1f);
    CGFloat padding = size * 0.12f;
    CGFloat width = MAX(numerator->_width, denominator->_width) + padding * 2.0f;
    CGFloat numeratorShift = axis + rule / 2.0f + gap + numerator->_descent;
    CGFloat denominatorShift = denominator->_ascent + gap + rule / 2.0f - axis;

    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = TGMathClassInner;
    box->_size = size;
    box->_width = width;
    [box addChild:numerator x:(width - numerator->_width) / 2.0f shift:numeratorShift];
    [box addChild:denominator x:(width - denominator->_width) / 2.0f shift:-denominatorShift];
    box->_ascent = numeratorShift + numerator->_ascent;
    box->_descent = denominatorShift + denominator->_descent;
    if (hasRule)
    {
        box->_drawPaths = ^(CGContextRef context, CGFloat x, CGFloat baseline)
        {
            CGContextFillRect(context, CGRectMake(x + padding / 2.0f, baseline - axis - rule / 2.0f, width - padding, rule));
        };
    }
    return box;
}

- (TGMathBox *)wrap:(TGMathBox *)content left:(NSString *)left right:(NSString *)right style:(TGMathStyle)style
{
    TGMathBox *leftBox = [self delimiter:left forAscent:content->_ascent descent:content->_descent style:style left:true];
    TGMathBox *rightBox = [self delimiter:right forAscent:content->_ascent descent:content->_descent style:style left:false];
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = TGMathClassInner;
    CGFloat x = 0.0f;
    for (TGMathBox *part in @[leftBox, content, rightBox])
    {
        [box addChild:part x:x shift:0.0f];
        x += part->_width;
        box->_ascent = MAX(box->_ascent, part->_ascent);
        box->_descent = MAX(box->_descent, part->_descent);
    }
    box->_width = x;
    return box;
}

- (TGMathBox *)radical:(TGMathBox *)body index:(TGMathBox *)indexBox style:(TGMathStyle)style
{
    CGFloat size = [self sizeForStyle:style];
    CGFloat rule = [self ruleForStyle:style];
    CGFloat gap = rule + size * (style == TGMathStyleDisplay ? 0.16f : 0.1f);
    CGFloat height = body->_ascent + body->_descent + gap + rule;
    CGFloat signWidth = MAX(size * 0.55f, MIN(size * 1.0f, height * 0.3f));
    CGFloat indexOffset = 0.0f;
    if (indexBox != nil)
        indexOffset = MAX(0.0f, indexBox->_width - signWidth * 0.5f);
    CGFloat padding = size * 0.08f;

    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = TGMathClassOrd;
    box->_size = size;
    box->_width = indexOffset + signWidth + body->_width + padding;
    box->_ascent = body->_ascent + gap + rule;
    box->_descent = body->_descent;
    [box addChild:body x:indexOffset + signWidth shift:0.0f];
    if (indexBox != nil)
    {
        CGFloat indexShift = -body->_descent + height * 0.55f + indexBox->_descent;
        [box addChild:indexBox x:0.0f shift:indexShift];
        box->_ascent = MAX(box->_ascent, indexShift + indexBox->_ascent);
    }
    CGFloat bodyWidth = body->_width;
    CGFloat bodyAscent = body->_ascent;
    CGFloat bodyDescent = body->_descent;
    box->_drawPaths = ^(CGContextRef context, CGFloat x, CGFloat baseline)
    {
        CGFloat left = x + indexOffset;
        CGFloat top = baseline - bodyAscent - gap - rule / 2.0f;
        CGFloat bottom = baseline + bodyDescent;
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        TGMathStrokeLine(context, CGPointMake(left + signWidth * 0.06f, bottom - height * 0.42f), CGPointMake(left + signWidth * 0.26f, bottom - height * 0.5f), rule);
        TGMathStrokeLine(context, CGPointMake(left + signWidth * 0.26f, bottom - height * 0.5f), CGPointMake(left + signWidth * 0.52f, bottom), rule * 2.0f);
        TGMathStrokeLine(context, CGPointMake(left + signWidth * 0.52f, bottom), CGPointMake(left + signWidth, top), rule);
        CGContextSetLineCap(context, kCGLineCapButt);
        TGMathStrokeLine(context, CGPointMake(left + signWidth, top), CGPointMake(left + signWidth + bodyWidth + padding, top), rule);
    };
    return box;
}

- (TGMathBox *)accent:(NSString *)kind body:(TGMathBox *)body style:(TGMathStyle)style
{
    CGFloat size = [self sizeForStyle:style];
    CGFloat rule = [self ruleForStyle:style];
    bool under = [kind isEqualToString:@"underline"];
    CGFloat accentHeight = [kind isEqualToString:@"overline"] || [kind isEqualToString:@"bar"] || under ? rule : size * 0.22f;
    CGFloat gap = size * 0.08f;

    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = body->_mathClass;
    box->_size = size;
    box->_width = body->_width;
    box->_ascent = under ? body->_ascent : body->_ascent + gap + accentHeight;
    box->_descent = under ? body->_descent + gap + rule : body->_descent;
    [box addChild:body x:0.0f shift:0.0f];
    CGFloat width = body->_width;
    CGFloat bodyAscent = body->_ascent;
    CGFloat bodyDescent = body->_descent;
    box->_drawPaths = ^(CGContextRef context, CGFloat x, CGFloat baseline)
    {
        CGFloat bottom = baseline - bodyAscent - gap;
        CGFloat top = bottom - accentHeight;
        CGFloat inset = width > size ? 0.0f : width * 0.12f;
        CGFloat left = x + inset;
        CGFloat right = x + width - inset;
        CGFloat center = x + width / 2.0f;
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        if (under)
            CGContextFillRect(context, CGRectMake(x, baseline + bodyDescent + gap, width, rule));
        else if ([kind isEqualToString:@"overline"] || [kind isEqualToString:@"bar"])
            CGContextFillRect(context, CGRectMake(left, top, right - left, rule));
        else if ([kind isEqualToString:@"hat"] || [kind isEqualToString:@"widehat"])
        {
            CGFloat half = [kind isEqualToString:@"hat"] ? MIN(width / 2.0f, size * 0.22f) : width / 2.0f;
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, center - half, bottom);
            CGContextAddLineToPoint(context, center, top);
            CGContextAddLineToPoint(context, center + half, bottom);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"vec"] || [kind isEqualToString:@"overrightarrow"])
        {
            CGFloat y = (top + bottom) / 2.0f;
            CGFloat head = size * 0.12f;
            TGMathStrokeLine(context, CGPointMake(left, y), CGPointMake(right, y), rule);
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, right - head, y - head);
            CGContextAddLineToPoint(context, right, y);
            CGContextAddLineToPoint(context, right - head, y + head);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"tilde"] || [kind isEqualToString:@"widetilde"])
        {
            CGFloat half = [kind isEqualToString:@"tilde"] ? MIN(width / 2.0f, size * 0.25f) : width / 2.0f;
            CGContextSetLineWidth(context, rule);
            CGContextMoveToPoint(context, center - half, bottom);
            CGContextAddCurveToPoint(context, center - half * 0.5f, top - accentHeight * 0.3f, center, bottom, center, (top + bottom) / 2.0f);
            CGContextAddCurveToPoint(context, center, top, center + half * 0.5f, bottom + accentHeight * 0.3f, center + half, top);
            CGContextStrokePath(context);
        }
        else if ([kind isEqualToString:@"dot"] || [kind isEqualToString:@"ddot"])
        {
            CGFloat radius = MAX(0.8f, size * 0.05f);
            CGFloat y = (top + bottom) / 2.0f;
            if ([kind isEqualToString:@"dot"])
                CGContextFillEllipseInRect(context, CGRectMake(center - radius, y - radius, radius * 2.0f, radius * 2.0f));
            else
            {
                CGContextFillEllipseInRect(context, CGRectMake(center - radius * 3.0f, y - radius, radius * 2.0f, radius * 2.0f));
                CGContextFillEllipseInRect(context, CGRectMake(center + radius, y - radius, radius * 2.0f, radius * 2.0f));
            }
        }
    };
    return box;
}

- (TGMathBox *)attachScriptsToBase:(TGMathBox *)base superscript:(TGMathBox *)superscript subscript:(TGMathBox *)subscript style:(TGMathStyle)style
{
    if (superscript == nil && subscript == nil)
        return base;

    CGFloat size = [self sizeForStyle:style];
    CGFloat rule = [self ruleForStyle:style];
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = base->_mathClass;
    box->_size = size;

    bool limits = base->_largeOperator && (base->_limits == 1 || (base->_limits == 0 && style == TGMathStyleDisplay));
    if (limits)
    {
        CGFloat gap = size * 0.12f;
        CGFloat width = base->_width;
        if (superscript != nil)
            width = MAX(width, superscript->_width);
        if (subscript != nil)
            width = MAX(width, subscript->_width);
        [box addChild:base x:(width - base->_width) / 2.0f shift:0.0f];
        box->_ascent = base->_ascent;
        box->_descent = base->_descent;
        if (superscript != nil)
        {
            CGFloat shift = base->_ascent + gap + superscript->_descent;
            [box addChild:superscript x:(width - superscript->_width) / 2.0f shift:shift];
            box->_ascent = shift + superscript->_ascent;
        }
        if (subscript != nil)
        {
            CGFloat shift = base->_descent + gap + subscript->_ascent;
            [box addChild:subscript x:(width - subscript->_width) / 2.0f shift:-shift];
            box->_descent = shift + subscript->_descent;
        }
        box->_width = width;
        return box;
    }

    [box addChild:base x:0.0f shift:0.0f];
    CGFloat scriptSize = [self sizeForStyle:TGMathScriptStyle(style)];
    CGFloat superscriptShift = 0.0f;
    CGFloat subscriptShift = 0.0f;
    if (superscript != nil)
        superscriptShift = MAX(size * 0.36f, MAX(base->_ascent - scriptSize * 0.38f, superscript->_descent + size * 0.12f));
    if (subscript != nil)
        subscriptShift = MAX(size * 0.18f, MAX(base->_descent - scriptSize * 0.05f, subscript->_ascent - size * 0.42f));
    if (superscript != nil && subscript != nil)
    {
        CGFloat clearance = (superscriptShift - superscript->_descent) - (subscript->_ascent - subscriptShift);
        if (clearance < rule * 4.0f)
            subscriptShift += rule * 4.0f - clearance;
    }
    CGFloat scriptX = base->_width + (base->_largeOperator ? size * 0.04f : size * 0.03f);
    CGFloat width = base->_width;
    box->_ascent = base->_ascent;
    box->_descent = base->_descent;
    if (superscript != nil)
    {
        [box addChild:superscript x:scriptX shift:superscriptShift];
        width = MAX(width, scriptX + superscript->_width);
        box->_ascent = MAX(box->_ascent, superscriptShift + superscript->_ascent);
    }
    if (subscript != nil)
    {
        [box addChild:subscript x:scriptX shift:-subscriptShift];
        width = MAX(width, scriptX + subscript->_width);
        box->_descent = MAX(box->_descent, subscriptShift + subscript->_descent);
    }
    box->_width = width + size * 0.05f;
    return box;
}

- (TGMathBox *)largeOperator:(NSString *)symbol style:(TGMathStyle)style limitsByDefault:(bool)limitsByDefault
{
    CGFloat size = [self sizeForStyle:style];
    CGFloat scale = style == TGMathStyleDisplay ? 1.55f : 1.15f;
    UIFont *font = TGMathFont(TGMathFontRoman, size * scale);
    TGMathBox *glyph = TGMathGlyph(symbol, font, TGMathClassOp);
    CGFloat axis = [self axisForStyle:style];
    CGFloat glyphCenter = (glyph->_ascent - glyph->_descent) / 2.0f;
    CGFloat shift = axis - glyphCenter;
    TGMathBox *box = [[TGMathBox alloc] init];
    box->_mathClass = TGMathClassOp;
    box->_largeOperator = true;
    box->_limits = limitsByDefault ? 0 : 2;
    box->_width = glyph->_width;
    box->_ascent = glyph->_ascent + shift;
    box->_descent = MAX(0.0f, glyph->_descent - shift);
    box->_size = size;
    [box addChild:glyph x:0.0f shift:shift];
    return box;
}

- (TGMathBox *)matrixForEnvironment:(NSString *)environment style:(TGMathStyle)style fontKind:(TGMathFontKind)fontKind
{
    if ([environment isEqualToString:@"array"])
        [self readRawGroup];

    TGMathStyle cellStyle = style == TGMathStyleDisplay ? TGMathStyleText : style;
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    NSMutableArray *row = [[NSMutableArray alloc] init];
    NSString *previousEnd = _environmentEnd;
    _environmentEnd = environment;
    while (true)
    {
        TGMathStop stop = TGMathStopEnd;
        NSArray *atoms = [self parseAtomsWithStyle:cellStyle fontKind:fontKind stop:&stop];
        [row addObject:TGMathHList(atoms, cellStyle, [self sizeForStyle:cellStyle])];
        if (stop == TGMathStopCell)
            continue;
        [rows addObject:row];
        row = [[NSMutableArray alloc] init];
        if (stop != TGMathStopRow)
            break;
    }
    _environmentEnd = previousEnd;

    if (rows.count > 1)
    {
        NSArray *last = rows.lastObject;
        if (last.count == 1 && ((TGMathBox *)last[0])->_width <= 0.0f)
            [rows removeLastObject];
    }

    NSUInteger columns = 0;
    for (NSArray *cells in rows)
        columns = MAX(columns, cells.count);
    CGFloat size = [self sizeForStyle:style];
    bool cases = [environment isEqualToString:@"cases"];
    bool aligned = [environment isEqualToString:@"aligned"] || [environment isEqualToString:@"align"] || [environment isEqualToString:@"align*"];
    CGFloat columnGap = aligned ? 0.0f : (cases ? size : size * 0.8f);
    CGFloat rowGap = size * 0.28f;

    NSMutableArray *columnWidths = [[NSMutableArray alloc] init];
    for (NSUInteger column = 0; column < columns; column++)
    {
        CGFloat width = 0.0f;
        for (NSArray *cells in rows)
        {
            if (column < cells.count)
                width = MAX(width, ((TGMathBox *)cells[column])->_width);
        }
        [columnWidths addObject:@(width)];
    }

    NSMutableArray *rowAscents = [[NSMutableArray alloc] init];
    NSMutableArray *rowDescents = [[NSMutableArray alloc] init];
    CGFloat totalHeight = 0.0f;
    CGFloat strut = size * 0.7f;
    for (NSArray *cells in rows)
    {
        CGFloat ascent = strut;
        CGFloat descent = size * 0.3f;
        for (TGMathBox *cell in cells)
        {
            ascent = MAX(ascent, cell->_ascent);
            descent = MAX(descent, cell->_descent);
        }
        [rowAscents addObject:@(ascent)];
        [rowDescents addObject:@(descent)];
        totalHeight += ascent + descent;
    }
    totalHeight += rowGap * (CGFloat)MAX(0, (NSInteger)rows.count - 1);

    TGMathBox *grid = [[TGMathBox alloc] init];
    grid->_mathClass = TGMathClassInner;
    grid->_size = size;
    CGFloat axis = [self axisForStyle:style];
    CGFloat top = axis + totalHeight / 2.0f;
    CGFloat y = top;
    CGFloat totalWidth = 0.0f;
    for (NSNumber *width in columnWidths)
        totalWidth += width.floatValue;
    totalWidth += columnGap * (CGFloat)MAX(0, (NSInteger)columns - 1);
    NSUInteger rowIndex = 0;
    for (NSArray *cells in rows)
    {
        CGFloat ascent = [rowAscents[rowIndex] floatValue];
        CGFloat baselineShift = y - ascent;
        CGFloat x = 0.0f;
        for (NSUInteger column = 0; column < cells.count; column++)
        {
            TGMathBox *cell = cells[column];
            CGFloat columnWidth = [columnWidths[column] floatValue];
            CGFloat cellX = x + (columnWidth - cell->_width) / 2.0f;
            if (cases)
                cellX = x;
            else if (aligned)
                cellX = (column % 2 == 0) ? x + columnWidth - cell->_width : x;
            [grid addChild:cell x:cellX shift:baselineShift];
            x += columnWidth + columnGap;
        }
        y -= ascent + [rowDescents[rowIndex] floatValue] + rowGap;
        rowIndex++;
    }
    grid->_width = totalWidth;
    grid->_ascent = top;
    grid->_descent = MAX(0.0f, totalHeight - top);

    NSString *left = nil;
    NSString *right = nil;
    if ([environment isEqualToString:@"pmatrix"])
    {
        left = @"(";
        right = @")";
    }
    else if ([environment isEqualToString:@"bmatrix"])
    {
        left = @"[";
        right = @"]";
    }
    else if ([environment isEqualToString:@"Bmatrix"])
    {
        left = @"{";
        right = @"}";
    }
    else if ([environment isEqualToString:@"vmatrix"])
    {
        left = @"|";
        right = @"|";
    }
    else if ([environment isEqualToString:@"Vmatrix"])
    {
        left = @"‖";
        right = @"‖";
    }
    else if (cases)
    {
        left = @"{";
        right = @".";
    }
    if (left != nil)
        return [self wrap:grid left:left right:right style:style];
    return grid;
}

- (NSString *)mapDoubleStruck:(NSString *)text
{
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        map = @{@"C": @"ℂ", @"H": @"ℍ", @"N": @"ℕ", @"P": @"ℙ", @"Q": @"ℚ", @"R": @"ℝ", @"Z": @"ℤ"};
    });
    return map[text];
}

- (TGMathBox *)textBox:(NSString *)text fontKind:(TGMathFontKind)fontKind style:(TGMathStyle)style
{
    return TGMathGlyph(text, TGMathFont(fontKind, [self sizeForStyle:style]), TGMathClassOrd);
}

- (TGMathBox *)parseArgumentWithStyle:(TGMathStyle)style fontKind:(TGMathFontKind)fontKind
{
    [self skipWhitespace];
    if ([self peek] == '{')
    {
        _index++;
        TGMathStop stop = TGMathStopEnd;
        NSArray *atoms = [self parseAtomsWithStyle:style fontKind:fontKind stop:&stop];
        return TGMathHList(atoms, style, [self sizeForStyle:style]);
    }
    TGMathBox *atom = [self parseSingleAtomWithStyle:style fontKind:fontKind];
    return atom ?: TGMathSpace(0.0f);
}

- (TGMathBox *)parseSingleAtomWithStyle:(TGMathStyle)style fontKind:(TGMathFontKind)fontKind
{
    TGMathStop stop = TGMathStopEnd;
    bool stopped = false;
    TGMathStyle mutableStyle = style;
    TGMathFontKind mutableFont = fontKind;
    return [self parseAtomWithStyle:&mutableStyle fontKind:&mutableFont stop:&stop stopped:&stopped];
}

- (TGMathBox *)symbolForCommand:(NSString *)name style:(TGMathStyle)style fontKind:(TGMathFontKind)fontKind
{
    static NSDictionary *symbols = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        NSDictionary *lowerGreek = @{@"alpha": @"α", @"beta": @"β", @"gamma": @"γ", @"delta": @"δ", @"epsilon": @"ϵ", @"varepsilon": @"ε", @"zeta": @"ζ", @"eta": @"η", @"theta": @"θ", @"vartheta": @"ϑ", @"iota": @"ι", @"kappa": @"κ", @"lambda": @"λ", @"mu": @"μ", @"nu": @"ν", @"xi": @"ξ", @"pi": @"π", @"varpi": @"ϖ", @"rho": @"ρ", @"varrho": @"ϱ", @"sigma": @"σ", @"varsigma": @"ς", @"tau": @"τ", @"upsilon": @"υ", @"phi": @"ϕ", @"varphi": @"φ", @"chi": @"χ", @"psi": @"ψ", @"omega": @"ω"};
        for (NSString *key in lowerGreek)
            dict[key] = @[lowerGreek[key], @(TGMathClassOrd), @(TGMathFontItalic)];
        NSDictionary *upperGreek = @{@"Gamma": @"Γ", @"Delta": @"Δ", @"Theta": @"Θ", @"Lambda": @"Λ", @"Xi": @"Ξ", @"Pi": @"Π", @"Sigma": @"Σ", @"Upsilon": @"Υ", @"Phi": @"Φ", @"Psi": @"Ψ", @"Omega": @"Ω"};
        for (NSString *key in upperGreek)
            dict[key] = @[upperGreek[key], @(TGMathClassOrd), @(TGMathFontRoman)];
        NSDictionary *binary = @{@"pm": @"±", @"mp": @"∓", @"times": @"×", @"div": @"÷", @"cdot": @"⋅", @"ast": @"∗", @"star": @"⋆", @"circ": @"∘", @"bullet": @"∙", @"oplus": @"⊕", @"ominus": @"⊖", @"otimes": @"⊗", @"odot": @"⊙", @"cup": @"∪", @"cap": @"∩", @"setminus": @"∖", @"wedge": @"∧", @"land": @"∧", @"vee": @"∨", @"lor": @"∨", @"oslash": @"⊘", @"dagger": @"†"};
        for (NSString *key in binary)
            dict[key] = @[binary[key], @(TGMathClassBin), @(TGMathFontRoman)];
        NSDictionary *relations = @{@"leq": @"≤", @"le": @"≤", @"geq": @"≥", @"ge": @"≥", @"neq": @"≠", @"ne": @"≠", @"approx": @"≈", @"equiv": @"≡", @"sim": @"∼", @"simeq": @"≃", @"cong": @"≅", @"propto": @"∝", @"ll": @"≪", @"gg": @"≫", @"in": @"∈", @"notin": @"∉", @"ni": @"∋", @"subset": @"⊂", @"supset": @"⊃", @"subseteq": @"⊆", @"supseteq": @"⊇", @"to": @"→", @"rightarrow": @"→", @"leftarrow": @"←", @"gets": @"←", @"leftrightarrow": @"↔", @"Rightarrow": @"⇒", @"Leftarrow": @"⇐", @"Leftrightarrow": @"⇔", @"implies": @"⟹", @"iff": @"⟺", @"impliedby": @"⟸", @"mapsto": @"↦", @"longrightarrow": @"⟶", @"longleftarrow": @"⟵", @"perp": @"⊥", @"parallel": @"∥", @"mid": @"∣", @"models": @"⊨", @"vdash": @"⊢", @"uparrow": @"↑", @"downarrow": @"↓", @"prec": @"≺", @"succ": @"≻", @"preceq": @"⪯", @"succeq": @"⪰", @"asymp": @"≍", @"doteq": @"≐", @"coloneqq": @"≔"};
        for (NSString *key in relations)
            dict[key] = @[relations[key], @(TGMathClassRel), @(TGMathFontRoman)];
        NSDictionary *ordinary = @{@"infty": @"∞", @"partial": @"∂", @"nabla": @"∇", @"forall": @"∀", @"exists": @"∃", @"nexists": @"∄", @"emptyset": @"∅", @"varnothing": @"∅", @"neg": @"¬", @"lnot": @"¬", @"angle": @"∠", @"triangle": @"△", @"hbar": @"ℏ", @"ell": @"ℓ", @"Re": @"ℜ", @"Im": @"ℑ", @"aleph": @"ℵ", @"prime": @"′", @"ldots": @"…", @"dots": @"…", @"cdots": @"⋯", @"vdots": @"⋮", @"ddots": @"⋱", @"degree": @"°", @"top": @"⊤", @"bot": @"⊥", @"square": @"□", @"Box": @"□", @"checkmark": @"✓", @"%": @"%", @"$": @"$", @"&": @"&", @"#": @"#", @"_": @"_", @"{": @"{", @"}": @"}", @"|": @"‖", @"backslash": @"\\", @"langle": @"⟨", @"rangle": @"⟩", @"lfloor": @"⌊", @"rfloor": @"⌋", @"lceil": @"⌈", @"rceil": @"⌉", @"vert": @"|", @"Vert": @"‖", @"lbrace": @"{", @"rbrace": @"}"};
        for (NSString *key in ordinary)
            dict[key] = @[ordinary[key], @(TGMathClassOrd), @(TGMathFontRoman)];
        for (NSString *key in @[@"langle", @"lfloor", @"lceil", @"lbrace", @"{"])
            dict[key] = @[ordinary[key], @(TGMathClassOpen), @(TGMathFontRoman)];
        for (NSString *key in @[@"rangle", @"rfloor", @"rceil", @"rbrace", @"}"])
            dict[key] = @[ordinary[key], @(TGMathClassClose), @(TGMathFontRoman)];
        symbols = dict;
    });

    NSArray *symbol = symbols[name];
    if (symbol == nil)
        return nil;
    TGMathFontKind kind = (TGMathFontKind)[symbol[2] intValue];
    if (fontKind == TGMathFontBold || fontKind == TGMathFontBoldItalic)
        kind = kind == TGMathFontItalic ? TGMathFontBoldItalic : TGMathFontBold;
    return TGMathGlyph(symbol[0], TGMathFont(kind, [self sizeForStyle:style]), (TGMathClass)[symbol[1] intValue]);
}

- (TGMathBox *)parseCommand:(NSString *)name style:(TGMathStyle *)style fontKind:(TGMathFontKind *)fontKind stop:(TGMathStop *)stop stopped:(bool *)stopped
{
    TGMathStyle currentStyle = *style;
    CGFloat size = [self sizeForStyle:currentStyle];

    if ([name isEqualToString:@"\\"])
    {
        *stop = TGMathStopRow;
        *stopped = true;
        return nil;
    }
    if ([name isEqualToString:@"right"])
    {
        *stop = TGMathStopRight;
        *stopped = true;
        return nil;
    }
    if ([name isEqualToString:@"end"])
    {
        [self readRawGroup];
        *stop = TGMathStopEnvironmentEnd;
        *stopped = true;
        return nil;
    }

    static NSDictionary *spaces = nil;
    static NSSet *largeOperatorsWithLimits = nil;
    static NSDictionary *largeOperators = nil;
    static NSSet *functions = nil;
    static NSSet *functionsWithLimits = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        spaces = @{@",": @(3.0f / 18.0f), @":": @(4.0f / 18.0f), @">": @(4.0f / 18.0f), @";": @(5.0f / 18.0f), @"!": @(-3.0f / 18.0f), @" ": @(6.0f / 18.0f), @"quad": @(1.0f), @"qquad": @(2.0f), @"enspace": @(0.5f), @"thinspace": @(3.0f / 18.0f)};
        largeOperators = @{@"sum": @"∑", @"prod": @"∏", @"coprod": @"∐", @"bigcup": @"⋃", @"bigcap": @"⋂", @"bigoplus": @"⨁", @"bigotimes": @"⨂", @"bigvee": @"⋁", @"bigwedge": @"⋀", @"int": @"∫", @"iint": @"∬", @"iiint": @"∭", @"oint": @"∮"};
        largeOperatorsWithLimits = [NSSet setWithArray:@[@"sum", @"prod", @"coprod", @"bigcup", @"bigcap", @"bigoplus", @"bigotimes", @"bigvee", @"bigwedge"]];
        functions = [NSSet setWithArray:@[@"sin", @"cos", @"tan", @"cot", @"sec", @"csc", @"arcsin", @"arccos", @"arctan", @"sinh", @"cosh", @"tanh", @"coth", @"log", @"ln", @"lg", @"exp", @"det", @"dim", @"ker", @"deg", @"arg", @"gcd", @"hom", @"lim", @"limsup", @"liminf", @"max", @"min", @"sup", @"inf", @"Pr"]];
        functionsWithLimits = [NSSet setWithArray:@[@"lim", @"limsup", @"liminf", @"max", @"min", @"sup", @"inf", @"Pr", @"det", @"gcd"]];
    });

    NSNumber *space = spaces[name];
    if (space != nil)
        return TGMathSpace(size * space.floatValue);

    if ([name isEqualToString:@"displaystyle"])
    {
        *style = TGMathStyleDisplay;
        return nil;
    }
    if ([name isEqualToString:@"textstyle"])
    {
        *style = TGMathStyleText;
        return nil;
    }
    if ([name isEqualToString:@"scriptstyle"])
    {
        *style = TGMathStyleScript;
        return nil;
    }
    if ([name isEqualToString:@"scriptscriptstyle"])
    {
        *style = TGMathStyleScriptScript;
        return nil;
    }
    if ([name isEqualToString:@"bf"])
    {
        *fontKind = TGMathFontBold;
        return nil;
    }
    if ([name isEqualToString:@"rm"])
    {
        *fontKind = TGMathFontRoman;
        return nil;
    }
    if ([name isEqualToString:@"it"])
    {
        *fontKind = TGMathFontItalic;
        return nil;
    }
    if ([name isEqualToString:@"left"])
    {
        NSString *left = [self readDelimiter];
        TGMathStop innerStop = TGMathStopEnd;
        NSArray *atoms = [self parseAtomsWithStyle:currentStyle fontKind:*fontKind stop:&innerStop];
        NSString *right = innerStop == TGMathStopRight ? [self readDelimiter] : @".";
        return [self wrap:TGMathHList(atoms, currentStyle, size) left:left right:right style:currentStyle];
    }
    if ([name isEqualToString:@"middle"])
    {
        NSString *delimiter = [self readDelimiter];
        return TGMathGlyph(delimiter, TGMathFont(TGMathFontRoman, size), TGMathClassRel);
    }
    if ([name isEqualToString:@"big"] || [name isEqualToString:@"Big"] || [name isEqualToString:@"bigg"] || [name isEqualToString:@"Bigg"] || [name hasPrefix:@"bigl"] || [name hasPrefix:@"bigr"] || [name hasPrefix:@"Bigl"] || [name hasPrefix:@"Bigr"])
    {
        NSString *delimiter = [self readDelimiter];
        CGFloat factor = [name hasPrefix:@"bigg"] || [name hasPrefix:@"Bigg"] ? ([name hasPrefix:@"B"] ? 2.4f : 2.0f) : ([name hasPrefix:@"B"] ? 1.6f : 1.25f);
        CGFloat half = size * factor / 2.0f;
        CGFloat axis = [self axisForStyle:currentStyle];
        bool left = [name hasSuffix:@"l"] || [delimiter isEqualToString:@"("] || [delimiter isEqualToString:@"["] || [delimiter isEqualToString:@"{"] || [delimiter isEqualToString:@"⟨"];
        return [self delimiter:delimiter forAscent:axis + half descent:half - axis style:currentStyle left:left];
    }
    if ([name isEqualToString:@"frac"] || [name isEqualToString:@"dfrac"] || [name isEqualToString:@"tfrac"] || [name isEqualToString:@"cfrac"])
    {
        TGMathStyle fractionStyle = currentStyle;
        if ([name isEqualToString:@"dfrac"] || [name isEqualToString:@"cfrac"])
            fractionStyle = TGMathStyleDisplay;
        else if ([name isEqualToString:@"tfrac"])
            fractionStyle = TGMathStyleText;
        TGMathStyle childStyle = TGMathFractionStyle(fractionStyle);
        TGMathBox *numerator = [self parseArgumentWithStyle:childStyle fontKind:*fontKind];
        TGMathBox *denominator = [self parseArgumentWithStyle:childStyle fontKind:*fontKind];
        return [self fractionWithNumerator:numerator denominator:denominator style:fractionStyle rule:true];
    }
    if ([name isEqualToString:@"binom"] || [name isEqualToString:@"dbinom"] || [name isEqualToString:@"tbinom"])
    {
        TGMathStyle fractionStyle = [name isEqualToString:@"dbinom"] ? TGMathStyleDisplay : ([name isEqualToString:@"tbinom"] ? TGMathStyleText : currentStyle);
        TGMathStyle childStyle = TGMathFractionStyle(fractionStyle);
        TGMathBox *top = [self parseArgumentWithStyle:childStyle fontKind:*fontKind];
        TGMathBox *bottom = [self parseArgumentWithStyle:childStyle fontKind:*fontKind];
        TGMathBox *fraction = [self fractionWithNumerator:top denominator:bottom style:fractionStyle rule:false];
        return [self wrap:fraction left:@"(" right:@")" style:fractionStyle];
    }
    if ([name isEqualToString:@"sqrt"])
    {
        [self skipWhitespace];
        TGMathBox *indexBox = nil;
        if ([self peek] == '[')
        {
            _index++;
            TGMathStop innerStop = TGMathStopEnd;
            NSArray *atoms = [self parseAtomsWithStyle:TGMathStyleScriptScript fontKind:*fontKind stop:&innerStop bracketTerminates:true];
            indexBox = TGMathHList(atoms, TGMathStyleScriptScript, [self sizeForStyle:TGMathStyleScriptScript]);
        }
        TGMathBox *body = [self parseArgumentWithStyle:currentStyle fontKind:*fontKind];
        return [self radical:body index:indexBox style:currentStyle];
    }
    if ([name isEqualToString:@"text"] || [name isEqualToString:@"textrm"] || [name isEqualToString:@"textnormal"] || [name isEqualToString:@"mbox"] || [name isEqualToString:@"textbf"] || [name isEqualToString:@"textit"] || [name isEqualToString:@"texttt"] || [name isEqualToString:@"textsf"])
    {
        NSString *raw = [self readRawGroup];
        TGMathFontKind kind = TGMathFontRoman;
        if ([name isEqualToString:@"textbf"])
            kind = TGMathFontBold;
        else if ([name isEqualToString:@"textit"])
            kind = TGMathFontItalic;
        else if ([name isEqualToString:@"texttt"])
            kind = TGMathFontMono;
        else if ([name isEqualToString:@"textsf"])
            kind = TGMathFontSans;
        return [self textBox:raw fontKind:kind style:currentStyle];
    }
    if ([name isEqualToString:@"operatorname"])
    {
        NSString *raw = [self readRawGroup];
        TGMathBox *box = [self textBox:raw fontKind:TGMathFontRoman style:currentStyle];
        box->_mathClass = TGMathClassOp;
        return box;
    }
    if ([name isEqualToString:@"mathrm"] || [name isEqualToString:@"mathbf"] || [name isEqualToString:@"mathit"] || [name isEqualToString:@"mathsf"] || [name isEqualToString:@"mathtt"] || [name isEqualToString:@"mathcal"] || [name isEqualToString:@"mathscr"] || [name isEqualToString:@"mathbb"] || [name isEqualToString:@"boldsymbol"] || [name isEqualToString:@"bm"] || [name isEqualToString:@"mathfrak"])
    {
        TGMathFontKind kind = TGMathFontRoman;
        if ([name isEqualToString:@"mathbf"])
            kind = TGMathFontBold;
        else if ([name isEqualToString:@"boldsymbol"] || [name isEqualToString:@"bm"])
            kind = TGMathFontBoldItalic;
        else if ([name isEqualToString:@"mathit"] || [name isEqualToString:@"mathcal"] || [name isEqualToString:@"mathscr"])
            kind = TGMathFontItalic;
        else if ([name isEqualToString:@"mathsf"])
            kind = TGMathFontSans;
        else if ([name isEqualToString:@"mathtt"])
            kind = TGMathFontMono;
        else if ([name isEqualToString:@"mathbb"])
            kind = TGMathFontDoubleStruck;
        return [self parseArgumentWithStyle:currentStyle fontKind:kind];
    }
    if ([name isEqualToString:@"overline"] || [name isEqualToString:@"underline"] || [name isEqualToString:@"hat"] || [name isEqualToString:@"widehat"] || [name isEqualToString:@"bar"] || [name isEqualToString:@"vec"] || [name isEqualToString:@"overrightarrow"] || [name isEqualToString:@"tilde"] || [name isEqualToString:@"widetilde"] || [name isEqualToString:@"dot"] || [name isEqualToString:@"ddot"])
    {
        TGMathBox *body = [self parseArgumentWithStyle:currentStyle fontKind:*fontKind];
        return [self accent:name body:body style:currentStyle];
    }
    if ([name isEqualToString:@"begin"])
    {
        NSString *environment = [self readRawGroup];
        return [self matrixForEnvironment:environment style:currentStyle fontKind:*fontKind];
    }
    if ([name isEqualToString:@"not"])
    {
        TGMathBox *body = [self parseSingleAtomWithStyle:currentStyle fontKind:*fontKind];
        if (body == nil)
            return nil;
        TGMathBox *box = [[TGMathBox alloc] init];
        box->_mathClass = body->_mathClass;
        box->_width = body->_width;
        box->_ascent = body->_ascent;
        box->_descent = body->_descent;
        [box addChild:body x:0.0f shift:0.0f];
        CGFloat width = body->_width;
        CGFloat ascent = body->_ascent;
        CGFloat descent = body->_descent;
        CGFloat rule = [self ruleForStyle:currentStyle];
        box->_drawPaths = ^(CGContextRef context, CGFloat x, CGFloat baseline)
        {
            TGMathStrokeLine(context, CGPointMake(x + width * 0.75f, baseline - ascent), CGPointMake(x + width * 0.25f, baseline + descent), rule);
        };
        return box;
    }

    NSString *largeOperator = largeOperators[name];
    if (largeOperator != nil)
        return [self largeOperator:largeOperator style:currentStyle limitsByDefault:[largeOperatorsWithLimits containsObject:name]];

    if ([functions containsObject:name])
    {
        TGMathBox *box = [self textBox:name fontKind:TGMathFontRoman style:currentStyle];
        box->_mathClass = TGMathClassOp;
        if ([functionsWithLimits containsObject:name])
        {
            box->_largeOperator = true;
            box->_limits = 0;
        }
        return box;
    }

    TGMathBox *symbol = [self symbolForCommand:name style:currentStyle fontKind:*fontKind];
    if (symbol != nil)
        return symbol;

    return [self textBox:[@"\\" stringByAppendingString:name] fontKind:TGMathFontRoman style:currentStyle];
}

- (TGMathBox *)parseAtomWithStyle:(TGMathStyle *)style fontKind:(TGMathFontKind *)fontKind stop:(TGMathStop *)stop stopped:(bool *)stopped
{
    return [self parseAtomWithStyle:style fontKind:fontKind stop:stop stopped:stopped bracketTerminates:false];
}

- (TGMathBox *)parseAtomWithStyle:(TGMathStyle *)style fontKind:(TGMathFontKind *)fontKind stop:(TGMathStop *)stop stopped:(bool *)stopped bracketTerminates:(bool)bracketTerminates
{
    if (_depth >= 40)
    {
        NSString *rest = _index < _source.length ? [_source substringFromIndex:_index] : @"";
        _index = _source.length;
        *stop = TGMathStopEnd;
        *stopped = rest.length == 0;
        return rest.length == 0 ? nil : TGMathGlyph(rest, TGMathFont(TGMathFontRoman, [self sizeForStyle:*style]), TGMathClassOrd);
    }
    _depth++;
    TGMathBox *atom = [self parseAtomBodyWithStyle:style fontKind:fontKind stop:stop stopped:stopped bracketTerminates:bracketTerminates];
    _depth--;
    return atom;
}

- (TGMathBox *)parseAtomBodyWithStyle:(TGMathStyle *)style fontKind:(TGMathFontKind *)fontKind stop:(TGMathStop *)stop stopped:(bool *)stopped bracketTerminates:(bool)bracketTerminates
{
    [self skipWhitespace];
    if ([self atEnd])
    {
        *stop = TGMathStopEnd;
        *stopped = true;
        return nil;
    }

    unichar c = [self peek];
    TGMathStyle currentStyle = *style;
    CGFloat size = [self sizeForStyle:currentStyle];

    if (c == '}')
    {
        _index++;
        *stop = TGMathStopBrace;
        *stopped = true;
        return nil;
    }
    if (c == ']' && bracketTerminates)
    {
        _index++;
        *stop = TGMathStopBracket;
        *stopped = true;
        return nil;
    }
    if (c == '&')
    {
        _index++;
        if (_environmentEnd != nil)
        {
            *stop = TGMathStopCell;
            *stopped = true;
        }
        return nil;
    }
    if (c == '{')
    {
        _index++;
        TGMathStop innerStop = TGMathStopEnd;
        NSArray *atoms = [self parseAtomsWithStyle:currentStyle fontKind:*fontKind stop:&innerStop];
        return TGMathHList(atoms, currentStyle, size);
    }
    if (c == '\\')
    {
        NSString *name = [self readCommandName];
        if (name.length == 0)
            return nil;
        return [self parseCommand:name style:style fontKind:fontKind stop:stop stopped:stopped];
    }

    _index++;
    if (c >= '0' && c <= '9')
    {
        NSUInteger start = _index - 1;
        while (![self atEnd])
        {
            unichar d = [self peek];
            if (!((d >= '0' && d <= '9') || d == '.'))
                break;
            _index++;
        }
        NSString *number = [_source substringWithRange:NSMakeRange(start, _index - start)];
        TGMathFontKind kind = (*fontKind == TGMathFontBold || *fontKind == TGMathFontBoldItalic) ? TGMathFontBold : (*fontKind == TGMathFontSans || *fontKind == TGMathFontMono ? *fontKind : TGMathFontRoman);
        return TGMathGlyph(number, TGMathFont(kind, size), TGMathClassOrd);
    }
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
    {
        NSString *letter = [NSString stringWithCharacters:&c length:1];
        TGMathFontKind kind = *fontKind;
        if (kind == TGMathFontDoubleStruck)
        {
            NSString *mapped = [self mapDoubleStruck:letter];
            if (mapped != nil)
                return TGMathGlyph(mapped, TGMathFont(TGMathFontRoman, size), TGMathClassOrd);
            kind = TGMathFontBold;
        }
        return TGMathGlyph(letter, TGMathFont(kind, size), TGMathClassOrd);
    }

    NSString *string = [NSString stringWithCharacters:&c length:1];
    TGMathClass mathClass = TGMathClassOrd;
    switch (c)
    {
        case '+':
            mathClass = TGMathClassBin;
            break;
        case '-':
            mathClass = TGMathClassBin;
            string = @"−";
            break;
        case '*':
            mathClass = TGMathClassBin;
            string = @"∗";
            break;
        case '=':
        case '<':
        case '>':
        case ':':
            mathClass = TGMathClassRel;
            break;
        case ',':
        case ';':
            mathClass = TGMathClassPunct;
            break;
        case '(':
        case '[':
            mathClass = TGMathClassOpen;
            break;
        case ')':
        case ']':
        case '!':
        case '?':
            mathClass = TGMathClassClose;
            break;
        case '\'':
            string = @"′";
            break;
        default:
            break;
    }
    return TGMathGlyph(string, TGMathFont(TGMathFontRoman, size), mathClass);
}

- (NSArray *)parseAtomsWithStyle:(TGMathStyle)style fontKind:(TGMathFontKind)fontKind stop:(TGMathStop *)stop
{
    return [self parseAtomsWithStyle:style fontKind:fontKind stop:stop bracketTerminates:false];
}

- (NSArray *)parseAtomsWithStyle:(TGMathStyle)initialStyle fontKind:(TGMathFontKind)initialFontKind stop:(TGMathStop *)stop bracketTerminates:(bool)bracketTerminates
{
    NSMutableArray *atoms = [[NSMutableArray alloc] init];
    TGMathStyle style = initialStyle;
    TGMathFontKind fontKind = initialFontKind;
    *stop = TGMathStopEnd;

    if (_depth >= 40)
    {
        NSString *rest = _index < _source.length ? [_source substringFromIndex:_index] : @"";
        _index = _source.length;
        if (rest.length != 0)
            [atoms addObject:TGMathGlyph(rest, TGMathFont(TGMathFontRoman, [self sizeForStyle:style]), TGMathClassOrd)];
        return atoms;
    }
    _depth++;

    while (true)
    {
        [self skipWhitespace];
        if ([self atEnd])
        {
            *stop = TGMathStopEnd;
            break;
        }

        unichar c = [self peek];
        if (c == '^' || c == '_' || c == '\'')
        {
            TGMathBox *base = atoms.lastObject;
            if (base != nil)
                [atoms removeLastObject];
            else
                base = TGMathSpace(0.0f);
            TGMathBox *superscript = nil;
            TGMathBox *subscript = nil;
            TGMathStyle scriptStyle = TGMathScriptStyle(style);
            while (true)
            {
                [self skipWhitespace];
                unichar d = [self peek];
                if (d == '^' && superscript == nil)
                {
                    _index++;
                    superscript = [self parseArgumentWithStyle:scriptStyle fontKind:fontKind];
                }
                else if (d == '_' && subscript == nil)
                {
                    _index++;
                    subscript = [self parseArgumentWithStyle:scriptStyle fontKind:fontKind];
                }
                else if (d == '\'' && superscript == nil)
                {
                    NSMutableString *primes = [[NSMutableString alloc] init];
                    while ([self peek] == '\'')
                    {
                        [primes appendString:@"′"];
                        _index++;
                    }
                    superscript = TGMathGlyph(primes, TGMathFont(TGMathFontRoman, [self sizeForStyle:scriptStyle]), TGMathClassOrd);
                }
                else
                    break;
            }
            [atoms addObject:[self attachScriptsToBase:base superscript:superscript subscript:subscript style:style]];
            continue;
        }

        if (c == '\\')
        {
            NSUInteger savedIndex = _index;
            NSString *name = [self readCommandName];
            if ([name isEqualToString:@"limits"] || [name isEqualToString:@"nolimits"])
            {
                TGMathBox *last = atoms.lastObject;
                if (last != nil)
                    last->_limits = [name isEqualToString:@"limits"] ? 1 : 2;
                continue;
            }
            _index = savedIndex;
        }

        bool stopped = false;
        TGMathBox *atom = [self parseAtomWithStyle:&style fontKind:&fontKind stop:stop stopped:&stopped bracketTerminates:bracketTerminates];
        if (stopped)
            break;
        if (atom != nil)
            [atoms addObject:atom];
    }
    _depth--;
    return atoms;
}

- (TGMathBox *)parseRootWithStyle:(TGMathStyle)style
{
    NSMutableArray *atoms = [[NSMutableArray alloc] init];
    while (![self atEnd])
    {
        TGMathStop stop = TGMathStopEnd;
        [atoms addObjectsFromArray:[self parseAtomsWithStyle:style fontKind:TGMathFontItalic stop:&stop]];
        if (stop == TGMathStopEnd)
            break;
    }
    return TGMathHList(atoms, style, [self sizeForStyle:style]);
}

@end

@interface TGRichMessageMathLayout ()
{
    TGMathBox *_box;
}

@end

@implementation TGRichMessageMathLayout

+ (instancetype)layoutWithSource:(NSString *)source fontSize:(CGFloat)fontSize display:(bool)display
{
    TGMathParser *parser = [[TGMathParser alloc] initWithSource:[source stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] baseSize:fontSize];
    TGMathBox *box = [parser parseRootWithStyle:display ? TGMathStyleDisplay : TGMathStyleText];
    TGRichMessageMathLayout *layout = [[TGRichMessageMathLayout alloc] init];
    layout->_box = box;
    layout->_width = ceil(box->_width);
    layout->_ascent = ceil(box->_ascent);
    layout->_descent = ceil(box->_descent);
    return layout;
}

- (void)drawInContext:(CGContextRef)context baselineOrigin:(CGPoint)origin color:(UIColor *)color
{
    if (_box == nil || context == NULL)
        return;
    CGContextSaveGState(context);
    UIGraphicsPushContext(context);
    [color set];
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetFillColorWithColor(context, color.CGColor);
    [_box drawInContext:context x:origin.x baseline:origin.y];
    UIGraphicsPopContext();
    CGContextRestoreGState(context);
}

@end
