#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const TGWarpProfileName;
FOUNDATION_EXPORT NSString *const TGWarpProfileConf;
FOUNDATION_EXPORT NSString *const TGWarpProfileGenerated;

@interface TGWarpProfileStore : NSObject

+ (NSArray *)orderedProfiles;
+ (NSArray *)availableProfileNames;

+ (NSString *)generatedProfilesDirectory;

+ (NSString *)writeGeneratedProfile:(NSString *)conf;

+ (BOOL)deleteProfileNamed:(NSString *)name;
+ (BOOL)hasHiddenProfiles;
+ (void)restoreHiddenProfiles;

@end
