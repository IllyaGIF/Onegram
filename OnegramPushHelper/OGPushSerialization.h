#import <Foundation/Foundation.h>

#import "../submodules/MtProtoKit/MTProtoKit/MTSerialization.h"

typedef id (^OGPushUpdatesStateParser)(NSData *);

@interface OGPushIncomingObject : NSObject

@property (nonatomic, readonly) int32_t signature;
@property (nonatomic, readonly) bool requiresApplication;
@property (nonatomic, readonly) bool requiresStateCheck;
@property (nonatomic, readonly) uint64_t digest;

@end

@interface OGPushSerialization : NSObject <MTSerialization>

- (instancetype)initWithLayer:(NSUInteger)layer;

- (OGPushUpdatesStateParser)requestUpdatesState:(__autoreleasing NSData **)data;

+ (NSData *)pingDelayDisconnectPayloadWithPingId:(int64_t)pingId disconnectDelay:(int32_t)disconnectDelay;

@end
