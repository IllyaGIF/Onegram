#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGRect OGPlatformKeyboardEndFrame(NSNotification *notification);
FOUNDATION_EXPORT CGRect OGPlatformKeyboardFrameInView(NSNotification *notification, UIView *view);

FOUNDATION_EXPORT void OGPlatformSetExclusiveTouch(UIView *view, BOOL enabled);
FOUNDATION_EXPORT void OGPlatformSetViewRasterization(UIView *view, BOOL enabled, CGFloat scale);
FOUNDATION_EXPORT void OGPlatformSetLayerContentsScale(CALayer *layer, CGFloat scale);

FOUNDATION_EXPORT void OGPlatformApplyLegacySegmentedControlStyle(UISegmentedControl *control, UIColor *tintColor);
FOUNDATION_EXPORT void OGPlatformSetSegmentedControlBackgroundImage(UISegmentedControl *control, UIImage *image, UIControlState state, UIBarMetrics barMetrics);
FOUNDATION_EXPORT void OGPlatformSetSegmentedControlDividerImage(UISegmentedControl *control, UIImage *image, UIControlState leftState, UIControlState rightState, UIBarMetrics barMetrics);
FOUNDATION_EXPORT void OGPlatformSetSegmentedControlTitleTextAttributes(UISegmentedControl *control, NSDictionary *attributes, UIControlState state);

FOUNDATION_EXPORT void OGPlatformPresentActionSheet(UIActionSheet *actionSheet, UIBarButtonItem *barButtonItem, UIView *sourceView, CGRect sourceRect, UIView *fallbackView, BOOL animated);
FOUNDATION_EXPORT void OGPlatformSetPopoverBackgroundColor(id popoverController, UIColor *color);
FOUNDATION_EXPORT void OGPlatformApplyNavigationBarTitleStyle(UINavigationBar *navigationBar, UIColor *textColor, UIColor *shadowColor, CGSize shadowOffset, UIFont *font);

FOUNDATION_EXPORT void OGPlatformSetLabelMinimumScaleFactor(UILabel *label, CGFloat minimumScaleFactor);
FOUNDATION_EXPORT void OGPlatformSetTextFieldSelectionRange(UITextField *textField, NSRange range);
FOUNDATION_EXPORT void OGPlatformSetTextFieldInputAccessoryView(UITextField *textField, UIView *accessoryView);
FOUNDATION_EXPORT void OGPlatformSetTextFieldInputView(UITextField *textField, UIView *inputView);
FOUNDATION_EXPORT UIView *OGPlatformTextInputView(id textInput);
FOUNDATION_EXPORT void OGPlatformSetTextInputView(id textInput, UIView *inputView);
FOUNDATION_EXPORT void OGPlatformDisableSpellChecking(id textInput);
FOUNDATION_EXPORT BOOL OGPlatformSuperclassViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, Class currentClass);
FOUNDATION_EXPORT void OGPlatformSetViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, BOOL enabled);
FOUNDATION_EXPORT UIEdgeInsets OGPlatformSuperclassViewAlignmentRectInsets(UIView *view, Class currentClass);
FOUNDATION_EXPORT CGSize OGPlatformViewIntrinsicContentSize(UIView *view);
FOUNDATION_EXPORT void OGPlatformInvalidateViewIntrinsicContentSize(UIView *view);
FOUNDATION_EXPORT void OGPlatformSetTableViewSectionIndexColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT void OGPlatformSetTableViewSectionIndexBackgroundColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT void OGPlatformSetTableViewSectionIndexTrackingBackgroundColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT BOOL OGPlatformSetSwitchColors(UISwitch *switchView, UIColor *onTintColor, UIColor *tintColor);
FOUNDATION_EXPORT void OGPlatformSetSwitchThumbTintColor(UISwitch *switchView, UIColor *color);
FOUNDATION_EXPORT BOOL OGPlatformPresentActivityItems(UIViewController *presenter, NSArray *items, UIView *sourceView, CGRect sourceRect, UIBarButtonItem *barButtonItem, NSUInteger permittedArrowDirections, void (^completion)(void));

FOUNDATION_EXPORT void OGPlatformBeginReceivingRemoteControlEvents(UIApplication *application);
FOUNDATION_EXPORT void OGPlatformSetStatusBarHidden(UIApplication *application, BOOL hidden, NSInteger animation);
typedef NSUInteger OGPlatformBackgroundTaskIdentifier;
#define OGPlatformBackgroundTaskInvalid ((OGPlatformBackgroundTaskIdentifier)-1)
FOUNDATION_EXPORT OGPlatformBackgroundTaskIdentifier OGPlatformBeginBackgroundTask(UIApplication *application, void (^expirationHandler)(void));
FOUNDATION_EXPORT void OGPlatformEndBackgroundTask(UIApplication *application, OGPlatformBackgroundTaskIdentifier identifier);
FOUNDATION_EXPORT BOOL OGPlatformViewControllerIsTransitioning(UIViewController *viewController);
FOUNDATION_EXPORT NSArray *OGPlatformChildViewControllers(UIViewController *viewController);
FOUNDATION_EXPORT BOOL OGPlatformAccessibilityInvertColorsEnabled(void);
FOUNDATION_EXPORT void OGPlatformHideAccessibilityElements(UIView *view);
FOUNDATION_EXPORT BOOL OGPlatformSupportsModernLoginIntro(void);
FOUNDATION_EXPORT BOOL OGPlatformControlAnimationsEnabled(void);
FOUNDATION_EXPORT BOOL OGPlatformTransientAnimationsEnabled(void);
FOUNDATION_EXPORT void OGPlatformInstallUIKitGuards(void);
FOUNDATION_EXPORT NSURL *OGPlatformBundleResourceURL(NSBundle *bundle, NSString *name, NSString *extension);
FOUNDATION_EXPORT void OGPlatformConfigureWebViewMediaPlayback(id webView, BOOL allowsInlinePlayback, BOOL requiresUserAction);

typedef NSInteger OGPlatformMessageComposeResult;
enum
{
    OGPlatformMessageComposeResultCancelled = 0,
    OGPlatformMessageComposeResultSent = 1,
    OGPlatformMessageComposeResultFailed = 2
};

FOUNDATION_EXPORT BOOL OGPlatformCanSendTextMessage(void);
FOUNDATION_EXPORT id OGPlatformCreateTextMessageComposer(id delegate, NSArray *recipients, NSString *body);
FOUNDATION_EXPORT NSArray *OGPlatformTextMessageComposerRecipients(id composer);
FOUNDATION_EXPORT NSString *OGPlatformTextMessageComposerBody(id composer);
FOUNDATION_EXPORT BOOL OGPlatformOpenTextMessage(NSArray *recipients);

FOUNDATION_EXPORT id OGPlatformCreateLocalNotification(void);
FOUNDATION_EXPORT id OGPlatformLocalNotificationFromLaunchOptions(NSDictionary *launchOptions);
FOUNDATION_EXPORT NSDictionary *OGPlatformLocalNotificationUserInfo(id notification);
FOUNDATION_EXPORT NSString *OGPlatformLocalNotificationSoundName(id notification);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationFireDate(id notification, NSDate *fireDate);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationAlertBody(id notification, NSString *alertBody);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationSoundName(id notification, NSString *soundName);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationUserInfo(id notification, NSDictionary *userInfo);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationCategory(id notification, NSString *category);
FOUNDATION_EXPORT void OGPlatformSetLocalNotificationAlertTitle(id notification, NSString *alertTitle);
FOUNDATION_EXPORT NSString *OGPlatformDefaultLocalNotificationSoundName(void);
FOUNDATION_EXPORT void OGPlatformPresentLocalNotificationNow(UIApplication *application, id notification);
FOUNDATION_EXPORT BOOL OGPlatformSetBackgroundFetchEnabled(UIApplication *application, BOOL enabled);
FOUNDATION_EXPORT void OGPlatformScheduleLocalNotification(UIApplication *application, id notification);
FOUNDATION_EXPORT void OGPlatformCancelLocalNotification(UIApplication *application, id notification);
FOUNDATION_EXPORT void OGPlatformCancelAllLocalNotifications(UIApplication *application);
FOUNDATION_EXPORT id OGPlatformCreateUserNotificationAction(NSString *identifier, NSString *title, BOOL destructive, BOOL authenticationRequired, BOOL foreground, BOOL textInput);
FOUNDATION_EXPORT id OGPlatformCreateUserNotificationCategory(NSString *identifier, NSArray *defaultActions, NSArray *minimalActions);
FOUNDATION_EXPORT BOOL OGPlatformUserNotificationSettingsSupported(UIApplication *application);
FOUNDATION_EXPORT BOOL OGPlatformRegisterUserNotificationSettings(UIApplication *application, NSArray *categories);
