#import "TGWarpProfileStore.h"
#import "TGFuckDPILog.h"

NSString *const TGWarpProfileName      = @"name";
NSString *const TGWarpProfileConf      = @"conf";
NSString *const TGWarpProfileGenerated = @"generated";

static NSString *const kHiddenProfilesKey = @"FuckDPIHiddenProfiles_v6";

@interface TGWarpProfileStore ()
+ (NSArray *)hiddenNames;
+ (void)unhideName:(NSString *)name;
@end

@implementation TGWarpProfileStore

+ (NSString *)generatedProfilesDirectory
{
    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *dir = [documents stringByAppendingPathComponent:@"Profiles"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        NSError *error = nil;
        if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error])
            FDPILog(@"profiles: cannot create %@: %@", dir, [error localizedDescription]);
    }
    return dir;
}

+ (NSArray *)hiddenNames
{
    NSArray *hidden = [[NSUserDefaults standardUserDefaults] arrayForKey:kHiddenProfilesKey];
    return hidden ?: [NSArray array];
}

+ (NSArray *)orderedProfiles
{
    NSMutableArray *profiles = [NSMutableArray array];
    NSMutableSet *seenNames = [NSMutableSet set];
    NSSet *hidden = [NSSet setWithArray:[self hiddenNames]];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *generatedDir = [self generatedProfilesDirectory];
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSArray *dirs = @[generatedDir,
                      bundlePath,
                      [bundlePath stringByAppendingPathComponent:@"Profiles"],
                      [[NSBundle mainBundle] resourcePath]];

    for (NSString *dir in dirs) {
        BOOL generated = [dir isEqualToString:generatedDir];
        NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *f in [files sortedArrayUsingSelector:@selector(compare:)]) {
            if (![[f pathExtension] isEqualToString:@"conf"]) continue;
            if ([seenNames containsObject:f]) continue;
            if ([hidden containsObject:f]) continue;
            NSString *full = [dir stringByAppendingPathComponent:f];
            NSString *c = [NSString stringWithContentsOfFile:full encoding:NSUTF8StringEncoding error:nil];
            if (c.length == 0) continue;
            [seenNames addObject:f];
            [profiles addObject:@{TGWarpProfileName: f,
                                  TGWarpProfileConf: c,
                                  TGWarpProfileGenerated: @(generated)}];
        }
    }
    return profiles;
}

+ (NSArray *)availableProfileNames
{
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *p in [self orderedProfiles]) [names addObject:[p objectForKey:TGWarpProfileName]];
    return names;
}

+ (NSString *)writeGeneratedProfile:(NSString *)conf
{
    if (conf.length == 0) return nil;

    NSString *name = [NSString stringWithFormat:@"WARP_GEN%.0f.conf", [[NSDate date] timeIntervalSince1970]];
    NSString *path = [[self generatedProfilesDirectory] stringByAppendingPathComponent:name];

    NSError *error = nil;
    if (![conf writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        FDPILog(@"profiles: writing %@ failed: %@", name, [error localizedDescription]);
        return nil;
    }

    [self unhideName:name];

    FDPILog(@"profiles: generated %@", name);
    return name;
}

+ (BOOL)deleteProfileNamed:(NSString *)name
{
    if (name.length == 0) return NO;

    NSString *path = [[self generatedProfilesDirectory] stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSError *error = nil;
        if (![fm removeItemAtPath:path error:&error]) {
            FDPILog(@"profiles: deleting %@ failed: %@", name, [error localizedDescription]);
            return NO;
        }
        FDPILog(@"profiles: deleted generated %@", name);
        return YES;
    }

    NSMutableArray *hidden = [[self hiddenNames] mutableCopy];
    if (![hidden containsObject:name]) {
        [hidden addObject:name];
        [[NSUserDefaults standardUserDefaults] setObject:hidden forKey:kHiddenProfilesKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    FDPILog(@"profiles: hid bundled %@", name);
    return YES;
}

+ (void)unhideName:(NSString *)name
{
    NSMutableArray *hidden = [[self hiddenNames] mutableCopy];
    if (![hidden containsObject:name]) return;
    [hidden removeObject:name];
    [[NSUserDefaults standardUserDefaults] setObject:hidden forKey:kHiddenProfilesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)hasHiddenProfiles
{
    return [self hiddenNames].count > 0;
}

+ (void)restoreHiddenProfiles
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHiddenProfilesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    FDPILog(@"profiles: restored bundled profiles");
}

@end
