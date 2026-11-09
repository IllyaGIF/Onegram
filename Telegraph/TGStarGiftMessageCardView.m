#import "TGStarGiftMessageCardView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftCoverView.h"
#import "TGAnimatedStickerView.h"
#import "TGPresentation.h"
#import <math.h>

static const CGFloat TGStarGiftMessageCardInset = 2.0f;
static const CGFloat TGStarGiftMessageCardRadius = 24.0f;
static const CGFloat TGStarGiftMessageCoverInset = 4.0f;
static const CGFloat TGStarGiftMessageCoverRadius = 20.0f;
static const CGFloat TGStarGiftMessageCoverAvatarCenterY = 104.0f;
static const CGFloat TGStarGiftMessageStickerSide = 120.0f;
static const CGFloat TGStarGiftMessageStickerOffset = 16.0f;
static const CGFloat TGStarGiftMessageChatRibbonSide = 68.0f;
static const CGFloat TGStarGiftMessageRibbonSide = 58.0f;
static const CGFloat TGStarGiftMessageButtonHeight = 34.0f;
static const CGFloat TGStarGiftMessageButtonPadding = 19.0f;
static const CGFloat TGStarGiftMessageCreatorRadius = 9.0f;
static const CGFloat TGStarGiftMessageBubbleDiameter = 33.0f;
static const CGFloat TGStarGiftMessageBubbleRadius = 14.0f;

static void TGStarGiftMessageAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    CGContextMoveToPoint(context, CGRectGetMinX(rect) + radius, CGRectGetMinY(rect));
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMaxY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMaxY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMinY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMinY(rect), radius);
    CGContextClosePath(context);
}

static void TGStarGiftMessageAddChatRibbonPath(CGContextRef context)
{
    CGContextMoveToPoint(context, 62.376f, 34.376f);
    CGContextAddLineToPoint(context, 33.624f, 5.624f);
    CGContextAddCurveToPoint(context, 31.548f, 3.548f, 30.510f, 2.510f, 29.299f, 1.768f);
    CGContextAddCurveToPoint(context, 28.226f, 1.110f, 27.055f, 0.626f, 25.831f, 0.332f);
    CGContextAddCurveToPoint(context, 24.450f, 0.0f, 22.982f, 0.0f, 20.047f, 0.0f);
    CGContextAddLineToPoint(context, 7.725f, 0.0f);
    CGContextAddCurveToPoint(context, 5.302f, 0.0f, 4.091f, 0.0f, 3.530f, 0.479f);
    CGContextAddCurveToPoint(context, 3.043f, 0.895f, 2.784f, 1.519f, 2.835f, 2.157f);
    CGContextAddCurveToPoint(context, 2.892f, 2.892f, 3.749f, 3.749f, 5.463f, 5.463f);
    CGContextAddLineToPoint(context, 62.537f, 62.537f);
    CGContextAddCurveToPoint(context, 64.251f, 64.251f, 65.108f, 65.108f, 65.843f, 65.165f);
    CGContextAddCurveToPoint(context, 66.481f, 65.216f, 67.105f, 64.957f, 67.521f, 64.470f);
    CGContextAddCurveToPoint(context, 68.0f, 63.909f, 68.0f, 62.698f, 68.0f, 60.275f);
    CGContextAddLineToPoint(context, 68.0f, 47.953f);
    CGContextAddCurveToPoint(context, 68.0f, 45.018f, 68.0f, 43.550f, 67.668f, 42.169f);
    CGContextAddCurveToPoint(context, 67.374f, 40.945f, 66.890f, 39.774f, 66.232f, 38.701f);
    CGContextAddCurveToPoint(context, 65.490f, 37.490f, 64.452f, 36.452f, 62.376f, 34.376f);
    CGContextClosePath(context);
}

static NSCache *TGStarGiftMessageImageCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = 4 * 1024 * 1024;
    });
    return cache;
}

static void TGStarGiftMessageCacheImage(UIImage *image, NSString *key)
{
    if (image == nil)
        return;
    [TGStarGiftMessageImageCache() setObject:image forKey:key cost:(NSUInteger)(image.size.width * image.size.height * image.scale * image.scale * 4.0f)];
}

static UIImage *TGStarGiftMessagePlateImage(CGSize size, UIColor *color, bool ribbon)
{
    if (color == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    NSString *key = [[NSString alloc] initWithFormat:@"plate:%dx%d:%08x:%d", (int)ceil(size.width), (int)ceil(size.height), TGColorHexCodeWithAlpha(color), ribbon ? 1 : 0];
    UIImage *image = [TGStarGiftMessageImageCache() objectForKey:key];
    if (image != nil)
        return image;
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorRef opaqueColor = CGColorCreateCopyWithAlpha(color.CGColor, 1.0f);
    CGContextSetAlpha(context, CGColorGetAlpha(color.CGColor));
    CGContextBeginTransparencyLayer(context, NULL);
    CGContextSetFillColorWithColor(context, opaqueColor);
    TGStarGiftMessageAddRoundedRect(context, CGRectInset(CGRectMake(0.0f, 0.0f, size.width, size.height), TGStarGiftMessageCardInset, TGStarGiftMessageCardInset), TGStarGiftMessageCardRadius);
    CGContextFillPath(context);
    if (ribbon)
    {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, size.width - TGStarGiftMessageChatRibbonSide, 0.0f);
        TGStarGiftMessageAddChatRibbonPath(context);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
    }
    CGContextEndTransparencyLayer(context);
    CGColorRelease(opaqueColor);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    TGStarGiftMessageCacheImage(image, key);
    return image;
}

static UIImage *TGStarGiftMessageChatRibbonImage(UIColor *color)
{
    NSString *key = [[NSString alloc] initWithFormat:@"ribbon:%08x", TGColorHexCodeWithAlpha(color)];
    UIImage *image = [TGStarGiftMessageImageCache() objectForKey:key];
    if (image != nil)
        return image;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(TGStarGiftMessageChatRibbonSide, TGStarGiftMessageChatRibbonSide), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    TGStarGiftMessageAddChatRibbonPath(context);
    CGContextFillPath(context);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    TGStarGiftMessageCacheImage(image, key);
    return image;
}

static void TGStarGiftMessageAddBubbleBody(CGContextRef context, CGFloat offset)
{
    CGFloat side = TGStarGiftMessageBubbleDiameter;
    CGFloat radius = TGStarGiftMessageBubbleRadius;
    CGFloat arcRadius = radius + offset * 2.0f;
    CGContextMoveToPoint(context, -offset, radius + offset);
    CGContextAddArcToPoint(context, -offset, -offset, radius + offset, -offset, arcRadius);
    CGContextAddLineToPoint(context, side - radius - offset, -offset);
    CGContextAddArcToPoint(context, side + offset, -offset, side + offset, radius + offset, arcRadius);
    CGContextAddLineToPoint(context, side + offset, side - radius - offset);
    CGContextAddArcToPoint(context, side + offset, side + offset, side - radius - offset, side + offset, arcRadius);
    CGContextAddLineToPoint(context, radius + offset, side + offset);
    CGContextAddArcToPoint(context, -offset, side + offset, -offset, side - radius - offset, arcRadius);
    CGContextClosePath(context);
}

static void TGStarGiftMessageAddBubbleTail(CGContextRef context, CGRect ellipse)
{
    CGContextMoveToPoint(context, CGRectGetMinX(ellipse), CGRectGetMidY(ellipse));
    CGContextAddQuadCurveToPoint(context, CGRectGetMinX(ellipse), CGRectGetMaxY(ellipse), CGRectGetMidX(ellipse), CGRectGetMaxY(ellipse));
    CGContextAddQuadCurveToPoint(context, CGRectGetMaxX(ellipse), CGRectGetMaxY(ellipse), CGRectGetMaxX(ellipse), CGRectGetMidY(ellipse));
}

static CGSize TGStarGiftMessageBubbleRawSize(void)
{
    return CGSizeMake(TGStarGiftMessageBubbleDiameter + 6.0f + 4.0f, TGStarGiftMessageBubbleDiameter + 4.0f);
}

static UIImage *TGStarGiftMessageMirroredImage(UIImage *image)
{
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, image.size.width, 0.0f);
    CGContextScaleCTM(context, -1.0f, 1.0f);
    [image drawAtPoint:CGPointZero];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

static UIImage *TGStarGiftMessageBubbleFormImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGRect bottomEllipse = CGRectMake(24.0f, 16.0f, 27.0f, 17.0f);
        CGRect topEllipse = CGRectMake(33.0f, 14.0f, 23.0f, 21.0f);
        CGFloat side = TGStarGiftMessageBubbleDiameter;
        UIGraphicsBeginImageContextWithOptions(TGStarGiftMessageBubbleRawSize(), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(context, 2.0f, 2.0f);
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        TGStarGiftMessageAddBubbleBody(context, 0.0f);
        CGContextFillPath(context);
        TGStarGiftMessageAddBubbleTail(context, bottomEllipse);
        CGContextFillPath(context);
        CGContextFillRect(context, CGRectMake(side / 2.0f, CGFloor(side / 2.0f), side / 2.0f, CGCeil(CGRectGetMidY(bottomEllipse)) - CGFloor(side / 2.0f)));
        CGContextSetBlendMode(context, kCGBlendModeClear);
        CGContextFillEllipseInRect(context, topEllipse);
        image = TGStarGiftMessageMirroredImage(UIGraphicsGetImageFromCurrentImageContext());
        UIGraphicsEndImageContext();
    });
    return image;
}

static UIImage *TGStarGiftMessageBubbleOutlineImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGRect bottomEllipse = CGRectMake(24.0f, 16.0f, 27.0f, 17.0f);
        CGRect topEllipse = CGRectMake(33.0f, 14.0f, 23.0f, 21.0f);
        CGFloat side = TGStarGiftMessageBubbleDiameter;
        CGFloat innerExtension = 0.25f;
        CGFloat borderWidth = TGScreenPixel + innerExtension;
        CGFloat borderOffset = ABS(TGScreenPixel - 0.5f) < FLT_EPSILON ? -innerExtension / 2.0f + TGScreenPixel / 2.0f : -innerExtension / 2.0f;
        CGRect outlineBottomEllipse = CGRectInset(bottomEllipse, -borderOffset, -borderOffset);
        CGRect outlineTopEllipse = CGRectInset(topEllipse, borderOffset, borderOffset);
        CGSize rawSize = TGStarGiftMessageBubbleRawSize();

        UIGraphicsBeginImageContextWithOptions(rawSize, false, 0.0f);
        CGContextRef tailContext = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(tailContext, 2.0f, 2.0f);
        CGContextSetStrokeColorWithColor(tailContext, [UIColor blackColor].CGColor);
        CGContextSetLineWidth(tailContext, borderWidth);
        TGStarGiftMessageAddBubbleTail(tailContext, outlineBottomEllipse);
        CGContextStrokePath(tailContext);
        CGContextSetBlendMode(tailContext, kCGBlendModeClear);
        CGContextFillEllipseInRect(tailContext, outlineTopEllipse);
        TGStarGiftMessageAddBubbleBody(tailContext, 0.0f);
        CGContextFillPath(tailContext);
        CGContextSetBlendMode(tailContext, kCGBlendModeNormal);
        CGContextSaveGState(tailContext);
        CGContextAddEllipseInRect(tailContext, outlineBottomEllipse);
        CGContextClip(tailContext);
        CGRect maskBounds = CGRectInset(bottomEllipse, -1.0f, -1.0f);
        CGContextClipToRect(tailContext, CGRectMake(CGRectGetMinX(maskBounds), CGRectGetMidY(maskBounds), maskBounds.size.width, maskBounds.size.height / 2.0f));
        CGContextStrokeEllipseInRect(tailContext, outlineTopEllipse);
        CGContextRestoreGState(tailContext);
        UIImage *tailImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIGraphicsBeginImageContextWithOptions(rawSize, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(context, 2.0f, 2.0f);
        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextSetLineWidth(context, borderWidth);
        TGStarGiftMessageAddBubbleBody(context, borderOffset);
        CGContextStrokePath(context);
        CGContextSetBlendMode(context, kCGBlendModeClear);
        TGStarGiftMessageAddBubbleTail(context, bottomEllipse);
        CGContextFillPath(context);
        CGContextFillRect(context, CGRectMake(CGFloor(side / 2.0f), side / 2.0f, side / 2.0f + borderWidth, CGCeil(CGRectGetMidY(bottomEllipse)) - CGFloor(side / 2.0f)));
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        CGContextMoveToPoint(context, side + borderOffset, side / 2.0f);
        CGContextAddLineToPoint(context, side + borderOffset, CGRectGetMidY(outlineBottomEllipse));
        CGContextStrokePath(context);
        CGContextTranslateCTM(context, -2.0f, -2.0f);
        [tailImage drawAtPoint:CGPointZero];
        image = TGStarGiftMessageMirroredImage(UIGraphicsGetImageFromCurrentImageContext());
        UIGraphicsEndImageContext();
    });
    return image;
}

static UIImage *TGStarGiftMessageStretchableBubble(UIImage *image)
{
    CGSize rawSize = TGStarGiftMessageBubbleRawSize();
    NSInteger outgoingStretchX = (NSInteger)(1.0f + 1.0f + roundf(TGStarGiftMessageBubbleDiameter / 2.0f)) - 1;
    NSInteger stretchX = (NSInteger)(rawSize.width - 2.0f) - outgoingStretchX + 1;
    NSInteger stretchY = (NSInteger)(1.0f + 1.0f + roundf(TGStarGiftMessageBubbleDiameter / 2.0f));
    return [image stretchableImageWithLeftCapWidth:stretchX topCapHeight:stretchY];
}

static UIImage *TGStarGiftMessageBubbleImage(UIColor *fillColor, CGSize size)
{
    if (fillColor == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    NSString *key = [[NSString alloc] initWithFormat:@"bubble:%dx%d:%08x", (int)ceil(size.width), (int)ceil(size.height), TGColorHexCodeWithAlpha(fillColor)];
    UIImage *image = [TGStarGiftMessageImageCache() objectForKey:key];
    if (image != nil)
        return image;
    CGRect bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef gradientContext = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)[UIColor colorWithWhite:1.0f alpha:0.5f].CGColor, (__bridge id)[UIColor colorWithWhite:1.0f alpha:0.5f].CGColor, (__bridge id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor, (__bridge id)[UIColor colorWithWhite:1.0f alpha:0.5f].CGColor, (__bridge id)[UIColor colorWithWhite:1.0f alpha:0.5f].CGColor];
    CGFloat locations[] = {0.0f, 0.1f, 0.5f, 0.9f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGFloat direction = (CGFloat)cos(M_PI / 4.0);
    CGPoint center = CGPointMake(size.width / 2.0f, size.height / 2.0f);
    CGFloat extent = direction * size.width / 2.0f + direction * size.height / 2.0f;
    CGContextDrawLinearGradient(gradientContext, gradient, CGPointMake(center.x - direction * extent, center.y - direction * extent), CGPointMake(center.x + direction * extent, center.y + direction * extent), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    [TGStarGiftMessageStretchableBubble(TGStarGiftMessageBubbleOutlineImage()) drawInRect:bounds blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    UIImage *outline = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [TGStarGiftMessageStretchableBubble(TGStarGiftMessageBubbleFormImage()) drawInRect:bounds];
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    CGContextSetFillColorWithColor(context, fillColor.CGColor);
    CGContextFillRect(context, bounds);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    [outline drawInRect:bounds];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    TGStarGiftMessageCacheImage(image, key);
    return image;
}

@implementation TGStarGiftMessageCardContent

@end

@interface TGStarGiftMessageCardView () <UIGestureRecognizerDelegate>
{
    UIImageView *_plateView;
    TGStarGiftCoverView *_coverView;
    TGAnimatedStickerView *_stickerView;
    TGImageView *_staticStickerView;
    UIView *_creatorBackgroundView;
    UIImageView *_bubbleView;
    TGLetteredAvatarView *_avatarView;
    UIControl *_buttonView;
    UILabel *_buttonLabel;
    UIImageView *_ribbonView;
    UILabel *_ribbonLabel;
    UITapGestureRecognizer *_tapRecognizer;
    UILongPressGestureRecognizer *_longPressRecognizer;
    TGStarGiftMessageCardContent *_content;
    int64_t _stickerDocumentId;
    int64_t _avatarPeerId;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGStarGiftMessageCardView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _plateView = [[UIImageView alloc] init];
        [self addSubview:_plateView];

        _coverView = [[TGStarGiftCoverView alloc] init];
        _coverView.clipsToBounds = true;
        _coverView.layer.cornerRadius = TGStarGiftMessageCoverRadius;
        _coverView.hidden = true;
        [self addSubview:_coverView];

        _stickerView = [[TGAnimatedStickerView alloc] init];
        _stickerView.loops = false;
        _stickerView.playing = false;
        _stickerView.usesSourceFrameRate = true;
        _stickerView.restsOnLastFrame = true;
        _stickerView.userInteractionEnabled = false;
        __weak TGStarGiftMessageCardView *weakSelf = self;
        _stickerView.playbackFinished = ^
        {
            __strong TGStarGiftMessageCardView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_stickerFinished != nil)
                strongSelf->_stickerFinished();
        };
        [self addSubview:_stickerView];

        _staticStickerView = [[TGImageView alloc] init];
        _staticStickerView.contentMode = UIViewContentModeScaleAspectFit;
        _staticStickerView.userInteractionEnabled = false;
        _staticStickerView.hidden = true;
        [self addSubview:_staticStickerView];

        _creatorBackgroundView = [[UIView alloc] init];
        _creatorBackgroundView.clipsToBounds = true;
        _creatorBackgroundView.layer.cornerRadius = TGStarGiftMessageCreatorRadius;
        _creatorBackgroundView.userInteractionEnabled = false;
        _creatorBackgroundView.hidden = true;
        [self addSubview:_creatorBackgroundView];

        _bubbleView = [[UIImageView alloc] init];
        _bubbleView.hidden = true;
        [self addSubview:_bubbleView];

        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 22.0f, 22.0f)];
        [_avatarView setSingleFontSize:12.0f doubleFontSize:12.0f useBoldFont:false];
        _avatarView.fadeTransition = true;
        _avatarView.userInteractionEnabled = false;
        _avatarView.hidden = true;
        [self addSubview:_avatarView];

        _buttonView = [[UIControl alloc] init];
        _buttonView.clipsToBounds = true;
        _buttonView.layer.cornerRadius = TGStarGiftMessageButtonHeight / 2.0f;
        _buttonView.hidden = true;
        [_buttonView addTarget:self action:@selector(buttonTouchDown) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [_buttonView addTarget:self action:@selector(buttonTouchCancelled) forControlEvents:UIControlEventTouchDragExit | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [_buttonView addTarget:self action:@selector(buttonTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_buttonView];

        _buttonLabel = [[UILabel alloc] init];
        _buttonLabel.backgroundColor = [UIColor clearColor];
        _buttonLabel.font = TGSemiboldSystemFontOfSize(15.0f);
        _buttonLabel.textAlignment = NSTextAlignmentCenter;
        _buttonLabel.userInteractionEnabled = false;
        [_buttonView addSubview:_buttonLabel];

        _ribbonView = [[UIImageView alloc] init];
        _ribbonView.userInteractionEnabled = false;
        _ribbonView.hidden = true;
        [self addSubview:_ribbonView];

        _ribbonLabel = [[UILabel alloc] init];
        _ribbonLabel.backgroundColor = [UIColor clearColor];
        _ribbonLabel.font = TGSemiboldSystemFontOfSize(11.0f);
        _ribbonLabel.textAlignment = NSTextAlignmentCenter;
        _ribbonLabel.userInteractionEnabled = false;
        _ribbonLabel.hidden = true;
        [self addSubview:_ribbonLabel];

        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
        _tapRecognizer.delegate = self;
        [self addGestureRecognizer:_tapRecognizer];

        _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGesture:)];
        _longPressRecognizer.minimumPressDuration = 0.5;
        _longPressRecognizer.delegate = self;
        [self addGestureRecognizer:_longPressRecognizer];
    }
    return self;
}

- (void)willBecomeRecycled
{
    _stickerView.playing = false;
    _pressed = nil;
    _buttonPressed = nil;
    _creatorPressed = nil;
    _longPressed = nil;
    _stickerFinished = nil;
}

- (void)setContent:(TGStarGiftMessageCardContent *)content
{
    _content = content;
    TGStarGift *gift = content.gift;

    _coverView.hidden = !content.cover;
    [_coverView setGift:content.cover ? gift : nil];

    TGDocumentMediaAttachment *sticker = gift.sticker;
    if (_stickerDocumentId != sticker.documentId || sticker == nil)
    {
        _stickerDocumentId = sticker.documentId;
        bool animatedSticker = sticker != nil && [TGAnimatedStickerView isAnimatedStickerDocument:sticker];
        _stickerView.hidden = !animatedSticker;
        _staticStickerView.hidden = animatedSticker || sticker == nil;
        NSString *placeholderUri = sticker != nil ? [TGAnimatedStickerView placeholderUriForDocument:sticker size:CGSizeMake(TGStarGiftMessageStickerSide * 2.0f, TGStarGiftMessageStickerSide * 2.0f)] : nil;
        if (animatedSticker)
        {
            [_staticStickerView reset];
            [_stickerView setDocument:sticker placeholderUri:placeholderUri];
        }
        else
        {
            [_stickerView reset];
            if (placeholderUri != nil)
                [_staticStickerView loadUri:placeholderUri withOptions:@{}];
            else
                [_staticStickerView reset];
        }
    }

    _buttonView.hidden = content.buttonTitle.length == 0;
    _buttonView.backgroundColor = content.overlayColor;
    _buttonLabel.text = content.buttonTitle;
    _buttonLabel.textColor = content.textColor;

    _creatorBackgroundView.hidden = CGRectIsEmpty(content.creatorFrame);
    _creatorBackgroundView.backgroundColor = content.overlayColor;

    bool bubble = !CGRectIsEmpty(content.bubbleFrame);
    _bubbleView.hidden = !bubble;
    _bubbleView.image = bubble ? TGStarGiftMessageBubbleImage(content.bubbleColor, content.bubbleFrame.size) : nil;
    _avatarView.hidden = !bubble || content.avatarPeerId == 0;
    if (!_avatarView.hidden && _avatarPeerId != content.avatarPeerId)
    {
        _avatarPeerId = content.avatarPeerId;
        TGStarGiftSetPeerAvatar(_avatarView, content.avatarPeerId, 22.0f, _presentation);
    }

    bool ribbon = content.ribbonTitle.length != 0;
    _ribbonView.hidden = !ribbon;
    _ribbonLabel.hidden = !ribbon;
    if (ribbon)
    {
        if (content.ribbonColors.count >= 2)
            _ribbonView.image = TGStarGiftRibbonImage(content.ribbonColors[0], content.ribbonColors[1]);
        else
            _ribbonView.image = TGStarGiftMessageChatRibbonImage(content.overlayColor);
        _ribbonLabel.text = content.ribbonTitle;
        _ribbonLabel.textColor = content.textColor;
    }

    [self setNeedsLayout];
}

- (void)playStickerOnce
{
    if (!_stickerView.hidden)
        [_stickerView restart];
}

- (void)buttonTouchDown
{
    [_buttonView.layer removeAllAnimations];
    _buttonView.alpha = 0.4f;
}

- (void)buttonTouchCancelled
{
    [UIView animateWithDuration:0.2 animations:^
    {
        _buttonView.alpha = 1.0f;
    }];
}

- (void)buttonTouchUpInside
{
    [self buttonTouchCancelled];
    if (_buttonPressed != nil)
        _buttonPressed();
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return _buttonView.hidden || ![touch.view isDescendantOfView:_buttonView];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;
    CGPoint point = [recognizer locationInView:self];
    if (!_creatorBackgroundView.hidden && CGRectContainsPoint(_creatorBackgroundView.frame, point))
    {
        if (_creatorPressed != nil)
            _creatorPressed();
        return;
    }
    if (!CGRectContainsPoint(CGRectInset(self.bounds, TGStarGiftMessageCardInset, TGStarGiftMessageCardInset), point))
        return;
    if (_pressed != nil)
        _pressed(point);
}

- (void)longPressGesture:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan && _longPressed != nil)
        _longPressed();
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    CGRect card = CGRectInset(bounds, TGStarGiftMessageCardInset, TGStarGiftMessageCardInset);
    bool ribbon = _content.ribbonTitle.length != 0;

    _plateView.frame = bounds;
    _plateView.image = TGStarGiftMessagePlateImage(bounds.size, _content.plateColor, ribbon && !_content.cover);

    CGRect coverFrame = CGRectInset(card, TGStarGiftMessageCoverInset, TGStarGiftMessageCoverInset);
    _coverView.frame = coverFrame;
    _coverView.avatarCenter = CGPointMake(coverFrame.size.width / 2.0f, TGStarGiftMessageCoverAvatarCenterY);
    _coverView.defaultHeight = coverFrame.size.height;
    _coverView.gradientFrame = CGRectMake(TGScreenPixelFloor((coverFrame.size.width - coverFrame.size.height) / 2.0f), 0.0f, coverFrame.size.height, coverFrame.size.height);

    CGRect stickerFrame = CGRectMake(card.origin.x + TGScreenPixelFloor((card.size.width - TGStarGiftMessageStickerSide) / 2.0f), card.origin.y + TGStarGiftMessageStickerOffset, TGStarGiftMessageStickerSide, TGStarGiftMessageStickerSide);
    _stickerView.frame = stickerFrame;
    _staticStickerView.frame = stickerFrame;

    _creatorBackgroundView.frame = _content.creatorFrame;
    _bubbleView.frame = _content.bubbleFrame;
    _avatarView.frame = _content.avatarFrame;

    if (!_buttonView.hidden)
    {
        CGSize titleSize = [_buttonLabel sizeThatFits:CGSizeMake(card.size.width, CGFLOAT_MAX)];
        titleSize.width = CGCeil(titleSize.width);
        titleSize.height = CGCeil(titleSize.height);
        CGFloat buttonWidth = titleSize.width + TGStarGiftMessageButtonPadding * 2.0f;
        _buttonView.frame = CGRectMake(card.origin.x + TGScreenPixelFloor((card.size.width - buttonWidth) / 2.0f), _content.buttonOriginY, buttonWidth, TGStarGiftMessageButtonHeight);
        _buttonLabel.frame = CGRectMake(TGStarGiftMessageButtonPadding, TGScreenPixelFloor((TGStarGiftMessageButtonHeight - titleSize.height) / 2.0f), titleSize.width, titleSize.height);
    }

    if (ribbon)
    {
        CGRect ribbonFrame;
        if (_content.ribbonColors.count >= 2)
        {
            ribbonFrame = CGRectMake(CGRectGetMaxX(card) - TGStarGiftMessageRibbonSide + 2.0f, card.origin.y - 2.0f, TGStarGiftMessageRibbonSide, TGStarGiftMessageRibbonSide);
            if (_content.cover)
                ribbonFrame = CGRectOffset(ribbonFrame, -4.0f, 4.0f);
        }
        else
            ribbonFrame = CGRectMake(CGRectGetMaxX(card) - TGStarGiftMessageChatRibbonSide + 2.0f, card.origin.y - 2.0f, TGStarGiftMessageChatRibbonSide, TGStarGiftMessageChatRibbonSide);
        _ribbonView.frame = ribbonFrame;
        _ribbonLabel.transform = CGAffineTransformIdentity;
        CGSize labelSize = [_ribbonLabel sizeThatFits:CGSizeMake(card.size.width, CGFLOAT_MAX)];
        _ribbonLabel.bounds = CGRectMake(0.0f, 0.0f, CGCeil(labelSize.width), CGCeil(labelSize.height));
        _ribbonLabel.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
        _ribbonLabel.center = CGPointMake(CGRectGetMidX(ribbonFrame) + 7.0f, CGRectGetMidY(ribbonFrame) - 6.0f);
    }
}

@end
