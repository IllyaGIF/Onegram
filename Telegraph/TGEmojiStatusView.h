#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

@interface TGEmojiStatusView : TGRemoteImageView

@property (nonatomic) int64_t documentId;
@property (nonatomic) bool suppressed;
@property (nonatomic, readonly) bool displaysStatus;
@property (nonatomic, copy) void (^displayChanged)(void);

@end
