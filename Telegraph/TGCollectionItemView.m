#import "TGCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <QuartzCore/QuartzCore.h>

#import "TGPresentation.h"

@interface TGCollectionItemView ()
{
    UIImageView *_classicIOS6BackgroundImageView;
    UIImageView *_classicIOS6SelectedBackgroundImageView;
}

@end

static UIImage *TGCollectionItemViewClassicIOS6Image(int itemPosition, bool selected, TGPresentation *presentation)
{
    if (itemPosition == 0)
        return nil;

    NSString *name = nil;
    if ((itemPosition & TGCollectionItemViewPositionFirstInBlock) && (itemPosition & TGCollectionItemViewPositionLastInBlock))
        name = @"GroupedCellSingle";
    else if (itemPosition & TGCollectionItemViewPositionFirstInBlock)
        name = @"GroupedCellTop";
    else if (itemPosition & TGCollectionItemViewPositionLastInBlock)
        name = @"GroupedCellBottom";
    else
        name = @"GroupedCellMiddle";

    if (selected)
        name = [name stringByAppendingString:@"_Selected"];

    UIImage *image = [TGPresentation classicIOS6ResourceImage:name];
    if (image == nil)
        return nil;

    if (presentation.pallete.isDark)
    {
        UIColor *tintColor = selected ? presentation.pallete.collectionMenuCellSelectionColor : presentation.pallete.collectionMenuCellBackgroundColor;
        image = [TGPresentation classicIOS6ThemedImage:image tintColor:tintColor alpha:selected ? 0.78f : 0.88f];
    }

    return [image stretchableImageWithLeftCapWidth:(int)floor(image.size.width / 2.0f) topCapHeight:(int)floor(image.size.height / 2.0f)];
}

@implementation TGCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _itemPosition = 1 << 31;
        _separatorInset = 15.0f;
        _classicIOS6HorizontalInset = 9.0f;
        
        self.backgroundView = [[UIView alloc] init];
        _classicIOS6BackgroundImageView = [[UIImageView alloc] init];
        _classicIOS6BackgroundImageView.userInteractionEnabled = false;
        [self.backgroundView addSubview:_classicIOS6BackgroundImageView];
        
        self.selectedBackgroundView = [[UIView alloc] init];
        _classicIOS6SelectedBackgroundImageView = [[UIImageView alloc] init];
        _classicIOS6SelectedBackgroundImageView.userInteractionEnabled = false;
        [self.selectedBackgroundView addSubview:_classicIOS6SelectedBackgroundImageView];
        
        if (_topStripeView == nil)
        {
            _topStripeView = [[UIView alloc] init];
            [self.backgroundView addSubview:_topStripeView];
        }
        
        if (_bottomStripeView == nil)
        {
            _bottomStripeView = [[UIView alloc] init];
            [self.backgroundView addSubview:_bottomStripeView];
        }
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    _topStripeView.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
    _bottomStripeView.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
    [self _updateStripes];
}

- (void)setHighlightDisabled:(bool)highlightDisabled
{
    _highlightDisabled = highlightDisabled;
    [self _updateStripes];
}

- (void)setItemPosition:(int)itemPosition
{
    [self setItemPosition:itemPosition animated:false];
}

- (void)setItemPosition:(int)itemPosition animated:(bool)animated
{
    if (_itemPosition != itemPosition)
    {
        _itemPosition = itemPosition;
        if (animated)
        {
            [UIView animateWithDuration:0.25 animations:^
            {
                [self _updateStripes];
            }];
            [self setNeedsLayout];
        }
        else
        {
            [self _updateStripes];
            [self setNeedsLayout];
        }
    }
}

- (void)setIgnoreSeparatorInset:(bool)ignoreSeparatorInset
{
    _ignoreSeparatorInset = ignoreSeparatorInset;
    [self setNeedsLayout];
}

- (void)_updateStripes
{
    bool classicIOS6Style = [TGPresentation classicIOS6Style] && _itemPosition != 0;
    if (classicIOS6Style)
    {
        _classicIOS6BackgroundImageView.image = TGCollectionItemViewClassicIOS6Image(_itemPosition, false, _presentation);
        _classicIOS6SelectedBackgroundImageView.image = self.highlightDisabled ? nil : TGCollectionItemViewClassicIOS6Image(_itemPosition, true, _presentation);
        _classicIOS6BackgroundImageView.hidden = false;
        _classicIOS6SelectedBackgroundImageView.hidden = self.highlightDisabled;
        _topStripeView.alpha = 0.0f;
        _bottomStripeView.alpha = 0.0f;
        self.backgroundView.backgroundColor = [UIColor clearColor];
        self.selectedBackgroundView.backgroundColor = [UIColor clearColor];
    }
    else
    {
        _classicIOS6BackgroundImageView.image = nil;
        _classicIOS6SelectedBackgroundImageView.image = nil;
        _classicIOS6BackgroundImageView.hidden = true;
        _classicIOS6SelectedBackgroundImageView.hidden = true;
        _topStripeView.alpha = (_itemPosition & (TGCollectionItemViewPositionFirstInBlock | TGCollectionItemViewPositionLastInBlock | TGCollectionItemViewPositionMiddleInBlock)) == 0 ? 0.0f : 1.0f;
        _bottomStripeView.alpha = (_itemPosition & (TGCollectionItemViewPositionLastInBlock | TGCollectionItemViewPositionIncludeNextSeparator)) == 0 ? 0.0f : 1.0f;
        self.backgroundView.backgroundColor = _itemPosition == 0 ? [UIColor clearColor] : _presentation.pallete.collectionMenuCellBackgroundColor;
        self.selectedBackgroundView.backgroundColor = self.highlightDisabled ? [UIColor clearColor] : _presentation.pallete.collectionMenuCellSelectionColor;
    }
}

static void adjustSelectedBackgroundViewFrame(CGSize viewSize, int positionMask, UIEdgeInsets selectionInsets, UIView *backgroundView)
{
    CGRect frame = backgroundView.frame;
    
    CGFloat stripeHeight = TGScreenPixel;
    
    if ((positionMask & TGCollectionItemViewPositionFirstInBlock) && (positionMask & TGCollectionItemViewPositionLastInBlock))
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height;
    }
    else if (positionMask & (TGCollectionItemViewPositionLastInBlock | TGCollectionItemViewPositionIncludeNextSeparator))
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height;
    }
    else if (positionMask & TGCollectionItemViewPositionFirstInBlock)
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height + stripeHeight;
    }
    else
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height + stripeHeight;
    }
    
    frame.origin.y -= selectionInsets.top;
    frame.size.height += selectionInsets.top + selectionInsets.bottom;

    backgroundView.frame = frame;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    if (selected)
    {
        adjustSelectedBackgroundViewFrame(self.frame.size, _itemPosition, _selectionInsets, self.selectedBackgroundView);
        
        [self adjustOrdering];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if (highlighted)
    {
        adjustSelectedBackgroundViewFrame(self.frame.size, _itemPosition, _selectionInsets, self.selectedBackgroundView);
        
        [self adjustOrdering];
    }
}

- (void)adjustOrdering
{
    Class UITableViewCellClass = [PSUICollectionViewCell class];
    Class UISearchBarClass = [UISearchBar class];
    int maxCellIndex = 0;
    int index = -1;
    int selfIndex = 0;
    for (UIView *view in self.superview.subviews)
    {
        index++;
        if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])
        {
            maxCellIndex = index;
            
            if (view == self)
                selfIndex = index;
        }
    }
    
    if (selfIndex < maxCellIndex)
    {
        [self.superview insertSubview:self atIndex:maxCellIndex];
    }
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.bounds.size;
    
    adjustSelectedBackgroundViewFrame(viewSize, _itemPosition, _selectionInsets, self.selectedBackgroundView);
    
    static CGFloat stripeHeight = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        stripeHeight = TGScreenPixel;
    });
    
    if ([TGPresentation classicIOS6Style] && _itemPosition != 0)
    {
        CGFloat horizontalInset = _classicIOS6HorizontalInset > FLT_EPSILON ? _classicIOS6HorizontalInset : 9.0f;
        CGFloat leftInset = horizontalInset + self.safeAreaInset.left;
        CGFloat rightInset = horizontalInset + self.safeAreaInset.right;
        CGFloat width = MAX(0.0f, viewSize.width - leftInset - rightInset);
        _classicIOS6BackgroundImageView.frame = CGRectMake(leftInset, 0.0f, width, viewSize.height);
        _classicIOS6SelectedBackgroundImageView.frame = CGRectMake(leftInset, 0.0f, width, self.selectedBackgroundView.bounds.size.height);
        return;
    }

    CGFloat separatorInset = !_ignoreSeparatorInset ? _separatorInset + self.safeAreaInset.left : 0.0f;
    
    if (_itemPosition & TGCollectionItemViewPositionFirstInBlock)
        _topStripeView.frame = CGRectMake(0, 0, viewSize.width, stripeHeight);
    else
        _topStripeView.frame = CGRectMake(separatorInset, 0, viewSize.width - separatorInset, stripeHeight);
    
    if (_itemPosition & TGCollectionItemViewPositionLastInBlock)
        _bottomStripeView.frame = CGRectMake(0, viewSize.height - stripeHeight, viewSize.width, stripeHeight);
    else if (_itemPosition & TGCollectionItemViewPositionIncludeNextSeparator)
        _bottomStripeView.frame = CGRectMake(separatorInset, viewSize.height - stripeHeight, viewSize.width - separatorInset, stripeHeight);
}

@end
