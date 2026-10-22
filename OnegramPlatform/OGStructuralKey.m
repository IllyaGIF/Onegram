#import "OGStructuralKey.h"

NSUInteger OGStructuralKeyHash(id key)
{
    if (![key isKindOfClass:[NSArray class]])
        return [key hash];
    NSArray *components = key;
    NSUInteger hash = components.count;
    for (id component in components)
        hash = hash * 31u + OGStructuralKeyHash(component);
    return hash;
}

static const void *OGStructuralKeyRetain(__unused CFAllocatorRef allocator, const void *value)
{
    return CFRetain(value);
}

static void OGStructuralKeyRelease(__unused CFAllocatorRef allocator, const void *value)
{
    CFRelease(value);
}

static CFHashCode OGStructuralKeyCFHash(const void *value)
{
    return (CFHashCode)OGStructuralKeyHash((__bridge id)value);
}

static const CFDictionaryKeyCallBacks OGStructuralKeyCallBacks = {
    0,
    OGStructuralKeyRetain,
    OGStructuralKeyRelease,
    CFCopyDescription,
    CFEqual,
    OGStructuralKeyCFHash
};

NSMutableDictionary *OGStructuralKeyDictionaryCreate(void)
{
    return (__bridge_transfer NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OGStructuralKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}
