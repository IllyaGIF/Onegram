#import <UIKit/UIKit.h>

@interface OGMediaBitrateIndicatorView : UIView

@property (nonatomic, strong) UIFont *font;
@property (nonatomic, copy) double (^rateProvider)(void);
@property (nonatomic) double mediaBitrate;

- (bool)hasContent;

@end
