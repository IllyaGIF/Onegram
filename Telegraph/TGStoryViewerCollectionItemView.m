#import "TGStoryViewerCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGPresentation.h"

static const CGFloat TGStoryViewerAvatarSide = 40.0f;

@interface TGStoryViewerCollectionItemView ()
{
    TGLetteredAvatarView *_avatarView;
    UILabel *_nameLabel;
    UILabel *_dateLabel;
    UIImageView *_reactionView;
    UILabel *_reactionLabel;
}

@end

@implementation TGStoryViewerCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGStoryViewerAvatarSide, TGStoryViewerAvatarSide)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:true];
        _avatarView.fadeTransition = true;
        [self addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.font = TGMediumSystemFontOfSize(16.0f);
        [self addSubview:_nameLabel];

        _dateLabel = [[UILabel alloc] init];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.font = TGSystemFontOfSize(13.0f);
        [self addSubview:_dateLabel];

        _reactionView = [[UIImageView alloc] init];
        _reactionView.contentMode = UIViewContentModeCenter;
        [self addSubview:_reactionView];

        _reactionLabel = [[UILabel alloc] init];
        _reactionLabel.backgroundColor = [UIColor clearColor];
        _reactionLabel.font = TGEmojiFontOfSize(22.0f);
        _reactionLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_reactionLabel];

        self.separatorInset = 15.0f + TGStoryViewerAvatarSide + 12.0f;
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _nameLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _dateLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    _reactionLabel.textColor = presentation.pallete.collectionMenuTextColor;
}

- (void)setUser:(TGUser *)user date:(int32_t)date hasReaction:(bool)hasReaction reaction:(NSString *)reaction blocked:(bool)blocked
{
    _nameLabel.text = user.displayName ?: @"";
    NSString *dateText = date != 0 ? [TGDateUtils stringForMessageListDate:date] : @"";
    _dateLabel.text = blocked ? [[NSString alloc] initWithFormat:@"%@ · %@", dateText, TGLocalized(@"StoryViewers.Blocked")] : dateText;

    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:TGStoryViewerAvatarSide];
    NSString *avatarUrl = user.photoFullUrlSmall.length != 0 ? user.photoFullUrlSmall : user.photoUrlSmall;
    if (avatarUrl.length != 0)
    {
        if (!TGStringCompare([_avatarView currentUrl], avatarUrl))
            [_avatarView loadImage:avatarUrl filter:@"circle:40x40" placeholder:placeholder];
    }
    else
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(TGStoryViewerAvatarSide, TGStoryViewerAvatarSide) uid:user.uid firstName:user.firstName lastName:user.lastName placeholder:placeholder];

    NSString *displayedReaction = hasReaction ? (reaction.length != 0 ? reaction : @"❤️") : nil;
    UIImage *reactionImage = displayedReaction.length != 0 ? TGEmojiImageOfSize(displayedReaction, 24.0f) : nil;
    _reactionView.image = reactionImage;
    _reactionView.hidden = reactionImage == nil;
    _reactionLabel.text = reactionImage == nil ? displayedReaction : nil;
    _reactionLabel.hidden = reactionImage != nil || displayedReaction.length == 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.bounds.size;
    CGFloat left = 15.0f + self.safeAreaInset.left;
    CGFloat right = size.width - 15.0f - self.safeAreaInset.right;
    _avatarView.frame = CGRectMake(left, CGFloor((size.height - TGStoryViewerAvatarSide) / 2.0f), TGStoryViewerAvatarSide, TGStoryViewerAvatarSide);

    bool hasReaction = !_reactionView.hidden || !_reactionLabel.hidden;
    CGRect reactionFrame = CGRectMake(right - 32.0f, CGFloor((size.height - 32.0f) / 2.0f), 32.0f, 32.0f);
    _reactionView.frame = reactionFrame;
    _reactionLabel.frame = reactionFrame;

    CGFloat textLeft = CGRectGetMaxX(_avatarView.frame) + 12.0f;
    CGFloat textRight = hasReaction ? CGRectGetMinX(reactionFrame) - 8.0f : right;
    CGFloat textWidth = MAX(0.0f, textRight - textLeft);
    _nameLabel.frame = CGRectMake(textLeft, 9.0f, textWidth, 21.0f);
    _dateLabel.frame = CGRectMake(textLeft, 30.0f, textWidth, 17.0f);
}

@end
