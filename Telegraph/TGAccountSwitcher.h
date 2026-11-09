#import <Foundation/Foundation.h>

@class TGAccountRecord;
@class TGUser;

FOUNDATION_EXPORT NSString *const TGAccountSwitcherAccountsDidChangeNotification;

@interface TGAccountSwitcher : NSObject

+ (TGAccountSwitcher *)instance;
+ (int64_t)receiverUserIdFromPayload:(NSDictionary *)payload;

- (bool)isSwitching;
- (bool)canCancelAddingAccount;

- (void)switchToAccount:(TGAccountRecord *)account;
- (void)routeNotificationPayload:(NSDictionary *)payload completion:(void (^)(bool routed))completion;
- (void)addAccount;
- (void)cancelAddingAccount;

- (void)refreshActiveAccount;
- (void)updateActiveAccountWithUser:(TGUser *)user;
- (bool)consumeAuthorizationWithUserId:(int64_t)userId;
- (bool)switchToRemainingAccountAfterLogout;
- (NSArray *)otherAuthorizedUserIds;

@end
