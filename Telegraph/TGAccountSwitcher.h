#import <Foundation/Foundation.h>

@class TGAccountRecord;
@class TGUser;

FOUNDATION_EXPORT NSString *const TGAccountSwitcherAccountsDidChangeNotification;

@interface TGAccountSwitcher : NSObject

+ (TGAccountSwitcher *)instance;

- (bool)isSwitching;
- (bool)canCancelAddingAccount;

- (void)switchToAccount:(TGAccountRecord *)account;
- (void)routeNotificationPayload:(NSDictionary *)payload completion:(void (^)(bool routed))completion;
- (void)addAccount;
- (void)cancelAddingAccount;

- (void)refreshActiveAccount;
- (void)updateActiveAccountWithUser:(TGUser *)user;
- (bool)consumeAuthorizationWithUserId:(int32_t)userId;
- (bool)switchToRemainingAccountAfterLogout;
- (NSArray *)otherAuthorizedUserIds;

@end
