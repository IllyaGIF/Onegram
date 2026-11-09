#import "TGPresentationPallete.h"

@interface TGNightPresentationPallete : TGPresentationPallete

+ (NSUInteger)surfaceToneCount;
+ (uint32_t)surfaceColorForTone:(NSUInteger)tone;
+ (void)setSurfaceTone:(NSInteger)tone;

@end
