#import "TGOnegramSettingsController.h"

@interface TGOnegramRootSettingsController : TGOnegramSettingsController
@end

@interface TGOnegramGeneralSettingsController : TGOnegramSettingsController
@end

@interface TGOnegramChatListSettingsController : TGOnegramSettingsController
@end

@interface TGOnegramMessagesSettingsController : TGOnegramSettingsController
@end

@interface TGOnegramConfirmationsSettingsController : TGOnegramSettingsController
@end

#ifdef __cplusplus
extern "C" {
#endif

NSArray *TGOnegramDoubleTapActions(bool outgoing);
NSArray *TGOnegramMenuActionIdentifiers(void);

#ifdef __cplusplus
}
#endif
