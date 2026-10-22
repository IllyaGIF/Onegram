#import "OGMemoryCache.h"
#import "OGStructuralKey.h"
#import <UIKit/UIKit.h>

@interface OGMemoryCacheEntry : NSObject

@property (nonatomic, copy) id<NSCopying> key;
@property (nonatomic, strong) id object;
@property (nonatomic) NSUInteger cost;
@property (nonatomic, unsafe_unretained) OGMemoryCacheEntry *previous;
@property (nonatomic, unsafe_unretained) OGMemoryCacheEntry *next;

@end

@implementation OGMemoryCacheEntry
@end

@interface OGMemoryCache ()
{
    NSRecursiveLock *_lock;
    NSMutableDictionary *_entries;
    OGMemoryCacheEntry *_first;
    OGMemoryCacheEntry *_last;
    NSUInteger _countLimit;
    NSUInteger _costLimit;
    uint64_t _totalCost;
    uint64_t _evictionGeneration;
}
@end

@implementation OGMemoryCache

- (instancetype)init
{
    return [self initWithCountLimit:0 costLimit:0];
}

- (instancetype)initWithCountLimit:(NSUInteger)countLimit costLimit:(NSUInteger)costLimit
{
    self = [super init];
    if (self != nil)
    {
        _lock = [[NSRecursiveLock alloc] init];
        _entries = OGStructuralKeyDictionaryCreate();
        _countLimit = countLimit;
        _costLimit = costLimit;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)memoryWarning:(NSNotification *)notification
{
    [self removeAllObjects];
}

- (void)unlinkEntry:(OGMemoryCacheEntry *)entry
{
    OGMemoryCacheEntry *previous = entry.previous;
    OGMemoryCacheEntry *next = entry.next;
    if (previous != nil)
        previous.next = next;
    else
        _first = next;
    if (next != nil)
        next.previous = previous;
    else
        _last = previous;
    entry.previous = nil;
    entry.next = nil;
}

- (void)appendEntry:(OGMemoryCacheEntry *)entry
{
    entry.previous = _last;
    entry.next = nil;
    if (_last != nil)
        _last.next = entry;
    else
        _first = entry;
    _last = entry;
}

- (void)removeEntry:(OGMemoryCacheEntry *)entry
{
    if (entry == nil)
        return;
    [self unlinkEntry:entry];
    _totalCost -= entry.cost;
    _evictionGeneration++;
    [_entries removeObjectForKey:entry.key];
}

- (void)trimLockedToCost:(uint64_t)cost count:(NSUInteger)count
{
    while (_first != nil && (_totalCost > cost || _entries.count > count))
        [self removeEntry:_first];
}

- (NSUInteger)countLimit
{
    [_lock lock];
    NSUInteger value = _countLimit;
    [_lock unlock];
    return value;
}

- (void)setCountLimit:(NSUInteger)countLimit
{
    [_lock lock];
    _countLimit = countLimit;
    [self trimLockedToCost:_costLimit == 0 ? UINT64_MAX : _costLimit count:_countLimit == 0 ? NSUIntegerMax : _countLimit];
    [_lock unlock];
}

- (NSUInteger)costLimit
{
    [_lock lock];
    NSUInteger value = _costLimit;
    [_lock unlock];
    return value;
}

- (void)setCostLimit:(NSUInteger)costLimit
{
    [_lock lock];
    _costLimit = costLimit;
    [self trimLockedToCost:_costLimit == 0 ? UINT64_MAX : _costLimit count:_countLimit == 0 ? NSUIntegerMax : _countLimit];
    [_lock unlock];
}

- (NSUInteger)count
{
    [_lock lock];
    NSUInteger value = _entries.count;
    [_lock unlock];
    return value;
}

- (uint64_t)totalCost
{
    [_lock lock];
    uint64_t value = _totalCost;
    [_lock unlock];
    return value;
}

- (uint64_t)evictionGeneration
{
    [_lock lock];
    uint64_t value = _evictionGeneration;
    [_lock unlock];
    return value;
}

- (id)objectForKey:(id<NSCopying>)key
{
    if (key == nil)
        return nil;
    [_lock lock];
    OGMemoryCacheEntry *entry = [_entries objectForKey:key];
    id object = entry.object;
    if (entry != nil && entry != _last)
    {
        [self unlinkEntry:entry];
        [self appendEntry:entry];
    }
    [_lock unlock];
    return object;
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key cost:(NSUInteger)cost
{
    if (key == nil)
        return;
    [_lock lock];
    OGMemoryCacheEntry *entry = [_entries objectForKey:key];
    if (object == nil || (_costLimit != 0 && cost > _costLimit))
    {
        [self removeEntry:entry];
        [_lock unlock];
        return;
    }
    if (entry != nil)
    {
        [self unlinkEntry:entry];
        _totalCost -= entry.cost;
    }
    else
    {
        entry = [[OGMemoryCacheEntry alloc] init];
        entry.key = key;
        [_entries setObject:entry forKey:entry.key];
    }
    entry.object = object;
    entry.cost = cost;
    _totalCost += cost;
    [self appendEntry:entry];
    [self trimLockedToCost:_costLimit == 0 ? UINT64_MAX : _costLimit count:_countLimit == 0 ? NSUIntegerMax : _countLimit];
    [_lock unlock];
}

- (void)removeObjectForKey:(id<NSCopying>)key
{
    if (key == nil)
        return;
    [_lock lock];
    [self removeEntry:[_entries objectForKey:key]];
    [_lock unlock];
}

- (void)removeObjectsForKeys:(NSArray *)keys
{
    [_lock lock];
    for (id<NSCopying> key in keys)
        [self removeEntry:[_entries objectForKey:key]];
    [_lock unlock];
}

- (void)removeObjectsMatchingKeyPredicate:(BOOL (^)(id key))predicate
{
    if (predicate == nil)
        return;
    [_lock lock];
    for (id key in [_entries allKeys])
    {
        if (predicate(key))
            [self removeEntry:[_entries objectForKey:key]];
    }
    [_lock unlock];
}

- (void)moveObjectForKey:(id<NSCopying>)key toKey:(id<NSCopying>)newKey
{
    if (key == nil || newKey == nil)
        return;
    [_lock lock];
    OGMemoryCacheEntry *entry = [_entries objectForKey:key];
    OGMemoryCacheEntry *replacement = [_entries objectForKey:newKey];
    if (entry != nil && entry != replacement)
    {
        [self removeEntry:replacement];
        [_entries removeObjectForKey:key];
        entry.key = newKey;
        [_entries setObject:entry forKey:entry.key];
    }
    [_lock unlock];
}

- (NSArray *)allKeys
{
    [_lock lock];
    NSArray *keys = [_entries allKeys];
    [_lock unlock];
    return keys;
}

- (void)trimToCost:(NSUInteger)cost
{
    [_lock lock];
    [self trimLockedToCost:cost count:NSUIntegerMax];
    [_lock unlock];
}

- (void)removeAllObjects
{
    [_lock lock];
    _first = nil;
    _last = nil;
    _totalCost = 0;
    _evictionGeneration++;
    [_entries removeAllObjects];
    [_lock unlock];
}

@end
