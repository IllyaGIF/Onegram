#import <Foundation/Foundation.h>

#import "OnegramIOS3Compatibility.h"
#import <Block.h>

id objc_retain(id value)
{
    return [value retain];
}

void objc_release(id value)
{
    [value release];
}

id objc_autorelease(id value)
{
    return [value autorelease];
}

id objc_retainAutorelease(id value)
{
    return [[value retain] autorelease];
}

id objc_retainAutoreleaseReturnValue(id value)
{
    return [[value retain] autorelease];
}

id objc_retainAutoreleasedReturnValue(id value)
{
    return [value retain];
}

id objc_autoreleaseReturnValue(id value)
{
    return [value autorelease];
}

id objc_retainBlock(id value)
{
    return value == nil ? nil : _Block_copy(value);
}

void objc_storeStrong(id *location, id value)
{
    id retained = [value retain];
    id previous = *location;
    *location = retained;
    [previous release];
}

id OnegramIOS3LoadStrongIvar(const void *location)
{
    if (location == NULL)
        return nil;
    return *(id const *)location;
}

void OnegramIOS3StoreStrongIvar(void *location, id value)
{
    if (location == NULL)
        return;
    objc_storeStrong((id *)location, value);
}

void *objc_autoreleasePoolPush(void)
{
    return [[NSAutoreleasePool alloc] init];
}

void objc_autoreleasePoolPop(void *pool)
{
    [(NSAutoreleasePool *)pool drain];
}

id objc_retainedObject(id value)
{
    return value;
}

id objc_unretainedObject(id value)
{
    return value;
}

void *objc_unretainedPointer(id value)
{
    return value;
}

@implementation NSValue (OnegramIOS3UIOffsetCompatibility)

+ (NSValue *)valueWithUIOffset:(UIOffset)offset
{
    return [NSValue value:&offset withObjCType:@encode(UIOffset)];
}

- (UIOffset)UIOffsetValue
{
    UIOffset offset = UIOffsetMake(0.0f, 0.0f);
    [self getValue:&offset];
    return offset;
}

@end

@implementation NSIndexSet (OnegramIOS3EnumerationCompatibility)

- (void)enumerateIndexesUsingBlock:(void (^)(NSUInteger idx, BOOL *stop))block
{
    [self enumerateIndexesWithOptions:0 usingBlock:block];
}

- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(NSUInteger idx, BOOL *stop))block
{
    if (block == nil)
        return;

    BOOL stop = NO;
    if ((opts & NSEnumerationReverse) != 0)
    {
        NSUInteger index = [self lastIndex];
        while (index != NSNotFound && !stop)
        {
            block(index, &stop);
            if (index == 0)
                break;
            index = [self indexLessThanIndex:index];
        }
    }
    else
    {
        NSUInteger index = [self firstIndex];
        while (index != NSNotFound && !stop)
        {
            block(index, &stop);
            index = [self indexGreaterThanIndex:index];
        }
    }
}

@end

@implementation NSArray (OnegramIOS3Subscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return [self objectAtIndex:index];
}

- (id)firstObject
{
    return [self count] == 0 ? nil : [self objectAtIndex:0];
}

- (id)lastObject
{
    return [self count] == 0 ? nil : [self objectAtIndex:[self count] - 1];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block
{
    [self enumerateObjectsWithOptions:0 usingBlock:block];
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block
{
    if (block == nil)
        return;

    BOOL stop = NO;
    NSUInteger count = [self count];
    if ((opts & NSEnumerationReverse) != 0)
    {
        NSUInteger index = count;
        while (index > 0 && !stop)
        {
            index--;
            block([self objectAtIndex:index], index, &stop);
        }
    }
    else
    {
        for (NSUInteger index = 0; index < count && !stop; index++)
            block([self objectAtIndex:index], index, &stop);
    }
}

- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate
{
    if (predicate == nil)
        return NSNotFound;

    BOOL stop = NO;
    NSUInteger count = [self count];
    for (NSUInteger index = 0; index < count && !stop; index++)
    {
        if (predicate([self objectAtIndex:index], index, &stop))
            return index;
    }
    return NSNotFound;
}

- (NSArray *)sortedArrayUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    NSMutableArray *result = [NSMutableArray arrayWithArray:self];
    [result sortUsingComparator:cmptr];
    return result;
}

@end

@implementation NSMutableArray (OnegramIOS3Subscripting)

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index
{
    if (index == [self count])
        [self addObject:object];
    else
        [self replaceObjectAtIndex:index withObject:object];
}

@end

@implementation NSSet (OnegramIOS3EnumerationCompatibility)

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block
{
    if (block == nil)
        return;

    BOOL stop = NO;
    for (id object in self)
    {
        block(object, &stop);
        if (stop)
            break;
    }
}

@end

@implementation NSDictionary (OnegramIOS3Subscripting)

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block
{
    if (block == nil)
        return;

    BOOL stop = NO;
    for (id key in self)
    {
        block(key, [self objectForKey:key], &stop);
        if (stop)
            break;
    }
}

- (NSArray *)keysSortedByValueUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    NSMutableArray *keys = [NSMutableArray arrayWithArray:[self allKeys]];
    if (cmptr == nil || [keys count] < 2)
        return keys;

    [keys sortUsingComparator:^NSComparisonResult(id lhs, id rhs)
    {
        return cmptr([self objectForKey:lhs], [self objectForKey:rhs]);
    }];
    return keys;
}

@end

@implementation NSMutableDictionary (OnegramIOS3Subscripting)

- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)key
{
    if (object == nil)
        [self removeObjectForKey:key];
    else
        [self setObject:object forKey:key];
}

@end
