#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGPasswordSetupController : TGViewController

@property (nonatomic, copy) void (^completion)(NSString *);

- (instancetype)initWithSetupNew:(bool)setupNew;

@end
