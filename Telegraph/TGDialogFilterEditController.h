#import "TGCollectionMenuController.h"

@class TGDialogFilter;

@interface TGDialogFilterEditController : TGCollectionMenuController

@property (nonatomic) bool presentsIncludePickerOnAppear;
@property (nonatomic, strong) NSArray *initialIncludedPeerIds;

- (instancetype)initWithFilter:(TGDialogFilter *)filter allFilters:(NSArray *)allFilters;

@end
