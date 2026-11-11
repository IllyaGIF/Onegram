#import "TGStickerCreationPreviewItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressSpinnerView.h"

static const CGFloat TGStickerCreationPreviewSide = 200.0f;

static UIImage *TGStickerCreationCheckerboardImage(UIColor *lightColor, UIColor *darkColor)
{
    CGFloat cell = 8.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(cell * 2.0f, cell * 2.0f), true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, lightColor.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, cell * 2.0f, cell * 2.0f));
    CGContextSetFillColorWithColor(context, darkColor.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, cell, cell));
    CGContextFillRect(context, CGRectMake(cell, cell, cell, cell));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGStickerCreationPreviewItemView ()
{
    UIView *_backgroundView;
    UIImageView *_imageView;
    TGActivityIndicatorView *_activityIndicator;
}

@end

@implementation TGStickerCreationPreviewItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _backgroundView = [[UIView alloc] init];
        _backgroundView.clipsToBounds = true;
        _backgroundView.layer.cornerRadius = 12.0f;
        [self addSubview:_backgroundView];

        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_backgroundView addSubview:_imageView];

        bool coloredIndicator = [UIActivityIndicatorView instancesRespondToSelector:@selector(setColor:)];
        _activityIndicator = [[TGActivityIndicatorView alloc] initWithActivityIndicatorStyle:coloredIndicator ? UIActivityIndicatorViewStyleWhiteLarge : UIActivityIndicatorViewStyleGray];
        _activityIndicator.hidesWhenStopped = true;
        [self addSubview:_activityIndicator];

        [self updateBackground];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    [self updateBackground];
}

- (void)updateBackground
{
    UIColor *baseColor = self.presentation.pallete.collectionMenuCellBackgroundColor ?: [UIColor whiteColor];
    UIColor *checkColor = self.presentation.pallete.collectionMenuSeparatorColor ?: UIColorRGB(0xe1e1e1);
    _backgroundView.backgroundColor = [UIColor colorWithPatternImage:TGStickerCreationCheckerboardImage(baseColor, [checkColor colorWithAlphaComponent:0.6f])];
    _activityIndicator.color = self.presentation.pallete.collectionMenuCommentColor ?: [UIColor grayColor];
}

- (void)setImage:(UIImage *)image
{
    _imageView.image = image;
}

- (void)setProcessing:(bool)processing
{
    _imageView.alpha = processing ? 0.4f : 1.0f;
    if (processing)
        [_activityIndicator startAnimating];
    else
        [_activityIndicator stopAnimating];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.bounds.size;
    CGFloat side = MIN(TGStickerCreationPreviewSide, size.height - 24.0f);
    _backgroundView.frame = CGRectMake(CGFloor((size.width - side) / 2.0f), CGFloor((size.height - side) / 2.0f), side, side);
    _imageView.frame = CGRectInset(_backgroundView.bounds, 8.0f, 8.0f);
    _activityIndicator.center = CGPointMake(CGRectGetMidX(_backgroundView.frame), CGRectGetMidY(_backgroundView.frame));
}

@end
