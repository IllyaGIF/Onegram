#import "TGPassportErrors.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGStringUtils.h"

#import "TGPassportSignals.h"
#import "TLSecureValueError.h"

NSString *const TGPassportErrorTargetMain = @"main";
NSString *const TGPassportErrorTargetData = @"data";
NSString *const TGPassportErrorTargetFrontSide = @"frontSide";
NSString *const TGPassportErrorTargetReverseSide = @"reverseSide";
NSString *const TGPassportErrorTargetSelfie = @"selfie";
NSString *const TGPassportErrorTargetTranslation = @"translation";
NSString *const TGPassportErrorTargetFiles = @"files";

@implementation NSArray (DeepCopy)

- (NSArray *)deepCopy {
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[self count]];
    for (id obj in self) {
        id copiedObject = nil;
        if ([obj respondsToSelector:@selector(deepCopy)])
            copiedObject = [obj deepCopy];
        else
            copiedObject = [obj copy];
        [result addObject:copiedObject];
    }
    return [NSArray arrayWithArray:result];
}

- (NSMutableArray *)mutableDeepCopy {
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[self count]];
    for (id obj in self) {
        id copiedObject = nil;
        if ([obj respondsToSelector:@selector(mutableDeepCopy)])
            copiedObject = [obj mutableDeepCopy];
        else if ([obj respondsToSelector:@selector(mutableCopyWithZone:)])
            copiedObject = [obj mutableCopy];
        else if ([obj respondsToSelector:@selector(deepCopy)])
            copiedObject = [obj deepCopy];
        else
            copiedObject = [obj copy];
        [result addObject:copiedObject];
    }
    return result;
}

@end

@implementation NSDictionary (DeepCopy)

- (NSDictionary *)deepCopy {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    for (id key in self) {
        id obj = [self objectForKey:key];
        id copiedObject = nil;
        id copiedKey = nil;

        if ([obj respondsToSelector:@selector(deepCopy)])
            copiedObject = [obj deepCopy];
        else
            copiedObject = [obj copy];

        if ([key respondsToSelector:@selector(deepCopy)])
            copiedKey = [key deepCopy];
        else
            copiedKey = [key copy];

        [result setObject:copiedObject forKey:copiedKey];
    }
    return [NSDictionary dictionaryWithDictionary:result];
}

- (NSMutableDictionary *)mutableDeepCopy {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    for (id key in self) {
        id obj = [self objectForKey:key];
        id copiedObject = nil;
        id copiedKey = nil;

        if ([obj respondsToSelector:@selector(mutableDeepCopy)])
            copiedObject = [obj mutableDeepCopy];
        else if ([obj respondsToSelector:@selector(mutableCopyWithZone:)])
            copiedObject = [obj mutableCopy];
        else if ([obj respondsToSelector:@selector(deepCopy)])
            copiedObject = [obj deepCopy];
        else
            copiedObject = [obj copy];

        if ([key respondsToSelector:@selector(deepCopy)])
            copiedKey = [key deepCopy];
        else
            copiedKey = [key copy];

        [result setObject:copiedObject forKey:copiedKey];
    }
    return result;
}

@end

@interface TGPassportErrors ()
{
    NSMutableDictionary *_dict;
}
@end

@implementation TGPassportErrors

- (instancetype)initWithArray:(NSArray *)array fileHashes:(NSSet *)fileHashes
{
    if (array.count == 0)
        return nil;
    
    self = [super init];
    if (self != nil)
    {
        _dict = [[NSMutableDictionary alloc] init];
        
        for (TLSecureValueError *error in array)
        {
            TGPassportType scope = [TGPassportSignals typeForSecureValueType:error.type];
            
            NSDictionary *scopeDict = _dict[@(scope)];
            if (scopeDict == nil)
            {
                NSMutableDictionary *mainErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *dataErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *frontSideErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *reverseSideErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *selfieErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *translationErrors = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *fileErrors = [[NSMutableDictionary alloc] init];
                scopeDict = @{ TGPassportErrorTargetMain: mainErrors, TGPassportErrorTargetData: dataErrors, TGPassportErrorTargetFrontSide: frontSideErrors, TGPassportErrorTargetReverseSide: reverseSideErrors, TGPassportErrorTargetSelfie: selfieErrors, TGPassportErrorTargetTranslation: translationErrors, TGPassportErrorTargetFiles: fileErrors };
                _dict[@(scope)] = scopeDict;
            }
            
            if ([error isKindOfClass:[TLSecureValueError$secureValueError class]])
            {
                NSMutableDictionary *mainErrors = scopeDict[TGPassportErrorTargetMain];
                mainErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorData class]])
            {
                NSMutableDictionary *dataErrors = scopeDict[TGPassportErrorTargetData];
                NSString *field = ((TLSecureValueError$secureValueErrorData *)error).field;
                if (field.length > 0)
                    dataErrors[field] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorFrontSide class]])
            {
                NSMutableDictionary *frontSideErrors = scopeDict[TGPassportErrorTargetFrontSide];
                NSString *fileHash = [TGStringUtils stringByEncodingInBase64:((TLSecureValueError$secureValueErrorFrontSide *)error).file_hash];
                if ([fileHashes containsObject:fileHash])
                    frontSideErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorReverseSide class]])
            {
                NSMutableDictionary *reverseSideErrors = scopeDict[TGPassportErrorTargetReverseSide];
                NSString *fileHash = [TGStringUtils stringByEncodingInBase64:((TLSecureValueError$secureValueErrorReverseSide *)error).file_hash];
                if ([fileHashes containsObject:fileHash])
                    reverseSideErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorSelfie class]])
            {
                NSMutableDictionary *selfieErrors = scopeDict[TGPassportErrorTargetSelfie];
                NSString *fileHash = [TGStringUtils stringByEncodingInBase64:((TLSecureValueError$secureValueErrorSelfie *)error).file_hash];
                if ([fileHashes containsObject:fileHash])
                    selfieErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorTranslationFile class]])
            {
                NSMutableDictionary *translationErrors = scopeDict[TGPassportErrorTargetTranslation];
                NSString *fileHash = [TGStringUtils stringByEncodingInBase64:((TLSecureValueError$secureValueErrorTranslationFile *)error).file_hash];
                if (fileHash == nil)
                    translationErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
                else if ([fileHashes containsObject:fileHash])
                    translationErrors[fileHash] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorTranslationFiles class]])
            {
                NSMutableDictionary *translationErrors = scopeDict[TGPassportErrorTargetTranslation];
                translationErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorFile class]])
            {
                NSMutableDictionary *fileErrors = scopeDict[TGPassportErrorTargetFiles];
                NSString *fileHash = [TGStringUtils stringByEncodingInBase64:((TLSecureValueError$secureValueErrorFile *)error).file_hash];
                if (fileHash == nil)
                    fileErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
                else if ([fileHashes containsObject:fileHash])
                    fileErrors[fileHash] = [[TGPassportError alloc] initWithError:error];
            }
            else if ([error isKindOfClass:[TLSecureValueError$secureValueErrorFiles class]])
            {
                NSMutableDictionary *fileErrors = scopeDict[TGPassportErrorTargetFiles];
                fileErrors[@"common"] = [[TGPassportError alloc] initWithError:error];
            }
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGPassportErrors *errors = [[TGPassportErrors alloc] init];
    errors->_dict = [_dict mutableDeepCopy];
    return errors;
}

- (NSArray *)errorsForType:(TGPassportType)type
{
    NSArray *mainErrors = [_dict[@(type)][TGPassportErrorTargetMain] allValues];
    NSArray *dataErrors = [_dict[@(type)][TGPassportErrorTargetData] allValues];
    NSArray *frontSideErrors = [_dict[@(type)][TGPassportErrorTargetFrontSide] allValues];
    NSArray *reverseSideErrors = [_dict[@(type)][TGPassportErrorTargetReverseSide] allValues];
    NSArray *selfieErrors = [_dict[@(type)][TGPassportErrorTargetSelfie] allValues];
    NSArray *translationErrors = [_dict[@(type)][TGPassportErrorTargetTranslation] allValues];
    NSArray *fileErrors = [_dict[@(type)][TGPassportErrorTargetFiles] allValues];
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [result addObjectsFromArray:mainErrors];
    [result addObjectsFromArray:dataErrors];
    [result addObjectsFromArray:frontSideErrors];
    [result addObjectsFromArray:reverseSideErrors];
    [result addObjectsFromArray:selfieErrors];
    [result addObjectsFromArray:translationErrors];
    [result addObjectsFromArray:fileErrors];
    return result;
}

- (NSArray *)fieldErrorsForType:(TGPassportType)type
{
    NSArray *main = [_dict[@(type)][TGPassportErrorTargetMain] allValues];
    NSArray *all = [_dict[@(type)][TGPassportErrorTargetData] allValues];
    return [main arrayByAddingObjectsFromArray:all];
}

- (TGPassportError *)errorForTypeMain:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetMain][@"common"];
}

- (TGPassportError *)errorForType:(TGPassportType)type dataField:(NSString *)field
{
    return _dict[@(type)][TGPassportErrorTargetData][field];
}

- (TGPassportError *)errorForTypeFiles:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetFiles][@"common"];
}

- (TGPassportError *)errorForTypeFrontSide:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetFrontSide][@"common"];
}

- (TGPassportError *)errorForTypeReverseSide:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetReverseSide][@"common"];
}

- (TGPassportError *)errorForTypeSelfie:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetSelfie][@"common"];
}

- (TGPassportError *)errorForTypeTranslation:(TGPassportType)type
{
    return _dict[@(type)][TGPassportErrorTargetTranslation][@"common"];
}

- (TGPassportError *)errorForType:(TGPassportType)type fileHash:(NSString *)fileHash
{
    return _dict[@(type)][TGPassportErrorTargetFiles][fileHash];
}

- (TGPassportError *)errorForType:(TGPassportType)type translationFileHash:(NSString *)fileHash
{
    return _dict[@(type)][TGPassportErrorTargetTranslation][fileHash];
}

- (void)correctMainErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
}

- (void)correctErrorForType:(TGPassportType)type dataField:(NSString *)field
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetData] removeObjectForKey:field];
}

- (void)correctFrontSideErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetFrontSide] removeObjectForKey:@"common"];
}

- (void)correctReverseSideErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetReverseSide] removeObjectForKey:@"common"];
}

- (void)correctSelfieErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetSelfie] removeObjectForKey:@"common"];
}

- (void)correctTranslationErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetTranslation] removeObjectForKey:@"common"];
}

- (void)correctFilesErrorForType:(TGPassportType)type
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetFiles] removeObjectForKey:@"common"];
}

- (void)correctFileErrorForType:(TGPassportType)type fileHash:(NSString *)fileHash
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetFiles] removeObjectForKey:fileHash];
}

- (void)correctTranslationErrorForType:(TGPassportType)type fileHash:(NSString *)fileHash
{
    [_dict[@(type)][TGPassportErrorTargetMain] removeObjectForKey:@"common"];
    [_dict[@(type)][TGPassportErrorTargetTranslation] removeObjectForKey:fileHash];
}

@end


@implementation TGPassportError

- (instancetype)initWithError:(TLSecureValueError *)error
{
    self = [super init];
    if (self != nil)
    {
        if ([error isKindOfClass:[TLSecureValueError$secureValueErrorData class]])
            _key = ((TLSecureValueError$secureValueErrorData *)error).field;
        _text = error.text;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGPassportError *error = [[TGPassportError alloc] init];
    error->_key = _key;
    error->_text = _text;
    return error;
}

@end
