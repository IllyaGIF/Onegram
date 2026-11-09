#import "TGCollectionMenuController.h"

@interface TGVLESSServersController : TGCollectionMenuController

@property (nonatomic) bool enablesVLESSAfterAddingServers;

- (instancetype)initModal:(bool)modal;

+ (NSString *)selectedServerTitle;

@end
