#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#import <SafariServices/SSReadingList.h>
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import <SafariServices/SFSafariViewController.h>
#else

@class SFSafariViewController;

@protocol SFSafariViewControllerDelegate <NSObject>
@optional
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller;
@end

@interface SFSafariViewController : UIViewController
@property (nonatomic, unsafe_unretained) id<SFSafariViewControllerDelegate> delegate;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)entersReaderIfAvailable;
- (NSArray *)previewActionItems;
@end

#endif
