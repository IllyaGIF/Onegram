#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/LegacyComponents/PSCoding.h"

@class SSignal;
@class TLInputPeer;

@interface TGSendAsPeer : NSObject <PSCoding>

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, readonly) bool premiumRequired;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *firstName;
@property (nonatomic, copy, readonly) NSString *lastName;
@property (nonatomic, copy, readonly) NSString *avatarUrl;

- (TLInputPeer *)inputPeer;
+ (instancetype)peerWithId:(int64_t)peerId;

@end

@interface TGSendAsState : NSObject
@property (nonatomic, copy, readonly) NSArray *peers;
@property (nonatomic, strong, readonly) TGSendAsPeer *selectedPeer;
@end

@interface TGSendAsSignals : NSObject

+ (SSignal *)availableSendersForPeerId:(int64_t)peerId accessHash:(int64_t)accessHash;
+ (SSignal *)selectSender:(TGSendAsPeer *)sender peerId:(int64_t)peerId accessHash:(int64_t)accessHash;
+ (TGSendAsPeer *)selectedSenderForPeerId:(int64_t)peerId;

@end
