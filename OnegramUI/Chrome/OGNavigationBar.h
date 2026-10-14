#import "../Base/OGView.h"
@class OGLabel;
@class OGNavigationButton;
@class OGImageView;
@interface OGNavigationBar : OGView
@property (nonatomic, retain, readonly) OGImageView *backgroundView;
@property (nonatomic, retain, readonly) OGLabel *titleLabel;
@property (nonatomic, retain, readonly) OGNavigationButton *leftButton;
@property (nonatomic, retain, readonly) OGNavigationButton *rightButton;
@property (nonatomic, copy) NSString *backgroundAssetDirectory;
@property (nonatomic, copy) NSString *backgroundAssetName;
@end
