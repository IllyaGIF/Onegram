#import "TGCollectionMenuController.h"

@interface TGPowerServersController : TGCollectionMenuController

@property (nonatomic) bool enablesPowerAfterAddingServers;

+ (NSString *)selectedServerTitle;

@end
