#import "TGModernViewModel.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGInlineVideoModel : TGModernViewModel

@property (nonatomic, strong) SSignal *videoPathSignal;

@end
