#import "TGAuthSessionListSignals.h"

#import "TGTelegramNetworking.h"
#import "TGUserDataRequestBuilder.h"

#import "TL/TLMetaScheme.h"
#import "TL/TLBool.h"

#import "TGUser+Telegraph.h"

#import "TGAuthSession.h"

@interface TGAcceptLoginTokenRequest : TLMetaRpc
@property (nonatomic, strong) NSData *token;
@end

@implementation TGAcceptLoginTokenRequest
- (int32_t)TLconstructorSignature { return (int32_t)0xe894ad4d; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLAuthorization class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (void)TLserialize:(NSOutputStream *)stream { [stream writeBytes:self.token]; }
@end

@implementation TGAuthSessionListSignals

+ (NSData *)loginTokenFromQRCode:(NSString *)code
{
    NSString *prefix = @"tg://login?token=";
    if (![code hasPrefix:prefix] || code.length > 512)
        return nil;
    NSString *encoded = [code substringFromIndex:prefix.length];
    if (encoded.length == 0)
        return nil;
    NSMutableData *result = [[NSMutableData alloc] init];
    uint32_t accumulator = 0;
    int bits = 0;
    NSUInteger padding = 0;
    NSUInteger symbols = 0;
    for (NSUInteger index = 0; index < encoded.length; index++)
    {
        unichar c = [encoded characterAtIndex:index];
        if (c == '=')
        {
            padding++;
            if (padding > 2)
                return nil;
            continue;
        }
        if (padding != 0)
            return nil;
        int value;
        if (c >= 'A' && c <= 'Z') value = c - 'A';
        else if (c >= 'a' && c <= 'z') value = c - 'a' + 26;
        else if (c >= '0' && c <= '9') value = c - '0' + 52;
        else if (c == '-') value = 62;
        else if (c == '_') value = 63;
        else return nil;
        symbols++;
        accumulator = (accumulator << 6) | value;
        bits += 6;
        if (bits >= 8)
        {
            bits -= 8;
            uint8_t byte = (accumulator >> bits) & 0xff;
            [result appendBytes:&byte length:1];
        }
    }
    if (symbols % 4 == 1 || (bits != 0 && (accumulator & ((1u << bits) - 1)) != 0))
        return nil;
    if (padding != 0 && (encoded.length % 4 != 0 || padding != (4 - symbols % 4) % 4))
        return nil;
    return result.length == 0 ? nil : result;
}

+ (SSignal *)acceptLoginToken:(NSData *)token
{
    if (token.length == 0)
        return [SSignal fail:@"AUTH_TOKEN_INVALID"];
    TGAcceptLoginTokenRequest *request = [[TGAcceptLoginTokenRequest alloc] init];
    request.token = token;
    return [[[TGTelegramNetworking instance] requestSignal:request continueOnServerErrors:false failOnFloodErrors:true] timeout:30.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:@"NETWORK_TIMEOUT"]];
}

+ (SSignal *)authSessionList
{
    TLRPCaccount_getAuthorizations$account_getAuthorizations *getAuthorizations = [[TLRPCaccount_getAuthorizations$account_getAuthorizations alloc] init];
    return [[[[TGTelegramNetworking instance] requestSignal:getAuthorizations continueOnServerErrors:false failOnFloodErrors:true] timeout:30.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:@"NETWORK_TIMEOUT"]] map:^id(TLaccount_Authorizations *authorizations)
    {
        NSMutableArray *authSessions = [[NSMutableArray alloc] init];
        
        for (TLAuthorization *auth in authorizations.authorizations)
        {
            [authSessions addObject:[[TGAuthSession alloc] initWithSessionHash:auth.n_hash flags:auth.flags deviceModel:auth.device_model platform:auth.platform systemVersion:auth.system_version apiId:auth.api_id appName:auth.app_name appVersion:auth.app_version dateCreated:auth.date_created dateActive:auth.date_active ip:auth.ip country:auth.country region:auth.region]];
        }
        
        return authSessions;
    }];
}

+ (SSignal *)removeAllOtherSessions
{
    TLRPCauth_resetAuthorizations$auth_resetAuthorizations *resetAuthorizations = [[TLRPCauth_resetAuthorizations$auth_resetAuthorizations alloc] init];
    return [[[[TGTelegramNetworking instance] requestSignal:resetAuthorizations continueOnServerErrors:false failOnFloodErrors:true] timeout:30.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:@"NETWORK_TIMEOUT"]] mapToSignal:^SSignal *(TLBool *result)
    {
        if (![result boolValue])
            return [SSignal fail:@"SESSION_RESET_FAILED"];
        return [self authSessionList];
    }];
}

+ (SSignal *)removeSession:(TGAuthSession *)session
{
    if (session == nil || session.sessionHash == 0 || (session.flags & 1) != 0)
        return [SSignal fail:@"CURRENT_SESSION"];
    TLRPCaccount_resetAuthorization$account_resetAuthorization *resetAuthorization = [[TLRPCaccount_resetAuthorization$account_resetAuthorization alloc] init];
    resetAuthorization.n_hash = session.sessionHash;
    
    return [[[[TGTelegramNetworking instance] requestSignal:resetAuthorization continueOnServerErrors:false failOnFloodErrors:true] timeout:30.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:@"NETWORK_TIMEOUT"]] mapToSignal:^SSignal *(TLBool *result)
    {
        if (![result boolValue])
            return [SSignal fail:@"SESSION_RESET_FAILED"];
        return [self authSessionList];
    }];
}

+ (SSignal *)loggedAppsSessionList
{
    TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations *getWebAuthorizations = [[TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations alloc] init];
    return [[[TGTelegramNetworking instance] requestSignal:getWebAuthorizations] map:^id(TLaccount_WebAuthorizations *authorizations)
    {
        NSMutableArray *authSessions = [[NSMutableArray alloc] init];
        NSMutableDictionary *users = [[NSMutableDictionary alloc] init];
        NSMutableArray *updateUsers = [[NSMutableArray alloc] init];
        
        for (TLUser *userDesc in authorizations.users)
        {
            TGUser *user = [[TGUser alloc] initWithTelegraphUserDesc:userDesc];
            if (user != nil)
            {
                users[@(user.uid)] = user;
                [updateUsers addObject:user];
            }
        }
        
        [TGUserDataRequestBuilder executeUserObjectsUpdate:updateUsers];
        
        for (TLWebAuthorization *auth in authorizations.authorizations)
        {
            [authSessions addObject:[[TGAppSession alloc] initWithSessionHash:auth.n_hash bot:users[@(auth.bot_id)] domain:auth.domain browser:auth.browser platform:auth.platform dateCreated:auth.date_created dateActive:auth.date_active ip:auth.ip country:nil region:auth.region]];
        }
        
        return authSessions;
    }];
}

+ (SSignal *)removeAllAppSessions
{
    TLRPCaccount_resetWebAuthorizations$account_resetWebAuthorizations *resetWebAuthorizations = [[TLRPCaccount_resetWebAuthorizations$account_resetWebAuthorizations alloc] init];
    
    return [[TGTelegramNetworking instance] requestSignal:resetWebAuthorizations];
}

+ (SSignal *)removeAppSession:(TGAppSession *)session
{
    TLRPCaccount_resetWebAuthorization$account_resetWebAuthorization *resetWebAuthorization = [[TLRPCaccount_resetWebAuthorization$account_resetWebAuthorization alloc] init];
    resetWebAuthorization.n_hash = session.sessionHash;
    
    return [[[TGTelegramNetworking instance] requestSignal:resetWebAuthorization] mapToSignal:^SSignal *(__unused id result)
    {
        return [self loggedAppsSessionList];
    }];
}
@end
