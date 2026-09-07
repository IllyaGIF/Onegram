#import "TGCollectionMenuController.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGConversation;

@interface TGSetupChannelAfterCreationController : TGCollectionMenuController

- (instancetype)initWithConversation:(TGConversation *)conversation exportedLink:(NSString *)exportedLink modal:(bool)modal conversationsToDeleteForPublicUsernames:(NSArray *)conversationsToDeleteForPublicUsernames checkConversationsToDeleteForPublicUsernames:(bool)checkConversationsToDeleteForPublicUsernames;

@end
