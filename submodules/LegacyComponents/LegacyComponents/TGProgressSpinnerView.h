#import <UIKit/UIKit.h>

@interface TGProgressSpinnerView : UIView

@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light;

- (void)setProgress;
- (void)setSucceed;

@end

@interface TGActivityIndicatorView : UIView

@property (nonatomic, strong) UIColor *color;
@property (nonatomic) BOOL hidesWhenStopped;
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;
@property (nonatomic) UIActivityIndicatorViewStyle activityIndicatorViewStyle;

- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
- (void)startAnimating;
- (void)stopAnimating;

@end
