#import "TGStoryThumbnailTileView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"

#import "TGPresentation.h"
#import "TGStoryItem.h"
#import "TGStoriesSignals.h"
#import "TGProfileActionsCollectionItemView.h"

const CGSize TGStoryThumbnailTileSize = {84.0f, 150.0f};

@interface TGStoryThumbnailTileView ()
{
    TGImageView *_imageView;
    UIImageView *_addView;
    UIView *_overlayView;
}

@end

@implementation TGStoryThumbnailTileView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        self.layer.cornerRadius = 10.0f;
        self.backgroundColor = UIColorRGB(0x202020);
        _imageView = [[TGImageView alloc] init];
        _imageView.userInteractionEnabled = false;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        _overlayView = [[UIView alloc] init];
        _overlayView.userInteractionEnabled = false;
        _overlayView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
        _overlayView.hidden = true;
        [self addSubview:_overlayView];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    _overlayView.hidden = !highlighted;
}

- (void)setStory:(TGStoryItem *)story
{
    _addView.hidden = true;
    _imageView.hidden = false;
    [_imageView setSignal:[TGStoriesSignals thumbnailForStory:story size:TGStoryThumbnailTileSize]];
}

- (void)setAddTileWithPresentation:(TGPresentation *)presentation
{
    [_imageView reset];
    _imageView.hidden = true;
    TGPresentationPallete *pallete = presentation.pallete;
    self.backgroundColor = pallete.isDark ? pallete.collectionMenuCellBackgroundColor : pallete.collectionMenuBackgroundColor;
    if (_addView == nil)
    {
        _addView = [[UIImageView alloc] init];
        [self addSubview:_addView];
    }
    _addView.hidden = false;
    _addView.image = TGProfileActionGlyphImage(TGProfileActionIconStory, presentation.pallete.collectionMenuAccentColor);
    [_addView sizeToFit];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _imageView.frame = self.bounds;
    _overlayView.frame = self.bounds;
    _addView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

@end
