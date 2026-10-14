#import <Foundation/Foundation.h>

@class AWGConfig;

typedef NS_ENUM(NSInteger, AWGHandshakeState) {
    AWGHandshakeStateIdle = 0,
    AWGHandshakeStateInitSent,
    AWGHandshakeStateEstablished,
    AWGHandshakeStateFailed
};

extern const NSUInteger kAWGInitiationLength;
extern const NSUInteger kAWGResponseLength;
extern const NSUInteger kAWGTransportHeaderLen;

@interface AWGHandshake : NSObject

@property (nonatomic, readonly) AWGHandshakeState state;
@property (nonatomic, readonly) uint32_t localIndex;
@property (nonatomic, readonly) uint32_t remoteIndex;

@property (nonatomic, readonly) NSData *sendingKey;
@property (nonatomic, readonly) NSData *receivingKey;

- (instancetype)initWithConfig:(AWGConfig *)config;

- (void)reset;

- (NSArray *)buildInitiationDatagrams;

- (BOOL)processResponse:(NSData *)packet error:(NSError **)error;

@property (nonatomic, readonly) BOOL isEstablished;


- (NSData *)transportHeaderWithCounter:(uint64_t)counter;
- (size_t)writeTransportHeader:(uint8_t *)outHeader counter:(uint64_t)counter;

- (NSUInteger)transportPayloadOffsetForPacket:(NSData *)packet counter:(uint64_t *)outCounter;
- (NSUInteger)transportPayloadOffsetForBytes:(const uint8_t *)bytes length:(size_t)length counter:(uint64_t *)outCounter;

+ (void)transportNonce:(uint8_t *)out12 forCounter:(uint64_t)counter;

@end
