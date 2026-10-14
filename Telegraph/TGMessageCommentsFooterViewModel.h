#import "TGModernViewModel.h"

@class TGPresentation;

@interface TGMessageCommentsFooterReplier : NSObject

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) bool isUser;
@property (nonatomic, copy, readonly) NSString *avatarUrl;
@property (nonatomic, copy, readonly) NSString *firstName;
@property (nonatomic, copy, readonly) NSString *lastName;

+ (NSArray *)repliersWithPeerIds:(NSArray *)peerIds;

@end

@interface TGMessageCommentsFooterViewModel : TGModernViewModel

@property (nonatomic, copy) void (^pressed)(void);
@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, copy) NSArray *repliers;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) int32_t count;

@end
