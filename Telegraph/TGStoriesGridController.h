#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

@interface TGStoriesGridController : TGViewController

@property (nonatomic, copy) void (^storiesChanged)(void);

- (instancetype)initWithPeerId:(int64_t)peerId archive:(bool)archive;

@end
