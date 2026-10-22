#import <Foundation/Foundation.h>

@interface TGUserDefaults : NSObject

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (void)synchronize;
- (void)suspendForAccountSwitch;
- (void)reloadAfterAccountSwitch;
- (void)resumeAfterAccountSwitch;

+ (instancetype)standard;

@end
