#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TGIOS6MessageViewsRpc : TLMetaRpc

@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic, strong) NSArray *messageIds;
@property (nonatomic) bool increment;

+ (NSDictionary *)parseResponseFromStream:(NSInputStream *)is signature:(int32_t)signature error:(__autoreleasing NSError **)error;

@end
