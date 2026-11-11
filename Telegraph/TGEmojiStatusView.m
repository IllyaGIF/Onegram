#import "TGEmojiStatusView.h"

#import "TGCustomEmojiThumbnail.h"

@interface TGEmojiStatusView ()
{
    bool _thumbnailReady;
}

@end

@implementation TGEmojiStatusView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.contentMode = UIViewContentModeScaleAspectFit;
        self.hidden = true;
    }
    return self;
}

- (bool)displaysStatus
{
    return self.superview != nil && !self.hidden;
}

- (void)setDocumentId:(int64_t)documentId
{
    if (_documentId == documentId)
        return;

    _documentId = documentId;
    _thumbnailReady = false;
    [self cancelLoading];
    [self refreshVisibility];

    if (documentId == 0)
        return;

    __weak TGEmojiStatusView *weakSelf = self;
    TGCustomEmojiLoadThumbnail(documentId, ^(NSString *thumbnailUri)
    {
        TGEmojiStatusView *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_documentId != documentId || thumbnailUri.length == 0)
            return;

        [strongSelf loadImage:thumbnailUri filter:nil placeholder:nil];
        strongSelf->_thumbnailReady = true;
        [strongSelf refreshVisibility];
    });
}

- (void)setSuppressed:(bool)suppressed
{
    if (_suppressed == suppressed)
        return;

    _suppressed = suppressed;
    [self refreshVisibility];
}

- (void)refreshVisibility
{
    bool hidden = _documentId == 0 || !_thumbnailReady || _suppressed;
    if (self.hidden == hidden)
        return;

    self.hidden = hidden;
    if (_displayChanged != nil)
        _displayChanged();
}

@end
