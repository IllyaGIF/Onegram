#import "TGMessageCommentsFooterView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGPresentation.h"
#import "TGMessageCommentsFooterViewModel.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

@interface TGMessageCommentsFooterView ()
{
    UIView *_separatorView;
    NSMutableArray *_avatarViews;
    NSMutableArray *_avatarOverlayViews;
    UILabel *_titleLabel;
    UILabel *_countLabel;
    UIImageView *_chevronView;
    NSUInteger _visibleAvatarCount;
    UIEdgeInsets _avatarOverlayOutsets;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGMessageCommentsFooterView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];

        self.modernHighlight = true;

        _separatorView = [[UIView alloc] init];
        _separatorView.userInteractionEnabled = false;
        _separatorView.backgroundColor = appearance.commentsSeparatorColor;
        [self addSubview:_separatorView];

        _avatarViews = [[NSMutableArray alloc] init];
        _avatarOverlayViews = [[NSMutableArray alloc] init];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.userInteractionEnabled = false;
        _titleLabel.font = appearance.commentsTitleFont;
        _titleLabel.textColor = appearance.commentsTextColor;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _countLabel = [[UILabel alloc] init];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.userInteractionEnabled = false;
        _countLabel.font = appearance.commentsCountFont;
        _countLabel.textColor = appearance.commentsTextColor;
        [self addSubview:_countLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[TGPresentation brandedIOS6CommentsChevronImage]];
        _chevronView.userInteractionEnabled = false;
        [self addSubview:_chevronView];
    }
    return self;
}

- (void)willBecomeRecycled
{
    [self removeTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
}

- (TGLetteredAvatarView *)avatarViewAtIndex:(NSUInteger)index
{
    while (_avatarViews.count <= index)
    {
        OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
        TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, appearance.commentsAvatarSize, appearance.commentsAvatarSize)];
        avatarView.userInteractionEnabled = false;
        avatarView.clipsToBounds = true;
        avatarView.layer.cornerRadius = appearance.commentsAvatarCornerRadius;
        [avatarView setSingleFontSize:9.0f doubleFontSize:8.0f useBoldFont:true];
        [self insertSubview:avatarView belowSubview:_titleLabel];
        [_avatarViews addObject:avatarView];

        UIImageView *overlayView = [[UIImageView alloc] init];
        overlayView.userInteractionEnabled = false;
        [self insertSubview:overlayView aboveSubview:avatarView];
        [_avatarOverlayViews addObject:overlayView];
    }
    return _avatarViews[index];
}

- (void)setRepliers:(NSArray *)repliers presentation:(TGPresentation *)presentation
{
    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    NSUInteger count = MIN(repliers.count, appearance.commentsAvatarMaximumCount);
    CGFloat avatarSize = appearance.commentsAvatarSize;
    UIImage *placeholder = [presentation.images avatarPlaceholderWithDiameter:avatarSize];
    NSString *filter = [[NSString alloc] initWithFormat:@"scale:%dx%d", (int)avatarSize, (int)avatarSize];
    UIEdgeInsets overlayOutsets = UIEdgeInsetsZero;
    UIImage *overlayImage = [TGPresentation brandedIOS6CommentsAvatarOverlayImageWithOutsets:&overlayOutsets];
    _avatarOverlayOutsets = overlayOutsets;

    for (NSUInteger i = 0; i < count; i++)
    {
        TGMessageCommentsFooterReplier *replier = repliers[i];
        TGLetteredAvatarView *avatarView = [self avatarViewAtIndex:i];
        avatarView.hidden = false;
        ((UIImageView *)_avatarOverlayViews[i]).hidden = false;
        ((UIImageView *)_avatarOverlayViews[i]).image = overlayImage;
        if (replier.avatarUrl.length != 0)
        {
            if (![avatarView.currentUrl isEqualToString:replier.avatarUrl])
                [avatarView loadImage:replier.avatarUrl filter:filter placeholder:placeholder];
        }
        else if (replier.isUser)
            [avatarView loadUserPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) uid:(int)replier.peerId firstName:replier.firstName lastName:replier.lastName placeholder:placeholder];
        else
            [avatarView loadGroupPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) conversationId:replier.peerId title:replier.firstName placeholder:placeholder];
    }

    for (NSUInteger i = count; i < _avatarViews.count; i++)
    {
        ((UIView *)_avatarViews[i]).hidden = true;
        ((UIView *)_avatarOverlayViews[i]).hidden = true;
    }

    _visibleAvatarCount = count;
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title count:(int32_t)count
{
    _titleLabel.text = title;
    _countLabel.text = count > 0 ? [[NSString alloc] initWithFormat:@"+%d", (int)count] : nil;
    _countLabel.hidden = count <= 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    CGSize size = self.bounds.size;

    _separatorView.frame = CGRectMake(0.0f, 0.0f, size.width, TGScreenPixel);

    CGFloat avatarSize = appearance.commentsAvatarSize;
    CGFloat avatarY = CGFloor((size.height - avatarSize) / 2.0f);
    CGFloat titleX = appearance.commentsTitleLeftWithoutAvatars;
    for (NSUInteger i = 0; i < _visibleAvatarCount; i++)
    {
        CGFloat avatarX = appearance.commentsAvatarLeft + appearance.commentsAvatarStep * i;
        UIView *avatarView = _avatarViews[i];
        avatarView.frame = CGRectMake(avatarX, avatarY, avatarSize, avatarSize);
        UIImageView *overlayView = _avatarOverlayViews[i];
        overlayView.frame = CGRectMake(avatarX - _avatarOverlayOutsets.left, avatarY - _avatarOverlayOutsets.top, avatarSize + _avatarOverlayOutsets.left + _avatarOverlayOutsets.right, avatarSize + _avatarOverlayOutsets.top + _avatarOverlayOutsets.bottom);
        titleX = CGRectGetMaxX(avatarView.frame) + appearance.commentsTitleSpacing;
    }

    CGSize chevronSize = _chevronView.image.size;
    _chevronView.frame = CGRectMake(size.width - appearance.commentsChevronRightInset - chevronSize.width, CGFloor((size.height - chevronSize.height) / 2.0f), chevronSize.width, chevronSize.height);

    CGFloat textRight = CGRectGetMinX(_chevronView.frame) - appearance.commentsCountSpacing;
    if (!_countLabel.hidden)
    {
        CGSize countSize = [_countLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, size.height)];
        _countLabel.frame = CGRectMake(textRight - ceilf(countSize.width), CGFloor((size.height - countSize.height) / 2.0f), ceilf(countSize.width), ceilf(countSize.height));
        textRight = CGRectGetMinX(_countLabel.frame) - appearance.commentsCountSpacing;
    }

    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, size.height)];
    _titleLabel.frame = CGRectMake(titleX, CGFloor((size.height - titleSize.height) / 2.0f), MAX(0.0f, MIN(ceilf(titleSize.width), textRight - titleX)), ceilf(titleSize.height));
}

@end
