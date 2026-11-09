#import <Foundation/Foundation.h>

@class MTRequest;
@class MTRpcError;

@protocol MTRequestInterceptor <NSObject>

- (bool)requestInterceptorShouldSendRequest:(MTRequest *)request;
- (bool)requestInterceptor:(MTRequest *)request completedWithData:(NSData *)data error:(MTRpcError *)error replacementData:(NSData *__autoreleasing *)replacementData replacementError:(MTRpcError *__autoreleasing *)replacementError;

@end
