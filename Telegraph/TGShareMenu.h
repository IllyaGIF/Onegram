#import <Foundation/Foundation.h>

@class TGViewController;
@class TGMenuSheetController;
@class TGConversation;

@interface TGShareMenu : NSObject

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController menuController:(TGMenuSheetController *)menuController buttonTitle:(NSString *)buttonTitle buttonAction:(void (^)(void))buttonAction shareAction:(void (^)(NSArray *peerIds, NSString *caption))shareAction externalShareItemSignal:(id)externalShareItemSignal sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect barButtonItem:(UIBarButtonItem *)barButtonItem;

+ (TGMenuSheetController *)presentChannelShareMenuInParentController:(TGViewController *)parentController conversation:(TGConversation *)conversation sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect;

@end
