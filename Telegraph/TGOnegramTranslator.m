#import "TGOnegramTranslator.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "../legacy/TelegraphKit/TGCommon.h"

#import "TGOnegramSettings.h"

static NSString *const TGOnegramTranslatorErrorDomain = @"TGOnegramTranslator";
static const NSTimeInterval TGOnegramTranslatorTimeout = 20.0;
static const NSUInteger TGOnegramTranslatorMaximumLength = 5000;

@implementation TGOnegramTranslation

- (instancetype)initWithText:(NSString *)text sourceLanguage:(NSString *)sourceLanguage targetLanguage:(NSString *)targetLanguage
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _sourceLanguage = [sourceLanguage lowercaseString];
        _targetLanguage = targetLanguage;
    }
    return self;
}

@end

static NSError *TGOnegramTranslatorError(NSString *description)
{
    return [NSError errorWithDomain:TGOnegramTranslatorErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: description ?: TGLocalized(@"Translator.Error.Generic")}];
}

static NSString *TGOnegramTranslatorQueryEscape(NSString *string)
{
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, CFSTR(":/?#[]@!$&'()*+,;=\n\r"), kCFStringEncodingUTF8);
}

static NSString *TGOnegramTranslatorFormBody(NSArray *pairs)
{
    NSMutableArray *components = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index + 1 < pairs.count; index += 2)
        [components addObject:[[NSString alloc] initWithFormat:@"%@=%@", TGOnegramTranslatorQueryEscape(pairs[index]), TGOnegramTranslatorQueryEscape(pairs[index + 1])]];
    return [components componentsJoinedByString:@"&"];
}

@implementation TGOnegramTranslator

+ (NSArray *)providerTitles
{
    return @[@"Google", @"Microsoft", @"DeepL", TGLocalized(@"Translator.Provider.LLM")];
}

+ (NSArray *)languageCodes
{
    return @[@"en", @"ru", @"uk", @"be", @"kk", @"uz", @"de", @"fr", @"es", @"it", @"pt", @"pl", @"cs", @"nl", @"sv", @"fi", @"no", @"da", @"tr", @"ar", @"fa", @"he", @"hi", @"zh", @"ja", @"ko", @"id", @"vi", @"th", @"el", @"ro", @"hu", @"bg", @"sr", @"hr", @"ka", @"hy", @"az", @"et", @"lv", @"lt"];
}

+ (NSString *)displayNameForLanguage:(NSString *)code
{
    if (code.length == 0)
        return @"";
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:[self appLanguage]];
    NSString *name = [locale displayNameForKey:NSLocaleLanguageCode value:code];
    if (name.length == 0)
        return code;
    return [[[name substringToIndex:1] uppercaseString] stringByAppendingString:[name substringFromIndex:1]];
}

+ (NSString *)appLanguage
{
    NSString *code = effectiveLocalization().code;
    if (code.length == 0)
        code = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    NSRange separator = [code rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]];
    if (separator.location != NSNotFound)
        code = [code substringToIndex:separator.location];
    return [code lowercaseString];
}

+ (NSString *)targetLanguage
{
    NSString *target = [TGOnegramSettings stringForKey:TGOnegramSettingTranslatorTargetLanguage];
    return target.length != 0 ? target : [self appLanguage];
}

+ (NSString *)detectedLanguageForText:(NSString *)text
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    if (text.length == 0 || NSClassFromString(@"NSLinguisticTagger") == nil)
        return nil;
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeLanguage] options:0];
    tagger.string = text.length > 400 ? [text substringToIndex:400] : text;
    NSString *language = [tagger tagAtIndex:0 scheme:NSLinguisticTagSchemeLanguage tokenRange:NULL sentenceRange:NULL];
    if (language.length == 0 || [language isEqualToString:@"und"])
        return nil;
    NSRange separator = [language rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]];
    return separator.location == NSNotFound ? language : [language substringToIndex:separator.location];
#else
    return nil;
#endif
}

+ (bool)shouldOfferTranslationForText:(NSString *)text
{
    if (![TGOnegramSettings boolForKey:TGOnegramSettingTranslatorShowButton] || [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0)
        return false;
    NSString *language = [self detectedLanguageForText:text];
    if (language == nil)
        return true;
    if ([language isEqualToString:[self targetLanguage]])
        return false;
    return ![[TGOnegramSettings arrayForKey:TGOnegramSettingTranslatorSkipLanguages] containsObject:language];
}

+ (NSData *)performRequest:(NSMutableURLRequest *)request statusCode:(NSInteger *)statusCode error:(NSError **)error
{
    request.timeoutInterval = TGOnegramTranslatorTimeout;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
    NSHTTPURLResponse *response = nil;
    NSError *connectionError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&connectionError];
    if (statusCode != NULL)
        *statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? response.statusCode : 0;
    if (data == nil && error != NULL)
        *error = TGOnegramTranslatorError(connectionError.localizedDescription ?: TGLocalized(@"Translator.Error.Network"));
    return data;
}

+ (id)jsonFromData:(NSData *)data
{
    if (data.length == 0)
        return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

+ (TGOnegramTranslation *)googleTranslate:(NSString *)text target:(NSString *)target error:(NSError **)error
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://translate.googleapis.com/translate_a/single"]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [TGOnegramTranslatorFormBody(@[@"client", @"gtx", @"sl", @"auto", @"tl", target, @"dt", @"t", @"ie", @"UTF-8", @"oe", @"UTF-8", @"q", text]) dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger status = 0;
    id json = [self jsonFromData:[self performRequest:request statusCode:&status error:error]];
    NSArray *root = [json isKindOfClass:[NSArray class]] ? json : nil;
    if (root.count == 0 || ![root[0] isKindOfClass:[NSArray class]])
    {
        if (error != NULL && *error == nil)
            *error = TGOnegramTranslatorError(status == 429 ? TGLocalized(@"Translator.Error.RateLimit") : nil);
        return nil;
    }
    NSMutableString *result = [[NSMutableString alloc] init];
    for (id segment in (NSArray *)root[0])
    {
        NSArray *parts = [segment isKindOfClass:[NSArray class]] ? segment : nil;
        if (parts.count != 0 && [parts[0] isKindOfClass:[NSString class]])
            [result appendString:parts[0]];
    }
    NSString *source = root.count > 2 && [root[2] isKindOfClass:[NSString class]] ? root[2] : nil;
    return [[TGOnegramTranslation alloc] initWithText:result sourceLanguage:source targetLanguage:target];
}

+ (NSString *)microsoftToken:(NSError **)error
{
    static NSString *cachedToken = nil;
    static CFAbsoluteTime cachedTime = 0.0;
    @synchronized (self)
    {
        if (cachedToken != nil && CFAbsoluteTimeGetCurrent() - cachedTime < 8.0 * 60.0)
            return cachedToken;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://edge.microsoft.com/translate/auth"]];
    NSInteger status = 0;
    NSData *data = [self performRequest:request statusCode:&status error:error];
    NSString *token = data.length != 0 && status == 200 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (token.length == 0)
    {
        if (error != NULL && *error == nil)
            *error = TGOnegramTranslatorError(nil);
        return nil;
    }
    @synchronized (self)
    {
        cachedToken = token;
        cachedTime = CFAbsoluteTimeGetCurrent();
    }
    return token;
}

+ (TGOnegramTranslation *)microsoftTranslate:(NSString *)text target:(NSString *)target error:(NSError **)error
{
    NSString *token = [self microsoftToken:error];
    if (token == nil)
        return nil;
    NSString *url = [[NSString alloc] initWithFormat:@"https://api-edge.cognitive.microsofttranslator.com/translate?api-version=3.0&to=%@", TGOnegramTranslatorQueryEscape(target)];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@[@{@"Text": text}] options:0 error:nil];
    NSInteger status = 0;
    id json = [self jsonFromData:[self performRequest:request statusCode:&status error:error]];
    NSArray *entries = [json isKindOfClass:[NSArray class]] ? json : nil;
    NSDictionary *entry = entries.count != 0 && [entries[0] isKindOfClass:[NSDictionary class]] ? entries[0] : nil;
    NSArray *translations = [entry[@"translations"] isKindOfClass:[NSArray class]] ? entry[@"translations"] : nil;
    NSDictionary *translation = translations.count != 0 && [translations[0] isKindOfClass:[NSDictionary class]] ? translations[0] : nil;
    NSString *result = translation[@"text"];
    if (![result isKindOfClass:[NSString class]])
    {
        if (error != NULL && *error == nil)
            *error = TGOnegramTranslatorError(status == 429 ? TGLocalized(@"Translator.Error.RateLimit") : nil);
        return nil;
    }
    NSDictionary *detected = entry[@"detectedLanguage"];
    NSString *source = [detected isKindOfClass:[NSDictionary class]] && [detected[@"language"] isKindOfClass:[NSString class]] ? detected[@"language"] : nil;
    return [[TGOnegramTranslation alloc] initWithText:result sourceLanguage:source targetLanguage:target];
}

+ (TGOnegramTranslation *)deeplTranslate:(NSString *)text target:(NSString *)target error:(NSError **)error
{
    NSString *key = [TGOnegramSettings secretForKey:TGOnegramSecretTranslatorDeepLKey];
    if (key.length == 0)
    {
        if (error != NULL)
            *error = TGOnegramTranslatorError(TGLocalized(@"Translator.Error.NoKey"));
        return nil;
    }
    NSString *host = [key hasSuffix:@":fx"] ? @"https://api-free.deepl.com/v2/translate" : @"https://api.deepl.com/v2/translate";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:host]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"DeepL-Auth-Key " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [TGOnegramTranslatorFormBody(@[@"text", text, @"target_lang", [target uppercaseString]]) dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger status = 0;
    id json = [self jsonFromData:[self performRequest:request statusCode:&status error:error]];
    NSArray *translations = [json isKindOfClass:[NSDictionary class]] ? json[@"translations"] : nil;
    NSDictionary *translation = [translations isKindOfClass:[NSArray class]] && translations.count != 0 ? translations[0] : nil;
    NSString *result = [translation isKindOfClass:[NSDictionary class]] ? translation[@"text"] : nil;
    if (![result isKindOfClass:[NSString class]])
    {
        if (error != NULL && *error == nil)
            *error = TGOnegramTranslatorError(status == 403 ? TGLocalized(@"Translator.Error.BadKey") : (status == 456 ? TGLocalized(@"Translator.Error.Quota") : nil));
        return nil;
    }
    NSString *source = [translation[@"detected_source_language"] isKindOfClass:[NSString class]] ? translation[@"detected_source_language"] : nil;
    return [[TGOnegramTranslation alloc] initWithText:result sourceLanguage:source targetLanguage:target];
}

+ (TGOnegramTranslation *)llmTranslate:(NSString *)text target:(NSString *)target error:(NSError **)error
{
    NSString *key = [TGOnegramSettings secretForKey:TGOnegramSecretTranslatorLLMKey];
    NSString *endpoint = [TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMEndpoint];
    NSString *model = [TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMModel];
    while ([endpoint hasSuffix:@"/"])
        endpoint = [endpoint substringToIndex:endpoint.length - 1];
    NSURL *url = [NSURL URLWithString:[endpoint stringByAppendingString:@"/chat/completions"]];
    if (url == nil || model.length == 0)
    {
        if (error != NULL)
            *error = TGOnegramTranslatorError(TGLocalized(@"Translator.Error.NoEndpoint"));
        return nil;
    }
    NSString *languageName = [[[NSLocale alloc] initWithLocaleIdentifier:@"en"] displayNameForKey:NSLocaleLanguageCode value:target] ?: target;
    NSString *prompt = [[NSString alloc] initWithFormat:@"Translate the user's message into %@. Reply with the translation only, keep formatting, emoji, names and links unchanged.", languageName];
    NSDictionary *body = @{@"model": model, @"temperature": @0.2, @"messages": @[@{@"role": @"system", @"content": prompt}, @{@"role": @"user", @"content": text}]};
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    if (key.length != 0)
        [request setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSInteger status = 0;
    id json = [self jsonFromData:[self performRequest:request statusCode:&status error:error]];
    NSArray *choices = [json isKindOfClass:[NSDictionary class]] ? json[@"choices"] : nil;
    NSDictionary *choice = [choices isKindOfClass:[NSArray class]] && choices.count != 0 ? choices[0] : nil;
    NSDictionary *message = [choice isKindOfClass:[NSDictionary class]] ? choice[@"message"] : nil;
    NSString *result = [message isKindOfClass:[NSDictionary class]] ? message[@"content"] : nil;
    if (![result isKindOfClass:[NSString class]])
    {
        if (error != NULL && *error == nil)
            *error = TGOnegramTranslatorError(status == 401 ? TGLocalized(@"Translator.Error.BadKey") : nil);
        return nil;
    }
    return [[TGOnegramTranslation alloc] initWithText:[result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] sourceLanguage:[self detectedLanguageForText:text] targetLanguage:target];
}

+ (SSignal *)translateText:(NSString *)text
{
    NSString *source = text.length > TGOnegramTranslatorMaximumLength ? [text substringToIndex:TGOnegramTranslatorMaximumLength] : text;
    NSString *target = [self targetLanguage];
    TGOnegramTranslatorProvider provider = (TGOnegramTranslatorProvider)[TGOnegramSettings integerForKey:TGOnegramSettingTranslatorProvider];
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __block bool cancelled = false;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            NSError *error = nil;
            TGOnegramTranslation *translation = nil;
            switch (provider)
            {
                case TGOnegramTranslatorProviderMicrosoft:
                    translation = [self microsoftTranslate:source target:target error:&error];
                    break;
                case TGOnegramTranslatorProviderDeepL:
                    translation = [self deeplTranslate:source target:target error:&error];
                    break;
                case TGOnegramTranslatorProviderLLM:
                    translation = [self llmTranslate:source target:target error:&error];
                    break;
                default:
                    translation = [self googleTranslate:source target:target error:&error];
                    break;
            }
            TGDispatchOnMainThread(^
            {
                if (cancelled)
                    return;
                if (translation.text.length != 0)
                {
                    [subscriber putNext:translation];
                    [subscriber putCompletion];
                }
                else
                {
                    [subscriber putError:error ?: TGOnegramTranslatorError(nil)];
                }
            });
        });
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            TGDispatchOnMainThread(^
            {
                cancelled = true;
            });
        }];
    }];
}

@end
