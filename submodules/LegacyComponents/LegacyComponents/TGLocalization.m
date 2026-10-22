#import "TGLocalization.h"

#import "TGPluralization.h"

#import <pthread.h>

static pthread_mutex_t fallbackDictsMutex = PTHREAD_MUTEX_INITIALIZER;

static NSArray *startupFallbackKeys() {
    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"Contacts.TabTitle",
            @"DialogList.TabTitle",
            @"Settings.TabTitle",
            @"Calls.TabTitle",
            @"DialogList.Title",
            @"DialogList.SearchLabel",
            @"Common.Back",
            @"Common.Edit",
            @"Common.Done",
            @"Common.OK",
            @"DialogList.PinLimitError"
        ];
    });
    return keys;
}

static bool isStartupFallbackKey(NSString *key) {
    return [startupFallbackKeys() containsObject:key];
}

static NSDictionary *startupFallbackDict(NSString *code) {
    if (code == nil) {
        code = @"en";
    }
    static NSMutableDictionary *dicts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dicts = [[NSMutableDictionary alloc] init];
    });
    pthread_mutex_lock(&fallbackDictsMutex);
    NSDictionary *dict = dicts[code];
    if (dict == nil) {
        NSString *directory = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lproj", code]];
        NSString *path = [directory stringByAppendingPathComponent:@"OnegramStartup.txt"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        if (data.length != 0) {
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
                NSRange separator = [line rangeOfString:@"\t"];
                if (separator.location == NSNotFound) {
                    continue;
                }
                NSString *key = [line substringToIndex:separator.location];
                NSString *value = [line substringFromIndex:separator.location + separator.length];
                if (key.length != 0) {
                    result[key] = value;
                }
            }
        }
        dict = result;
        dicts[code] = dict;
    }
    pthread_mutex_unlock(&fallbackDictsMutex);
    return dict;
}

static NSDictionary *fallbackDict(NSString *code) {
    if (code == nil) {
        code = @"en";
    }
    static NSMutableDictionary *dicts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dicts = [[NSMutableDictionary alloc] init];
    });
    pthread_mutex_lock(&fallbackDictsMutex);
    NSDictionary *dict = dicts[code];
    if (dict == nil) {
        NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:code ofType:@"lproj"]];
        NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"];
        dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict == nil) {
            dict = @{};
        }
        dicts[code] = dict;
    }
    pthread_mutex_unlock(&fallbackDictsMutex);
    return dict;
}

static NSString *fallbackString(NSString *key, NSString *code) {
    NSString *value = nil;
    if (isStartupFallbackKey(key)) {
        value = startupFallbackDict(code)[key];
        if (value == nil) {
            value = startupFallbackDict(@"en")[key];
        }
        if (value != nil) {
            return value;
        }
    }
    value = fallbackDict(code)[key];
    if (value == nil) {
        value = fallbackDict(@"en")[key];
    }
    
    if (value == nil) {
        return key;
    } else {
        return value;
    }
}

static NSString *TGLocalizationBrandTitle(void) {
    static NSString *title = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *appTitle = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
        if (appTitle == nil) {
            appTitle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        }
        if (appTitle != nil && ![appTitle isEqualToString:@"Telegram"]) {
            title = appTitle;
        }
    });
    return title;
}

static NSString *TGLocalizationBrandedValue(NSString *value, NSString *brandTitle) {
    if (brandTitle == nil || ![value isKindOfClass:[NSString class]] || [value rangeOfString:@"Telegram" options:NSLiteralSearch].location == NSNotFound) {
        return value;
    }
    return [value stringByReplacingOccurrencesOfString:@"Telegram" withString:brandTitle options:NSLiteralSearch range:NSMakeRange(0, value.length)];
}

static NSDictionary *TGLocalizationBrandedDictionary(NSDictionary *dict, NSString *brandTitle) {
    if (brandTitle == nil || dict.count == 0) {
        return dict;
    }
    NSMutableDictionary *result = nil;
    for (NSString *key in dict.keyEnumerator) {
        NSString *value = dict[key];
        NSString *branded = TGLocalizationBrandedValue(value, brandTitle);
        if (branded != value) {
            if (result == nil) {
                result = [[NSMutableDictionary alloc] initWithDictionary:dict];
            }
            result[key] = branded;
        }
    }
    return result != nil ? result : dict;
}

@interface TGLocalization () {
    NSDictionary *_dict;
    NSString *_brandTitle;
    NSMutableDictionary *_brandedValues;
    pthread_mutex_t _brandedValuesLock;
}

@end

@implementation TGLocalization

- (instancetype)initWithVersion:(int32_t)version code:(NSString *)code sourceDict:(NSDictionary *)dict brandTitle:(NSString *)brandTitle isActive:(bool)isActive {
    self = [super init];
    if (self != nil) {
        _version = version;
        _code = code;
        _dict = dict ?: @{};
        _brandTitle = brandTitle;
        _isActive = isActive;
        pthread_mutex_init(&_brandedValuesLock, NULL);
        
        NSString *rawCode = code;
        NSRange range = [rawCode rangeOfString:@"_"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringToIndex:range.location];
        }
        range = [rawCode rangeOfString:@"-"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringToIndex:range.location];
        }
        rawCode = [rawCode lowercaseString];
        unsigned int lc = 0;
        const char *s = rawCode.UTF8String;
        for (; s != NULL && *s; s++) { lc = (lc << 8) + *s; }
        _languageCodeHash = lc;
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_brandedValuesLock);
}
    
- (instancetype)initWithVersion:(int32_t)version code:(NSString *)code dict:(NSDictionary *)dict isActive:(bool)isActive {
    return [self initWithVersion:version code:code sourceDict:dict brandTitle:TGLocalizationBrandTitle() isActive:isActive];
}
    
- (instancetype)initWithVersion:(int32_t)version code:(NSString *)code preparedDict:(NSDictionary *)dict isActive:(bool)isActive {
    return [self initWithVersion:version code:code sourceDict:dict brandTitle:nil isActive:isActive];
}

- (NSDictionary *)dictionaryRepresentation {
    return TGLocalizationBrandedDictionary(_dict, _brandTitle) ?: @{};
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithVersion:[aDecoder decodeInt32ForKey:@"version"] code:[aDecoder decodeObjectForKey:@"code"] dict:[aDecoder decodeObjectForKey:@"dict"] isActive:[aDecoder decodeBoolForKey:@"isActive"]];
}
    
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_version forKey:@"version"];
    [aCoder encodeObject:_code forKey:@"code"];
    [aCoder encodeObject:_dict forKey:@"dict"];
    [aCoder encodeBool:_isActive forKey:@"isActive"];
}
    
- (TGLocalization *)mergedWith:(NSDictionary *)other version:(int32_t)version {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[self dictionaryRepresentation]];
    [dict addEntriesFromDictionary:TGLocalizationBrandedDictionary(other, TGLocalizationBrandTitle())];
    
    return [[TGLocalization alloc] initWithVersion:version code:_code preparedDict:dict isActive:_isActive];
}
    
- (TGLocalization *)withUpdatedIsActive:(bool)isActive {
    return [[TGLocalization alloc] initWithVersion:_version code:_code sourceDict:_dict brandTitle:_brandTitle isActive:isActive];
}

- (TGLocalization *)withUpdatedVersion:(int32_t)version {
    return [[TGLocalization alloc] initWithVersion:version code:_code sourceDict:_dict brandTitle:_brandTitle isActive:_isActive];
}

- (NSLocale *)locale
{
    NSString *suffix = @"";
    NSString *identifier = [[NSLocale currentLocale] localeIdentifier];
    NSRange range = [identifier rangeOfString:@"_"];
    if (range.location != NSNotFound)
        suffix = [identifier substringFromIndex:range.location];
    
    identifier = [_code stringByAppendingString:suffix];
    return [[NSLocale alloc] initWithLocaleIdentifier:identifier];
}
    
- (void)preloadFallback {
    fallbackDict(_code);
    if (![_code isEqualToString:@"en"]) {
        fallbackDict(@"en");
    }
}

- (NSString *)get:(NSString *)key {
    if (key == nil) {
        return nil;
    }
    NSString *value = _dict[key];

    if (value != nil && value.length != 0) {
        if (_brandTitle == nil || [value rangeOfString:@"Telegram" options:NSLiteralSearch].location == NSNotFound) {
            return value;
        }
        pthread_mutex_lock(&_brandedValuesLock);
        NSString *branded = _brandedValues[key];
        pthread_mutex_unlock(&_brandedValuesLock);
        if (branded != nil) {
            return branded;
        }
        branded = TGLocalizationBrandedValue(value, _brandTitle);
        pthread_mutex_lock(&_brandedValuesLock);
        if (_brandedValues == nil) {
            _brandedValues = [[NSMutableDictionary alloc] init];
        }
        _brandedValues[key] = branded;
        pthread_mutex_unlock(&_brandedValuesLock);
        return branded;
    } else {
        return fallbackString(key, _code);
    }
}

- (NSString *)getPluralized:(NSString *)key count:(int32_t)count {
    NSString *suffix = nil;
    switch (TGPluralForm(_languageCodeHash, count)) {
        case TGPluralFormZero:
            suffix = @"_0";
            break;
        case TGPluralFormOne:
            suffix = @"_1";
            break;
        case TGPluralFormTwo:
            suffix = @"_2";
            break;
        case TGPluralFormFew:
            suffix = @"_3_10";
            break;
        case TGPluralFormMany:
            suffix = @"_many";
            break;
        case TGPluralFormOther:
            suffix = @"_any";
            break;
    }
    NSString *finalKey = [key stringByAppendingString:suffix];
    if (_dict[finalKey] == nil) {
        finalKey = [key stringByAppendingString:@"_any"];
    }
    
    return [[NSString alloc] initWithFormat:[self get:finalKey], [NSString stringWithFormat:@"%d", count]];
}

- (bool)contains:(NSString *)key {
    return _dict[key] != nil;
}

@end
