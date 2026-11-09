#import "TGOnegramColorsController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGCollectionItem.h"
#import "TGCollectionItemView.h"
#import "TGCollectionMenuSection.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGAppearancePreviewCollectionItem.h"
#import "TGAppearanceController.h"
#import "TGPresentation.h"
#import "TGPresentationPallete.h"
#import "TGPresentationCustomColors.h"
#import "TGOnegramColorPreview.h"

static const CGFloat TGOnegramColorRowHeight = 54.0f;
static const CGFloat TGOnegramColorRowSwatchSide = 26.0f;
static const CGFloat TGOnegramColorPreviewVerticalInset = 10.0f;

static NSArray *TGOnegramColorPresets(void)
{
    static NSArray *presets = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        presets = @[@0x007ee5, @0x2ea6ff, @0x00c2ed, @0x29b327, @0x4cd964, @0x8bc34a,
                    @0xffcc00, @0xeba239, @0xff7519, @0xff3b30, @0xff5da2, @0xd84f9a,
                    @0x7748ff, @0x5856d6, @0x8e8e93, @0x5e6e7e, @0x3e546a, @0x6d4c41,
                    @0xffffff, @0xf1f1f4, @0xd6e4ef, @0xe1ffc7, @0x2c2c2e, @0x000000];
    });
    return presets;
}

@interface TGOnegramColorParameterItemView : TGCollectionItemView
{
    UILabel *_titleLabel;
    UILabel *_valueLabel;
    UIImageView *_swatchView;
    UIImageView *_disclosureView;
}

- (void)setParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete;

@end

@implementation TGOnegramColorParameterItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.backgroundColor = [UIColor clearColor];
        _valueLabel.font = TGSystemFontOfSize(13.0f);
        _valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_valueLabel];

        _swatchView = [[UIImageView alloc] init];
        [self addSubview:_swatchView];

        _disclosureView = [[UIImageView alloc] init];
        [self addSubview:_disclosureView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _disclosureView.image = presentation.images.collectionMenuDisclosureIcon;
    [_disclosureView sizeToFit];
    [self setNeedsLayout];
}

- (void)setParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    UIColor *color = [TGPresentationCustomColors colorForParameter:parameter pallete:pallete];
    bool custom = [TGPresentationCustomColors hasCustomColorForParameter:parameter pallete:pallete];
    _titleLabel.text = parameter.title;
    _valueLabel.text = custom ? [[NSString alloc] initWithFormat:@"%@ · %@", TGOnegramColorHexString(color), TGLocalized(@"OnegramColors.Changed")] : TGOnegramColorHexString(color);
    _valueLabel.textColor = custom ? pallete.collectionMenuAccentColor : pallete.collectionMenuVariantColor;
    _swatchView.image = TGOnegramColorSwatchImage(color, TGOnegramColorRowSwatchSide, pallete.collectionMenuSeparatorColor);
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat left = 15.0f + self.safeAreaInset.left;
    CGSize disclosureSize = _disclosureView.frame.size;
    _disclosureView.frame = CGRectMake(bounds.size.width - 15.0f - self.safeAreaInset.right - disclosureSize.width, CGFloor((bounds.size.height - disclosureSize.height) / 2.0f), disclosureSize.width, disclosureSize.height);
    _swatchView.frame = CGRectMake(CGRectGetMinX(_disclosureView.frame) - 12.0f - TGOnegramColorRowSwatchSide, CGFloor((bounds.size.height - TGOnegramColorRowSwatchSide) / 2.0f), TGOnegramColorRowSwatchSide, TGOnegramColorRowSwatchSide);
    CGFloat textWidth = MAX(0.0f, CGRectGetMinX(_swatchView.frame) - 12.0f - left);
    CGFloat titleHeight = CGCeil(OGPlatformFontLineHeight(_titleLabel.font));
    CGFloat valueHeight = CGCeil(OGPlatformFontLineHeight(_valueLabel.font));
    CGFloat spacing = 1.0f;
    CGFloat top = CGFloor((bounds.size.height - titleHeight - spacing - valueHeight) / 2.0f);
    _titleLabel.frame = CGRectMake(left, top, textWidth, titleHeight);
    _valueLabel.frame = CGRectMake(left, top + titleHeight + spacing, textWidth, valueHeight);
}

@end

@interface TGOnegramColorParameterItem : TGCollectionItem

@property (nonatomic, strong, readonly) TGPresentationColorParameter *parameter;
@property (nonatomic, strong) TGPresentationPallete *pallete;
@property (nonatomic, copy) void (^pressed)(TGPresentationColorParameter *parameter);

- (instancetype)initWithParameter:(TGPresentationColorParameter *)parameter;
- (void)refresh;

@end

@implementation TGOnegramColorParameterItem

- (instancetype)initWithParameter:(TGPresentationColorParameter *)parameter
{
    self = [super init];
    if (self != nil)
    {
        _parameter = parameter;
        self.selectable = true;
        self.highlightable = true;
        self.deselectAutomatically = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGOnegramColorParameterItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGOnegramColorRowHeight);
}

- (void)bindView:(TGOnegramColorParameterItemView *)view
{
    [super bindView:view];
    [view setParameter:_parameter pallete:_pallete];
}

- (void)refresh
{
    [(TGOnegramColorParameterItemView *)[self boundView] setParameter:_parameter pallete:_pallete];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil)
        _pressed(_parameter);
}

@end

@interface TGOnegramColorLargePreviewItemView : TGCollectionItemView
{
    UIImageView *_imageView;
    TGPresentationColorPreview _preview;
    TGPresentationPallete *_pallete;
    UIColor *_color;
}

- (void)setPreview:(TGPresentationColorPreview)preview pallete:(TGPresentationPallete *)pallete color:(UIColor *)color;

@end

@implementation TGOnegramColorLargePreviewItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[UIImageView alloc] init];
        [self addSubview:_imageView];
    }
    return self;
}

- (void)setPreview:(TGPresentationColorPreview)preview pallete:(TGPresentationPallete *)pallete color:(UIColor *)color
{
    _preview = preview;
    _pallete = pallete;
    _color = color;
    [self renderPreview];
}

- (CGSize)previewSize
{
    return CGSizeMake(MAX(0.0f, self.bounds.size.width - 30.0f - self.safeAreaInset.left - self.safeAreaInset.right), MAX(0.0f, self.bounds.size.height - TGOnegramColorPreviewVerticalInset * 2.0f));
}

- (void)renderPreview
{
    CGSize size = [self previewSize];
    _imageView.image = TGOnegramColorPreviewImage(_preview, _pallete, _color, size);
    _imageView.frame = CGRectMake(15.0f + self.safeAreaInset.left, TGOnegramColorPreviewVerticalInset, size.width, size.height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGSizeEqualToSize(_imageView.frame.size, [self previewSize]))
        [self renderPreview];
}

@end

@interface TGOnegramColorLargePreviewItem : TGCollectionItem

@property (nonatomic) TGPresentationColorPreview preview;
@property (nonatomic, strong) TGPresentationPallete *pallete;
@property (nonatomic, strong) UIColor *color;

@end

@implementation TGOnegramColorLargePreviewItem

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
    return [TGOnegramColorLargePreviewItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGOnegramColorPreviewHeight(_preview) + TGOnegramColorPreviewVerticalInset * 2.0f);
}

- (void)bindView:(TGOnegramColorLargePreviewItemView *)view
{
    [super bindView:view];
    [view setPreview:_preview pallete:_pallete color:_color];
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    [(TGOnegramColorLargePreviewItemView *)[self boundView] setPreview:_preview pallete:_pallete color:color];
}

@end

@interface TGOnegramColorSwatchesItemView : TGCollectionItemView
{
    NSMutableArray *_buttons;
    uint32_t _selectedColor;
}

@property (nonatomic, copy) void (^colorSelected)(uint32_t color);

- (void)setSelectedColor:(uint32_t)color;

@end

@implementation TGOnegramColorSwatchesItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _buttons = [[NSMutableArray alloc] init];
        NSArray *presets = TGOnegramColorPresets();
        for (NSUInteger i = 0; i < presets.count; i++)
        {
            UIButton *button = [[UIButton alloc] init];
            button.tag = (NSInteger)i;
            [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];
            [_buttons addObject:button];
        }
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    [self updateButtons];
}

- (void)setSelectedColor:(uint32_t)color
{
    _selectedColor = color;
    [self updateButtons];
}

- (void)updateButtons
{
    NSArray *presets = TGOnegramColorPresets();
    UIColor *borderColor = self.presentation.pallete.collectionMenuSeparatorColor;
    UIColor *selectionColor = self.presentation.pallete.collectionMenuAccentColor;
    for (UIButton *button in _buttons)
    {
        uint32_t rgb = [presets[(NSUInteger)button.tag] unsignedIntValue];
        bool selected = rgb == (_selectedColor & 0xffffff);
        UIImage *image = TGOnegramColorSwatchImage(UIColorRGB(rgb), 34.0f, borderColor);
        if (selected)
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(40.0f, 40.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [image drawInRect:CGRectMake(5.0f, 5.0f, 30.0f, 30.0f)];
            CGContextSetStrokeColorWithColor(context, selectionColor.CGColor);
            CGContextSetLineWidth(context, 2.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(1.0f, 1.0f, 38.0f, 38.0f));
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        [button setImage:image forState:UIControlStateNormal];
    }
}

- (void)buttonPressed:(UIButton *)button
{
    uint32_t rgb = [TGOnegramColorPresets()[(NSUInteger)button.tag] unsignedIntValue];
    if (_colorSelected != nil)
        _colorSelected(rgb);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat side = 40.0f;
    NSUInteger columns = 6;
    CGFloat left = 10.0f + self.safeAreaInset.left;
    CGFloat width = self.bounds.size.width - left - 10.0f - self.safeAreaInset.right;
    CGFloat spacing = MAX(0.0f, (width - side * (CGFloat)columns) / (CGFloat)(columns - 1));
    for (UIButton *button in _buttons)
    {
        NSUInteger index = (NSUInteger)button.tag;
        NSUInteger row = index / columns;
        NSUInteger column = index % columns;
        button.frame = CGRectMake(left + (side + spacing) * (CGFloat)column, 8.0f + (side + 6.0f) * (CGFloat)row, side, side);
    }
}

@end

@interface TGOnegramColorSwatchesItem : TGCollectionItem

@property (nonatomic) uint32_t selectedColor;
@property (nonatomic, copy) void (^colorSelected)(uint32_t color);

@end

@implementation TGOnegramColorSwatchesItem

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
    return [TGOnegramColorSwatchesItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    NSUInteger rows = (TGOnegramColorPresets().count + 5) / 6;
    return CGSizeMake(containerSize.width, 16.0f + 46.0f * (CGFloat)rows - 6.0f);
}

- (void)bindView:(TGOnegramColorSwatchesItemView *)view
{
    [super bindView:view];
    view.colorSelected = _colorSelected;
    [view setSelectedColor:_selectedColor];
}

- (void)setSelectedColor:(uint32_t)selectedColor
{
    _selectedColor = selectedColor;
    [(TGOnegramColorSwatchesItemView *)[self boundView] setSelectedColor:selectedColor];
}

@end

typedef enum {
    TGOnegramColorSliderHue = 0,
    TGOnegramColorSliderSaturation,
    TGOnegramColorSliderBrightness
} TGOnegramColorSliderKind;

static UIImage *TGOnegramColorSliderTrackImage(TGOnegramColorSliderKind kind, CGFloat hue, CGFloat saturation, CGFloat brightness, CGFloat width)
{
    CGFloat height = 8.0f;
    width = MAX(8.0f, CGFloor(width));
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextBeginPath(context);
    CGFloat radius = height / 2.0f;
    CGContextMoveToPoint(context, radius, 0.0f);
    CGContextAddArcToPoint(context, width, 0.0f, width, radius, radius);
    CGContextAddArcToPoint(context, width, height, width - radius, height, radius);
    CGContextAddArcToPoint(context, 0.0f, height, 0.0f, radius, radius);
    CGContextAddArcToPoint(context, 0.0f, 0.0f, radius, 0.0f, radius);
    CGContextClosePath(context);
    CGContextClip(context);
    NSInteger steps = (NSInteger)width;
    for (NSInteger i = 0; i < steps; i++)
    {
        CGFloat t = steps <= 1 ? 0.0f : (CGFloat)i / (CGFloat)(steps - 1);
        UIColor *color = nil;
        if (kind == TGOnegramColorSliderHue)
            color = [UIColor colorWithHue:t saturation:1.0f brightness:1.0f alpha:1.0f];
        else if (kind == TGOnegramColorSliderSaturation)
            color = [UIColor colorWithHue:hue saturation:t brightness:MAX(0.2f, brightness) alpha:1.0f];
        else
            color = [UIColor colorWithHue:hue saturation:saturation brightness:t alpha:1.0f];
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillRect(context, CGRectMake((CGFloat)i, 0.0f, 1.0f, height));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGOnegramColorSliderItemView : TGCollectionItemView
{
    UILabel *_titleLabel;
    UILabel *_valueLabel;
    UISlider *_slider;
    TGOnegramColorSliderKind _kind;
    CGFloat _hue;
    CGFloat _saturation;
    CGFloat _brightness;
    CGFloat _trackWidth;
}

@property (nonatomic, copy) void (^valueChanged)(CGFloat value, bool finished);

- (void)setKind:(TGOnegramColorSliderKind)kind title:(NSString *)title hue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness;

@end

@implementation TGOnegramColorSliderItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(15.0f);
        [self addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.backgroundColor = [UIColor clearColor];
        _valueLabel.font = TGSystemFontOfSize(15.0f);
        _valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:_valueLabel];

        _slider = [[UISlider alloc] init];
        _slider.minimumValue = 0.0f;
        _slider.maximumValue = 1.0f;
        [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
        [_slider addTarget:self action:@selector(sliderFinished) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self addSubview:_slider];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _valueLabel.textColor = presentation.pallete.collectionMenuVariantColor;
}

- (CGFloat)currentValue
{
    if (_kind == TGOnegramColorSliderHue)
        return _hue;
    if (_kind == TGOnegramColorSliderSaturation)
        return _saturation;
    return _brightness;
}

- (void)setKind:(TGOnegramColorSliderKind)kind title:(NSString *)title hue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness
{
    _kind = kind;
    _hue = hue;
    _saturation = saturation;
    _brightness = brightness;
    _titleLabel.text = title;
    if (!_slider.tracking)
        _slider.value = (float)[self currentValue];
    [self updateValueLabel];
    _trackWidth = 0.0f;
    [self setNeedsLayout];
}

- (void)updateValueLabel
{
    CGFloat value = _slider.value;
    _valueLabel.text = _kind == TGOnegramColorSliderHue ? [[NSString alloc] initWithFormat:@"%d°", (int)lroundf((float)(value * 360.0f))] : [[NSString alloc] initWithFormat:@"%d%%", (int)lroundf((float)(value * 100.0f))];
}

- (void)updateTrack
{
    CGRect trackRect = [_slider trackRectForBounds:_slider.bounds];
    CGFloat width = trackRect.size.width > 1.0f ? trackRect.size.width : _slider.bounds.size.width;
    _trackWidth = width;
    UIImage *track = TGOnegramColorSliderTrackImage(_kind, _hue, _saturation, _brightness, width);
    [_slider setMinimumTrackImage:track forState:UIControlStateNormal];
    [_slider setMaximumTrackImage:track forState:UIControlStateNormal];
}

- (void)sliderChanged
{
    [self updateValueLabel];
    if (_valueChanged != nil)
        _valueChanged(_slider.value, false);
}

- (void)sliderFinished
{
    if (_valueChanged != nil)
        _valueChanged(_slider.value, true);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat left = 15.0f + self.safeAreaInset.left;
    CGFloat width = bounds.size.width - left - 15.0f - self.safeAreaInset.right;
    _titleLabel.frame = CGRectMake(left, 8.0f, width * 0.6f, 20.0f);
    _valueLabel.frame = CGRectMake(left + width * 0.6f, 8.0f, width * 0.4f, 20.0f);
    _slider.frame = CGRectMake(left, 30.0f, width, 28.0f);
    CGRect trackRect = [_slider trackRectForBounds:_slider.bounds];
    if (fabs(trackRect.size.width - _trackWidth) > 0.5f)
        [self updateTrack];
}

@end

@interface TGOnegramColorSliderItem : TGCollectionItem

@property (nonatomic) TGOnegramColorSliderKind kind;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, copy) void (^valueChanged)(CGFloat value, bool finished);

- (void)setHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness;

@end

@interface TGOnegramColorSliderItem ()
{
    CGFloat _hue;
    CGFloat _saturation;
    CGFloat _brightness;
}

@end

@implementation TGOnegramColorSliderItem

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
    return [TGOnegramColorSliderItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 66.0f);
}

- (void)bindView:(TGOnegramColorSliderItemView *)view
{
    [super bindView:view];
    view.valueChanged = _valueChanged;
    [view setKind:_kind title:_title hue:_hue saturation:_saturation brightness:_brightness];
}

- (void)setHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness
{
    _hue = hue;
    _saturation = saturation;
    _brightness = brightness;
    [(TGOnegramColorSliderItemView *)[self boundView] setKind:_kind title:_title hue:hue saturation:saturation brightness:brightness];
}

@end

@interface TGOnegramColorPickerController : TGCollectionMenuController
{
    TGPresentationColorParameter *_parameter;
    TGPresentationPallete *_pallete;
    CGFloat _hue;
    CGFloat _saturation;
    CGFloat _brightness;
    TGOnegramColorLargePreviewItem *_previewItem;
    TGOnegramColorSwatchesItem *_swatchesItem;
    NSArray *_sliderItems;
    TGCommentCollectionItem *_hexItem;
}

- (instancetype)initWithParameter:(TGPresentationColorParameter *)parameter;

@end

@implementation TGOnegramColorPickerController

- (instancetype)initWithParameter:(TGPresentationColorParameter *)parameter
{
    self = [super init];
    if (self != nil)
    {
        _parameter = parameter;
        _pallete = TGPresentation.current.pallete;
        TGOnegramColorGetHSB([TGPresentationCustomColors colorForParameter:parameter pallete:_pallete], &_hue, &_saturation, &_brightness);

        [self setTitleText:parameter.title];
        [self setRightBarButtonItem:[TGPresentation navigationBarButtonItemWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)]];

        _previewItem = [[TGOnegramColorLargePreviewItem alloc] init];
        _previewItem.preview = parameter.preview;
        _previewItem.pallete = _pallete;
        _previewItem.color = [self currentColor];

        _hexItem = [[TGCommentCollectionItem alloc] initWithText:TGOnegramColorHexString([self currentColor])];
        TGCollectionMenuSection *previewSection = [[TGCollectionMenuSection alloc] initWithItems:@[
            [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.Example")],
            _previewItem,
            _hexItem
        ]];
        [self.menuSections addSection:previewSection];

        __weak TGOnegramColorPickerController *weakSelf = self;
        _swatchesItem = [[TGOnegramColorSwatchesItem alloc] init];
        _swatchesItem.selectedColor = TGColorHexCode([self currentColor]);
        _swatchesItem.colorSelected = ^(uint32_t rgb)
        {
            __strong TGOnegramColorPickerController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            TGOnegramColorGetHSB(UIColorRGB(rgb), &strongSelf->_hue, &strongSelf->_saturation, &strongSelf->_brightness);
            [strongSelf colorUpdated];
        };
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
            [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.Presets")],
            _swatchesItem
        ]]];

        NSArray *titles = @[TGLocalized(@"OnegramColors.Hue"), TGLocalized(@"OnegramColors.Saturation"), TGLocalized(@"OnegramColors.Brightness")];
        NSMutableArray *sliderItems = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < titles.count; i++)
        {
            TGOnegramColorSliderItem *item = [[TGOnegramColorSliderItem alloc] init];
            item.kind = (TGOnegramColorSliderKind)i;
            item.title = titles[i];
            TGOnegramColorSliderKind kind = item.kind;
            item.valueChanged = ^(CGFloat value, __unused bool finished)
            {
                __strong TGOnegramColorPickerController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                if (kind == TGOnegramColorSliderHue)
                    strongSelf->_hue = value;
                else if (kind == TGOnegramColorSliderSaturation)
                    strongSelf->_saturation = value;
                else
                    strongSelf->_brightness = value;
                [strongSelf colorUpdated];
            };
            [sliderItems addObject:item];
        }
        _sliderItems = sliderItems;
        NSMutableArray *slidersSectionItems = [[NSMutableArray alloc] initWithObjects:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.Custom")], nil];
        [slidersSectionItems addObjectsFromArray:sliderItems];
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:slidersSectionItems]];

        TGButtonCollectionItem *resetItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.ResetColor") action:@selector(resetPressed)];
        resetItem.deselectAutomatically = true;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[resetItem]]];

        [self updateSliders];
    }
    return self;
}

- (UIColor *)currentColor
{
    return [UIColor colorWithHue:_hue saturation:_saturation brightness:_brightness alpha:1.0f];
}

- (void)updateSliders
{
    for (TGOnegramColorSliderItem *item in _sliderItems)
        [item setHue:_hue saturation:_saturation brightness:_brightness];
}

- (void)colorUpdated
{
    UIColor *color = [self currentColor];
    _previewItem.color = color;
    _hexItem.text = TGOnegramColorHexString(color);
    _swatchesItem.selectedColor = TGColorHexCode(color);
    [self updateSliders];
}

- (void)donePressed
{
    [TGPresentationCustomColors setColor:[self currentColor] forParameter:_parameter pallete:_pallete];
    [self.navigationController popViewControllerAnimated:true];
}

- (void)resetPressed
{
    [TGPresentationCustomColors setColor:nil forParameter:_parameter pallete:_pallete];
    [self.navigationController popViewControllerAnimated:true];
}

@end

@interface TGOnegramColorsController ()
{
    TGAppearancePreviewCollectionItem *_previewItem;
    NSArray *_parameterItems;
    TGCollectionMenuSection *_resetSection;
}

@end

@implementation TGOnegramColorsController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGLocalized(@"OnegramColors.Title")];

        _previewItem = [[TGAppearancePreviewCollectionItem alloc] init];
        _previewItem.messages = [TGAppearanceController previewMessages];
        __weak TGOnegramColorsController *weakSelf = self;
        _previewItem.heightChanged = ^
        {
            __strong TGOnegramColorsController *strongSelf = weakSelf;
            [strongSelf.collectionLayout invalidateLayout];
        };
        TGCollectionMenuSection *previewSection = [[TGCollectionMenuSection alloc] initWithItems:@[
            [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.Preview")],
            _previewItem,
            [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"OnegramColors.Info")]
        ]];
        UIEdgeInsets previewInsets = previewSection.insets;
        previewInsets.top = 32.0f;
        previewSection.insets = previewInsets;
        [self.menuSections addSection:previewSection];

        NSMutableArray *parameterItems = [[NSMutableArray alloc] init];
        NSArray *sectionTitles = @[TGLocalized(@"OnegramColors.SectionGeneral"), TGLocalized(@"OnegramColors.SectionChatList"), TGLocalized(@"OnegramColors.SectionMessages")];
        TGPresentationColorSection sections[] = {TGPresentationColorSectionGeneral, TGPresentationColorSectionChatList, TGPresentationColorSectionMessages};
        for (NSUInteger i = 0; i < 3; i++)
        {
            NSMutableArray *items = [[NSMutableArray alloc] initWithObjects:[[TGHeaderCollectionItem alloc] initWithTitle:sectionTitles[i]], nil];
            for (TGPresentationColorParameter *parameter in [TGPresentationCustomColors parametersInSection:sections[i]])
            {
                TGOnegramColorParameterItem *item = [[TGOnegramColorParameterItem alloc] initWithParameter:parameter];
                item.pallete = TGPresentation.current.pallete;
                item.pressed = ^(TGPresentationColorParameter *pressedParameter)
                {
                    __strong TGOnegramColorsController *strongSelf = weakSelf;
                    [strongSelf openParameter:pressedParameter];
                };
                [items addObject:item];
                [parameterItems addObject:item];
            }
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:items]];
        }
        _parameterItems = parameterItems;

        TGButtonCollectionItem *resetItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.ResetAll") action:@selector(resetAllPressed)];
        resetItem.deselectAutomatically = true;
        resetItem.titleColor = TGPresentation.current.pallete.collectionMenuDestructiveColor;
        _resetSection = [[TGCollectionMenuSection alloc] initWithItems:@[resetItem]];
        [self updateResetSection];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    for (TGOnegramColorParameterItem *item in _parameterItems)
    {
        item.pallete = presentation.pallete;
        [item refresh];
    }
    for (TGButtonCollectionItem *item in _resetSection.items)
        item.titleColor = presentation.pallete.collectionMenuDestructiveColor;
    [_previewItem reset];
    [self updateResetSection];
}

- (void)updateResetSection
{
    bool hasCustom = [TGPresentationCustomColors hasCustomColorsForPallete:TGPresentation.current.pallete];
    NSUInteger index = [self.menuSections.sections indexOfObject:_resetSection];
    if (hasCustom && index == NSNotFound)
        [self.menuSections addSection:_resetSection];
    else if (!hasCustom && index != NSNotFound)
        [self.menuSections deleteSection:index];
    [self.collectionView reloadData];
}

- (void)openParameter:(TGPresentationColorParameter *)parameter
{
    TGOnegramColorPickerController *controller = [[TGOnegramColorPickerController alloc] initWithParameter:parameter];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)resetAllPressed
{
    [TGPresentationCustomColors resetColorsForPallete:TGPresentation.current.pallete];
}

@end
