#import "../OnegramRuntime/OGPluginAvailability.h"

#if OG_PLUGINS_AVAILABLE

#import "TGOnegramSettingsController.h"

@interface TGPluginsController : TGOnegramSettingsController

- (instancetype)init;

+ (bool)isPluginArchivePath:(NSString *)path fileName:(NSString *)fileName;
+ (void)presentInstallPromptForPath:(NSString *)path fileName:(NSString *)fileName;
+ (void)presentMenuItems:(NSArray *)items ofType:(NSString *)menuType context:(NSDictionary *)context fromController:(UIViewController *)controller;
+ (void)openPluginWithIdentifier:(NSString *)identifier;

@end

#endif
