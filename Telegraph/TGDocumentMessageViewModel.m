#import "TGImageInfo+Telegraph.h"
#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGDocumentMessageViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGModernRemoteImageViewModel.h"
#import "TGMessageImageViewModel.h"
#import "TGModernImageViewModel.h"
#import "TGModernLabelViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernClockProgressViewModel.h"
#import "TGModernTextViewModel.h"

#import "TGTextMessageBackgroundViewModel.h"

#import "TGMessageImageViewModel.h"
#import "TGMessageImageView.h"
#import "TGDocumentMessageIconModel.h"
#import "TGDocumentMessageIconView.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGReplyHeaderModel.h"

#import "TGSharedMediaFileThumbnailView.h"

#import "TGAppDelegate.h"

#import "TGReusableLabel.h"

#import "TGPresentation.h"
#import "TGMessageGroupedLayout.h"
#import "TGMessageReactionsLayout.h"
#import "TGMessageViewsViewModel.h"
#import "TGModernDateViewModel.h"

@interface TGDocumentMessageViewModel () <TGMessageImageViewDelegate>
{
    NSString *_legacyThumbnailCacheUri;
    bool _mediaIsAvailable;
    bool _progressVisible;
    float _progress;
    
    TGModernTextViewModel *_textModel;
    TGModernLabelViewModel *_documentNameModel;
    TGModernLabelViewModel *_documentSizeModel;
    TGMessageImageViewModel *_imageModel;
    TGDocumentMessageIconModel *_iconModel;
    
    NSString *_titleText;
    NSString *_sizeText;
    
    NSArray *_currentLinkSelectionViews;
    NSArray *_textCheckingResults;
    TGMessage *_documentMessage;
    TGDocumentMediaAttachment *_document;
    NSArray *_suppressedGroupModels;
}

@end

static CTFontRef textFontForSize(CGFloat size)
{
    static CTFontRef font = NULL;
    static int cachedSize = 0;
    
    if ((int)size != cachedSize || font == NULL)
    {
        font = TGCoreTextSystemFontOfSize(size);
        cachedSize = (int)size;
    }
    
    return font;
}

static NSString *TGIOS6DisplayFileNameForDocument(TGDocumentMediaAttachment *document)
{
    NSString *fileName = document.fileName.length == 0 ? @"file" : document.fileName;
    if ([fileName pathExtension].length != 0)
        return fileName;
    
    NSString *mimeType = [document.mimeType lowercaseString];
    bool zipMime = [mimeType isEqualToString:@"application/zip"] || [mimeType isEqualToString:@"application/x-zip-compressed"];
    if (zipMime)
        return [fileName stringByAppendingPathExtension:(document.size > 1024 * 1024 ? @"ipa" : @"zip")];
    
    NSDictionary *mimeExtensions = @{
        @"application/pdf": @"pdf",
        @"application/x-rar-compressed": @"rar",
        @"application/x-7z-compressed": @"7z",
        @"application/gzip": @"gz",
        @"application/x-tar": @"tar",
        @"application/vnd.android.package-archive": @"apk",
        @"application/x-debian-package": @"deb",
        @"application/x-itunes-ipa": @"ipa",
        @"application/octet-stream+ipa": @"ipa",
        @"text/plain": @"txt",
        @"text/html": @"html",
        @"text/css": @"css",
        @"text/javascript": @"js",
        @"application/javascript": @"js",
        @"application/json": @"json",
        @"application/xml": @"xml",
        @"text/xml": @"xml",
        @"image/jpeg": @"jpg",
        @"image/png": @"png",
        @"image/gif": @"gif",
        @"image/webp": @"webp",
        @"audio/mpeg": @"mp3",
        @"audio/mp4": @"m4a",
        @"audio/ogg": @"ogg",
        @"video/mp4": @"mp4",
        @"video/quicktime": @"mov"
    };
    NSString *extension = mimeExtensions[mimeType];
    if (extension.length != 0)
        return [fileName stringByAppendingPathExtension:extension];
    
    bool genericMime = mimeType.length == 0 || [mimeType isEqualToString:@"application/octet-stream"];
    if (genericMime && document.size > 1024 * 1024)
        return [fileName stringByAppendingPathExtension:@"ipa"];
    
    return fileName;
}

static NSString *TGDocumentMessagePreviewUri(TGDocumentMediaAttachment *document, TGMessage *message, NSString *legacyThumbnailCacheUri, CGSize dimensions)
{
    if ((document.documentId == 0 && document.localDocumentId == 0) || (legacyThumbnailCacheUri.length == 0 && !document.isImageFile))
        return nil;

    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"file-thumbnail://?"];
    if (document.documentId != 0)
    {
        [uri appendFormat:@"id=%" PRId64 "&cid=%" PRId64 "&mid=%" PRId32, document.documentId, message.cid, message.mid];
        if (document.originInfo != nil)
            [uri appendFormat:@"&origin_info=%@", [document.originInfo stringRepresentation]];
    }
    else
        [uri appendFormat:@"local-id=%" PRId64, document.localDocumentId];

    [uri appendFormat:@"&file-name=%@", [TGStringUtils stringByEscapingForURL:document.safeFileName]];
    CGSize renderSize = CGSizeMake(86.0f, 86.0f);
    if (dimensions.width > FLT_EPSILON && dimensions.height > FLT_EPSILON)
    {
        CGFloat scale = 86.0f / MIN(dimensions.width, dimensions.height);
        renderSize = CGSizeMake(CGFloor(dimensions.width * scale), CGFloor(dimensions.height * scale));
    }
    [uri appendFormat:@"&width=86&height=86&renderWidth=%d&renderHeight=%d&rounded=1", (int)renderSize.width, (int)renderSize.height];
    if (legacyThumbnailCacheUri.length != 0)
        [uri appendFormat:@"&legacy-thumbnail-cache-url=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailCacheUri]];
    return uri;
}

@implementation TGDocumentMessageViewModel

- (instancetype)initWithMessage:(TGMessage *)message document:(TGDocumentMediaAttachment *)document authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context
{
    self = [super initWithMessage:message authorPeer:authorPeer viaUser:viaUser context:context];
    if (self != nil)
    {
        _documentMessage = message;
        _document = document;
        _textCheckingResults = message.textCheckingResults;
        _authorPeerId = message.fromUid;
        _textCheckingResults = message.textCheckingResults;
        
        CGSize dimensions = CGSizeZero;
        _legacyThumbnailCacheUri = [document.thumbnailInfo imageUrlForPreviewWithSize:&dimensions];
        NSString *filePreviewUri = TGDocumentMessagePreviewUri(document, message, _legacyThumbnailCacheUri, dimensions);
        
        _titleText = TGIOS6DisplayFileNameForDocument(document);
        
        _documentNameModel = [[TGModernLabelViewModel alloc] initWithText:@"" textColor:(!_incomingAppearance && [TGPresentation brandedIOS6Style]) ? [UIColor whiteColor] : (_incomingAppearance ? _context.presentation.pallete.chatIncomingAccentColor : _context.presentation.pallete.chatOutgoingAccentColor) font:TGCoreTextSystemFontOfSize(16.0f) maxWidth:145.0f truncateInTheMiddle:true];
        [_contentModel addSubmodel:_documentNameModel];
        
        NSString *sizeString = @"";
        if (document.size == INT_MAX)
        {
            sizeString = TGLocalized(@"Conversation.Processing");
        }
        else if (document.size >= 1024 * 1024)
        {
            sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Megabytes"), (float)(float)document.size / (1024 * 1024)];
        }
        else if (document.size >= 1024)
        {
            sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Kilobytes"), (int)(int)(document.size / 1024)];
        }
        else
        {
            sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Bytes"), (int)(int)(document.size)];
        }
        
        _sizeText = sizeString;

        _textModel = [[TGModernTextViewModel alloc] initWithText:message.caption font:textFontForSize(TGGetMessageViewModelLayoutConstants()->textFontSize)];
        _textModel.underlineAllLinks = _incomingAppearance ? _context.presentation.pallete.underlineAllIncomingLinks : _context.presentation.pallete.underlineAllOutgoingLinks;
        _textModel.textCheckingResults = _textCheckingResults;
        _textModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingTextColor : _context.presentation.pallete.chatOutgoingTextColor;
        _textModel.linkColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingLinkColor : _context.presentation.pallete.chatOutgoingLinkColor;
        if (message.isBroadcast)
            _textModel.additionalTrailingWidth += 10.0f;
        [_contentModel addSubmodel:_textModel];
        
        _documentSizeModel = [[TGModernLabelViewModel alloc] initWithText:@"" textColor:(!_incomingAppearance && [TGPresentation brandedIOS6Style]) ? [UIColor whiteColor] : (_incomingAppearance ? _context.presentation.pallete.chatIncomingSubtextColor : _context.presentation.pallete.chatOutgoingSubtextColor) font:TGCoreTextSystemFontOfSize(13.0f) maxWidth:145.0f];
        [_contentModel addSubmodel:_documentSizeModel];
        
        [self updateIconWithUri:filePreviewUri];
    }
    return self;
}

- (void)setGroupedLayout:(TGMessageGroupedLayout *)groupedLayout
{
    [super setGroupedLayout:groupedLayout];
    bool primary = groupedLayout.documentGroup && groupedLayout.mainMessageId == _mid;
    _backgroundModel.drawsBubble = !groupedLayout.documentGroup || primary;
    _textModel.text = groupedLayout.documentGroup ? (primary ? groupedLayout.caption : @"") : _documentMessage.caption;
    _textModel.textCheckingResults = groupedLayout.documentGroup ? groupedLayout.captionTextCheckingResults : _documentMessage.textCheckingResults;
    if (groupedLayout.documentGroup) {
        [_reactionsModel updateWithSummary:primary ? groupedLayout.reactionSummary : nil chosenReaction:primary ? groupedLayout.chosenReaction : nil parent:self viewStorage:nil container:[_contentModel boundView].superview];
        if (primary) {
            TGMessage *status = groupedLayout.statusMessage;
            int variant = 0;
            [_dateModel setText:[TGDateUtils stringForShortTime:(int)status.date daytimeVariant:&variant] daytimeVariant:variant];
            _messageViewsModel.count = status.viewCount.viewCount;
            if (status.isEdited && _editedLabelModel == nil) {
                _editedLabelModel = [[TGModernLabelViewModel alloc] initWithText:TGLocalized(@"Conversation.MessageEditedLabel") textColor:_dateModel.textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
                [_contentModel addSubmodel:_editedLabelModel];
            }
        }
    } else {
        [_reactionsModel updateWithMessage:_documentMessage parent:self viewStorage:nil container:[_contentModel boundView].superview];
    }
    [_contentModel setNeedsSubmodelContentsUpdate];
}

- (void)layoutDocumentRowAtOrigin:(CGPoint)origin width:(CGFloat)width
{
    CGFloat nameX = (_imageModel != nil ? 74.0f : 60.0f) + 8.0f;
    [_documentNameModel setText:_titleText maxWidth:MAX(1.0f, width - nameX)];
    [_documentSizeModel setText:_sizeText maxWidth:MAX(1.0f, width - nameX)];
    _documentNameModel.frame = CGRectMake(origin.x - _contentModel.frame.origin.x + nameX, origin.y - _contentModel.frame.origin.y + 3.0f, _documentNameModel.frame.size.width, _documentNameModel.frame.size.height);
    _documentSizeModel.frame = CGRectMake(origin.x - _contentModel.frame.origin.x + nameX, origin.y - _contentModel.frame.origin.y + 28.0f, _documentSizeModel.frame.size.width, _documentSizeModel.frame.size.height);
    _imageModel.frame = CGRectMake(origin.x, origin.y, 74.0f, 74.0f);
    _iconModel.frame = CGRectMake(origin.x, origin.y, 60.0f, 60.0f);
}

- (bool)updateIconWithUri:(NSString *)filePreviewUri
{
    bool rebind = false;
    if (filePreviewUri.length != 0)
    {
        if (_imageModel == nil)
        {
            _imageModel = [[TGMessageImageViewModel alloc] initWithUri:filePreviewUri];
            _imageModel.skipDrawInContext = true;
            _imageModel.timestampHidden = true;
            _imageModel.overlayDiameter = 44.0f;
            _imageModel.frame = CGRectMake(0.0f, 0.0f, 74.0f, 74.0f);
            [self addSubmodel:_imageModel];
            rebind = true;
        }
        _imageModel.hidden = false;
        
        [self removeSubmodel:_iconModel viewStorage:nil];
        _iconModel = nil;
    }
    else
    {
        if (_iconModel == nil)
        {
            _iconModel = [[TGDocumentMessageIconModel alloc] init];
            _iconModel.presentation = _context.presentation;
            _iconModel.skipDrawInContext = true;
            _iconModel.frame = CGRectMake(0.0f, 0.0f, 60.0f, 60.0f);
            _iconModel.fileName = _titleText;
            _iconModel.incoming = _incomingAppearance;
            [self addSubmodel:_iconModel];
            rebind = true;
        }
        _iconModel.hidden = false;
        
        [self removeSubmodel:_imageModel viewStorage:nil];
        _imageModel = nil;
    }
    return rebind;
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    _documentMessage = message;
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];
    
    NSArray *currentTextCheckingResults = nil;
    TGDocumentMediaAttachment *document = nil;
    for (TGMediaAttachment *attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            document = (TGDocumentMediaAttachment *)attachment;
            _document = document;
            currentTextCheckingResults = message.textCheckingResults;
            break;
        }
    }
    
    if (document == nil)
        return;
    
    NSString *sizeString = @"";
    if (document.size == INT_MAX)
    {
        sizeString = TGLocalized(@"Conversation.Processing");
    }
    else if (document.size >= 1024 * 1024)
    {
        sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Megabytes"), (float)(float)document.size / (1024 * 1024)];
    }
    else if (document.size >= 1024)
    {
        sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Kilobytes"), (int)(int)(document.size / 1024)];
    }
    else
    {
        sizeString = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.Bytes"), (int)(int)(document.size)];
    }
    
    if (!TGStringCompare(_textModel.text, message.caption)) {
        _textCheckingResults = currentTextCheckingResults;
        
        _textModel.text = message.caption;
        _textModel.textCheckingResults = currentTextCheckingResults;
        if (sizeUpdated != NULL)
           *sizeUpdated = true;
    }
    
    _sizeText = sizeString;
    _titleText = TGIOS6DisplayFileNameForDocument(document);
    
    bool rebind = false;
    CGSize dimensions = CGSizeZero;
    NSString *newLegacyThumbnailCacheUri = [document.thumbnailInfo imageUrlForPreviewWithSize:&dimensions];
    NSString *previewUri = TGDocumentMessagePreviewUri(document, message, newLegacyThumbnailCacheUri, dimensions);
    if (!TGStringCompare(newLegacyThumbnailCacheUri, _legacyThumbnailCacheUri) || !TGStringCompare(previewUri, _imageModel.uri))
    {
        _titleText = TGIOS6DisplayFileNameForDocument(document);
        
        [_contentModel setNeedsSubmodelContentsUpdate];
        _legacyThumbnailCacheUri = newLegacyThumbnailCacheUri;
        rebind = [self updateImage:document message:message dimensions:dimensions];
        if (sizeUpdated != NULL)
           *sizeUpdated = true;
    }
    
    
    if (rebind) {
        UIView *container = _backgroundModel.boundView.superview;
        [self unbindView:viewStorage];
        
        [self bindViewToContainer:container viewStorage:viewStorage];
        
        [_contentModel setNeedsSubmodelContentsUpdate];
        [_contentModel updateSubmodelContentsIfNeeded];
    }
    
    if (sizeUpdated != NULL)
       *sizeUpdated = true;
    if (self.groupedLayout.documentGroup)
        [self setGroupedLayout:self.groupedLayout];
}

- (bool)updateImage:(TGDocumentMediaAttachment *)document message:(TGMessage *)message dimensions:(CGSize)dimensions
{
    NSString *previewUri = TGDocumentMessagePreviewUri(document, message, _legacyThumbnailCacheUri, dimensions);
    bool rebind = [self updateIconWithUri:previewUri];
    _imageModel.uri = previewUri;
    return rebind;
}

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)__unused viewStorage delayDisplay:(bool)delayDisplay
{   
    [super updateMediaAvailability:mediaIsAvailable viewStorage:viewStorage delayDisplay:delayDisplay];
    
    if (mediaIsAvailable && !_mediaIsAvailable && (OGPlatformMediaDownloadsRequireUserAction() || _legacyThumbnailCacheUri.length == 0))
        [_imageModel reloadImage:false];

    _mediaIsAvailable = mediaIsAvailable;
    
    [self updateImageOverlay:false];
}

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)viewStorage animated:(bool)animated
{
    [super updateProgress:progressVisible progress:progress viewStorage:viewStorage animated:animated];
    
    bool progressWasVisible = _progressVisible;
    float previousProgress = _progress;
    
    _progress = progress;
    _progressVisible = progressVisible;
    
    [self updateImageOverlay:((progressWasVisible && !_progressVisible) || (_progressVisible && ABS(_progress - previousProgress) > FLT_EPSILON)) && animated];
}

- (void)updateImageOverlay:(bool)animated
{
    _imageModel.viewUserInteractionDisabled = (_incoming && _mediaIsAvailable) || !_progressVisible;
    _iconModel.viewUserInteractionDisabled = (_incoming && _mediaIsAvailable) || !_progressVisible;
    
    if (_progressVisible)
    {
        [_imageModel setOverlayType:TGMessageImageViewOverlayProgress animated:false];
        [_imageModel setProgress:_progress animated:animated];
        
        [_iconModel setOverlayType:TGMessageImageViewOverlayProgress animated:false];
        [_iconModel setProgress:_progress animated:animated];
    }
    else if (!_mediaIsAvailable)
    {
        [_imageModel setOverlayType:TGMessageImageViewOverlayDownload animated:false];
        [_imageModel setProgress:0.0f animated:false];
        
        [_iconModel setOverlayType:TGMessageImageViewOverlayDownload animated:false];
        [_iconModel setProgress:0.0f animated:false];
    }
    else
    {
        [_imageModel setOverlayType:TGMessageImageViewOverlayNone animated:animated];
        [_iconModel setOverlayType:TGMessageImageViewOverlayPlay animated:animated];
        
        [_imageModel setProgress:0.0f animated:false];
        [_iconModel setProgress:0.0f animated:false];
    }
}

- (void)imageDataInvalidated:(NSString *)imageUrl
{
    if ([_legacyThumbnailCacheUri isEqualToString:imageUrl])
    {
        [_imageModel reloadImage:false];
    }
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    [_imageModel bindViewToContainer:container viewStorage:viewStorage];
    [_imageModel boundView].frame = CGRectOffset([_imageModel boundView].frame, itemPosition.x, itemPosition.y);
    (((TGMessageImageViewContainer *)[_imageModel boundView])).imageView.delegate = self;
    
    [_iconModel bindViewToContainer:container viewStorage:viewStorage];
    [_iconModel boundView].frame = CGRectOffset([_iconModel boundView].frame, itemPosition.x, itemPosition.y);
    ((TGDocumentMessageIconView *)[_iconModel boundView]).delegate = self;
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    (((TGMessageImageViewContainer *)[_imageModel boundView])).imageView.delegate = self;
    ((TGDocumentMessageIconView *)[_iconModel boundView]).delegate = self;
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    UIView *imageView = [_imageModel boundView];
    ((TGMessageImageViewContainer *)imageView).imageView.delegate = nil;
    
    UIView *iconView = [_iconModel boundView];
    ((TGDocumentMessageIconView *)iconView).delegate = nil;
    
    [super unbindView:viewStorage];
}

- (void)layoutContentForHeaderHeight:(CGFloat)headerHeight
{
    if (self.groupedLayout.documentGroup) {
        CGPoint origin = CGPointMake(_contentModel.frame.origin.x + 1.0f, _contentModel.frame.origin.y + headerHeight);
        self.groupedLayout.mediaOrigin = origin;
        [self layoutDocumentRowAtOrigin:origin width:self.groupedLayout.documentContentWidth];
        _textModel.frame = CGRectMake(1.0f, headerHeight + self.groupedLayout.dimensions.height + 4.0f, _textModel.frame.size.width, _textModel.frame.size.height);
        return;
    }
    CGSize previewSize = CGSizeZero;
    if (_imageModel != nil)
        previewSize = _imageModel.frame.size;
    else
    {
        previewSize = _iconModel.frame.size;
        previewSize.width -= 4.0f;
        previewSize.height -= 4.0f;
    }
    
    if (_imageModel != nil)
    {
        _documentNameModel.frame = CGRectMake(previewSize.width + 14.0f, headerHeight + 22.0f, _documentNameModel.frame.size.width, _documentNameModel.frame.size.height);
        _documentSizeModel.frame = CGRectMake(previewSize.width + 14.0f, headerHeight + 45.0f, _documentSizeModel.frame.size.width, _documentSizeModel.frame.size.height);
    }
    else
    {
        _documentNameModel.frame = CGRectMake(previewSize.width + 1.0f, headerHeight + 10.0f - TGRetinaPixel, _documentNameModel.frame.size.width, _documentNameModel.frame.size.height);
        _documentSizeModel.frame = CGRectMake(previewSize.width + 1.0f, headerHeight + 32.0f - TGRetinaPixel, _documentSizeModel.frame.size.width, _documentSizeModel.frame.size.height);
    }
    
    _imageModel.frame = CGRectMake(_backgroundModel.frame.origin.x + 9.0f + (_incomingAppearance ? 5.0f : 0.0f), _backgroundModel.frame.origin.y + 9.0f + headerHeight, _imageModel.frame.size.width, _imageModel.frame.size.height);
    _iconModel.frame = CGRectMake(_backgroundModel.frame.origin.x + 4.0f + (_incomingAppearance ? 5.0f : 0.0f), _backgroundModel.frame.origin.y + 4.0f + headerHeight, _iconModel.frame.size.width, _iconModel.frame.size.height);
    
    if (_textModel.text.length != 0 && ![_textModel.text isEqualToString:@" "]) {
        CGRect textFrame = _textModel.frame;
        
        CGFloat textInset = 0.0f;
        if (_imageModel != nil) {
            textInset = CGRectGetMaxY(_imageModel.frame) - _contentModel.frame.origin.y - 2.0f;
        } else {
            textInset = CGRectGetMaxY(_iconModel.frame) - _contentModel.frame.origin.y - 8.0f;
        }
        textFrame.origin = CGPointMake(1, textInset);
        _textModel.frame = textFrame;
        headerHeight += textFrame.size.height;
    } else {
        _textModel.frame = CGRectZero;
    }
}

- (CGSize)contentSizeForContainerSize:(CGSize)containerSize needsContentsUpdate:(bool *)needsContentsUpdate infoWidth:(CGFloat)infoWidth
{
    if (self.groupedLayout.documentGroup) {
        self.groupedLayout.documentContentWidth = containerSize.width;
        bool hasCaption = self.groupedLayout.caption.length != 0;
        if (hasCaption) {
            _textModel.layoutFlags = TGReusableLabelLayoutMultiline | TGReusableLabelLayoutHighlightLinks;
            _textModel.additionalTrailingWidth = infoWidth;
            [_textModel layoutForContainerSize:containerSize];
        } else {
            _textModel.frame = CGRectZero;
        }
        if (needsContentsUpdate != NULL)
            *needsContentsUpdate = true;
        CGFloat captionHeight = hasCaption ? _textModel.frame.size.height + 4.0f : (infoWidth > FLT_EPSILON ? _dateModel.frame.size.height + 3.0f : 0.0f);
        return CGSizeMake(containerSize.width, self.groupedLayout.dimensions.height + captionHeight);
    }
    CGSize textSize = CGSizeZero;
    
    int layoutFlags = TGReusableLabelLayoutMultiline | TGReusableLabelLayoutHighlightLinks;
    
    if (_context.commandsEnabled)
        layoutFlags |= TGReusableLabelLayoutHighlightCommands;
    
    bool updateContents = [_textModel layoutNeedsUpdatingForContainerSize:containerSize additionalTrailingWidth:infoWidth layoutFlags:layoutFlags];
    _textModel.layoutFlags = layoutFlags;
    _textModel.additionalTrailingWidth = infoWidth;
    if (updateContents)
        [_textModel layoutForContainerSize:containerSize];
    
    if (needsContentsUpdate != NULL && updateContents)
       *needsContentsUpdate = updateContents;
    
    CGSize previewSize = CGSizeZero;
    if (_imageModel != nil)
    {
        previewSize = _imageModel.frame.size;
        previewSize.width -= 2.0f;
        previewSize.height -= 2.0f;
    }
    else
    {
        previewSize = _iconModel.frame.size;
        previewSize.width -= 4.0f + 8.0f;
        previewSize.height -= 4.0f + 8.0f;
    }
    
    bool tempUpdateContents = false;
    [_documentNameModel setText:_titleText maxWidth:containerSize.width - previewSize.width - 16.0f needsContentUpdate:&updateContents];
    updateContents = updateContents || tempUpdateContents;
    
    [_documentSizeModel setText:_sizeText maxWidth:containerSize.width - previewSize.width - 16.0f needsContentUpdate:&tempUpdateContents];
    updateContents = updateContents || tempUpdateContents;
    
    
    CGFloat nameWidth = _documentNameModel.frame.size.width;
    CGFloat sizeWidth = _documentSizeModel.frame.size.width;
    
    if (_textModel.text.length != 0 && ![_textModel.text isEqualToString:@" "]) {
        textSize = _textModel.frame.size;
        if (_imageModel != nil) {
            textSize.height += 2.0f;
        } else {
            textSize.height += 8.0f;
        }
        if (infoWidth < FLT_EPSILON) {
            textSize.height -= 15.0f;
        }
    } else {
        textSize.width = MAX(textSize.width, MIN(containerSize.width, infoWidth + sizeWidth + previewSize.width + 16.0f));
        
        if (infoWidth < FLT_EPSILON) {
            textSize.height -= 12.0f;
        }
    }
    
    if (_authorSignatureModel != nil) {
        previewSize.height += 14.0f;
    }
    
    CGFloat brandedBottomInset = [TGPresentation brandedIOS6Style] ? 4.0f : 0.0f;
    return CGSizeMake(MAX(textSize.width, MAX(nameWidth, sizeWidth) + previewSize.width + 14.0f), previewSize.height + 10.0f + textSize.height + brandedBottomInset);
}

- (void)messageImageViewActionButtonPressed:(TGMessageImageView *)messageImageView withAction:(TGMessageImageViewActionType)action
{
    if (messageImageView == ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView || messageImageView == [_iconModel boundView])
    {
        if (action == TGMessageImageViewActionCancelDownload)
            [self cancelMediaDownload];
        else
            [self activateMedia];
    }
}

- (void)activateMedia
{
    if (_mediaIsAvailable)
    {
        [_context.companionHandle requestAction:@"openMediaRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    }
    else
        [_context.companionHandle requestAction:@"mediaDownloadRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
}

- (void)cancelMediaDownload
{
    [_context.companionHandle requestAction:@"mediaProgressCancelRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    for (NSArray *entry in _suppressedGroupModels) {
        TGModernViewModel *model = entry[0];
        model.hidden = [entry[1] boolValue];
    }
    _suppressedGroupModels = nil;
    _backgroundModel.drawsBubble = !self.groupedLayout.documentGroup || self.groupedLayout.mainMessageId == _mid;
    if (self.groupedLayout.documentGroup && self.groupedLayout.mainMessageId != _mid) {
        CGRect row = [self.groupedLayout frameForMessageId:_mid];
        CGPoint origin = CGPointMake(self.groupedLayout.mediaOrigin.x, self.groupedLayout.mediaOrigin.y + row.origin.y);
        CGFloat width = self.groupedLayout.documentContentWidth;
        _backgroundModel.frame = CGRectMake(origin.x, origin.y, width, row.size.height);
        _contentModel.frame = CGRectMake(origin.x, origin.y, width, row.size.height);
        _textModel.frame = CGRectZero;
        [self layoutDocumentRowAtOrigin:origin width:width];
        NSMutableArray *suppressed = [[NSMutableArray alloc] init];
        for (TGModernViewModel *model in self.submodels) {
            if (model == _backgroundModel || model == _contentModel || model == _imageModel || model == _iconModel)
                continue;
            [suppressed addObject:@[model, @(model.hidden)]];
            model.hidden = true;
        }
        for (TGModernViewModel *model in _contentModel.submodels) {
            if (model == _documentNameModel || model == _documentSizeModel)
                continue;
            [suppressed addObject:@[model, @(model.hidden)]];
            model.hidden = true;
        }
        _suppressedGroupModels = suppressed;
        self.frame = CGRectMake(0.0f, 0.0f, containerSize.width, CGRectGetMaxY(_backgroundModel.frame));
        [_contentModel setNeedsSubmodelContentsUpdate];
        [_contentModel updateSubmodelContentsIfNeeded];
        return;
    }
    [super layoutForContainerSize:containerSize];
}

- (bool (^)(CGPoint))pointInside
{
    if (self.groupedLayout.documentGroup && self.groupedLayout.mainMessageId != _mid) {
        CGRect frame = _backgroundModel.frame;
        return ^bool(CGPoint point) { return CGRectContainsPoint(frame, point); };
    }
    return [super pointInside];
}

- (void)clearLinkSelection
{
    for (UIView *linkView in _currentLinkSelectionViews)
    {
        [linkView removeFromSuperview];
    }
    _currentLinkSelectionViews = nil;
}

- (void)updateLinkSelection:(CGPoint)point
{
    if ([_contentModel boundView] != nil)
    {
        [self clearLinkSelection];
        
        CGPoint offset = CGPointMake(_contentModel.frame.origin.x - _backgroundModel.frame.origin.x, _contentModel.frame.origin.y - _backgroundModel.frame.origin.y);
        
        NSArray *regionData = nil;
        NSString *link = [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x - offset.x, point.y - _textModel.frame.origin.y - offset.y) regionData:&regionData];
        
        CGPoint regionOffset = CGPointZero;
        
        if (link != nil)
        {
            CGRect topRegion = regionData.count > 0 ? [regionData[0] CGRectValue] : CGRectZero;
            CGRect middleRegion = regionData.count > 1 ? [regionData[1] CGRectValue] : CGRectZero;
            CGRect bottomRegion = regionData.count > 2 ? [regionData[2] CGRectValue] : CGRectZero;
            
            topRegion.origin = CGPointMake(topRegion.origin.x + regionOffset.x, topRegion.origin.y + regionOffset.y);
            middleRegion.origin = CGPointMake(middleRegion.origin.x + regionOffset.x, middleRegion.origin.y + regionOffset.y);
            bottomRegion.origin = CGPointMake(bottomRegion.origin.x + regionOffset.x, bottomRegion.origin.y + regionOffset.y);
            
            UIImageView *topView = nil;
            UIImageView *middleView = nil;
            UIImageView *bottomView = nil;
            
            UIImageView *topCornerLeft = nil;
            UIImageView *topCornerRight = nil;
            UIImageView *bottomCornerLeft = nil;
            UIImageView *bottomCornerRight = nil;
            
            NSMutableArray *linkHighlightedViews = [[NSMutableArray alloc] init];
            
            topView = [[UIImageView alloc] init];
            middleView = [[UIImageView alloc] init];
            bottomView = [[UIImageView alloc] init];
            
            topCornerLeft = [[UIImageView alloc] init];
            topCornerRight = [[UIImageView alloc] init];
            bottomCornerLeft = [[UIImageView alloc] init];
            bottomCornerRight = [[UIImageView alloc] init];
            
            if (topRegion.size.height != 0)
            {
                topView.hidden = false;
                topView.frame = topRegion;
                if (middleRegion.size.height == 0 && bottomRegion.size.height == 0)
                    topView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
                else
                    topView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                topView.hidden = true;
                topView.frame = CGRectZero;
            }
            
            if (middleRegion.size.height != 0)
            {
                middleView.hidden = false;
                middleView.frame = middleRegion;
                if (bottomRegion.size.height == 0)
                    middleView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
                else
                    middleView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                middleView.hidden = true;
                middleView.frame = CGRectZero;
            }
            
            if (bottomRegion.size.height != 0)
            {
                bottomView.hidden = false;
                bottomView.frame = bottomRegion;
                bottomView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                bottomView.hidden = true;
                bottomView.frame = CGRectZero;
            }
            
            topCornerLeft.hidden = true;
            topCornerRight.hidden = true;
            bottomCornerLeft.hidden = true;
            bottomCornerRight.hidden = true;
            
            if (topRegion.size.height != 0 && middleRegion.size.height != 0)
            {
                if (topRegion.origin.x == middleRegion.origin.x)
                {
                    topCornerLeft.hidden = false;
                    topCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerLR];
                    topCornerLeft.frame = CGRectMake(topRegion.origin.x, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
                }
                else if (topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    topCornerLeft.hidden = false;
                    topCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerBT];
                    topCornerLeft.frame = CGRectMake(topRegion.origin.x - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
                }
                
                if (topRegion.origin.x + topRegion.size.width == middleRegion.origin.x + middleRegion.size.width)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerRL];
                    topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 4, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
                }
                else if (topRegion.origin.x + topRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerBT];
                    topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
                }
                else if (bottomRegion.size.height == 0 && topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f && topRegion.origin.x + topRegion.size.width > middleRegion.origin.x + middleRegion.size.width + 3.5f)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerTB];
                    topCornerRight.frame = CGRectMake(middleRegion.origin.x + middleRegion.size.width - 3.5f, middleRegion.origin.y, 7, 4);
                }
            }
            
            if (middleRegion.size.height != 0 && bottomRegion.size.height != 0)
            {
                if (middleRegion.origin.x == bottomRegion.origin.x)
                {
                    bottomCornerLeft.hidden = false;
                    bottomCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerLR];
                    bottomCornerLeft.frame = CGRectMake(middleRegion.origin.x, middleRegion.origin.y + middleRegion.size.height - 3.5f, 4, 7);
                }
                
                if (bottomRegion.origin.x + bottomRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    bottomCornerRight.hidden = false;
                    bottomCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerTB];
                    bottomCornerRight.frame = CGRectMake(bottomRegion.origin.x + bottomRegion.size.width - 3.5f, bottomRegion.origin.y, 7, 4);
                }
            }
            
            if (!topView.hidden)
                [linkHighlightedViews addObject:topView];
            if (!middleView.hidden)
                [linkHighlightedViews addObject:middleView];
            if (!bottomView.hidden)
                [linkHighlightedViews addObject:bottomView];
            
            if (!topCornerLeft.hidden)
                [linkHighlightedViews addObject:topCornerLeft];
            if (!topCornerRight.hidden)
                [linkHighlightedViews addObject:topCornerRight];
            if (!bottomCornerLeft.hidden)
                [linkHighlightedViews addObject:bottomCornerLeft];
            if (!bottomCornerRight.hidden)
                [linkHighlightedViews addObject:bottomCornerRight];
            
            for (UIView *partView in linkHighlightedViews)
            {
                partView.frame = CGRectOffset(partView.frame, _textModel.frame.origin.x, _textModel.frame.origin.y + 1);
                [[_contentModel boundView] addSubview:partView];
            }
            
            _currentLinkSelectionViews = linkHighlightedViews;
        }
    }
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer shouldFailTap:(CGPoint)__unused point
{
    CGPoint convertedPoint = [recognizer locationInView:[_contentModel boundView]];
    
    if (_textModel.frame.size.height > FLT_EPSILON && point.y >= CGRectGetMinY(_textModel.frame)) {
        if (([_textModel linkAtPoint:CGPointMake(convertedPoint.x - _textModel.frame.origin.x, convertedPoint.y - _textModel.frame.origin.y) regionData:NULL] != nil || (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, convertedPoint)) || (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, convertedPoint)) ||
             (_viaUserModel && CGRectContainsPoint(_viaUserModel.frame, convertedPoint)))) {
            return 3;
        }
        
        return 0;
    }
    
    return 3;
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)point
{
    [self updateLinkSelection:point];
}

- (bool)gestureRecognizerShouldLetScrollViewStealTouches:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    [self clearLinkSelection];
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        [self clearLinkSelection];
    }
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint point = [recognizer locationInView:[_contentModel boundView]];
        NSString *linkCandidate = [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x, point.y - _textModel.frame.origin.y) regionData:NULL];
        
        if (recognizer.longTapped)
        {
            if (linkCandidate != nil)
                [_context.companionHandle requestAction:@"openLinkWithOptionsRequested" options:@{@"url": linkCandidate}];
            else
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        }
        else if (recognizer.doubleTapped)
            [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        else if (linkCandidate != nil)
            [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": linkCandidate, @"mid": @(_mid)}];
        else if (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, point)) {
            if (TGPeerIdIsChannel(_forwardedPeerId)) {
                [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(_forwardedPeerId), @"messageId": @(_forwardedMessageId)}];
            } else {
                [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @((int32_t)_forwardedPeerId)}];
            }
        }
        else if (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, point))
            [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_replyMessageId), @"sourceMid": @(_mid)}];
        else if (_textModel.frame.size.height <= FLT_EPSILON || point.y < CGRectGetMinY(_textModel.frame)) {
            [self activateMedia];
        }
    }
}

- (bool)isPreviewableAtPoint:(CGPoint)__unused point
{
    return (_imageModel != nil);
}

- (NSString *)linkAtPoint:(CGPoint)point {
    point.x -= _contentModel.frame.origin.x;
    point.y -= _contentModel.frame.origin.y;
    return [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x, point.y - _textModel.frame.origin.y) regionData:NULL];
}

@end
