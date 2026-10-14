#import "../Base/OGView.h"
#import "../Base/OGIconView.h"
#import "../Base/OGLabel.h"
#import "../Base/OGSeparatorView.h"
#import "../Common/OGAvatarView.h"
#import "../Common/OGBadgeView.h"

@interface OGListCell : OGView
@property (nonatomic, retain, readonly) OGAvatarView *avatarView;
@property (nonatomic, retain, readonly) OGIconView *iconView;
@property (nonatomic, retain, readonly) OGLabel *titleLabel;
@property (nonatomic, retain, readonly) OGLabel *subtitleLabel;
@property (nonatomic, retain, readonly) OGLabel *detailLabel;
@property (nonatomic, retain, readonly) OGBadgeView *badgeView;
@property (nonatomic, retain, readonly) OGIconView *accessoryView;
@property (nonatomic, retain, readonly) OGSeparatorView *separatorView;
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic) BOOL showsAvatar;
@property (nonatomic) BOOL showsIcon;
@property (nonatomic) BOOL showsAccessory;
@property (nonatomic) BOOL showsSeparator;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
- (void)prepareForReuse;
@end
