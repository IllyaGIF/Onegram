#import <UIKit/UIKit.h>

@interface TGPaidMessagesConfirmation : NSObject

+ (void)confirmMessagesCount:(NSUInteger)count price:(int64_t)price peerId:(int64_t)peerId controller:(UIViewController *)controller completion:(void (^)(bool confirmed))completion;
+ (void)confirmSendingToPeerIds:(NSArray *)peerIds messagesPerPeer:(NSUInteger)messagesPerPeer controller:(UIViewController *)controller completion:(void (^)(bool confirmed))completion;
+ (void)presentTopUpFromController:(UIViewController *)controller requiredStars:(int64_t)requiredStars completion:(void (^)(bool toppedUp))completion;
+ (void)handleSendError:(NSString *)errorType peerId:(int64_t)peerId;

@end
