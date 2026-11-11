#ifndef OG_COMPAT_WATCHCONNECTIVITY_H
#define OG_COMPAT_WATCHCONNECTIVITY_H

#import <Foundation/Foundation.h>

extern NSString * const WCErrorDomain;

typedef NSInteger WCErrorCode;
#define WCErrorCodeNotReachable 7007
#define WCErrorCodeDeliveryFailed 7014

@protocol WCSessionDelegate <NSObject>
@end

@interface WCSessionFile : NSObject
@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSDictionary *metadata;
@end

@interface WCSessionFileTransfer : NSObject
@end

@interface WCSession : NSObject
@property (nonatomic, assign) id<WCSessionDelegate> delegate;
@property (nonatomic, readonly, getter=isReachable) BOOL reachable;
@property (nonatomic, readonly, getter=isPaired) BOOL paired;
@property (nonatomic, readonly, getter=isWatchAppInstalled) BOOL watchAppInstalled;
@property (nonatomic, readonly) NSDictionary *applicationContext;
@property (nonatomic, readonly) NSURL *watchDirectoryURL;
+ (BOOL)isSupported;
+ (WCSession *)defaultSession;
- (void)activateSession;
- (BOOL)updateApplicationContext:(NSDictionary *)applicationContext error:(NSError **)error;
- (void)sendMessageData:(NSData *)messageData replyHandler:(void (^)(NSData *replyMessageData))replyHandler errorHandler:(void (^)(NSError *error))errorHandler;
- (WCSessionFileTransfer *)transferFile:(NSURL *)file metadata:(NSDictionary *)metadata;
- (void)transferUserInfo:(NSDictionary *)userInfo;
@end

#endif
