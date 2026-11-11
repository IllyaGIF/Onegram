#import "TGCollectionMenuController.h"

@interface TGPaidMessagesSettingsController : TGCollectionMenuController

@property (nonatomic, copy) void (^settingsChanged)(bool enabled, int64_t stars);

- (instancetype)initWithAccountStars:(int64_t)stars;
- (instancetype)initWithChannelId:(int64_t)channelId broadcast:(bool)broadcast enabled:(bool)enabled stars:(int64_t)stars;

@end
