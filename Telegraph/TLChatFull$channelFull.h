#import "TLChatFull.h"

@class TLPhoto;
@class TLPeerNotifySettings;
@class TLExportedChatInvite;
@class TLStickerSet;


@interface TLChatFull$channelFull : TLChatFull

@property (nonatomic) int32_t flags;

@property (nonatomic) bool canViewParticipants;
@property (nonatomic) bool can_set_username;
@property (nonatomic) bool can_set_stickers;

@property (nonatomic) NSString *about;
@property (nonatomic) int32_t participants_count;
@property (nonatomic) int32_t admins_count;
@property (nonatomic) int32_t kicked_count;
@property (nonatomic) int32_t banned_count;
@property (nonatomic) int32_t read_inbox_max_id;
@property (nonatomic) int32_t read_outbox_max_id;
@property (nonatomic) int32_t unread_count;
@property (nonatomic) int32_t migrated_from_chat_id;
@property (nonatomic) int32_t migrated_from_max_id;
@property (nonatomic) int32_t pinned_msg_id;
@property (nonatomic, strong) TLStickerSet *stickerset;
@property (nonatomic) int32_t available_min_id;

@end
