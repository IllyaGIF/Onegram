#import "../submodules/LegacyComponents/LegacyComponents/TGModernMediaListItemContentView.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGImageView;

@interface TGModernMediaListThumbnailItemView : TGModernMediaListItemContentView

@property (nonatomic, strong, readonly) TGImageView *imageView;

- (void)setImageUri:(NSString *)imageUri;
- (void)setImageUri:(NSString *)imageUri synchronously:(bool)synchronously;
- (void)setImageSignal:(SSignal *)signal;

@end
