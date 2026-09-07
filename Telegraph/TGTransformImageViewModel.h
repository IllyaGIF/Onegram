#import "TGModernViewModel.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TransformImageArguments;

@interface TGTransformImageViewModel : TGModernViewModel

@property (nonatomic, strong) TransformImageArguments *arguments;

- (void)setSignalGenerator:(SSignal *(^)())signalGenerator identifier:(NSString *)identifier;

@end
