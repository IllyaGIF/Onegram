#import "TGOnegramSliderCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGCollectionItemView.h"
#import "TGPresentation.h"
#import "TGFlatControls.h"

@interface TGOnegramSliderCollectionItemView : TGCollectionItemView
{
    UILabel *_titleLabel;
    UILabel *_valueLabel;
    UISlider *_slider;
}

@property (nonatomic, weak) TGOnegramSliderCollectionItem *item;

- (void)updateFromItem;

@end

@implementation TGOnegramSliderCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.backgroundColor = [UIColor clearColor];
        _valueLabel.font = TGSystemFontOfSize(17.0f);
        _valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:_valueLabel];

        _slider = [[UISlider alloc] init];
        [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
        [_slider addTarget:self action:@selector(sliderCommitted) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self addSubview:_slider];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _valueLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    if (TGFlatControlsEnabled())
        TGFlatControlsApplySliderStyle(_slider, presentation.pallete.collectionMenuAccentColor, presentation.pallete.collectionMenuAccessoryColor);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    else if ([_slider respondsToSelector:@selector(setMinimumTrackTintColor:)])
        _slider.minimumTrackTintColor = presentation.pallete.collectionMenuAccentColor;
#endif
}

- (float)sliderPositionForValue:(NSInteger)value
{
    TGOnegramSliderCollectionItem *item = _item;
    return (float)(item.reversed ? item.minimumValue + item.maximumValue - value : value);
}

- (NSInteger)steppedValue
{
    TGOnegramSliderCollectionItem *item = _item;
    NSInteger step = MAX(1, item.step);
    NSInteger raw = (NSInteger)lroundf(_slider.value);
    if (item.reversed)
        raw = item.minimumValue + item.maximumValue - raw;
    NSInteger value = item.minimumValue + ((raw - item.minimumValue + step / 2) / step) * step;
    return MAX(item.minimumValue, MIN(item.maximumValue, value));
}

- (void)updateFromItem
{
    TGOnegramSliderCollectionItem *item = _item;
    _titleLabel.text = item.title;
    _slider.minimumValue = (float)item.minimumValue;
    _slider.maximumValue = (float)item.maximumValue;
    _slider.value = [self sliderPositionForValue:item.value];
    _valueLabel.text = item.valueFormatter != nil ? item.valueFormatter(item.value) : [[NSString alloc] initWithFormat:@"%d", (int)item.value];
    [self setNeedsLayout];
}

- (void)sliderChanged
{
    TGOnegramSliderCollectionItem *item = _item;
    NSInteger value = [self steppedValue];
    if (value == item.value)
        return;
    item.value = value;
    _valueLabel.text = item.valueFormatter != nil ? item.valueFormatter(value) : [[NSString alloc] initWithFormat:@"%d", (int)value];
    [self setNeedsLayout];
    if (item.valueChanged != nil)
        item.valueChanged(value);
}

- (void)sliderCommitted
{
    TGOnegramSliderCollectionItem *item = _item;
    _slider.value = [self sliderPositionForValue:item.value];
    if (item.valueCommitted != nil)
        item.valueCommitted(item.value);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    bool classic = [TGPresentation classicThemeStyle];
    CGRect contentFrame = [self classicIOS6GroupedFrame];
    CGFloat originX = contentFrame.origin.x + 15.0f + (classic ? 0.0f : self.safeAreaInset.left);
    CGFloat maxX = CGRectGetMaxX(contentFrame) - 15.0f - (classic ? 0.0f : self.safeAreaInset.right);
    CGFloat width = MAX(0.0f, maxX - originX);
    CGFloat valueWidth = MIN(width * 0.4f, CGCeil(OGPlatformTextSize(_valueLabel.text, _valueLabel.font, CGSizeMake(width, 24.0f), UILineBreakModeTailTruncation).width));
    _titleLabel.frame = CGRectMake(originX, 11.0f, width - valueWidth - 8.0f, 22.0f);
    _valueLabel.frame = CGRectMake(maxX - valueWidth, 11.0f, valueWidth, 22.0f);
    _slider.frame = CGRectMake(originX, 38.0f, width, 30.0f);
}

@end

@implementation TGOnegramSliderCollectionItem

- (instancetype)initWithTitle:(NSString *)title minimumValue:(NSInteger)minimumValue maximumValue:(NSInteger)maximumValue value:(NSInteger)value
{
    self = [super init];
    if (self != nil)
    {
        self.highlightable = false;
        self.selectable = false;
        _title = title;
        _minimumValue = minimumValue;
        _maximumValue = maximumValue;
        _value = value;
        _step = 1;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGOnegramSliderCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 78.0f);
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];
    TGOnegramSliderCollectionItemView *sliderView = (TGOnegramSliderCollectionItemView *)view;
    sliderView.item = self;
    [sliderView updateFromItem];
}

- (void)unbindView
{
    ((TGOnegramSliderCollectionItemView *)self.boundView).item = nil;
    [super unbindView];
}

- (void)setValue:(NSInteger)value
{
    _value = value;
}

@end
