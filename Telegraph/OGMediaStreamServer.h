#import <Foundation/Foundation.h>

#import "OGMediaFetchSession.h"

@interface OGMediaStream : NSObject

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) OGMediaFetchSession *session;

- (int64_t)size;
- (double)downloadRate;
- (bool)isComplete;
- (void)invalidate;

@end

@interface OGMediaStreamServer : NSObject

+ (OGMediaStreamServer *)sharedServer;

- (OGMediaStream *)streamWithDescriptor:(OGMediaFetchDescriptor *)descriptor publishPath:(NSString *)publishPath mimeType:(NSString *)mimeType pathExtension:(NSString *)pathExtension;

@end
