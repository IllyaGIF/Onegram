#import "TGStarGiftUpgradeController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGCollectionMenuSection.h"
#import "TGVariantCollectionItem.h"
#import "TGVariantCollectionItemView.h"
#import "TGButtonCollectionItem.h"
#import "TGStarGiftHeaderCollectionItem.h"
#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftsSignals.h"
#import "TGCustomAlertView.h"
#import "TGPresentation.h"
#import "TGTLDynamic.h"

static NSString *TGStarGiftRarityDescription(int32_t permille)
{
    if (permille <= 0)
        return nil;
    CGFloat percentage = (CGFloat)permille / 10.0f;
    return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.RarityPercent"), percentage];
}

@interface OGStarGiftRarityItemView : TGVariantCollectionItemView

@property (nonatomic, strong) UILabel *rarityLabel;

- (void)setRarityText:(NSString *)rarityText;

@end

@implementation OGStarGiftRarityItemView

- (void)setRarityText:(NSString *)rarityText
{
    if (_rarityLabel == nil)
    {
        _rarityLabel = [[UILabel alloc] init];
        _rarityLabel.backgroundColor = self.presentation.pallete.collectionMenuAccentColor ?: UIColorRGB(0x417fba);
        _rarityLabel.textColor = [UIColor whiteColor];
        _rarityLabel.font = TGBoldSystemFontOfSize(11.0f);
        _rarityLabel.textAlignment = NSTextAlignmentCenter;
        _rarityLabel.layer.cornerRadius = 9.0f;
        _rarityLabel.layer.masksToBounds = true;
        [self addSubview:_rarityLabel];
    }
    _rarityLabel.text = rarityText;
    [self setNeedsLayout];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _rarityLabel.backgroundColor = presentation.pallete.collectionMenuAccentColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize labelSize = [_rarityLabel sizeThatFits:CGSizeMake(200.0f, 18.0f)];
    CGFloat width = MIN(self.bounds.size.width - 30.0f, labelSize.width + 14.0f);
    _rarityLabel.frame = CGRectMake(self.bounds.size.width - width - 15.0f, self.bounds.size.height - 21.0f, width, 18.0f);
}

@end

@interface OGStarGiftRarityItem : TGVariantCollectionItem

@property (nonatomic, strong) NSString *rarityText;

@end

@implementation OGStarGiftRarityItem

- (Class)itemViewClass
{
    return [OGStarGiftRarityItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 62.0f);
}

- (void)bindView:(OGStarGiftRarityItemView *)view
{
    [super bindView:view];
    [view setRarityText:_rarityText];
}

@end

@interface TGStarGiftUpgradeController ()
{
    TGSavedStarGift *_gift;
    TGTLDynamicObject *_upgradePreview;
    int64_t _upgradePrice;
    SMetaDisposable *_actionDisposable;
}

@end

@implementation TGStarGiftUpgradeController

- (instancetype)initWithSavedGift:(TGSavedStarGift *)gift
{
    self = [super init];
    if (self != nil)
    {
        _gift = gift;
        _upgradePrice = gift.upgradeStars;
        _actionDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:TGLocalized(@"OnegramGifts.UpgradePreview")];
        [self rebuildSections];
    }
    return self;
}

- (void)dealloc
{
    [_actionDisposable dispose];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_upgradePreview == nil)
        [self fetchUpgradePreview];
}

- (void)fetchUpgradePreview
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    __weak TGStarGiftUpgradeController *weakSelf = self;
    [_actionDisposable setDisposable:[[[TGStarGiftsSignals upgradePreviewForGift:_gift] deliverOn:[SQueue mainQueue]] startWithNext:^(TGTLDynamicObject *preview)
    {
        __strong TGStarGiftUpgradeController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_upgradePreview = preview;
            [strongSelf rebuildSections];
        }
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ActionFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        [progressWindow dismiss:true];
    }]];
}

- (void)rebuildSections
{
    while (self.menuSections.sections.count != 0)
        [self.menuSections deleteSection:0];

    TGStarGiftHeaderCollectionItem *header = [[TGStarGiftHeaderCollectionItem alloc] init];
    header.gift = _gift.gift;
    header.title = TGLocalized(@"OnegramGifts.UpgradePreview");
    header.subtitle = TGLocalized(@"OnegramGifts.UpgradePreviewHint");
    [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[header]]];
    if (_upgradePreview == nil)
    {
        [self.collectionView reloadData];
        return;
    }

    NSMutableArray *attributes = [[NSMutableArray alloc] init];
    for (TGTLDynamicObject *attribute in [_upgradePreview arrayField:@"sample_attributes"])
    {
        if (![attribute isKindOfClass:[TGTLDynamicObject class]])
            continue;
        NSString *title = nil;
        if ([attribute isConstructor:@"starGiftAttributeModel"])
            title = TGLocalized(@"OnegramGifts.Model");
        else if ([attribute isConstructor:@"starGiftAttributePattern"])
            title = TGLocalized(@"OnegramGifts.Pattern");
        else if ([attribute isConstructor:@"starGiftAttributeBackdrop"])
            title = TGLocalized(@"OnegramGifts.Backdrop");
        NSString *name = [attribute stringField:@"name"];
        if (title.length != 0 && name.length != 0)
        {
            TGTLDynamicObject *rarity = [attribute objectField:@"rarity"];
            [attributes addObject:[self rarityItemWithTitle:title name:name permille:[rarity int32Field:@"permille"]]];
        }
    }
    if (attributes.count != 0)
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:attributes]];

    NSMutableArray *prices = [[NSMutableArray alloc] init];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    int32_t newestDate = INT32_MIN;
    for (TGTLDynamicObject *price in [_upgradePreview arrayField:@"prices"])
    {
        if (![price isKindOfClass:[TGTLDynamicObject class]])
            continue;
        int32_t date = [price int32Field:@"date"];
        if (date <= now && date > newestDate)
        {
            newestDate = date;
            _upgradePrice = [price int64Field:@"upgrade_stars"];
        }
    }
    [prices addObject:[self infoItemWithTitle:TGLocalized(@"OnegramGifts.UpgradeCost") value:TGStarGiftStarsString(_upgradePrice)]];
    for (TGTLDynamicObject *price in [_upgradePreview arrayField:@"next_prices"])
    {
        if (![price isKindOfClass:[TGTLDynamicObject class]])
            continue;
        NSString *date = [TGDateUtils stringForPreciseDate:[price int32Field:@"date"]];
        [prices addObject:[self infoItemWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.UpgradeFuturePrice"), date] value:TGStarGiftStarsString([price int64Field:@"upgrade_stars"])]];
    }
    TGButtonCollectionItem *upgrade = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramGifts.UpgradeAction") action:@selector(confirmUpgradePressed)];
    upgrade.deselectAutomatically = true;
    upgrade.titleColor = [TGPresentation current].pallete.collectionMenuAccentColor;
    [prices addObject:upgrade];
    [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:prices]];
    [self.collectionView reloadData];
}

- (TGVariantCollectionItem *)infoItemWithTitle:(NSString *)title value:(NSString *)value
{
    TGVariantCollectionItem *item = [[TGVariantCollectionItem alloc] initWithTitle:title variant:value action:NULL];
    item.hideArrow = true;
    item.selectable = false;
    item.highlightable = false;
    return item;
}

- (TGVariantCollectionItem *)rarityItemWithTitle:(NSString *)title name:(NSString *)name permille:(int32_t)permille
{
    NSString *rarity = TGStarGiftRarityDescription(permille);
    if (rarity.length == 0)
        return [self infoItemWithTitle:title value:name];
    OGStarGiftRarityItem *item = [[OGStarGiftRarityItem alloc] initWithTitle:title variant:name action:NULL];
    item.hideArrow = true;
    item.selectable = false;
    item.highlightable = false;
    item.rarityText = rarity;
    return item;
}

- (void)confirmUpgradePressed
{
    if (_upgradePreview == nil)
        return;
    __weak TGStarGiftUpgradeController *weakSelf = self;
    [_actionDisposable setDisposable:[[[TGStarGiftsSignals starsBalance] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *balance)
    {
        __strong TGStarGiftUpgradeController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (strongSelf->_upgradePrice > [balance longLongValue])
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.InsufficientStars") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            return;
        }
        NSString *message = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.UpgradeConfirm"), TGStarGiftStarsString(strongSelf->_upgradePrice)];
        [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.UpgradeAction") completionBlock:^(bool confirmed)
        {
            __strong TGStarGiftUpgradeController *innerSelf = weakSelf;
            if (innerSelf == nil || !confirmed)
                return;
            [innerSelf runAction:[TGStarGiftsSignals upgradeGift:innerSelf->_gift expectedStars:innerSelf->_upgradePrice] completion:^
            {
                __strong TGStarGiftUpgradeController *updatedSelf = weakSelf;
                if (updatedSelf != nil)
                    [updatedSelf.navigationController popViewControllerAnimated:true];
            }];
        }];
    } error:^(__unused id error)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.ActionFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil]];
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

@end
