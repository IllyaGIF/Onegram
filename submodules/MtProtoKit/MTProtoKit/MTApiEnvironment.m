

#import "MTApiEnvironment.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#else

#endif

#include <sys/sysctl.h>
#include <stdlib.h>
#include <string.h>

#import <CommonCrypto/CommonDigest.h>

#define IFPGA_NAMESTRING                @"iFPGA"

#define IPHONE_1G_NAMESTRING            @"iPhone 1G"
#define IPHONE_3G_NAMESTRING            @"iPhone 3G"
#define IPHONE_3GS_NAMESTRING           @"iPhone 3GS"
#define IPHONE_4_NAMESTRING             @"iPhone 4"
#define IPHONE_4S_NAMESTRING            @"iPhone 4S"
#define IPHONE_5_NAMESTRING             @"iPhone 5"
#define IPHONE_5S_NAMESTRING             @"iPhone 5S"
#define IPHONE_6_NAMESTRING             @"iPhone 6"
#define IPHONE_6Plus_NAMESTRING             @"iPhone 6 Plus"
#define IPHONE_6S_NAMESTRING             @"iPhone 6S"
#define IPHONE_6SPlus_NAMESTRING             @"iPhone 6S Plus"
#define IPHONE_7_NAMESTRING             @"iPhone 7"
#define IPHONE_7Plus_NAMESTRING             @"iPhone 7 Plus"
#define IPHONE_8_NAMESTRING             @"iPhone 8"
#define IPHONE_8Plus_NAMESTRING             @"iPhone 8 Plus"
#define IPHONE_X_NAMESTRING             @"iPhone X"
#define IPHONE_SE_NAMESTRING             @"iPhone SE"
#define IPHONE_UNKNOWN_NAMESTRING       @"Unknown iPhone"

#define IPOD_1G_NAMESTRING              @"iPod touch 1G"
#define IPOD_2G_NAMESTRING              @"iPod touch 2G"
#define IPOD_3G_NAMESTRING              @"iPod touch 3G"
#define IPOD_4G_NAMESTRING              @"iPod touch 4G"
#define IPOD_5G_NAMESTRING              @"iPod touch 5G"
#define IPOD_6G_NAMESTRING              @"iPod touch 6G"
#define IPOD_UNKNOWN_NAMESTRING         @"Unknown iPod"

#define IPAD_1G_NAMESTRING              @"iPad 1G"
#define IPAD_2G_NAMESTRING              @"iPad 2G"
#define IPAD_3G_NAMESTRING              @"iPad 3G"
#define IPAD_4G_NAMESTRING              @"iPad 4G"
#define IPAD_5G_NAMESTRING              @"iPad Air 2"
#define IPAD_6G_NAMESTRING  @"iPad Pro"
#define IPAD_UNKNOWN_NAMESTRING         @"Unknown iPad"

#define APPLETV_2G_NAMESTRING           @"Apple TV 2G"
#define APPLETV_3G_NAMESTRING           @"Apple TV 3G"
#define APPLETV_4G_NAMESTRING           @"Apple TV 4G"
#define APPLETV_UNKNOWN_NAMESTRING      @"Unknown Apple TV"

#define IOS_FAMILY_UNKNOWN_DEVICE       @"Unknown iOS device"

#define SIMULATOR_NAMESTRING            @"iPhone Simulator"
#define SIMULATOR_IPHONE_NAMESTRING     @"iPhone Simulator"
#define SIMULATOR_IPAD_NAMESTRING       @"iPad Simulator"
#define SIMULATOR_APPLETV_NAMESTRING    @"Apple TV Simulator"

typedef enum {
    UIDeviceUnknown,
    
    UIDeviceSimulator,
    UIDeviceSimulatoriPhone,
    UIDeviceSimulatoriPad,
    UIDeviceSimulatorAppleTV,
    
    UIDevice1GiPhone,
    UIDevice3GiPhone,
    UIDevice3GSiPhone,
    UIDevice4iPhone,
    UIDevice4SiPhone,
    UIDevice5iPhone,
    UIDevice5SiPhone,
    UIDevice6iPhone,
    UIDevice6PlusiPhone,
    UIDevice6siPhone,
    UIDevice6SPlusiPhone,
    UIDevice7iPhone,
    UIDevice7PlusiPhone,
    UIDevice8iPhone,
    UIDevice8PlusiPhone,
    UIDeviceXiPhone,
    UIDeviceSEPhone,
    
    UIDevice1GiPod,
    UIDevice2GiPod,
    UIDevice3GiPod,
    UIDevice4GiPod,
    UIDevice5GiPod,
    UIDevice6GiPod,
    
    UIDevice1GiPad,
    UIDevice2GiPad,
    UIDevice3GiPad,
    UIDevice4GiPad,
    UIDevice5GiPad,
    UIDevice6GiPad,
    
    UIDeviceAppleTV2,
    UIDeviceAppleTV3,
    UIDeviceAppleTV4,
    
    UIDeviceUnknowniPhone,
    UIDeviceUnknowniPod,
    UIDeviceUnknowniPad,
    UIDeviceUnknownAppleTV,
    UIDeviceIFPGA,
    
    UIDeviceOSX
    
} UIDevicePlatform;

typedef enum {
    UIDeviceFamilyiPhone,
    UIDeviceFamilyiPod,
    UIDeviceFamilyiPad,
    UIDeviceFamilyAppleTV,
    UIDeviceFamilyUnknown,
    
} UIDeviceFamily;


typedef struct
{
    const char *identifier;
    const char *name;
} MTOnegramDeviceModelEntry;

static NSString *MTOnegramDeviceModel(void)
{
#if TARGET_OS_IPHONE
#if TARGET_IPHONE_SIMULATOR
    return @"iPhone Simulator";
#else
    static const MTOnegramDeviceModelEntry models[] =
    {
        {"iPhone1,1", "iPhone 2G"},
        {"iPhone1,2", "iPhone 3G"},
        {"iPhone2,1", "iPhone 3GS"},
        {"iPhone3,1", "iPhone 4"},
        {"iPhone3,2", "iPhone 4"},
        {"iPhone3,3", "iPhone 4"},
        {"iPhone4,1", "iPhone 4S"},
        {"iPhone5,1", "iPhone 5"},
        {"iPhone5,2", "iPhone 5"},
        {"iPhone5,3", "iPhone 5c"},
        {"iPhone5,4", "iPhone 5c"},
        {"iPhone6,1", "iPhone 5s"},
        {"iPhone6,2", "iPhone 5s"},
        {"iPhone7,1", "iPhone 6 Plus"},
        {"iPhone7,2", "iPhone 6"},
        {"iPhone8,1", "iPhone 6s"},
        {"iPhone8,2", "iPhone 6s Plus"},
        {"iPhone8,4", "iPhone SE"},
        {"iPhone9,1", "iPhone 7"},
        {"iPhone9,3", "iPhone 7"},
        {"iPhone9,2", "iPhone 7 Plus"},
        {"iPhone9,4", "iPhone 7 Plus"},
        {"iPhone10,1", "iPhone 8"},
        {"iPhone10,4", "iPhone 8"},
        {"iPhone10,2", "iPhone 8 Plus"},
        {"iPhone10,5", "iPhone 8 Plus"},
        {"iPhone10,3", "iPhone X"},
        {"iPhone10,6", "iPhone X"},
        {"iPhone11,2", "iPhone XS"},
        {"iPhone11,4", "iPhone XS Max"},
        {"iPhone11,6", "iPhone XS Max"},
        {"iPhone11,8", "iPhone XR"},
        {"iPhone12,1", "iPhone 11"},
        {"iPhone12,3", "iPhone 11 Pro"},
        {"iPhone12,5", "iPhone 11 Pro Max"},
        {"iPhone12,8", "iPhone SE (2nd generation)"},
        {"iPhone13,1", "iPhone 12 mini"},
        {"iPhone13,2", "iPhone 12"},
        {"iPhone13,3", "iPhone 12 Pro"},
        {"iPhone13,4", "iPhone 12 Pro Max"},
        {"iPhone14,2", "iPhone 13 Pro"},
        {"iPhone14,3", "iPhone 13 Pro Max"},
        {"iPhone14,4", "iPhone 13 mini"},
        {"iPhone14,5", "iPhone 13"},
        {"iPhone14,6", "iPhone SE (3rd generation)"},
        {"iPhone14,7", "iPhone 14"},
        {"iPhone14,8", "iPhone 14 Plus"},
        {"iPhone15,2", "iPhone 14 Pro"},
        {"iPhone15,3", "iPhone 14 Pro Max"},
        {"iPhone15,4", "iPhone 15"},
        {"iPhone15,5", "iPhone 15 Plus"},
        {"iPhone16,1", "iPhone 15 Pro"},
        {"iPhone16,2", "iPhone 15 Pro Max"},
        {"iPhone17,1", "iPhone 16 Pro"},
        {"iPhone17,2", "iPhone 16 Pro Max"},
        {"iPhone17,3", "iPhone 16"},
        {"iPhone17,4", "iPhone 16 Plus"},
        {"iPhone17,5", "iPhone 16e"},

        {"iPod1,1", "iPod touch (1st generation)"},
        {"iPod2,1", "iPod touch (2nd generation)"},
        {"iPod3,1", "iPod touch (3rd generation)"},
        {"iPod4,1", "iPod touch (4th generation)"},
        {"iPod5,1", "iPod touch (5th generation)"},
        {"iPod7,1", "iPod touch (6th generation)"},
        {"iPod9,1", "iPod touch (7th generation)"},

        {"iPad1,1", "iPad"},
        {"iPad2,1", "iPad 2"},
        {"iPad2,2", "iPad 2"},
        {"iPad2,3", "iPad 2"},
        {"iPad2,4", "iPad 2"},
        {"iPad2,5", "iPad mini"},
        {"iPad2,6", "iPad mini"},
        {"iPad2,7", "iPad mini"},
        {"iPad3,1", "iPad (3rd generation)"},
        {"iPad3,2", "iPad (3rd generation)"},
        {"iPad3,3", "iPad (3rd generation)"},
        {"iPad3,4", "iPad (4th generation)"},
        {"iPad3,5", "iPad (4th generation)"},
        {"iPad3,6", "iPad (4th generation)"},
        {"iPad4,1", "iPad Air"},
        {"iPad4,2", "iPad Air"},
        {"iPad4,3", "iPad Air"},
        {"iPad4,4", "iPad mini 2"},
        {"iPad4,5", "iPad mini 2"},
        {"iPad4,6", "iPad mini 2"},
        {"iPad4,7", "iPad mini 3"},
        {"iPad4,8", "iPad mini 3"},
        {"iPad4,9", "iPad mini 3"},
        {"iPad5,1", "iPad mini 4"},
        {"iPad5,2", "iPad mini 4"},
        {"iPad5,3", "iPad Air 2"},
        {"iPad5,4", "iPad Air 2"},
        {"iPad6,3", "iPad Pro 9.7-inch"},
        {"iPad6,4", "iPad Pro 9.7-inch"},
        {"iPad6,7", "iPad Pro 12.9-inch"},
        {"iPad6,8", "iPad Pro 12.9-inch"}
    };

    size_t size = 0;

    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0)
        return @"iPhone";

    char *machine = (char *)malloc(size);

    if (machine == NULL)
        return @"iPhone";

    if (sysctlbyname("hw.machine", machine, &size, NULL, 0) != 0)
    {
        free(machine);
        return @"iPhone";
    }

    NSUInteger count = sizeof(models) / sizeof(models[0]);

    for (NSUInteger i = 0; i < count; i++)
    {
        if (strcmp(machine, models[i].identifier) == 0)
        {
            NSString *name = [NSString stringWithUTF8String:models[i].name];
            free(machine);
            return name;
        }
    }

    NSString *identifier = [NSString stringWithUTF8String:machine];
    free(machine);

    if (identifier == nil || [identifier length] == 0)
        return @"iPhone";

    return identifier;
#endif
#else
    return @"Mac";
#endif
}

static NSString *MTOnegramAppVersion(void)
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (version == nil || [version length] == 0)
        version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    if (version == nil || [version length] == 0)
        version = @"1.0";

    return version;
}

@implementation MTSocksProxySettings

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password secret:(NSData *)secret {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _port = port;
        _username = username;
        _password = password;
        _secret = secret;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTSocksProxySettings class]]) {
        return false;
    }
    MTSocksProxySettings *other = object;
    if ((other->_ip != nil) != (_ip != nil) || (_ip != nil && ![_ip isEqual:other->_ip])) {
        return false;
    }
    if (other->_port != _port) {
        return false;
    }
    if ((other->_username != nil) != (_username != nil) || (_username != nil && ![_username isEqual:other->_username])) {
        return false;
    }
    if ((other->_password != nil) != (_password != nil) || (_password != nil && ![_password isEqual:other->_password])) {
        return false;
    }
    if ((other->_secret != nil) != (_secret != nil) || (_secret != nil && ![_secret isEqual:other->_secret])) {
        return false;
    }
    return true;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%d+%@+%@+%@", _ip, (int)_port, _username, _password, _secret];
}

+ (bool)secretSupportsExtendedPadding:(NSData *)data {
    if (data.length == 17) {
        uint8_t first = 0;
        [data getBytes:&first length:1];
        return (first == 0xdd);
    }
    return false;
}

@end

@implementation MTNetworkSettings

- (instancetype)initWithReducedBackupDiscoveryTimeout:(bool)reducedBackupDiscoveryTimeout {
    self = [super init];
    if (self != nil) {
        _reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTNetworkSettings class]]) {
        return false;
    }
    MTNetworkSettings *other = object;
    if (_reducedBackupDiscoveryTimeout != other->_reducedBackupDiscoveryTimeout) {
        return false;
    }
    return true;
}

@end

@implementation MTApiEnvironment

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _deviceModel = MTOnegramDeviceModel();
#if TARGET_OS_IPHONE
        _systemVersion = [[UIDevice currentDevice] systemVersion];
#else
        NSProcessInfo *pInfo = [NSProcessInfo processInfo];
        _systemVersion = [[[pInfo operatingSystemVersionString] componentsSeparatedByString:@" "] objectAtIndex:1];
#endif
        
NSString *suffix = @"";
#if TARGET_OS_OSX
#ifdef BETA
        suffix = @" BETA";
#endif
        
#ifdef APPSTORE
        suffix = @" APPSTORE";
#endif
        
#ifdef STABLE
        suffix = @" STABLE";
#endif
#endif
        NSString *versionString = [[NSString alloc] initWithFormat:@"%@%@", MTOnegramAppVersion(), suffix];
        _appVersion = versionString;
        
        _systemLangCode = [[NSLocale preferredLanguages] objectAtIndex:0];
        
        _langPack = @"ios";
        _langPackCode = @"";
        
        [self _updateApiInitializationHash];
    }
    return self;
}

- (void)_updateApiInitializationHash {
    _apiInitializationHash = [[NSString alloc] initWithFormat:@"apiId=%" PRId32 "&deviceModel=%@&systemVersion=%@&appVersion=%@&langCode=%@&layer=%@&langPack=%@&langPackCode=%@&proxy=%@", _apiId, _deviceModel, _systemVersion, _appVersion, _systemLangCode, _layer, _langPack, _langPackCode, _socksProxySettings];
}

- (void)setLayer:(NSNumber *)layer {
    _layer = layer;
    
    [self _updateApiInitializationHash];
}

- (void)setAppVersion:(NSString *)appVersion {
    _appVersion = appVersion;
    
    [self _updateApiInitializationHash];
}

- (void)setLangPack:(NSString *)langPack {
    _langPack = langPack;
    
    [self _updateApiInitializationHash];
}

- (void)setLangPackCode:(NSString *)langPackCode {
    _langPackCode = langPackCode;
    
    [self _updateApiInitializationHash];
}

- (NSString *)platformString
{
    switch ([self platformType])
    {
        case UIDevice1GiPhone: return IPHONE_1G_NAMESTRING;
        case UIDevice3GiPhone: return IPHONE_3G_NAMESTRING;
        case UIDevice3GSiPhone: return IPHONE_3GS_NAMESTRING;
        case UIDevice4iPhone: return IPHONE_4_NAMESTRING;
        case UIDevice4SiPhone: return IPHONE_4S_NAMESTRING;
        case UIDevice5iPhone: return IPHONE_5_NAMESTRING;
        case UIDevice5SiPhone: return IPHONE_5S_NAMESTRING;
        case UIDevice6iPhone: return IPHONE_6_NAMESTRING;
        case UIDevice6PlusiPhone: return IPHONE_6Plus_NAMESTRING;
        case UIDevice6siPhone: return IPHONE_6S_NAMESTRING;
        case UIDevice6SPlusiPhone: return IPHONE_6SPlus_NAMESTRING;
        case UIDevice7iPhone: return IPHONE_7_NAMESTRING;
        case UIDevice7PlusiPhone: return IPHONE_7Plus_NAMESTRING;
        case UIDevice8iPhone: return IPHONE_8_NAMESTRING;
        case UIDevice8PlusiPhone: return IPHONE_8Plus_NAMESTRING;
        case UIDeviceXiPhone: return IPHONE_X_NAMESTRING;
        case UIDeviceSEPhone: return IPHONE_SE_NAMESTRING;
        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPod: return IPOD_1G_NAMESTRING;
        case UIDevice2GiPod: return IPOD_2G_NAMESTRING;
        case UIDevice3GiPod: return IPOD_3G_NAMESTRING;
        case UIDevice4GiPod: return IPOD_4G_NAMESTRING;
        case UIDevice5GiPod: return IPOD_5G_NAMESTRING;
        case UIDevice6GiPod: return IPOD_6G_NAMESTRING;
        case UIDeviceUnknowniPod: return IPOD_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPad : return IPAD_1G_NAMESTRING;
        case UIDevice2GiPad : return IPAD_2G_NAMESTRING;
        case UIDevice3GiPad : return IPAD_3G_NAMESTRING;
        case UIDevice4GiPad : return IPAD_4G_NAMESTRING;
        case UIDevice5GiPad : return IPAD_5G_NAMESTRING;
        case UIDevice6GiPad : return IPAD_6G_NAMESTRING;
        case UIDeviceUnknowniPad : return IPAD_UNKNOWN_NAMESTRING;
            
        case UIDeviceAppleTV2 : return APPLETV_2G_NAMESTRING;
        case UIDeviceAppleTV3 : return APPLETV_3G_NAMESTRING;
        case UIDeviceAppleTV4 : return APPLETV_4G_NAMESTRING;
        case UIDeviceUnknownAppleTV: return APPLETV_UNKNOWN_NAMESTRING;
            
        case UIDeviceSimulator: return SIMULATOR_NAMESTRING;
        case UIDeviceSimulatoriPhone: return SIMULATOR_IPHONE_NAMESTRING;
        case UIDeviceSimulatoriPad: return SIMULATOR_IPAD_NAMESTRING;
        case UIDeviceSimulatorAppleTV: return SIMULATOR_APPLETV_NAMESTRING;
            
        case UIDeviceIFPGA: return IFPGA_NAMESTRING;
            
        case UIDeviceOSX: return [self macHWName];
        
        default: return IOS_FAMILY_UNKNOWN_DEVICE;
    }
}
    
-(NSString *)macHWName {
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *name = [[NSString alloc] initWithUTF8String:model];
        free(model);
        return name;
    };
    return @"macOS";
}

- (NSUInteger)platformType
{
#if TARGET_OS_IPHONE
    NSString *platform = [self platform];
    
    if ([platform isEqualToString:@"iFPGA"])        return UIDeviceIFPGA;
    
    if ([platform isEqualToString:@"iPhone1,1"])    return UIDevice1GiPhone;
    if ([platform isEqualToString:@"iPhone1,2"])    return UIDevice3GiPhone;
    if ([platform hasPrefix:@"iPhone2"])            return UIDevice3GSiPhone;
    if ([platform hasPrefix:@"iPhone3"])            return UIDevice4iPhone;
    if ([platform hasPrefix:@"iPhone4"])            return UIDevice4SiPhone;
    if ([platform hasPrefix:@"iPhone5"])            return UIDevice5iPhone;
    if ([platform hasPrefix:@"iPhone6"])            return UIDevice5SiPhone;
    
    if ([platform isEqualToString:@"iPhone7,1"])    return UIDevice6PlusiPhone;
    if ([platform isEqualToString:@"iPhone7,2"])    return UIDevice6iPhone;
    if ([platform isEqualToString:@"iPhone8,1"])    return UIDevice6siPhone;
    if ([platform isEqualToString:@"iPhone8,2"])    return UIDevice6SPlusiPhone;
    if ([platform isEqualToString:@"iPhone9,1"])    return UIDevice7iPhone;
    if ([platform isEqualToString:@"iPhone9,3"])    return UIDevice7iPhone;
    if ([platform isEqualToString:@"iPhone9,2"])    return UIDevice7PlusiPhone;
    if ([platform isEqualToString:@"iPhone9,4"])    return UIDevice7PlusiPhone;
    
    if ([platform isEqualToString:@"iPhone10,1"])    return UIDevice8iPhone;
    if ([platform isEqualToString:@"iPhone10,4"])    return UIDevice8iPhone;
    if ([platform isEqualToString:@"iPhone10,2"])    return UIDevice8PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,5"])    return UIDevice8PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,3"])    return UIDeviceXiPhone;
    if ([platform isEqualToString:@"iPhone10,6"])    return UIDeviceXiPhone;
    
    if ([platform isEqualToString:@"iPhone8,4"])    return UIDeviceSEPhone;
    
    if ([platform hasPrefix:@"iPod1"])              return UIDevice1GiPod;
    if ([platform hasPrefix:@"iPod2"])              return UIDevice2GiPod;
    if ([platform hasPrefix:@"iPod3"])              return UIDevice3GiPod;
    if ([platform hasPrefix:@"iPod4"])              return UIDevice4GiPod;
    if ([platform hasPrefix:@"iPod5"])              return UIDevice5GiPod;
    if ([platform hasPrefix:@"iPod7"])              return UIDevice6GiPod;
    
    if ([platform hasPrefix:@"iPad1"])              return UIDevice1GiPad;
    if ([platform hasPrefix:@"iPad2"])              return UIDevice2GiPad;
    if ([platform hasPrefix:@"iPad3"])              return UIDevice3GiPad;
    if ([platform hasPrefix:@"iPad4"])              return UIDevice4GiPad;
    if ([platform hasPrefix:@"iPad5"])              return UIDevice5GiPad;
    if ([platform hasPrefix:@"iPad6"])              return UIDevice6GiPad;
    
    if ([platform hasPrefix:@"AppleTV2"])           return UIDeviceAppleTV2;
    if ([platform hasPrefix:@"AppleTV3"])           return UIDeviceAppleTV3;
    
    if ([platform hasPrefix:@"iPhone"])             return UIDeviceUnknowniPhone;
    if ([platform hasPrefix:@"iPod"])               return UIDeviceUnknowniPod;
    if ([platform hasPrefix:@"iPad"])               return UIDeviceUnknowniPad;
    if ([platform hasPrefix:@"AppleTV"])            return UIDeviceUnknownAppleTV;
    
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"])
    {
        return UIDeviceSimulatoriPhone;
    }
#else
    return UIDeviceOSX;
#endif
    
    return UIDeviceUnknown;
}

- (NSString *)getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

- (NSString *)platform
{
    return [self getSysInfoByName:"hw.machine"];
}

- (MTApiEnvironment *)withUpdatedLangPackCode:(NSString *)langPackCode {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = langPackCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result->_socksProxySettings = self.socksProxySettings;
    result->_onegramWebSocketEnabled = self.onegramWebSocketEnabled;
    result->_preferHttpTransport = self.preferHttpTransport;
    result->_networkSettings = self.networkSettings;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_onegramWebSocketEnabled = self.onegramWebSocketEnabled;
    result->_preferHttpTransport = self.preferHttpTransport;
    result->_networkSettings = self.networkSettings;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedSocksProxySettings:(MTSocksProxySettings *)socksProxySettings {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = socksProxySettings;
    result->_onegramWebSocketEnabled = self.onegramWebSocketEnabled;
    result->_preferHttpTransport = self.preferHttpTransport;
    result->_networkSettings = self.networkSettings;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedOnegramWebSocketEnabled:(bool)onegramWebSocketEnabled {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_onegramWebSocketEnabled = onegramWebSocketEnabled;
    result->_preferHttpTransport = self.preferHttpTransport;
    result->_networkSettings = self.networkSettings;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedNetworkSettings:(MTNetworkSettings *)networkSettings {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_onegramWebSocketEnabled = self.onegramWebSocketEnabled;
    result->_preferHttpTransport = self.preferHttpTransport;
    result->_networkSettings = networkSettings;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedPreferHttpTransport:(bool)preferHttpTransport {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];

    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;

    result.langPack = self.langPack;

    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_onegramWebSocketEnabled = self.onegramWebSocketEnabled;
    result->_preferHttpTransport = preferHttpTransport;
    result->_networkSettings = self.networkSettings;

    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;

    [result _updateApiInitializationHash];

    return result;
}

@end
