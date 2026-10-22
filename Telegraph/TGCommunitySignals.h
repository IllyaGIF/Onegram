#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGCommunity.h"

@class TGConversation;
@class TGActionMediaAttachment;

@interface TGCommunitySignals : NSObject

+ (void)storeCommunitiesFromChats:(NSArray *)chats;
+ (TGCommunity *)cachedCommunityWithId:(int64_t)communityId;

+ (SSignal *)communityChatsForConversation:(TGConversation *)conversation;
+ (SSignal *)synchronizeLinkedCommunities;

+ (NSString *)serviceTextForCommunityAction:(TGActionMediaAttachment *)action isChannel:(bool)isChannel authorName:(NSString *)authorName;

+ (void)reloadForAccountSwitch;

@end
