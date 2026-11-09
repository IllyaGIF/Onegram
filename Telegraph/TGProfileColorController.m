#import "TGProfileColorController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGCollectionItem.h"
#import "TGCollectionItemView.h"
#import "TGCollectionMenuSection.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGCustomAlertView.h"
#import "TGUserExtendedInfo.h"
#import "TGPresentation.h"

static const CGFloat TGProfileColorSwatchSide = 34.0f;

static UIImage *TGProfileColorSwatchImage(UIColor *color, bool selected, UIColor *ringColor)
{
    CGFloat side = TGProfileColorSwatchSide;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect inner = selected ? CGRectInset(CGRectMake(0.0f, 0.0f, side, side), 5.0f, 5.0f) : CGRectInset(CGRectMake(0.0f, 0.0f, side, side), 2.0f, 2.0f);
    if (color != nil)
    {
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, inner);
    }
    else
    {
        CGContextSetStrokeColorWithColor(context, UIColorRGB(0xa0a0a6).CGColor);
        CGContextSetLineWidth(context, 1.5f);
        CGContextStrokeEllipseInRect(context, CGRectInset(inner, 0.75f, 0.75f));
        CGContextMoveToPoint(context, CGRectGetMinX(inner) + inner.size.width * 0.25f, CGRectGetMaxY(inner) - inner.size.height * 0.25f);
        CGContextAddLineToPoint(context, CGRectGetMaxX(inner) - inner.size.width * 0.25f, CGRectGetMinY(inner) + inner.size.height * 0.25f);
        CGContextStrokePath(context);
    }
    if (selected)
    {
        CGContextSetStrokeColorWithColor(context, (ringColor ?: color ?: [UIColor grayColor]).CGColor);
        CGContextSetLineWidth(context, 2.0f);
        CGContextStrokeEllipseInRect(context, CGRectInset(CGRectMake(0.0f, 0.0f, side, side), 1.0f, 1.0f));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGProfileColorSwatchesItem : TGCollectionItem

@property (nonatomic) bool profilePalette;
@property (nonatomic) int32_t selectedColor;
@property (nonatomic, copy) void (^colorSelected)(int32_t color);

@end

@interface TGProfileColorSwatchesItemView : TGCollectionItemView
{
    NSMutableArray *_buttons;
    bool _profilePalette;
    int32_t _selectedColor;
}

@property (nonatomic, copy) void (^colorSelected)(int32_t color);

- (void)setProfilePalette:(bool)profilePalette selectedColor:(int32_t)selectedColor;

@end

@implementation TGProfileColorSwatchesItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        _buttons = [[NSMutableArray alloc] init];
    return self;
}

- (void)setProfilePalette:(bool)profilePalette selectedColor:(int32_t)selectedColor
{
    _profilePalette = profilePalette;
    _selectedColor = selectedColor;
    NSUInteger count = (profilePalette ? TGUserProfileColorCount() : TGUserNameColorCount()) + 1;
    while (_buttons.count < count)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:button];
        [_buttons addObject:button];
    }
    while (_buttons.count > count)
    {
        [[_buttons lastObject] removeFromSuperview];
        [_buttons removeLastObject];
    }
    for (NSUInteger i = 0; i < count; i++)
    {
        int32_t color = (int32_t)i - 1;
        UIColor *swatchColor = color < 0 ? nil : (profilePalette ? TGUserProfileColor(color) : TGUserNameColor(color));
        [[_buttons objectAtIndex:i] setImage:TGProfileColorSwatchImage(swatchColor, color == selectedColor, self.presentation.pallete.collectionMenuAccentColor) forState:UIControlStateNormal];
    }
    [self setNeedsLayout];
}

- (void)buttonPressed:(UIButton *)button
{
    NSUInteger index = [_buttons indexOfObject:button];
    if (index != NSNotFound && _colorSelected != nil)
        _colorSelected((int32_t)index - 1);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    NSUInteger count = _buttons.count;
    if (count == 0)
        return;
    CGFloat left = 15.0f + self.safeAreaInset.left;
    CGFloat width = self.bounds.size.width - left - 15.0f - self.safeAreaInset.right;
    CGFloat spacing = count > 1 ? (width - TGProfileColorSwatchSide * count) / (count - 1) : 0.0f;
    spacing = MAX(4.0f, spacing);
    for (NSUInteger i = 0; i < count; i++)
        ((UIButton *)[_buttons objectAtIndex:i]).frame = CGRectMake(CGFloor(left + i * (TGProfileColorSwatchSide + spacing)), CGFloor((self.bounds.size.height - TGProfileColorSwatchSide) / 2.0f), TGProfileColorSwatchSide, TGProfileColorSwatchSide);
}

@end

@implementation TGProfileColorSwatchesItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.selectable = false;
        self.highlightable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGProfileColorSwatchesItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 56.0f);
}

- (void)bindView:(TGProfileColorSwatchesItemView *)view
{
    [super bindView:view];
    [view setProfilePalette:_profilePalette selectedColor:_selectedColor];
    __weak TGProfileColorSwatchesItem *weakSelf = self;
    view.colorSelected = ^(int32_t color)
    {
        __strong TGProfileColorSwatchesItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.colorSelected != nil)
            strongSelf.colorSelected(color);
    };
}

- (void)unbindView
{
    ((TGProfileColorSwatchesItemView *)[self boundView]).colorSelected = nil;
    [super unbindView];
}

- (void)setSelectedColor:(int32_t)selectedColor
{
    _selectedColor = selectedColor;
    [(TGProfileColorSwatchesItemView *)[self boundView] setProfilePalette:_profilePalette selectedColor:selectedColor];
}

@end

@interface TGProfileColorController ()
{
    int32_t _profileColor;
    int32_t _nameColor;
    TGProfileColorSwatchesItem *_profileItem;
    TGProfileColorSwatchesItem *_nameItem;
    SMetaDisposable *_updateDisposable;
}

@end

@implementation TGProfileColorController

- (instancetype)initWithProfileColor:(int32_t)profileColor nameColor:(int32_t)nameColor
{
    self = [super init];
    if (self != nil)
    {
        _profileColor = profileColor;
        _nameColor = nameColor;
        _updateDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:TGLocalized(@"OnegramProfile.ColorTitle")];

        __weak TGProfileColorController *weakSelf = self;
        _profileItem = [[TGProfileColorSwatchesItem alloc] init];
        _profileItem.profilePalette = true;
        _profileItem.selectedColor = profileColor;
        _profileItem.colorSelected = ^(int32_t color)
        {
            __strong TGProfileColorController *strongSelf = weakSelf;
            [strongSelf applyColor:color forProfile:true];
        };
        _nameItem = [[TGProfileColorSwatchesItem alloc] init];
        _nameItem.profilePalette = false;
        _nameItem.selectedColor = nameColor;
        _nameItem.colorSelected = ^(int32_t color)
        {
            __strong TGProfileColorController *strongSelf = weakSelf;
            [strongSelf applyColor:color forProfile:false];
        };

        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
            [[TGHeaderCollectionItem alloc] initWithTitle:[TGLocalized(@"OnegramProfile.ProfileColor") uppercaseString]],
            _profileItem,
            [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"OnegramProfile.ProfileColorInfo")]
        ]]];
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
            [[TGHeaderCollectionItem alloc] initWithTitle:[TGLocalized(@"OnegramProfile.NameColor") uppercaseString]],
            _nameItem,
            [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"OnegramProfile.NameColorInfo")]
        ]]];
    }
    return self;
}

- (void)dealloc
{
    [_updateDisposable dispose];
}

- (void)applyColor:(int32_t)color forProfile:(bool)forProfile
{
    int32_t previous = forProfile ? _profileColor : _nameColor;
    if (previous == color)
        return;
    if (forProfile)
    {
        _profileColor = color;
        _profileItem.selectedColor = color;
    }
    else
    {
        _nameColor = color;
        _nameItem.selectedColor = color;
    }
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak TGProfileColorController *weakSelf = self;
    [_updateDisposable setDisposable:[[[TGUserExtendedInfo updateColor:color forProfile:forProfile] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        __strong TGProfileColorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (forProfile)
        {
            strongSelf->_profileColor = previous;
            strongSelf->_profileItem.selectedColor = previous;
        }
        else
        {
            strongSelf->_nameColor = previous;
            strongSelf->_nameItem.selectedColor = previous;
        }
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramProfile.ColorFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        [progressWindow dismiss:true];
        __strong TGProfileColorController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.colorsChanged != nil)
            strongSelf.colorsChanged(strongSelf->_profileColor, strongSelf->_nameColor);
    }]];
}

@end
