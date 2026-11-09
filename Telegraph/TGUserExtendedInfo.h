#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGConversation;

@interface TGUserExtendedInfo : NSObject

@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly) bool hasBirthday;
@property (nonatomic, readonly) int32_t birthdayDay;
@property (nonatomic, readonly) int32_t birthdayMonth;
@property (nonatomic, readonly) int32_t birthdayYear;
@property (nonatomic, strong, readonly) TGConversation *personalChannel;
@property (nonatomic, readonly) int32_t personalChannelMessageId;
@property (nonatomic, readonly) int32_t personalChannelSubscribersCount;
@property (nonatomic, readonly) int32_t starGiftsCount;
@property (nonatomic, readonly) bool hasStarsRating;
@property (nonatomic, readonly) int32_t starsRatingLevel;
@property (nonatomic, readonly) int32_t profileColor;
@property (nonatomic, readonly) int32_t nameColor;

- (NSString *)birthdayString;

+ (SSignal *)extendedInfoForUserId:(int64_t)userId;
+ (SSignal *)updateColor:(int32_t)color forProfile:(bool)forProfile;

@end

UIColor *TGUserProfileColor(int32_t color);
UIColor *TGUserNameColor(int32_t color);
NSUInteger TGUserProfileColorCount(void);
NSUInteger TGUserNameColorCount(void);
