#import "LegacyComponentsGlobals.h"
#import "TGLetteredAvatarView.h"
#import "OGPlatformVersion.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"
#import "../../../OnegramPlatform/OGMemoryCache.h"

#import "TGImageManager.h"
#import "TGGradientLabel.h"

static UIImage *TGLetteredAvatarRoundedImage(UIImage *image, CGFloat radius, CGSize boundsSize)
{
    if (image == nil || radius <= 0.0f || image.size.width < 1.0f || image.size.height < 1.0f)
        return image;
    CGFloat imageRadius = boundsSize.width > 1.0f ? radius * image.size.width / boundsSize.width : radius;
    NSArray *key = @[image, @(imageRadius)];
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:192 costLimit:4 * 1024 * 1024];
    });
    UIImage *rounded = [cache objectForKey:key];
    if (rounded != nil)
        return rounded;

    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
    {
        UIGraphicsEndImageContext();
        return image;
    }
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:imageRadius] addClip];
    [image drawInRect:rect];
    rounded = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (rounded == nil)
        return image;

    uint64_t cost = (uint64_t)CGImageGetBytesPerRow(rounded.CGImage) * CGImageGetHeight(rounded.CGImage);
    if (image.CGImage != NULL)
        cost += (uint64_t)CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage);
    [cache setObject:rounded forKey:key cost:(NSUInteger)MIN((uint64_t)NSUIntegerMax, cost)];
    return rounded;
}

@interface TGLetteredAvatarView ()
{
    TGGradientLabel *_label;
    
    UIFont *_singleFont;
    UIFont *_doubleFont;
    bool _usingSingleFont;
    CGFloat _singleSize;
    CGFloat _doubleSize;

    bool _roundsImage;
    UIImage *_sourceImage;
    CGSize _roundedBoundsSize;
}

@end

@implementation TGLetteredAvatarView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        if (iosMajorVersion() >= 11)
            self.accessibilityIgnoresInvertColors = true;
        
        _label = [[TGGradientLabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        [self addSubview:_label];
        self.layer.cornerRadius = 7.0f;
        _roundsImage = true;
   }
    return self;
}

- (void)setSingleFontSize:(CGFloat)singleFontSize doubleFontSize:(CGFloat)doubleFontSize useBoldFont:(bool)__unused useBoldFont
{
    if (ABS(singleFontSize - _singleSize) < FLT_EPSILON && ABS(doubleFontSize - _doubleSize) < FLT_EPSILON)
        return;
    
    _singleSize = singleFontSize;
    _doubleSize = doubleFontSize;
    
    _singleFont = [TGFont roundedFontOfSize:singleFontSize];
    _doubleFont = _singleFont;
}

- (void)loadImage:(UIImage *)image
{
    _label.hidden = true;
    
    [super loadImage:image];
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(bool)forceFade
{
    _label.hidden = true;
    
    [super loadImage:url filter:filter placeholder:placeholder forceFade:forceFade];
}

static bool isEmojiCharacter(NSString *singleChar)
{
    const unichar high = [singleChar characterAtIndex:0];
    
    if (0xd800 <= high && high <= 0xdbff && singleChar.length >= 2)
    {
        const unichar low = [singleChar characterAtIndex:1];
        const int codepoint = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        
        return (0x1d000 <= codepoint && codepoint <= 0x1f77f);
    }
    
    return (0x2100 <= high && high <= 0x27bf);
}

static NSString *TGLetteredAvatarCleanedUpString(NSString *string)
{
    NSMutableString *__block buffer = [NSMutableString stringWithCapacity:string.length];
    
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock: ^(NSString* substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL* stop)
     {
         [buffer appendString:isEmojiCharacter(substring) ? @"" : substring];
     }];
    
    return buffer;
}

static NSString *TGLetteredAvatarUserLetters(NSString *firstName, NSString *lastName)
{
    NSString *cleanFirstName = TGLetteredAvatarCleanedUpString(firstName);
    NSString *cleanLastName = TGLetteredAvatarCleanedUpString(lastName);
    
    if (cleanFirstName.length != 0 && cleanLastName.length != 0)
        return [[NSString alloc] initWithFormat:@"%@\u200B%@", [cleanFirstName substringToIndex:1], [cleanLastName substringToIndex:1]];
    else if (cleanFirstName.length != 0)
        return [cleanFirstName substringToIndex:1];
    else if (cleanLastName.length != 0)
        return [cleanLastName substringToIndex:1];
    return @" ";
}

static NSString *TGLetteredAvatarTitleLetters(NSString *title)
{
    NSString *cleanTitle = TGLetteredAvatarCleanedUpString(title);
    return cleanTitle.length >= 1 ? [cleanTitle substringToIndex:1] : @" ";
}

+ (void)prepareLettersForFirstName:(NSString *)firstName lastName:(NSString *)lastName fontSize:(CGFloat)fontSize height:(CGFloat)height
{
    if (TGCurrentInterfaceStyle() != 0)
        return;
    [TGGradientLabel prepareText:TGLetteredAvatarUserLetters(firstName, lastName) font:[TGFont roundedFontOfSize:fontSize] textColor:[UIColor whiteColor] height:height];
}

+ (void)prepareLettersForTitle:(NSString *)title fontSize:(CGFloat)fontSize height:(CGFloat)height
{
    if (TGCurrentInterfaceStyle() != 0)
        return;
    [TGGradientLabel prepareText:TGLetteredAvatarTitleLetters(title) font:[TGFont roundedFontOfSize:fontSize] textColor:[UIColor whiteColor] height:height];
}

- (void)setFirstName:(NSString *)firstName lastName:(NSString *)lastName
{
    if (!_label.hidden)
    {
        _label.text = TGLetteredAvatarUserLetters(firstName, lastName);
        
        [_label sizeToFit];
        CGSize labelSize = _label.frame.size;
        CGSize boundsSize = self.bounds.size;
        labelSize.height = boundsSize.height;
        _label.frame = CGRectMake(TGRetinaFloor((boundsSize.width - labelSize.width) / 2.0f), CGFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    }
}

- (void)setTitle:(NSString *)title
{
    _label.text = TGLetteredAvatarTitleLetters(title);
    
    [_label sizeToFit];
    [self setNeedsLayout];
}

- (void)setTitleNeedsDisplay
{
    if (!_label.hidden)
        [_label setNeedsDisplay];
}

- (void)loadSavedMessagesWithSize:(CGSize)size placeholder:(UIImage *)placeholder
{
    _label.text = @"";
    
    NSString *placeholderUri = [[NSString alloc] initWithFormat:@"placeholder://?type=saved-messages&w=%d&h=%d" PRId32 "", (int)size.width, (int)size.height];
    if (!TGStringCompare([self currentUrl], placeholderUri))
        [super loadImage:placeholderUri filter:nil placeholder:placeholder];
    
    _label.hidden = true;
}

- (void)loadUserPlaceholderWithSize:(CGSize)size uid:(int)uid firstName:(NSString *)firstName lastName:(NSString *)lastName placeholder:(UIImage *)placeholder
{
    _label.font = _doubleFont;
    _usingSingleFont = false;
    
    _label.text = TGLetteredAvatarUserLetters(firstName, lastName);
    
    _label.textColor = [UIColor whiteColor];
    
    [_label sizeToFit];
    [self setNeedsLayout];
    
    NSString *placeholderUri = [[NSString alloc] initWithFormat:@"placeholder://?type=user-avatar&w=%d&h=%d&uid=%" PRId32 "", (int)size.width, (int)size.height, (int32_t)uid];
    if (!TGStringCompare([self currentUrl], placeholderUri))
        [super loadImage:placeholderUri filter:nil placeholder:placeholder];
    
    _label.hidden = (TGCurrentInterfaceStyle() != 0);
}

typedef struct
{
    int top;
    int bottom;
} TGGradientColors;

- (void)loadGroupPlaceholderWithSize:(CGSize)size conversationId:(int64_t)conversationId title:(NSString *)title placeholder:(UIImage *)placeholder
{
    _label.font = _singleFont;
    _usingSingleFont = true;
    
    _label.text = TGLetteredAvatarTitleLetters(title);
    
    if (conversationId == 0)
        _label.textColor = [UIColor whiteColor];
    else
        _label.textColor = [UIColor whiteColor];
    
    [_label sizeToFit];
    CGSize labelSize = _label.frame.size;
    CGSize boundsSize = self.bounds.size;
    labelSize.height = boundsSize.height;
    _label.frame = CGRectMake(TGRetinaFloor((boundsSize.width - labelSize.width) / 2.0f), CGFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    
    [super loadImage:[[NSString alloc] initWithFormat:@"placeholder://?type=group-avatar&w=%d&h=%d&cid=%" PRId64 "", (int)size.width, (int)size.height, conversationId] filter:nil placeholder:placeholder];
    
    _label.hidden = (TGCurrentInterfaceStyle() != 0);
}

+ (void)prewarmImage:(UIImage *)image cornerRadius:(CGFloat)cornerRadius boundsSize:(CGSize)boundsSize
{
    TGLetteredAvatarRoundedImage(image, cornerRadius, boundsSize);
}

- (UIImage *)roundedImageForImage:(UIImage *)image
{
    return _roundsImage ? TGLetteredAvatarRoundedImage(image, self.layer.cornerRadius, self.bounds.size) : image;
}

- (void)setImage:(UIImage *)image
{
    _sourceImage = image;
    _roundedBoundsSize = self.bounds.size;
    [super setImage:[self roundedImageForImage:image]];
}

- (UIImage *)currentImage
{
    return self.image != nil ? _sourceImage : nil;
}

- (void)refreshRoundedImage
{
    if (_sourceImage == nil)
        return;
    _roundedBoundsSize = self.bounds.size;
    [super setImage:[self roundedImageForImage:_sourceImage]];
}

- (void)setClipsToBounds:(BOOL)clipsToBounds
{
    [super setClipsToBounds:false];
    if (_roundsImage != (bool)clipsToBounds)
    {
        _roundsImage = clipsToBounds;
        [self refreshRoundedImage];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (_sourceImage != nil && !CGSizeEqualToSize(_roundedBoundsSize, self.bounds.size))
        [self refreshRoundedImage];
    
    CGSize labelSize = _label.frame.size;
    CGSize boundsSize = self.bounds.size;
    labelSize.height = boundsSize.height;
    _label.frame = CGRectMake(TGScreenPixelFloor((boundsSize.width - labelSize.width) / 2.0f), TGScreenPixelFloor((boundsSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
}

@end
