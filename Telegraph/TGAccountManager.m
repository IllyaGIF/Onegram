#import "TGAccountManager.h"

#import "TGAppDelegate.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>

static NSString *const TGAccountRegistryAccountsKey = @"accounts";
static NSString *const TGAccountRegistryActiveKey = @"active";
static NSString *const TGAccountRecordIdKey = @"id";
static NSString *const TGAccountRecordUserIdKey = @"userId";
static NSString *const TGAccountRecordFirstNameKey = @"firstName";
static NSString *const TGAccountRecordLastNameKey = @"lastName";
static NSString *const TGAccountRecordPhoneKey = @"phone";
static NSString *const TGAccountJournalFromKey = @"from";
static NSString *const TGAccountJournalToKey = @"to";
static NSString *const TGAccountJournalPhaseKey = @"phase";
static NSString *const TGAccountJournalPhaseOut = @"out";
static NSString *const TGAccountJournalPhaseIn = @"in";
static NSString *const TGAccountErrorDomain = @"TGAccountManager";

@interface TGAccountRecord ()

- (instancetype)initWithAccountId:(NSString *)accountId userId:(int32_t)userId firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)phoneNumber;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end

@implementation TGAccountRecord

- (instancetype)initWithAccountId:(NSString *)accountId userId:(int32_t)userId firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)phoneNumber
{
    self = [super init];
    if (self != nil)
    {
        _accountId = [accountId copy];
        _userId = userId;
        _firstName = [firstName copy];
        _lastName = [lastName copy];
        _phoneNumber = [phoneNumber copy];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    NSString *accountId = dictionary[TGAccountRecordIdKey];
    if (![accountId isKindOfClass:[NSString class]] || accountId.length == 0)
        return nil;

    NSNumber *userId = dictionary[TGAccountRecordUserIdKey];
    NSString *firstName = dictionary[TGAccountRecordFirstNameKey];
    NSString *lastName = dictionary[TGAccountRecordLastNameKey];
    NSString *phoneNumber = dictionary[TGAccountRecordPhoneKey];
    return [self initWithAccountId:accountId userId:[userId isKindOfClass:[NSNumber class]] ? [userId intValue] : 0 firstName:[firstName isKindOfClass:[NSString class]] ? firstName : nil lastName:[lastName isKindOfClass:[NSString class]] ? lastName : nil phoneNumber:[phoneNumber isKindOfClass:[NSString class]] ? phoneNumber : nil];
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    dictionary[TGAccountRecordIdKey] = _accountId;
    dictionary[TGAccountRecordUserIdKey] = @(_userId);
    if (_firstName.length != 0)
        dictionary[TGAccountRecordFirstNameKey] = _firstName;
    if (_lastName.length != 0)
        dictionary[TGAccountRecordLastNameKey] = _lastName;
    if (_phoneNumber.length != 0)
        dictionary[TGAccountRecordPhoneKey] = _phoneNumber;
    return dictionary;
}

- (NSString *)displayName
{
    if (_firstName.length != 0 && _lastName.length != 0)
        return [[NSString alloc] initWithFormat:@"%@ %@", _firstName, _lastName];
    if (_firstName.length != 0)
        return _firstName;
    if (_lastName.length != 0)
        return _lastName;
    return _phoneNumber ?: @"";
}

@end

@interface TGAccountManager ()
{
    NSRecursiveLock *_lock;
    NSMutableArray *_accounts;
    NSString *_activeAccountId;
}

@end

@implementation TGAccountManager

+ (NSString *)documentsPath
{
    return [TGAppDelegate documentsPath];
}

+ (NSString *)rootPath
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        path = [[[[self documentsPath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"OnegramAccounts"];
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:NULL];
    });
    return path;
}

+ (NSString *)registryPath
{
    return [[self rootPath] stringByAppendingPathComponent:@"accounts.plist"];
}

+ (NSString *)journalPath
{
    return [[self rootPath] stringByAppendingPathComponent:@"switch.plist"];
}

+ (NSString *)slotPathForAccountId:(NSString *)accountId
{
    return [[[self rootPath] stringByAppendingPathComponent:@"Slots"] stringByAppendingPathComponent:accountId];
}

+ (NSString *)trashPath
{
    return [[self rootPath] stringByAppendingPathComponent:@"Trash"];
}

+ (void)emptyTrash
{
    NSString *trashPath = [self trashPath];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:trashPath error:NULL])
            [[NSFileManager defaultManager] removeItemAtPath:[trashPath stringByAppendingPathComponent:name] error:NULL];
    });
}

+ (NSString *)avatarsPath
{
    return [[self rootPath] stringByAppendingPathComponent:@"Avatars"];
}

+ (NSSet *)globalDocumentEntries
{
    static NSSet *entries = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        entries = [[NSSet alloc] initWithArray:@[
            @"application-0.log",
            @"OnegramLogs",
            @"ios6_last_crash.txt",
            @"ios6_last_system_crash.txt",
            @"ios6_diagnostic_breadcrumbs.log",
            @"localization",
            @"localizations.data",
            @"CustomLocalization.bundle",
            @"presentation.dat",
            @"autonight.dat",
            @"proxies.data",
            @"network-usage",
            @"wifi-usage-reset",
            @"cellular-usage-reset",
            @"mtkeychain-aes",
            @"tempcache_v1",
            @"Inbox"
        ]];
    });
    return entries;
}

+ (NSArray *)accountScopedStandardDefaultsKeys
{
    return @[
        @"recentBots_v0",
        @"recentGifs_v0",
        @"recentStickers_v0",
        @"TG_stickerPacks",
        @"webSearchRecentQueries",
        @"webSearchRecentSelectedItems_v1",
        @"autocompletion.recentHashtags.entered",
        @"autocompletion.recentHashtags.searchedBy",
        @"TGIOS6SelectedDialogFilterId",
        @"Telegram_recentSearch_peers"
    ];
}

+ (NSArray *)accountScopedContainerDefaultsKeys
{
    return @[@"Telegram_recentSearch_peers"];
}

+ (NSUserDefaults *)containerDefaults
{
    if (iosMajorVersion() < 8)
        return nil;
    return [[NSUserDefaults alloc] initWithSuiteName:[@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]]];
}

+ (NSString *)accountDefaultsPath
{
    return [[self documentsPath] stringByAppendingPathComponent:@"account-defaults.plist"];
}

+ (NSDictionary *)takeValuesForKeys:(NSArray *)keys fromDefaults:(NSUserDefaults *)defaults
{
    NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
    if (defaults == nil)
        return values;
    for (NSString *key in keys)
    {
        id value = [defaults objectForKey:key];
        if (value != nil)
            values[key] = value;
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
    return values;
}

+ (void)putValues:(NSDictionary *)values forKeys:(NSArray *)keys intoDefaults:(NSUserDefaults *)defaults
{
    if (defaults == nil)
        return;
    for (NSString *key in keys)
    {
        id value = [values isKindOfClass:[NSDictionary class]] ? values[key] : nil;
        if (value != nil)
            [defaults setObject:value forKey:key];
        else
            [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
}

+ (bool)stashAccountUserDefaults
{
    NSMutableDictionary *record = [[NSMutableDictionary alloc] init];
    record[@"standard"] = [self takeValuesForKeys:[self accountScopedStandardDefaultsKeys] fromDefaults:[NSUserDefaults standardUserDefaults]];
    record[@"container"] = [self takeValuesForKeys:[self accountScopedContainerDefaultsKeys] fromDefaults:[self containerDefaults]];
    if ([self writePropertyList:record toPath:[self accountDefaultsPath]])
        return true;
    [self putValues:record[@"standard"] forKeys:[self accountScopedStandardDefaultsKeys] intoDefaults:[NSUserDefaults standardUserDefaults]];
    [self putValues:record[@"container"] forKeys:[self accountScopedContainerDefaultsKeys] intoDefaults:[self containerDefaults]];
    return false;
}

+ (void)restoreAccountUserDefaults
{
    NSString *path = [self accountDefaultsPath];
    NSDictionary *record = [self readPropertyListAtPath:path];
    [self putValues:record[@"standard"] forKeys:[self accountScopedStandardDefaultsKeys] intoDefaults:[NSUserDefaults standardUserDefaults]];
    [self putValues:record[@"container"] forKeys:[self accountScopedContainerDefaultsKeys] intoDefaults:[self containerDefaults]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

+ (bool)isAccountScopedDocumentEntry:(NSString *)name
{
    if (name.length == 0 || [name hasPrefix:@"."])
        return false;
    return ![[self globalDocumentEntries] containsObject:name];
}

+ (NSString *)generateAccountId
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *value = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return value;
}

+ (NSDictionary *)readPropertyListAtPath:(NSString *)path
{
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    if (data.length == 0)
        return nil;
    NSString *errorDescription = nil;
    id value = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorDescription];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

+ (bool)writePropertyList:(NSDictionary *)dictionary toPath:(NSString *)path
{
    NSString *errorDescription = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 errorDescription:&errorDescription];
    if (data == nil)
    {
        TGLog(@"ACCOUNTS plist.encode path=%@ error=%@", path.lastPathComponent, errorDescription);
        return false;
    }
    bool written = [data writeToFile:path atomically:true];
    if (!written)
        TGLog(@"ACCOUNTS plist.write path=%@ failed", path.lastPathComponent);
    return written;
}

+ (bool)moveEntry:(NSString *)name fromDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)targetDirectory
{
    NSString *sourcePath = [sourceDirectory stringByAppendingPathComponent:name];
    NSString *targetPath = [targetDirectory stringByAppendingPathComponent:name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
    {
        NSString *conflictName = [[NSString alloc] initWithFormat:@"%@.conflict-%lld", name, (long long)(CFAbsoluteTimeGetCurrent() * 1000.0)];
        TGLog(@"ACCOUNTS slot.conflict entry=%@ keep=%@", name, conflictName);
        targetPath = [targetDirectory stringByAppendingPathComponent:conflictName];
    }
    if (rename([sourcePath fileSystemRepresentation], [targetPath fileSystemRepresentation]) != 0)
    {
        TGLog(@"ACCOUNTS slot.rename entry=%@ errno=%d", name, errno);
        return false;
    }
    return true;
}

+ (void)discardStrayAccountEntriesInDirectory:(NSString *)directory
{
    NSString *trashPath = [self trashPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:trashPath withIntermediateDirectories:true attributes:nil error:NULL];
    bool discarded = false;
    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL])
    {
        if (![self isAccountScopedDocumentEntry:name])
            continue;
        NSString *sourcePath = [directory stringByAppendingPathComponent:name];
        NSString *trashedPath = [trashPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%@-%@", [self generateAccountId], name]];
        if (rename([sourcePath fileSystemRepresentation], [trashedPath fileSystemRepresentation]) != 0)
            [[NSFileManager defaultManager] removeItemAtPath:sourcePath error:NULL];
        TGLog(@"ACCOUNTS slot.stray entry=%@", name);
        discarded = true;
    }
    if (discarded)
        [self emptyTrash];
}

+ (bool)moveAllEntriesFromDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)targetDirectory
{
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sourceDirectory error:NULL];
    bool success = true;
    for (NSString *name in names)
    {
        if (![self moveEntry:name fromDirectory:sourceDirectory toDirectory:targetDirectory])
            success = false;
    }
    return success;
}

+ (void)removeDirectoryIfEmpty:(NSString *)path
{
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    if (names != nil && names.count == 0)
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

+ (void)performLaunchRecovery
{
    NSDictionary *journal = [self readPropertyListAtPath:[self journalPath]];
    if (journal == nil)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self accountDefaultsPath]])
            [self restoreAccountUserDefaults];
        return;
    }

    NSString *fromId = journal[TGAccountJournalFromKey];
    NSString *toId = journal[TGAccountJournalToKey];
    NSString *phase = journal[TGAccountJournalPhaseKey];
    if (![fromId isKindOfClass:[NSString class]] || ![toId isKindOfClass:[NSString class]] || ![phase isKindOfClass:[NSString class]])
    {
        TGLog(@"ACCOUNTS recovery.invalidJournal");
        [[NSFileManager defaultManager] removeItemAtPath:[self journalPath] error:NULL];
        return;
    }

    NSString *documentsPath = [self documentsPath];
    NSMutableDictionary *registry = [[NSMutableDictionary alloc] initWithDictionary:[self readPropertyListAtPath:[self registryPath]] ?: @{}];

    if ([phase isEqualToString:TGAccountJournalPhaseIn])
    {
        NSString *targetSlot = [self slotPathForAccountId:toId];
        [self moveAllEntriesFromDirectory:targetSlot toDirectory:documentsPath];
        [self removeDirectoryIfEmpty:targetSlot];
        registry[TGAccountRegistryActiveKey] = toId;
        TGLog(@"ACCOUNTS recovery.forward from=%@ to=%@", fromId, toId);
    }
    else
    {
        NSString *sourceSlot = [self slotPathForAccountId:fromId];
        [self moveAllEntriesFromDirectory:sourceSlot toDirectory:documentsPath];
        [self removeDirectoryIfEmpty:sourceSlot];
        registry[TGAccountRegistryActiveKey] = fromId;
        TGLog(@"ACCOUNTS recovery.rollback from=%@ to=%@", fromId, toId);
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:[self accountDefaultsPath]])
        [self restoreAccountUserDefaults];

    if ([self writePropertyList:registry toPath:[self registryPath]])
        [[NSFileManager defaultManager] removeItemAtPath:[self journalPath] error:NULL];
}

+ (TGAccountManager *)instance
{
    static TGAccountManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[TGAccountManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _lock = [[NSRecursiveLock alloc] init];
        _accounts = [[NSMutableArray alloc] init];
        [self loadRegistry];
    }
    return self;
}

- (void)loadRegistry
{
    NSDictionary *registry = [TGAccountManager readPropertyListAtPath:[TGAccountManager registryPath]];
    NSArray *records = registry[TGAccountRegistryAccountsKey];
    if ([records isKindOfClass:[NSArray class]])
    {
        for (NSDictionary *dictionary in records)
        {
            if (![dictionary isKindOfClass:[NSDictionary class]])
                continue;
            TGAccountRecord *record = [[TGAccountRecord alloc] initWithDictionary:dictionary];
            if (record != nil && [self recordWithId:record.accountId] == nil)
                [_accounts addObject:record];
        }
    }

    NSString *activeId = registry[TGAccountRegistryActiveKey];
    if ([activeId isKindOfClass:[NSString class]] && [self recordWithId:activeId] != nil)
        _activeAccountId = activeId;

    bool changed = false;
    if (_activeAccountId == nil)
    {
        TGAccountRecord *record = [[TGAccountRecord alloc] initWithAccountId:[TGAccountManager generateAccountId] userId:0 firstName:nil lastName:nil phoneNumber:nil];
        [_accounts insertObject:record atIndex:0];
        _activeAccountId = record.accountId;
        changed = true;
    }

    for (TGAccountRecord *record in [_accounts copy])
    {
        if (record.userId == 0 && ![record.accountId isEqualToString:_activeAccountId])
        {
            [self deleteStorageForAccountId:record.accountId];
            [_accounts removeObject:record];
            changed = true;
        }
    }

    if (changed)
        [self saveRegistry];

    [TGAccountManager emptyTrash];

    TGLog(@"ACCOUNTS registry.load count=%d active=%@", (int)_accounts.count, _activeAccountId);
}

- (bool)saveRegistry
{
    NSMutableArray *records = [[NSMutableArray alloc] init];
    for (TGAccountRecord *record in _accounts)
        [records addObject:[record dictionaryRepresentation]];
    NSMutableDictionary *registry = [[NSMutableDictionary alloc] init];
    registry[TGAccountRegistryAccountsKey] = records;
    if (_activeAccountId != nil)
        registry[TGAccountRegistryActiveKey] = _activeAccountId;
    return [TGAccountManager writePropertyList:registry toPath:[TGAccountManager registryPath]];
}

- (TGAccountRecord *)recordWithId:(NSString *)accountId
{
    if (accountId == nil)
        return nil;
    for (TGAccountRecord *record in _accounts)
    {
        if ([record.accountId isEqualToString:accountId])
            return record;
    }
    return nil;
}

- (void)deleteStorageForAccountId:(NSString *)accountId
{
    NSString *slotPath = [TGAccountManager slotPathForAccountId:accountId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:slotPath])
    {
        NSString *trashPath = [TGAccountManager trashPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:trashPath withIntermediateDirectories:true attributes:nil error:NULL];
        NSString *trashedPath = [trashPath stringByAppendingPathComponent:[TGAccountManager generateAccountId]];
        if (rename([slotPath fileSystemRepresentation], [trashedPath fileSystemRepresentation]) != 0)
            [[NSFileManager defaultManager] removeItemAtPath:slotPath error:NULL];
        [TGAccountManager emptyTrash];
    }
    [[NSFileManager defaultManager] removeItemAtPath:[[TGAccountManager avatarsPath] stringByAppendingPathComponent:[accountId stringByAppendingPathExtension:@"jpg"]] error:NULL];
}

- (NSArray *)accounts
{
    [_lock lock];
    NSArray *accounts = [_accounts copy];
    [_lock unlock];
    return accounts;
}

- (NSArray *)authorizedAccounts
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (TGAccountRecord *record in [self accounts])
    {
        if (record.userId != 0)
            [result addObject:record];
    }
    return result;
}

- (TGAccountRecord *)activeAccount
{
    [_lock lock];
    TGAccountRecord *record = [self recordWithId:_activeAccountId];
    [_lock unlock];
    return record;
}

- (TGAccountRecord *)accountWithId:(NSString *)accountId
{
    [_lock lock];
    TGAccountRecord *record = [self recordWithId:accountId];
    [_lock unlock];
    return record;
}

- (TGAccountRecord *)accountWithUserId:(int32_t)userId
{
    if (userId == 0)
        return nil;
    TGAccountRecord *result = nil;
    [_lock lock];
    for (TGAccountRecord *record in _accounts)
    {
        if (record.userId == userId)
        {
            result = record;
            break;
        }
    }
    [_lock unlock];
    return result;
}

- (bool)updateActiveAccountWithUserId:(int32_t)userId firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)phoneNumber
{
    bool changed = false;
    [_lock lock];
    TGAccountRecord *current = [self recordWithId:_activeAccountId];
    if (current != nil && (current.userId != userId || !TGStringCompare(current.firstName, firstName) || !TGStringCompare(current.lastName, lastName) || !TGStringCompare(current.phoneNumber, phoneNumber)))
    {
        TGAccountRecord *updated = [[TGAccountRecord alloc] initWithAccountId:current.accountId userId:userId firstName:firstName lastName:lastName phoneNumber:phoneNumber];
        [_accounts replaceObjectAtIndex:[_accounts indexOfObject:current] withObject:updated];
        [self saveRegistry];
        changed = true;
    }
    [_lock unlock];
    return changed;
}

- (NSString *)avatarPathForAccount:(TGAccountRecord *)account
{
    if (account.accountId == nil)
        return nil;
    NSString *directory = [TGAccountManager avatarsPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:NULL];
    return [directory stringByAppendingPathComponent:[account.accountId stringByAppendingPathExtension:@"jpg"]];
}

- (TGAccountRecord *)createAccount
{
    TGAccountRecord *record = [[TGAccountRecord alloc] initWithAccountId:[TGAccountManager generateAccountId] userId:0 firstName:nil lastName:nil phoneNumber:nil];
    [_lock lock];
    [[NSFileManager defaultManager] createDirectoryAtPath:[TGAccountManager slotPathForAccountId:record.accountId] withIntermediateDirectories:true attributes:nil error:NULL];
    [_accounts addObject:record];
    [self saveRegistry];
    [_lock unlock];
    return record;
}

- (bool)writeJournalFrom:(NSString *)fromId to:(NSString *)toId phase:(NSString *)phase
{
    return [TGAccountManager writePropertyList:@{TGAccountJournalFromKey: fromId, TGAccountJournalToKey: toId, TGAccountJournalPhaseKey: phase} toPath:[TGAccountManager journalPath]];
}

- (bool)transferActiveSlotToAccount:(TGAccountRecord *)account error:(NSError **)error
{
    [_lock lock];
    NSString *fromId = _activeAccountId;
    NSString *toId = account.accountId;
    if (toId == nil || [self recordWithId:toId] == nil || fromId == nil)
    {
        [_lock unlock];
        if (error != NULL)
            *error = [NSError errorWithDomain:TGAccountErrorDomain code:1 userInfo:nil];
        return false;
    }
    if ([fromId isEqualToString:toId])
    {
        [_lock unlock];
        return true;
    }

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    NSString *documentsPath = [TGAccountManager documentsPath];
    NSString *sourceSlot = [TGAccountManager slotPathForAccountId:fromId];
    NSString *targetSlot = [TGAccountManager slotPathForAccountId:toId];

    if (![self writeJournalFrom:fromId to:toId phase:TGAccountJournalPhaseOut])
    {
        [_lock unlock];
        if (error != NULL)
            *error = [NSError errorWithDomain:TGAccountErrorDomain code:2 userInfo:nil];
        return false;
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:sourceSlot withIntermediateDirectories:true attributes:nil error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:targetSlot withIntermediateDirectories:true attributes:nil error:NULL];

    bool movedOut = [TGAccountManager stashAccountUserDefaults];
    for (NSString *name in movedOut ? [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsPath error:NULL] : nil)
    {
        if (![TGAccountManager isAccountScopedDocumentEntry:name])
            continue;
        if (![TGAccountManager moveEntry:name fromDirectory:documentsPath toDirectory:sourceSlot])
        {
            movedOut = false;
            break;
        }
    }

    if (!movedOut || ![self writeJournalFrom:fromId to:toId phase:TGAccountJournalPhaseIn])
    {
        [TGAccountManager moveAllEntriesFromDirectory:sourceSlot toDirectory:documentsPath];
        [TGAccountManager removeDirectoryIfEmpty:sourceSlot];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[TGAccountManager accountDefaultsPath]])
            [TGAccountManager restoreAccountUserDefaults];
        [[NSFileManager defaultManager] removeItemAtPath:[TGAccountManager journalPath] error:NULL];
        [_lock unlock];
        TGLog(@"ACCOUNTS slot.transfer.rollback from=%@ to=%@", fromId, toId);
        if (error != NULL)
            *error = [NSError errorWithDomain:TGAccountErrorDomain code:3 userInfo:nil];
        return false;
    }

    [TGAccountManager discardStrayAccountEntriesInDirectory:documentsPath];
    [TGAccountManager moveAllEntriesFromDirectory:targetSlot toDirectory:documentsPath];
    [TGAccountManager removeDirectoryIfEmpty:targetSlot];
    [TGAccountManager restoreAccountUserDefaults];

    _activeAccountId = toId;
    if ([self saveRegistry])
        [[NSFileManager defaultManager] removeItemAtPath:[TGAccountManager journalPath] error:NULL];
    [_lock unlock];

    TGLog(@"ACCOUNTS slot.transfer from=%@ to=%@ time=%.3f", fromId, toId, CFAbsoluteTimeGetCurrent() - startTime);
    return true;
}

- (void)removeInactiveAccount:(TGAccountRecord *)account
{
    [_lock lock];
    TGAccountRecord *record = [self recordWithId:account.accountId];
    if (record != nil && ![record.accountId isEqualToString:_activeAccountId])
    {
        [_accounts removeObject:record];
        [self saveRegistry];
        [self deleteStorageForAccountId:record.accountId];
        TGLog(@"ACCOUNTS remove id=%@ userId=%d", record.accountId, record.userId);
    }
    [_lock unlock];
}

@end
