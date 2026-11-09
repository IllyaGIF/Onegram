#import "OGStickerFrameSource.h"

@interface OGWebMStickerSource : NSObject <OGStickerFrameSource>

@property (nonatomic, readonly) NSString *failureReason;
@property (nonatomic, readonly) NSString *statistics;

- (instancetype)initWithData:(NSData *)data width:(size_t)width height:(size_t)height;

@end
