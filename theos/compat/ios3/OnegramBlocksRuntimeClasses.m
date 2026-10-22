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

@interface OnegramIOS3StackBlock : NSObject <NSCopying>
@end

@implementation OnegramIOS3StackBlock

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

@interface OnegramIOS3MallocBlock : NSObject <NSCopying>
@end

@implementation OnegramIOS3MallocBlock

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

@interface OnegramIOS3AutoBlock : NSObject <NSCopying>
@end

@implementation OnegramIOS3AutoBlock

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@interface OnegramIOS3FinalizingBlock : OnegramIOS3AutoBlock
@end

@implementation OnegramIOS3FinalizingBlock
@end

@interface OnegramIOS3GlobalBlock : NSObject <NSCopying>
@end

@implementation OnegramIOS3GlobalBlock

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

@interface OnegramIOS3BlockVariable : NSObject
@end

@implementation OnegramIOS3BlockVariable
@end

#if !defined(ONEGRAM_LINKER_BLOCK_ALIASES)
__asm__(
".globl __NSConcreteStackBlock\n"
".set __NSConcreteStackBlock, _OBJC_CLASS_$_OnegramIOS3StackBlock\n"
".globl __NSConcreteMallocBlock\n"
".set __NSConcreteMallocBlock, _OBJC_CLASS_$_OnegramIOS3MallocBlock\n"
".globl __NSConcreteAutoBlock\n"
".set __NSConcreteAutoBlock, _OBJC_CLASS_$_OnegramIOS3AutoBlock\n"
".globl __NSConcreteFinalizingBlock\n"
".set __NSConcreteFinalizingBlock, _OBJC_CLASS_$_OnegramIOS3FinalizingBlock\n"
".globl __NSConcreteGlobalBlock\n"
".set __NSConcreteGlobalBlock, _OBJC_CLASS_$_OnegramIOS3GlobalBlock\n"
".globl __NSConcreteWeakBlockVariable\n"
".set __NSConcreteWeakBlockVariable, _OBJC_CLASS_$_OnegramIOS3BlockVariable\n"
);
#endif
