#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <QuickLook/QuickLook.h>
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
@interface TGDocumentController : QLPreviewController
#else
@interface TGDocumentController : TGViewController
#endif

@property (nonatomic, assign) bool previewMode;
@property (nonatomic, copy) void (^shareAction)(NSArray *peerIds, NSString *caption);

- (instancetype)initWithURL:(NSURL *)url messageId:(int32_t)messageId;

@property (nonatomic, assign) bool useDefaultAction;

@end
