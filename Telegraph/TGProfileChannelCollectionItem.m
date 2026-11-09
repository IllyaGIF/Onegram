#import "TGProfileChannelCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCollectionItemView.h"
#import "TGPresentation.h"

static const CGFloat TGProfileChannelAvatarSide = 44.0f;

@interface TGProfileChannelCollectionItemView : TGCollectionItemView
{
    TGLetteredAvatarView *_avatarView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_disclosureView;
}

- (void)setChannel:(TGConversation *)channel;

@end

@implementation TGProfileChannelCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGProfileChannelAvatarSide, TGProfileChannelAvatarSide)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGMediumSystemFontOfSize(16.0f);
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(14.0f);
        [self.contentView addSubview:_subtitleLabel];

        _disclosureView = [[UIImageView alloc] init];
        [self.contentView addSubview:_disclosureView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    _disclosureView.image = presentation.images.collectionMenuDisclosureIcon;
    [_disclosureView sizeToFit];
}

- (void)setChannel:(TGConversation *)conversation
{
    _titleLabel.text = conversation.chatTitle;
    _subtitleLabel.text = conversation.username.length != 0 ? [[NSString alloc] initWithFormat:@"@%@", conversation.username] : TGLocalized(@"OnegramProfile.Channel");
    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:TGProfileChannelAvatarSide];
    NSString *filter = [[NSString alloc] initWithFormat:@"circle:%.0fx%.0f", TGProfileChannelAvatarSide, TGProfileChannelAvatarSide];
    if (conversation.chatPhotoFullSmall.length != 0)
        [_avatarView loadImage:conversation.chatPhotoFullSmall filter:filter placeholder:placeholder];
    else
        [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(TGProfileChannelAvatarSide, TGProfileChannelAvatarSide) conversationId:conversation.conversationId title:conversation.chatTitle placeholder:placeholder];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat left = 15.0f + self.safeAreaInset.left;
    _avatarView.frame = CGRectMake(left, CGFloor((bounds.size.height - TGProfileChannelAvatarSide) / 2.0f), TGProfileChannelAvatarSide, TGProfileChannelAvatarSide);
    CGSize disclosureSize = _disclosureView.frame.size;
    _disclosureView.frame = CGRectMake(bounds.size.width - 15.0f - self.safeAreaInset.right - disclosureSize.width, CGFloor((bounds.size.height - disclosureSize.height) / 2.0f), disclosureSize.width, disclosureSize.height);
    CGFloat textLeft = CGRectGetMaxX(_avatarView.frame) + 12.0f;
    CGFloat textWidth = MAX(0.0f, CGRectGetMinX(_disclosureView.frame) - 8.0f - textLeft);
    _titleLabel.frame = CGRectMake(textLeft, CGFloor(bounds.size.height / 2.0f) - 20.0f, textWidth, 20.0f);
    _subtitleLabel.frame = CGRectMake(textLeft, CGFloor(bounds.size.height / 2.0f) + 1.0f, textWidth, 18.0f);
}

@end

@implementation TGProfileChannelCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.selectable = true;
        self.highlightable = true;
        self.deselectAutomatically = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGProfileChannelCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 64.0f);
}

- (void)bindView:(TGProfileChannelCollectionItemView *)view
{
    [super bindView:view];
    [view setChannel:_channel];
}

- (void)setChannel:(TGConversation *)channel
{
    _channel = channel;
    [(TGProfileChannelCollectionItemView *)[self boundView] setChannel:channel];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil && _channel != nil)
        _pressed(_channel);
}

@end
