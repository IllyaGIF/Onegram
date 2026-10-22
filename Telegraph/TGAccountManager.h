#import <Foundation/Foundation.h>

@interface TGAccountRecord : NSObject

@property (nonatomic, strong, readonly) NSString *accountId;
@property (nonatomic, readonly) int32_t userId;
@property (nonatomic, strong, readonly) NSString *firstName;
@property (nonatomic, strong, readonly) NSString *lastName;
@property (nonatomic, strong, readonly) NSString *phoneNumber;

- (NSString *)displayName;

@end

@interface TGAccountManager : NSObject

+ (TGAccountManager *)instance;
+ (void)performLaunchRecovery;

- (NSArray *)accounts;
- (NSArray *)authorizedAccounts;
- (TGAccountRecord *)activeAccount;
- (TGAccountRecord *)accountWithId:(NSString *)accountId;
- (TGAccountRecord *)accountWithUserId:(int32_t)userId;

- (bool)updateActiveAccountWithUserId:(int32_t)userId firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)phoneNumber;
- (NSString *)avatarPathForAccount:(TGAccountRecord *)account;

- (TGAccountRecord *)createAccount;
- (bool)transferActiveSlotToAccount:(TGAccountRecord *)account error:(NSError **)error;
- (void)removeInactiveAccount:(TGAccountRecord *)account;

@end
