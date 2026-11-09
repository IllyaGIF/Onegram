#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGSavedStarGift;

@interface TGSavedStarGiftsPage : NSObject

@property (nonatomic, readonly) int32_t totalCount;
@property (nonatomic, strong, readonly) NSArray *gifts;
@property (nonatomic, strong, readonly) NSString *nextOffset;

- (instancetype)initWithTotalCount:(int32_t)totalCount gifts:(NSArray *)gifts nextOffset:(NSString *)nextOffset;

@end

@interface TGStarGiftsSignals : NSObject

+ (SSignal *)savedGifts:(int64_t)peerId offset:(NSString *)offset limit:(int32_t)limit;
+ (SSignal *)savedGift:(TGSavedStarGift *)gift;
+ (SSignal *)setGift:(TGSavedStarGift *)gift saved:(bool)saved;
+ (SSignal *)setGifts:(NSArray *)gifts pinnedToTopForPeerId:(int64_t)peerId;
+ (SSignal *)setGift:(TGSavedStarGift *)gift pinnedToTop:(bool)pinnedToTop;
+ (SSignal *)convertGift:(TGSavedStarGift *)gift;

+ (SSignal *)availableGifts;
+ (SSignal *)starsBalance;
+ (SSignal *)sendGiftWithId:(int64_t)giftId toPeerId:(int64_t)peerId message:(NSString *)message hideName:(bool)hideName;
+ (SSignal *)upgradePreviewForGift:(TGSavedStarGift *)gift;
+ (SSignal *)upgradeGift:(TGSavedStarGift *)gift expectedStars:(int64_t)expectedStars;
+ (SSignal *)transferGift:(TGSavedStarGift *)gift toPeerId:(int64_t)peerId expectedStars:(int64_t)expectedStars;
+ (SSignal *)setResalePrice:(int64_t)price forGift:(TGSavedStarGift *)gift;

@end
