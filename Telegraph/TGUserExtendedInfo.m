#import "TGUserExtendedInfo.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGStoriesSignals.h"
#import "TGStoryItem.h"
#import "TGTelegraph.h"
#import "TGConversation+Telegraph.h"
#import "TL/TLMetaScheme.h"
#import "TLUser$modernUser.h"
#import "TLChat$channel.h"
#import "TLChatFull$channelFull.h"
#import "TGTelegramNetworking.h"

static const uint32_t TGUserProfileColors[] = {0xba5650, 0xc27c3e, 0x956ac8, 0x49a355, 0x3e97ad, 0x5a8fbb, 0xb85378, 0x7f8b95};
static const uint32_t TGUserNameColors[] = {0xcc5049, 0xd67722, 0x955cdb, 0x40a920, 0x309eba, 0x368ad1, 0xc7508b};

NSUInteger TGUserProfileColorCount(void)
{
    return sizeof(TGUserProfileColors) / sizeof(TGUserProfileColors[0]);
}

NSUInteger TGUserNameColorCount(void)
{
    return sizeof(TGUserNameColors) / sizeof(TGUserNameColors[0]);
}

UIColor *TGUserProfileColor(int32_t color)
{
    if (color < 0)
        return nil;
    return UIColorRGB(TGUserProfileColors[(NSUInteger)color % TGUserProfileColorCount()]);
}

UIColor *TGUserNameColor(int32_t color)
{
    if (color < 0)
        return nil;
    return UIColorRGB(TGUserNameColors[(NSUInteger)color % TGUserNameColorCount()]);
}

@interface TGUserExtendedInfo ()

@property (nonatomic) int64_t userId;
@property (nonatomic) bool hasBirthday;
@property (nonatomic) int32_t birthdayDay;
@property (nonatomic) int32_t birthdayMonth;
@property (nonatomic) int32_t birthdayYear;
@property (nonatomic, strong) TGConversation *personalChannel;
@property (nonatomic) int32_t personalChannelMessageId;
@property (nonatomic) int32_t personalChannelSubscribersCount;
@property (nonatomic) int32_t starGiftsCount;
@property (nonatomic) bool hasStarsRating;
@property (nonatomic) int32_t starsRatingLevel;
@property (nonatomic) int32_t profileColor;
@property (nonatomic) int32_t nameColor;

@end

@implementation TGUserExtendedInfo

- (NSString *)birthdayString
{
    if (!_hasBirthday || _birthdayMonth < 1 || _birthdayMonth > 12 || _birthdayDay < 1)
        return nil;
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.day = _birthdayDay;
    components.month = _birthdayMonth;
    components.year = _birthdayYear > 0 ? _birthdayYear : 2000;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDate *date = [calendar dateFromComponents:components];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSString *code = effectiveLocalization().code;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:code.length == 0 ? @"en" : code];
    formatter.calendar = calendar;
    formatter.dateFormat = _birthdayYear > 0 ? @"d MMMM yyyy" : @"d MMMM";
    NSString *dateString = [formatter stringFromDate:date];
    if (_birthdayYear <= 0)
        return dateString;

    NSDateComponents *today = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
    NSInteger age = today.year - _birthdayYear;
    if (today.month < _birthdayMonth || (today.month == _birthdayMonth && today.day < _birthdayDay))
        age--;
    if (age <= 0 || age > 150)
        return dateString;
    return [[NSString alloc] initWithFormat:TGLocalized(@"OnegramProfile.BirthdayWithAge"), dateString, (int)age];
}

+ (SSignal *)extendedInfoForUserId:(int64_t)userId
{
    id inputUser = [TGStoriesSignals inputUserForUserId:userId];
    if (inputUser == nil)
        return [SSignal fail:nil];
    NSSet *dynamicTypes = [[NSSet alloc] initWithObjects:@"users.UserFull", @"UserFull", @"Birthday", @"StarsRating", nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"users.getFullUser" parameters:@{@"id": inputUser} dynamicTypes:dynamicTypes] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![result isConstructor:@"users.userFull"])
            return [SSignal fail:nil];
        NSArray *users = [result arrayField:@"users"];
        NSArray *chats = [result arrayField:@"chats"];
        [TGStoriesSignals processUsers:users chats:chats];

        TGUserExtendedInfo *info = [[TGUserExtendedInfo alloc] init];
        info.userId = userId;
        info.profileColor = -1;
        info.nameColor = -1;
        TGTLDynamicObject *fullUser = [result objectField:@"full_user"];
        TGTLDynamicObject *birthday = [fullUser objectField:@"birthday"];
        if (birthday != nil)
        {
            info.hasBirthday = true;
            info.birthdayDay = [birthday int32Field:@"day"];
            info.birthdayMonth = [birthday int32Field:@"month"];
            info.birthdayYear = [birthday int32Field:@"year"];
        }
        TGTLDynamicObject *starsRating = [fullUser objectField:@"stars_rating"];
        if (starsRating != nil)
        {
            info.hasStarsRating = true;
            info.starsRatingLevel = [starsRating int32Field:@"level"];
        }
        info.starGiftsCount = [fullUser int32Field:@"stargifts_count"];

        int64_t channelPeerId = [fullUser field:@"personal_channel_id"] == nil ? 0 : TGPeerIdFromChannelId([fullUser int64Field:@"personal_channel_id"]);
        if (channelPeerId != 0)
        {
            for (id chat in chats)
            {
                if (![chat isKindOfClass:[TLChat class]])
                    continue;
                TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
                if (conversation.conversationId == channelPeerId)
                {
                    info.personalChannel = conversation;
                    if ([chat isKindOfClass:[TLChat$channel class]])
                        info.personalChannelSubscribersCount = ((TLChat$channel *)chat).participants_count;
                    break;
                }
            }
            info.personalChannelMessageId = [fullUser int32Field:@"personal_channel_message"];
        }

        for (id user in users)
        {
            if (![user isKindOfClass:[TLUser$modernUser class]] || TGPeerIdFromUserId(((TLUser$modernUser *)user).n_id) != userId)
                continue;
            info.nameColor = ((TLUser$modernUser *)user).nameColorId;
            info.profileColor = ((TLUser$modernUser *)user).profileColorId;
        }
        if (info.personalChannel == nil || info.personalChannelSubscribersCount > 0)
            return [SSignal single:info];
        return [[[self subscribersCountForChannel:info.personalChannel] map:^id(NSNumber *count)
        {
            info.personalChannelSubscribersCount = [count intValue];
            return info;
        }] catch:^SSignal *(__unused id error)
        {
            return [SSignal single:info];
        }];
    }];
}

+ (SSignal *)subscribersCountForChannel:(TGConversation *)channel
{
    TLRPCchannels_getFullChannel$channels_getFullChannel *getFullChannel = [[TLRPCchannels_getFullChannel$channels_getFullChannel alloc] init];
    TLInputChannel$inputChannel *inputChannel = [[TLInputChannel$inputChannel alloc] init];
    inputChannel.channel_id = TGChannelIdFromPeerId(channel.conversationId);
    inputChannel.access_hash = channel.accessHash;
    getFullChannel.channel = inputChannel;
    return [[[TGTelegramNetworking instance] requestSignal:getFullChannel] map:^id(TLmessages_ChatFull *result)
    {
        if ([result isKindOfClass:[TLmessages_ChatFull class]] && [result.full_chat isKindOfClass:[TLChatFull$channelFull class]])
            return @(((TLChatFull$channelFull *)result.full_chat).participants_count);
        return @0;
    }];
}

+ (SSignal *)updateColor:(int32_t)color forProfile:(bool)forProfile
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (forProfile)
        parameters[@"for_profile"] = @true;
    if (color >= 0)
        parameters[@"color"] = [TGTLDynamicObject objectWithConstructor:@"peerColor" fields:@{@"color": @(color)}];
    return [TGTLDynamicRpc requestSignalWithMethod:@"account.updateColor" parameters:parameters];
}

@end
