#ifndef Telegraph_TGPeerIdAdapter_h
#define Telegraph_TGPeerIdAdapter_h

#include <stdint.h>
#include <stdbool.h>

static const int64_t TGPeerIdMaxUserId = 1099511627775LL;
static const int64_t TGPeerIdMaxGroupId = 999999999999LL;
static const int64_t TGPeerIdMaxChannelId = 997852516352LL;
static const int64_t TGPeerIdMinMonoforumId = 1002147483649LL;
static const int64_t TGPeerIdMaxMonoforumId = 3000000000000LL;
static const int64_t TGPeerIdMaxSecretChatLocalId = 2147483647LL;
static const int64_t TGPeerIdChannelBase = -1000000000000LL;
static const int64_t TGPeerIdSecretChatBase = -2000000000000LL;
static const int64_t TGPeerIdAdminLogBase = -6000000000000LL;
static const int64_t TGPeerIdAdBase = -4000000000000LL;
static const int64_t TGPeerIdFeedBase = -5000000000000LL;
static const int64_t TGPeerIdMaxFeedId = 2147483647LL;
static const int64_t TGPeerIdReservedBase = TGPeerIdMaxUserId + 1;
static const int64_t TGPeerIdNotificationDefaultsPrivate = TGPeerIdReservedBase + 1;
static const int64_t TGPeerIdNotificationDefaultsGroup = TGPeerIdReservedBase + 2;
static const int64_t TGPeerIdNotificationDefaultsChannel = TGPeerIdReservedBase + 4;

static inline bool TGChannelIdIsValid(int64_t channelId) {
    return (channelId > 0 && channelId <= TGPeerIdMaxChannelId) || (channelId >= TGPeerIdMinMonoforumId && channelId <= TGPeerIdMaxMonoforumId);
}

static inline bool TGPeerIdIsUser(int64_t peerId) {
    return peerId > 0 && peerId <= TGPeerIdMaxUserId;
}

static inline bool TGPeerIdIsGroup(int64_t peerId) {
    return peerId < 0 && peerId >= -TGPeerIdMaxGroupId;
}

static inline bool TGPeerIdIsChannel(int64_t peerId) {
    return peerId < TGPeerIdChannelBase && TGChannelIdIsValid(TGPeerIdChannelBase - peerId);
}

static inline bool TGPeerIdIsSecretChat(int64_t peerId) {
    return peerId <= TGPeerIdSecretChatBase && peerId >= TGPeerIdSecretChatBase - TGPeerIdMaxSecretChatLocalId;
}

static inline bool TGPeerIdIsAdminLog(int64_t peerId) {
    return peerId < TGPeerIdAdminLogBase && peerId >= TGPeerIdAdminLogBase - TGPeerIdMaxChannelId;
}

static inline bool TGPeerIdIsAd(int64_t peerId) {
    return peerId < TGPeerIdAdBase && peerId >= TGPeerIdAdBase - TGPeerIdMaxChannelId;
}

static inline bool TGPeerIdIsNotificationDefaults(int64_t peerId) {
    return peerId == TGPeerIdNotificationDefaultsPrivate || peerId == TGPeerIdNotificationDefaultsGroup || peerId == TGPeerIdNotificationDefaultsChannel;
}

static inline bool TGPeerIdIsFeed(int64_t peerId) {
    return peerId < TGPeerIdFeedBase && peerId >= TGPeerIdFeedBase - TGPeerIdMaxFeedId;
}

static inline int64_t TGPeerIdFromUserId(int64_t userId) {
    return (userId > 0 && userId <= TGPeerIdMaxUserId) ? userId : 0;
}

static inline int64_t TGUserIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsUser(peerId) ? peerId : 0;
}

static inline int64_t TGPeerIdFromGroupId(int64_t groupId) {
    return (groupId > 0 && groupId <= TGPeerIdMaxGroupId) ? -groupId : 0;
}

static inline int64_t TGGroupIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsGroup(peerId) ? -peerId : 0;
}

static inline int64_t TGPeerIdFromChannelId(int64_t channelId) {
    return TGChannelIdIsValid(channelId) ? TGPeerIdChannelBase - channelId : 0;
}

static inline int64_t TGChannelIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsChannel(peerId) ? TGPeerIdChannelBase - peerId : 0;
}

static inline int64_t TGPeerIdFromSecretChatLocalId(int32_t localId) {
    return localId >= 0 ? TGPeerIdSecretChatBase - (int64_t)localId : 0;
}

static inline int32_t TGSecretChatLocalIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsSecretChat(peerId) ? (int32_t)(TGPeerIdSecretChatBase - peerId) : 0;
}

static inline int64_t TGPeerIdFromAdminLogId(int64_t channelId) {
    return (channelId > 0 && channelId <= TGPeerIdMaxChannelId) ? TGPeerIdAdminLogBase - channelId : 0;
}

static inline int64_t TGAdminLogIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsAdminLog(peerId) ? TGPeerIdAdminLogBase - peerId : 0;
}

static inline int64_t TGPeerIdFromFeedId(int32_t feedId) {
    return feedId > 0 ? TGPeerIdFeedBase - (int64_t)feedId : 0;
}

static inline int32_t TGFeedIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsFeed(peerId) ? (int32_t)(TGPeerIdFeedBase - peerId) : 0;
}

static inline int64_t TGPeerIdFromAdId(int64_t channelId) {
    return (channelId > 0 && channelId <= TGPeerIdMaxChannelId) ? TGPeerIdAdBase - channelId : 0;
}

static inline int64_t TGAdIdFromPeerId(int64_t peerId) {
    return TGPeerIdIsAd(peerId) ? TGPeerIdAdBase - peerId : 0;
}

#endif
