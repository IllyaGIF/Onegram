#import "RMIntroStillIconsView.h"

#import "../../../../OnegramPlatform/OGPlatformDispatch.h"
#import "../../../../OnegramPlatform/OGPlatformGraphics.h"
#import "../../../../OnegramPlatform/OGPlatformVersion.h"

static const CGFloat RMIntroStillIconsAssetScale = 2.0f;
static const CGFloat RMIntroStillIconsMinimumScale = 0.8f;

@interface RMIntroStillIconsView ()
{
    NSArray *_imageNames;
    NSArray *_imageViews;
    CGSize *_nativeSizes;
    CGFloat _pagePosition;
    bool _keepsOnlyNeighbourImages;
}

@end

@implementation RMIntroStillIconsView

- (instancetype)initWithImageNames:(NSArray *)imageNames
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        self.backgroundColor = [UIColor clearColor];

        _imageNames = [imageNames copy];
        _keepsOnlyNeighbourImages = OGPlatformUsesConstrainedBackgroundExecution();
        _nativeSizes = (CGSize *)calloc(MAX(_imageNames.count, (NSUInteger)1), sizeof(CGSize));

        NSMutableArray *imageViews = [[NSMutableArray alloc] initWithCapacity:_imageNames.count];
        for (NSUInteger index = 0; index < _imageNames.count; index++)
        {
            UIImageView *imageView = [[UIImageView alloc] init];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.hidden = true;
            [self addSubview:imageView];
            [imageViews addObject:imageView];
        }
        _imageViews = imageViews;
    }
    return self;
}

- (void)dealloc
{
    free(_nativeSizes);
}

- (void)loadImageAtIndex:(NSUInteger)index
{
    UIImageView *imageView = [_imageViews objectAtIndex:index];
    if (imageView.image != nil)
        return;

    NSString *path = [[NSBundle mainBundle] pathForResource:[_imageNames objectAtIndex:index] ofType:@"png" inDirectory:@"Tour.bundle"];
    if (path.length == 0)
        return;

    UIImage *sourceImage = [UIImage imageWithContentsOfFile:path];
    if (sourceImage == nil)
        return;

    _nativeSizes[index] = CGSizeMake(sourceImage.size.width * sourceImage.scale / RMIntroStillIconsAssetScale, sourceImage.size.height * sourceImage.scale / RMIntroStillIconsAssetScale);

    UIImage *image = sourceImage;
    CGFloat boxSide = MIN(self.bounds.size.width, self.bounds.size.height);
    if (_keepsOnlyNeighbourImages && boxSide > 0.0f)
    {
        UIImage *thumbnail = OGPlatformThumbnailFromImageFile(path, (size_t)ceil(boxSide * OGPlatformScreenScale()));
        if (thumbnail != nil)
            image = thumbnail;
    }

    imageView.image = image;
    [self layoutImageViewAtIndex:index];
}

- (void)unloadImageAtIndex:(NSUInteger)index
{
    UIImageView *imageView = [_imageViews objectAtIndex:index];
    imageView.image = nil;
    imageView.hidden = true;
}

- (void)layoutImageViewAtIndex:(NSUInteger)index
{
    UIImageView *imageView = [_imageViews objectAtIndex:index];
    CGSize boxSize = self.bounds.size;
    CGSize nativeSize = _nativeSizes[index];

    CGSize size = boxSize;
    if (nativeSize.width > 0.0f && nativeSize.height > 0.0f)
    {
        CGFloat fitScale = MIN(1.0f, MIN(boxSize.width / nativeSize.width, boxSize.height / nativeSize.height));
        size = CGSizeMake(floor(nativeSize.width * fitScale), floor(nativeSize.height * fitScale));
    }

    imageView.bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);
    imageView.center = CGPointMake(boxSize.width / 2.0f, boxSize.height / 2.0f);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    for (NSUInteger index = 0; index < _imageViews.count; index++)
        [self layoutImageViewAtIndex:index];
    [self updateVisibleImages];
}

- (void)setPagePosition:(CGFloat)pagePosition
{
    CGFloat maxPosition = (CGFloat)MAX((NSInteger)_imageViews.count - 1, 0);
    _pagePosition = MAX(0.0f, MIN(maxPosition, pagePosition));
    [self updateVisibleImages];
}

- (void)updateVisibleImages
{
    if (self.bounds.size.width <= 0.0f || self.bounds.size.height <= 0.0f)
        return;

    NSInteger lowerIndex = (NSInteger)floor(_pagePosition);
    NSInteger upperIndex = lowerIndex + 1;
    CGFloat progress = _pagePosition - lowerIndex;

    for (NSInteger index = 0; index < (NSInteger)_imageViews.count; index++)
    {
        UIImageView *imageView = [_imageViews objectAtIndex:index];

        CGFloat visibility = 0.0f;
        if (index == lowerIndex)
            visibility = 1.0f - progress;
        else if (index == upperIndex)
            visibility = progress;

        bool isNeighbour = index >= lowerIndex - 1 && index <= upperIndex + 1;
        if (isNeighbour)
            [self loadImageAtIndex:(NSUInteger)index];
        else if (_keepsOnlyNeighbourImages)
            [self unloadImageAtIndex:(NSUInteger)index];

        CGFloat alpha = MAX(0.0f, (visibility - 0.25f) / 0.75f);
        if (alpha <= 0.0f)
        {
            imageView.hidden = true;
            continue;
        }

        CGFloat scale = RMIntroStillIconsMinimumScale + (1.0f - RMIntroStillIconsMinimumScale) * visibility;
        imageView.hidden = false;
        imageView.alpha = alpha;
        imageView.transform = CGAffineTransformMakeScale(scale, scale);
    }
}

@end
