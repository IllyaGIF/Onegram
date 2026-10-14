#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/LegacyComponents/PSCoding.h"

@interface TGCommunity : NSObject <PSCoding>

@property (nonatomic, readonly) int64_t communityId;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, strong, readonly) NSString *title;

- (instancetype)initWithCommunityId:(int64_t)communityId accessHash:(int64_t)accessHash title:(NSString *)title;

- (TGCommunity *)communityByMergingCommunity:(TGCommunity *)community;

@end

@interface TGCommunityChats : NSObject

@property (nonatomic, strong, readonly) TGCommunity *community;
@property (nonatomic, strong, readonly) NSArray *joinedConversations;
@property (nonatomic, strong, readonly) NSArray *viewableConversations;

- (instancetype)initWithCommunity:(TGCommunity *)community joinedConversations:(NSArray *)joinedConversations viewableConversations:(NSArray *)viewableConversations;

@end
