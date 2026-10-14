#import "TGModernView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

@class TGPresentation;

@interface TGMessageCommentsFooterView : TGModernButton <TGModernView>

- (void)setRepliers:(NSArray *)repliers presentation:(TGPresentation *)presentation;
- (void)setTitle:(NSString *)title count:(int32_t)count;

@end
