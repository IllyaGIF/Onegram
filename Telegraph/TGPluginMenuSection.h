#import "../OnegramRuntime/OGPluginAvailability.h"

#if OG_PLUGINS_AVAILABLE

#import <Foundation/Foundation.h>

@class TGCollectionMenuController;
@class TGCollectionMenuSection;

@interface TGPluginMenuSection : NSObject

- (instancetype)initWithMenuType:(NSString *)menuType controller:(TGCollectionMenuController *)controller peerId:(int64_t)peerId;
- (instancetype)initWithMenuTypes:(NSArray *)menuTypes controller:(TGCollectionMenuController *)controller peerId:(int64_t)peerId;

- (bool)updateVisible:(bool)visible beforeSection:(TGCollectionMenuSection *)anchorSection;

@end

#endif
