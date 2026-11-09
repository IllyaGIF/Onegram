#import "TGLegacyDatabase.h"

#import "FMDatabase.h"

#import "PSKeyValueDecoder.h"

#import "TGLegacyUser.h"

#import "TGUserModel.h"
#import "TGPrivateChatModel.h"
#import "TGGroupChatModel.h"
#import "TGChannelChatModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#if defined(_MSC_VER)

#define FORCE_INLINE    __forceinline

#include <stdlib.h>

#define ROTL32(x,y)     _rotl(x,y)
#define ROTL64(x,y)     _rotl64(x,y)

#define BIG_CONSTANT(x) (x)


#else

#define FORCE_INLINE __attribute__((always_inline))

static inline uint32_t rotl32 ( uint32_t x, int8_t r )
{
    return (x << r) | (x >> (32 - r));
}

#define ROTL32(x,y)     rotl32(x,y)
#define ROTL64(x,y)     rotl64(x,y)

#define BIG_CONSTANT(x) (x##LLU)

#endif


static FORCE_INLINE uint32_t getblock ( const uint32_t * p, int i )
{
    return p[i];
}


static FORCE_INLINE uint32_t fmix ( uint32_t h )
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}


static void MurmurHash3_x86_32 ( const void * key, int len,
                                uint32_t seed, void * out )
{
    const uint8_t * data = (const uint8_t*)key;
    const int nblocks = len / 4;
    
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xcc9e2d51;
    const uint32_t c2 = 0x1b873593;
    
    
    const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
    
    for(int i = -nblocks; i; i++)
    {
        uint32_t k1 = getblock(blocks,i);
        
        k1 *= c1;
        k1 = ROTL32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = ROTL32(h1,13);
        h1 = h1*5+0xe6546b64;
    }
    
    
    const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
    
    uint32_t k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
            k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    
    h1 ^= len;
    
    h1 = fmix(h1);
    
   *(uint32_t*)out = h1;
}

int32_t murMurHash32(NSString *string)
{
    const char *utf8 = string.UTF8String;
    
    int32_t result = 0;
    MurmurHash3_x86_32((uint8_t *)utf8, (int)strlen(utf8), -137723950, &result);
    
    return result;
}

@interface TGLegacyDatabase () {
    FMDatabase *_database;
    NSString *_databasePath;
    SQueue *_queue;
}

@end

@implementation TGLegacyDatabase

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self != nil) {
        _databasePath = path;
        
        _queue = [[SQueue alloc] init];
        
        [_queue dispatch:^{
            [self _openDatabase];
        }];
    }
    return self;
}

- (bool)_isCurrentDatabaseEncrypted
{
    return [_databasePath hasSuffix:@".y"];
}

- (bool)_openDatabase {
    NSAssert([_queue isCurrentQueue], @"queue error");
    _database = [FMDatabase databaseWithPath:_databasePath];
    
    if (![_database openWithFlags:SQLITE_OPEN_READONLY]) {
        NSLog(@"***** Error: couldn't open database! *****");
        [_database close];
        _database = nil;
        return false;
    }
    
    [_database setShouldCacheStatements:true];
    [_database setLogsErrors:true];
    
    if ([self _isCurrentDatabaseEncrypted]) {
        [_database close];
        _database = nil;
        return false;
    }
    
    return true;
}

- (SSignal *)contactUsersMatchingQuery:(NSString *)query {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        [_queue dispatch:^{
            NSString *normalizedQuery = [query lowercaseString];
            NSMutableArray *users = [[NSMutableArray alloc] init];
            
            
            FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT uid, first_name, last_name, local_first_name, local_last_name, phone_number, access_hash FROM users_v30 WHERE uid IN (SELECT uid FROM contacts_v30)"]];
            while ([result next]) {
                int64_t uid = [result longLongIntForColumnIndex:0];
                NSString *firstName = [result stringForColumnIndex:1];
                NSString *lastName = [result stringForColumnIndex:2];
                NSString *phonebookFirstName = [result stringForColumnIndex:3];
                NSString *phonebookLastName = [result stringForColumnIndex:4];
                NSString *phoneNumber = [result stringForColumnIndex:5];
                int64_t accessHash = [result longLongIntForColumnIndex:6];
                
                NSString *normalizedFirstName = nil;
                NSString *normalizedLastName = nil;
                
                if (phonebookFirstName.length != 0 || phonebookLastName.length != 0) {
                    normalizedFirstName = phonebookFirstName;
                    normalizedLastName = phonebookLastName;
                } else {
                    normalizedFirstName = firstName;
                    normalizedLastName = lastName;
                }
                
                NSString *normalizedNameA = nil;
                NSString *normalizedNameB = nil;
                
                if (normalizedFirstName.length != 0 && normalizedLastName.length != 0) {
                    normalizedNameA = [[[normalizedFirstName stringByAppendingString:@" "] stringByAppendingString:normalizedLastName] lowercaseString];
                    normalizedNameB = [[[normalizedLastName stringByAppendingString:@" "] stringByAppendingString:normalizedFirstName] lowercaseString];
                } else if (normalizedFirstName.length != 0) {
                    normalizedNameA = normalizedFirstName;
                } else if (normalizedLastName.length != 0) {
                    normalizedNameA = normalizedLastName;
                } else {
                    continue;
                }
                
                if ([normalizedNameA hasPrefix:normalizedQuery] || (normalizedNameB != nil && [normalizedNameB hasPrefix:normalizedQuery])) {
                    [users addObject:[[TGLegacyUser alloc] initWithUserId:uid accessHash:accessHash firstName:normalizedFirstName lastName:normalizedLastName phoneNumber:phoneNumber photoSmall:nil]];
                }
            }
            
            [subscriber putNext:users];
            [subscriber putCompletion];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            
        }];
    }];
}


+ (NSString *)cleanPhone:(NSString *)phone clip:(bool)clip
{
    if (phone.length == 0)
        return @"";
    
    char buf[phone.length];
    int bufPtr = 0;
    
    int length = (int)phone.length;
    for (int i = 0; i < length; i++)
    {
        unichar c = [phone characterAtIndex:i];
        if (c >= '0' && c <= '9')
        {
            buf[bufPtr++] = (char)c;
        }
    }
    
    return [[NSString alloc] initWithBytes:buf length:bufPtr encoding:NSUTF8StringEncoding];
    
}

- (SSignal *)contactUsersMatchingPhone:(NSString *)queryPhoneNumber {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        [_queue dispatch:^{
            [subscriber putNext:[self contactUsersMatchingPhoneSync:queryPhoneNumber]];
            [subscriber putCompletion];
        }];
        return nil;
    }];
}

- (NSArray *)contactUsersMatchingPhoneSync:(NSString *)queryPhoneNumber {
    __block NSArray *resultUsers = nil;
    [_queue dispatchSync:^{
        NSString *normalizedPhone = [TGLegacyDatabase cleanPhone:queryPhoneNumber clip:true];
        NSMutableArray *users = [[NSMutableArray alloc] init];
        
        FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT uid, first_name, last_name, local_first_name, local_last_name, phone_number, access_hash FROM users_v30 WHERE uid IN (SELECT uid FROM contacts_v30)"]];
        while ([result next]) {
            int64_t uid = [result longLongIntForColumnIndex:0];
            NSString *firstName = [result stringForColumnIndex:1];
            NSString *lastName = [result stringForColumnIndex:2];
            NSString *phonebookFirstName = [result stringForColumnIndex:3];
            NSString *phonebookLastName = [result stringForColumnIndex:4];
            NSString *phoneNumber = [result stringForColumnIndex:5];
            int64_t accessHash = [result longLongIntForColumnIndex:6];
            
            NSString *normalizedFirstName = nil;
            NSString *normalizedLastName = nil;
            
            if (phonebookFirstName.length != 0 || phonebookLastName.length != 0) {
                normalizedFirstName = phonebookFirstName;
                normalizedLastName = phonebookLastName;
            } else {
                normalizedFirstName = firstName;
                normalizedLastName = lastName;
            }
            
            if ([[TGLegacyDatabase cleanPhone:phoneNumber clip:true] isEqualToString:normalizedPhone]) {
                [users addObject:[[TGLegacyUser alloc] initWithUserId:uid accessHash:accessHash firstName:normalizedFirstName lastName:normalizedLastName phoneNumber:phoneNumber photoSmall:nil]];
                break;
            }
        }
    
        resultUsers = users;
    }];
    return resultUsers;
}

- (NSArray *)topUsers {
    NSMutableArray *users = [[NSMutableArray alloc] init];
    
    FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT u.uid, u.first_name, u.last_name, u.access_hash, u.photo_small FROM users_v30 u JOIN peer_rating_30 p ON u.uid = p.peer_id WHERE p.category = 1 ORDER BY p.rating DESC LIMIT 9"]];
    while ([result next]) {
        int64_t uid = [result longLongIntForColumnIndex:0];
        NSString *firstName = [result stringForColumnIndex:1];
        NSString *lastName = [result stringForColumnIndex:2];
        int64_t accessHash = [result longLongIntForColumnIndex:3];
        NSString *photoSmall = [result stringForColumnIndex:4];
        
        [users addObject:[[TGLegacyUser alloc] initWithUserId:uid accessHash:accessHash firstName:firstName lastName:lastName phoneNumber:nil photoSmall:photoSmall]];
    }
    
    return users;
}

- (NSDictionary *)unreadCountsForUsers:(NSArray *)users {
    NSMutableDictionary *counts = [[NSMutableDictionary alloc] init];
    
    NSMutableString *rangeString = [[NSMutableString alloc] init];
    bool first = true;
    for (TGLegacyUser *user in users)
    {
        if (first)
            first = false;
        else
            [rangeString appendString:@","];
        
        [rangeString appendFormat:@"%lld", user.userId];
    }
    
    FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT cid, unread_count FROM convesations_v30 WHERE cid IN (%@)", rangeString]];
    
    while ([result next]) {
        int64_t cid = [result longLongIntForColumnIndex:0];
        int32_t unreadCount = [result intForColumnIndex:1];
        
        counts[@(cid)] = @(unreadCount);
    }
    
    return counts;
}

- (TGLegacyUser *)userWithIdSync:(int64_t)userId {
    
    __block TGLegacyUser *resultUser = nil;
    [_queue dispatchSync:^{
        NSString *tableName = @"users_v30";
        
        TGLegacyUser *model = nil;
        FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT uid, first_name, last_name, access_hash, photo_small, phone_number FROM %@ WHERE uid=?", tableName], @(userId)];
        if ([result next])
        {
            int64_t uid = [result longLongIntForColumnIndex:0];
            NSString *firstName = [result stringForColumnIndex:1];
            NSString *lastName = [result stringForColumnIndex:2];
            int64_t accessHash = [result longLongIntForColumnIndex:3];
            NSString *photoSmall = [result stringForColumnIndex:4];
            NSString *phoneNumber = [result stringForColumnIndex:5];
            
            model = [[TGLegacyUser alloc] initWithUserId:uid accessHash:accessHash firstName:firstName lastName:lastName phoneNumber:phoneNumber photoSmall:photoSmall];
        }
        
        resultUser = model;
    }];
    return resultUser;
}

- (TGChatModel *)conversationWithIdSync:(int64_t)conversationId {
    __block TGChatModel *resultConversation = nil;
    [_queue dispatchSync:^{
        NSString *tableName = TGPeerIdIsChannel(conversationId) ? @"channel_conversations_v30" : @"convesations_v30";
        
        TGChatModel *model = nil;
        FMResultSet *result = [_database executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE cid=?", tableName], @(conversationId)];
        if ([result next])
        {
            if (TGPeerIdIsChannel(conversationId)) {
                NSData *data = [result dataForColumn:@"data"];
                PSKeyValueCoder *coder = [[PSKeyValueDecoder alloc] initWithData:data];
                int64_t flags = [coder decodeInt64ForCKey:"flags"];
                bool isGroup = flags & (1 << 7);
                
                model = [[TGChannelChatModel alloc] initWithChannelId:TGChannelIdFromPeerId([coder decodeInt64ForCKey:"i"]) title:[coder decodeStringForCKey:"ct"] avatarLocation:[[TGFileLocation alloc] initWithFileUrl:[coder decodeStringForCKey:"cp.s"]] isGroup:isGroup accessHash:[coder decodeInt64ForCKey:"ah"]];
                
            } else if (TGPeerIdIsGroup(conversationId)) {
                NSData *data = [result dataForColumn:@"chat_photo"];
                NSString *photoSmall;
                NSString *photoMedium;
                NSString *photoBig;
                
                int ptr = 0;
                
                int32_t version = 1;
                if (data.length >= 4) {
                    int32_t magic = 0;
                    [data getBytes:&magic length:4];
                    if (magic == 0x7acde441) {
                        ptr += 4;
                        
                        [data getBytes:&version range:NSMakeRange(ptr, 4)];
                        ptr += 4;
                    }
                }
                
                for (int i = 0; i < 3; i++)
                {
                    int length = 0;
                    [data getBytes:&length range:NSMakeRange(ptr, 4)];
                    ptr += 4;
                    
                    uint8_t *valueBytes = malloc(length);
                    [data getBytes:valueBytes range:NSMakeRange(ptr, length)];
                    ptr += length;
                    NSString *value = [[NSString alloc] initWithBytesNoCopy:valueBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
                    
                    if (i == 0)
                        photoSmall = value;
                    else if (i == 1)
                        photoMedium = value;
                    else if (i == 2)
                        photoBig = value;
                }

                model = [[TGGroupChatModel alloc] initWithGroupId:TGGroupIdFromPeerId(conversationId) title:[result stringForColumn:@"chat_title"] avatarLocation:[[TGFileLocation alloc] initWithFileUrl:photoSmall]];
            } else if (TGPeerIdIsUser(conversationId)) {
                model = [[TGPrivateChatModel alloc] initWithUserId:TGUserIdFromPeerId(conversationId)];
            }
        }

        resultConversation = model;
    }];
    return resultConversation;
}

- (NSData *)customPropertySync:(NSString *)name {
    __block NSData *resultData = nil;
    [_queue dispatchSync:^{
        FMResultSet *result = [_database executeQuery:[[NSString alloc] initWithFormat:@"SELECT value FROM %@ WHERE key=?", @"service_v30"], [[NSNumber alloc] initWithInt:murMurHash32(name)]];
        if ([result next])
        {
            resultData = [result dataForColumn:@"value"];
            result = nil;
        }
    }];
    return resultData;
}

@end
