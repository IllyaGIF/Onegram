#import "TGCheckPasswordActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "TGTelegramNetworking.h"
#import "TL/TLMetaScheme.h"

#import "TGTwoStepConfig.h"
#import "TGTwoStepUtils.h"

#import "TGUser+Telegraph.h"
#import "TGUserDataRequestBuilder.h"
#import "TGTelegraph.h"
#import "TGAppDelegate.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTProto.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"

@interface TGCheckPasswordActor ()
{
    NSString *_plaintextPassword;
    TGTwoStepConfig *_twoStepConfig;
    bool _finished;
    bool _qrLogin;
}

@end

@implementation TGCheckPasswordActor

- (bool)markFinished
{
    @synchronized (self)
    {
        if (_finished)
            return false;
        _finished = true;
        return true;
    }
}

- (void)completeWithUserDescription:(id)userDescription source:(NSString *)source
{
    if (userDescription == nil)
        return;

    TGUser *user = [[TGUser alloc] initWithTelegraphUserDesc:userDescription];
    if (user == nil || user.uid == 0)
    {
        TGLog(@"QR password %@ returned invalid self user", source);
        return;
    }

    if (![self markFinished])
        return;


    [TGUserDataRequestBuilder executeUserObjectsUpdate:@[user]];
    [ActionStageInstance() actionCompleted:self.path result:@{@"userId": @(user.uid)}];
}

- (void)scheduleAuthorizationProbe
{
    TGCheckPasswordActor *actorReference1 = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        TGCheckPasswordActor *strongSelf = actorReference1;
        if (strongSelf == nil || strongSelf->_finished)
            return;

        MTRequest *probeRequest = [[MTRequest alloc] init];
        probeRequest.dependsOnPasswordEntry = false;

        TLRPCusers_getUsers$users_getUsers *getUsers = [[TLRPCusers_getUsers$users_getUsers alloc] init];
        getUsers.n_id = @[[[TLInputUser$inputUserSelf alloc] init]];
        probeRequest.body = getUsers;

        [probeRequest setCompleted:^(NSArray *users, __unused NSTimeInterval timestamp, MTRpcError *error)
        {
            TGCheckPasswordActor *strongSelf = actorReference1;
            if (strongSelf == nil || strongSelf->_finished)
                return;

            if (error == nil && users.count != 0)
            {
                [strongSelf completeWithUserDescription:users[0] source:@"selfProbe"];
            }
            else
            {
                TGLog(@"QR password post-check probe pending error=%@", error.errorDescription ?: @"none");
            }
        }];

        [[TGTelegramNetworking instance] addRequest:probeRequest];
    });
}

+ (void)load
{
    @autoreleasepool
    {
        [ASActor registerActorClass:self];
    }
}

+ (NSString *)genericPath
{
    return @"/checkPassword/@";
}

- (void)execute:(NSDictionary *)options
{
    _plaintextPassword = options[@"password"];
    _twoStepConfig = options[@"twoStepConfig"];
    _qrLogin = [options[@"qrLogin"] boolValue];
    
    MTRequest *request = [[MTRequest alloc] init];
    request.dependsOnPasswordEntry = false;
    request.body = [[TLRPCaccount_getPassword$account_getPassword alloc] init];
    
    TGCheckPasswordActor *actorReference2 = self;
    [request setCompleted:^(TLaccount_Password *password, __unused NSTimeInterval timestamp, MTRpcError *error)
    {
        TGCheckPasswordActor *strongSelf = actorReference2;
        if (error == nil)
            [strongSelf passwordRequestSuccess:password];
        else
            [strongSelf passwordRequestFailed:error.errorDescription];
    }];
    
    self.cancelToken = request.internalId;
    
    [[TGTelegramNetworking instance] addRequest:request];
}

- (void)passwordRequestSuccess:(TLaccount_Password *)password
{
    if (password.flags & (1 << 2))
    {
        TGPasswordKdfAlgo *freshAlgo = [TGPasswordKdfAlgo algoWithTL:password.current_algo];
        TLInputCheckPasswordSRP *srpPassword = [TGTwoStepUtils srpPasswordWithPassword:_plaintextPassword
                                                                                 algo:freshAlgo
                                                                                srpId:password.srp_id
                                                                                 srpB:password.srp_B];


        if (srpPassword == nil)
        {
            TGLog(@"QR password SRP generation failed");
            [ActionStageInstance() actionFailed:self.path reason:TGCheckPasswordErrorCodeInvalidPassword];
            return;
        }

        MTRequest *request = [[MTRequest alloc] init];
        request.dependsOnPasswordEntry = false;
        TLRPCauth_checkPassword$auth_checkPassword *checkPassword = [[TLRPCauth_checkPassword$auth_checkPassword alloc] init];
        checkPassword.password = srpPassword;
        
        request.body = checkPassword;
        
        TGCheckPasswordActor *actorReference3 = self;
        [request setCompleted:^(TLauth_Authorization *auth, __unused NSTimeInterval timestamp, MTRpcError *error)
        {
            TGCheckPasswordActor *strongSelf = actorReference3;
            if (error == nil)
                [strongSelf checkPasswordSuccess:auth];
            else
                [strongSelf checkPasswordFailed:error.errorDescription];
        }];
        
        request.shouldContinueExecutionWithErrorContext = ^bool (__unused MTRequestErrorContext *errorContext)
        {
            return false;
        };
        
        self.cancelToken = request.internalId;
        [[TGTelegramNetworking instance] addRequest:request];
        [self scheduleAuthorizationProbe];
    }
    else
    {
        [ActionStageInstance() actionCompleted:self.path result:nil];
    }
}

- (void)passwordRequestFailed:(NSString *)errorText
{
    TGLog(@"QR password account.getPassword error=%@", errorText);
    if ([self markFinished])
        [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)checkPasswordSuccess:(TLauth_Authorization *)auth
{    
    [self completeWithUserDescription:auth.user source:@"checkPassword"];
}

- (void)checkPasswordFailed:(NSString *)errorText
{
    TGLog(@"QR password auth.checkPassword error=%@", errorText);

    int errorCode = TGCheckPasswordErrorCodeInvalidPassword;
    if ([errorText rangeOfString:@"PASSWORD_HASH_INVALID"].location != NSNotFound)
        errorCode = TGCheckPasswordErrorCodeInvalidPassword;
    else if ([errorText rangeOfString:@"FLOOD_WAIT"].location != NSNotFound)
        errorCode = TGCheckPasswordErrorCodeFlood;
    
    if ([self markFinished])
        [ActionStageInstance() actionFailed:self.path reason:errorCode];
}

@end
