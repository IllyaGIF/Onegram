#import "TGStarGiftHeaderCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCollectionItemView.h"
#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGPresentation.h"

static const CGSize TGStarGiftHeaderTileSize = {150.0f, 170.0f};

@interface TGStarGiftHeaderCollectionItemView : TGCollectionItemView
{
    TGStarGiftTileView *_tileView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
}

- (void)setGift:(TGStarGift *)gift title:(NSString *)title subtitle:(NSString *)subtitle;

@end

@implementation TGStarGiftHeaderCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _tileView = [[TGStarGiftTileView alloc] init];
        _tileView.userInteractionEnabled = false;
        [self.contentView addSubview:_tileView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGMediumSystemFontOfSize(20.0f);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(14.0f);
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 2;
        [self.contentView addSubview:_subtitleLabel];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _tileView.presentation = presentation;
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
}

- (void)setGift:(TGStarGift *)gift title:(NSString *)title subtitle:(NSString *)subtitle
{
    [_tileView setGift:gift caption:nil];
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    _tileView.frame = CGRectMake(CGFloor((bounds.size.width - TGStarGiftHeaderTileSize.width) / 2.0f), 12.0f, TGStarGiftHeaderTileSize.width, TGStarGiftHeaderTileSize.height);
    _titleLabel.frame = CGRectMake(15.0f, CGRectGetMaxY(_tileView.frame) + 12.0f, bounds.size.width - 30.0f, 26.0f);
    _subtitleLabel.frame = CGRectMake(15.0f, CGRectGetMaxY(_titleLabel.frame) + 2.0f, bounds.size.width - 30.0f, 36.0f);
}

@end

@implementation TGStarGiftHeaderCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.transparent = true;
        self.selectable = false;
        self.highlightable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGStarGiftHeaderCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 12.0f + TGStarGiftHeaderTileSize.height + 12.0f + 26.0f + 2.0f + 36.0f + 8.0f);
}

- (void)bindView:(TGStarGiftHeaderCollectionItemView *)view
{
    [super bindView:view];
    [view setGift:_gift title:_title subtitle:_subtitle];
}

@end
