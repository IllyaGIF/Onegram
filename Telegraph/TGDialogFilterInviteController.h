#import "TGCollectionMenuController.h"

@class TGDialogFilter;
@class TGDialogFilterInvite;

@interface TGDialogFilterInviteController : TGCollectionMenuController

- (instancetype)initWithInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter;

@end
