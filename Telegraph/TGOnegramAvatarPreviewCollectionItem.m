#import "TGOnegramAvatarPreviewCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGCollectionItemView.h"

static const CGFloat TGOnegramAvatarPreviewSide = 52.0f;
static const NSUInteger TGOnegramAvatarPreviewCount = 4;

@interface TGOnegramAvatarPreviewCollectionItemView : TGCollectionItemView
{
    NSArray *_avatarViews;
}

- (void)refreshRoundness;

@end

@implementation TGOnegramAvatarPreviewCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        NSMutableArray *avatarViews = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < TGOnegramAvatarPreviewCount; index++)
        {
            TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGOnegramAvatarPreviewSide, TGOnegramAvatarPreviewSide)];
            [avatarView setSingleFontSize:20.0f doubleFontSize:20.0f useBoldFont:false];
            avatarView.fadeTransition = false;
            avatarView.layer.cornerRadius = 7.0f;
            [self addSubview:avatarView];
            [avatarViews addObject:avatarView];
        }
        _avatarViews = avatarViews;
        [self reloadAvatars];
    }
    return self;
}

- (void)reloadAvatars
{
    NSArray *firstNames = @[@"Anna", @"Boris", @"Vera", @"Gleb"];
    NSArray *lastNames = @[@"Smith", @"Ivanov", @"Lee", @"Orlov"];
    [_avatarViews enumerateObjectsUsingBlock:^(TGLetteredAvatarView *avatarView, NSUInteger index, __unused BOOL *stop)
    {
        [avatarView loadUserPlaceholderWithSize:CGSizeMake(TGOnegramAvatarPreviewSide, TGOnegramAvatarPreviewSide) uid:(int64_t)(index * 3 + 1) firstName:firstNames[index] lastName:lastNames[index] placeholder:nil];
    }];
}

- (void)refreshRoundness
{
    for (TGLetteredAvatarView *avatarView in _avatarViews)
        [avatarView setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect contentFrame = [self classicIOS6GroupedFrame];
    CGFloat spacing = MIN(28.0f, (contentFrame.size.width - TGOnegramAvatarPreviewSide * TGOnegramAvatarPreviewCount) / (TGOnegramAvatarPreviewCount + 1));
    CGFloat totalWidth = TGOnegramAvatarPreviewSide * TGOnegramAvatarPreviewCount + spacing * (TGOnegramAvatarPreviewCount - 1);
    CGFloat x = contentFrame.origin.x + CGFloor((contentFrame.size.width - totalWidth) / 2.0f);
    CGFloat y = CGFloor((self.bounds.size.height - TGOnegramAvatarPreviewSide) / 2.0f);
    for (TGLetteredAvatarView *avatarView in _avatarViews)
    {
        avatarView.frame = CGRectMake(x, y, TGOnegramAvatarPreviewSide, TGOnegramAvatarPreviewSide);
        x += TGOnegramAvatarPreviewSide + spacing;
    }
}

@end

@implementation TGOnegramAvatarPreviewCollectionItem

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

- (Class)itemViewClass
{
    return [TGOnegramAvatarPreviewCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 84.0f);
}

- (void)refresh
{
    [(TGOnegramAvatarPreviewCollectionItemView *)self.boundView refreshRoundness];
}

@end
