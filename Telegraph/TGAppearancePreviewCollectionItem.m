#import "TGAppearancePreviewCollectionItem.h"

#import "TGAppearancePreviewCollectionItemView.h"

@interface TGAppearancePreviewCollectionItem ()
{
    CGFloat _cachedHeight;
    bool _heightChangeScheduled;
}
@end

@implementation TGAppearancePreviewCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (void)updateCachedHeightFromView:(TGAppearancePreviewCollectionItemView *)view
{
    if (view == nil || fabs(view.contentHeight - _cachedHeight) <= FLT_EPSILON)
        return;
    _cachedHeight = view.contentHeight;
    [self scheduleHeightChanged];
}

- (void)scheduleHeightChanged
{
    if (_heightChangeScheduled)
        return;
    _heightChangeScheduled = true;

    __weak TGAppearancePreviewCollectionItem *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGAppearancePreviewCollectionItem *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_heightChangeScheduled = false;
        if (strongSelf.heightChanged)
            strongSelf.heightChanged();
    });
}

- (void)bindView:(TGAppearancePreviewCollectionItemView *)view
{
    [super bindView:view];
    
    __weak TGAppearancePreviewCollectionItem *weakSelf = self;
    __weak TGAppearancePreviewCollectionItemView *weakView = view;
    view.contentHeightChanged = ^
    {
        __strong TGAppearancePreviewCollectionItem *strongSelf = weakSelf;
        [strongSelf updateCachedHeightFromView:weakView];
    };
    view.stickerScale = _stickerScale;
    view.messagePresentation = _messagePresentation;
    view.messages = _messages;
    view.fontSize = _fontSize;
    [view updateWallpaper];
    
    [self updateCachedHeightFromView:view];
}

- (void)unbindView
{
    ((TGAppearancePreviewCollectionItemView *)self.boundView).contentHeightChanged = nil;
    [super unbindView];
}

- (void)setMessages:(NSArray *)messages
{
    _messages = messages;
    
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view setMessages:messages];
    
    [self updateCachedHeightFromView:view];
}

- (void)setMessagePresentation:(TGPresentation *)messagePresentation
{
    _messagePresentation = messagePresentation;
    
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view setMessagePresentation:messagePresentation];
    
    [self updateCachedHeightFromView:view];
}

- (void)setStickerScale:(CGFloat)stickerScale
{
    _stickerScale = stickerScale;
    
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view setStickerScale:stickerScale];
    [self updateCachedHeightFromView:view];
}

- (void)setFontSize:(int32_t)fontSize
{
    _fontSize = fontSize;
    
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view setFontSize:fontSize];

    [self updateCachedHeightFromView:view];
}

- (void)updateWallpaper
{
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view updateWallpaper];
}

- (void)reset
{
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view reset];
}

- (void)refreshMetrics
{
    TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
    [view refreshMetrics];
    
    [self updateCachedHeightFromView:view];
}

- (Class)itemViewClass
{
    return [TGAppearancePreviewCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    if (_cachedHeight < FLT_EPSILON)
    {
        TGAppearancePreviewCollectionItemView *view = (TGAppearancePreviewCollectionItemView *)self.boundView;
        _cachedHeight = view.contentHeight;
    }
    return CGSizeMake(containerSize.width, _cachedHeight);
}

@end
