#import <Foundation/Foundation.h>
#import "Block.h"
#import "Block_private.h"

static void OnegramBlockRetainObject(const void *object)
{
    [(id)object retain];
}

static void OnegramBlockReleaseObject(const void *object)
{
    [(id)object release];
}

__attribute__((constructor)) static void OnegramInitializeBlocksRuntime(void)
{
    _Block_use_RR(OnegramBlockRetainObject, OnegramBlockReleaseObject);
}

@interface __NSStackBlock__ : NSObject <NSCopying>
@end

@implementation __NSStackBlock__

- (id)copy
{
    return _Block_copy(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    return _Block_copy(self);
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

@end

@interface __NSMallocBlock__ : NSObject <NSCopying>
@end

@implementation __NSMallocBlock__

- (id)copy
{
    return _Block_copy(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    return _Block_copy(self);
}

- (id)retain
{
    return _Block_copy(self);
}

- (oneway void)release
{
    _Block_release(self);
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return [super autorelease];
}

@end

@interface __NSAutoBlock__ : NSObject <NSCopying>
@end

@implementation __NSAutoBlock__

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@interface __NSFinalizingBlock__ : __NSAutoBlock__
@end

@implementation __NSFinalizingBlock__
@end

@interface __NSGlobalBlock__ : NSObject <NSCopying>
@end

@implementation __NSGlobalBlock__

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

@end

@interface __NSBlockVariable__ : NSObject
@end

@implementation __NSBlockVariable__
@end

#if !defined(ONEGRAM_LINKER_BLOCK_ALIASES)
__asm__(
".globl __NSConcreteStackBlock\n"
".set __NSConcreteStackBlock, _OBJC_CLASS_$___NSStackBlock__\n"
".globl __NSConcreteMallocBlock\n"
".set __NSConcreteMallocBlock, _OBJC_CLASS_$___NSMallocBlock__\n"
".globl __NSConcreteAutoBlock\n"
".set __NSConcreteAutoBlock, _OBJC_CLASS_$___NSAutoBlock__\n"
".globl __NSConcreteFinalizingBlock\n"
".set __NSConcreteFinalizingBlock, _OBJC_CLASS_$___NSFinalizingBlock__\n"
".globl __NSConcreteGlobalBlock\n"
".set __NSConcreteGlobalBlock, _OBJC_CLASS_$___NSGlobalBlock__\n"
".globl __NSConcreteWeakBlockVariable\n"
".set __NSConcreteWeakBlockVariable, _OBJC_CLASS_$___NSBlockVariable__\n"
);
#endif
