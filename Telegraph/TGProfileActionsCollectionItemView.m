#import "TGProfileActionsCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGProfileActionsCollectionItem.h"
#import "TGPresentation.h"
#import <math.h>

const CGFloat TGProfileActionsCollectionItemViewHeight = 60.0f;

static const CGFloat TGProfileActionGlyphSide = 24.0f;
static const CGFloat TGProfileActionButtonSpacing = 8.0f;
static const CGFloat TGProfileActionHorizontalInset = 15.0f;
static const CGFloat TGProfileActionMaxButtonWidth = 120.0f;

static void TGProfileActionAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat midX = CGRectGetMidX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat midY = CGRectGetMidY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextMoveToPoint(context, minX, midY);
    CGContextAddArcToPoint(context, minX, minY, midX, minY, radius);
    CGContextAddArcToPoint(context, maxX, minY, maxX, midY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, midY, radius);
    CGContextClosePath(context);
}

static void TGProfileActionAddPolyline(CGContextRef context, const CGPoint *points, size_t count)
{
    CGContextMoveToPoint(context, points[0].x, points[0].y);
    for (size_t i = 1; i < count; i++)
        CGContextAddLineToPoint(context, points[i].x, points[i].y);
}

static void TGProfileActionStrokePolyline(CGContextRef context, const CGPoint *points, size_t count, CGFloat lineWidth)
{
    CGContextBeginPath(context);
    TGProfileActionAddPolyline(context, points, count);
    CGContextSetLineWidth(context, lineWidth);
    CGContextStrokePath(context);
}

static void TGProfileActionDrawBell(CGContextRef context)
{
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 12.0f, 3.5f);
    CGContextAddCurveToPoint(context, 7.5f, 3.5f, 6.5f, 7.5f, 6.5f, 11.0f);
    CGContextAddLineToPoint(context, 6.5f, 15.0f);
    CGContextAddLineToPoint(context, 4.5f, 17.5f);
    CGContextAddLineToPoint(context, 19.5f, 17.5f);
    CGContextAddLineToPoint(context, 17.5f, 15.0f);
    CGContextAddLineToPoint(context, 17.5f, 11.0f);
    CGContextAddCurveToPoint(context, 17.5f, 7.5f, 16.5f, 3.5f, 12.0f, 3.5f);
    CGContextClosePath(context);
    CGContextFillPath(context);
    CGContextFillEllipseInRect(context, CGRectMake(10.75f, 1.75f, 2.5f, 2.5f));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 14.5f, 19.0f);
    CGContextAddArc(context, 12.0f, 19.0f, 2.5f, 0.0f, (CGFloat)M_PI, 0);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

static void TGProfileActionAddHeart(CGContextRef context)
{
    CGContextMoveToPoint(context, 12.0f, 20.5f);
    CGContextAddCurveToPoint(context, 4.0f, 15.0f, 2.0f, 11.5f, 2.0f, 8.5f);
    CGContextAddCurveToPoint(context, 2.0f, 5.2f, 4.6f, 3.0f, 7.4f, 3.0f);
    CGContextAddCurveToPoint(context, 9.4f, 3.0f, 11.0f, 4.1f, 12.0f, 5.8f);
    CGContextAddCurveToPoint(context, 13.0f, 4.1f, 14.6f, 3.0f, 16.6f, 3.0f);
    CGContextAddCurveToPoint(context, 19.4f, 3.0f, 22.0f, 5.2f, 22.0f, 8.5f);
    CGContextAddCurveToPoint(context, 22.0f, 11.5f, 20.0f, 15.0f, 12.0f, 20.5f);
    CGContextClosePath(context);
}

static void TGProfileActionDrawGlyph(CGContextRef context, TGProfileActionIcon icon)
{
    switch (icon)
    {
        case TGProfileActionIconHeart:
            CGContextBeginPath(context);
            TGProfileActionAddHeart(context);
            CGContextSetLineWidth(context, 2.0f);
            CGContextStrokePath(context);
            break;
        case TGProfileActionIconHeartFilled:
            CGContextBeginPath(context);
            TGProfileActionAddHeart(context);
            CGContextFillPath(context);
            break;
        case TGProfileActionIconMessage:
        {
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(2.0f, 3.0f, 20.0f, 15.0f), 5.0f);
            CGContextFillPath(context);
            CGPoint tail[] = {{6.0f, 16.0f}, {4.5f, 21.5f}, {11.0f, 17.5f}};
            CGContextBeginPath(context);
            TGProfileActionAddPolyline(context, tail, 3);
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        }
        case TGProfileActionIconCall:
        {
            CGContextBeginPath(context);
            CGContextAddArc(context, 17.0f, 7.0f, 11.0f, (CGFloat)M_PI, (CGFloat)M_PI_2, 1);
            CGContextSetLineWidth(context, 4.5f);
            CGContextStrokePath(context);
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(3.0f, 2.5f, 8.0f, 6.0f), 2.5f);
            TGProfileActionAddRoundedRect(context, CGRectMake(15.5f, 13.0f, 6.0f, 8.0f), 2.5f);
            CGContextFillPath(context);
            break;
        }
        case TGProfileActionIconMute:
            TGProfileActionDrawBell(context);
            break;
        case TGProfileActionIconUnmute:
        {
            TGProfileActionDrawBell(context);
            CGPoint slash[] = {{3.5f, 2.5f}, {20.5f, 21.5f}};
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            TGProfileActionStrokePolyline(context, slash, 2, 4.5f);
            CGContextRestoreGState(context);
            TGProfileActionStrokePolyline(context, slash, 2, 1.8f);
            break;
        }
        case TGProfileActionIconShare:
        {
            CGPoint shaft[] = {{12.0f, 2.5f}, {12.0f, 14.0f}};
            CGPoint head[] = {{8.0f, 6.5f}, {12.0f, 2.5f}, {16.0f, 6.5f}};
            CGPoint box[] = {{9.0f, 9.5f}, {6.0f, 9.5f}, {6.0f, 21.0f}, {18.0f, 21.0f}, {18.0f, 9.5f}, {15.0f, 9.5f}};
            TGProfileActionStrokePolyline(context, shaft, 2, 2.0f);
            TGProfileActionStrokePolyline(context, head, 3, 2.0f);
            TGProfileActionStrokePolyline(context, box, 6, 2.0f);
            break;
        }
        case TGProfileActionIconLeave:
        {
            CGPoint door[] = {{13.0f, 8.0f}, {13.0f, 4.0f}, {4.0f, 4.0f}, {4.0f, 20.0f}, {13.0f, 20.0f}, {13.0f, 16.0f}};
            CGPoint shaft[] = {{9.0f, 12.0f}, {21.0f, 12.0f}};
            CGPoint head[] = {{17.0f, 8.0f}, {21.0f, 12.0f}, {17.0f, 16.0f}};
            TGProfileActionStrokePolyline(context, door, 6, 2.0f);
            TGProfileActionStrokePolyline(context, shaft, 2, 2.0f);
            TGProfileActionStrokePolyline(context, head, 3, 2.0f);
            break;
        }
        case TGProfileActionIconMore:
        {
            CGFloat radius = 2.2f;
            for (int i = 0; i < 3; i++)
                CGContextFillEllipseInRect(context, CGRectMake(5.0f + 7.0f * i - radius, 12.0f - radius, radius * 2.0f, radius * 2.0f));
            break;
        }
        case TGProfileActionIconAddMember:
        {
            CGContextFillEllipseInRect(context, CGRectMake(5.0f, 3.0f, 8.0f, 8.0f));
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(1.5f, 13.5f, 15.0f, 8.0f), 4.0f);
            CGContextFillPath(context);
            CGPoint vertical[] = {{19.5f, 4.5f}, {19.5f, 11.5f}};
            CGPoint horizontal[] = {{16.0f, 8.0f}, {23.0f, 8.0f}};
            TGProfileActionStrokePolyline(context, vertical, 2, 2.0f);
            TGProfileActionStrokePolyline(context, horizontal, 2, 2.0f);
            break;
        }
        case TGProfileActionIconSearch:
        {
            CGContextSetLineWidth(context, 2.2f);
            CGContextStrokeEllipseInRect(context, CGRectMake(4.0f, 4.0f, 13.0f, 13.0f));
            CGPoint handle[] = {{15.5f, 15.5f}, {20.5f, 20.5f}};
            TGProfileActionStrokePolyline(context, handle, 2, 2.8f);
            break;
        }
        case TGProfileActionIconEdit:
        {
            CGPoint pencil[] = {{16.0f, 3.0f}, {21.0f, 8.0f}, {9.5f, 19.5f}, {3.5f, 20.5f}, {4.5f, 14.5f}};
            CGContextBeginPath(context);
            TGProfileActionAddPolyline(context, pencil, 5);
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        }
        case TGProfileActionIconCamera:
        {
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(2.0f, 6.5f, 20.0f, 14.0f), 3.5f);
            TGProfileActionAddRoundedRect(context, CGRectMake(8.0f, 4.0f, 8.0f, 4.0f), 1.5f);
            CGContextFillPath(context);
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextFillEllipseInRect(context, CGRectMake(12.0f - 4.2f, 13.5f - 4.2f, 8.4f, 8.4f));
            CGContextRestoreGState(context);
            CGContextFillEllipseInRect(context, CGRectMake(12.0f - 2.6f, 13.5f - 2.6f, 5.2f, 5.2f));
            break;
        }
        case TGProfileActionIconGift:
        {
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(4.0f, 11.5f, 16.0f, 9.5f), 1.5f);
            TGProfileActionAddRoundedRect(context, CGRectMake(2.5f, 7.5f, 19.0f, 4.0f), 1.5f);
            CGContextFillPath(context);
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextFillRect(context, CGRectMake(11.0f, 7.0f, 2.0f, 15.0f));
            CGContextFillRect(context, CGRectMake(2.0f, 11.0f, 20.0f, 1.0f));
            CGContextRestoreGState(context);
            CGContextSetLineWidth(context, 1.8f);
            CGContextStrokeEllipseInRect(context, CGRectMake(6.0f, 2.5f, 5.5f, 4.5f));
            CGContextStrokeEllipseInRect(context, CGRectMake(12.5f, 2.5f, 5.5f, 4.5f));
            break;
        }
        case TGProfileActionIconStory:
        {
            CGContextSetLineWidth(context, 2.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(3.0f, 3.0f, 18.0f, 18.0f));
            CGPoint vertical[] = {{12.0f, 8.0f}, {12.0f, 16.0f}};
            CGPoint horizontal[] = {{8.0f, 12.0f}, {16.0f, 12.0f}};
            TGProfileActionStrokePolyline(context, vertical, 2, 2.0f);
            TGProfileActionStrokePolyline(context, horizontal, 2, 2.0f);
            break;
        }
        case TGProfileActionIconSettings:
        {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, 12.0f, 12.0f);
            for (int i = 0; i < 8; i++)
            {
                CGContextBeginPath(context);
                TGProfileActionAddRoundedRect(context, CGRectMake(-2.25f, -10.5f, 4.5f, 5.0f), 1.0f);
                CGContextFillPath(context);
                CGContextRotateCTM(context, (CGFloat)(M_PI / 4.0));
            }
            CGContextRestoreGState(context);
            CGContextFillEllipseInRect(context, CGRectMake(4.5f, 4.5f, 15.0f, 15.0f));
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextFillEllipseInRect(context, CGRectMake(8.5f, 8.5f, 7.0f, 7.0f));
            CGContextRestoreGState(context);
            break;
        }
        case TGProfileActionIconBolt:
        {
            CGPoint points[] = {{13.5f, 2.0f}, {5.0f, 13.5f}, {11.5f, 13.5f}, {10.0f, 22.0f}, {19.0f, 9.5f}, {12.5f, 9.5f}};
            CGContextBeginPath(context);
            TGProfileActionAddPolyline(context, points, sizeof(points) / sizeof(points[0]));
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        }
        case TGProfileActionIconProfile:
        {
            CGContextFillEllipseInRect(context, CGRectMake(7.5f, 2.5f, 9.0f, 9.0f));
            CGContextBeginPath(context);
            TGProfileActionAddRoundedRect(context, CGRectMake(3.5f, 13.5f, 17.0f, 8.5f), 4.25f);
            CGContextFillPath(context);
            break;
        }
    }
}

static void TGProfileActionPrepareGlyphContext(CGContextRef context, UIColor *color)
{
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
}

UIImage *TGProfileActionGlyphImage(TGProfileActionIcon icon, UIColor *color)
{
    CGSize size = CGSizeMake(TGProfileActionGlyphSide, TGProfileActionGlyphSide);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    TGProfileActionPrepareGlyphContext(context, color);
    TGProfileActionDrawGlyph(context, icon);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGProfileActionSettingsIconImage(TGProfileActionIcon icon, UIColor *backgroundColor)
{
    const CGFloat side = 29.0f;
    const CGFloat glyphSide = 19.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextBeginPath(context);
    TGProfileActionAddRoundedRect(context, CGRectMake(0.0f, 0.0f, side, side), 6.5f);
    CGContextFillPath(context);
    CGContextTranslateCTM(context, (side - glyphSide) / 2.0f, (side - glyphSide) / 2.0f);
    CGContextScaleCTM(context, glyphSide / TGProfileActionGlyphSide, glyphSide / TGProfileActionGlyphSide);
    CGContextBeginTransparencyLayer(context, NULL);
    TGProfileActionPrepareGlyphContext(context, [UIColor whiteColor]);
    TGProfileActionDrawGlyph(context, icon);
    CGContextEndTransparencyLayer(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGProfileActionButton : UIControl
{
    UIToolbar *_blurView;
    UIView *_backgroundView;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UIColor *_normalBackgroundColor;
    UIColor *_highlightedBackgroundColor;
}

@property (nonatomic, strong) TGProfileAction *action;
@property (nonatomic, strong) UIColor *buttonColor;
@property (nonatomic, copy) NSDictionary *buttonStyle;

- (void)setPresentation:(TGPresentation *)presentation;

@end

@implementation TGProfileActionButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.isAccessibilityElement = true;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _backgroundView = [[UIView alloc] init];
        _backgroundView.userInteractionEnabled = false;
        _backgroundView.layer.cornerRadius = 10.0f;
        [self addSubview:_backgroundView];

        _iconView = [[UIImageView alloc] init];
        _iconView.userInteractionEnabled = false;
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.userInteractionEnabled = false;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(12.0f);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)setAction:(TGProfileAction *)action
{
    _action = action;
    _titleLabel.text = action.title;
    self.accessibilityLabel = action.title;
}

- (void)setButtonColor:(UIColor *)buttonColor
{
    _buttonColor = buttonColor;
    if (buttonColor != nil)
        _normalBackgroundColor = buttonColor;
    [self updateBackground];
}

- (void)setButtonStyle:(NSDictionary *)buttonStyle
{
    _buttonStyle = [buttonStyle copy];
    CGFloat blur = [_buttonStyle[@"blur"] respondsToSelector:@selector(doubleValue)] ? [_buttonStyle[@"blur"] doubleValue] : 0;
    if (blur > 0.0f && _blurView == nil)
    {
        _blurView = [[UIToolbar alloc] initWithFrame:self.bounds];
        _blurView.userInteractionEnabled = NO;
        _blurView.translucent = YES;
        [self insertSubview:_blurView atIndex:0];
    }
    else if (blur <= 0.0f && _blurView != nil)
    {
        [_blurView removeFromSuperview];
        _blurView = nil;
    }
    [self setNeedsLayout];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _normalBackgroundColor = _buttonColor ?: presentation.pallete.collectionMenuCellBackgroundColor;
    _highlightedBackgroundColor = presentation.pallete.collectionMenuCellSelectionColor;
    UIColor *tintColor = _action.destructive || _action.selected ? presentation.pallete.collectionMenuDestructiveColor : presentation.pallete.collectionMenuAccentColor;
    _titleLabel.textColor = tintColor;
    _iconView.image = tintColor == nil ? nil : TGProfileActionGlyphImage(_action.icon, tintColor);
    [self updateBackground];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateBackground];
}

- (void)updateBackground
{
    _backgroundView.backgroundColor = self.highlighted ? _highlightedBackgroundColor : _normalBackgroundColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _backgroundView.frame = bounds;
    CGFloat radius = _buttonStyle != nil ? MIN(bounds.size.width, bounds.size.height) * .5f : 10.0f;
    NSNumber *requested = _buttonStyle[@"corner_radius"];
    if ([requested isKindOfClass:[NSNumber class]])
        radius = MAX(0.0f, MIN(radius, [requested floatValue]));
    _backgroundView.layer.cornerRadius = radius;
    _blurView.frame = bounds;
    _blurView.layer.cornerRadius = radius;
    _blurView.clipsToBounds = YES;
    _iconView.transform = CGAffineTransformIdentity;
    _titleLabel.transform = CGAffineTransformIdentity;
    _iconView.frame = CGRectMake(CGFloor((bounds.size.width - TGProfileActionGlyphSide) / 2.0f), 9.0f, TGProfileActionGlyphSide, TGProfileActionGlyphSide);
    _titleLabel.frame = CGRectMake(4.0f, 37.0f, MAX(0.0f, bounds.size.width - 8.0f), 15.0f);
    CGFloat sx = MAX(.1f, MIN(3.0f, [_buttonStyle[@"content_scale_x"] floatValue] / 100.0f));
    CGFloat sy = MAX(.1f, MIN(3.0f, [_buttonStyle[@"content_scale_y"] floatValue] / 100.0f));
    if (_buttonStyle[@"content_scale_x"] == nil) sx = 1.0f;
    if (_buttonStyle[@"content_scale_y"] == nil) sy = 1.0f;
    if ([_buttonStyle[@"plain_content"] boolValue])
    {
        UIView *ancestor = self.superview;
        for (NSUInteger index = 0; ancestor != nil && index < 6; index++, ancestor = ancestor.superview)
        {
            CGAffineTransform transform = ancestor.transform;
            CGFloat parentX = sqrtf(transform.a * transform.a + transform.c * transform.c);
            CGFloat parentY = sqrtf(transform.b * transform.b + transform.d * transform.d);
            if (parentX > .001f) sx /= parentX;
            if (parentY > .001f) sy /= parentY;
        }
    }
    CGAffineTransform scale = CGAffineTransformMakeScale(sx, sy);
    if ([_buttonStyle[@"vertical"] boolValue])
        scale = CGAffineTransformRotate(scale, (CGFloat)M_PI_2);
    _iconView.transform = scale;
    _titleLabel.transform = scale;
}

@end

@interface TGProfileActionsCollectionItemView ()
{
    NSMutableArray *_buttons;
    UIColor *_buttonColor;
    NSDictionary *_buttonStyle;
}

@end

@implementation TGProfileActionsCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _buttons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    for (TGProfileActionButton *button in _buttons)
        [button setPresentation:presentation];
}

- (void)setActions:(NSArray *)actions
{
    while (_buttons.count > actions.count)
    {
        [[_buttons lastObject] removeFromSuperview];
        [_buttons removeLastObject];
    }
    while (_buttons.count < actions.count)
    {
        TGProfileActionButton *button = [[TGProfileActionButton alloc] init];
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:button];
        [_buttons addObject:button];
    }

    for (NSUInteger index = 0; index < actions.count; index++)
    {
        TGProfileActionButton *button = [_buttons objectAtIndex:index];
        button.action = [actions objectAtIndex:index];
        button.buttonColor = _buttonColor;
        button.buttonStyle = _buttonStyle;
        [button setPresentation:self.presentation];
    }

    [self setNeedsLayout];
}

- (void)setButtonColor:(UIColor *)buttonColor
{
    _buttonColor = buttonColor;
    for (TGProfileActionButton *button in _buttons)
    {
        button.buttonColor = buttonColor;
        [button setPresentation:self.presentation];
    }
}

- (void)setButtonStyle:(NSDictionary *)buttonStyle
{
    _buttonStyle = [buttonStyle copy];
    for (TGProfileActionButton *button in _buttons)
        button.buttonStyle = _buttonStyle;
    [self setNeedsLayout];
}

- (UIView *)buttonForActionWithSelector:(SEL)action
{
    for (TGProfileActionButton *button in _buttons)
    {
        if (button.action.action == action)
            return button;
    }
    return nil;
}

- (void)buttonPressed:(TGProfileActionButton *)button
{
    if (_actionSelected != nil && button.action != nil)
        _actionSelected(button.action);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSUInteger count = _buttons.count;
    if (count == 0)
        return;

    CGRect bounds = self.bounds;
    CGFloat left = TGProfileActionHorizontalInset + self.safeAreaInset.left;
    CGFloat availableWidth = MAX(0.0f, bounds.size.width - left - TGProfileActionHorizontalInset - self.safeAreaInset.right);
    CGFloat buttonWidth = CGFloor((availableWidth - TGProfileActionButtonSpacing * (count - 1)) / count);
    buttonWidth = MIN(buttonWidth, TGProfileActionMaxButtonWidth);
    CGFloat totalWidth = buttonWidth * count + TGProfileActionButtonSpacing * (count - 1);
    CGFloat x = left + CGFloor((availableWidth - totalWidth) / 2.0f);
    for (TGProfileActionButton *button in _buttons)
    {
        button.frame = CGRectMake(x, 0.0f, buttonWidth, TGProfileActionsCollectionItemViewHeight);
        x += buttonWidth + TGProfileActionButtonSpacing;
    }
}

@end
