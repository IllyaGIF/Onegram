#import "TGStarGiftSheetView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"
#import "../OnegramPlatform/OGPlatformText.h"

#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftCoverView.h"
#import "TGStarGiftUpgradeController.h"
#import "TGStarGiftsSignals.h"
#import "TGAnimatedStickerView.h"
#import "TGShareTargetController.h"
#import "TGCustomActionSheet.h"
#import "TGCustomAlertView.h"
#import "TGInterfaceManager.h"
#import "TGPresentation.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTLDynamic.h"

static const CGFloat TGStarGiftSheetSideInset = 16.0f;
static const CGFloat TGStarGiftSheetUniqueHeaderHeight = 240.0f;
static const CGFloat TGStarGiftSheetRegularHeaderHeight = 210.0f;
static const CGFloat TGStarGiftSheetHeaderButtonHeight = 58.0f;
static const CGFloat TGStarGiftSheetStickerSide = 136.0f;
static const CGFloat TGStarGiftSheetButtonHeight = 52.0f;

static NSString *TGStarGiftSheetPeerName(int64_t peerId)
{
    if (peerId == 0)
        return nil;
    if (TGPeerIdIsUser(peerId))
        return [TGDatabaseInstance() loadUser:peerId].displayName;
    return [TGDatabaseInstance() loadConversationWithId:peerId].chatTitle;
}

static NSString *TGStarGiftSheetCollectibleNumber(int32_t number)
{
    if (number > 9999)
        return TGStarGiftFormattedNumber(number);
    return [[NSString alloc] initWithFormat:@"%d", (int)number];
}

static NSString *TGStarGiftSheetRarityText(int32_t permille, NSString *level, UIColor **color)
{
    if (level.length != 0)
    {
        if ([level isEqualToString:@"Epic"])
            *color = UIColorRGB(0xaf52de);
        else if ([level isEqualToString:@"Legendary"])
            *color = UIColorRGB(0xd57e32);
        else if ([level isEqualToString:@"Rare"])
            *color = UIColorRGB(0x25a3b9);
        else if ([level isEqualToString:@"Uncommon"])
            *color = UIColorRGB(0x22b447);
        return TGLocalized([@"OnegramGifts.Rarity" stringByAppendingString:level]);
    }
    if (permille <= 0)
        return @"<0.1%";
    NSString *value = [[NSString alloc] initWithFormat:@"%0.1f", permille * 0.1];
    if ([value hasSuffix:@".0"])
        value = [value substringToIndex:value.length - 2];
    return [value stringByAppendingString:@"%"];
}

static NSString *TGStarGiftSheetCurrencyString(int64_t amount, NSString *currency)
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = currency;
    NSUInteger fractionDigits = formatter.maximumFractionDigits;
    double value = (double)amount;
    for (NSUInteger i = 0; i < fractionDigits; i++)
        value /= 10.0;
    NSString *string = [formatter stringFromNumber:@(value)];
    if (string.length == 0)
        string = [[NSString alloc] initWithFormat:@"%lld %@", amount, currency];
    return [@"~" stringByAppendingString:string];
}

static UIImage *TGStarGiftSheetMoreIcon(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(32.0f, 32.0f), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    for (NSInteger i = -1; i <= 1; i++)
        CGContextFillEllipseInRect(context, CGRectMake(16.0f + i * 7.0f - 2.0f, 14.0f, 4.0f, 4.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface OGStarGiftSheetValueView : UIView

@property (nonatomic, strong) TGLetteredAvatarView *avatarView;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIButton *pillButton;

- (CGSize)layoutForWidth:(CGFloat)width;

@end

@implementation OGStarGiftSheetValueView

- (CGSize)layoutForWidth:(CGFloat)width
{
    CGFloat x = 0.0f;
    CGFloat height = 0.0f;
    if (_avatarView != nil)
    {
        _avatarView.frame = CGRectMake(0.0f, 0.0f, 22.0f, 22.0f);
        x = 28.0f;
        height = 22.0f;
    }
    CGSize pillSize = CGSizeZero;
    if (_pillButton != nil)
    {
        CGSize titleSize = [_pillButton.titleLabel sizeThatFits:CGSizeMake(width, 18.0f)];
        pillSize = CGSizeMake(CGCeil(titleSize.width) + 12.0f, 18.0f);
    }
    CGFloat labelWidth = MAX(0.0f, width - x - (_pillButton != nil ? pillSize.width + 4.0f : 0.0f));
    CGSize labelSize = [_label sizeThatFits:CGSizeMake(labelWidth, CGFLOAT_MAX)];
    labelSize.width = MIN(labelWidth, CGCeil(labelSize.width));
    labelSize.height = CGCeil(labelSize.height);
    CGFloat labelY = _avatarView != nil ? CGFloor((22.0f - labelSize.height) / 2.0f) : 0.0f;
    _label.frame = CGRectMake(x, labelY, labelSize.width, labelSize.height);
    height = MAX(height, labelY + labelSize.height);
    x += labelSize.width;
    if (_pillButton != nil)
    {
        CGFloat lineHeight = CGCeil(_label.font.ascender - _label.font.descender);
        _pillButton.frame = CGRectMake(x + 4.0f, labelY + CGFloor((lineHeight - pillSize.height) / 2.0f), pillSize.width, pillSize.height);
        x = CGRectGetMaxX(_pillButton.frame);
        height = MAX(height, CGRectGetMaxY(_pillButton.frame));
    }
    return CGSizeMake(x, height);
}

@end

@interface OGStarGiftSheetRow : NSObject

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) OGStarGiftSheetValueView *valueView;
@property (nonatomic) CGFloat valueInset;

@end

@implementation OGStarGiftSheetRow

@end

@interface TGStarGiftSheetView ()
{
    TGSavedStarGift *_savedGift;
    bool _canManage;
    TGPresentationPallete *_pallete;
    __weak UIViewController *_parentController;
    SMetaDisposable *_actionDisposable;
    int64_t _stickerDocumentId;

    TGStarGiftCoverView *_coverView;
    TGAnimatedStickerView *_stickerView;
    TGImageView *_staticStickerView;
    UILabel *_titleLabel;
    UILabel *_numberLabel;
    UILabel *_subtitleLabel;
    TGModernButton *_closeButton;
    TGModernButton *_moreButton;

    NSArray *_headerButtons;
    UIView *_tableView;
    UIView *_titleColumnView;
    UIView *_verticalSeparatorView;
    NSArray *_rowSeparatorViews;
    NSArray *_rows;
    UILabel *_infoLabel;
    TGModernButton *_infoLinkButton;
    TGModernButton *_actionButton;
}

@end

@implementation TGStarGiftSheetView

- (instancetype)initWithSavedGift:(TGSavedStarGift *)gift canManage:(bool)canManage
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _savedGift = gift;
        _canManage = canManage && [gift canManage];
        _pallete = [TGPresentation current].pallete;
        _actionDisposable = [[SMetaDisposable alloc] init];
        self.backgroundColor = _pallete.menuBackgroundColor;

        _coverView = [[TGStarGiftCoverView alloc] init];
        [self addSubview:_coverView];

        _stickerView = [[TGAnimatedStickerView alloc] init];
        _stickerView.loops = false;
        _stickerView.usesSourceFrameRate = true;
        [self addSubview:_stickerView];

        _staticStickerView = [[TGImageView alloc] init];
        _staticStickerView.contentMode = UIViewContentModeScaleAspectFit;
        _staticStickerView.hidden = true;
        [self addSubview:_staticStickerView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(20.0f);
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _numberLabel = [[UILabel alloc] init];
        _numberLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_numberLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13.0f);
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 5;
        [self addSubview:_subtitleLabel];

        _closeButton = [[TGModernButton alloc] init];
        _closeButton.layer.cornerRadius = 22.0f;
        _closeButton.adjustsImageWhenHighlighted = false;
        [_closeButton addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeButton];

        _moreButton = [[TGModernButton alloc] init];
        _moreButton.layer.cornerRadius = 22.0f;
        _moreButton.adjustsImageWhenHighlighted = false;
        [_moreButton addTarget:self action:@selector(morePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_moreButton];

        [self updateHeader];
        [self rebuildContent];
    }
    return self;
}

- (void)dealloc
{
    [_actionDisposable dispose];
}

- (void)presentFromController:(UIViewController *)controller
{
    _parentController = controller;
    [TGOnegramCardOverlay presentCardView:self placement:TGOnegramCardPlacementSheet parentController:controller];
}

- (void)cardWillAppear
{
    _stickerView.playing = !_stickerView.hidden;
}

- (void)cardDidDisappear
{
    _stickerView.playing = false;
}

- (bool)hasCover
{
    return _savedGift.gift.unique && _savedGift.gift.hasBackdrop;
}

- (UIColor *)controlColor
{
    TGStarGift *gift = _savedGift.gift;
    if ([self hasCover])
        return TGStarGiftMixedColor(TGStarGiftColor(gift.backdropEdgeColor), [UIColor whiteColor], 0.2f);
    return TGStarGiftMixedColor(_pallete.menuBackgroundColor, _pallete.menuTextColor, _pallete.isDark ? 0.08f : 0.05f);
}

- (UIColor *)vibrantColor
{
    UIColor *innerColor = TGStarGiftColor(_savedGift.gift.backdropCenterColor);
    return TGStarGiftMixedColor(TGStarGiftMultipliedColor(innerColor, 1.0f, 1.02f, 1.25f), [UIColor whiteColor], 0.3f);
}

- (int64_t)ownerPeerId
{
    TGStarGift *gift = _savedGift.gift;
    return gift.ownerPeerId != 0 ? gift.ownerPeerId : _savedGift.ownerPeerId;
}

- (void)updateHeader
{
    TGStarGift *gift = _savedGift.gift;
    bool cover = [self hasCover];
    _coverView.hidden = !cover;
    [_coverView setGift:cover ? gift : nil];

    TGDocumentMediaAttachment *sticker = gift.sticker;
    bool animatedSticker = sticker != nil && [TGAnimatedStickerView isAnimatedStickerDocument:sticker];
    _stickerView.hidden = !animatedSticker;
    _staticStickerView.hidden = animatedSticker || sticker == nil;
    if (sticker.documentId != _stickerDocumentId)
    {
        _stickerDocumentId = sticker.documentId;
        NSString *placeholderUri = sticker != nil ? [TGAnimatedStickerView placeholderUriForDocument:sticker size:CGSizeMake(TGStarGiftSheetStickerSide * 2.0f, TGStarGiftSheetStickerSide * 2.0f)] : nil;
        if (animatedSticker)
            [_stickerView setDocument:sticker placeholderUri:placeholderUri];
        else if (sticker != nil)
            [_staticStickerView loadUri:placeholderUri withOptions:@{}];
    }

    UIColor *controlColor = [self controlColor];
    UIColor *iconColor = cover ? [UIColor whiteColor] : _pallete.menuSecondaryTextColor;
    _closeButton.backgroundColor = controlColor;
    [_closeButton setImage:TGTintedImage(TGImageNamed(@"StarGiftCloseIcon"), iconColor) forState:UIControlStateNormal];
    _moreButton.backgroundColor = controlColor;
    [_moreButton setImage:TGStarGiftSheetMoreIcon(iconColor) forState:UIControlStateNormal];
    _moreButton.hidden = !_canManage && !(gift.unique && gift.slug.length != 0);

    if (gift.unique)
    {
        _titleLabel.text = gift.title;
        _titleLabel.textColor = cover ? [UIColor whiteColor] : _pallete.menuTextColor;
        _numberLabel.text = [@"#" stringByAppendingString:TGStarGiftSheetCollectibleNumber(gift.number)];
        _numberLabel.font = TGBoldSystemFontOfSize(gift.number < 1000 ? 20.0f : 15.0f);
        _numberLabel.textColor = cover ? [self vibrantColor] : _pallete.menuSecondaryTextColor;
        _numberLabel.hidden = false;
        _subtitleLabel.text = gift.modelName.length != 0 ? gift.modelName : TGLocalized(@"OnegramGifts.Collectible");
        _subtitleLabel.textColor = cover ? [self vibrantColor] : _pallete.menuSecondaryTextColor;
        _subtitleLabel.hidden = false;
    }
    else
    {
        _titleLabel.text = gift.title.length != 0 ? gift.title : TGLocalized(@"OnegramGifts.Gift");
        _titleLabel.textColor = _pallete.menuTextColor;
        _numberLabel.hidden = true;
        _subtitleLabel.hidden = true;
    }
}

- (UILabel *)tableLabelWithText:(NSString *)text color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.font = TGSystemFontOfSize(15.0f);
    label.textColor = color;
    label.text = text;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (UIButton *)pillButtonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = TGSystemFontOfSize(11.0f);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.backgroundColor = [color colorWithAlphaComponent:0.1f];
    button.layer.cornerRadius = 9.0f;
    button.userInteractionEnabled = action != NULL;
    if (action != NULL)
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (OGStarGiftSheetRow *)rowWithTitle:(NSString *)title text:(NSString *)text
{
    OGStarGiftSheetRow *row = [[OGStarGiftSheetRow alloc] init];
    if (title != nil)
        row.titleLabel = [self tableLabelWithText:title color:_pallete.menuTextColor];
    row.valueView = [[OGStarGiftSheetValueView alloc] init];
    row.valueView.label = [self tableLabelWithText:text color:_pallete.menuTextColor];
    row.valueView.label.numberOfLines = 0;
    row.valueView.label.lineBreakMode = NSLineBreakByWordWrapping;
    [row.valueView addSubview:row.valueView.label];
    row.valueInset = 12.0f;
    return row;
}

- (void)row:(OGStarGiftSheetRow *)row setPill:(UIButton *)pill
{
    row.valueView.pillButton = pill;
    [row.valueView addSubview:pill];
}

- (OGStarGiftSheetRow *)rarityRowWithTitle:(NSString *)title name:(NSString *)name permille:(int32_t)permille level:(NSString *)level
{
    OGStarGiftSheetRow *row = [self rowWithTitle:title text:name];
    UIColor *color = _pallete.menuAccentColor;
    NSString *rarity = TGStarGiftSheetRarityText(permille, level, &color);
    [self row:row setPill:[self pillButtonWithTitle:rarity color:color action:NULL]];
    return row;
}

- (OGStarGiftSheetRow *)peerRowWithTitle:(NSString *)title peerId:(int64_t)peerId name:(NSString *)name anonymous:(bool)anonymous
{
    bool tappable = TGPeerIdIsUser(peerId);
    OGStarGiftSheetRow *row = [self rowWithTitle:title text:name];
    row.valueView.label.numberOfLines = 1;
    row.valueView.label.lineBreakMode = NSLineBreakByTruncatingTail;
    if (peerId != 0 || anonymous)
    {
        TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] init];
        [avatarView setSingleFontSize:9.0f doubleFontSize:9.0f useBoldFont:true];
        if (anonymous)
            [avatarView loadImage:TGStarGiftAnonymousAvatarImage(22.0f)];
        else
            TGStarGiftSetPeerAvatar(avatarView, peerId, 22.0f, [TGPresentation current]);
        row.valueView.avatarView = avatarView;
        [row.valueView addSubview:avatarView];
    }
    if (tappable)
    {
        row.valueView.label.textColor = _pallete.menuAccentColor;
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(peerRowTapped:)];
        [row.valueView addGestureRecognizer:recognizer];
    }
    return row;
}

- (NSArray *)buildRows
{
    TGStarGift *gift = _savedGift.gift;
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    if (gift.unique)
    {
        int64_t ownerPeerId = [self ownerPeerId];
        NSString *ownerName = gift.ownerName.length != 0 ? gift.ownerName : TGStarGiftSheetPeerName(ownerPeerId);
        if (ownerName.length != 0)
            [rows addObject:[self peerRowWithTitle:TGLocalized(@"OnegramGifts.Owner") peerId:ownerPeerId name:ownerName anonymous:false]];
        if (gift.modelName.length != 0)
            [rows addObject:[self rarityRowWithTitle:TGLocalized(@"OnegramGifts.Model") name:gift.modelName permille:gift.modelRarityPermille level:gift.modelRarityLevel]];
        if (gift.patternName.length != 0)
            [rows addObject:[self rarityRowWithTitle:TGLocalized(@"OnegramGifts.Pattern") name:gift.patternName permille:gift.patternRarityPermille level:gift.patternRarityLevel]];
        if (gift.backdropName.length != 0)
            [rows addObject:[self rarityRowWithTitle:TGLocalized(@"OnegramGifts.Backdrop") name:gift.backdropName permille:gift.backdropRarityPermille level:gift.backdropRarityLevel]];
        if (gift.availabilityTotal > 0)
        {
            NSString *issued = [[NSString alloc] initWithFormat:@"%@/%@", TGStarGiftFormattedNumber(gift.availabilityRemains), TGStarGiftFormattedNumber(gift.availabilityTotal)];
            [rows addObject:[self rowWithTitle:TGLocalized(@"OnegramGifts.Availability") text:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.Issued"), issued]]];
        }
        if (gift.valueAmount > 0 && gift.valueCurrency.length != 0)
        {
            OGStarGiftSheetRow *row = [self rowWithTitle:TGLocalized(@"OnegramGifts.Value") text:TGStarGiftSheetCurrencyString(gift.valueAmount, gift.valueCurrency)];
            row.valueInset = 10.0f;
            [rows addObject:row];
        }
        return rows;
    }

    bool anonymous = _savedGift.fromPeerId == 0;
    NSString *fromName = anonymous ? TGLocalized(@"OnegramGifts.Anonymous") : TGStarGiftSheetPeerName(_savedGift.fromPeerId);
    if (fromName.length != 0)
        [rows addObject:[self peerRowWithTitle:TGLocalized(@"OnegramGifts.From") peerId:anonymous ? 0 : _savedGift.fromPeerId name:fromName anonymous:anonymous]];
    if (_savedGift.date != 0)
        [rows addObject:[self rowWithTitle:TGLocalized(@"OnegramGifts.Date") text:[TGDateUtils stringForPreciseDate:_savedGift.date]]];
    if (gift.stars > 0)
    {
        OGStarGiftSheetRow *row = [self rowWithTitle:TGLocalized(@"OnegramGifts.Value") text:TGStarGiftStarsString(gift.stars)];
        row.valueInset = 10.0f;
        if (_canManage && [_savedGift canConvert])
            [self row:row setPill:[self pillButtonWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.SellFor"), TGStarGiftStarsString(_savedGift.convertStars)] color:_pallete.menuAccentColor action:@selector(convertPressed)]];
        [rows addObject:row];
    }
    if (gift.limited && gift.availabilityTotal > 0)
        [rows addObject:[self rowWithTitle:TGLocalized(@"OnegramGifts.Availability") text:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.AvailabilityValue"), TGStarGiftFormattedNumber(gift.availabilityRemains), TGStarGiftFormattedNumber(gift.availabilityTotal)]]];
    if (!gift.soldOut && _savedGift.canUpgrade)
    {
        OGStarGiftSheetRow *row = [self rowWithTitle:TGLocalized(@"OnegramGifts.Status") text:TGLocalized(@"OnegramGifts.NonUnique")];
        row.valueInset = 10.0f;
        if (_canManage)
            [self row:row setPill:[self pillButtonWithTitle:TGLocalized(@"OnegramGifts.UpgradePill") color:_pallete.menuAccentColor action:@selector(upgradePressed)]];
        [rows addObject:row];
    }
    if (_savedGift.message.length != 0)
    {
        [rows addObject:[self rowWithTitle:nil text:_savedGift.message]];
    }
    return rows;
}

- (TGModernButton *)headerButtonWithTitle:(NSString *)title iconName:(NSString *)iconName action:(SEL)action
{
    TGModernButton *button = [[TGModernButton alloc] init];
    button.backgroundColor = [self controlColor];
    button.layer.cornerRadius = 16.0f;
    UIImageView *iconView = [[UIImageView alloc] initWithImage:TGTintedImage(TGImageNamed(iconName), [UIColor whiteColor])];
    iconView.tag = 1;
    [button addSubview:iconView];
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = TGSystemFontOfSize(11.0f);
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = title;
    titleLabel.tag = 2;
    [button addSubview:titleLabel];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)rebuildContent
{
    for (UIView *view in _headerButtons)
        [view removeFromSuperview];
    [_tableView removeFromSuperview];
    [_infoLabel removeFromSuperview];
    [_infoLinkButton removeFromSuperview];
    [_actionButton removeFromSuperview];

    TGStarGift *gift = _savedGift.gift;
    NSMutableArray *headerButtons = [[NSMutableArray alloc] init];
    if (_canManage && [self hasCover])
    {
        if ([_savedGift canTransfer])
            [headerButtons addObject:[self headerButtonWithTitle:TGLocalized(@"OnegramGifts.HeaderTransfer") iconName:@"StarGiftTransferIcon" action:@selector(transferPressed)]];
        if ([_savedGift canResell])
        {
            bool listed = gift.resellAmounts.count != 0;
            [headerButtons addObject:[self headerButtonWithTitle:TGLocalized(listed ? @"OnegramGifts.HeaderUnlist" : @"OnegramGifts.HeaderSell") iconName:listed ? @"StarGiftUnlistIcon" : @"StarGiftSellIcon" action:listed ? @selector(stopResellPressed) : @selector(resellPressed)]];
        }
    }
    for (UIView *view in headerButtons)
        [self addSubview:view];
    _headerButtons = headerButtons;

    _rows = [self buildRows];
    _tableView = [[UIView alloc] init];
    _tableView.clipsToBounds = true;
    _tableView.layer.cornerRadius = 14.0f;
    _tableView.layer.borderWidth = 1.0f;
    UIColor *borderColor = TGStarGiftMixedColor(_pallete.menuBackgroundColor, _pallete.menuSeparatorColor, 0.6f);
    _tableView.layer.borderColor = borderColor.CGColor;
    _titleColumnView = [[UIView alloc] init];
    _titleColumnView.backgroundColor = TGStarGiftMixedColor(_pallete.menuBackgroundColor, _pallete.menuTextColor, _pallete.isDark ? 0.08f : 0.05f);
    [_tableView addSubview:_titleColumnView];
    NSMutableArray *separators = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i + 1 < _rows.count; i++)
    {
        UIView *separator = [[UIView alloc] init];
        separator.backgroundColor = borderColor;
        [_tableView addSubview:separator];
        [separators addObject:separator];
    }
    _rowSeparatorViews = separators;
    _verticalSeparatorView = [[UIView alloc] init];
    _verticalSeparatorView.backgroundColor = borderColor;
    [_tableView addSubview:_verticalSeparatorView];
    for (OGStarGiftSheetRow *row in _rows)
    {
        if (row.titleLabel != nil)
            [_tableView addSubview:row.titleLabel];
        [_tableView addSubview:row.valueView];
    }
    [self addSubview:_tableView];

    _infoLabel = nil;
    _infoLinkButton = nil;
    if (_canManage)
    {
        _infoLabel = [[UILabel alloc] init];
        _infoLabel.backgroundColor = [UIColor clearColor];
        _infoLabel.font = TGSystemFontOfSize(13.0f);
        _infoLabel.textColor = _pallete.menuSecondaryTextColor;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        _infoLabel.text = TGLocalized(_savedGift.unsaved ? @"OnegramGifts.HiddenInfo" : @"OnegramGifts.DisplayedInfo");
        [self addSubview:_infoLabel];

        _infoLinkButton = [[TGModernButton alloc] init];
        _infoLinkButton.titleLabel.font = TGSystemFontOfSize(13.0f);
        [_infoLinkButton setTitleColor:_pallete.menuAccentColor];
        [_infoLinkButton setTitle:[TGLocalized(_savedGift.unsaved ? @"OnegramGifts.ShowOnProfile" : @"OnegramGifts.HideFromProfile") stringByAppendingString:@" ›"] forState:UIControlStateNormal];
        [_infoLinkButton addTarget:self action:@selector(toggleVisibilityPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_infoLinkButton];
    }

    NSString *actionTitle = TGLocalized(@"Common.OK");
    SEL action = @selector(closePressed);
    if (_canManage && !gift.unique && _savedGift.canUpgrade)
    {
        actionTitle = TGLocalized(@"OnegramGifts.UpgradeAction");
        action = @selector(upgradePressed);
    }
    else if (_canManage && _savedGift.unsaved)
    {
        actionTitle = TGLocalized(@"OnegramGifts.Display");
        action = @selector(toggleVisibilityPressed);
    }
    _actionButton = [[TGModernButton alloc] init];
    _actionButton.backgroundColor = _pallete.menuAccentColor;
    _actionButton.layer.cornerRadius = TGStarGiftSheetButtonHeight / 2.0f;
    _actionButton.titleLabel.font = TGSemiboldSystemFontOfSize(17.0f);
    [_actionButton setTitleColor:_pallete.accentContrastColor];
    [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
    [_actionButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_actionButton];

    [self setNeedsLayout];
}

- (CGFloat)headerHeight
{
    if (!_savedGift.gift.unique)
        return TGStarGiftSheetRegularHeaderHeight;
    CGFloat height = TGStarGiftSheetUniqueHeaderHeight;
    if (_headerButtons.count != 0)
        height += TGStarGiftSheetHeaderButtonHeight + 16.0f;
    return height;
}

- (CGFloat)layoutForWidth:(CGFloat)width
{
    TGStarGift *gift = _savedGift.gift;
    CGFloat headerHeight = [self headerHeight];
    CGFloat centerX = width / 2.0f;

    _coverView.frame = CGRectMake(0.0f, 0.0f, width, headerHeight);
    _coverView.avatarCenter = CGPointMake(centerX, 104.0f);
    _coverView.defaultHeight = 300.0f;
    _coverView.gradientFrame = CGRectMake(CGFloor((width - 300.0f) / 2.0f), -250.0f, 300.0f, 550.0f);

    CGRect stickerFrame = CGRectMake(CGFloor(centerX - TGStarGiftSheetStickerSide / 2.0f), 88.0f - TGStarGiftSheetStickerSide / 2.0f, TGStarGiftSheetStickerSide, TGStarGiftSheetStickerSide);
    _stickerView.frame = stickerFrame;
    _staticStickerView.frame = stickerFrame;

    _closeButton.frame = CGRectMake(16.0f, 16.0f, 44.0f, 44.0f);
    _moreButton.frame = CGRectMake(width - 16.0f - 44.0f, 16.0f, 44.0f, 44.0f);

    CGFloat titleMaxWidth = width - TGStarGiftSheetSideInset * 2.0f - 60.0f;
    CGSize numberSize = _numberLabel.hidden ? CGSizeZero : [_numberLabel sizeThatFits:CGSizeMake(titleMaxWidth, CGFLOAT_MAX)];
    numberSize.width = CGCeil(numberSize.width);
    CGFloat numberSpacing = _numberLabel.hidden ? 0.0f : CGCeil(OGPlatformTextSize(@" ", _titleLabel.font, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), UILineBreakModeClip).width);
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(titleMaxWidth, CGFLOAT_MAX)];
    titleSize.width = MIN(CGCeil(titleSize.width), MAX(0.0f, titleMaxWidth - numberSpacing - numberSize.width));
    titleSize.height = CGCeil(titleSize.height);
    CGFloat titleCenterY = gift.unique ? 190.0f : 173.0f;
    CGFloat titleX = CGFloor(centerX - (titleSize.width + numberSpacing + numberSize.width) / 2.0f);
    _titleLabel.frame = CGRectMake(titleX, CGFloor(titleCenterY - titleSize.height / 2.0f), titleSize.width, titleSize.height);
    if (!_numberLabel.hidden)
    {
        CGFloat baselineOffset = _titleLabel.font.ascender - _numberLabel.font.ascender;
        _numberLabel.frame = CGRectMake(CGRectGetMaxX(_titleLabel.frame) + numberSpacing, CGRectGetMinY(_titleLabel.frame) + CGFloor(baselineOffset), numberSize.width, CGCeil(numberSize.height));
    }
    if (!_subtitleLabel.hidden)
    {
        CGFloat subtitleMaxWidth = width - TGStarGiftSheetSideInset * 2.0f - 50.0f;
        CGSize subtitleSize = [_subtitleLabel sizeThatFits:CGSizeMake(subtitleMaxWidth, CGFLOAT_MAX)];
        subtitleSize.width = MIN(subtitleMaxWidth, CGCeil(subtitleSize.width));
        _subtitleLabel.frame = CGRectMake(CGFloor(centerX - subtitleSize.width / 2.0f), 207.0f, subtitleSize.width, CGCeil(subtitleSize.height));
    }

    if (_headerButtons.count != 0)
    {
        CGFloat spacing = 10.0f;
        CGFloat buttonWidth = CGFloor((width - TGStarGiftSheetSideInset * 2.0f - spacing * (_headerButtons.count - 1)) / _headerButtons.count);
        CGFloat buttonY = headerHeight - TGStarGiftSheetHeaderButtonHeight - 16.0f;
        CGFloat x = TGStarGiftSheetSideInset;
        for (UIView *button in _headerButtons)
        {
            button.frame = CGRectMake(x, buttonY, buttonWidth, TGStarGiftSheetHeaderButtonHeight);
            UIView *iconView = [button viewWithTag:1];
            iconView.frame = CGRectMake(CGFloor((buttonWidth - 30.0f) / 2.0f), 22.0f - 15.0f, 30.0f, 30.0f);
            UILabel *titleLabel = (UILabel *)[button viewWithTag:2];
            CGFloat labelHeight = CGCeil(titleLabel.font.ascender - titleLabel.font.descender);
            titleLabel.frame = CGRectMake(4.0f, CGFloor(42.0f - labelHeight / 2.0f), buttonWidth - 8.0f, labelHeight);
            x += buttonWidth + spacing;
        }
    }

    CGFloat originY = headerHeight + (_subtitleLabel.hidden ? 9.0f : 16.0f);
    CGFloat tableWidth = width - TGStarGiftSheetSideInset * 2.0f;
    CGFloat titleColumnWidth = 100.0f;
    for (OGStarGiftSheetRow *row in _rows)
    {
        if (row.titleLabel != nil)
            titleColumnWidth = MAX(titleColumnWidth, CGCeil([row.titleLabel sizeThatFits:CGSizeMake(tableWidth, CGFLOAT_MAX)].width) + 24.0f);
    }
    CGFloat rowY = 0.0f;
    CGFloat titledHeight = 0.0f;
    for (NSUInteger i = 0; i < _rows.count; i++)
    {
        OGStarGiftSheetRow *row = [_rows objectAtIndex:i];
        bool titled = row.titleLabel != nil;
        CGFloat valueX = titled ? titleColumnWidth + row.valueInset : 12.0f;
        CGFloat valueWidth = tableWidth - valueX - 12.0f;
        CGSize valueSize = [row.valueView layoutForWidth:valueWidth];
        CGFloat contentHeight = valueSize.height;
        if (titled)
        {
            CGSize titleLabelSize = [row.titleLabel sizeThatFits:CGSizeMake(titleColumnWidth - 24.0f, CGFLOAT_MAX)];
            row.titleLabel.frame = CGRectMake(12.0f, rowY + 11.0f, titleColumnWidth - 24.0f, CGCeil(titleLabelSize.height));
            contentHeight = MAX(contentHeight, CGCeil(titleLabelSize.height));
        }
        CGFloat rowHeight = MAX(40.0f, contentHeight + 22.0f);
        row.valueView.frame = CGRectMake(valueX, rowY + 11.0f, valueWidth, valueSize.height);
        rowY += rowHeight;
        if (titled)
            titledHeight = rowY;
        if (i < _rowSeparatorViews.count)
            ((UIView *)[_rowSeparatorViews objectAtIndex:i]).frame = CGRectMake(0.0f, rowY - 1.0f, tableWidth, 1.0f);
    }
    _titleColumnView.frame = CGRectMake(0.0f, 0.0f, titleColumnWidth, titledHeight);
    _verticalSeparatorView.frame = CGRectMake(titleColumnWidth - 1.0f, 0.0f, 1.0f, titledHeight);
    _tableView.frame = CGRectMake(TGStarGiftSheetSideInset, originY, tableWidth, rowY);
    _tableView.hidden = _rows.count == 0;
    if (_rows.count != 0)
        originY += rowY + 23.0f;

    if (_infoLabel != nil)
    {
        originY -= 5.0f;
        CGFloat maxWidth = width - TGStarGiftSheetSideInset * 2.0f - 60.0f;
        CGSize infoSize = [_infoLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
        CGSize linkSize = [_infoLinkButton.titleLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
        infoSize = CGSizeMake(CGCeil(infoSize.width), CGCeil(infoSize.height));
        linkSize = CGSizeMake(CGCeil(linkSize.width), CGCeil(linkSize.height));
        if (infoSize.width + 4.0f + linkSize.width <= maxWidth)
        {
            CGFloat x = CGFloor(centerX - (infoSize.width + 4.0f + linkSize.width) / 2.0f);
            _infoLabel.frame = CGRectMake(x, originY, infoSize.width, infoSize.height);
            _infoLinkButton.frame = CGRectMake(x + infoSize.width + 4.0f, originY, linkSize.width, infoSize.height);
            originY += infoSize.height;
        }
        else
        {
            _infoLabel.frame = CGRectMake(CGFloor(centerX - MIN(maxWidth, infoSize.width) / 2.0f), originY, MIN(maxWidth, infoSize.width), infoSize.height);
            originY += infoSize.height;
            _infoLinkButton.frame = CGRectMake(CGFloor(centerX - linkSize.width / 2.0f), originY, linkSize.width, linkSize.height);
            originY += linkSize.height;
        }
        originY += 16.0f;
    }

    _actionButton.frame = CGRectMake(30.0f, originY, width - 60.0f, TGStarGiftSheetButtonHeight);
    originY += TGStarGiftSheetButtonHeight + 12.0f;
    return originY;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
    return [self layoutForWidth:width];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self layoutForWidth:self.bounds.size.width];
}

- (void)dismissThen:(void (^)(void))completion
{
    TGOnegramCardOverlay *overlay = self.overlay;
    if (overlay == nil)
    {
        if (completion != nil)
            completion();
        return;
    }
    [overlay dismissAnimated:true completion:completion];
}

- (void)closePressed
{
    [self dismissThen:nil];
}

- (void)applyUpdatedGift:(TGSavedStarGift *)gift
{
    _savedGift = gift;
    [self updateHeader];
    [self rebuildContent];
    [self.overlay setNeedsCardLayoutAnimated:true];
    if (_giftUpdated != nil)
        _giftUpdated(gift);
}

- (void)runAction:(SSignal *)signal completion:(void (^)(void))completion
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    [_actionDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ActionFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
        completion();
    }]];
}

- (void)morePressed
{
    TGStarGift *gift = _savedGift.gift;
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (_canManage && !_savedGift.unsaved)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(_savedGift.pinnedToTop ? @"OnegramGifts.Unpin" : @"OnegramGifts.Pin") action:@"pin"]];
    if (_canManage && gift.unique && [_savedGift canResell] && gift.resellAmounts.count != 0)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramGifts.ChangePrice") action:@"price"]];
    if (gift.unique && gift.slug.length != 0)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramGifts.CopyLink") action:@"link"]];
    if (_canManage)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(_savedGift.unsaved ? @"OnegramGifts.ShowOnProfile" : @"OnegramGifts.HideFromProfile") action:@"visibility"]];
    if (_canManage && gift.unique && [_savedGift canTransfer])
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramGifts.Transfer") action:@"transfer"]];
    if (actions.count == 0)
        return;
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
    [[[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(id target, NSString *action)
    {
        TGStarGiftSheetView *sheet = target;
        if ([action isEqualToString:@"pin"])
            [sheet togglePinPressed];
        else if ([action isEqualToString:@"price"])
            [sheet resellPressed];
        else if ([action isEqualToString:@"link"])
            [sheet copyLinkPressed];
        else if ([action isEqualToString:@"visibility"])
            [sheet toggleVisibilityPressed];
        else if ([action isEqualToString:@"transfer"])
            [sheet transferPressed];
    } target:self] showInView:self];
}

- (void)copyLinkPressed
{
    NSString *slug = _savedGift.gift.slug;
    if (slug.length == 0)
        return;
    [UIPasteboard generalPasteboard].string = [@"https://t.me/nft/" stringByAppendingString:slug];
    [[[TGProgressWindow alloc] init] dismissWithSuccess];
}

- (void)peerRowTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;
    int64_t peerId = _savedGift.gift.unique ? [self ownerPeerId] : _savedGift.fromPeerId;
    if (!TGPeerIdIsUser(peerId))
        return;
    [self dismissThen:^
    {
        [[TGInterfaceManager instance] navigateToProfileOfUser:peerId];
    }];
}

- (void)toggleVisibilityPressed
{
    if (!_canManage)
        return;
    bool saved = _savedGift.unsaved;
    TGSavedStarGift *updated = [_savedGift savedStarGiftWithUnsaved:!saved];
    __weak TGStarGiftSheetView *weakSelf = self;
    [self runAction:[TGStarGiftsSignals setGift:_savedGift saved:saved] completion:^
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        [strongSelf applyUpdatedGift:updated];
    }];
}

- (void)togglePinPressed
{
    if (!_canManage)
        return;
    bool pinned = !_savedGift.pinnedToTop;
    TGSavedStarGift *updated = [_savedGift savedStarGiftWithPinnedToTop:pinned];
    __weak TGStarGiftSheetView *weakSelf = self;
    [self runAction:[TGStarGiftsSignals setGift:_savedGift pinnedToTop:pinned] completion:^
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        [strongSelf applyUpdatedGift:updated];
        if (pinned)
            [strongSelf dismissThen:nil];
    }];
}

- (void)convertPressed
{
    if (!_canManage || ![_savedGift canConvert])
        return;
    __weak TGStarGiftSheetView *weakSelf = self;
    NSString *message = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ConvertConfirm"), TGStarGiftStarsString(_savedGift.convertStars)];
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.ConvertAction") completionBlock:^(bool okButtonPressed)
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        if (strongSelf == nil || !okButtonPressed)
            return;
        TGSavedStarGift *gift = strongSelf->_savedGift;
        [strongSelf runAction:[TGStarGiftsSignals convertGift:gift] completion:^
        {
            __strong TGStarGiftSheetView *innerSelf = weakSelf;
            if (innerSelf == nil)
                return;
            if (innerSelf.giftRemoved != nil)
                innerSelf.giftRemoved(gift);
            [innerSelf dismissThen:nil];
        }];
    }];
}

- (void)upgradePressed
{
    if (!_canManage || !_savedGift.canUpgrade || _savedGift.gift.unique)
        return;
    UINavigationController *navigationController = _parentController.navigationController;
    TGSavedStarGift *gift = _savedGift;
    [self dismissThen:^
    {
        [navigationController pushViewController:[[TGStarGiftUpgradeController alloc] initWithSavedGift:gift] animated:true];
    }];
}

- (void)transferPressed
{
    if (!_canManage || ![_savedGift canTransfer])
        return;
    UIViewController *parentController = _parentController;
    UINavigationController *navigationController = parentController.navigationController;
    if (navigationController == nil)
        return;
    TGShareTargetController *picker = [[TGShareTargetController alloc] init];
    picker.presentation = [TGPresentation current];
    picker.completionBlock = ^(NSArray *selectedPeerIds)
    {
        if (selectedPeerIds.count != 1 || !TGPeerIdIsUser([[selectedPeerIds objectAtIndex:0] longLongValue]))
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.TransferSelectOne") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            return;
        }
        int64_t peerId = [[selectedPeerIds objectAtIndex:0] longLongValue];
        if (peerId == TGTelegraphInstance.clientUserId)
            return;
        [self confirmTransferToPeer:peerId parentController:parentController];
    };
    [self dismissThen:^
    {
        [navigationController pushViewController:picker animated:true];
    }];
}

- (void)confirmTransferToPeer:(int64_t)peerId parentController:(UIViewController *)parentController
{
    TGSavedStarGift *gift = _savedGift;
    int64_t fee = gift.transferStars;
    if (fee < 0)
        return;
    NSString *recipient = TGStarGiftSheetPeerName(peerId);
    if (recipient.length == 0)
        recipient = [[NSString alloc] initWithFormat:@"%lld", peerId];
    NSString *message = fee > 0 ? [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.TransferPaidConfirm"), recipient, TGStarGiftStarsString(fee)] : [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.TransferConfirm"), recipient];
    __weak TGStarGiftSheetView *weakSelf = self;
    __weak UIViewController *weakParentController = parentController;
    void (^confirm)(void) = ^
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.Transfer") completionBlock:^(bool confirmed)
        {
            __strong TGStarGiftSheetView *strongSelf = weakSelf;
            if (strongSelf == nil || !confirmed)
                return;
            [strongSelf runAction:[TGStarGiftsSignals transferGift:gift toPeerId:peerId expectedStars:fee] completion:^
            {
                __strong TGStarGiftSheetView *innerSelf = weakSelf;
                if (innerSelf.giftRemoved != nil)
                    innerSelf.giftRemoved(gift);
                __strong UIViewController *strongParentController = weakParentController;
                if (strongParentController != nil)
                    [strongParentController.navigationController popToViewController:strongParentController animated:true];
            }];
        }];
    };
    if (fee == 0)
    {
        confirm();
        return;
    }
    [_actionDisposable setDisposable:[[[TGStarGiftsSignals starsBalance] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *balance)
    {
        if (fee > [balance longLongValue])
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.InsufficientStars") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        else
            confirm();
    } error:^(__unused id error)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ActionFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil]];
}

- (void)resellPressed
{
    if (!_canManage || ![_savedGift canResell])
        return;
    int64_t existingPrice = TGStarGiftResaleStars(_savedGift.gift);
    NSString *text = existingPrice > 0 ? [[NSString alloc] initWithFormat:@"%lld", existingPrice] : nil;
    __weak TGStarGiftSheetView *weakSelf = self;
    [TGCustomAlertView presentTextInputAlertWithTitle:TGLocalized(@"OnegramGifts.SetResalePrice") message:TGLocalized(@"OnegramGifts.ResalePriceHint") placeholder:TGLocalized(@"OnegramGifts.ResalePricePlaceholder") text:text keyboardType:UIKeyboardTypeNumberPad cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(NSString *enteredText)
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        [strongSelf resalePriceEntered:enteredText];
    }];
}

- (void)refreshGiftAfterResale
{
    __weak TGStarGiftSheetView *weakSelf = self;
    [_actionDisposable setDisposable:[[[TGStarGiftsSignals savedGift:_savedGift] deliverOn:[SQueue mainQueue]] startWithNext:^(TGSavedStarGift *gift)
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyUpdatedGift:gift];
    } error:^(__unused id error)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ActionFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil]];
}

- (void)stopResellPressed
{
    if (!_canManage || ![_savedGift canResell] || _savedGift.gift.resellAmounts.count == 0)
        return;
    __weak TGStarGiftSheetView *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.StopResaleConfirm") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.StopResale") completionBlock:^(bool confirmed)
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        if (strongSelf == nil || !confirmed)
            return;
        [strongSelf runAction:[TGStarGiftsSignals setResalePrice:0 forGift:strongSelf->_savedGift] completion:^
        {
            __strong TGStarGiftSheetView *updatedSelf = weakSelf;
            [updatedSelf refreshGiftAfterResale];
        }];
    }];
}

- (void)resalePriceEntered:(NSString *)text
{
    NSString *input = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int64_t price = input.length != 0 && input.length <= 18 && [input rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound ? [input longLongValue] : 0;
    if (price <= 0)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ResalePriceInvalid") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        return;
    }
    NSString *confirmation = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ResaleConfirm"), TGStarGiftStarsString(price)];
    __weak TGStarGiftSheetView *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:confirmation cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.SetResalePrice") completionBlock:^(bool confirmed)
    {
        __strong TGStarGiftSheetView *strongSelf = weakSelf;
        if (strongSelf == nil || !confirmed)
            return;
        [strongSelf runAction:[TGStarGiftsSignals setResalePrice:price forGift:strongSelf->_savedGift] completion:^
        {
            __strong TGStarGiftSheetView *updatedSelf = weakSelf;
            [updatedSelf refreshGiftAfterResale];
        }];
    }];
}

@end
