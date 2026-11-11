#import "TGStickerKeyboardTabSettingsCell.h"

#import "TGStickerKeyboardTabPanel.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import "TGModernButton.h"
#import <QuartzCore/QuartzCore.h>

static void setViewFrame(UIView *view, CGRect frame)
{
    CGAffineTransform transform = view.transform;
    view.transform = CGAffineTransformIdentity;
    if (!CGRectEqualToRect(view.frame, frame))
        view.frame = frame;
    view.transform = transform;
}

@interface TGStickerKeyboardTabSettingsCell () {
    TGStickerKeyboardViewStyle _style;
    TGStickerKeyboardPallete *_pallete;
    
    TGModernButton *_button;
    
    UIView *_wrapperView;
    UIImageView *_imageView;
    UILabel *_badgeLabel;
    UIImageView *_badgeView;
}

@end

static UIImage *TGStickerKeyboardTabCustomEmojiIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat side = 24.0f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        UIColor *color = UIColorRGB(0x8a8e93);
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, 1.6f);
        CGContextStrokeEllipseInRect(context, CGRectMake(2.5f, 2.5f, side - 5.0f, side - 5.0f));
        CGContextFillEllipseInRect(context, CGRectMake(8.0f, 8.5f, 2.4f, 3.0f));
        CGContextFillEllipseInRect(context, CGRectMake(13.6f, 8.5f, 2.4f, 3.0f));
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextAddArc(context, side / 2.0f, 12.5f, 5.0f, (CGFloat)(M_PI * 0.15), (CGFloat)(M_PI * 0.85), 0);
        CGContextStrokePath(context);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

UIImage *TGStickerKeyboardCreateStickerIcon(UIColor *color)
{
    CGFloat side = 24.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.6f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextMoveToPoint(context, 15.0f, 3.0f);
    CGContextAddLineToPoint(context, 7.0f, 3.0f);
    CGContextAddArcToPoint(context, 3.0f, 3.0f, 3.0f, 7.0f, 4.0f);
    CGContextAddLineToPoint(context, 3.0f, 17.0f);
    CGContextAddArcToPoint(context, 3.0f, 21.0f, 7.0f, 21.0f, 4.0f);
    CGContextAddLineToPoint(context, 13.0f, 21.0f);
    CGContextAddLineToPoint(context, 21.0f, 13.0f);
    CGContextAddLineToPoint(context, 21.0f, 11.0f);
    CGContextStrokePath(context);
    CGContextMoveToPoint(context, 13.0f, 21.0f);
    CGContextAddLineToPoint(context, 13.0f, 15.0f);
    CGContextAddArcToPoint(context, 13.0f, 13.0f, 15.0f, 13.0f, 2.0f);
    CGContextAddLineToPoint(context, 21.0f, 13.0f);
    CGContextStrokePath(context);
    CGContextMoveToPoint(context, 18.5f, 2.5f);
    CGContextAddLineToPoint(context, 18.5f, 8.5f);
    CGContextMoveToPoint(context, 15.5f, 5.5f);
    CGContextAddLineToPoint(context, 21.5f, 5.5f);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TGStickerKeyboardTabCreateStickerIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = TGStickerKeyboardCreateStickerIcon(UIColorRGB(0x8a8e93));
    });
    return image;
}

@implementation TGStickerKeyboardTabSettingsCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _button = [[TGModernButton alloc] init];
        _button.modernHighlight = true;
        [_button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_button];
        
        _wrapperView = [[UIView alloc] init];
        _wrapperView.userInteractionEnabled = false;
        [self.contentView addSubview:_wrapperView];
        
        _imageView = [[UIImageView alloc] init];
        _imageView.image = TGComponentsImageNamed(@"StickerKeyboardSettingsIcon.png");
        _imageView.userInteractionEnabled = false;
        _imageView.contentMode = UIViewContentModeCenter;
        [_wrapperView addSubview:_imageView];
        
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = UIColorRGB(0xe6e6e6);
    }
    return self;
}

- (void)setPallete:(TGStickerKeyboardPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
    _badgeView.image = pallete.badge;
    _badgeLabel.textColor = pallete.badgeTextColor;
}

- (void)setMode:(TGStickerKeyboardTabSettingsCellMode)mode {
    _mode = mode;
    
    if (mode == TGStickerKeyboardTabSettingsCellSettings) {
        _imageView.image = _pallete != nil ? _pallete.settingsIcon : TGComponentsImageNamed(@"StickerKeyboardSettingsIcon.png");
    } else if (mode == TGStickerKeyboardTabSettingsCellGifs) {
        _imageView.image = _pallete != nil ? _pallete.gifIcon : TGComponentsImageNamed(@"StickerKeyboardGifIcon.png");
    } else if (mode == TGStickerKeyboardTabSettingsCellCustomEmoji) {
        _imageView.image = _pallete.customEmojiIcon ?: TGStickerKeyboardTabCustomEmojiIcon();
    } else if (mode == TGStickerKeyboardTabSettingsCellCreateSticker) {
        _imageView.image = _pallete.createStickerIcon ?: TGStickerKeyboardTabCreateStickerIcon();
    } else {
        _imageView.image = _pallete != nil ? _pallete.trendingIcon : TGComponentsImageNamed(@"StickerKeyboardTrendingIcon.png");
    }
    _button.hidden = mode != TGStickerKeyboardTabSettingsCellSettings && mode != TGStickerKeyboardTabSettingsCellCreateSticker;
}

- (void)setInnerAlpha:(CGFloat)innerAlpha
{
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 36.0f / 2.0f * (1.0f - innerAlpha));
    transform = CGAffineTransformScale(transform, innerAlpha, innerAlpha);
    
    _wrapperView.transform = transform;
    self.selectedBackgroundView.transform = transform;
}

- (void)setStyle:(TGStickerKeyboardViewStyle)style
{
    _style = style;
    
    switch (style)
    {
        case TGStickerKeyboardViewDarkBlurredStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGB(0x393939);
        }
            break;
            
        case TGStickerKeyboardViewPaintStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGB(0xdadada);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
        }
            break;
            
        case TGStickerKeyboardViewPaintDarkStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGBA(0xfbfffe, 0.47f);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
        }
            break;
            
        default:
        {
            self.selectedBackgroundView.backgroundColor = _pallete != nil ? _pallete.selectionColor : UIColorRGB(0xe6e7e9);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
        }
            break;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_badgeLabel != nil) {
        CGSize labelSize = _badgeLabel.frame.size;
        CGFloat badgeWidth = MAX(16.0f, labelSize.width + 6.0);
        _badgeView.frame = CGRectMake(self.frame.size.width - badgeWidth - 4.0, 6.0f, badgeWidth, 16.0f);
        _badgeLabel.frame = CGRectMake(CGRectGetMinX(_badgeView.frame) + TGRetinaFloor((badgeWidth - labelSize.width) / 2.0f), CGRectGetMinY(_badgeView.frame) + 1.0f, labelSize.width, labelSize.height);
    }
    
    if (_style == TGStickerKeyboardViewDefaultStyle)
    {
        setViewFrame(_wrapperView, CGRectOffset(self.bounds, 0.0f, -3.0f));
        setViewFrame(_imageView, self.bounds);
        
        _button.frame = self.bounds;
        
        setViewFrame(self.selectedBackgroundView, CGRectMake(floor((self.frame.size.width - 36.0f) / 2.0f), 0, 36.0f, 36.0f));
    }
    else
    {
        _wrapperView.frame = self.bounds;
        _button.frame = self.bounds;
        _imageView.frame = self.bounds;
    }
}

- (void)buttonPressed {
    if (_pressed) {
        _pressed();
    }
}

- (void)setBadge:(NSString *)badge {
    if (badge != nil) {
        if (_badgeLabel == nil) {
            _badgeLabel = [[UILabel alloc] init];
            _badgeLabel.font = TGSystemFontOfSize(12.0);
            _badgeLabel.backgroundColor = [UIColor clearColor];
            _badgeLabel.textColor = _pallete != nil ? _pallete.badgeTextColor : [UIColor whiteColor];
            [_wrapperView addSubview:_badgeLabel];
            
            static UIImage *badgeImage = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(16.0f, 16.0f), false, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                CGContextSetFillColorWithColor(context, UIColorRGB(0xff3b30).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 16.0f, 16.0f));
                
                badgeImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:7.0f topCapHeight:0.0f];
                UIGraphicsEndImageContext();
            });
            _badgeView = [[UIImageView alloc] initWithImage:_pallete != nil ? _pallete.badge : badgeImage];
            
            [_wrapperView addSubview:_badgeView];
            [_wrapperView addSubview:_badgeLabel];
        }
        _badgeLabel.text = badge;
        [_badgeLabel sizeToFit];
    } else {
        [_badgeView removeFromSuperview];
        _badgeView = nil;
        [_badgeLabel removeFromSuperview];
        _badgeLabel = nil;
    }
    
    [self setNeedsLayout];
}

@end
