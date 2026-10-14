#import "TLChat.h"

@class TLChatPhoto;
@class TLInputChannel;


@interface TLChat$chat : TLChat

@property (nonatomic) int32_t flags;

@property (nonatomic) bool creator;
@property (nonatomic) bool kicked;
@property (nonatomic) bool left;
@property (nonatomic) bool admins_enabled;
@property (nonatomic) bool admin;
@property (nonatomic) bool deactivated;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) TLChatPhoto *photo;
@property (nonatomic) int32_t participants_count;
@property (nonatomic) int32_t date;
@property (nonatomic) int32_t version;
@property (nonatomic, strong) TLInputChannel *migrated_to;

@end
