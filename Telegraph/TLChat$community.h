#import "TLChat.h"

@class TLChatPhoto;

@interface TLChat$community : TLChat

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t flags2;
@property (nonatomic) int64_t community_id;
@property (nonatomic) int64_t access_hash;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) TLChatPhoto *photo;
@property (nonatomic) int32_t date;

@property (nonatomic, readonly) bool creator;
@property (nonatomic, readonly) bool left;
@property (nonatomic, readonly) bool min;
@property (nonatomic, readonly) bool collapsed_in_dialogs;

@end
