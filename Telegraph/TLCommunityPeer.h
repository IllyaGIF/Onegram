#import <Foundation/Foundation.h>

#import "TLObject.h"

@class TLPeer;

@interface TLCommunityPeer : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic, strong) NSNumber *visible;
@property (nonatomic, strong) TLPeer *peer;

@property (nonatomic, readonly) bool can_view_history;

@end

@interface TLCommunityPeer$communityPeer : TLCommunityPeer

@end
