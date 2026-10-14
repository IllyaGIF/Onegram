#import <Foundation/Foundation.h>

#import "TLMetaRpc.h"
#import "TLObject.h"

#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLInputMedia;
@class TLInputGeoPoint;


@interface TLRPCmessages_editMessage : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic) bool no_webpage;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t n_id;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) TLInputMedia *media;
@property (nonatomic, strong) NSArray *entities;
@property (nonatomic, strong) TLInputGeoPoint *geo_point;

@end
