#import <Foundation/Foundation.h>

#import "../submodules/MtProtoKit/MTProtoKit/MTSerialization.h"

typedef id (^OGHelperUpdatesStateParser)(NSData *);

@interface OGHelperIncomingObject : NSObject

@property (nonatomic, readonly) int32_t signature;
@property (nonatomic, readonly) bool requiresApplication;
@property (nonatomic, readonly) bool requiresStateCheck;
@property (nonatomic, readonly) uint64_t digest;

@end

@interface OGHelperSerialization : NSObject <MTSerialization>

- (instancetype)initWithLayer:(NSUInteger)layer;

- (OGHelperUpdatesStateParser)requestUpdatesState:(__autoreleasing NSData **)data;

+ (NSData *)pingDelayDisconnectPayloadWithPingId:(int64_t)pingId disconnectDelay:(int32_t)disconnectDelay;

@end
