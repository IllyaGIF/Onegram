#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

extern NSString *const TGPaidMessagesPriceChangedNotification;
extern NSString *const TGPaidMessagesPeerIdKey;
extern NSString *const TGPaidMessagesStarsKey;

@class TGActionMediaAttachment;

@interface TGPaidMessagesFreeLink : NSObject

@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int32_t expires;

@end

@interface TGStarsTopUpOption : NSObject

@property (nonatomic, readonly) int64_t stars;
@property (nonatomic, strong, readonly) NSString *currency;
@property (nonatomic, readonly) int64_t amount;
@property (nonatomic, readonly) bool extended;

@end

@interface TGPaidMessagesSignals : NSObject

+ (int64_t)maxStarsPerMessage;
+ (int64_t)defaultStarsPerMessage;
+ (int32_t)commissionPermille;

+ (bool)hasCachedPriceForPeerId:(int64_t)peerId;
+ (int64_t)cachedPriceForPeerId:(int64_t)peerId;
+ (void)setCachedPrice:(int64_t)stars forPeerId:(int64_t)peerId;
+ (SSignal *)priceForUserId:(int64_t)userId;

+ (SSignal *)pricesForPeerIds:(NSArray *)peerIds;
+ (void)approveSendingToPeerIds:(NSArray *)peerIds;
+ (int64_t)allowedStarsForPeerId:(int64_t)peerId;

+ (bool)isPaidMessagesError:(NSString *)errorType;
+ (int64_t)starsFromPaymentRequiredError:(NSString *)errorType;

+ (bool)needsConfirmationForPeerId:(int64_t)peerId price:(int64_t)price;
+ (void)setConfirmationSkipped:(bool)skipped forPeerId:(int64_t)peerId price:(int64_t)price;

+ (SSignal *)starsBalance;
+ (SSignal *)topUpOptions;
+ (SSignal *)topUpFormUrlForOption:(TGStarsTopUpOption *)option;

+ (SSignal *)chargeStarsForNonContacts;
+ (SSignal *)setChargeStarsForNonContacts:(int64_t)stars;
+ (SSignal *)freeExceptionUserIds;
+ (SSignal *)setFreeExceptionUserIds:(NSArray *)userIds;
+ (SSignal *)chargedStarsFromUserId:(int64_t)userId;
+ (SSignal *)revenueFromUserId:(int64_t)userId;
+ (SSignal *)setFeeRemoved:(bool)removed forUserId:(int64_t)userId refundCharged:(bool)refundCharged;
+ (SSignal *)exportFreeLinkTemporary:(bool)temporary revoke:(bool)revoke;
+ (SSignal *)importFreeToken:(NSString *)token userId:(int64_t)userId;
+ (SSignal *)setChannelPrice:(int64_t)stars channelId:(int64_t)channelId broadcastMessagesAllowed:(bool)broadcastMessagesAllowed;

+ (NSString *)starsString:(int64_t)stars;
+ (NSString *)serviceTextForAction:(TGActionMediaAttachment *)action outgoing:(bool)outgoing authorName:(NSString *)authorName peerName:(NSString *)peerName;

@end
