#import "OGScreenPreviewController.h"

@implementation OGScreenPreviewController
- (void)setPreviewController:(UIViewController *)previewController
{
    if (_previewController == previewController)
        return;
    [_previewController.view removeFromSuperview];
    _previewController = previewController;
    if (_previewController != nil)
    {
        _previewController.view.frame = self.view.bounds;
        _previewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:_previewController.view];
    }
}
@end
