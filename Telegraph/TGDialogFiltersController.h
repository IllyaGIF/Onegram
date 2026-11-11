#import "TGCollectionMenuController.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGDialogFilter;

@interface TGDialogFiltersController : TGCollectionMenuController

@property (nonatomic) bool startsReordering;

+ (NSString *)summaryForFilter:(TGDialogFilter *)filter;
+ (UIImage *)iconForFilter:(TGDialogFilter *)filter presentation:(TGPresentation *)presentation;
+ (SSignal *)signalWithProgress:(SSignal *)signal;
+ (void)presentError:(id)error;
+ (void)presentActionSheetWithTitle:(NSString *)title actions:(NSArray *)actions controller:(UIViewController *)controller sourceRect:(CGRect)sourceRect actionBlock:(void (^)(NSString *action))actionBlock;
+ (void)deleteFilter:(TGDialogFilter *)filter controller:(UIViewController *)controller completion:(void (^)(bool deleted))completion;

@end
