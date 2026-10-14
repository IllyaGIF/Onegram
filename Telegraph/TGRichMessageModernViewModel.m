#import "TGRichMessageModernViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGRichMessage.h"
#import "TGRichMessageMediaAttachment.h"
#import "TGRichMessageMath.h"
#import "TGRichMessageTheme.h"
#import "TGRichMessageTextBuilder.h"
#import "TGRichMessageDecorationViewModel.h"
#import "TGRichMessageInlineImageStore.h"

#import "TGModernFlatteningViewModel.h"
#import "TGModernTextViewModel.h"
#import "TGModernImageViewModel.h"
#import "TGSignalImageViewModel.h"
#import "TGReplyHeaderModel.h"
#import "TGTextMessageBackgroundViewModel.h"
#import "TGTelegraphConversationMessageAssetsSource.h"
#import "TGSharedPhotoSignals.h"
#import "TGSharedFileSignals.h"
#import "TGSharedMediaSignals.h"
#import "TGSharedMediaUtils.h"
#import "TGInstantPageMedia.h"
#import "TLUser$modernUser.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGBotReplyMarkupButton.h"
#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

typedef enum {
    TGRichNodeText = 0,
    TGRichNodeCode,
    TGRichNodeDivider,
    TGRichNodeAnchor,
    TGRichNodeList,
    TGRichNodeListItem,
    TGRichNodeQuote,
    TGRichNodePullquote,
    TGRichNodeMedia,
    TGRichNodeGrid,
    TGRichNodeFile,
    TGRichNodeTable,
    TGRichNodeDetails,
    TGRichNodeEmbedPost,
    TGRichNodeChannel,
    TGRichNodeArticles,
    TGRichNodeArticle,
    TGRichNodeMath,
    TGRichNodeButtons,
    TGRichNodeCard
} TGRichNodeKind;

typedef enum {
    TGRichMarkerBullet = 0,
    TGRichMarkerNumber,
    TGRichMarkerCheckbox
} TGRichMarkerKind;

@interface TGRichNode : NSObject

@property (nonatomic) TGRichNodeKind kind;
@property (nonatomic, strong) TGRichMessageBlock *block;
@property (nonatomic) CGFloat spacingBefore;
@property (nonatomic) CGFloat spacingAfter;
@property (nonatomic, strong) TGModernTextViewModel *textModel;
@property (nonatomic, strong) TGModernTextViewModel *secondaryModel;
@property (nonatomic, strong) TGModernTextViewModel *tertiaryModel;
@property (nonatomic, strong) NSArray *children;
@property (nonatomic, strong) NSArray *models;
@property (nonatomic, strong) NSArray *cells;
@property (nonatomic, strong) TGSignalImageViewModel *imageModel;
@property (nonatomic, strong) TGModernFlatteningViewModel *badgeModel;
@property (nonatomic) CGSize mediaSize;
@property (nonatomic) CGFloat mediaCornerRadius;
@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) id payload;
@property (nonatomic, strong) NSString *key;
@property (nonatomic) bool expanded;
@property (nonatomic) bool collapsible;
@property (nonatomic) bool hiddenMedia;
@property (nonatomic) TGRichMarkerKind markerKind;
@property (nonatomic) bool checked;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic, strong) NSDictionary *anchors;
@property (nonatomic, strong) NSString *anchorName;
@property (nonatomic, strong) NSString *mathSource;
@property (nonatomic, strong) TGRichMessageMathLayout *math;
@property (nonatomic) CGFloat mathWidth;
@property (nonatomic, strong) NSString *fileExtension;
@property (nonatomic) int32_t flags;

@end

@implementation TGRichNode

@end

@interface TGRichTableCellInfo : NSObject

@property (nonatomic, strong) TGRichMessageTableCell *cell;
@property (nonatomic, strong) TGModernTextViewModel *model;
@property (nonatomic) NSInteger row;
@property (nonatomic) NSInteger column;
@property (nonatomic) NSInteger rowspan;
@property (nonatomic) NSInteger colspan;

@end

@implementation TGRichTableCellInfo

@end

@interface TGRichHitRegion : NSObject

@property (nonatomic) CGRect rect;
@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) id payload;

@end

@implementation TGRichHitRegion

@end

static UIImage *TGRichMessageBadgeBackgroundImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat radius = 4.0f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(radius * 2.0f, radius * 2.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.55f).CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, radius * 2.0f, radius * 2.0f));
        image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)radius topCapHeight:(NSInteger)radius];
        UIGraphicsEndImageContext();
    });
    return image;
}

static NSString *TGRichMessageDurationString(int32_t duration)
{
    if (duration >= 60 * 60)
        return [[NSString alloc] initWithFormat:@"%d:%02d:%02d", (int)(duration / 3600), (int)((duration % 3600) / 60), (int)(duration % 60)];
    return [[NSString alloc] initWithFormat:@"%d:%02d", (int)(duration / 60), (int)(duration % 60)];
}

static NSString *TGRichMessageSizeString(int32_t size)
{
    if (size >= 1024 * 1024)
        return [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Megabytes"), (float)size / (1024.0f * 1024.0f)];
    if (size >= 1024)
        return [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Kilobytes"), (int)(size / 1024)];
    return [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Bytes"), (int)size];
}

static NSString *TGRichMessageRomanNumber(NSInteger value)
{
    if (value <= 0 || value >= 4000)
        return [[NSString alloc] initWithFormat:@"%d", (int)value];
    NSArray *numerals = @[@"M", @"CM", @"D", @"CD", @"C", @"XC", @"L", @"XL", @"X", @"IX", @"V", @"IV", @"I"];
    int values[] = {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1};
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < numerals.count; index++)
    {
        while (value >= values[index])
        {
            [result appendString:numerals[index]];
            value -= values[index];
        }
    }
    return result;
}

static NSString *TGRichMessageAlphabeticNumber(NSInteger value)
{
    if (value <= 0)
        return [[NSString alloc] initWithFormat:@"%d", (int)value];
    NSMutableString *result = [[NSMutableString alloc] init];
    while (value > 0)
    {
        value -= 1;
        unichar c = (unichar)('a' + value % 26);
        [result insertString:[NSString stringWithCharacters:&c length:1] atIndex:0];
        value /= 26;
    }
    return result;
}

static NSString *TGRichMessageFormatNumber(NSInteger value, NSString *type)
{
    if ([type isEqualToString:@"a"])
        return TGRichMessageAlphabeticNumber(value);
    if ([type isEqualToString:@"A"])
        return [TGRichMessageAlphabeticNumber(value) uppercaseString];
    if ([type isEqualToString:@"i"])
        return [TGRichMessageRomanNumber(value) lowercaseString];
    if ([type isEqualToString:@"I"])
        return TGRichMessageRomanNumber(value);
    return [[NSString alloc] initWithFormat:@"%d", (int)value];
}

@interface TGRichMessageModernViewModel ()
{
    TGRichMessage *_richMessage;
    int64_t _peerId;
    int32_t _editDate;
    NSSet *_expandedKeys;

    TGRichMessageTheme *_theme;
    TGRichMessageTextEnvironment *_environment;
    TGModernViewModel *_container;
    TGRichMessageDecorationViewModel *_decorationModel;
    NSArray *_nodes;
    NSMutableArray *_textModels;
    NSMutableArray *_imageModels;
    NSMutableArray *_galleryMedias;
    NSMutableArray *_audioDocuments;
    NSSet *_inlineImageKeys;

    NSMutableArray *_decorations;
    NSMutableArray *_hitRegions;
    NSMutableDictionary *_anchorOffsets;
    CGFloat _layoutWidth;
    CGFloat _contentHeight;
    bool _layoutValid;

    NSArray *_currentLinkSelectionViews;
    __weak TGModernViewStorage *_viewStorage;
    CGPoint _imageBindingOffset;
}

@end

@implementation TGRichMessageModernViewModel

- (instancetype)initWithMessage:(TGMessage *)message richMessage:(TGRichMessage *)richMessage authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context
{
    self = [super initWithMessage:message authorPeer:authorPeer viaUser:viaUser context:context];
    if (self != nil)
    {
        _authorPeerId = message.fromUid;
        _richMessage = richMessage;
        _peerId = message.cid;
        _editDate = message.editDate;
        _expandedKeys = [context richMessageExpandedKeysForMessageId:message.mid peerId:message.cid];
        _theme = [[TGRichMessageTheme alloc] initWithContext:context incoming:_incomingAppearance];
        [self rebuildWithViewStorage:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inlineImageLoaded:) name:TGRichMessageInlineImageLoadedNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGRichMessageInlineImageLoadedNotification object:nil];
}

- (void)inlineImageLoaded:(NSNotification *)notification
{
    NSString *key = notification.userInfo[@"key"];
    NSSet *keys = _inlineImageKeys;
    if (key == nil || ![keys containsObject:key])
        return;
    [_contentModel setNeedsSubmodelContentsUpdate];
    [_contentModel updateSubmodelContentsIfNeeded];
}

#pragma mark - Styles

- (CGFloat)fontSize
{
    return _theme.fontSize;
}

- (TGRichMessageTextStyle *)styleWithSize:(CGFloat)size bold:(bool)bold italic:(bool)italic color:(TGRichMessageColorKind)color
{
    TGRichMessageTextStyle *style = [TGRichMessageTextStyle styleWithSize:size];
    style.bold = bold;
    style.italic = italic;
    style.colorKind = color;
    return style;
}

- (TGModernTextViewModel *)registerTextModel:(TGModernTextViewModel *)model
{
    if (model != nil)
        [_textModels addObject:model];
    return model;
}

- (TGModernTextViewModel *)textModelForText:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style anchors:(NSMutableDictionary *)anchors
{
    if (text == nil)
        return nil;
    return [self registerTextModel:[_environment textModelWithText:text style:style anchors:anchors]];
}

- (TGModernTextViewModel *)textModelForString:(NSString *)string style:(TGRichMessageTextStyle *)style
{
    return [self registerTextModel:[_environment textModelWithString:string style:style]];
}

- (bool)isKeyToggled:(NSString *)key
{
    return key != nil && [_expandedKeys containsObject:key];
}

#pragma mark - Building

- (void)rebuildWithViewStorage:(TGModernViewStorage *)viewStorage
{
    [self clearLinkSelection];
    if (_container != nil)
        [_contentModel removeSubmodel:_container viewStorage:viewStorage];

    _container = [[TGModernViewModel alloc] init];
    _container.hasNoView = true;
    _decorationModel = [[TGRichMessageDecorationViewModel alloc] initWithTheme:_theme];
    [_container addSubmodel:_decorationModel];

    _textModels = [[NSMutableArray alloc] init];
    _imageModels = [[NSMutableArray alloc] init];
    _galleryMedias = [[NSMutableArray alloc] init];
    _audioDocuments = [[NSMutableArray alloc] init];
    _environment = [[TGRichMessageTextEnvironment alloc] initWithTheme:_theme richMessage:_richMessage spoilersRevealed:[self isKeyToggled:@"spoilers"]];

    _nodes = [self nodesForBlocks:_richMessage.blocks path:@"b"];
    _inlineImageKeys = [_environment.inlineImageKeys copy];

    for (TGModernTextViewModel *model in _textModels)
        [_container addSubmodel:model];
    for (TGSignalImageViewModel *model in _imageModels)
        [_container addSubmodel:model];
    [_contentModel addSubmodel:_container];

    _layoutValid = false;
    _layoutWidth = 0.0f;
}

- (void)relayoutWithWidth:(CGFloat)width origin:(CGPoint)origin
{
    if (width <= 0.0f)
        return;
    [self performLayoutWithWidth:width];
    [self applyContainerOrigin:origin];
    [_contentModel setNeedsSubmodelContentsUpdate];
    [_contentModel updateSubmodelContentsIfNeeded];
}

- (TGSignalImageViewModel *)imageModelWithCornerRadius:(CGFloat)radius identifier:(NSString *)identifier generator:(SSignal *(^)(CGSize size, void (^pixelProcessingBlock)(void *, int, int, int)))generator
{
    TGSignalImageViewModel *model = [[TGSignalImageViewModel alloc] init];
    model.skipDrawInContext = true;
    model.viewUserInteractionDisabled = true;
    model.ignoresInvertColors = true;
    __weak TGSignalImageViewModel *weakModel = model;
    [model setSignalGenerator:^SSignal *
    {
        __strong TGSignalImageViewModel *strongModel = weakModel;
        CGSize size = strongModel == nil ? CGSizeMake(100.0f, 100.0f) : strongModel.frame.size;
        size = CGSizeMake(MAX(1.0f, CGCeil(size.width)), MAX(1.0f, CGCeil(size.height)));
        return generator(size, radius > 0.0f ? [TGSharedMediaSignals pixelProcessingBlockForRoundCornersOfRadius:radius] : nil);
    } identifier:identifier];
    [_imageModels addObject:model];
    return model;
}

- (TGSignalImageViewModel *)imageModelForPhoto:(TGImageMediaAttachment *)photo cornerRadius:(CGFloat)radius
{
    if (photo == nil)
        return nil;
    return [self imageModelWithCornerRadius:radius identifier:[[NSString alloc] initWithFormat:@"rich-photo-%lld-%d", photo.imageId, (int)radius] generator:^SSignal *(CGSize size, void (^pixelProcessingBlock)(void *, int, int, int))
    {
        return [TGSharedPhotoSignals squarePhotoThumbnail:photo ofSize:size threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:pixelProcessingBlock downloadLargeImage:true placeholder:nil];
    }];
}

- (TGSignalImageViewModel *)imageModelForDocument:(TGDocumentMediaAttachment *)document cornerRadius:(CGFloat)radius
{
    if (document == nil)
        return nil;
    return [self imageModelWithCornerRadius:radius identifier:[[NSString alloc] initWithFormat:@"rich-document-%lld-%d", document.documentId, (int)radius] generator:^SSignal *(CGSize size, void (^pixelProcessingBlock)(void *, int, int, int))
    {
        return [TGSharedFileSignals squareFileThumbnail:document ofSize:size threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:pixelProcessingBlock];
    }];
}

- (CGFloat)mediaCornerRadius
{
    return _theme.branded ? 6.0f : 8.0f;
}

- (TGModernFlatteningViewModel *)badgeModelWithText:(NSString *)text
{
    if (text.length == 0)
        return nil;
    TGModernFlatteningViewModel *badge = [[TGModernFlatteningViewModel alloc] init];
    TGModernImageViewModel *background = [[TGModernImageViewModel alloc] initWithImage:TGRichMessageBadgeBackgroundImage()];
    [badge addSubmodel:background];
    TGModernTextViewModel *label = [[TGModernTextViewModel alloc] initWithText:text font:TGCoreTextSystemFontOfSize(11.0f)];
    label.textColor = [UIColor whiteColor];
    [label layoutForContainerSize:CGSizeMake(200.0f, 200.0f)];
    [badge addSubmodel:label];
    CGSize labelSize = label.frame.size;
    CGSize badgeSize = CGSizeMake(labelSize.width + 10.0f, 18.0f);
    background.frame = CGRectMake(0.0f, 0.0f, badgeSize.width, badgeSize.height);
    label.frame = CGRectMake(5.0f, CGFloor((badgeSize.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    badge.frame = CGRectMake(0.0f, 0.0f, badgeSize.width, badgeSize.height);
    return badge;
}

- (TGRichNode *)textNodeForText:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style before:(CGFloat)before after:(CGFloat)after
{
    NSMutableDictionary *anchors = [[NSMutableDictionary alloc] init];
    TGModernTextViewModel *model = [self textModelForText:text style:style anchors:anchors];
    if (model == nil && anchors.count == 0)
        return nil;
    TGRichNode *node = [[TGRichNode alloc] init];
    node.kind = TGRichNodeText;
    node.textModel = model;
    node.anchors = anchors;
    node.spacingBefore = before;
    node.spacingAfter = after;
    node.fontSize = style.size;
    return node;
}

- (TGRichNode *)captionNodeForBlock:(TGRichMessageBlock *)block node:(TGRichNode *)node
{
    CGFloat F = [self fontSize];
    node.secondaryModel = [self textModelForText:block.caption style:[self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary] anchors:nil];
    node.tertiaryModel = [self textModelForText:block.credit style:[self styleWithSize:F - 4.0f bold:false italic:true color:TGRichMessageColorSecondary] anchors:nil];
    return node;
}

- (TGVideoMediaAttachment *)videoForDocument:(TGDocumentMediaAttachment *)document caption:(NSString *)caption loop:(bool)loop
{
    TGVideoMediaAttachment *video = [[TGVideoMediaAttachment alloc] init];
    video.videoId = document.documentId;
    video.accessHash = document.accessHash;
    video.thumbnailInfo = document.thumbnailInfo;
    video.originInfo = document.originInfo;
    video.caption = caption;
    video.loopVideo = loop;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]])
        {
            video.duration = ((TGDocumentAttributeVideo *)attribute).duration;
            video.dimensions = ((TGDocumentAttributeVideo *)attribute).size;
        }
    }
    TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
    [videoInfo addVideoWithQuality:1 url:[[NSString alloc] initWithFormat:@"video:%lld:%lld:%d:%d", document.documentId, document.accessHash, document.datacenterId, document.size] size:document.size];
    video.videoInfo = videoInfo;
    return video;
}

- (TGRichNode *)mediaNodeForBlock:(TGRichMessageBlock *)block path:(NSString *)path compact:(bool)compact
{
    CGFloat radius = compact ? (_theme.branded ? 4.0f : 6.0f) : [self mediaCornerRadius];
    TGRichNode *node = [[TGRichNode alloc] init];
    node.kind = TGRichNodeMedia;
    node.block = block;
    node.key = path;
    node.mediaCornerRadius = radius;
    node.spacingBefore = 10.0f;
    node.spacingAfter = 10.0f;
    NSString *caption = [block.caption plainText];

    switch (block.kind)
    {
        case TGRichMessageBlockKindPhoto:
        {
            TGImageMediaAttachment *photo = [_richMessage photoWithId:block.identifier];
            CGSize size = CGSizeZero;
            [photo.imageInfo imageUrlForLargestSize:&size];
            node.mediaSize = size;
            node.hiddenMedia = (block.flags & TGRichMessageBlockFlagPhotoSpoiler) && ![self isKeyToggled:path];
            if (photo != nil && !node.hiddenMedia)
                node.imageModel = [self imageModelForPhoto:photo cornerRadius:radius];
            if (block.string.length != 0)
            {
                node.action = @"url";
                node.payload = block.string;
            }
            else if (photo != nil)
            {
                TGImageMediaAttachment *mediaWithCaption = [photo copy];
                mediaWithCaption.caption = caption;
                node.action = @"media";
                node.payload = @(_galleryMedias.count);
                [_galleryMedias addObject:[[TGInstantPageMedia alloc] initWithIndex:(NSInteger)_galleryMedias.count media:mediaWithCaption groupedId:0]];
            }
            break;
        }
        case TGRichMessageBlockKindVideo:
        {
            TGDocumentMediaAttachment *document = [_richMessage documentWithId:block.identifier];
            CGSize size = [document pictureSize];
            int32_t duration = 0;
            for (id attribute in document.attributes)
            {
                if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]])
                {
                    size = ((TGDocumentAttributeVideo *)attribute).size;
                    duration = ((TGDocumentAttributeVideo *)attribute).duration;
                }
            }
            node.mediaSize = size;
            node.hiddenMedia = (block.flags & TGRichMessageBlockFlagVideoSpoiler) && ![self isKeyToggled:path];
            if (document != nil && !node.hiddenMedia)
            {
                node.imageModel = [self imageModelForDocument:document cornerRadius:radius];
                [node.imageModel setManualProgress:true];
                [node.imageModel setPlay];
                if (!compact && duration > 0)
                {
                    node.badgeModel = [self badgeModelWithText:TGRichMessageDurationString(duration)];
                    [node.imageModel addSubmodel:node.badgeModel];
                }
            }
            if (document != nil)
            {
                node.action = @"media";
                node.payload = @(_galleryMedias.count);
                [_galleryMedias addObject:[[TGInstantPageMedia alloc] initWithIndex:(NSInteger)_galleryMedias.count media:[self videoForDocument:document caption:caption loop:(block.flags & TGRichMessageBlockFlagVideoLoop) != 0] groupedId:0]];
            }
            break;
        }
        case TGRichMessageBlockKindMap:
        {
            node.mediaSize = block.size.width > 0.0f && block.size.height > 0.0f ? block.size : CGSizeMake(16.0f, 10.0f);
            double latitude = block.latitude;
            double longitude = block.longitude;
            int32_t zoom = block.zoom;
            node.imageModel = [self imageModelWithCornerRadius:0.0f identifier:[[NSString alloc] initWithFormat:@"rich-map-%f-%f-%d", latitude, longitude, (int)zoom] generator:^SSignal *(CGSize size, __unused void (^pixelProcessingBlock)(void *, int, int, int))
            {
                NSString *uri = [[NSString alloc] initWithFormat:@"map-thumbnail://?latitude=%f&longitude=%f&width=%d&height=%d&flat=1&cornerRadius=%d", latitude, longitude, (int)size.width, (int)size.height, (int)radius];
                return [TGRichMessageInlineImageStore imageSignalForUri:uri];
            }];
            node.action = @"url";
            node.payload = [[NSString alloc] initWithFormat:@"https://maps.google.com/maps?q=%f,%f&z=%d", latitude, longitude, (int)MAX(1, zoom)];
            break;
        }
        case TGRichMessageBlockKindEmbed:
        {
            TGImageMediaAttachment *poster = [_richMessage photoWithId:block.identifier];
            CGSize posterSize = CGSizeZero;
            [poster.imageInfo imageUrlForLargestSize:&posterSize];
            node.mediaSize = block.size.width > 0.0f && block.size.height > 0.0f ? block.size : posterSize;
            if (poster != nil)
            {
                node.imageModel = [self imageModelForPhoto:poster cornerRadius:radius];
                [node.imageModel setManualProgress:true];
                if (block.string.length != 0)
                    [node.imageModel setPlay];
                else
                    [node.imageModel setNone];
            }
            if (block.string.length != 0)
            {
                node.action = @"url";
                node.payload = block.string;
            }
            break;
        }
        default:
            break;
    }

    if (!compact)
        [self captionNodeForBlock:block node:node];
    return node;
}

- (TGRichNode *)fileNodeForBlock:(TGRichMessageBlock *)block
{
    CGFloat F = [self fontSize];
    TGDocumentMediaAttachment *document = [_richMessage documentWithId:block.identifier];
    TGRichNode *node = [[TGRichNode alloc] init];
    node.kind = TGRichNodeFile;
    node.block = block;
    node.spacingBefore = 10.0f;
    node.spacingAfter = 10.0f;

    NSString *title = nil;
    NSString *subtitle = nil;
    bool isAudio = false;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            TGDocumentAttributeAudio *audio = attribute;
            isAudio = true;
            if (audio.performer.length != 0 && audio.title.length != 0)
                title = [[NSString alloc] initWithFormat:@"%@ – %@", audio.performer, audio.title];
            else if (audio.title.length != 0)
                title = audio.title;
            else if (audio.performer.length != 0)
                title = audio.performer;
            if (audio.duration > 0)
                subtitle = TGRichMessageDurationString(audio.duration);
        }
    }
    if (title.length == 0)
        title = [document fileName];
    if (title.length == 0)
        title = TGLocalized(isAudio ? @"Message.Audio" : @"Message.File");
    if (document != nil && document.size > 0)
        subtitle = subtitle.length != 0 ? [[NSString alloc] initWithFormat:@"%@, %@", subtitle, TGRichMessageSizeString(document.size)] : TGRichMessageSizeString(document.size);

    TGRichMessageTextStyle *titleStyle = [self styleWithSize:F - 1.0f bold:true italic:false color:TGRichMessageColorPrimary];
    titleStyle.maxNumberOfLines = 1;
    node.textModel = [self textModelForString:title style:titleStyle];
    TGRichMessageTextStyle *subtitleStyle = [self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary];
    subtitleStyle.maxNumberOfLines = 1;
    node.models = subtitle.length != 0 ? @[[self textModelForString:subtitle style:subtitleStyle]] : @[];
    node.checked = isAudio;

    NSString *extension = [[[document fileName] pathExtension] uppercaseString];
    if (extension.length > 4)
        extension = [extension substringToIndex:4];
    node.fileExtension = extension;

    if (document != nil)
    {
        if (isAudio)
        {
            node.action = @"audio";
            node.payload = @(_audioDocuments.count);
            [_audioDocuments addObject:document];
        }
        else
        {
            node.action = @"document";
            node.payload = document;
        }
    }
    [self captionNodeForBlock:block node:node];
    return node;
}

- (NSArray *)listItemNodesForBlock:(TGRichMessageBlock *)block path:(NSString *)path
{
    CGFloat F = [self fontSize];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    bool ordered = block.kind == TGRichMessageBlockKindOrderedList;
    bool reversed = (block.flags & TGRichMessageBlockFlagOrderedListReversed) != 0;
    NSInteger start = (block.flags & TGRichMessageBlockFlagOrderedListHasStart) ? block.start : (reversed ? (NSInteger)block.items.count : 1);
    NSInteger index = 0;
    for (TGRichMessageListItem *item in block.items)
    {
        TGRichNode *node = [[TGRichNode alloc] init];
        node.kind = TGRichNodeListItem;
        node.fontSize = F;
        node.spacingBefore = 3.0f;
        node.spacingAfter = 3.0f;
        NSString *itemPath = [[NSString alloc] initWithFormat:@"%@.%d", path, (int)index];
        if (item.flags & TGRichMessageListItemFlagCheckbox)
        {
            node.markerKind = TGRichMarkerCheckbox;
            node.checked = (item.flags & TGRichMessageListItemFlagChecked) != 0;
        }
        else if (ordered)
        {
            node.markerKind = TGRichMarkerNumber;
            NSString *number = item.number;
            if (number.length == 0)
            {
                NSInteger value = (item.flags & TGRichMessageListItemFlagHasValue) ? item.value : (reversed ? start - index : start + index);
                number = TGRichMessageFormatNumber(value, item.numberingType.length != 0 ? item.numberingType : block.string);
            }
            TGRichMessageTextStyle *numberStyle = [self styleWithSize:F bold:false italic:false color:TGRichMessageColorPrimary];
            numberStyle.alignment = NSTextAlignmentRight;
            TGModernTextViewModel *numberModel = [self textModelForString:[number stringByAppendingString:@"."] style:numberStyle];
            node.models = numberModel == nil ? @[] : @[numberModel];
        }
        else
            node.markerKind = TGRichMarkerBullet;

        if (item.text != nil)
        {
            TGRichNode *textNode = [self textNodeForText:item.text style:[self styleWithSize:F bold:false italic:false color:TGRichMessageColorPrimary] before:0.0f after:0.0f];
            node.children = textNode == nil ? @[] : @[textNode];
        }
        else
            node.children = [self nodesForBlocks:item.blocks path:itemPath];
        [items addObject:node];
        index++;
    }
    return items;
}

- (TGRichNode *)tableNodeForBlock:(TGRichMessageBlock *)block
{
    CGFloat F = [self fontSize];
    TGRichNode *node = [[TGRichNode alloc] init];
    node.kind = TGRichNodeTable;
    node.block = block;
    node.flags = block.flags;
    node.spacingBefore = 10.0f;
    node.spacingAfter = 10.0f;
    TGRichMessageTextStyle *titleStyle = [self styleWithSize:F - 1.0f bold:true italic:false color:TGRichMessageColorPrimary];
    titleStyle.alignment = NSTextAlignmentCenter;
    node.textModel = [self textModelForText:block.text style:titleStyle anchors:nil];

    NSMutableArray *cells = [[NSMutableArray alloc] init];
    NSInteger rowCount = MIN((NSInteger)block.rows.count, (NSInteger)256);
    NSInteger maximumColumns = 64;
    NSInteger maximumCells = 2048;
    bool *occupied = rowCount > 0 ? (bool *)calloc((size_t)(rowCount * maximumColumns), sizeof(bool)) : NULL;
    for (NSInteger rowIndex = 0; rowIndex < rowCount && occupied != NULL; rowIndex++)
    {
        NSArray *row = block.rows[rowIndex];
        NSInteger column = 0;
        for (TGRichMessageTableCell *cell in row)
        {
            while (column < maximumColumns && occupied[rowIndex * maximumColumns + column])
                column++;
            if (column >= maximumColumns || (NSInteger)cells.count >= maximumCells)
                break;
            TGRichTableCellInfo *info = [[TGRichTableCellInfo alloc] init];
            info.cell = cell;
            info.row = rowIndex;
            info.column = column;
            info.rowspan = MAX(1, MIN((NSInteger)cell.rowspan, rowCount - rowIndex));
            info.colspan = MAX(1, MIN((NSInteger)cell.colspan, maximumColumns - column));
            bool header = (cell.flags & TGRichMessageTableCellFlagHeader) != 0;
            TGRichMessageTextStyle *style = [self styleWithSize:F - 1.5f bold:header italic:false color:TGRichMessageColorPrimary];
            if (cell.flags & TGRichMessageTableCellFlagAlignCenter)
                style.alignment = NSTextAlignmentCenter;
            else if (cell.flags & TGRichMessageTableCellFlagAlignRight)
                style.alignment = NSTextAlignmentRight;
            info.model = [self textModelForText:cell.text style:style anchors:nil];
            for (NSInteger r = 0; r < info.rowspan; r++)
            {
                for (NSInteger c = 0; c < info.colspan; c++)
                    occupied[(rowIndex + r) * maximumColumns + column + c] = true;
            }
            [cells addObject:info];
            column += info.colspan;
        }
    }
    if (occupied != NULL)
        free(occupied);
    node.cells = cells;
    return node;
}

- (TGRichNode *)detailsNodeWithTitle:(TGRichMessageText *)title blocks:(NSArray *)blocks open:(bool)open path:(NSString *)path thinking:(bool)thinking text:(TGRichMessageText *)thinkingText
{
    CGFloat F = [self fontSize];
    TGRichNode *node = [[TGRichNode alloc] init];
    node.kind = TGRichNodeDetails;
    node.key = path;
    node.expanded = open;
    node.spacingBefore = 10.0f;
    node.spacingAfter = 10.0f;
    TGRichMessageTextStyle *titleStyle = [self styleWithSize:F bold:true italic:false color:thinking ? TGRichMessageColorSecondary : TGRichMessageColorPrimary];
    if (title != nil)
        node.textModel = [self textModelForText:title style:titleStyle anchors:nil];
    if (node.textModel == nil)
        node.textModel = [self textModelForString:TGLocalized(thinking ? @"RichMessage.Thinking" : @"RichMessage.ShowMore") style:titleStyle];
    if (open)
    {
        if (thinking)
        {
            TGRichNode *textNode = [self textNodeForText:thinkingText style:[self styleWithSize:F - 1.0f bold:false italic:true color:TGRichMessageColorSecondary] before:0.0f after:0.0f];
            node.children = textNode == nil ? @[] : @[textNode];
        }
        else
            node.children = [self nodesForBlocks:blocks path:path];
    }
    return node;
}

- (NSArray *)nodesForBlocks:(NSArray *)blocks path:(NSString *)path
{
    NSMutableArray *nodes = [[NSMutableArray alloc] init];
    NSInteger index = -1;
    for (TGRichMessageBlock *block in blocks)
    {
        index++;
        NSString *blockPath = [[NSString alloc] initWithFormat:@"%@.%d", path, (int)index];
        NSArray *created = [self nodesForBlock:block path:blockPath];
        if (created.count != 0)
            [nodes addObjectsFromArray:created];
    }
    return nodes;
}

- (NSArray *)nodesForBlock:(TGRichMessageBlock *)block path:(NSString *)path
{
    CGFloat F = [self fontSize];
    TGRichNode *node = nil;
    switch (block.kind)
    {
        case TGRichMessageBlockKindTitle:
            node = [self textNodeForText:block.text style:[self styleWithSize:F + 5.0f bold:true italic:false color:TGRichMessageColorPrimary] before:2.0f after:6.0f];
            break;
        case TGRichMessageBlockKindSubtitle:
            node = [self textNodeForText:block.text style:[self styleWithSize:F + 1.0f bold:false italic:false color:TGRichMessageColorSecondary] before:2.0f after:6.0f];
            break;
        case TGRichMessageBlockKindHeading:
        {
            CGFloat sizes[] = {F + 4.0f, F + 2.0f, F + 1.0f, F, F - 1.0f, F - 2.0f};
            int32_t level = MAX(1, MIN(6, block.level));
            node = [self textNodeForText:block.text style:[self styleWithSize:sizes[level - 1] bold:true italic:false color:level == 6 ? TGRichMessageColorSecondary : TGRichMessageColorPrimary] before:level <= 2 ? 14.0f : 11.0f after:4.0f];
            break;
        }
        case TGRichMessageBlockKindKicker:
            node = [self textNodeForText:block.text style:[self styleWithSize:F - 3.0f bold:true italic:false color:TGRichMessageColorAccent] before:8.0f after:2.0f];
            break;
        case TGRichMessageBlockKindParagraph:
            node = [self textNodeForText:block.text style:[self styleWithSize:F bold:false italic:false color:TGRichMessageColorPrimary] before:8.0f after:8.0f];
            break;
        case TGRichMessageBlockKindFooter:
            node = [self textNodeForText:block.text style:[self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary] before:8.0f after:4.0f];
            break;
        case TGRichMessageBlockKindAuthorDate:
        {
            NSMutableArray *parts = [[NSMutableArray alloc] init];
            if (block.text != nil && ![block.text isEmpty])
                [parts addObject:block.text];
            if (block.date != 0)
            {
                if (parts.count != 0)
                    [parts addObject:[TGRichMessageText plainText:@" • "]];
                NSString *date = [TGRichMessageTextEnvironment formattedDate:block.date flags:TGRichMessageDateFlagLongDate];
                [parts addObject:[TGRichMessageText plainText:date ?: @""]];
            }
            TGRichMessageText *text = [[TGRichMessageText alloc] initWithKind:TGRichMessageTextKindConcat string:nil texts:parts identifier:0 value:0 flags:0 size:CGSizeZero button:nil];
            node = [self textNodeForText:text style:[self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary] before:2.0f after:8.0f];
            break;
        }
        case TGRichMessageBlockKindUnsupported:
            node = [self textNodeForText:[TGRichMessageText plainText:TGLocalized(@"RichMessage.Unsupported")] style:[self styleWithSize:F - 2.0f bold:false italic:true color:TGRichMessageColorSecondary] before:8.0f after:8.0f];
            break;
        case TGRichMessageBlockKindPreformatted:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeCode;
            node.block = block;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            TGRichMessageTextStyle *codeStyle = [self styleWithSize:CGFloor(F * 0.84f) bold:false italic:false color:TGRichMessageColorPrimary];
            codeStyle.mono = true;
            codeStyle.codeBlock = true;
            node.textModel = [self textModelForText:block.text style:codeStyle anchors:nil];
            TGRichMessageTextStyle *languageStyle = [self styleWithSize:F - 4.0f bold:true italic:false color:TGRichMessageColorSecondary];
            languageStyle.maxNumberOfLines = 1;
            node.secondaryModel = [self textModelForString:block.string style:languageStyle];
            node.payload = [block.text plainText] ?: @"";
            node.key = path;
            break;
        }
        case TGRichMessageBlockKindDivider:
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeDivider;
            node.spacingBefore = 6.0f;
            node.spacingAfter = 6.0f;
            break;
        case TGRichMessageBlockKindAnchor:
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeAnchor;
            node.anchorName = block.string;
            break;
        case TGRichMessageBlockKindList:
        case TGRichMessageBlockKindOrderedList:
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeList;
            node.block = block;
            node.spacingBefore = 8.0f;
            node.spacingAfter = 8.0f;
            node.children = [self listItemNodesForBlock:block path:path];
            break;
        case TGRichMessageBlockKindBlockquote:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeQuote;
            node.key = path;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            node.collapsible = (block.flags & TGRichMessageBlockFlagBlockquoteCollapsed) != 0;
            node.expanded = !node.collapsible || [self isKeyToggled:path];
            TGRichMessageTextStyle *style = [self styleWithSize:F bold:false italic:false color:TGRichMessageColorPrimary];
            if (!node.expanded)
                style.maxNumberOfLines = 3;
            TGRichNode *textNode = [self textNodeForText:block.text style:style before:0.0f after:0.0f];
            node.children = textNode == nil ? @[] : @[textNode];
            node.secondaryModel = [self textModelForText:block.secondaryText style:[self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary] anchors:nil];
            break;
        }
        case TGRichMessageBlockKindBlockquoteBlocks:
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeQuote;
            node.key = path;
            node.expanded = true;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            node.children = [self nodesForBlocks:block.blocks path:path];
            node.secondaryModel = [self textModelForText:block.secondaryText style:[self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary] anchors:nil];
            break;
        case TGRichMessageBlockKindPullquote:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodePullquote;
            node.spacingBefore = 12.0f;
            node.spacingAfter = 12.0f;
            TGRichMessageTextStyle *style = [self styleWithSize:F + 1.0f bold:false italic:true color:TGRichMessageColorPrimary];
            style.alignment = NSTextAlignmentCenter;
            node.textModel = [self textModelForText:block.text style:style anchors:nil];
            TGRichMessageTextStyle *captionStyle = [self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary];
            captionStyle.alignment = NSTextAlignmentCenter;
            node.secondaryModel = [self textModelForText:block.secondaryText style:captionStyle anchors:nil];
            break;
        }
        case TGRichMessageBlockKindPhoto:
        case TGRichMessageBlockKindVideo:
        case TGRichMessageBlockKindMap:
            node = [self mediaNodeForBlock:block path:path compact:false];
            break;
        case TGRichMessageBlockKindEmbed:
        {
            if ([_richMessage photoWithId:block.identifier] != nil)
                node = [self mediaNodeForBlock:block path:path compact:false];
            else
            {
                node = [[TGRichNode alloc] init];
                node.kind = TGRichNodeCard;
                node.spacingBefore = 10.0f;
                node.spacingAfter = 10.0f;
                NSURL *url = block.string.length != 0 ? [NSURL URLWithString:block.string] : nil;
                NSString *title = url.host.length != 0 ? url.host : TGLocalized(@"RichMessage.Embed");
                TGRichMessageTextStyle *titleStyle = [self styleWithSize:F - 1.0f bold:true italic:false color:TGRichMessageColorAccent];
                titleStyle.maxNumberOfLines = 1;
                node.textModel = [self textModelForString:title style:titleStyle];
                if (block.string.length != 0)
                {
                    TGRichMessageTextStyle *urlStyle = [self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary];
                    urlStyle.maxNumberOfLines = 2;
                    node.models = @[[self textModelForString:block.string style:urlStyle]];
                    node.action = @"url";
                    node.payload = block.string;
                }
                else
                    node.models = @[];
                [self captionNodeForBlock:block node:node];
            }
            break;
        }
        case TGRichMessageBlockKindCollage:
        case TGRichMessageBlockKindSlideshow:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeGrid;
            node.block = block;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            NSMutableArray *children = [[NSMutableArray alloc] init];
            NSInteger index = 0;
            for (TGRichMessageBlock *item in block.blocks)
            {
                if (item.kind == TGRichMessageBlockKindPhoto || item.kind == TGRichMessageBlockKindVideo)
                    [children addObject:[self mediaNodeForBlock:item path:[[NSString alloc] initWithFormat:@"%@.%d", path, (int)index] compact:block.blocks.count > 1]];
                index++;
            }
            node.children = children;
            [self captionNodeForBlock:block node:node];
            break;
        }
        case TGRichMessageBlockKindCover:
            return [self nodesForBlocks:block.blocks path:path];
        case TGRichMessageBlockKindAudio:
        case TGRichMessageBlockKindDocument:
        {
            TGDocumentMediaAttachment *document = [_richMessage documentWithId:block.identifier];
            bool isVideo = false;
            for (id attribute in document.attributes)
            {
                if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]])
                    isVideo = true;
            }
            if (isVideo && block.kind == TGRichMessageBlockKindDocument)
            {
                TGRichMessageBlock *videoBlock = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindVideo];
                videoBlock.identifier = block.identifier;
                videoBlock.caption = block.caption;
                videoBlock.credit = block.credit;
                node = [self mediaNodeForBlock:videoBlock path:path compact:false];
            }
            else
                node = [self fileNodeForBlock:block];
            break;
        }
        case TGRichMessageBlockKindTable:
            node = [self tableNodeForBlock:block];
            break;
        case TGRichMessageBlockKindDetails:
        {
            bool open = ((block.flags & TGRichMessageBlockFlagDetailsOpen) != 0) != [self isKeyToggled:path];
            node = [self detailsNodeWithTitle:block.text blocks:block.blocks open:open path:path thinking:false text:nil];
            break;
        }
        case TGRichMessageBlockKindThinking:
            node = [self detailsNodeWithTitle:nil blocks:nil open:[self isKeyToggled:path] path:path thinking:true text:block.text];
            break;
        case TGRichMessageBlockKindRelatedArticles:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeArticles;
            node.spacingBefore = 12.0f;
            node.spacingAfter = 10.0f;
            node.textModel = [self textModelForText:block.text style:[self styleWithSize:F bold:true italic:false color:TGRichMessageColorPrimary] anchors:nil];
            NSMutableArray *children = [[NSMutableArray alloc] init];
            for (TGRichMessageRelatedArticle *article in block.articles)
            {
                TGRichNode *articleNode = [[TGRichNode alloc] init];
                articleNode.kind = TGRichNodeArticle;
                TGRichMessageTextStyle *titleStyle = [self styleWithSize:F - 1.0f bold:true italic:false color:TGRichMessageColorPrimary];
                titleStyle.maxNumberOfLines = 2;
                articleNode.textModel = [self textModelForString:article.title.length != 0 ? article.title : article.url style:titleStyle];
                TGRichMessageTextStyle *descriptionStyle = [self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary];
                descriptionStyle.maxNumberOfLines = 2;
                NSString *description = article.articleDescription;
                if (description.length == 0 && article.author.length != 0)
                    description = article.author;
                articleNode.secondaryModel = [self textModelForString:description style:descriptionStyle];
                TGImageMediaAttachment *photo = [_richMessage photoWithId:article.photoId];
                if (photo != nil)
                    articleNode.imageModel = [self imageModelForPhoto:photo cornerRadius:4.0f];
                articleNode.action = @"url";
                articleNode.payload = article.url;
                [children addObject:articleNode];
            }
            node.children = children;
            break;
        }
        case TGRichMessageBlockKindEmbedPost:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeEmbedPost;
            node.block = block;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            TGRichMessageTextStyle *authorStyle = [self styleWithSize:F - 1.0f bold:true italic:false color:TGRichMessageColorPrimary];
            authorStyle.maxNumberOfLines = 1;
            node.textModel = [self textModelForString:block.secondaryString style:authorStyle];
            NSString *date = block.date != 0 ? [TGRichMessageTextEnvironment formattedDate:block.date flags:TGRichMessageDateFlagLongDate] : nil;
            TGRichMessageTextStyle *dateStyle = [self styleWithSize:F - 3.0f bold:false italic:false color:TGRichMessageColorSecondary];
            dateStyle.maxNumberOfLines = 1;
            node.models = date.length != 0 ? @[[self textModelForString:date style:dateStyle]] : @[];
            TGImageMediaAttachment *avatar = [_richMessage photoWithId:block.identifier];
            if (avatar != nil)
                node.imageModel = [self imageModelForPhoto:avatar cornerRadius:14.0f];
            node.children = [self nodesForBlocks:block.blocks path:path];
            [self captionNodeForBlock:block node:node];
            if (block.string.length != 0)
            {
                node.action = @"url";
                node.payload = block.string;
            }
            break;
        }
        case TGRichMessageBlockKindChannel:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeChannel;
            node.block = block;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            TGRichMessageTextStyle *titleStyle = [self styleWithSize:F bold:true italic:false color:TGRichMessageColorPrimary];
            titleStyle.maxNumberOfLines = 1;
            node.textModel = [self textModelForString:block.string.length != 0 ? block.string : @"Telegram" style:titleStyle];
            TGRichMessageTextStyle *buttonStyle = [self styleWithSize:F - 4.0f bold:true italic:false color:TGRichMessageColorAccent];
            buttonStyle.maxNumberOfLines = 1;
            node.secondaryModel = [self textModelForString:TGLocalized(@"Conversation.ViewChannel") style:buttonStyle];
            node.action = @"channel";
            node.payload = block;
            break;
        }
        case TGRichMessageBlockKindMath:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeMath;
            node.mathSource = block.string;
            node.spacingBefore = 10.0f;
            node.spacingAfter = 10.0f;
            node.fontSize = F + 1.0f;
            break;
        }
        case TGRichMessageBlockKindButtonRow:
        {
            node = [[TGRichNode alloc] init];
            node.kind = TGRichNodeButtons;
            node.block = block;
            node.flags = block.flags;
            node.spacingBefore = 8.0f;
            node.spacingAfter = 8.0f;
            NSMutableArray *models = [[NSMutableArray alloc] init];
            NSMutableArray *buttons = [[NSMutableArray alloc] init];
            for (TGRichMessageButton *button in block.buttons)
            {
                TGRichMessageColorKind colorKind = TGRichMessageColorAccent;
                if (button.style & (TGRichMessageButtonStylePrimary | TGRichMessageButtonStyleDanger | TGRichMessageButtonStyleSuccess))
                    colorKind = TGRichMessageColorInverted;
                else if (_theme.branded && !(button.style & TGRichMessageButtonStyleLink))
                    colorKind = TGRichMessageColorPrimary;
                TGRichMessageTextStyle *style = [self styleWithSize:F - 1.0f bold:true italic:false color:colorKind];
                style.alignment = NSTextAlignmentCenter;
                style.maxNumberOfLines = 1;
                TGModernTextViewModel *model = [self textModelForText:button.text style:style anchors:nil];
                if (model == nil)
                    model = [self textModelForString:@" " style:style];
                [models addObject:model];
                [buttons addObject:button];
            }
            node.models = models;
            node.payload = buttons;
            break;
        }
    }
    return node == nil ? @[] : @[node];
}

#pragma mark - Layout

- (void)addDecoration:(TGRichDecorationKind)kind rect:(CGRect)rect
{
    [_decorations addObject:[TGRichDecoration decorationWithKind:kind rect:rect]];
}

- (TGRichDecoration *)addDecorationObject:(TGRichDecorationKind)kind rect:(CGRect)rect
{
    TGRichDecoration *decoration = [TGRichDecoration decorationWithKind:kind rect:rect];
    [_decorations addObject:decoration];
    return decoration;
}

- (void)addHitRegion:(CGRect)rect action:(NSString *)action payload:(id)payload
{
    if (action == nil)
        return;
    TGRichHitRegion *region = [[TGRichHitRegion alloc] init];
    region.rect = rect;
    region.action = action;
    region.payload = payload;
    [_hitRegions addObject:region];
}

- (CGSize)layoutTextModel:(TGModernTextViewModel *)model width:(CGFloat)width
{
    if (model == nil)
        return CGSizeZero;
    [model layoutForContainerSize:CGSizeMake(MAX(1.0f, width), CGFLOAT_MAX)];
    return model.frame.size;
}

- (void)placeTextModel:(TGModernTextViewModel *)model x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    if (model == nil)
        return;
    CGSize size = model.frame.size;
    CGFloat originX = x;
    if (model.alignment == NSTextAlignmentCenter)
        originX = x + CGFloor((width - size.width) / 2.0f);
    else if (model.alignment == NSTextAlignmentRight)
        originX = x + width - size.width;
    model.frame = CGRectMake(originX, y, size.width, size.height);
}

- (CGFloat)firstBaselineForFontSize:(CGFloat)size
{
    UIFont *font = [_theme fontWithSize:size bold:false italic:false mono:false];
    return CGFloor(font.ascender - font.descender);
}

- (CGFloat)layoutNodes:(NSArray *)nodes x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    CGFloat currentY = y;
    TGRichNode *previous = nil;
    for (TGRichNode *node in nodes)
    {
        if (node.kind == TGRichNodeAnchor)
        {
            if (node.anchorName.length != 0 && _anchorOffsets[node.anchorName] == nil)
                _anchorOffsets[node.anchorName] = @(currentY);
            continue;
        }
        if (previous != nil)
            currentY += MAX(previous.spacingAfter, node.spacingBefore);
        CGFloat height = [self layoutNode:node x:x y:currentY width:width];
        currentY += height;
        previous = node;
    }
    return currentY - y;
}

- (CGFloat)layoutCaptionsForNode:(TGRichNode *)node x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    CGFloat currentY = y;
    if (node.secondaryModel != nil)
    {
        currentY += 5.0f;
        [self layoutTextModel:node.secondaryModel width:width];
        [self placeTextModel:node.secondaryModel x:x y:currentY width:width];
        currentY += node.secondaryModel.frame.size.height;
    }
    if (node.tertiaryModel != nil)
    {
        currentY += 2.0f;
        [self layoutTextModel:node.tertiaryModel width:width];
        [self placeTextModel:node.tertiaryModel x:x y:currentY width:width];
        currentY += node.tertiaryModel.frame.size.height;
    }
    return currentY - y;
}

- (void)placeImageModel:(TGSignalImageViewModel *)model frame:(CGRect)frame
{
    if (model == nil)
        return;
    model.frame = frame;
    model.transitionContentRect = CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height);
}

- (CGFloat)layoutMediaNode:(TGRichNode *)node x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)fixedHeight
{
    CGSize natural = node.mediaSize;
    if (natural.width <= 0.0f || natural.height <= 0.0f)
        natural = CGSizeMake(16.0f, 10.0f);
    CGFloat mediaHeight = fixedHeight;
    if (mediaHeight <= 0.0f)
    {
        mediaHeight = CGFloor(width * natural.height / natural.width);
        mediaHeight = MIN(MAX(mediaHeight, 60.0f), MAX(width * 1.25f, 180.0f));
    }
    CGRect mediaRect = CGRectMake(x, y, width, mediaHeight);
    TGRichDecoration *frameDecoration = [self addDecorationObject:node.hiddenMedia ? TGRichDecorationMediaSpoiler : TGRichDecorationMediaFrame rect:mediaRect];
    frameDecoration.value = node.mediaCornerRadius;
    if (node.hiddenMedia)
    {
        frameDecoration.object = fixedHeight > 0.0f ? nil : TGLocalized(@"RichMessage.TapToReveal");
        [self addHitRegion:mediaRect action:@"toggle" payload:node.key];
    }
    else
    {
        [self placeImageModel:node.imageModel frame:mediaRect];
        if (node.badgeModel != nil)
        {
            CGSize badgeSize = node.badgeModel.frame.size;
            node.badgeModel.frame = CGRectMake(6.0f, mediaHeight - badgeSize.height - 6.0f, badgeSize.width, badgeSize.height);
        }
        [self addHitRegion:mediaRect action:node.action payload:node.payload];
    }
    if (fixedHeight > 0.0f)
        return mediaHeight;
    return mediaHeight + [self layoutCaptionsForNode:node x:x y:y + mediaHeight width:width];
}

- (CGFloat)layoutTableNode:(TGRichNode *)node x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    CGFloat currentY = y;
    if (node.textModel != nil)
    {
        [self layoutTextModel:node.textModel width:width];
        [self placeTextModel:node.textModel x:x y:currentY width:width];
        currentY += node.textModel.frame.size.height + 6.0f;
    }

    NSArray *cells = node.cells;
    if (cells.count == 0)
        return currentY - y;

    bool compact = (node.flags & TGRichMessageBlockFlagTableCompact) != 0;
    bool bordered = (node.flags & TGRichMessageBlockFlagTableBordered) != 0;
    bool striped = (node.flags & TGRichMessageBlockFlagTableStriped) != 0;
    CGFloat padding = compact ? 4.0f : 7.0f;
    CGFloat F = [self fontSize];

    NSInteger columns = 0;
    NSInteger rows = 0;
    for (TGRichTableCellInfo *info in cells)
    {
        columns = MAX(columns, info.column + info.colspan);
        rows = MAX(rows, info.row + info.rowspan);
    }

    NSMutableArray *natural = [[NSMutableArray alloc] init];
    NSMutableArray *minimum = [[NSMutableArray alloc] init];
    for (NSInteger column = 0; column < columns; column++)
    {
        [natural addObject:@(padding * 2.0f + 4.0f)];
        [minimum addObject:@(padding * 2.0f + F * 1.6f)];
    }
    for (TGRichTableCellInfo *info in cells)
    {
        if (info.colspan != 1 || info.model == nil)
            continue;
        CGFloat naturalWidth = [self layoutTextModel:info.model width:10000.0f].width + padding * 2.0f + 1.0f;
        natural[info.column] = @(MAX([natural[info.column] floatValue], naturalWidth));
    }

    CGFloat naturalTotal = 0.0f;
    CGFloat minimumTotal = 0.0f;
    for (NSInteger column = 0; column < columns; column++)
    {
        naturalTotal += [natural[column] floatValue];
        minimumTotal += MIN([natural[column] floatValue], [minimum[column] floatValue]);
    }

    NSMutableArray *widths = [[NSMutableArray alloc] init];
    if (naturalTotal <= width)
    {
        CGFloat extra = width - naturalTotal;
        for (NSInteger column = 0; column < columns; column++)
        {
            CGFloat value = [natural[column] floatValue];
            [widths addObject:@(CGFloor(value + extra * value / MAX(1.0f, naturalTotal)))];
        }
    }
    else
    {
        CGFloat available = MAX(width - minimumTotal, 0.0f);
        CGFloat flexible = 0.0f;
        for (NSInteger column = 0; column < columns; column++)
            flexible += MAX(0.0f, [natural[column] floatValue] - MIN([natural[column] floatValue], [minimum[column] floatValue]));
        for (NSInteger column = 0; column < columns; column++)
        {
            CGFloat base = MIN([natural[column] floatValue], [minimum[column] floatValue]);
            CGFloat share = flexible > 0.0f ? (MAX(0.0f, [natural[column] floatValue] - base) / flexible) * available : 0.0f;
            [widths addObject:@(CGFloor(minimumTotal > width ? width / (CGFloat)columns : base + share))];
        }
    }
    CGFloat usedWidth = 0.0f;
    for (NSNumber *value in widths)
        usedWidth += value.floatValue;
    if (columns > 0 && usedWidth < width)
        widths[columns - 1] = @([widths[columns - 1] floatValue] + width - usedWidth);

    NSMutableArray *columnOffsets = [[NSMutableArray alloc] init];
    CGFloat offset = 0.0f;
    for (NSInteger column = 0; column < columns; column++)
    {
        [columnOffsets addObject:@(offset)];
        offset += [widths[column] floatValue];
    }
    [columnOffsets addObject:@(offset)];

    NSMutableArray *rowHeights = [[NSMutableArray alloc] init];
    for (NSInteger row = 0; row < rows; row++)
        [rowHeights addObject:@(padding * 2.0f + CGFloor(F * 1.2f))];
    for (TGRichTableCellInfo *info in cells)
    {
        CGFloat cellWidth = [columnOffsets[info.column + info.colspan] floatValue] - [columnOffsets[info.column] floatValue];
        CGFloat height = padding * 2.0f + [self layoutTextModel:info.model width:cellWidth - padding * 2.0f].height;
        if (info.rowspan == 1)
            rowHeights[info.row] = @(MAX([rowHeights[info.row] floatValue], height));
    }
    for (TGRichTableCellInfo *info in cells)
    {
        if (info.rowspan <= 1)
            continue;
        CGFloat cellWidth = [columnOffsets[info.column + info.colspan] floatValue] - [columnOffsets[info.column] floatValue];
        CGFloat height = padding * 2.0f + [self layoutTextModel:info.model width:cellWidth - padding * 2.0f].height;
        CGFloat spanned = 0.0f;
        for (NSInteger row = info.row; row < info.row + info.rowspan; row++)
            spanned += [rowHeights[row] floatValue];
        if (height > spanned)
        {
            NSInteger lastRow = info.row + info.rowspan - 1;
            rowHeights[lastRow] = @([rowHeights[lastRow] floatValue] + height - spanned);
        }
    }

    NSMutableArray *rowOffsets = [[NSMutableArray alloc] init];
    CGFloat rowOffset = 0.0f;
    for (NSInteger row = 0; row < rows; row++)
    {
        [rowOffsets addObject:@(rowOffset)];
        rowOffset += [rowHeights[row] floatValue];
    }
    [rowOffsets addObject:@(rowOffset)];

    CGRect tableRect = CGRectMake(x, currentY, width, rowOffset);
    for (TGRichTableCellInfo *info in cells)
    {
        CGFloat cellX = x + [columnOffsets[info.column] floatValue];
        CGFloat cellY = currentY + [rowOffsets[info.row] floatValue];
        CGFloat cellWidth = [columnOffsets[info.column + info.colspan] floatValue] - [columnOffsets[info.column] floatValue];
        CGFloat cellHeight = [rowOffsets[info.row + info.rowspan] floatValue] - [rowOffsets[info.row] floatValue];
        CGRect cellRect = CGRectMake(cellX, cellY, cellWidth, cellHeight);
        bool header = (info.cell.flags & TGRichMessageTableCellFlagHeader) != 0;
        if (header || (striped && info.row % 2 == 1))
        {
            TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationTableCell rect:cellRect];
            decoration.flags = header ? TGRichDecorationFlagHeader : TGRichDecorationFlagStripe;
            decoration.clipRect = tableRect;
        }
        if (info.model != nil)
        {
            CGSize size = info.model.frame.size;
            CGFloat textY = cellY + padding;
            if (info.cell.flags & TGRichMessageTableCellFlagVerticalAlignMiddle)
                textY = cellY + CGFloor((cellHeight - size.height) / 2.0f);
            else if (info.cell.flags & TGRichMessageTableCellFlagVerticalAlignBottom)
                textY = cellY + cellHeight - padding - size.height;
            [self placeTextModel:info.model x:cellX + padding y:textY width:cellWidth - padding * 2.0f];
        }
    }

    for (NSInteger row = 1; row < rows; row++)
    {
        CGFloat lineY = currentY + [rowOffsets[row] floatValue];
        for (TGRichTableCellInfo *info in cells)
        {
            if (info.row != row)
                continue;
            CGFloat cellX = x + [columnOffsets[info.column] floatValue];
            CGFloat cellWidth = [columnOffsets[info.column + info.colspan] floatValue] - [columnOffsets[info.column] floatValue];
            [self addDecoration:TGRichDecorationTableLine rect:CGRectMake(cellX, lineY, cellWidth, 1.0f)];
        }
    }
    if (bordered)
    {
        for (TGRichTableCellInfo *info in cells)
        {
            if (info.column == 0)
                continue;
            CGFloat lineX = x + [columnOffsets[info.column] floatValue];
            CGFloat cellY = currentY + [rowOffsets[info.row] floatValue];
            CGFloat cellHeight = [rowOffsets[info.row + info.rowspan] floatValue] - [rowOffsets[info.row] floatValue];
            TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationTableLine rect:CGRectMake(lineX, cellY, 1.0f, cellHeight)];
            decoration.flags = TGRichDecorationFlagVertical;
        }
    }
    if (bordered)
        [self addDecoration:TGRichDecorationTableBorder rect:tableRect];

    return currentY + rowOffset - y;
}

- (CGFloat)layoutNode:(TGRichNode *)node x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    CGFloat F = [self fontSize];
    switch (node.kind)
    {
        case TGRichNodeText:
        {
            for (NSString *name in node.anchors)
            {
                if (_anchorOffsets[name] == nil)
                    _anchorOffsets[name] = @(y);
            }
            if (node.textModel == nil)
                return 0.0f;
            [self layoutTextModel:node.textModel width:width];
            [self placeTextModel:node.textModel x:x y:y width:width];
            return node.textModel.frame.size.height;
        }
        case TGRichNodeCode:
        {
            CGFloat padding = 10.0f;
            CGFloat header = MAX(26.0f, CGFloor(F * 1.7f));
            CGSize textSize = [self layoutTextModel:node.textModel width:width - padding * 2.0f];
            CGFloat height = header + 7.0f + textSize.height + 9.0f;
            TGRichDecoration *panel = [self addDecorationObject:TGRichDecorationCodePanel rect:CGRectMake(x, y, width, height)];
            panel.value = header;
            if (node.secondaryModel != nil)
            {
                CGSize labelSize = [self layoutTextModel:node.secondaryModel width:width - padding * 2.0f - 30.0f];
                node.secondaryModel.frame = CGRectMake(x + padding, y + CGFloor((header - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
            }
            CGFloat iconSide = 16.0f;
            CGRect iconRect = CGRectMake(x + width - padding - iconSide, y + CGFloor((header - iconSide) / 2.0f), iconSide, iconSide);
            TGRichDecoration *icon = [self addDecorationObject:TGRichDecorationCopyIcon rect:iconRect];
            if ([self isKeyToggled:[@"copied:" stringByAppendingString:node.key ?: @""]])
                icon.flags = TGRichDecorationFlagChecked;
            [self addHitRegion:CGRectMake(x + width - 54.0f, y, 54.0f, header) action:@"copy" payload:@[node.payload ?: @"", node.key ?: @""]];
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(x + padding, y + header + 7.0f, textSize.width, textSize.height);
            return height;
        }
        case TGRichNodeDivider:
        {
            [self addDecoration:TGRichDecorationDivider rect:CGRectMake(x + CGFloor(width * 0.2f), y + 4.0f, CGFloor(width * 0.6f), 1.0f)];
            return 9.0f;
        }
        case TGRichNodeAnchor:
            return 0.0f;
        case TGRichNodeList:
        {
            CGFloat gutter = CGFloor(F * 1.15f);
            for (TGRichNode *item in node.children)
            {
                if (item.markerKind == TGRichMarkerNumber && item.models.count != 0)
                    gutter = MAX(gutter, [self layoutTextModel:item.models[0] width:200.0f].width + 7.0f);
                else if (item.markerKind == TGRichMarkerCheckbox)
                    gutter = MAX(gutter, CGFloor(F * 1.45f));
            }
            return [self layoutListItems:node.children x:x y:y width:width gutter:gutter];
        }
        case TGRichNodeQuote:
        {
            CGFloat inset = 12.0f;
            CGFloat rightInset = 22.0f;
            CGFloat contentY = y + 6.0f;
            CGFloat contentHeight = [self layoutNodes:node.children x:x + inset y:contentY width:width - inset - rightInset];
            CGFloat captionHeight = [self layoutCaptionsForNode:node x:x + inset y:contentY + contentHeight width:width - inset - rightInset];
            CGFloat height = 6.0f + contentHeight + captionHeight + (node.collapsible ? 16.0f : 7.0f);
            CGRect rect = CGRectMake(x, y, width, height);
            [_decorations insertObject:[TGRichDecoration decorationWithKind:TGRichDecorationQuote rect:rect] atIndex:0];
            [self addDecoration:TGRichDecorationQuoteIcon rect:CGRectMake(x + width - 17.0f, y + 5.0f, 12.0f, 11.0f)];
            if (node.collapsible)
            {
                TGRichDecoration *chevron = [self addDecorationObject:TGRichDecorationChevron rect:CGRectMake(x + width - 18.0f, y + height - 14.0f, 10.0f, 8.0f)];
                chevron.flags = node.expanded ? TGRichDecorationFlagExpanded : 0;
                [self addHitRegion:rect action:@"toggle" payload:node.key];
            }
            return height;
        }
        case TGRichNodePullquote:
        {
            CGFloat inset = 18.0f;
            CGFloat currentY = y + 8.0f;
            if (node.textModel != nil)
            {
                [self layoutTextModel:node.textModel width:width - inset * 2.0f];
                [self placeTextModel:node.textModel x:x + inset y:currentY width:width - inset * 2.0f];
                currentY += node.textModel.frame.size.height;
            }
            currentY += [self layoutCaptionsForNode:node x:x + inset y:currentY width:width - inset * 2.0f];
            currentY += 8.0f;
            [self addDecoration:TGRichDecorationPullquote rect:CGRectMake(x, y, width, currentY - y)];
            return currentY - y;
        }
        case TGRichNodeMedia:
            return [self layoutMediaNode:node x:x y:y width:width height:0.0f];
        case TGRichNodeGrid:
        {
            NSInteger count = (NSInteger)node.children.count;
            CGFloat currentY = y;
            if (count == 1)
                currentY += [self layoutMediaNode:node.children[0] x:x y:y width:width height:0.0f];
            else if (count > 1)
            {
                NSInteger columns = (count == 2 || count == 4) ? 2 : 3;
                CGFloat gap = 2.0f;
                CGFloat side = CGFloor((width - gap * (CGFloat)(columns - 1)) / (CGFloat)columns);
                NSInteger index = 0;
                for (TGRichNode *child in node.children)
                {
                    NSInteger row = index / columns;
                    NSInteger column = index % columns;
                    CGFloat cellWidth = column == columns - 1 ? width - (side + gap) * (CGFloat)(columns - 1) : side;
                    [self layoutMediaNode:child x:x + (side + gap) * (CGFloat)column y:y + (side + gap) * (CGFloat)row width:cellWidth height:side];
                    index++;
                }
                NSInteger rows = (count + columns - 1) / columns;
                currentY += side * (CGFloat)rows + gap * (CGFloat)(rows - 1);
            }
            currentY += [self layoutCaptionsForNode:node x:x y:currentY width:width];
            return currentY - y;
        }
        case TGRichNodeFile:
        {
            CGFloat iconSide = 40.0f;
            CGFloat rowHeight = 44.0f;
            CGRect iconRect = CGRectMake(x, y + 2.0f, iconSide, iconSide);
            if (node.checked)
                [self addDecoration:TGRichDecorationAudioButton rect:iconRect];
            else
            {
                TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationFileIcon rect:iconRect];
                decoration.object = node.fileExtension;
            }
            CGFloat textX = x + iconSide + 10.0f;
            CGFloat textWidth = width - iconSide - 10.0f;
            CGSize titleSize = [self layoutTextModel:node.textModel width:textWidth];
            CGSize subtitleSize = node.models.count != 0 ? [self layoutTextModel:node.models[0] width:textWidth] : CGSizeZero;
            CGFloat totalHeight = titleSize.height + (subtitleSize.height > 0.0f ? subtitleSize.height + 1.0f : 0.0f);
            CGFloat textY = y + CGFloor((rowHeight - totalHeight) / 2.0f);
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(textX, textY, titleSize.width, titleSize.height);
            if (node.models.count != 0)
                ((TGModernTextViewModel *)node.models[0]).frame = CGRectMake(textX, textY + titleSize.height + 1.0f, subtitleSize.width, subtitleSize.height);
            [self addHitRegion:CGRectMake(x, y, width, rowHeight) action:node.action payload:node.payload];
            return rowHeight + [self layoutCaptionsForNode:node x:x y:y + rowHeight width:width];
        }
        case TGRichNodeTable:
            return [self layoutTableNode:node x:x y:y width:width];
        case TGRichNodeDetails:
        {
            CGFloat insetX = _theme.branded ? 10.0f : 4.0f;
            CGSize titleSize = [self layoutTextModel:node.textModel width:width - insetX * 2.0f - 22.0f];
            CGFloat header = MAX(CGFloor(F * 2.2f), titleSize.height + 14.0f);
            CGRect headerRect = CGRectMake(x, y, width, header);
            [self addDecoration:TGRichDecorationDetailsHeader rect:headerRect];
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(x + insetX, y + CGFloor((header - titleSize.height) / 2.0f), titleSize.width, titleSize.height);
            TGRichDecoration *chevron = [self addDecorationObject:TGRichDecorationChevron rect:CGRectMake(x + width - insetX - 12.0f, y + CGFloor((header - 8.0f) / 2.0f), 12.0f, 8.0f)];
            chevron.flags = node.expanded ? TGRichDecorationFlagExpanded : 0;
            [self addHitRegion:headerRect action:@"toggle" payload:node.key];
            CGFloat currentY = y + header;
            if (node.expanded && node.children.count != 0)
            {
                currentY += 8.0f;
                currentY += [self layoutNodes:node.children x:x + insetX y:currentY width:width - insetX * 2.0f];
                currentY += 6.0f;
                [self addDecoration:TGRichDecorationSeparator rect:CGRectMake(x, currentY, width, 1.0f)];
                currentY += 1.0f;
            }
            return currentY - y;
        }
        case TGRichNodeEmbedPost:
        {
            CGFloat inset = 12.0f;
            CGFloat currentY = y + 6.0f;
            CGFloat contentX = x + inset;
            CGFloat contentWidth = width - inset - 6.0f;
            CGFloat headerHeight = 0.0f;
            CGFloat textX = contentX;
            if (node.imageModel != nil)
            {
                CGRect avatarRect = CGRectMake(contentX, currentY, 28.0f, 28.0f);
                TGRichDecoration *frame = [self addDecorationObject:TGRichDecorationMediaFrame rect:avatarRect];
                frame.value = 14.0f;
                [self placeImageModel:node.imageModel frame:avatarRect];
                textX += 36.0f;
                headerHeight = 28.0f;
            }
            CGSize authorSize = [self layoutTextModel:node.textModel width:contentX + contentWidth - textX];
            CGSize dateSize = node.models.count != 0 ? [self layoutTextModel:node.models[0] width:contentX + contentWidth - textX] : CGSizeZero;
            CGFloat textHeight = authorSize.height + dateSize.height;
            CGFloat textY = currentY + MAX(0.0f, CGFloor((headerHeight - textHeight) / 2.0f));
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(textX, textY, authorSize.width, authorSize.height);
            if (node.models.count != 0)
                ((TGModernTextViewModel *)node.models[0]).frame = CGRectMake(textX, textY + authorSize.height, dateSize.width, dateSize.height);
            headerHeight = MAX(headerHeight, textHeight);
            if (headerHeight > 0.0f)
                [self addHitRegion:CGRectMake(x, y, width, headerHeight + 6.0f) action:node.action payload:node.payload];
            currentY += headerHeight;
            if (node.children.count != 0)
            {
                currentY += headerHeight > 0.0f ? 8.0f : 0.0f;
                currentY += [self layoutNodes:node.children x:contentX y:currentY width:contentWidth];
            }
            currentY += [self layoutCaptionsForNode:node x:contentX y:currentY width:contentWidth];
            currentY += 7.0f;
            [_decorations insertObject:[TGRichDecoration decorationWithKind:TGRichDecorationQuote rect:CGRectMake(x, y, width, currentY - y)] atIndex:0];
            return currentY - y;
        }
        case TGRichNodeChannel:
        {
            CGFloat height = 44.0f;
            [self addDecoration:TGRichDecorationCard rect:CGRectMake(x, y, width, height)];
            CGSize buttonSize = [self layoutTextModel:node.secondaryModel width:width / 2.0f];
            CGRect buttonRect = CGRectMake(x + width - buttonSize.width - 26.0f, y + 8.0f, buttonSize.width + 18.0f, height - 16.0f);
            TGRichDecoration *button = [self addDecorationObject:TGRichDecorationButton rect:buttonRect];
            button.value = 0.0f;
            if (node.secondaryModel != nil)
                node.secondaryModel.frame = CGRectMake(buttonRect.origin.x + 9.0f, buttonRect.origin.y + CGFloor((buttonRect.size.height - buttonSize.height) / 2.0f), buttonSize.width, buttonSize.height);
            CGSize titleSize = [self layoutTextModel:node.textModel width:buttonRect.origin.x - x - 18.0f];
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(x + 10.0f, y + CGFloor((height - titleSize.height) / 2.0f), titleSize.width, titleSize.height);
            [self addHitRegion:CGRectMake(x, y, width, height) action:node.action payload:node.payload];
            return height;
        }
        case TGRichNodeArticles:
        {
            CGFloat currentY = y;
            if (node.textModel != nil)
            {
                [self layoutTextModel:node.textModel width:width];
                [self placeTextModel:node.textModel x:x y:currentY width:width];
                currentY += node.textModel.frame.size.height + 4.0f;
            }
            for (TGRichNode *article in node.children)
            {
                [self addDecoration:TGRichDecorationSeparator rect:CGRectMake(x, currentY, width, 1.0f)];
                CGFloat rowY = currentY + 7.0f;
                CGFloat imageSide = article.imageModel != nil ? 48.0f : 0.0f;
                CGFloat textWidth = width - (imageSide > 0.0f ? imageSide + 10.0f : 0.0f);
                CGSize titleSize = [self layoutTextModel:article.textModel width:textWidth];
                CGSize descriptionSize = [self layoutTextModel:article.secondaryModel width:textWidth];
                if (article.textModel != nil)
                    article.textModel.frame = CGRectMake(x, rowY, titleSize.width, titleSize.height);
                if (article.secondaryModel != nil)
                    article.secondaryModel.frame = CGRectMake(x, rowY + titleSize.height + 2.0f, descriptionSize.width, descriptionSize.height);
                CGFloat rowHeight = MAX(imageSide, titleSize.height + (descriptionSize.height > 0.0f ? descriptionSize.height + 2.0f : 0.0f));
                if (article.imageModel != nil)
                {
                    CGRect imageRect = CGRectMake(x + width - imageSide, rowY, imageSide, imageSide);
                    TGRichDecoration *frame = [self addDecorationObject:TGRichDecorationMediaFrame rect:imageRect];
                    frame.value = 4.0f;
                    [self placeImageModel:article.imageModel frame:imageRect];
                }
                [self addHitRegion:CGRectMake(x, currentY, width, rowHeight + 14.0f) action:article.action payload:article.payload];
                currentY = rowY + rowHeight + 7.0f;
            }
            return currentY - y;
        }
        case TGRichNodeMath:
        {
            if (node.math == nil || ABS(node.mathWidth - width) > FLT_EPSILON)
            {
                CGFloat size = node.fontSize;
                TGRichMessageMathLayout *math = [TGRichMessageMathLayout layoutWithSource:node.mathSource fontSize:size display:true];
                if (math.width > width && math.width > 0.0f)
                    math = [TGRichMessageMathLayout layoutWithSource:node.mathSource fontSize:MAX(8.0f, CGFloor(size * width / math.width)) display:true];
                node.math = math;
                node.mathWidth = width;
            }
            TGRichMessageMathLayout *math = node.math;
            TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationMath rect:CGRectMake(x + MAX(0.0f, CGFloor((width - math.width) / 2.0f)), y + 4.0f, math.width, math.ascent + math.descent)];
            decoration.object = math;
            return math.ascent + math.descent + 8.0f;
        }
        case TGRichNodeButtons:
            return [self layoutButtonsNode:node x:x y:y width:width];
        case TGRichNodeCard:
        {
            CGFloat padding = 10.0f;
            CGFloat currentY = y + padding;
            CGSize titleSize = [self layoutTextModel:node.textModel width:width - padding * 2.0f];
            if (node.textModel != nil)
                node.textModel.frame = CGRectMake(x + padding, currentY, titleSize.width, titleSize.height);
            currentY += titleSize.height;
            if (node.models.count != 0)
            {
                CGSize urlSize = [self layoutTextModel:node.models[0] width:width - padding * 2.0f];
                ((TGModernTextViewModel *)node.models[0]).frame = CGRectMake(x + padding, currentY + 2.0f, urlSize.width, urlSize.height);
                currentY += urlSize.height + 2.0f;
            }
            currentY += padding;
            [_decorations insertObject:[TGRichDecoration decorationWithKind:TGRichDecorationCard rect:CGRectMake(x, y, width, currentY - y)] atIndex:0];
            [self addHitRegion:CGRectMake(x, y, width, currentY - y) action:node.action payload:node.payload];
            currentY += [self layoutCaptionsForNode:node x:x y:currentY width:width];
            return currentY - y;
        }
        case TGRichNodeListItem:
        case TGRichNodeArticle:
            return 0.0f;
    }
    return 0.0f;
}

- (CGFloat)layoutListItems:(NSArray *)items x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width gutter:(CGFloat)gutter
{
    CGFloat currentY = y;
    TGRichNode *previous = nil;
    for (TGRichNode *item in items)
    {
        if (previous != nil)
            currentY += MAX(previous.spacingAfter, item.spacingBefore);
        CGFloat contentHeight = [self layoutNodes:item.children x:x + gutter y:currentY width:width - gutter];
        CGFloat F = item.fontSize;
        CGFloat baseline = currentY + [self firstBaselineForFontSize:F];
        switch (item.markerKind)
        {
            case TGRichMarkerBullet:
            {
                CGFloat diameter = MAX(4.0f, CGFloor(F * 0.33f));
                [self addDecoration:TGRichDecorationBullet rect:CGRectMake(x + CGFloor(gutter * 0.4f - diameter / 2.0f), CGFloor(baseline - F * 0.33f - diameter / 2.0f), diameter, diameter)];
                break;
            }
            case TGRichMarkerNumber:
            {
                TGModernTextViewModel *model = item.models.count != 0 ? item.models[0] : nil;
                if (model != nil)
                {
                    CGSize size = [self layoutTextModel:model width:gutter];
                    model.frame = CGRectMake(x + gutter - 6.0f - size.width, currentY, size.width, size.height);
                }
                break;
            }
            case TGRichMarkerCheckbox:
            {
                CGFloat side = CGFloor(F * 1.0f);
                TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationCheckbox rect:CGRectMake(x + CGFloor((gutter - side) / 2.0f) - 2.0f, CGFloor(baseline - F * 0.36f - side / 2.0f), side, side)];
                decoration.flags = item.checked ? TGRichDecorationFlagChecked : 0;
                break;
            }
        }
        currentY += MAX(contentHeight, CGFloor(F * 1.2f));
        previous = item;
    }
    return currentY - y;
}

- (CGFloat)layoutButtonsNode:(TGRichNode *)node x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
{
    NSArray *models = node.models;
    NSArray *buttons = node.payload;
    NSInteger count = (NSInteger)models.count;
    if (count == 0)
        return 0.0f;
    CGFloat F = [self fontSize];
    CGFloat height = MAX(32.0f, CGFloor(F * 2.1f));
    CGFloat gap = 6.0f;
    bool aligned = (node.flags & (TGRichMessageBlockFlagButtonRowLeft | TGRichMessageBlockFlagButtonRowCenter | TGRichMessageBlockFlagButtonRowRight)) != 0;
    NSMutableArray *widths = [[NSMutableArray alloc] init];
    CGFloat total = 0.0f;
    if (aligned)
    {
        for (TGModernTextViewModel *model in models)
        {
            CGFloat buttonWidth = MIN(width, [self layoutTextModel:model width:width - 24.0f].width + 28.0f);
            [widths addObject:@(buttonWidth)];
            total += buttonWidth;
        }
        total += gap * (CGFloat)(count - 1);
    }
    if (!aligned || total > width)
    {
        [widths removeAllObjects];
        CGFloat buttonWidth = CGFloor((width - gap * (CGFloat)(count - 1)) / (CGFloat)count);
        for (NSInteger index = 0; index < count; index++)
            [widths addObject:@(index == count - 1 ? width - (buttonWidth + gap) * (CGFloat)(count - 1) : buttonWidth)];
        total = width;
    }
    CGFloat currentX = x;
    if (node.flags & TGRichMessageBlockFlagButtonRowCenter)
        currentX = x + CGFloor((width - total) / 2.0f);
    else if (node.flags & TGRichMessageBlockFlagButtonRowRight)
        currentX = x + width - total;
    for (NSInteger index = 0; index < count; index++)
    {
        CGFloat buttonWidth = [widths[index] floatValue];
        CGRect rect = CGRectMake(currentX, y, buttonWidth, height);
        TGRichMessageButton *button = index < (NSInteger)buttons.count ? buttons[index] : nil;
        TGRichDecoration *decoration = [self addDecorationObject:TGRichDecorationButton rect:rect];
        decoration.value = button.style;
        TGModernTextViewModel *model = models[index];
        CGSize size = [self layoutTextModel:model width:buttonWidth - 16.0f];
        model.frame = CGRectMake(currentX + CGFloor((buttonWidth - size.width) / 2.0f), y + CGFloor((height - size.height) / 2.0f), size.width, size.height);
        if (button != nil && button.action != TGRichMessageButtonActionDisabled)
            [self addHitRegion:rect action:@"button" payload:button];
        currentX += buttonWidth + gap;
    }
    return height;
}

- (void)performLayoutWithWidth:(CGFloat)width
{
    _decorations = [[NSMutableArray alloc] init];
    _hitRegions = [[NSMutableArray alloc] init];
    _anchorOffsets = [[NSMutableDictionary alloc] init];
    CGFloat height = [self layoutNodes:_nodes x:0.0f y:0.0f width:width];
    _contentHeight = CGCeil(MAX(height, 1.0f));
    _layoutWidth = width;
    _layoutValid = true;
    _decorationModel.decorations = _decorations;
    _decorationModel.frame = CGRectMake(0.0f, 0.0f, width, _contentHeight);
}

- (CGSize)contentSizeForContainerSize:(CGSize)containerSize needsContentsUpdate:(bool *)needsContentsUpdate infoWidth:(CGFloat)__unused infoWidth
{
    CGFloat width = CGFloor(containerSize.width);
    if (!_layoutValid || ABS(width - _layoutWidth) > FLT_EPSILON)
    {
        [self performLayoutWithWidth:width];
        if (needsContentsUpdate != NULL)
            *needsContentsUpdate = true;
    }
    CGSize size = CGSizeMake(_layoutWidth, _contentHeight);
    if ([TGPresentation brandedIOS6Style])
    {
        if (![self brandedReactionsShareTimeRow])
            size.height += [TGPresentation brandedIOS6ConversationAppearance].bubbleTimeRowHeight;
    }
    else
        size.height += 16.0f;
    size.height += 2.0f;
    return size;
}

- (void)applyContainerOrigin:(CGPoint)origin
{
    _container.frame = CGRectMake(origin.x, origin.y, _layoutWidth, _contentHeight);
    UIView *contentView = [NSThread isMainThread] ? [_contentModel boundView] : nil;
    for (TGSignalImageViewModel *model in _imageModels)
    {
        if (model.boundView != nil)
        {
            model.parentOffset = CGPointMake(origin.x + _imageBindingOffset.x, origin.y + _imageBindingOffset.y);
            model.frame = model.frame;
        }
        else
        {
            model.parentOffset = origin;
            if (contentView != nil && !CGRectIsEmpty(model.frame))
                [model bindViewToContainer:contentView viewStorage:_viewStorage];
        }
    }
}

- (void)layoutContentForHeaderHeight:(CGFloat)headerHeight containerSize:(CGSize)__unused containerSize
{
    [self applyContainerOrigin:CGPointMake(1.0f, headerHeight + TGGetMessageViewModelLayoutConstants()->textBubbleTextOffsetTop + 2.0f)];
}

- (void)bindImageModelsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage offset:(CGPoint)offset
{
    if (container == nil)
        return;
    _imageBindingOffset = offset;
    CGPoint origin = CGPointMake(_container.frame.origin.x + offset.x, _container.frame.origin.y + offset.y);
    for (TGSignalImageViewModel *model in _imageModels)
    {
        if (CGRectIsEmpty(model.frame))
            continue;
        if (model.boundView != nil)
            [model unbindView:viewStorage];
        model.parentOffset = origin;
        [model bindViewToContainer:container viewStorage:viewStorage];
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    _viewStorage = viewStorage;
    [super bindViewToContainer:container viewStorage:viewStorage];
    [self bindImageModelsToContainer:[_contentModel boundView] viewStorage:viewStorage offset:CGPointZero];
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    _viewStorage = viewStorage;
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    [self bindImageModelsToContainer:container viewStorage:viewStorage offset:CGPointMake(itemPosition.x + _contentModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y)];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [self clearLinkSelection];
    for (TGSignalImageViewModel *model in _imageModels)
    {
        if (model.boundView != nil)
            [model unbindView:viewStorage];
    }
    [super unbindView:viewStorage];
}

- (void)refreshMetrics
{
    _theme = [[TGRichMessageTheme alloc] initWithContext:_context incoming:_incomingAppearance];
    [self rebuildWithViewStorage:nil];
}

- (void)updateAssets
{
    [super updateAssets];
    CGFloat width = _layoutWidth;
    CGPoint origin = _container.frame.origin;
    _theme = [[TGRichMessageTheme alloc] initWithContext:_context incoming:_incomingAppearance];
    [self rebuildWithViewStorage:_viewStorage];
    [self relayoutWithWidth:width origin:origin];
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];

    TGRichMessage *richMessage = nil;
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGRichMessageMediaAttachment class]])
        {
            richMessage = ((TGRichMessageMediaAttachment *)attachment).richMessage;
            break;
        }
    }

    NSSet *expandedKeys = [_context richMessageExpandedKeysForMessageId:message.mid peerId:message.cid];
    bool contentChanged = richMessage != nil && richMessage != _richMessage && (message.editDate != _editDate || richMessage.blocks.count != _richMessage.blocks.count || ![[richMessage plainText] isEqualToString:[_richMessage plainText]]);
    if (contentChanged || ![expandedKeys isEqualToSet:_expandedKeys])
    {
        if (contentChanged)
        {
            _richMessage = richMessage;
            _editDate = message.editDate;
        }
        _expandedKeys = expandedKeys;
        [self rebuildWithViewStorage:viewStorage];
        [_contentModel setNeedsSubmodelContentsUpdate];
        if (sizeUpdated != NULL)
            *sizeUpdated = true;
    }
}

#pragma mark - Interaction

- (CGPoint)containerPointFromContentPoint:(CGPoint)point
{
    return CGPointMake(point.x - _container.frame.origin.x, point.y - _container.frame.origin.y);
}

- (NSString *)linkAtContainerPoint:(CGPoint)point regionData:(__autoreleasing NSArray **)regionData model:(__autoreleasing TGModernTextViewModel **)outModel linkText:(__autoreleasing NSString **)linkText
{
    for (TGModernTextViewModel *model in _textModels)
    {
        CGRect frame = model.frame;
        if (CGRectIsEmpty(frame) || !CGRectContainsPoint(CGRectInset(frame, -4.0f, -4.0f), point))
            continue;
        NSString *link = [model linkAtPoint:CGPointMake(point.x - frame.origin.x, point.y - frame.origin.y) regionData:regionData hiddenLink:NULL linkText:linkText];
        if (link != nil)
        {
            if (outModel != NULL)
                *outModel = model;
            return link;
        }
    }
    return nil;
}

- (TGRichHitRegion *)hitRegionAtContainerPoint:(CGPoint)point
{
    for (TGRichHitRegion *region in [_hitRegions reverseObjectEnumerator])
    {
        if (CGRectContainsPoint(region.rect, point))
            return region;
    }
    return nil;
}

- (void)setKeyToggled:(NSString *)key
{
    if (key == nil)
        return;
    NSMutableSet *keys = [[NSMutableSet alloc] initWithSet:_expandedKeys ?: [NSSet set]];
    if ([keys containsObject:key])
        [keys removeObject:key];
    else
        [keys addObject:key];
    [self applyExpandedKeys:keys];
}

- (void)applyExpandedKeys:(NSSet *)keys
{
    [_context setRichMessageExpandedKeys:keys forMessageId:_mid peerId:_peerId];
    [_context.companionHandle requestAction:@"richMessageStateChanged" options:@{@"mid": @(_mid), @"peerId": @(_peerId)}];
}

- (UIScrollView *)findScrollView
{
    UIView *superview = [[_contentModel boundView] superview];
    while (superview != nil)
    {
        if ([superview isKindOfClass:[UIScrollView class]])
            return (UIScrollView *)superview;
        superview = [superview superview];
    }
    return nil;
}

- (void)scrollToAnchor:(NSString *)name
{
    NSNumber *offset = _anchorOffsets[name];
    UIView *contentView = [_contentModel boundView];
    UIScrollView *scrollView = [self findScrollView];
    if (offset == nil || contentView == nil || scrollView == nil)
        return;
    CGRect anchorRect = [contentView convertRect:CGRectMake(0.0f, _container.frame.origin.y + offset.floatValue, 1.0f, 1.0f) toView:scrollView];
    UIEdgeInsets insets = scrollView.contentInset;
    bool flipped = scrollView.transform.d < 0.0f;
    CGFloat target = flipped ? CGRectGetMaxY(anchorRect) - scrollView.bounds.size.height + insets.bottom + 8.0f : anchorRect.origin.y - insets.top - 8.0f;
    CGFloat minimum = -insets.top;
    CGFloat maximum = MAX(minimum, scrollView.contentSize.height - scrollView.bounds.size.height + insets.bottom);
    target = MAX(minimum, MIN(maximum, target));
    [scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, target) animated:true];
}

- (void)activateButton:(TGRichMessageButton *)button
{
    if (button == nil)
        return;
    NSString *title = [button.text plainText] ?: @"";
    switch (button.action)
    {
        case TGRichMessageButtonActionUrl:
        case TGRichMessageButtonActionUrlAuth:
        case TGRichMessageButtonActionWebView:
            if (button.string.length != 0)
                [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": button.string, @"mid": @(_mid), @"hidden": @false}];
            break;
        case TGRichMessageButtonActionCallback:
            [_context.companionHandle requestAction:@"activateCommand" options:@{@"command": title, @"action": [[TGBotReplyMarkupButtonActionCallback alloc] initWithData:button.data ?: [NSData data]], @"mid": @(_mid), @"index": @(-1)}];
            break;
        case TGRichMessageButtonActionGame:
            [_context.companionHandle requestAction:@"activateCommand" options:@{@"command": title, @"action": [[TGBotReplyMarkupButtonActionGame alloc] initWithText:title], @"mid": @(_mid), @"index": @(-1)}];
            break;
        case TGRichMessageButtonActionBuy:
            [_context.companionHandle requestAction:@"activateCommand" options:@{@"command": title, @"action": [[TGBotReplyMarkupButtonActionPurchase alloc] initWithText:title], @"mid": @(_mid), @"index": @(-1)}];
            break;
        case TGRichMessageButtonActionSwitchInline:
            [_context.companionHandle requestAction:@"activateCommand" options:@{@"command": title, @"action": [[TGBotReplyMarkupButtonActionSwitchInline alloc] initWithQuery:button.string ?: @"" samePeer:button.samePeer], @"mid": @(_mid), @"index": @(-1)}];
            break;
        case TGRichMessageButtonActionUserProfile:
            if (button.identifier != 0)
                [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": [[NSString alloc] initWithFormat:@"tg-user://%d", (int)TGModernLegacyIdForModernId(button.identifier)], @"mid": @(_mid)}];
            break;
        case TGRichMessageButtonActionCopy:
            if (button.string.length != 0)
                [_context.companionHandle requestAction:@"richMessageCopyText" options:@{@"text": button.string}];
            break;
        default:
            break;
    }
}

- (void)activateLink:(NSString *)link linkText:(NSString *)linkText
{
    if ([link hasPrefix:@"tg-rich-spoiler:"])
    {
        if (![self isKeyToggled:@"spoilers"])
            [self setKeyToggled:@"spoilers"];
        return;
    }
    if ([link hasPrefix:@"tg-rich-copy:"])
    {
        NSString *text = [link substringFromIndex:@"tg-rich-copy:".length];
        if (text.length != 0)
            [_context.companionHandle requestAction:@"richMessageCopyText" options:@{@"text": text}];
        return;
    }
    if ([link hasPrefix:@"tg-rich-button:"])
    {
        NSInteger index = [[link substringFromIndex:@"tg-rich-button:".length] integerValue];
        if (index >= 0 && index < (NSInteger)_environment.buttons.count)
        {
            id button = _environment.buttons[index];
            if ([button isKindOfClass:[TGRichMessageButton class]])
                [self activateButton:button];
        }
        return;
    }
    if ([link hasPrefix:@"#"])
    {
        [self scrollToAnchor:[link substringFromIndex:1]];
        return;
    }
    bool hidden = false;
    if ([link hasPrefix:@"http://"] || [link hasPrefix:@"https://"])
    {
        NSURL *url = [NSURL URLWithString:link];
        NSString *host = url.host;
        if ([host hasPrefix:@"www."])
            host = [host substringFromIndex:4];
        hidden = host.length != 0 && [linkText rangeOfString:host options:NSCaseInsensitiveSearch].location == NSNotFound;
        if ([host isEqualToString:@"t.me"] || [host isEqualToString:@"telegram.me"])
            hidden = false;
    }
    [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": link, @"mid": @(_mid), @"hidden": @(hidden)}];
}

- (void)activateRegion:(TGRichHitRegion *)region
{
    NSString *action = region.action;
    if ([action isEqualToString:@"toggle"])
        [self setKeyToggled:region.payload];
    else if ([action isEqualToString:@"url"])
    {
        NSString *url = region.payload;
        if (url.length != 0)
            [self activateLink:url linkText:url];
    }
    else if ([action isEqualToString:@"media"])
    {
        if (_galleryMedias.count != 0)
            [_context.companionHandle requestAction:@"openRichMessageMedia" options:@{@"medias": [_galleryMedias copy], @"index": region.payload, @"mid": @(_mid)}];
    }
    else if ([action isEqualToString:@"audio"])
    {
        if (_audioDocuments.count != 0)
            [_context.companionHandle requestAction:@"openRichMessageAudio" options:@{@"documents": [_audioDocuments copy], @"index": region.payload}];
    }
    else if ([action isEqualToString:@"document"])
        [_context.companionHandle requestAction:@"openRichMessageDocument" options:@{@"document": region.payload, @"mid": @(_mid)}];
    else if ([action isEqualToString:@"copy"])
    {
        NSArray *payload = region.payload;
        NSString *text = payload.count > 0 ? payload[0] : nil;
        NSString *key = payload.count > 1 ? payload[1] : nil;
        if (text.length != 0)
            [_context.companionHandle requestAction:@"richMessageCopyText" options:@{@"text": text}];
        if (key.length != 0)
        {
            NSString *copiedKey = [@"copied:" stringByAppendingString:key];
            if (![self isKeyToggled:copiedKey])
            {
                NSMutableSet *keys = [[NSMutableSet alloc] initWithSet:_expandedKeys ?: [NSSet set]];
                for (NSString *existing in [keys allObjects])
                {
                    if ([existing hasPrefix:@"copied:"])
                        [keys removeObject:existing];
                }
                [keys addObject:copiedKey];
                [self applyExpandedKeys:keys];
                TGModernViewContext *context = _context;
                int32_t mid = _mid;
                int64_t peerId = _peerId;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
                {
                    NSMutableSet *currentKeys = [[NSMutableSet alloc] initWithSet:[context richMessageExpandedKeysForMessageId:mid peerId:peerId]];
                    if (![currentKeys containsObject:copiedKey])
                        return;
                    [currentKeys removeObject:copiedKey];
                    [context setRichMessageExpandedKeys:currentKeys forMessageId:mid peerId:peerId];
                    [context.companionHandle requestAction:@"richMessageStateChanged" options:@{@"mid": @(mid), @"peerId": @(peerId)}];
                });
            }
        }
    }
    else if ([action isEqualToString:@"button"])
        [self activateButton:region.payload];
    else if ([action isEqualToString:@"channel"])
    {
        TGRichMessageBlock *block = region.payload;
        if (block.secondaryString.length != 0)
            [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": [@"https://t.me/" stringByAppendingString:block.secondaryString], @"mid": @(_mid)}];
        else if (block.identifier != 0)
            [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(block.identifier)}];
    }
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
        return;
    [self clearLinkSelection];
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;

    CGPoint point = [self containerPointFromContentPoint:[recognizer locationInView:[_contentModel boundView]]];
    NSString *linkText = nil;
    NSString *link = [self linkAtContainerPoint:point regionData:NULL model:NULL linkText:&linkText];
    TGRichHitRegion *region = link == nil ? [self hitRegionAtContainerPoint:point] : nil;

    if (recognizer.longTapped)
    {
        if (link != nil && ![link hasPrefix:@"tg-rich-"] && ![link hasPrefix:@"#"])
            [_context.companionHandle requestAction:@"openLinkWithOptionsRequested" options:@{@"url": link}];
        else
            [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    }
    else if (recognizer.doubleTapped)
        [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    else if (link != nil)
        [self activateLink:link linkText:linkText];
    else if (region != nil)
        [self activateRegion:region];
    else
        [super messageDoubleTapGesture:recognizer];
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer shouldFailTap:(CGPoint)__unused point
{
    CGPoint contentPoint = [recognizer locationInView:[_contentModel boundView]];
    CGPoint containerPoint = [self containerPointFromContentPoint:contentPoint];
    if ([self linkAtContainerPoint:containerPoint regionData:NULL model:NULL linkText:NULL] != nil || [self hitRegionAtContainerPoint:containerPoint] != nil)
        return 3;
    if ((_forwardedHeaderModel != nil && CGRectContainsPoint(_forwardedHeaderModel.frame, contentPoint)) || (_replyHeaderModel != nil && CGRectContainsPoint(_replyHeaderModel.frame, contentPoint)) || (_viaUserModel != nil && CGRectContainsPoint(_viaUserModel.frame, contentPoint)))
        return 3;
    return 0;
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)point
{
    if ([self findScrollView].isDecelerating)
        return;
    CGPoint contentPoint = CGPointMake(point.x - (_contentModel.frame.origin.x - _backgroundModel.frame.origin.x), point.y - (_contentModel.frame.origin.y - _backgroundModel.frame.origin.y));
    [self updateLinkSelection:[self containerPointFromContentPoint:contentPoint]];
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    [self clearLinkSelection];
}

- (void)clearHighlights
{
    [self clearLinkSelection];
}

- (void)clearLinkSelection
{
    for (UIView *view in _currentLinkSelectionViews)
        [view removeFromSuperview];
    _currentLinkSelectionViews = nil;
}

- (void)updateLinkSelection:(CGPoint)point
{
    UIView *contentView = [_contentModel boundView];
    if (contentView == nil)
        return;
    [self clearLinkSelection];

    NSMutableArray *rects = [[NSMutableArray alloc] init];
    NSArray *regionData = nil;
    TGModernTextViewModel *model = nil;
    NSString *link = [self linkAtContainerPoint:point regionData:&regionData model:&model linkText:NULL];
    if (link != nil)
    {
        for (NSValue *value in regionData)
        {
            CGRect rect = [value CGRectValue];
            if (!CGRectIsEmpty(rect))
                [rects addObject:[NSValue valueWithCGRect:CGRectOffset(rect, model.frame.origin.x, model.frame.origin.y + 1.0f)]];
        }
    }
    else
    {
        TGRichHitRegion *region = [self hitRegionAtContainerPoint:point];
        if (region != nil)
            [rects addObject:[NSValue valueWithCGRect:region.rect]];
    }

    NSMutableArray *views = [[NSMutableArray alloc] init];
    UIImage *image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
    for (NSValue *value in rects)
    {
        UIImageView *view = [[UIImageView alloc] initWithImage:image];
        view.frame = CGRectOffset([value CGRectValue], _container.frame.origin.x, _container.frame.origin.y);
        [contentView addSubview:view];
        [views addObject:view];
    }
    _currentLinkSelectionViews = views;
}

@end
