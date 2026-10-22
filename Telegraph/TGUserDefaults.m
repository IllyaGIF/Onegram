#import "TGUserDefaults.h"
#import <libkern/OSAtomic.h>

@interface TGUserDefaults ()
{
    NSString *_path;
    NSDictionary *_dictionary;
    bool _suspended;
    
    OSSpinLock _lock;
}
@end

@implementation TGUserDefaults

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self != nil)
    {
        _path = [[TGUserDefaults documentsPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.defaults", name]];
        [self synchronize];
    }
    return self;
}

+ (NSString *)documentsPath
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 8)
        {
            NSString *groupName = [@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]];
            
            NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupName];
            if (groupURL != nil)
            {
                NSString *documentsPath = [[groupURL path] stringByAppendingPathComponent:@"Documents"];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:documentsPath withIntermediateDirectories:true attributes:nil error:NULL];
                
                path = documentsPath;
            }
            else
                path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
        }
        else
            path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
    });
    
    return path;
}

- (id)objectForKey:(NSString *)key
{
    OSSpinLockLock(&_lock);
    id value = _dictionary[key];
    OSSpinLockUnlock(&_lock);
    return value;
}

- (void)setObject:(id)value forKey:(NSString *)key
{
    if (key.length == 0)
        return;
    
    if (value == nil)
    {
        [self removeObjectForKey:key];
        return;
    }
    
    OSSpinLockLock(&_lock);
    if (_suspended)
    {
        OSSpinLockUnlock(&_lock);
        return;
    }
    NSMutableDictionary *dictionary = [_dictionary mutableCopy];
    dictionary[key] = value;
    _dictionary = dictionary;
    OSSpinLockUnlock(&_lock);
}

- (void)removeObjectForKey:(NSString *)key
{
    if (key.length == 0)
        return;
    
    OSSpinLockLock(&_lock);
    if (_suspended)
    {
        OSSpinLockUnlock(&_lock);
        return;
    }
    NSMutableDictionary *dictionary = [_dictionary mutableCopy];
    [dictionary removeObjectForKey:key];
    _dictionary = dictionary;
    OSSpinLockUnlock(&_lock);
}

- (void)synchronize
{
    OSSpinLockLock(&_lock);
    if (_dictionary == nil)
    {
        NSData *data = [NSData dataWithContentsOfFile:_path];
        if (data.length != 0)
        {
            id object = nil;
            @try {
                object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            } @catch (NSException *e) {
            }
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                _dictionary = (NSDictionary *)object;
            }
            else
            {
                [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
                _dictionary = [[NSDictionary alloc] init];
            }
        }
        else
        {
            _dictionary = [[NSDictionary alloc] init];
        }
    }
    else if (!_suspended)
    {
        [self _writeDictionary];
    }
    OSSpinLockUnlock(&_lock);
}

- (void)_writeDictionary
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_dictionary];
    if (data != nil)
        [data writeToFile:_path atomically:true];
}

- (void)suspendForAccountSwitch
{
    OSSpinLockLock(&_lock);
    if (_dictionary != nil && !_suspended)
        [self _writeDictionary];
    _suspended = true;
    OSSpinLockUnlock(&_lock);
}

- (void)reloadAfterAccountSwitch
{
    OSSpinLockLock(&_lock);
    _dictionary = nil;
    OSSpinLockUnlock(&_lock);
    [self synchronize];
}

- (void)resumeAfterAccountSwitch
{
    OSSpinLockLock(&_lock);
    _suspended = false;
    OSSpinLockUnlock(&_lock);
}

+ (instancetype)standard
{
    static dispatch_once_t onceToken;
    static TGUserDefaults *userDefaults;
    dispatch_once(&onceToken, ^
    {
        userDefaults = [[TGUserDefaults alloc] initWithName:@"standard"];
    });
    return userDefaults;
}

@end
