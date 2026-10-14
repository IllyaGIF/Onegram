#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGAuthSession.h"
#import "TGAppSession.h"

@interface TGAuthSessionListSignals : NSObject

+ (SSignal *)authSessionList;
+ (SSignal *)removeAllOtherSessions;
+ (SSignal *)removeSession:(TGAuthSession *)session;
+ (NSData *)loginTokenFromQRCode:(NSString *)code;
+ (SSignal *)acceptLoginToken:(NSData *)token;

+ (SSignal *)loggedAppsSessionList;
+ (SSignal *)removeAllAppSessions;
+ (SSignal *)removeAppSession:(TGAppSession *)session;

@end
