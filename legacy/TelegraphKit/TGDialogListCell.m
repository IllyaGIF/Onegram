#import "TGDialogListCell.h"
#import "TGCommon.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGReusableLabel.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGDateLabel.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGTelegramNetworking.h"

#import "TGDialogListCellEditingControls.h"

#import "TGCurrencyFormatter.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"

#import "TGSimpleImageView.h"

#include <math.h>

static bool TGDialogListClassicIOS6Style(void)
{
    return [TGPresentation classicIOS6Style];
}

static bool TGDialogListBrandedIOS6Style(void)
{
    return [TGPresentation brandedIOS6Style];
}

static const CGFloat TGDialogListBrandedIOS6TitleFontSize = 15.6f;
static const CGFloat TGDialogListBrandedIOS6BodyFontSize = 12.0f;
// кружочек
static const CGFloat TGDialogListBrandedIOS6BadgeScale = 0.97f;

static CGFloat TGDialogListAvatarSize(void)
{
    if (TGDialogListBrandedIOS6Style())
        return 50.0f;
    return TGDialogListClassicIOS6Style() ? 52.0f : 62.0f;
}

static CGFloat TGDialogListContentOffset(void)
{
    if (TGDialogListBrandedIOS6Style())
        return 61.0f;
    return TGDialogListClassicIOS6Style() ? 72.0f : 80.0f;
}

static UIColor *TGDialogListMessageTextColor(UIColor *defaultColor, bool unread)
{
    if (!TGDialogListBrandedIOS6Style())
        return defaultColor;
    return unread ? UIColorRGB(0x868282) : [UIColor blackColor];
}

static CGRect TGDialogListRectAvoidingBadge(CGRect rect, CGRect badgeFrame, CGFloat spacing)
{
    if (!CGRectIntersectsRect(rect, badgeFrame))
        return rect;

    CGFloat newX = CGRectGetMaxX(badgeFrame) + spacing;
    if (newX <= CGRectGetMinX(rect))
        return rect;

    CGFloat maxX = CGRectGetMaxX(rect);
    rect.origin.x = MIN(newX, maxX);
    rect.size.width = MAX(0.0f, maxX - rect.origin.x);
    return rect;
}

static UIImage *TGDialogListBrandedDisclosureImage(bool emphasized)
{
    static UIImage *darkImage = nil;
    static UIImage *lightImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *image = [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"];
        darkImage = TGTintedImage(image, UIColorRGB(0x000000));
        lightImage = TGTintedImage(image, UIColorRGB(0x868282));
    });
    return emphasized ? darkImage : lightImage;
}

static UIImage *TGDialogListBrandedPinImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *source = [TGPresentation brandedIOS6ResourceImage:@"pin-angle-fill"];
        if (source == nil)
            return;

        CGSize size = source.size;
        UIGraphicsBeginImageContextWithOptions(size, false, source.scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            0.714f, 0.714f, 0.714f, 1.0f,
            0.537f, 0.537f, 0.537f, 1.0f
        };
        CGFloat locations[] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        [source drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0f];

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

static NSMutableDictionary *TGDialogListSharedTextLayoutCache(void)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

static NSMutableArray *TGDialogListSharedTextLayoutCacheOrder(void)
{
    static NSMutableArray *order = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        order = [[NSMutableArray alloc] init];
    });
    return order;
}

static uint32_t TGDialogListColorKey(UIColor *color)
{
    if (color == nil)
        return 0;

    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    CGFloat r = 0.0f;
    CGFloat g = 0.0f;
    CGFloat b = 0.0f;
    CGFloat a = 1.0f;
    if (count == 2)
    {
        r = g = b = components[0];
        a = components[1];
    }
    else if (count >= 4)
    {
        r = components[0];
        g = components[1];
        b = components[2];
        a = components[3];
    }
    uint32_t ri = (uint32_t)MAX(0, MIN(255, (int)lrint(r * 255.0f)));
    uint32_t gi = (uint32_t)MAX(0, MIN(255, (int)lrint(g * 255.0f)));
    uint32_t bi = (uint32_t)MAX(0, MIN(255, (int)lrint(b * 255.0f)));
    uint32_t ai = (uint32_t)MAX(0, MIN(255, (int)lrint(a * 255.0f)));
    return (ri << 24) | (gi << 16) | (bi << 8) | ai;
}

static NSString *TGDialogListTextLayoutCacheKey(NSString *text, UIFont *font, UIColor *color, CGFloat width, NSUInteger maxLines, NSTextAlignment alignment)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    NSInteger pixelWidth = (NSInteger)lrint(MAX(0.0f, width) * scale);
    NSInteger pixelFontSize = (NSInteger)lrint(font.pointSize * scale * 16.0f);
    return [NSString stringWithFormat:@"%@|%@|%ld|%08x|%ld|%lu|%ld", text, font.fontName, (long)pixelFontSize, TGDialogListColorKey(color), (long)pixelWidth, (unsigned long)maxLines, (long)alignment];
}

static TGReusableLabelLayoutData *TGDialogListTextLayout(NSString *text, UIFont *font, UIColor *color, CGFloat width, NSUInteger maxLines, NSTextAlignment alignment)
{
    if (text.length == 0 || font == nil || width <= 0.0f)
        return nil;

    UIColor *resolvedColor = color == nil ? [UIColor blackColor] : color;
    NSString *cacheKey = TGDialogListTextLayoutCacheKey(text, font, resolvedColor, width, maxLines, alignment);
    NSMutableDictionary *cache = TGDialogListSharedTextLayoutCache();
    TGReusableLabelLayoutData *layout = nil;
    @synchronized(cache)
    {
        layout = cache[cacheKey];
    }
    if (layout != nil)
        return layout;

    CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
    if (coreTextFont == NULL)
        return nil;

    layout = [TGReusableLabel calculateLayout:text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:resolvedColor linkColor:nil frame:CGRectZero orMaxWidth:width flags:TGReusableLabelLayoutMultiline textAlignment:alignment outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:maxLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
    CFRelease(coreTextFont);
    if (layout != nil)
    {
        @synchronized(cache)
        {
            NSMutableArray *order = TGDialogListSharedTextLayoutCacheOrder();
            NSUInteger cacheLimit = 1536;
            NSUInteger evictionCount = 256;
            switch (devicePerformanceClass())
            {
                case TGPerformanceClassConstrained: cacheLimit = 512; evictionCount = 96; break;
                case TGPerformanceClassBalanced: cacheLimit = 1024; evictionCount = 160; break;
                case TGPerformanceClassFast: cacheLimit = 2048; evictionCount = 320; break;
                case TGPerformanceClassHigh: cacheLimit = 4096; evictionCount = 512; break;
            }
            if (cache.count >= cacheLimit && order.count >= evictionCount)
            {
                NSArray *expiredKeys = [order subarrayWithRange:NSMakeRange(0, evictionCount)];
                [cache removeObjectsForKeys:expiredKeys];
                [order removeObjectsInRange:NSMakeRange(0, evictionCount)];
            }
            if (cache[cacheKey] == nil)
            {
                cache[cacheKey] = layout;
                [order addObject:cacheKey];
            }
        }
    }
    return layout;
}

static CGSize TGDialogListTextSize(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines)
{
    TGReusableLabelLayoutData *layout = TGDialogListTextLayout(text, font, [UIColor blackColor], width, maxLines, NSTextAlignmentLeft);
    if (layout == nil)
        return CGSizeZero;

    CGSize size = layout.size;
    size.width = MIN(width, CGCeil(layout.drawingWidth));
    return size;
}

static void TGDialogListDrawLayout(TGReusableLabelLayoutData *layout, CGRect rect)
{
    if (layout != nil)
        [TGReusableLabel drawRichTextInRect:rect precalculatedLayout:layout linesRange:NSMakeRange(0, 0) shadowColor:TGDialogListBrandedIOS6Style() ? UIColorRGBA(0x000000, 0.20f) : nil shadowOffset:TGDialogListBrandedIOS6Style() ? CGSizeMake(0.0f, 1.0f) : CGSizeZero];
}

@interface TGDialogListTextView : UIView
{
    TGReusableLabelLayoutData *_titleLayout;
    TGReusableLabelLayoutData *_textLayout;
    TGReusableLabelLayoutData *_authorNameLayout;
    TGReusableLabelLayoutData *_typingLayout;
}
@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) CGRect titleFrame;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIImage *mediaIcon;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *actionTextColor;
@property (nonatomic) CGRect textFrame;
@property (nonatomic, strong) UIFont *textFont;
@property (nonatomic , strong) NSString *authorName;
@property (nonatomic) CGRect authorNameFrame;
@property (nonatomic, strong) UIFont *authorNameFont;
@property (nonatomic, strong) UIColor *authorNameColor;

@property (nonatomic) CGRect typingFrame;
@property (nonatomic) bool showTyping;
@property (nonatomic, strong) NSString *typingText;

@property (nonatomic) bool isMultichat;
@property (nonatomic) bool isEncrypted;
@property (nonatomic) bool isMuted;
@property (nonatomic) bool isVerified;

@end

@implementation TGDialogListTextView

- (void)setPresentation:(TGPresentation *)presentation
{
    if (_presentation != presentation)
    {
        _presentation = presentation;
        _titleLayout = nil;
        _textLayout = nil;
        _authorNameLayout = nil;
        _typingLayout = nil;
    }
}

- (void)setTitle:(NSString *)title
{
    if (_title != title && ![_title isEqualToString:title])
    {
        _title = title;
        _titleLayout = nil;
    }
}

- (void)setTitleFrame:(CGRect)titleFrame
{
    if (!CGRectEqualToRect(_titleFrame, titleFrame))
    {
        _titleFrame = titleFrame;
        _titleLayout = nil;
    }
}

- (void)setTitleFont:(UIFont *)titleFont
{
    if (_titleFont != titleFont && ![_titleFont isEqual:titleFont])
    {
        _titleFont = titleFont;
        _titleLayout = nil;
    }
}

- (void)setMediaIcon:(UIImage *)mediaIcon
{
    if (_mediaIcon != mediaIcon)
    {
        _mediaIcon = mediaIcon;
        _textLayout = nil;
    }
}

- (void)setText:(NSString *)text
{
    if (_text != text && ![_text isEqualToString:text])
    {
        _text = text;
        _textLayout = nil;
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    if (![_textColor isEqual:textColor])
    {
        _textColor = textColor;
        _textLayout = nil;
    }
}

- (void)setTextFont:(UIFont *)textFont
{
    if (_textFont != textFont && ![_textFont isEqual:textFont])
    {
        _textFont = textFont;
        _textLayout = nil;
        _typingLayout = nil;
    }
}

- (void)setActionTextColor:(UIColor *)actionTextColor
{
    if (![_actionTextColor isEqual:actionTextColor])
    {
        _actionTextColor = actionTextColor;
        _typingLayout = nil;
    }
}

- (void)setTextFrame:(CGRect)textFrame
{
    if (!CGRectEqualToRect(_textFrame, textFrame))
    {
        _textFrame = textFrame;
        _textLayout = nil;
    }
}

- (void)setAuthorName:(NSString *)authorName
{
    if (_authorName != authorName && ![_authorName isEqualToString:authorName])
    {
        _authorName = authorName;
        _authorNameLayout = nil;
        _textLayout = nil;
    }
}

- (void)setAuthorNameFrame:(CGRect)authorNameFrame
{
    if (!CGRectEqualToRect(_authorNameFrame, authorNameFrame))
    {
        _authorNameFrame = authorNameFrame;
        _authorNameLayout = nil;
    }
}

- (void)setAuthorNameFont:(UIFont *)authorNameFont
{
    if (_authorNameFont != authorNameFont && ![_authorNameFont isEqual:authorNameFont])
    {
        _authorNameFont = authorNameFont;
        _authorNameLayout = nil;
    }
}

- (void)setAuthorNameColor:(UIColor *)authorNameColor
{
    if (![_authorNameColor isEqual:authorNameColor])
    {
        _authorNameColor = authorNameColor;
        _authorNameLayout = nil;
    }
}

- (void)setTypingFrame:(CGRect)typingFrame
{
    if (!CGRectEqualToRect(_typingFrame, typingFrame))
    {
        _typingFrame = typingFrame;
        _typingLayout = nil;
    }
}

- (void)setTypingText:(NSString *)typingText
{
    if (_typingText != typingText && ![_typingText isEqualToString:typingText])
    {
        _typingText = typingText;
        _typingLayout = nil;
    }
}

- (void)setIsEncrypted:(bool)isEncrypted
{
    if (_isEncrypted != isEncrypted)
    {
        _isEncrypted = isEncrypted;
        _titleLayout = nil;
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect frame = self.frame;
    CGRect titleFrame = CGRectOffset(_titleFrame, -frame.origin.x, -frame.origin.y);
    CGRect textFrame = CGRectOffset(_textFrame, -frame.origin.x, -frame.origin.y);
    CGRect authorNameFrame = CGRectOffset(_authorNameFrame, -frame.origin.x, -frame.origin.y);
    CGRect typingFrame = CGRectOffset(_typingFrame, -frame.origin.x, -frame.origin.y);
    bool useStableTextDrawing = iosMajorVersion() >= 7;
    
    if (_isEncrypted)
    {
        UIImage *image = _presentation.images.dialogEncryptedIcon;
        [image drawAtPoint:CGPointMake(1.0f, 6.0f) blendMode:kCGBlendModeNormal alpha:1.0f];
    }
    
    CGContextSetFillColorWithColor(context, _isEncrypted ? _presentation.pallete.dialogEncryptedColor.CGColor : _presentation.pallete.dialogTitleColor.CGColor);
    if (CGRectIntersectsRect(rect, titleFrame))
    {
        if (_titleLayout == nil)
            _titleLayout = TGDialogListTextLayout(_title, _titleFont, _isEncrypted ? _presentation.pallete.dialogEncryptedColor : _presentation.pallete.dialogTitleColor, titleFrame.size.width, 1, NSTextAlignmentLeft);
        TGDialogListDrawLayout(_titleLayout, titleFrame);
    }
    
    if (_showTyping)
    {
        CGContextSetFillColorWithColor(context, _actionTextColor.CGColor);
        
        if (_typingLayout == nil)
            _typingLayout = TGDialogListTextLayout(_typingText, _textFont, _actionTextColor, typingFrame.size.width, 1, NSTextAlignmentLeft);
        TGDialogListDrawLayout(_typingLayout, typingFrame);
    }
    else
    {
        if (CGRectIntersectsRect(rect, textFrame))
        {
            CGContextSetFillColorWithColor(context, _textColor.CGColor);
            
            if (_mediaIcon != nil)
            {
                [_mediaIcon drawAtPoint:CGPointMake(textFrame.origin.x, textFrame.origin.y + 1.0f + TGScreenPixel) blendMode:kCGBlendModeNormal alpha:1.0f];
                textFrame = CGRectMake(textFrame.origin.x + 19, textFrame.origin.y, textFrame.size.width - 19, textFrame.size.height);
            }
            
            NSUInteger maxLines = TGDialogListBrandedIOS6Style() ? (_authorName.length == 0 ? 2 : 1) : (textFrame.size.height >= 30.0f ? 2 : 1);
            if (_textLayout == nil)
                _textLayout = TGDialogListTextLayout(_text, _textFont, _textColor, textFrame.size.width, maxLines, NSTextAlignmentLeft);
            TGDialogListDrawLayout(_textLayout, textFrame);
            
            //CGContextFillRect(context, textFrame);
        }
    
        if (_authorName != nil && _authorName.length != 0)
        {
            CGContextSetFillColorWithColor(context, _authorNameColor == nil ? [UIColor blackColor].CGColor : [_authorNameColor CGColor]);
            if (CGRectIntersectsRect(rect, authorNameFrame))
            {
                NSTextAlignment alignment = useStableTextDrawing ? NSTextAlignmentLeft : NSTextAlignmentRight;
                if (_authorNameLayout == nil)
                    _authorNameLayout = TGDialogListTextLayout(_authorName, _authorNameFont, _authorNameColor == nil ? [UIColor blackColor] : _authorNameColor, authorNameFrame.size.width, 1, alignment);
                TGDialogListDrawLayout(_authorNameLayout, authorNameFrame);
                
                //CGContextFillRect(context, authorNameFrame);
            }
        }
    }
}

@end

#pragma mark - Cell

@interface TGDialogListCell () <UIGestureRecognizerDelegate>
{
    CALayer *_separatorLayer;
    
    UIImage *_unreadBackgroundImage;
    UIImage *_unreadMutedBackgroundImage;
    UIImage *_unseenMentionsImage;
    
    NSMutableArray *_avatarViews;
    bool _fastScrolling;
    CGSize _fastLayoutSize;
    CGFloat _fastLayoutContentOffset;
}

@property (nonatomic, strong) TGDialogListCellEditingControls *wrapView;

@property (nonatomic, strong) TGDialogListTextView *textView;

@property (nonatomic, strong) TGLetteredAvatarView *avatarView;
@property (nonatomic, strong) UIView *brandedAvatarShadowView;
@property (nonatomic, strong) UIImageView *authorAvatarStrokeView;

@property (nonatomic, strong) TGDateLabel *dateLabel;
@property (nonatomic, strong) UILabel *brandedStatusLabel;

@property (nonatomic, strong) UIImageView *unreadCountBackgrond;
@property (nonatomic, strong) UIImageView *unseenMentionsView;
@property (nonatomic, strong) UIImageView *pinnedBackgrond;
@property (nonatomic, strong) UIImageView *brandedDisclosureView;
@property (nonatomic, strong) TGLabel *unreadCountLabel;

@property (nonatomic, strong) UIImageView *deliveryErrorBackgrond;

@property (nonatomic, strong) UIImageView *deliveredCheckmark;
@property (nonatomic, strong) UIImageView *readCheckmark;
@property (nonatomic, strong) UIImageView *pendingIndicator;

@property (nonatomic, strong) NSString *dateString;

@property (nonatomic) int validViews;
@property (nonatomic) CGSize validSize;

@property (nonatomic) bool hideAuthorName;

@property (nonatomic) bool editingIsActive;

@property (nonatomic, strong) UIImage *mediaIcon;

@property (nonatomic, strong) UIColor *messageTextColor;

@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIImageView *verifiedIcon;
@property (nonatomic, strong) UIImageView *premiumIcon;

@property (nonatomic, strong) UIView *typingDotsContainer;
@property (nonatomic) bool animatingTyping;
@property (nonatomic, strong) NSTimer *typingDotsTimer;
@property (nonatomic) int typingDotsAnimationStep;

@end

@implementation TGDialogListCell

+ (NSDictionary *)preparedPreviewForConversationId:(int64_t)conversationId messageText:(NSString *)messageText attachments:(NSArray *)attachments isSavedMessages:(int)isSavedMessages isGroupChat:(bool)isGroupChat isChannel:(bool)isChannel isChannelGroup:(bool)isChannelGroup isEncrypted:(bool)isEncrypted encryptionStatus:(int)encryptionStatus encryptionOutgoing:(bool)encryptionOutgoing encryptionFirstName:(NSString *)encryptionFirstName
{
    NSString *preparedText = messageText;
    int colorRole = 0;
    bool hideAuthorName = !isGroupChat || (isChannel && !isChannelGroup);
    bool attachmentFound = false;

    if (isSavedMessages == 2)
    {
        preparedText = TGLocalized(@"DialogList.SavedMessagesHelp");
        colorRole = 1;
    }
    else if (attachments.count != 0)
    {
        for (TGMediaAttachment *attachment in attachments)
        {
            if (attachment.type == TGActionMediaAttachmentType)
                return nil;
            else if (attachment.type == TGImageMediaAttachmentType)
            {
                TGImageMediaAttachment *imageMediaAttachment = (TGImageMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : imageMediaAttachment.caption;
                if (imageMediaAttachment.imageId == 0 && imageMediaAttachment.localImageId == 0)
                {
                    preparedText = TGLocalized(@"Message.ImageExpired");
                    colorRole = 2;
                }
                else if (caption.length > 0)
                {
                    bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"🖼 "];
                    preparedText = addEmoji ? [@"🖼 " stringByAppendingString:caption] : caption;
                    colorRole = 0;
                }
                else
                {
                    preparedText = TGLocalized(@"Message.Photo");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                TGVideoMediaAttachment *videoMediaAttachment = (TGVideoMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : videoMediaAttachment.caption;
                if (videoMediaAttachment.videoId == 0 && videoMediaAttachment.localVideoId == 0)
                {
                    preparedText = TGLocalized(@"Message.VideoExpired");
                    colorRole = 2;
                }
                else if (caption.length > 0)
                {
                    bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"📹 "];
                    preparedText = addEmoji ? [@"📹 " stringByAppendingString:caption] : caption;
                    colorRole = 0;
                }
                else
                {
                    preparedText = videoMediaAttachment.roundMessage ? TGLocalized(@"Message.VideoMessage") : TGLocalized(@"Message.Video");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                preparedText = ((TGLocationMediaAttachment *)attachment).period > 0 ? TGLocalized(@"Message.LiveLocation") : TGLocalized(@"Message.Location");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                preparedText = TGLocalized(@"Message.Contact");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGDocumentMediaAttachmentType)
            {
                TGDocumentMediaAttachment *documentAttachment = (TGDocumentMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : documentAttachment.caption;
                bool isAnimated = false;
                bool isSticker = false;
                bool isVoice = false;
                NSString *musicText = nil;
                NSString *stickerRepresentation = nil;
                for (id attribute in documentAttachment.attributes)
                {
                    if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]])
                        isAnimated = true;
                    else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                    {
                        isSticker = true;
                        stickerRepresentation = ((TGDocumentAttributeSticker *)attribute).alt;
                    }
                    else if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
                    {
                        isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                        if (!isVoice)
                        {
                            NSString *artist = ((TGDocumentAttributeAudio *)attribute).performer;
                            NSString *title = ((TGDocumentAttributeAudio *)attribute).title;
                            if (artist.length != 0 && title.length != 0)
                                musicText = [[artist stringByAppendingString:@" — "] stringByAppendingString:title];
                            else if (artist.length != 0)
                                musicText = artist;
                            else if (title.length != 0)
                                musicText = title;
                        }
                    }
                }

                if (TGPeerIdIsSecretChat(conversationId) && [documentAttachment.mimeType isEqualToString:@"video/mp4"] && documentAttachment.size < 1024 * 1024)
                    isAnimated = true;

                if (isSticker)
                {
                    preparedText = stickerRepresentation.length == 0 ? TGLocalized(@"Message.Sticker") : [[NSString alloc] initWithFormat:@"%@ %@", stickerRepresentation, TGLocalized(@"Message.Sticker")];
                    colorRole = 0;
                }
                else if (isAnimated)
                {
                    preparedText = TGLocalized(@"Message.Animation");
                    colorRole = 2;
                }
                else if (isVoice)
                {
                    preparedText = TGLocalized(@"Message.Audio");
                    colorRole = 2;
                }
                else if (musicText != nil)
                {
                    preparedText = musicText;
                    colorRole = 2;
                }
                else
                {
                    NSString *fileName = documentAttachment.fileName;
                    if (caption.length > 0)
                    {
                        bool addEmoji = ![caption hasPrefix:@"📎 "];
                        preparedText = addEmoji ? [@"📎 " stringByAppendingString:caption] : caption;
                    }
                    else if (fileName.length != 0)
                        preparedText = fileName;
                    else
                        preparedText = TGLocalized(@"Message.File");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGAudioMediaAttachmentType)
            {
                preparedText = TGLocalized(@"Message.Audio");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGGameAttachmentType)
            {
                preparedText = [@"🎮 " stringByAppendingString:((TGGameMediaAttachment *)attachment).title ?: @""];
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGInvoiceMediaAttachmentType)
            {
                preparedText = ((TGInvoiceMediaAttachment *)attachment).title ?: @"";
                colorRole = 2;
                attachmentFound = true;
                break;
            }
        }
    }

    if (!attachmentFound && isSavedMessages != 2)
        colorRole = 0;

    if (preparedText.length == 0 && isEncrypted)
    {
        colorRole = 1;
        if (encryptionStatus == 1)
            preparedText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.AwaitingEncryption"), encryptionFirstName ?: @""];
        else if (encryptionStatus == 2)
            preparedText = TGLocalized(@"DialogList.EncryptionProcessing");
        else if (encryptionStatus == 3)
            preparedText = TGLocalized(@"DialogList.EncryptionRejected");
        else if (encryptionStatus == 4)
        {
            if (encryptionOutgoing)
                preparedText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedOutgoing"), encryptionFirstName ?: @""];
            else
                preparedText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedIncoming"), encryptionFirstName ?: @""];
        }
    }

    return @{ @"text": preparedText ?: @"", @"colorRole": @(colorRole), @"hideAuthor": @(hideAuthorName) };
}

+ (void)prewarmTitleText:(NSString *)titleText messageText:(NSString *)messageText authorName:(NSString *)authorName statusText:(NSString *)statusText width:(CGFloat)width presentation:(TGPresentation *)presentation unread:(bool)unread unreadCount:(int)unreadCount serviceUnreadCount:(int)serviceUnreadCount unreadMark:(bool)unreadMark unreadMentionCount:(int)unreadMentionCount pinned:(bool)pinned muted:(bool)muted verified:(bool)verified premium:(bool)premium deliveryState:(TGMessageDeliveryState)deliveryState
{
    if (presentation == nil || width <= 0.0f)
        return;

    bool branded = [TGPresentation brandedIOS6Style];
    CGFloat contentX = TGDialogListContentOffset();
    UIFont *titleFont = branded ? TGBoldSystemFontOfSize(TGDialogListBrandedIOS6TitleFontSize) : TGMediumSystemFontOfSize(16.0f);
    UIFont *bodyFont = TGSystemFontOfSize(branded ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
    UIColor *titleColor = presentation.pallete.dialogTitleColor;
    UIColor *messageColor = TGDialogListMessageTextColor(presentation.pallete.dialogTextColor, unread);
    UIColor *authorColor = presentation.pallete.dialogNameColor;

    if (titleText.length != 0)
    {
        CGFloat titleWidth = CGCeil([titleText sizeWithFont:titleFont].width);
        titleWidth = MIN(titleWidth, MAX(32.0f, width - contentX - 24.0f));
        TGDialogListTextLayout(titleText, titleFont, titleColor, titleWidth, 1, NSTextAlignmentLeft);
    }

    int totalUnreadCount = unreadCount + serviceUnreadCount;
    CGFloat rightPadding = 0.0f;
    CGRect badgeFrame = CGRectZero;
    if (branded)
    {
        rightPadding = 22.0f;
        CGFloat scale = TGDialogListBrandedIOS6BadgeScale;
        CGFloat badgeHeight = 18.0f * scale;
        CGFloat badgeFontSize = 11.0f * scale;
        UIFont *badgeFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:badgeFontSize];
        if (badgeFont == nil)
            badgeFont = TGBoldSystemFontOfSize(badgeFontSize);
        NSString *badgeText = totalUnreadCount > 0 ? [TGPresentation brandedIOS6BadgeTextForCount:totalUnreadCount] : @"";
        CGFloat countWidth = badgeText.length == 0 ? 9.0f : [badgeText sizeWithFont:badgeFont].width;
        CGFloat backgroundWidth = MAX(badgeHeight, countWidth + 10.0f * scale);
        CGFloat originOffset = (18.0f - badgeHeight) / 2.0f;
        badgeFrame = CGRectMake(43.0f + originOffset, 42.0f + originOffset, backgroundWidth, badgeHeight);
    }
    else
    {
        if (totalUnreadCount > 0 || unreadMark || pinned)
        {
            UIFont *badgeFont = TGSystemFontOfSize(14.0f);
            NSString *badgeText = totalUnreadCount > 0 ? (totalUnreadCount < 1000 ? [NSString stringWithFormat:@"%d", totalUnreadCount] : [NSString stringWithFormat:@"%dK", totalUnreadCount / 1000]) : @"";
            CGFloat countWidth = badgeText.length == 0 ? 9.0f : [badgeText sizeWithFont:badgeFont].width;
            CGFloat backgroundWidth = MAX(20.0f, countWidth + 11.0f);
            rightPadding += backgroundWidth + 16.0f;
        }
    }
    if (unreadMentionCount > 0 && (totalUnreadCount > 0 || unreadMark || unread))
        rightPadding += (!branded && (totalUnreadCount > 0 || unreadMark || pinned)) ? 24.0f : 40.0f;
    if (deliveryState == TGMessageDeliveryStateFailed)
        rightPadding += 36.0f;

    CGFloat messageWidth = MAX(1.0f, width - contentX - 7.0f - rightPadding);
    NSUInteger maxLines = branded ? (authorName.length == 0 ? 2 : 1) : 2;
    if (branded && !CGRectIsEmpty(badgeFrame) && (totalUnreadCount > 0 || unreadMark))
    {
        CGFloat bodyHeight = CGCeil(bodyFont.lineHeight);
        CGFloat titleHeight = CGCeil(titleFont.lineHeight);
        CGRect messageFrame = CGRectMake(contentX, 2.0f + titleHeight, messageWidth, MAX(bodyHeight, 62.0f - (2.0f + titleHeight)));
        if (authorName.length != 0)
        {
            messageFrame.origin.y += bodyHeight;
            messageFrame.size.height -= bodyHeight;
        }
        messageFrame = TGDialogListRectAvoidingBadge(messageFrame, badgeFrame, 4.0f);
        messageWidth = MAX(1.0f, messageFrame.size.width);
    }

    if (messageText.length != 0)
        TGDialogListTextLayout(messageText, bodyFont, messageColor, messageWidth, maxLines, NSTextAlignmentLeft);
    if (authorName.length != 0)
        TGDialogListTextLayout(authorName, bodyFont, authorColor, MAX(1.0f, width - contentX - 4.0f - rightPadding), 1, NSTextAlignmentLeft);
    if (branded && statusText.length != 0)
        TGDialogListTextLayout(statusText, bodyFont, UIColorRGB(0x5a5a5a), MIN(103.2f, MAX(1.0f, width - contentX - 34.0f)), 1, NSTextAlignmentLeft);

    (void)muted;
    (void)verified;
    (void)premium;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier assetsSource:(id<TGDialogListCellAssetsSource>)assetsSource
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        if (iosMajorVersion() >= 7)
        {
            self.contentView.superview.clipsToBounds = false;
        }
        
        if (iosMajorVersion() <= 6) {
            _separatorLayer = [[CALayer alloc] init];
            _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
            [self.layer addSublayer:_separatorLayer];
        }
        
        _wrapView = [[TGDialogListCellEditingControls alloc] init];
        _wrapView.clipsToBounds = true;
        [self addSubview:_wrapView];
        
        __weak TGDialogListCell *weakSelf = self;
        _wrapView.requestDelete = ^{
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_deleteConversation) {
                    strongSelf->_deleteConversation(strongSelf->_conversationId);
                }
            }
        };
        _wrapView.toggleMute = ^(bool mute) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleMuteConversation) {
                    strongSelf->_toggleMuteConversation(strongSelf->_conversationId, mute);
                }
            }
        };
        _wrapView.togglePinned = ^(bool pin) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_togglePinConversation) {
                    strongSelf->_togglePinConversation(strongSelf->_conversationId, pin);
                }
            }
        };
        _wrapView.toggleGrouped = ^(bool group) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleGroupConversation) {
                    strongSelf->_toggleGroupConversation(strongSelf->_conversationId, group);
                }
            }
        };
        _wrapView.toggleRead = ^(bool read) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleReadConversation) {
                    strongSelf->_toggleReadConversation(strongSelf->_conversationId, read);
                }
            }
        };
        _wrapView.toggleArchived = ^(bool archived) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0 && strongSelf->_toggleArchiveConversation) {
                strongSelf->_toggleArchiveConversation(strongSelf->_conversationId, archived);
            }
        };
        
        UIView *selectedView = [[UIView alloc] init];
        self.selectedBackgroundView = selectedView;
        
        _assetsSource = assetsSource;

        _textView = [[TGDialogListTextView alloc] initWithFrame:CGRectMake(73, 2, self.frame.size.width - 73, 46)];
        _textView.contentMode = UIViewContentModeLeft;
        _textView.titleFont = TGDialogListBrandedIOS6Style() ? TGBoldSystemFontOfSize(TGDialogListBrandedIOS6TitleFontSize) : TGMediumSystemFontOfSize(16.0f);
        _textView.textFont = TGSystemFontOfSize(TGDialogListBrandedIOS6Style() ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
        _textView.authorNameFont = TGSystemFontOfSize(TGDialogListBrandedIOS6Style() ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
        _textView.opaque = false;
        _textView.backgroundColor = nil;//[UIColor whiteColor];
        _textView.layer.shouldRasterize = true;
        _textView.layer.rasterizationScale = [UIScreen mainScreen].scale;
        
        [_wrapView addSubview:_textView];
        
        _dateString = [[NSMutableString alloc] initWithCapacity:16];
        
        CGFloat dateFontSize = TGDialogListBrandedIOS6Style() ? 10.0f : 14.0f;
        CGFloat amWidth = 24.0f;
        if (TGIsPad())
        {
            dateFontSize = 15.0f;
            amWidth = 25.0f;
        }
        
        _dateLabel = [[TGDateLabel alloc] init];
        _dateLabel.amWidth = amWidth;
        _dateLabel.pmWidth = amWidth;
        _dateLabel.dstOffset = 0.0f;
        _dateLabel.dateFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.dateTextFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.dateLabelFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.textColor = UIColorRGB(0x595959);
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.opaque = false;
        if (TGDialogListBrandedIOS6Style())
        {
            _dateLabel.shadowColor = UIColorRGBA(0x000000, 0.30f);
            _dateLabel.shadowOffset = CGSizeMake(0.0f, 0.5f);
        }
        [_wrapView addSubview:_dateLabel];
        
        bool fadeTransition = cpuCoreCount() > 1;
        
        CGFloat avatarSize = TGDialogListAvatarSize();
        CGFloat avatarX = TGDialogListBrandedIOS6Style() ? 6.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 10.0f);
        CGFloat avatarY = TGDialogListBrandedIOS6Style() ? 5.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 7.0f);
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(avatarX, avatarY, avatarSize, avatarSize)];
        [_avatarView setSingleFontSize:TGDialogListBrandedIOS6Style() ? 21.0f : (TGDialogListClassicIOS6Style() ? 24.0f : 28.0f) doubleFontSize:TGDialogListBrandedIOS6Style() ? 16.0f : (TGDialogListClassicIOS6Style() ? 18.0f : 21.0f) useBoldFont:false];
        if (TGDialogListClassicIOS6Style())
        {
            _avatarView.clipsToBounds = true;
            _avatarView.layer.cornerRadius = TGDialogListBrandedIOS6Style() ? 8.0f : 7.0f;
        }
        _avatarView.fadeTransition = fadeTransition;
        [_wrapView addSubview:_avatarView];

        if (TGDialogListBrandedIOS6Style())
        {
            _brandedAvatarShadowView = [[UIView alloc] initWithFrame:_avatarView.frame];
            _brandedAvatarShadowView.backgroundColor = [UIColor whiteColor];
            _brandedAvatarShadowView.layer.cornerRadius = 8.0f;
            _brandedAvatarShadowView.layer.shadowColor = [UIColor blackColor].CGColor;
            _brandedAvatarShadowView.layer.shadowOpacity = 0.45f;
            _brandedAvatarShadowView.layer.shadowRadius = 1.0f;
            _brandedAvatarShadowView.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);
            _brandedAvatarShadowView.layer.shouldRasterize = true;
            _brandedAvatarShadowView.layer.rasterizationScale = [UIScreen mainScreen].scale;
            [_wrapView insertSubview:_brandedAvatarShadowView belowSubview:_avatarView];
        }
        
        _unreadCountLabel = [[TGLabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
        _unreadCountLabel.textColor = [UIColor whiteColor];
        _unreadCountLabel.font = TGSystemFontOfSize(14);
        
        [_wrapView addSubview:_unreadCountLabel];
        
        _unreadCountLabel.backgroundColor = [UIColor clearColor];
        
        _validSize = CGSizeZero;
    }
    return self;
}

- (void)dealloc
{
    [_avatarView cancelLoading];
    
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
}

- (void)setPresentation:(TGPresentation *)presentation
{
    bool reset = _presentation != nil;
    if (presentation == _presentation)
        return;
    
    _presentation = presentation;
    
    if (TGDialogListClassicIOS6Style())
    {
        bool darkStyle = presentation.pallete.isDark;
        self.backgroundColor = darkStyle ? presentation.pallete.backgroundColor : [UIColor whiteColor];
        self.selectedBackgroundView.backgroundColor = darkStyle ? presentation.pallete.selectionColor : UIColorRGB(0xd8e5f1);
        _separatorLayer.backgroundColor = darkStyle ? [UIColor clearColor].CGColor : UIColorRGB(0xd4d4d4).CGColor;
        _separatorLayer.hidden = darkStyle;
        if (TGDialogListBrandedIOS6Style())
        {
            CGFloat badgeFontSize = 11.0f * TGDialogListBrandedIOS6BadgeScale;
            UIFont *badgeFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:badgeFontSize];
            _unreadCountLabel.font = badgeFont != nil ? badgeFont : TGBoldSystemFontOfSize(badgeFontSize);
            _unreadCountLabel.shadowColor = [UIColor clearColor];
            _unreadCountLabel.shadowOffset = CGSizeZero;
        }
        else
        {
            _unreadCountLabel.font = TGBoldSystemFontOfSize(12.0f);
            _unreadCountLabel.shadowColor = UIColorRGBA(0x000000, 0.55f);
            _unreadCountLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        }
        _unreadCountLabel.textColor = [UIColor whiteColor];
    }
    else
    {
        self.backgroundColor = presentation.pallete.backgroundColor;
        self.selectedBackgroundView.backgroundColor = presentation.pallete.selectionColor;
        _separatorLayer.backgroundColor = presentation.pallete.barSeparatorColor.CGColor;
        _separatorLayer.hidden = false;
        _unreadCountLabel.font = TGSystemFontOfSize(14.0f);
        _unreadCountLabel.shadowColor = [UIColor clearColor];
        _unreadCountLabel.shadowOffset = CGSizeZero;
    }
    
    _textView.presentation = presentation;
    _textView.layer.shouldRasterize = true;
    _textView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    [_textView setNeedsDisplay];
    
    CGFloat brandedBadgeHeight = 18.0f * TGDialogListBrandedIOS6BadgeScale;
    UIImage *brandedBadgeImage = [TGPresentation brandedIOS6BadgeImageForWidth:brandedBadgeHeight height:brandedBadgeHeight];
    _unreadBackgroundImage = TGDialogListBrandedIOS6Style() ? brandedBadgeImage : presentation.images.dialogBadgeImage;
    _unreadMutedBackgroundImage = TGDialogListBrandedIOS6Style() ? brandedBadgeImage : presentation.images.dialogMutedBadgeImage;
    
    bool resetButtons = _wrapView.presentation != nil && presentation != _wrapView.presentation;
    _wrapView.presentation = presentation;
    if (resetButtons)
        [_wrapView resetButtons];
    
    if (_unreadCountBackgrond == nil)
    {
        _unreadCountBackgrond = [[TGSimpleImageView alloc] initWithImage:_unreadBackgroundImage];
        [_wrapView addSubview:_unreadCountBackgrond];
        
        [_unreadCountLabel.superview bringSubviewToFront:_unreadCountLabel];
    }
    else
    {
        _unreadCountBackgrond.image = _unreadBackgroundImage;
    }
    if (TGDialogListBrandedIOS6Style())
    {
        _unreadCountBackgrond.layer.shadowColor = [UIColor blackColor].CGColor;
        _unreadCountBackgrond.layer.shadowOpacity = 0.80f;
        _unreadCountBackgrond.layer.shadowRadius = 1.5f * TGDialogListBrandedIOS6BadgeScale;
        _unreadCountBackgrond.layer.shadowOffset = CGSizeMake(0.0f, 2.0f * TGDialogListBrandedIOS6BadgeScale);
        _unreadCountBackgrond.layer.shouldRasterize = true;
        _unreadCountBackgrond.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
    else
    {
        _unreadCountBackgrond.layer.shadowOpacity = 0.0f;
        _unreadCountBackgrond.layer.shouldRasterize = false;
    }
    
    if (_unseenMentionsView == nil)
    {
        _unseenMentionsView = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogMentionedIcon];
        [_wrapView addSubview:_unseenMentionsView];
    }
    else
    {
        _unseenMentionsView.image = presentation.images.dialogMentionedIcon;
    }
    
    if (_pinnedBackgrond == nil)
    {
        _pinnedBackgrond = [[TGSimpleImageView alloc] initWithImage:TGDialogListBrandedIOS6Style() ? TGDialogListBrandedPinImage() : presentation.images.dialogPinnedIcon];
        [_wrapView addSubview:_pinnedBackgrond];
    }
    else
    {
        _pinnedBackgrond.image = TGDialogListBrandedIOS6Style() ? TGDialogListBrandedPinImage() : presentation.images.dialogPinnedIcon;
    }

    if (TGDialogListBrandedIOS6Style())
    {
        if (_brandedDisclosureView == nil)
        {
            _brandedDisclosureView = [[TGSimpleImageView alloc] initWithImage:TGDialogListBrandedDisclosureImage(false)];
            [_wrapView addSubview:_brandedDisclosureView];
        }
        _brandedDisclosureView.hidden = false;
    }
    else
    {
        _brandedDisclosureView.hidden = true;
    }

    if (TGDialogListBrandedIOS6Style())
    {
        if (_brandedStatusLabel == nil)
        {
            _brandedStatusLabel = [[UILabel alloc] init];
            _brandedStatusLabel.backgroundColor = [UIColor clearColor];
            _brandedStatusLabel.font = TGSystemFontOfSize(TGDialogListBrandedIOS6BodyFontSize);
            _brandedStatusLabel.textColor = UIColorRGB(0x5a5a5a);
            _brandedStatusLabel.shadowColor = UIColorRGBA(0x000000, 0.20f);
            _brandedStatusLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
            _brandedStatusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            _brandedStatusLabel.numberOfLines = 1;
            [_wrapView addSubview:_brandedStatusLabel];
        }
        _brandedStatusLabel.text = _statusText;
        _brandedStatusLabel.hidden = _statusText.length == 0;

        if (_brandedAvatarShadowView == nil)
        {
            _brandedAvatarShadowView = [[UIView alloc] init];
            _brandedAvatarShadowView.backgroundColor = [UIColor whiteColor];
            _brandedAvatarShadowView.layer.cornerRadius = 8.0f;
            _brandedAvatarShadowView.layer.shadowColor = [UIColor blackColor].CGColor;
            _brandedAvatarShadowView.layer.shadowOpacity = 0.45f;
            _brandedAvatarShadowView.layer.shadowRadius = 1.0f;
            _brandedAvatarShadowView.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);
            _brandedAvatarShadowView.layer.shouldRasterize = true;
            _brandedAvatarShadowView.layer.rasterizationScale = [UIScreen mainScreen].scale;
            [_wrapView insertSubview:_brandedAvatarShadowView belowSubview:_avatarView];
        }
        _brandedAvatarShadowView.hidden = false;
    }
    else
    {
        _brandedStatusLabel.hidden = true;
        _brandedAvatarShadowView.hidden = true;
    }
    
    _muteIcon.image = presentation.images.dialogMutedIcon;
    _deliveryErrorBackgrond.image = presentation.images.dialogUnsentIcon;
    _pendingIndicator.image = presentation.images.dialogPendingIcon;
    _verifiedIcon.image = presentation.images.dialogVerifiedIcon;
    _premiumIcon.image = [TGPresentationAssets premiumBadgeIcon:14.0f];
    
    if (_deliveredCheckmark == nil)
    {
        _deliveredCheckmark = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogDeliveredIcon];
        [_wrapView addSubview:_deliveredCheckmark];
    }
    else
    {
        _deliveredCheckmark.image = presentation.images.dialogDeliveredIcon;
    }
    
    if (_readCheckmark == nil)
    {
        _readCheckmark = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogReadIcon];
        [_wrapView addSubview:_readCheckmark];
    }
    else
    {
        _readCheckmark.image = presentation.images.dialogReadIcon;
    }
    
    if (reset)
        [self resetView:false];
}

- (void)prepareForReuse
{
    [self stopTypingAnimation];
    _fastScrolling = false;
    _wrapView.layer.shouldRasterize = false;
    [_wrapView setExpanded:false animated:false];
    
    [super prepareForReuse];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    bool wasSelected = self.selected;
    
    [super setSelected:selected animated:animated];
    
    if ((selected && !wasSelected))
    {
        [self adjustOrdering];
    }
    
    if ((selected && !wasSelected) || (!selected && wasSelected))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
        {
            CGFloat separatorHeight = TGScreenPixel;
            selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
        }
        
        if (TGIsPad() && _separatorLayer != nil)
        {
            bool hidden = (TGDialogListClassicIOS6Style() && _presentation.pallete.isDark) || self.selected || self.highlighted;
            if (_separatorLayer.hidden != hidden)
            {
                [CATransaction begin];
                [CATransaction setDisableActions:true];
                _separatorLayer.hidden = hidden;
                [CATransaction commit];
            }
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    bool wasHighlighted = self.highlighted;
    
    [super setHighlighted:highlighted animated:animated];
    
    if ((highlighted && !wasHighlighted))
    {
        [self adjustOrdering];
    }
    
    if ((highlighted && !wasHighlighted) || (!highlighted && wasHighlighted))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
        {
            CGFloat separatorHeight = TGScreenPixel;
            selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
        }
        
        if (TGIsPad() && _separatorLayer != nil)
        {
            bool hidden = (TGDialogListClassicIOS6Style() && _presentation.pallete.isDark) || self.selected || self.highlighted;
            if (_separatorLayer.hidden != hidden)
            {
                [CATransaction begin];
                [CATransaction setDisableActions:true];
                _separatorLayer.hidden = hidden;
                [CATransaction commit];
            }
        }
    }
}

- (void)adjustOrdering
{
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil)
    {
        CGFloat separatorHeight = TGScreenPixel;
        selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
    }
    
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
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
}

- (void)setFastScrolling:(bool)fastScrolling
{
    if (_fastScrolling == fastScrolling)
        return;

    _fastScrolling = fastScrolling;
    bool rasterize = _fastScrolling && !_animatingTyping && ![_wrapView isExpanded];
    _wrapView.layer.shouldRasterize = rasterize;
    _wrapView.layer.rasterizationScale = [UIScreen mainScreen].scale;
}

- (void)setTypingString:(NSString *)typingString
{
    [self setTypingString:typingString animated:false];
}

- (void)setTypingString:(NSString *)typingString animated:(bool)__unused animated
{
    _typingString = typingString;
    
    if (((_textView.typingText == nil) != (typingString == nil)) || (typingString != nil) != _textView.showTyping || ![_textView.typingText isEqualToString:typingString])
    {
        _textView.showTyping = typingString != nil;
        _textView.typingText = typingString;
        
        if (typingString != nil)
            [self startTypingAnimation:false];
        else
            [self stopTypingAnimation];
        
        [_textView setNeedsDisplay];
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)collectCachedPhotos:(NSMutableDictionary *)dict
{
    [_avatarView tryFillCache:dict];
}

- (UIView *)typingDotsContainer
{
    if (_typingDotsContainer == nil)
    {
        _typingDotsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        for (int i = 0; i < 3; i++)
        {
            UILabel *typingDot = [[UILabel alloc] init];
            typingDot.tag = 100 + i;
            typingDot.text = @".";
            typingDot.textColor = _presentation.pallete.dialogTextColor;
            typingDot.font = _textView.textFont;
            typingDot.backgroundColor = [UIColor clearColor];
            typingDot.frame = CGRectMake(4 * i, 0, 4, 10);
            typingDot.alpha = i == 0 ? 0.0f : 0.0f;
            
            [_typingDotsContainer addSubview:typingDot];
        }
    }
    
    return _typingDotsContainer;
}

- (void)restartAnimations:(bool)force
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
    }
    
    if (_textView.showTyping)
        [self startTypingAnimation:force];
}

- (void)stopAnimations
{
    [self stopTypingAnimation];
}

- (void)startTypingAnimation:(bool)force
{
    if (!_animatingTyping)
    {
        UIView *typingDotsContainer = [self typingDotsContainer];
        
        _animatingTyping = true;
        _wrapView.layer.shouldRasterize = false;
        
        if (typingDotsContainer.superview == nil)
        {
            [_wrapView addSubview:typingDotsContainer];
            _validSize = CGSizeZero;
            [self layoutSubviews];
        }
        
        if (self.window != nil)
        {
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            if (state == UIApplicationStateActive || state == UIApplicationStateInactive || force)
                [self _loopTypingAnimation];
        }
    }
}

- (void)stopTypingAnimation
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
        
        [_typingDotsContainer removeFromSuperview];
        if (_fastScrolling && ![_wrapView isExpanded])
        {
            _wrapView.layer.shouldRasterize = true;
            _wrapView.layer.rasterizationScale = [UIScreen mainScreen].scale;
        }
    }
}

- (void)_loopTypingAnimation
{
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep = 0;
    [self _typingAnimationStep];
}

- (void)_typingAnimationStep
{
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep++;
    
    for (UIView *dotView in _typingDotsContainer.subviews)
    {
        if (dotView.tag >= 100)
        {
            int dotIndex = (int)(dotView.tag - 100);
            if (TGIsRTL())
                dotIndex = 2 - dotIndex;
            
            dotView.alpha = dotIndex < (_typingDotsAnimationStep - 1) ? 1.0f : 0.0f;
        }
    }
    
    if (_typingDotsAnimationStep > 3)
    {
        _typingDotsTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_loopTypingAnimation) interval:0.22 repeat:false];
    }
    else
    {
        _typingDotsTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_typingAnimationStep) interval:_typingDotsAnimationStep == 1 ? 0.22 : 0.12 repeat:false];
    }
}

static NSArray *editingButtonTypes(bool muted, bool pinnable, bool pinned, bool mutable, bool groupable, bool grouped, bool archived, bool isAd) {
    if (TGDialogListBrandedIOS6Style())
    {
        NSMutableArray *buttons = [[NSMutableArray alloc] init];
        if (!isAd)
            [buttons addObject:archived ? @(TGDialogListCellEditingControlsUnarchive) : @(TGDialogListCellEditingControlsArchive)];
        if (pinnable && !isAd)
            [buttons addObject:pinned ? @(TGDialogListCellEditingControlsUnpin) : @(TGDialogListCellEditingControlsPin)];
        if (mutable && !isAd)
            [buttons addObject:muted ? @(TGDialogListCellEditingControlsUnmute) : @(TGDialogListCellEditingControlsMute)];
        if (!isAd)
            [buttons addObject:@(TGDialogListCellEditingControlsDelete)];
        return buttons;
    }

    static dispatch_once_t onceToken;
    static NSMutableDictionary *buttonTypes;
    dispatch_once(&onceToken, ^{
        buttonTypes = [[NSMutableDictionary alloc] init];
    });
    
    TGDialogListCellEditingControlButton key = 0;
    if (pinnable && !isAd)
        key |= pinned ? TGDialogListCellEditingControlsUnpin : TGDialogListCellEditingControlsPin;
    
    if (mutable && !isAd)
        key |= muted ? TGDialogListCellEditingControlsUnmute : TGDialogListCellEditingControlsMute;
    
    if (groupable && !isAd)
        key |= grouped ? TGDialogListCellEditingControlsUngroup : TGDialogListCellEditingControlsGroup;
    
    if (!isAd) {
        key |= archived ? TGDialogListCellEditingControlsUnarchive : TGDialogListCellEditingControlsArchive;
        key |= TGDialogListCellEditingControlsDelete;
    }

    if (buttonTypes[@(key)] != nil)
        return buttonTypes[@(key)];
    
    NSMutableArray *buttons = [[NSMutableArray alloc] init];
    if (pinnable && !isAd)
        [buttons addObject:pinned ? @(TGDialogListCellEditingControlsUnpin) : @(TGDialogListCellEditingControlsPin)];
    
    if (mutable && !isAd)
        [buttons addObject:muted ? @(TGDialogListCellEditingControlsUnmute) : @(TGDialogListCellEditingControlsMute)];
    
//    if (false && groupable && !isAd)
//        [buttons addObject:grouped ? @(TGDialogListCellEditingControlsUngroup) : @(TGDialogListCellEditingControlsGroup)];
    
    if (!isAd)
        [buttons addObject:archived ? @(TGDialogListCellEditingControlsUnarchive) : @(TGDialogListCellEditingControlsArchive)];
    [buttons addObject:@(TGDialogListCellEditingControlsDelete)];
    
    buttonTypes[@(key)] = buttons;
    return buttons;
}

- (void)resetView:(bool)keepState
{
    if (self.selectionStyle != UITableViewCellSelectionStyleBlue)
        self.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    int totalUnreadCount = _unreadCount + _serviceUnreadCount;
    
    if (_isSavedMessages == 2 || _isAd) {
        [_wrapView setLeftButtonTypes:@[] rightButtonTypes:@[]];
    } else {
        bool groupable = _isChannel && !_isChannelGroup;
        bool readable = !_isSavedMessages;
        bool read = totalUnreadCount == 0 && !_unreadMark && _unreadMentionCount == 0;
        
        [_wrapView setLeftButtonTypes:readable ? @[ read ? @(TGDialogListCellEditingControlsUnread) : @(TGDialogListCellEditingControlsRead) ] : @[] rightButtonTypes:editingButtonTypes(_isMuted, !_isFeedChannels, _pinnedToTop, !_isEncrypted && !_isSavedMessages && !_isFeed, groupable, _groupedInFeed, _isArchived, _isAd)];
    }
    
    UIColor *backgroundColor = _pinnedToTop || _isAd || _isSavedMessages == 2 ? _presentation.pallete.dialogPinnedBackgroundColor : _presentation.pallete.backgroundColor;
    self.backgroundColor = backgroundColor;
    
    int currentDate = (int)[[TGTelegramNetworking instance] approximateRemoteTime];
    _dateString = _date == 0 || _isSavedMessages == 2 ? nil : [TGDateUtils stringForMessageListDate:(int)_date relativeToDate:currentDate];
    if (_isAd) {
        _dateString = TGLocalized(@"DialogList.AdLabel");
    }
    
    _textView.title = _titleText;
    if (TGDialogListBrandedIOS6Style() && _brandedStatusLabel != nil)
    {
        _brandedStatusLabel.text = _statusText;
        _brandedStatusLabel.hidden = _statusText.length == 0;
    }
    _textView.isVerified = _isVerified;
    
    UIColor *normalTextColor = _presentation.pallete.dialogTextColor;
    UIColor *actionTextColor = _presentation.pallete.dialogTextColor;
    UIColor *mediaTextColor = _presentation.pallete.dialogTextColor;
    
    NSDictionary *preparedPreview = _preparedPreview;
    if (preparedPreview != nil)
    {
        _messageText = preparedPreview[@"text"];
        _hideAuthorName = [preparedPreview[@"hideAuthor"] boolValue];
        int colorRole = [preparedPreview[@"colorRole"] intValue];
        _messageTextColor = colorRole == 1 ? actionTextColor : (colorRole == 2 ? mediaTextColor : normalTextColor);
        _mediaIcon = nil;
    }
    else
    {
    bool attachmentFound = false;
    _hideAuthorName = !_isGroupChat || _rawText || (_isChannel && !_isChannelGroup);
    
    if (_isSavedMessages == 2)
    {
        _messageText = TGLocalized(@"DialogList.SavedMessagesHelp");
        _messageTextColor = actionTextColor;
    }
    else
    {
        if (_messageAttachments != nil && _messageAttachments.count != 0)
        {
            for (TGMediaAttachment *attachment in _messageAttachments)
            {
                if (attachment.type == TGActionMediaAttachmentType)
                {
                    _mediaIcon = nil;
                    TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                    switch (actionAttachment.actionType)
                    {
                        case TGMessageActionChatEditTitle:
                        {
                            if (TGPeerIdIsChannel(_conversationId) || TGPeerIdIsAd(_conversationId)) {
                                _messageText = _isChannelGroup ? TGLocalized(@"Notification.RenamedGroup") : TGLocalized(@"Notification.RenamedChannel");
                            } else {
                                TGUser *user = [_users objectForKey:@"author"];
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RenamedChat"), user.displayName];
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatEditPhoto:
                        {
                            if (TGPeerIdIsChannel(_conversationId) || TGPeerIdIsAd(_conversationId)) {
                                if (_isChannelGroup) {
                                    if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil) {
                                        _messageText = TGLocalized(@"Group.MessagePhotoRemoved");
                                    } else {
                                        _messageText = TGLocalized(@"Group.MessagePhotoUpdated");
                                    }
                                } else {
                                    if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil) {
                                        _messageText = TGLocalized(@"Channel.MessagePhotoRemoved");
                                    } else {
                                        _messageText = TGLocalized(@"Channel.MessagePhotoUpdated");
                                    }
                                }
                            } else {
                                TGUser *user = [_users objectForKey:@"author"];
                                if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedGroupPhoto"), user.displayName];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedGroupPhoto"), user.displayName];
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionUserChangedPhoto:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedUserPhoto"), user.displayFirstName];
                            else
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedUserPhoto"), user.displayFirstName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatAddMember:
                        {
                            NSArray *uids = actionAttachment.actionData[@"uids"];
                            if (uids != nil) {
                                TGUser *authorUser = [_users objectForKey:@"author"];
                                NSMutableArray *subjectUsers = [[NSMutableArray alloc] init];
                                for (NSNumber *nUid in uids) {
                                    TGUser *user = [_users objectForKey:nUid];
                                    if (user != nil) {
                                        [subjectUsers addObject:user];
                                    }
                                }
                                
                                if (subjectUsers.count == 1 && authorUser.uid == ((TGUser *)subjectUsers[0]).uid) {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                                } else {
                                    NSMutableString *subjectNames = [[NSMutableString alloc] init];
                                    for (TGUser *user in subjectUsers) {
                                        if (subjectNames.length != 0) {
                                            [subjectNames appendString:@", "];
                                        }
                                        [subjectNames appendString:user.displayName];
                                    }
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectNames];
                                }
                                _messageTextColor = actionTextColor;
                                attachmentFound = true;
                                
                                _hideAuthorName = true;
                            } else {
                                NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                                if (nUid != nil)
                                {
                                    TGUser *authorUser = [_users objectForKey:@"author"];
                                    TGUser *subjectUser = [_users objectForKey:nUid];
                                    if (authorUser.uid == subjectUser.uid)
                                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                                    else
                                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectUser.displayName];
                                    _messageTextColor = actionTextColor;
                                    attachmentFound = true;
                                    
                                    _hideAuthorName = true;
                                }
                            }
                            
                            break;
                        }
                        case TGMessageActionJoinedByLink:
                        {
                            TGUser *authorUser = [_users objectForKey:@"author"];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedGroupByLink"), authorUser.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatDeleteMember:
                        {
                            NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                            if (nUid != nil)
                            {
                                TGUser *authorUser = [_users objectForKey:@"author"];
                                TGUser *subjectUser = [_users objectForKey:nUid];
                                if (authorUser.uid == subjectUser.uid)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.LeftChat"), authorUser.displayName];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Kicked"), authorUser.displayName, subjectUser.displayName];
                                _messageTextColor = actionTextColor;
                                attachmentFound = true;
                                
                                _hideAuthorName = true;
                            }
                            
                            break;
                        }
                        case TGMessageActionCreateChat:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CreatedChat"), user.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelCreated:
                        {
                            _messageText = TGLocalized(@"Notification.CreatedChannel");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupMigratedTo:
                        {
                            _messageText = TGLocalized(@"Notification.ChannelMigratedFrom");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupActivated:
                        {
                            _messageText = TGLocalized(@"Notification.GroupDeactivated");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupDeactivated:
                        {
                            _messageText = TGLocalized(@"Notification.GroupActivated");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelMigratedFrom:
                        {
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChannelMigratedFrom"), actionAttachment.actionData[@"title"]];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelInviter:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            if ([actionAttachment.actionData[@"uid"] intValue] == user.uid) {
                                if (_isChannelGroup) {
                                    _messageText = TGLocalized(@"Notification.GroupInviterSelf");
                                } else {
                                    _messageText = TGLocalized(@"Notification.ChannelInviterSelf");
                                }
                            } else {
                                int32_t inviterUid = [actionAttachment.actionData[@"uid"] intValue];
                                NSString *inviterName = nil;
                                TGUser *user = _users[@(inviterUid)];
                                if (user.uid == inviterUid) {
                                    inviterName = user.displayName;
                                }
                                
                                if (_isChannelGroup) {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.GroupInviter"), inviterName];
                                } else {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChannelInviter"), inviterName];
                                }
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionCreateBroadcastList:
                        {
                            _messageText = TGLocalized(@"Notification.CreatedBroadcastList");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionContactRequest:
                        {
                            _messageText = [[NSString alloc] initWithFormat:@"%@ sent contact request", _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionAcceptContactRequest:
                        {
                            _messageText = [[NSString alloc] initWithFormat:@"%@ accepted contact request", _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionContactRegistered:
                        {
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Joined"), _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatRequest:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatRequested");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatAccept:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatAccepted");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatDecline:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatRejected");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatMessageLifetime:
                        {
                            int messageLifetime = [actionAttachment.actionData[@"messageLifetime"] intValue];
                            
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            if (messageLifetime == 0)
                            {
                                if (_outgoing)
                                    _messageText = TGLocalized(@"Notification.MessageLifetimeRemovedOutgoing");
                                else
                                {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeRemoved"), _encryptionFirstName];
                                }
                            }
                            else
                            {
                                NSString *lifetimeString = [TGStringUtils stringForMessageTimerSeconds:messageLifetime];
                                
                                if (_outgoing)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeChangedOutgoing"), lifetimeString];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeChanged"), _encryptionFirstName, lifetimeString];
                            }
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatScreenshot:
                        case TGMessageActionEncryptedChatMessageScreenshot:
                        {
                            if (_encryptionFirstName.length != 0) {
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.SecretChatMessageScreenshot"), _encryptionFirstName];
                            } else {
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.SecretChatScreenshot"), _encryptionFirstName];
                            }
                            
                            break;
                        }
                        case TGMessageActionPinnedMessage:
                        {
                            TGMessage *replyMessage = nil;
                            for (id attachment in _messageAttachments) {
                                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                                    break;
                                }
                            }
                            
                            NSString *formatString = TGLocalized(@"Message.PinnedTextMessage");
                            for (id attachment in replyMessage.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedPhotoMessage");
                                } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedVideoMessage");
                                } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
                                    TGDocumentMediaAttachment *document = attachment;
                                    if ([document isAnimated]) {
                                        formatString = TGLocalized(@"Message.PinnedAnimationMessage");
                                    } else {
                                        bool isSticker = false;
                                        bool isAudio = false;
                                        bool isVoice = false;
                                        
                                        for (id attribute in document.attributes) {
                                            if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                                                isAudio = true;
                                                isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                                            } else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
                                                isSticker = true;
                                            }
                                        }
                                        
                                        if (isSticker) {
                                            formatString = TGLocalized(@"Message.PinnedStickerMessage");
                                        } else if (isVoice) {
                                            formatString = TGLocalized(@"Message.PinnedAudioMessage");
                                        } else {
                                            formatString = TGLocalized(@"Message.PinnedDocumentMessage");
                                        }
                                    }
                                } else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]]) {
                                    TGLocationMediaAttachment *location = (TGLocationMediaAttachment *)attachment;
                                    if (location.period > 0)
                                        formatString = TGLocalized(@"Message.PinnedLiveLocationMessage");
                                    else
                                        formatString = TGLocalized(@"Message.PinnedLocationMessage");
                                } else if ([attachment isKindOfClass:[TGContactMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedContactMessage");
                                } else if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedGame");
                                }  else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedInvoice");
                                }
                            }
                            
                            _messageText = [NSString stringWithFormat:formatString, replyMessage.text];
                            _messageTextColor = mediaTextColor;
                            
                            break;
                        }
                        case TGMessageActionGameScore:
                        {
                            TGMessage *replyMessage = nil;
                            for (TGMediaAttachment *attachment in _messageAttachments) {
                                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                                }
                            }
                            
                            NSString *gameTitle = nil;
                            for (id attachment in replyMessage.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                                    gameTitle = ((TGGameMediaAttachment *)attachment).title;
                                    break;
                                }
                            }
                            
                            int scoreCount = (int)[actionAttachment.actionData[@"score"] intValue];
                            
                            NSString *formatStringBase = @"";
                            if (_authorIsSelf) {
                                if (gameTitle != nil) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSelfExtended_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSelfSimple_" value:scoreCount];
                                }
                            } else {
                                if (gameTitle != nil) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreExtended_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSimple_" value:scoreCount];
                                }
                            }
                            
                            NSString *baseString = TGLocalized(formatStringBase);
                            baseString = [baseString stringByReplacingOccurrencesOfString:@"%@" withString:@"{score}"];
                            
                            NSMutableString *formatString = [[NSMutableString alloc] initWithString:baseString];
                            
                            NSRange scoreRange = [formatString rangeOfString:@"{score}"];
                            if (scoreRange.location != NSNotFound) {
                                [formatString replaceCharactersInRange:scoreRange withString:[NSString stringWithFormat:@"%d", scoreCount]];
                            }
                            
                            NSRange gameTitleRange = [formatString rangeOfString:@"{game}"];
                            if (gameTitleRange.location != NSNotFound) {
                                [formatString replaceCharactersInRange:gameTitleRange withString:gameTitle];
                            }
                            
                            _messageText = formatString;
                            _messageTextColor = mediaTextColor;
                            break;
                        }
                        case TGMessageActionPhoneCall:
                        {
                            bool outgoing = _authorIsSelf;
                            int reason = [actionAttachment.actionData[@"reason"] intValue];
                            bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
                            
                            NSString *type = TGLocalized(missed ? (outgoing ? @"Notification.CallCanceled" : @"Notification.CallMissed") : (outgoing ? @"Notification.CallOutgoing" : @"Notification.CallIncoming"));
                            int callDuration = [actionAttachment.actionData[@"duration"] intValue];
                            NSString *duration = missed || callDuration < 1 ? nil : [TGStringUtils stringForCallDurationSeconds:callDuration];
                            NSString *title = duration != nil ? [NSString stringWithFormat:TGLocalized(@"Notification.CallTimeFormat"), type, duration] : type;
                            _messageText = title;
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionPaymentSent: {
                            NSString *string = [[TGCurrencyFormatter shared] formatAmount:[actionAttachment.actionData[@"totalAmount"] longLongValue] currency:actionAttachment.actionData[@"currency"]];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Message.PaymentSent"), string];
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionText:
                        {
                            _messageText = actionAttachment.actionData[@"text"];
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionBotAllowed:
                        {
                            _messageText = [NSString stringWithFormat:TGLocalized(@"AuthSessions.Message"), actionAttachment.actionData[@"domain"]];
                            _messageTextColor = actionTextColor;
                        }
                        case TGMessageActionSecureValuesSent:
                        {
                            NSString *formatString = TGLocalized(@"Notification.PassportValuesSentMessage");
                            NSString *authorName = [_users[@(_conversationId)] displayName];
                            
                            NSArray *components = [actionAttachment.actionData[@"values"] componentsSeparatedByString:@","];
                            NSString *values = @"";
                            bool hasIdentity = false;
                            bool hasAddress = false;
                            for (NSString *component in components)
                            {
                                NSString *value = nil;
                                if ([component isEqualToString:@"personal_details"])
                                {
                                    value = TGLocalized(@"Notification.PassportValuePersonalDetails");
                                }
                                else if ([component isEqualToString:@"passport"] || [component isEqualToString:@"identity_card"] || [component isEqualToString:@"driver_license"] || [component isEqualToString:@"internal_passport"])
                                {
                                    if (!hasIdentity)
                                    {
                                        value = TGLocalized(@"Notification.PassportValueProofOfIdentity");
                                        hasIdentity = true;
                                    }
                                    else
                                    {
                                        continue;
                                    }
                                    
                                }
                                else if ([component isEqualToString:@"address"])
                                {
                                    value = TGLocalized(@"Notification.PassportValueAddress");
                                }
                                else if ([component isEqualToString:@"utility_bill"] || [component isEqualToString:@"bank_statement"] || [component isEqualToString:@"rental_agreement"] || [component isEqualToString:@"passport_registration"] || [component isEqualToString:@"temporary_registration"])
                                {
                                    if (!hasAddress)
                                    {
                                        value = TGLocalized(@"Notification.PassportValueProofOfAddress");
                                        hasAddress = true;
                                    }
                                    else
                                    {
                                        continue;
                                    }
                                }
                                else if ([component isEqualToString:@"phone"])
                                {
                                    value = TGLocalized(@"Notification.PassportValuePhone");
                                }
                                else if ([component isEqualToString:@"email"])
                                {
                                    value = TGLocalized(@"Notification.PassportValueEmail");
                                }
                                
                                if (values.length == 0)
                                    values = value ?: @"";
                                else
                                    values = [values stringByAppendingString:[NSString stringWithFormat:@", %@", value]];
                            }
                            
                            if (values.length > 0)
                                _messageText = [[NSString alloc] initWithFormat:formatString, authorName, values];
                            else
                                _messageText = @"";
                            _messageTextColor = actionTextColor;
                        }
                            break;
                        default:
                            break;
                    }
                }
                else if (attachment.type == TGImageMediaAttachmentType)
                {
                    TGImageMediaAttachment *imageMediaAttachment = (TGImageMediaAttachment *)attachment;
                    NSString *caption = _messageText.length > 0 ? _messageText : imageMediaAttachment.caption;
                    if (imageMediaAttachment.imageId == 0 && imageMediaAttachment.localImageId == 0) {
                        _messageText = TGLocalized(@"Message.ImageExpired");
                        _messageTextColor = mediaTextColor;
                    }
                    else if (caption.length > 0)
                    {
                        bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"🖼 "];
                        _messageText = addEmoji ? [@"🖼 " stringByAppendingString:caption] : caption;
                        _messageTextColor = normalTextColor;
                    }
                    else
                    {
                        _messageText = TGLocalized(@"Message.Photo");
                        _messageTextColor = mediaTextColor;
                    }
                    //_mediaIcon = [UIImage imageNamed:@"MediaPhoto"];
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGVideoMediaAttachmentType)
                {
                    TGVideoMediaAttachment *videoMediaAttachment = (TGVideoMediaAttachment *)attachment;
                    NSString *caption = _messageText.length > 0 ? _messageText : videoMediaAttachment.caption;
                    if (videoMediaAttachment.videoId == 0 && videoMediaAttachment.localVideoId == 0) {
                        _messageText = TGLocalized(@"Message.VideoExpired");
                        _messageTextColor = mediaTextColor;
                    }
                    else if (caption.length > 0)
                    {
                        bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"📹 "];
                        _messageText = addEmoji ? [@"📹 " stringByAppendingString:caption] : caption;
                        _messageTextColor = normalTextColor;
                    }
                    else
                    {
                        _messageText = videoMediaAttachment.roundMessage ? TGLocalized(@"Message.VideoMessage") : TGLocalized(@"Message.Video");
                        _messageTextColor = mediaTextColor;
                    }
                    //_mediaIcon = [UIImage imageNamed:@"MediaVideo"];
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGLocationMediaAttachmentType)
                {
                    TGLocationMediaAttachment *locationMediaAttachment = (TGLocationMediaAttachment *)attachment;
                    if (locationMediaAttachment.period > 0)
                        _messageText = TGLocalized(@"Message.LiveLocation");
                    else
                        _messageText = TGLocalized(@"Message.Location");
                    _messageTextColor = mediaTextColor;
                    //_mediaIcon = [UIImage imageNamed:@"MediaLocation"];
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGContactMediaAttachmentType)
                {
                    _messageText = TGLocalized(@"Message.Contact");
                    _messageTextColor = mediaTextColor;
                    //_mediaIcon = [UIImage imageNamed:@"MediaContact"];
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGDocumentMediaAttachmentType)
                {
                    TGDocumentMediaAttachment *documentAttachment = (TGDocumentMediaAttachment *)attachment;
                    
                    NSString *caption = _messageText.length > 0 ? _messageText : documentAttachment.caption;
                    bool isAnimated = false;
                    CGSize imageSize = CGSizeZero;
                    bool isSticker = false;
                    bool isVoice = false;
                    NSString *musicText = nil;
                    NSString *stickerRepresentation = nil;
                    for (id attribute in documentAttachment.attributes)
                    {
                        if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]])
                        {
                            isAnimated = true;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]])
                        {
                            imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                            imageSize = ((TGDocumentAttributeVideo *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                        {
                            isSticker = true;
                            stickerRepresentation = ((TGDocumentAttributeSticker *)attribute).alt;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                            isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                            if (!isVoice) {
                                NSString *artist = ((TGDocumentAttributeAudio *)attribute).performer;
                                NSString *title = ((TGDocumentAttributeAudio *)attribute).title;
                                if (artist.length != 0 && title.length != 0) {
                                    musicText = [[artist stringByAppendingString:@" — "] stringByAppendingString:title];
                                } else if (artist.length != 0) {
                                    musicText = artist;
                                } else if (title.length != 0) {
                                    musicText = title;
                                }
                            }
                        }
                    }
                    
                    if (TGPeerIdIsSecretChat(_conversationId) && [documentAttachment.mimeType isEqualToString:@"video/mp4"] && documentAttachment.size < 1024 * 1024) {
                        isAnimated = true;
                    }
                    
                    if (isSticker)
                    {
                        if (stickerRepresentation.length == 0)
                            _messageText = TGLocalized(@"Message.Sticker");
                        else
                            _messageText = [[NSString alloc] initWithFormat:@"%@ %@", stickerRepresentation, TGLocalized(@"Message.Sticker")];
                        _mediaIcon = nil;
                    }
                    else if (isAnimated) {
                        _messageText = TGLocalized(@"Message.Animation");
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else if (isVoice) {
                        _messageText = TGLocalized(@"Message.Audio");
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else if (musicText != nil) {
                        _messageText = musicText;
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else
                    {
                        NSString *fileName = ((TGDocumentMediaAttachment *)attachment).fileName;
                        if (caption.length > 0)
                        {
                            bool addEmoji = ![caption hasPrefix:@"📎 "];
                            _messageText = addEmoji ? [@"📎 " stringByAppendingString:caption] : caption;
                        }
                        else if (fileName.length != 0)
                            _messageText = fileName;
                        else
                            _messageText = TGLocalized(@"Message.File");
                        
                        _messageTextColor = mediaTextColor;
                        //_mediaIcon = [UIImage imageNamed:@"MediaFile"];
                        attachmentFound = true;
                    }
                    break;
                }
                else if (attachment.type == TGAudioMediaAttachmentType)
                {
                    _messageText = TGLocalized(@"Message.Audio");
                    _messageTextColor = mediaTextColor;
                    //_mediaIcon = [UIImage imageNamed:@"MediaVoice"];
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGGameAttachmentType) {
                    _messageText = [@"🎮 " stringByAppendingString:((TGGameMediaAttachment *)attachment).title];
                    _messageTextColor = mediaTextColor;
                    //_mediaIcon = [UIImage imageNamed:@"MediaVoice"];
                    attachmentFound = true;
                    break;
                } else if (attachment.type == TGInvoiceMediaAttachmentType) {
                    _messageText = [@"" stringByAppendingString:((TGInvoiceMediaAttachment *)attachment).title];
                    _messageTextColor = mediaTextColor;
                    //_mediaIcon = [UIImage imageNamed:@"MediaVoice"];
                    attachmentFound = true;
                    break;
                }
            }
        }
    }
    
    if (!attachmentFound)
    {
        _messageTextColor = normalTextColor;
        _mediaIcon = nil;
    }
    
    if (_messageText.length == 0)
    {
        _messageTextColor = actionTextColor;
        if (_isEncrypted)
        {
            if (_encryptionStatus == 1)
                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.AwaitingEncryption"), _encryptionFirstName];
            else if (_encryptionStatus == 2)
                _messageText = TGLocalized(@"DialogList.EncryptionProcessing");
            else if (_encryptionStatus == 3)
                _messageText = TGLocalized(@"DialogList.EncryptionRejected");
            else if (_encryptionStatus == 4)
            {
                if (_encryptionOutgoing)
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedOutgoing"), _encryptionFirstName];
                else
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedIncoming"), _encryptionFirstName];
            }
        }
    }
    
    }

    _textView.text = _messageText;
    _textView.textColor = TGDialogListMessageTextColor(_messageTextColor, _unread);
    _textView.actionTextColor = actionTextColor;
    _textView.mediaIcon = _mediaIcon;

    if (totalUnreadCount > 0 || _unreadMark) {
        _unreadCountBackgrond.hidden = false;
        _pinnedBackgrond.hidden = true;
        
        if (totalUnreadCount > 0)
        {
            _unreadCountLabel.hidden = false;
    
            if (TGDialogListBrandedIOS6Style())
            {
                _unreadCountLabel.text = [TGPresentation brandedIOS6BadgeTextForCount:totalUnreadCount];
            }
            else if (TGIsLocaleArabic())
            {
                _unreadCountLabel.text = [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d", totalUnreadCount]];
            }
            else
            {
                if (totalUnreadCount < 1000)
                    _unreadCountLabel.text = [[NSString alloc] initWithFormat:@"%d", totalUnreadCount];
                else
                    _unreadCountLabel.text = [[NSString alloc] initWithFormat:@"%dK", totalUnreadCount / 1000];
            }
        }
        else
        {
            _unreadCountLabel.hidden = true;
        }
    }
    else
    {
        _unreadCountBackgrond.hidden = true;
        _unreadCountLabel.hidden = true;
        
        _pinnedBackgrond.hidden = !_pinnedToTop;
    }
    
    if (_unreadMentionCount > 0 && (totalUnreadCount > 0 || _unreadMark || _unread)) {
        _unseenMentionsView.hidden = false;
    } else {
        _unseenMentionsView.hidden = true;
    }
    
    if (_deliveryState == TGMessageDeliveryStateFailed)
    {
        _unreadCountBackgrond.hidden = true;
        _unreadCountLabel.hidden = true;
        _pinnedBackgrond.hidden = true;
        _unseenMentionsView.hidden = true;
        
        if (_deliveryErrorBackgrond == nil)
        {
            _deliveryErrorBackgrond = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogUnsentIcon];
            [_wrapView addSubview:_deliveryErrorBackgrond];
        }
        else if (_deliveryErrorBackgrond.superview == nil)
            [_wrapView addSubview:_deliveryErrorBackgrond];
    }
    else if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil)
    {
        [_deliveryErrorBackgrond removeFromSuperview];
    }
    
    _textView.authorName = _hideAuthorName ? nil : _authorName;
    _textView.authorNameColor = self.presentation.pallete.dialogNameColor;
    
    if (_draft != nil && ![_draft isEmpty] && totalUnreadCount == 0) {
        _textView.text = _draft.text;
        _textView.textColor = TGDialogListBrandedIOS6Style() ? [UIColor blackColor] : _messageTextColor;
        _textView.authorName = TGLocalized(@"DialogList.Draft");
        _hideAuthorName = false;
        _authorName = _textView.authorName;
        _textView.authorNameColor = self.presentation.pallete.dialogDraftColor;
    }
    
    if (self.isFeed)
    {
        _avatarView.hidden = true;
        
        UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:29.0f];
        NSInteger i = 0;
        for (NSString *uri in _feedAvatarUrls)
        {
            TGLetteredAvatarView *avatarView = [self dequeueAvatarViewForIndex:i];
            
            if (uri.length == 0)
            {
                [avatarView loadGroupPlaceholderWithSize:CGSizeMake(29.0f, 29.0f) conversationId:[_feedChatIds[i] longLongValue] title:_feedChatTitles[i] placeholder:placeholder];
            }
            else
            {
                if (![_avatarView.currentUrl isEqualToString:uri])
                {
                    UIImage *currentPlaceholder = placeholder;
                    UIImage *currentImage = [avatarView currentImage];
                    if (currentImage != nil)
                        currentPlaceholder = currentImage;
                    
                    [avatarView loadImage:uri filter:@"circle:29x29" placeholder:nil];
                }
            }
            i++;
        }
    }
    else
    {
        _avatarView.hidden = false;
        
        CGFloat avatarSize = TGDialogListAvatarSize();
        UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:avatarSize];
        if (_isSavedMessages)
        {
            [_avatarView loadSavedMessagesWithSize:CGSizeMake(avatarSize, avatarSize) placeholder:placeholder];
        }
        else if (_avatarUrl.length != 0 && !_hasExplicitContent)
        {
            _avatarView.fadeTransitionDuration = keepState ? 0.3 : 0.14;
            
            if (![_avatarView.currentUrl isEqualToString:_avatarUrl])
            {
                if (keepState)
                {
                    [_avatarView loadImage:_avatarUrl filter:TGDialogListBrandedIOS6Style() ? @"scale:50x50" : (TGDialogListClassicIOS6Style() ? @"scale:52x52" : @"circle:62x62") placeholder:(_avatarView.currentImage != nil ? _avatarView.currentImage : placeholder) forceFade:true];
                }
                else
                {
                    [_avatarView loadImage:_avatarUrl filter:TGDialogListBrandedIOS6Style() ? @"scale:50x50" : (TGDialogListClassicIOS6Style() ? @"scale:52x52" : @"circle:62x62") placeholder:placeholder forceFade:false];
                }
            }
        }
        else
        {
            _avatarView.fadeTransitionDuration = 0.14;
            
            if (_isEncrypted || _conversationId > 0)
            {
                NSString *firstName = nil;
                NSString *lastName = nil;
                if (_titleLetters.count >= 2)
                {
                    firstName = _titleLetters[0];
                    lastName = _titleLetters[1];
                }
                else if (_titleLetters.count == 1)
                    firstName = _titleLetters[0];
                
                [_avatarView loadUserPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) uid:_isEncrypted ? _encryptedUserId : (int32_t)_conversationId firstName:firstName lastName:lastName placeholder:placeholder];
            }
            else
            {
                [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) conversationId:_conversationId title:_isBroadcast ? @"" : _titleText placeholder:placeholder];
            }
        }
    }
    
    _textView.isMultichat = _isGroupChat;
    _textView.isEncrypted = _isEncrypted;
    
    _dateLabel.dateText = _dateString;
    
    _validSize = CGSizeZero;
    
    [_textView setNeedsDisplay];
    
    if (_editingIsActive)
    {
        _editingIsActive = false;
    }
    
    if (_outgoing && (_draft == nil || [_draft isEmpty] || totalUnreadCount != 0) && !self.isSavedMessages) {
        if (TGDialogListBrandedIOS6Style())
        {
            _deliveredCheckmark.hidden = true;
            _readCheckmark.hidden = true;
        }
        else if (_deliveryState == TGMessageDeliveryStateDelivered && !_unread)
        {
            _deliveredCheckmark.hidden = true;
            _readCheckmark.hidden = false;
        }
        else if (_deliveryState == TGMessageDeliveryStateDelivered && _unread)
        {
            _deliveredCheckmark.hidden = false;
            _readCheckmark.hidden = true;
        }
        else
        {
            _deliveredCheckmark.hidden = true;
            _readCheckmark.hidden = true;
        }
        
        if (_deliveryState == TGMessageDeliveryStatePending)
        {
            if (_pendingIndicator == nil)
            {
                _pendingIndicator = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogPendingIcon];
                [_wrapView addSubview:_pendingIndicator];
            }
            
            _pendingIndicator.hidden = false;
        }
        else
        {
            _pendingIndicator.hidden = true;
        }
    }
    else
    {
        _deliveredCheckmark.hidden = true;
        _readCheckmark.hidden = true;
        
        _pendingIndicator.hidden = true;
    }
    
    if (_isMuted)
    {
        if (_muteIcon == nil)
            _muteIcon = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogMutedIcon];
        
        if (_muteIcon.superview == nil)
            [_wrapView addSubview:_muteIcon];
    }
    else if (_muteIcon != nil)
    {
        [_muteIcon removeFromSuperview];
    }
    
    if (_unreadCountBackgrond != nil && (totalUnreadCount > 0 || _unreadMark))
    {
        UIImage *unreadBackground = _isMuted ? _unreadMutedBackgroundImage : _unreadBackgroundImage;
        if (_unreadCountBackgrond.image != unreadBackground)
            _unreadCountBackgrond.image = unreadBackground;
        
        _unreadCountLabel.textColor = TGDialogListBrandedIOS6Style() ? [UIColor whiteColor] : (_isMuted ? _presentation.pallete.dialogBadgeMutedTextColor : _presentation.pallete.dialogBadgeTextColor);
    }
    
    if (_isVerified) {
        if (_verifiedIcon == nil) {
            _verifiedIcon = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogVerifiedIcon];
        }
        if (_verifiedIcon.superview == nil) {
            [_wrapView addSubview:_verifiedIcon];
        }
    } else if (_verifiedIcon != nil && _verifiedIcon.superview != nil) {
        [_verifiedIcon removeFromSuperview];
    }

    bool showPremiumBadge = _isPremium && !_isVerified && !_isSavedMessages;
    if (showPremiumBadge) {
        if (_premiumIcon == nil) {
            _premiumIcon = [[TGSimpleImageView alloc] initWithImage:[TGPresentationAssets premiumBadgeIcon:14.0f]];
        }
        if (_premiumIcon.superview == nil) {
            [_wrapView addSubview:_premiumIcon];
        }
    } else if (_premiumIcon != nil && _premiumIcon.superview != nil) {
        [_premiumIcon removeFromSuperview];
    }
    
    [self setNeedsLayout];
}

- (TGLetteredAvatarView *)dequeueAvatarViewForIndex:(NSInteger)index
{
    if (_avatarViews == nil)
        _avatarViews = [[NSMutableArray alloc] init];
    
    if ((NSInteger)_avatarViews.count < index + 1)
    {
        CGRect frame = CGRectZero;
        CGPoint origin = _avatarView.frame.origin;
        switch (index)
        {
            case 0:
                frame = CGRectMake(origin.x, origin.y, 29.0f, 29.0f);
                break;
                
            case 1:
                frame = CGRectMake(origin.x + 29.0f + 2.0f + TGScreenPixel, origin.y, 29.0f, 29.0f);
                break;
                
            case 2:
                frame = CGRectMake(origin.x, origin.y + 29.0f + 2.0f + TGScreenPixel, 29.0f, 29.0f);
                break;
                
            case 3:
                frame = CGRectMake(origin.x + 29.0f + 2.0f + TGScreenPixel, origin.y + 29.0f + 2.0f + TGScreenPixel, 29.0f, 29.0f);
                break;
                
            default:
                break;
        }
        
        TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] initWithFrame:frame];
        [avatarView setSingleFontSize:17.0f doubleFontSize:17.0f useBoldFont:true];
        [_avatarViews addObject:avatarView];
        [_wrapView addSubview:avatarView];
        
        return avatarView;
    }
    
    return _avatarViews[index];
}

- (void)dismissEditingControls:(bool)__unused animated
{
}

- (void)setIsLastCell:(bool)isLastCell {
    if (_isLastCell != isLastCell) {
        _isLastCell = isLastCell;
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews
{
#undef TG_TIMESTAMP_DEFINE
#undef TG_TIMESTAMP_MEASURE
    
#define TG_TIMESTAMP_DEFINE(x)
#define TG_TIMESTAMP_MEASURE(x)
    
    TG_TIMESTAMP_DEFINE(cellLayout);
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    [super layoutSubviews];
    
    CGFloat contentOffset = self.contentView.frame.origin.x;
    CGFloat contentWidth = self.contentView.frame.size.width;
    if (_fastScrolling && !CGSizeEqualToSize(_validSize, CGSizeZero) && CGSizeEqualToSize(_fastLayoutSize, self.bounds.size) && ABS(_fastLayoutContentOffset - contentOffset) < FLT_EPSILON)
        return;
    
    if ((_disableActions || contentOffset > FLT_EPSILON) && [_wrapView isExpanded]) {
        [_wrapView setExpanded:false animated:false];
    }
    [_wrapView setExpandable:contentOffset <= FLT_EPSILON || _disableActions];
    
    if (iosMajorVersion() >= 7)
    {
        static Class separatorClass = nil;
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            separatorClass = NSClassFromString(TGEncodeText(@"`VJUbcmfWjfxDfmmTfqbsbupsWjfx", -1));
        });
        for (UIView *subview in self.subviews) {
            if (subview.class == separatorClass) {
                CGRect frame = subview.frame;
                if (_isLastCell) {
                    frame.size.width = self.bounds.size.width;
                    frame.origin.x = 0.0f;
                } else {
                    if (contentOffset > FLT_EPSILON) {
                        frame.size.width = self.bounds.size.width - 116.0f;
                        frame.origin.x = 116.0f;
                    } else {
                        CGFloat contentX = TGDialogListContentOffset();
                        frame.size.width = self.bounds.size.width - contentX;
                        frame.origin.x = contentX;
                    }
                }
                if (!CGRectEqualToRect(subview.frame, frame)) {
                    subview.frame = frame;
                }
                break;
            }
        }
    }
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    CGFloat separatorHeight = TGScreenPixel;
    
    CGSize rawSize = self.frame.size;
    
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil) {
        selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, rawSize.height + separatorHeight);
    }
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    self.backgroundView.frame = CGRectMake(0.0f, 0.0f, rawSize.width, rawSize.height);
    
    static CGSize screenSize;
    static CGFloat widescreenWidth;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = TGScreenSize();
        widescreenWidth = MAX(screenSize.width, screenSize.height);
    });
    
    CGFloat safeInset = 0.0f;
    if (iosMajorVersion() >= 11 && [self respondsToSelector:@selector(safeAreaInsets)])
    {
        UIEdgeInsets (*safeAreaInsetsImp)(id, SEL) = (UIEdgeInsets (*)(id, SEL))[self methodForSelector:@selector(safeAreaInsets)];
        safeInset = safeAreaInsetsImp(self, @selector(safeAreaInsets)).left;
    }
    
    if (contentOffset > safeInset + FLT_EPSILON && (_pinnedToTop || _isAd)) {
        if (_pinnedBackgrond.alpha >= FLT_EPSILON) {
            _pinnedBackgrond.alpha = 0.0f;
            _unreadCountBackgrond.alpha = 0.0f;
            _unseenMentionsView.alpha = 0.0f;
            _dateLabel.alpha = 0.0f;
            _readCheckmark.alpha = 0.0f;
            _deliveredCheckmark.alpha = 0.0f;
            _unreadCountLabel.alpha = 0.0f;
        }
    } else if (_pinnedBackgrond.alpha <= 1.0f - FLT_EPSILON) {
        _pinnedBackgrond.alpha = 1.0f;
        _unreadCountBackgrond.alpha = 1.0f;
        _unseenMentionsView.alpha = 1.0f;
        _dateLabel.alpha = 1.0f;
        _readCheckmark.alpha = 1.0f;
        _deliveredCheckmark.alpha = 1.0f;
        _unreadCountLabel.alpha = 1.0f;
    }
    
    CGSize size = rawSize;
    if (!TGIsPad())
    {
        if ([TGViewController hasTallScreen])
        {
            size.width = contentWidth;
        }
        else
        {
            if (rawSize.width >= widescreenWidth - FLT_EPSILON)
                size.width = screenSize.height - contentOffset;
            else
                size.width = screenSize.width - contentOffset;
        }
    }
    else
        size.width = rawSize.width - contentOffset;
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    CGFloat contentX = TGDialogListContentOffset();
    CGFloat separatorOffset = contentX;
    
    if (_separatorLayer != nil) {
        bool disabledActions = [CATransaction disableActions];
        [CATransaction setDisableActions:true];
        _separatorLayer.frame = CGRectMake(separatorOffset, size.height - separatorHeight, rawSize.width - separatorOffset + 256.0f, separatorHeight);
        [CATransaction setDisableActions:disabledActions];
    }
    
    _wrapView.frame = CGRectMake(contentOffset, 0.0f, size.width, size.height);

    CGFloat avatarSize = TGDialogListAvatarSize();
    CGFloat avatarX = TGDialogListBrandedIOS6Style() ? 6.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 10.0f);
    CGFloat avatarY = TGDialogListBrandedIOS6Style() ? 5.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 7.0f);
    _avatarView.frame = CGRectMake(avatarX, avatarY, avatarSize, avatarSize);
    if (TGDialogListBrandedIOS6Style() && _brandedAvatarShadowView != nil)
    {
        _brandedAvatarShadowView.frame = _avatarView.frame;
        _brandedAvatarShadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_brandedAvatarShadowView.bounds cornerRadius:8.0f].CGPath;
    }

    if (TGDialogListBrandedIOS6Style() && _brandedDisclosureView != nil)
    {
        bool emphasized = !_unread;
        if (_draft != nil && ![_draft isEmpty])
            emphasized = true;
        _brandedDisclosureView.image = TGDialogListBrandedDisclosureImage(emphasized);
        CGSize disclosureSize = _brandedDisclosureView.image.size;
        CGFloat disclosureY = CGFloor(CGRectGetMidY(_avatarView.frame) - disclosureSize.height / 2.0f);
        _brandedDisclosureView.frame = CGRectMake(size.width - 20.0f, disclosureY, disclosureSize.width, disclosureSize.height);
    }
    
    if (!CGSizeEqualToSize(_validSize, size))
    {
        if (_textView != nil)
        {
            if (TGDialogListBrandedIOS6Style())
            {
                CGRect textViewFrame = CGRectMake(contentX, 0.0f, size.width - contentX, 62.0f);
                if (!CGRectEqualToRect(_textView.frame, textViewFrame))
                {
                    _textView.frame = textViewFrame;
                    [_textView setNeedsDisplay];
                }
            }
            else if (!CGSizeEqualToSize(_textView.frame.size, CGRectMake(contentX - 1.0f, 6, size.width - (contentX - 1.0f), 62).size))
            {
                _textView.frame = CGRectMake(contentX, 6, size.width - contentX, 62);
                [_textView setNeedsDisplay];
            }
        }
        
        int rightPadding = 0.0f;
        
        CGFloat countTextWidth = _unreadCountLabel.hidden ? 9.0f : [_unreadCountLabel.text sizeWithFont:_unreadCountLabel.font].width;
        
        CGFloat brandedBadgeHeight = 18.0f * TGDialogListBrandedIOS6BadgeScale;
        CGFloat brandedBadgeHorizontalPadding = 10.0f * TGDialogListBrandedIOS6BadgeScale;
        CGFloat backgroundWidth = TGDialogListBrandedIOS6Style() ? MAX(brandedBadgeHeight, countTextWidth + brandedBadgeHorizontalPadding) : MAX(20.0f, countTextWidth + 11.0f);
        CGFloat brandedBadgeOriginOffset = (18.0f - brandedBadgeHeight) / 2.0f;
        CGRect unreadCountBackgroundFrame = TGDialogListBrandedIOS6Style() ? CGRectMake(43.0f + brandedBadgeOriginOffset, 42.0f + brandedBadgeOriginOffset, backgroundWidth, brandedBadgeHeight) : CGRectMake(size.width - 11.0f - backgroundWidth, 38.0f, backgroundWidth, 20.0f);
        _unreadCountBackgrond.frame = unreadCountBackgroundFrame;
        if (TGDialogListBrandedIOS6Style())
        {
            _unreadCountBackgrond.image = [TGPresentation brandedIOS6BadgeImageForWidth:unreadCountBackgroundFrame.size.width height:unreadCountBackgroundFrame.size.height];
            _unreadCountBackgrond.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_unreadCountBackgrond.bounds cornerRadius:unreadCountBackgroundFrame.size.height / 2.0f].CGPath;
        }
        _pinnedBackgrond.frame = TGDialogListBrandedIOS6Style() ? CGRectMake(size.width - 25.0f, 4.0f, 16.0f, 16.0f) : CGRectMake(size.width - 14.0f - 20.0f, 39.0f, 20.0f, 20.0f);
        if (TGDialogListBrandedIOS6Style())
        {
            _unreadCountLabel.textAlignment = NSTextAlignmentCenter;
            CGRect unreadCountLabelFrame = unreadCountBackgroundFrame;
            unreadCountLabelFrame.origin.y = unreadCountBackgroundFrame.origin.y + TGScreenPixel;
            _unreadCountLabel.frame = unreadCountLabelFrame;
        }
        else
        {
            CGRect unreadCountLabelFrame = _unreadCountLabel.frame;
            unreadCountLabelFrame.origin = CGPointMake(unreadCountBackgroundFrame.origin.x + TGScreenPixelFloor(((unreadCountBackgroundFrame.size.width - countTextWidth) / 2.0f)), unreadCountBackgroundFrame.origin.y + 1.0f - TGScreenPixel);
            _unreadCountLabel.frame = unreadCountLabelFrame;
        }
        
        if (_unreadCountBackgrond.hidden && _pinnedBackgrond.hidden) {
            _unseenMentionsView.frame = CGRectMake(size.width - 11.0f - 20.0f, 38.0f, 20.0f, 20.0f);
        } else {
            _unseenMentionsView.frame = CGRectMake(unreadCountBackgroundFrame.origin.x - 6.0f - 20.0f, unreadCountBackgroundFrame.origin.y, 20.0f, 20.0f);
        }
        
        TG_TIMESTAMP_MEASURE(cellLayout);
        
        if (TGDialogListBrandedIOS6Style())
            rightPadding += 22;
        else if (!_unreadCountBackgrond.hidden || !_pinnedBackgrond.hidden)
            rightPadding += unreadCountBackgroundFrame.size.width + 16;
        
        if (!_unseenMentionsView.hidden) {
            if (!_unreadCountBackgrond.hidden || !_pinnedBackgrond.hidden) {
                rightPadding += 24.0f;
            } else {
                rightPadding += 24.0f + 16.0f;
            }
        }
        
        if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil)
        {
            CGRect deliveryErrorFrame = _deliveryErrorBackgrond.frame;
            deliveryErrorFrame = CGRectMake(size.width - 14.0f - TGScreenPixel - deliveryErrorFrame.size.width, 38.0f + TGScreenPixel, deliveryErrorFrame.size.width, deliveryErrorFrame.size.height);
            _deliveryErrorBackgrond.frame = deliveryErrorFrame;
            
            rightPadding += 36;
        }
        
        CGSize dateTextSize = [_dateLabel measureTextSize];
        
        CGFloat dateWidth = _date == 0 ? 0 : (int)(dateTextSize.width);
        CGRect dateFrame = TGDialogListBrandedIOS6Style() ? CGRectMake(size.width - dateWidth - 8.0f, 48.0f, MAX(dateTextSize.width, 40.0f), 15.0f) : CGRectMake(size.width - dateWidth - 11.0f + (contentOffset > FLT_EPSILON ? 4.0f : 0.0f), 10.0f + TGScreenPixel - (TGIsPad() ? 1.0f : 0.0f), _isAd ? dateTextSize.width : 75, 20);
        _dateLabel.frame = dateFrame;
        CGFloat titleLabelWidth = TGDialogListBrandedIOS6Style() ? (size.width - contentX - 29.0f) : (int)(dateFrame.origin.x - 4 - contentX - 18);
        CGFloat brandedStatusWidth = 0.0f;
        if (TGDialogListBrandedIOS6Style() && !_brandedStatusLabel.hidden)
        {
            brandedStatusWidth = MIN(103.2f, CGCeil([_brandedStatusLabel.text sizeWithFont:_brandedStatusLabel.font].width));
            titleLabelWidth = MAX(34.0f, titleLabelWidth - brandedStatusWidth - 3.0f);
        }
        CGFloat groupChatIconWidth = 0.0f;
        if (_isEncrypted)
        {
            groupChatIconWidth = 15;
            titleLabelWidth -= groupChatIconWidth;
        }
        
        if (_isMuted)
            titleLabelWidth -= 12;
        
        if (_isVerified) {
            titleLabelWidth -= _verifiedIcon.bounds.size.width + 10.0f;
        } else if (_premiumIcon.superview != nil) {
            titleLabelWidth -= _premiumIcon.bounds.size.width + 10.0f;
        }
        
        CGFloat titleTextWidth = CGCeil([_titleText sizeWithFont:_textView.titleFont].width) + (TGDialogListBrandedIOS6Style() ? 1.0f : 0.0f);
        titleLabelWidth = MIN(titleLabelWidth, titleTextWidth);
        
        TG_TIMESTAMP_MEASURE(cellLayout);
        
        CGFloat checkmarkY = TGDialogListBrandedIOS6Style() ? 31.0f : 13.0f;
        _deliveredCheckmark.frame = CGRectMake(dateFrame.origin.x - 16, checkmarkY, 14, 11);
        _readCheckmark.frame = CGRectMake(dateFrame.origin.x - 20, checkmarkY, 18, 11);
        
        if (_pendingIndicator != nil)
            _pendingIndicator.frame = CGRectMake(dateFrame.origin.x - 16, 13, 12, 12);
        
        CGFloat brandedTitleY = 2.0f;
        CGFloat brandedTitleHeight = CGCeil(_textView.titleFont.lineHeight);
        CGFloat brandedBodyHeight = CGCeil(_textView.textFont.lineHeight);
        CGRect titleRect = CGRectMake(contentX + groupChatIconWidth, TGDialogListBrandedIOS6Style() ? brandedTitleY : 8.0f, titleLabelWidth, TGDialogListBrandedIOS6Style() ? brandedTitleHeight : 20.0f);
        if (TGDialogListBrandedIOS6Style() && !_brandedStatusLabel.hidden)
        {
            CGFloat statusHeight = CGCeil(_brandedStatusLabel.font.lineHeight);
            CGFloat statusY = TGScreenPixelFloor(titleRect.origin.y + _textView.titleFont.ascender - _brandedStatusLabel.font.ascender + TGScreenPixel);
            CGFloat statusX = CGRectGetMaxX(titleRect) + 2.0f;
            if (_isVerified)
                statusX += _verifiedIcon.bounds.size.width + 7.0f;
            else if (_premiumIcon.superview != nil)
                statusX += _premiumIcon.bounds.size.width + 7.0f;
            _brandedStatusLabel.frame = CGRectMake(statusX, statusY, brandedStatusWidth, statusHeight);
        }

        CGFloat brandedMessageY = brandedTitleY + brandedTitleHeight;
        CGFloat brandedMessageHeight = MAX(brandedBodyHeight, 62.0f - brandedMessageY);
        CGRect messageRect = CGRectMake(contentX, TGDialogListBrandedIOS6Style() ? brandedMessageY : 30.0f - TGScreenPixel, size.width - contentX - 7.0f - rightPadding, TGDialogListBrandedIOS6Style() ? brandedMessageHeight : 40.0f);
        
        CGRect typingRect = messageRect;
        typingRect.size.width -= 12;
        if (TGIsRTL())
            typingRect.origin.x += 12.0f;
        _textView.typingFrame = typingRect;
        
        if (_typingDotsContainer.superview != nil)
        {
            CGSize typingSize = TGDialogListBrandedIOS6Style() ? [_textView.typingText sizeWithFont:_textView.textFont] : TGDialogListTextSize(_textView.typingText, _textView.textFont, typingRect.size.width, 1);
            
            CGRect typingDotsFrame = _typingDotsContainer.frame;
            typingDotsFrame.origin.x = TGIsRTL() ? messageRect.origin.x : (typingRect.origin.x + typingSize.width);
            typingDotsFrame.origin.y = typingRect.origin.y + 4;
            _typingDotsContainer.frame = typingDotsFrame;
        }
        
        if (_authorName != nil && !_hideAuthorName)
        {
            _textView.authorNameFrame = CGRectMake(contentX, TGDialogListBrandedIOS6Style() ? brandedMessageY : 29.0f + TGScreenPixel, size.width - contentX - 4.0f - rightPadding, TGDialogListBrandedIOS6Style() ? brandedBodyHeight : 20.0f);
            
            CGFloat authorLineHeight = TGDialogListBrandedIOS6Style() ? brandedBodyHeight : 12.0f;
            messageRect.origin.y += TGDialogListBrandedIOS6Style() ? authorLineHeight : (iosMajorVersion() >= 7 ? (16 + TGScreenPixel) : 17);
            messageRect.size.height -= authorLineHeight;
        }

        if (TGDialogListBrandedIOS6Style() && !_unreadCountBackgrond.hidden)
            messageRect = TGDialogListRectAvoidingBadge(messageRect, unreadCountBackgroundFrame, 4.0f);
        
        TG_TIMESTAMP_MEASURE(cellLayout);
        
        titleRect.size.width = titleLabelWidth;
        
        if (!TGDialogListBrandedIOS6Style() && iosMajorVersion() < 7 && _authorName != nil && !_hideAuthorName && TGDialogListTextSize(_messageText, _textView.textFont, messageRect.size.width, 2).height < 20)
            messageRect.origin.y += 9;
        
        if (_isVerified) {
            CGRect verifiedRect = _verifiedIcon.bounds;
            verifiedRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 4.0f, titleRect.origin.y + 4 - TGScreenPixel);
            _verifiedIcon.frame = verifiedRect;
        } else if (_premiumIcon.superview != nil) {
            CGRect premiumRect = _premiumIcon.bounds;
            premiumRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 4.0f, titleRect.origin.y + 3.0f - TGScreenPixel);
            _premiumIcon.frame = premiumRect;
        }
        
        if (_isMuted)
        {
            CGRect muteRect = _muteIcon.frame;
            if (TGDialogListBrandedIOS6Style())
            {
                CGFloat muteX = titleRect.origin.x + titleRect.size.width + 3.0f;
                CGFloat lineY = titleRect.origin.y;
                CGFloat lineHeight = _textView.titleFont.lineHeight;
                if (_isVerified)
                    muteX += _verifiedIcon.bounds.size.width + 7.0f;
                else if (_premiumIcon.superview != nil)
                    muteX += _premiumIcon.bounds.size.width + 7.0f;
                if (!_brandedStatusLabel.hidden)
                {
                    muteX = CGRectGetMaxX(_brandedStatusLabel.frame) + 3.0f;
                    lineY = _brandedStatusLabel.frame.origin.y;
                    lineHeight = _brandedStatusLabel.frame.size.height;
                }
                muteRect.origin = CGPointMake(muteX, TGScreenPixelFloor(lineY + (lineHeight - muteRect.size.height) / 2.0f));
            }
            else
            {
                muteRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 3, titleRect.origin.y + 6);
                if (_isVerified)
                    muteRect.origin.x += _verifiedIcon.bounds.size.width + 7.0f;
                else if (_premiumIcon.superview != nil)
                    muteRect.origin.x += _premiumIcon.bounds.size.width + 7.0f;
            }
            _muteIcon.frame = muteRect;
        }
        
        _textView.titleFrame = titleRect;
        _textView.textFrame = messageRect;

        _validSize = size;
        _fastLayoutSize = self.bounds.size;
        _fastLayoutContentOffset = contentOffset;
        
        TG_TIMESTAMP_MEASURE(cellLayout);
    }
}

#pragma mark -

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    bool wasEditing = self.isEditing;
    [super setEditing:editing animated:animated];
    if (animated && wasEditing != editing) {
        UIView *snapshotWrappingView = [[UIView alloc] initWithFrame:_wrapView.bounds];
        snapshotWrappingView.backgroundColor = self.backgroundColor;
        UIView *snapshotView = [_textView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = _textView.frame;
        [snapshotWrappingView addSubview:snapshotView];
        [_wrapView insertSubview:snapshotWrappingView aboveSubview:_textView];
        [UIView animateWithDuration:0.3 animations:^{
            snapshotWrappingView.alpha = 0.0f;
        } completion:^(__unused BOOL finished) {
            [snapshotWrappingView removeFromSuperview];
        }];
    }
}

- (bool)showingDeleteConfirmationButton
{
    return false;
}

- (bool)isEditingControlsExpanded {
    return [_wrapView isExpanded];
}

- (bool)isEditingControlsTracking {
    return [_wrapView isTracking];
}

- (void)setEditingConrolsExpanded:(bool)expanded animated:(bool)animated {
    if (expanded)
        _wrapView.layer.shouldRasterize = false;
    [_wrapView setExpanded:expanded animated:animated];
    if (!expanded && _fastScrolling && !_animatingTyping)
    {
        _wrapView.layer.shouldRasterize = true;
        _wrapView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
}

- (void)setSwipeActionsEnabled:(bool)enabled {
    [_wrapView setSwipeGesturesEnabled:enabled];
}

- (void)resetLocalization
{
    _dateLabel.dateText = @"";
}

- (UIView *)avatarSnapshotView
{
    return [_avatarView snapshotViewAfterScreenUpdates:false];
}

- (CGRect)avatarFrame
{
    CGRect frame = self.bounds;
    frame.size.width = CGRectGetMaxX(_avatarView.frame) + _avatarView.frame.origin.x;
    
    return frame;
}

- (CGRect)textContentFrame
{
    return self.bounds;
}

- (void)animateHighlight
{
    if (self.selected)
        return;
    
    [self setHighlighted:true];
    
    TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
    {
        [self setHighlighted:false animated:true];
    });
}

@end
