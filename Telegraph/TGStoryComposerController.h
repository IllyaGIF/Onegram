#import "TGCollectionMenuController.h"

@interface TGStoryComposerController : TGCollectionMenuController

@property (nonatomic, copy) void (^completion)(NSArray *stories);

- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage;

+ (void)presentFromController:(UIViewController *)controller completion:(void (^)(NSArray *stories))completion;

@end
