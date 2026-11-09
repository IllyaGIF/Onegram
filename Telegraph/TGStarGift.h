#import <UIKit/UIKit.h>

@class TGTLDynamicObject;
@class TGDocumentMediaAttachment;

@interface TGStarGift : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t giftId;
@property (nonatomic, readonly) bool unique;
@property (nonatomic, strong, readonly) TGDocumentMediaAttachment *sticker;
@property (nonatomic, strong, readonly) TGDocumentMediaAttachment *patternSticker;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *slug;
@property (nonatomic, readonly) int32_t number;
@property (nonatomic, readonly) int64_t ownerPeerId;
@property (nonatomic, strong, readonly) NSString *ownerName;
@property (nonatomic, readonly) int64_t releasedByPeerId;
@property (nonatomic, readonly) int64_t valueAmount;
@property (nonatomic, strong, readonly) NSString *valueCurrency;
@property (nonatomic, strong, readonly) NSArray *resellAmounts;
@property (nonatomic, readonly) bool burned;
@property (nonatomic, readonly) bool crafted;
@property (nonatomic, readonly) bool resaleTonOnly;
@property (nonatomic, readonly) int64_t stars;
@property (nonatomic, readonly) int64_t convertStars;
@property (nonatomic, readonly) int64_t upgradeStars;
@property (nonatomic, readonly) bool limited;
@property (nonatomic, readonly) bool soldOut;
@property (nonatomic, readonly) bool birthday;
@property (nonatomic, readonly) bool requirePremium;
@property (nonatomic, readonly) int32_t availabilityRemains;
@property (nonatomic, readonly) int32_t availabilityTotal;
@property (nonatomic, readonly) bool limitedPerUser;
@property (nonatomic, readonly) int32_t perUserRemains;
@property (nonatomic, readonly) bool hasBackdrop;
@property (nonatomic, readonly) int32_t backdropCenterColor;
@property (nonatomic, readonly) int32_t backdropEdgeColor;
@property (nonatomic, readonly) int32_t backdropPatternColor;
@property (nonatomic, readonly) int32_t backdropTextColor;
@property (nonatomic, strong, readonly) NSString *modelName;
@property (nonatomic, strong, readonly) NSString *backdropName;
@property (nonatomic, strong, readonly) NSString *patternName;
@property (nonatomic, readonly) int32_t modelRarityPermille;
@property (nonatomic, readonly) int32_t backdropRarityPermille;
@property (nonatomic, readonly) int32_t patternRarityPermille;
@property (nonatomic, strong, readonly) NSString *modelRarityLevel;
@property (nonatomic, strong, readonly) NSString *backdropRarityLevel;
@property (nonatomic, strong, readonly) NSString *patternRarityLevel;

+ (TGStarGift *)starGiftWithObject:(TGTLDynamicObject *)object;

- (bool)canBePurchased;

@end

@interface TGSavedStarGift : NSObject

@property (nonatomic, readonly) int64_t ownerPeerId;
@property (nonatomic, strong, readonly) TGStarGift *gift;
@property (nonatomic, readonly) int64_t fromPeerId;
@property (nonatomic, readonly) int32_t date;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, readonly) bool nameHidden;
@property (nonatomic, readonly) bool unsaved;
@property (nonatomic, readonly) bool refunded;
@property (nonatomic, readonly) bool canUpgrade;
@property (nonatomic, readonly) bool pinnedToTop;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, readonly) int64_t savedId;
@property (nonatomic, readonly) int64_t convertStars;
@property (nonatomic, readonly) int64_t upgradeStars;
@property (nonatomic, readonly) int64_t transferStars;
@property (nonatomic, readonly) int32_t giftNumber;
@property (nonatomic, readonly) int32_t canTransferAt;
@property (nonatomic, readonly) int32_t canResellAt;

+ (TGSavedStarGift *)savedStarGiftWithObject:(TGTLDynamicObject *)object ownerPeerId:(int64_t)ownerPeerId;
+ (TGSavedStarGift *)savedStarGiftWithActionData:(NSDictionary *)actionData ownerPeerId:(int64_t)ownerPeerId messageId:(int32_t)messageId fromPeerId:(int64_t)fromPeerId date:(int32_t)date;

- (TGSavedStarGift *)savedStarGiftWithUnsaved:(bool)unsaved;
- (TGSavedStarGift *)savedStarGiftWithPinnedToTop:(bool)pinnedToTop;
- (bool)canManage;
- (bool)canConvert;
- (bool)canTransfer;
- (bool)canResell;

@end

UIColor *TGStarGiftColor(int32_t rgb);
