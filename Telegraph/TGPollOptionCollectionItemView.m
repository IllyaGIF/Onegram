#import "TGPollOptionCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

static UIImage *TGPollOptionRadioImage(UIColor *color, bool selected)
{
    CGFloat side = 22.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(1.0f, 1.0f, side - 2.0f, side - 2.0f);
    if (selected)
    {
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, rect);
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(context, 2.0f);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextMoveToPoint(context, 6.5f, 11.5f);
        CGContextAddLineToPoint(context, 9.5f, 14.5f);
        CGContextAddLineToPoint(context, 15.5f, 8.0f);
        CGContextStrokePath(context);
    }
    else
    {
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, 1.5f);
        CGContextStrokeEllipseInRect(context, CGRectInset(rect, 0.75f, 0.75f));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TGPollOptionDeleteImage(UIColor *color)
{
    CGFloat side = 22.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(2.0f, 2.0f, side - 4.0f, side - 4.0f));
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, 7.5f, 7.5f);
    CGContextAddLineToPoint(context, side - 7.5f, side - 7.5f);
    CGContextMoveToPoint(context, side - 7.5f, 7.5f);
    CGContextAddLineToPoint(context, 7.5f, side - 7.5f);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGPollOptionCollectionItemView ()
{
    UIButton *_correctButton;
    UIButton *_deleteButton;
    bool _quiz;
    bool _correct;
    bool _canDelete;
}

@end

@implementation TGPollOptionCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _correctButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _correctButton.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
        _correctButton.hidden = true;
        [_correctButton addTarget:self action:@selector(correctButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_correctButton];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
        _deleteButton.hidden = true;
        [_deleteButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_deleteButton];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    [self updateImages];
}

- (void)updateImages
{
    UIColor *accentColor = self.presentation.pallete.collectionMenuCheckColor ?: (self.presentation.pallete.collectionMenuAccentColor ?: UIColorRGB(0x007aff));
    UIColor *borderColor = self.presentation.pallete.collectionMenuPlaceholderColor ?: UIColorRGB(0xc7c7cd);
    UIColor *deleteColor = self.presentation.pallete.collectionMenuPlaceholderColor ?: UIColorRGB(0xc7c7cd);
    [_correctButton setImage:TGPollOptionRadioImage(_correct ? accentColor : borderColor, _correct) forState:UIControlStateNormal];
    [_deleteButton setImage:TGPollOptionDeleteImage(deleteColor) forState:UIControlStateNormal];
}

- (void)setQuiz:(bool)quiz correct:(bool)correct canDelete:(bool)canDelete
{
    bool imagesChanged = _correct != correct;
    _quiz = quiz;
    _correct = correct;
    _canDelete = canDelete;
    _correctButton.hidden = !quiz;
    _deleteButton.hidden = !canDelete;
    if (imagesChanged || _correctButton.imageView.image == nil)
        [self updateImages];
    [self setNeedsLayout];
}

- (void)correctButtonPressed
{
    if (_correctPressed)
        _correctPressed();
}

- (void)deleteButtonPressed
{
    if (_deletePressed)
        _deletePressed();
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    CGFloat lineCenter = MIN(bounds.size.height / 2.0f, 22.0f);
    _correctButton.frame = CGRectMake(self.safeAreaInset.left + 1.0f, CGFloor(lineCenter - 22.0f), 44.0f, 44.0f);
    _deleteButton.frame = CGRectMake(bounds.size.width - self.safeAreaInset.right - 45.0f, CGFloor(lineCenter - 22.0f), 44.0f, 44.0f);
}

@end
