#import <Foundation/Foundation.h>
#include <stdint.h>

@interface OGMemoryCache : NSObject

@property (nonatomic) NSUInteger countLimit;
@property (nonatomic) NSUInteger costLimit;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) uint64_t totalCost;
@property (nonatomic, readonly) uint64_t evictionGeneration;

- (instancetype)initWithCountLimit:(NSUInteger)countLimit costLimit:(NSUInteger)costLimit;
- (id)objectForKey:(id<NSCopying>)key;
- (void)setObject:(id)object forKey:(id<NSCopying>)key cost:(NSUInteger)cost;
- (void)removeObjectForKey:(id<NSCopying>)key;
- (void)removeObjectsForKeys:(NSArray *)keys;
- (void)removeObjectsMatchingKeyPredicate:(BOOL (^)(id key))predicate;
- (void)moveObjectForKey:(id<NSCopying>)key toKey:(id<NSCopying>)newKey;
- (NSArray *)allKeys;
- (void)trimToCost:(NSUInteger)cost;
- (void)removeAllObjects;

@end
