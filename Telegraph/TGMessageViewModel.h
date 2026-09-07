/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGModernViewModel.h"

@class TGUser;
@class TGMessage;
@class TGModernViewContext;
@class TGMessageGroupedLayout;
@class TGModernLetteredAvatarViewModel;
@class TGMessageViewModel;
@class TGMessageViewModelReference;

typedef struct {
    CGFloat topInset;
    CGFloat bottomInset;
    CGFloat topInsetCollapsed;
    CGFloat bottomInsetCollapsed;
    CGFloat leftInset;
    CGFloat rightInset;
    
    CGFloat leftImageInset;
    CGFloat rightImageInset;
    
    CGFloat avatarInset;
    
    CGFloat textFontSize;
    CGFloat textBubblePaddingTop;
    CGFloat textBubblePaddingBottom;
    CGFloat textBubbleTextOffsetTop;
    
    CGFloat topPostInset;
    CGFloat bottomPostInset;
} TGMessageViewModelLayoutConstants;

#ifdef __cplusplus
extern "C" {
#endif
    
void TGMessageViewModelLayoutSetPreferredTextFontSize(CGFloat fontSize);
const TGMessageViewModelLayoutConstants *TGGetMessageViewModelLayoutConstants();
void TGUpdateMessageViewModelLayoutConstants(CGFloat baseFontPointSize);
    
#ifdef __cplusplus
}
#endif

@interface TGMessageViewModelReference : NSObject
{
    NSCondition *_condition;
    __weak TGMessageViewModel *_value;
    NSUInteger _activeCallbacks;
}
- (void)setValue:(TGMessageViewModel *)value;
- (void)withValue:(void (^)(void *value))block;
- (void)invalidate;
@end

@interface TGMessageViewModel : TGModernViewModel <UIGestureRecognizerDelegate>
{
    TGModernViewContext *_context;
    TGMessageViewModelReference *_lifetimeReference;
    id _authorPeer;
    
    int32_t _mid;
    int64_t _groupedId;
    int64_t _authorPeerId;
    
    TGModernLetteredAvatarViewModel *_avatarModel;
    
    bool _incomingAppearance;
    int _collapseFlags;
    int _positionFlags;
    TGMessageGroupedLayout *_groupedLayout;
    bool _editing;
    
    bool _needsEditingCheckButton;
    bool _editingCheckButtonGrowTransition;
    
    UIPanGestureRecognizer *_replyPanGestureRecognizer;
    CGFloat _replyPanOffset;
}

@property (nonatomic) bool needsRelativeBoundsUpdates;
@property (nonatomic) bool needsAvatar;
@property (nonatomic) CGFloat avatarOffset;

@property (nonatomic) int collapseFlags;
@property (nonatomic) int positionFlags;
@property (nonatomic) TGMessageGroupedLayout *groupedLayout;

@property (nonatomic, readonly) CGRect editingCheckButtonFrame;
@property (nonatomic, readonly) CGRect editingCheckAreaFrame;

@property (nonatomic, copy, readonly) bool (^pointInside)(CGPoint point);

- (instancetype)initWithAuthorPeer:(id)authorPeer context:(TGModernViewContext *)context;
- (TGMessageViewModelReference *)lifetimeReference;
- (void)invalidateLifetimeReference;

- (void)setAuthorAvatarUrl:(NSString *)authorAvatarUrl groupId:(int64_t)groupId;
- (void)setAuthorAvatarUrl:(NSString *)authorAvatarUrl;
- (void)setAuthorNameColor:(UIColor *)authorNameColor;
- (void)setAuthorSignature:(NSString *)authorSignature;

- (bool)setDiscussionCommentsEnabled:(bool)enabled count:(int32_t)count channelId:(int64_t)channelId;

// The official Telegram iOS layout treats comments as an attached footer of
// the same message bubble. Bubble subclasses use these helpers to reserve the
// footer space before the base model places the interactive row inside it.
- (CGFloat)discussionCommentsFooterHeight;
- (CGFloat)discussionCommentsFooterMinimumWidth;
- (bool)discussionCommentsFooterIntegratedInBubble;

- (void)updateAssets;
- (void)refreshMetrics;
- (void)updateSearchText:(bool)animated;
- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated;
- (void)relativeBoundsUpdated:(CGRect)bounds;
- (void)imageDataInvalidated:(NSString *)imageUrl;
- (CGRect)effectiveContentFrame;
- (CGRect)fullContentFrame;
- (UIView *)referenceViewForImageTransition;
- (void)setTemporaryHighlighted:(bool)temporaryHighlighted viewStorage:(TGModernViewStorage *)viewStorage;
- (void)clearHighlights;

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)viewStorage animated:(bool)animated;
- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)viewStorage delayDisplay:(bool)delayDisplay;
- (void)updateMediaVisibility;
- (void)updateMessageFocus;
- (void)updateMessageVisibility;
- (void)updateMessageAttributes;
- (void)updateEditingState:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage animationDelay:(NSTimeInterval)animationDelay;
- (void)updateInlineMediaContext;
- (void)updateAnimationsEnabled;
- (void)stopInlineMedia:(int32_t)excludeMid;
- (void)resumeInlineMedia;

- (void)updateReplySwipeInteraction:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage ended:(bool)ended;
- (void)setExplicitReplyPanOffset:(CGFloat)replyPanOffset ended:(bool)ended;

- (NSString *)linkAtPoint:(CGPoint)point;
- (bool)isPreviewableAtPoint:(CGPoint)point;

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition;

@end
