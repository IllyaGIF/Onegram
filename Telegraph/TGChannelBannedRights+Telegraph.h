#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TL/TLMetaScheme.h"

enum {
    TGChatBannedRightsChangeInfoFlag = 1 << 10,
    TGChatBannedRightsInviteUsersFlag = 1 << 15,
    TGChatBannedRightsPinMessagesFlag = 1 << 17
};

@interface TGChannelBannedRights (TG)

- (instancetype)initWithTL:(TLChannelBannedRights *)tlRights;
- (TLChatBannedRights *)tlRights;

@end
