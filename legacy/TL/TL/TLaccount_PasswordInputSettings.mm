#import "TLaccount_PasswordInputSettings.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLaccount_PasswordInputSettings


- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

@implementation TLaccount_PasswordInputSettings$account_passwordInputSettings : TLaccount_PasswordInputSettings


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xf19c121e;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x4281a929;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLaccount_PasswordInputSettings$account_passwordInputSettings *object = [[TLaccount_PasswordInputSettings$account_passwordInputSettings alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

