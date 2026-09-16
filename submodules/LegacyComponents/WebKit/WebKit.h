#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import <WebKit/WKWebView.h>
#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKNavigation.h>
#import <WebKit/WKNavigationAction.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKScriptMessage.h>
#import <WebKit/WKScriptMessageHandler.h>
#import <WebKit/WKFrameInfo.h>
#import <WebKit/WKPreferences.h>
#import <WebKit/WKUserScript.h>
#import <WebKit/WKUserContentController.h>
#else

typedef NSInteger WKUserScriptInjectionTime;
#define WKUserScriptInjectionTimeAtDocumentStart 0
#define WKUserScriptInjectionTimeAtDocumentEnd 1

typedef NSInteger WKNavigationActionPolicy;
#define WKNavigationActionPolicyCancel 0
#define WKNavigationActionPolicyAllow 1

@class WKUserScript;
@class WKScriptMessage;
@class WKNavigation;
@class WKNavigationAction;

@protocol WKNavigationDelegate <NSObject>
@end

@protocol WKScriptMessageHandler <NSObject>
- (void)userContentController:(id)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;
@end

@interface WKScriptMessage : NSObject
@property (nonatomic, readonly) id body;
@end

@interface WKFrameInfo : NSObject
@end

@interface WKNavigation : NSObject
@end

@interface WKNavigationAction : NSObject
@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) WKFrameInfo *targetFrame;
@end

@interface WKUserScript : NSObject
- (instancetype)initWithSource:(NSString *)source injectionTime:(WKUserScriptInjectionTime)injectionTime forMainFrameOnly:(BOOL)forMainFrameOnly;
@end

@interface WKPreferences : NSObject
@property (nonatomic) BOOL javaScriptEnabled;
@end

@interface WKUserContentController : NSObject
- (void)addUserScript:(WKUserScript *)userScript;
- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name;
@end

@interface WKWebViewConfiguration : NSObject
@property (nonatomic, retain) WKUserContentController *userContentController;
@property (nonatomic, retain) WKPreferences *preferences;
@property (nonatomic) BOOL allowsInlineMediaPlayback;
@property (nonatomic) BOOL requiresUserActionForMediaPlayback;
@property (nonatomic) BOOL mediaPlaybackRequiresUserAction;
@property (nonatomic) BOOL allowsPictureInPictureMediaPlayback;
@end

@interface WKWebView : UIView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration;
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) double estimatedProgress;
@property (nonatomic, assign) id<WKNavigationDelegate> navigationDelegate;
- (WKNavigation *)loadRequest:(NSURLRequest *)request;
- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id result, NSError *error))completionHandler;
@end

#endif
