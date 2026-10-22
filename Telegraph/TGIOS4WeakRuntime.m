#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <pthread.h>
#import <stdlib.h>

typedef id (*TGWeakLoadRetainedFunction)(id *);
typedef id (*TGWeakLoadFunction)(id *);
typedef id (*TGWeakStoreFunction)(id *, id);
typedef id (*TGWeakInitFunction)(id *, id);
typedef void (*TGWeakDestroyFunction)(id *);
typedef void (*TGWeakCopyFunction)(id *, id *);
typedef void (*TGWeakMoveFunction)(id *, id *);

typedef struct
{
    const void *target;
    Class implementationClass;
} TGWeakDispatchFrame;

typedef struct
{
    TGWeakDispatchFrame *frames;
    CFIndex count;
    CFIndex capacity;
} TGWeakDispatchStack;

typedef struct
{
    TGWeakDispatchStack releaseFrames;
    TGWeakDispatchStack deallocFrames;
} TGWeakThreadState;

static pthread_once_t TGWeakRuntimeOnce = PTHREAD_ONCE_INIT;
static pthread_mutex_t TGWeakRuntimeMutex;
static pthread_cond_t TGWeakRuntimeCondition;
static pthread_key_t TGWeakRuntimeThreadKey;
static CFMutableDictionaryRef TGWeakRuntimeReferences;
static CFMutableSetRef TGWeakRuntimeSwizzledClasses;
static CFMutableBagRef TGWeakRuntimeReleasing;
static CFMutableDictionaryRef TGWeakRuntimeReleaseImplementationClasses;
static CFMutableDictionaryRef TGWeakRuntimeDeallocImplementationClasses;
static TGWeakLoadRetainedFunction TGNativeLoadWeakRetained;
static TGWeakLoadFunction TGNativeLoadWeak;
static TGWeakStoreFunction TGNativeStoreWeak;
static TGWeakInitFunction TGNativeInitWeak;
static TGWeakDestroyFunction TGNativeDestroyWeak;
static TGWeakCopyFunction TGNativeCopyWeak;
static TGWeakMoveFunction TGNativeMoveWeak;
static SEL TGWeakReleaseSelector;
static SEL TGWeakOriginalReleaseSelector;
static SEL TGWeakDeallocSelector;
static SEL TGWeakOriginalDeallocSelector;

static void TGWeakReleaseHook(id target, SEL selector);
static void TGWeakDeallocHook(id target, SEL selector);

static void TGWeakThreadStateDestroy(void *pointer)
{
    TGWeakThreadState *state = (TGWeakThreadState *)pointer;
    if (state == NULL)
        return;
    free(state->releaseFrames.frames);
    free(state->deallocFrames.frames);
    free(state);
}

static Class TGWeakDispatchStackLookup(const TGWeakDispatchStack *stack, const void *target)
{
    for (CFIndex index = stack->count; index > 0; index--)
    {
        if (stack->frames[index - 1].target == target)
            return stack->frames[index - 1].implementationClass;
    }
    return Nil;
}

static void TGWeakDispatchStackPush(TGWeakDispatchStack *stack, const void *target, Class implementationClass)
{
    if (stack->count == stack->capacity)
    {
        CFIndex capacity = stack->capacity == 0 ? 16 : stack->capacity * 2;
        TGWeakDispatchFrame *frames = (TGWeakDispatchFrame *)realloc(stack->frames, (size_t)capacity * sizeof(TGWeakDispatchFrame));
        if (frames == NULL)
            abort();
        stack->frames = frames;
        stack->capacity = capacity;
    }
    stack->frames[stack->count].target = target;
    stack->frames[stack->count].implementationClass = implementationClass;
    stack->count++;
}

static TGWeakThreadState *TGWeakGetThreadState(void)
{
    TGWeakThreadState *state = (TGWeakThreadState *)pthread_getspecific(TGWeakRuntimeThreadKey);
    if (state == NULL)
    {
        state = (TGWeakThreadState *)calloc(1, sizeof(TGWeakThreadState));
        if (state == NULL)
            abort();
        if (pthread_setspecific(TGWeakRuntimeThreadKey, state) != 0)
            abort();
    }
    return state;
}

static Class TGWeakTopClassImplementingMethod(Class startClass, SEL selector)
{
    if (startClass == Nil)
        return Nil;

    IMP implementation = class_getMethodImplementation(startClass, selector);
    Class previousClass = startClass;
    Class currentClass = class_getSuperclass(previousClass);
    while (currentClass != Nil)
    {
        if (implementation != class_getMethodImplementation(currentClass, selector))
            break;
        previousClass = currentClass;
        currentClass = class_getSuperclass(currentClass);
    }
    return previousClass;
}

static Class TGWeakResolveImplementationClass(Class startClass, SEL selector, IMP hook)
{
    Class currentClass = startClass;
    while (currentClass != Nil)
    {
        Class implementationClass = TGWeakTopClassImplementingMethod(currentClass, selector);
        if (!class_respondsToSelector(implementationClass, selector))
            return Nil;
        if (class_getMethodImplementation(implementationClass, selector) != hook)
            return implementationClass;
        currentClass = class_getSuperclass(implementationClass);
    }
    return Nil;
}

static Class TGWeakCachedImplementationClassLocked(CFMutableDictionaryRef cache, Class cls, SEL selector, IMP hook)
{
    Class implementationClass = (Class)CFDictionaryGetValue(cache, cls);
    if (implementationClass == Nil)
    {
        implementationClass = TGWeakResolveImplementationClass(cls, selector, hook);
        if (implementationClass != Nil)
            CFDictionarySetValue(cache, cls, implementationClass);
    }
    return implementationClass;
}

static void TGWeakSwizzleClassLocked(Class cls, SEL selector, SEL originalSelector, IMP hook)
{
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL)
        abort();

    IMP originalImplementation = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    if (!class_addMethod(cls, originalSelector, originalImplementation, types))
    {
        Method ownMethod = class_getInstanceMethod(cls, originalSelector);
        if (ownMethod == NULL)
            abort();
    }
    class_replaceMethod(cls, selector, hook, types);
}

static void TGWeakEnsureHooksLocked(id object)
{
    Class cls = object_getClass(object);
    if (cls == Nil)
        abort();
    if (CFSetContainsValue(TGWeakRuntimeSwizzledClasses, cls))
        return;

    TGWeakSwizzleClassLocked(cls, TGWeakReleaseSelector, TGWeakOriginalReleaseSelector, (IMP)TGWeakReleaseHook);
    TGWeakSwizzleClassLocked(cls, TGWeakDeallocSelector, TGWeakOriginalDeallocSelector, (IMP)TGWeakDeallocHook);
    CFSetAddValue(TGWeakRuntimeSwizzledClasses, cls);
    CFDictionaryRemoveAllValues(TGWeakRuntimeReleaseImplementationClasses);
    CFDictionaryRemoveAllValues(TGWeakRuntimeDeallocImplementationClasses);
}

static void TGWeakClearLocation(const void *value, void *context)
{
    (void)context;
    id *location = (id *)value;
    *location = nil;
}

static void TGWeakReleaseHook(id target, SEL selector)
{
    TGWeakThreadState *state = TGWeakGetThreadState();
    Class lastClass = TGWeakDispatchStackLookup(&state->releaseFrames, target);
    Class targetClass = Nil;

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFBagAddValue(TGWeakRuntimeReleasing, target);
    if (lastClass == Nil)
        targetClass = TGWeakCachedImplementationClassLocked(TGWeakRuntimeReleaseImplementationClasses, object_getClass(target), TGWeakOriginalReleaseSelector, (IMP)TGWeakReleaseHook);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    if (lastClass != Nil)
    {
        targetClass = TGWeakResolveImplementationClass(class_getSuperclass(lastClass), TGWeakOriginalReleaseSelector, (IMP)TGWeakReleaseHook);
        if (targetClass == Nil)
            targetClass = TGWeakResolveImplementationClass(object_getClass(target), TGWeakOriginalReleaseSelector, (IMP)TGWeakReleaseHook);
    }
    if (targetClass == Nil)
        abort();

    IMP implementation = class_getMethodImplementation(targetClass, TGWeakOriginalReleaseSelector);
    if (implementation == NULL)
        abort();

    CFIndex depth = state->releaseFrames.count;
    TGWeakDispatchStackPush(&state->releaseFrames, target, targetClass);
    ((void (*)(id, SEL))implementation)(target, selector);
    state->releaseFrames.count = depth;

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFBagRemoveValue(TGWeakRuntimeReleasing, target);
    pthread_cond_broadcast(&TGWeakRuntimeCondition);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
}

static void TGWeakDeallocHook(id target, SEL selector)
{
    TGWeakThreadState *state = TGWeakGetThreadState();
    Class lastClass = TGWeakDispatchStackLookup(&state->deallocFrames, target);
    Class targetClass = Nil;

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFSetRef locations = (CFSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, target);
    if (locations != NULL)
    {
        CFSetApplyFunction(locations, TGWeakClearLocation, NULL);
        CFDictionaryRemoveValue(TGWeakRuntimeReferences, target);
        pthread_cond_broadcast(&TGWeakRuntimeCondition);
    }
    if (lastClass == Nil)
        targetClass = TGWeakCachedImplementationClassLocked(TGWeakRuntimeDeallocImplementationClasses, object_getClass(target), TGWeakOriginalDeallocSelector, (IMP)TGWeakDeallocHook);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    if (lastClass != Nil)
        targetClass = TGWeakResolveImplementationClass(class_getSuperclass(lastClass), TGWeakOriginalDeallocSelector, (IMP)TGWeakDeallocHook);
    if (targetClass == Nil)
        abort();

    IMP implementation = class_getMethodImplementation(targetClass, TGWeakOriginalDeallocSelector);
    if (implementation == NULL)
        abort();

    CFIndex depth = state->deallocFrames.count;
    TGWeakDispatchStackPush(&state->deallocFrames, target, targetClass);
    ((void (*)(id, SEL))implementation)(target, selector);
    state->deallocFrames.count = depth;
}

static void TGWeakRuntimeInitialize(void)
{
    TGNativeLoadWeakRetained = (TGWeakLoadRetainedFunction)dlsym(RTLD_NEXT, "objc_loadWeakRetained");
    TGNativeLoadWeak = (TGWeakLoadFunction)dlsym(RTLD_NEXT, "objc_loadWeak");
    TGNativeStoreWeak = (TGWeakStoreFunction)dlsym(RTLD_NEXT, "objc_storeWeak");
    TGNativeInitWeak = (TGWeakInitFunction)dlsym(RTLD_NEXT, "objc_initWeak");
    TGNativeDestroyWeak = (TGWeakDestroyFunction)dlsym(RTLD_NEXT, "objc_destroyWeak");
    TGNativeCopyWeak = (TGWeakCopyFunction)dlsym(RTLD_NEXT, "objc_copyWeak");
    TGNativeMoveWeak = (TGWeakMoveFunction)dlsym(RTLD_NEXT, "objc_moveWeak");

    if (TGNativeLoadWeakRetained != NULL && TGNativeStoreWeak != NULL)
        return;

    TGNativeLoadWeakRetained = NULL;
    TGNativeLoadWeak = NULL;
    TGNativeStoreWeak = NULL;
    TGNativeInitWeak = NULL;
    TGNativeDestroyWeak = NULL;
    TGNativeCopyWeak = NULL;
    TGNativeMoveWeak = NULL;

    pthread_mutexattr_t attributes;
    if (pthread_mutexattr_init(&attributes) != 0)
        abort();
    if (pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE) != 0)
        abort();
    if (pthread_mutex_init(&TGWeakRuntimeMutex, &attributes) != 0)
        abort();
    pthread_mutexattr_destroy(&attributes);
    if (pthread_cond_init(&TGWeakRuntimeCondition, NULL) != 0)
        abort();
    if (pthread_key_create(&TGWeakRuntimeThreadKey, TGWeakThreadStateDestroy) != 0)
        abort();

    TGWeakRuntimeReferences = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    TGWeakRuntimeSwizzledClasses = CFSetCreateMutable(NULL, 0, NULL);
    TGWeakRuntimeReleasing = CFBagCreateMutable(NULL, 0, NULL);
    TGWeakRuntimeReleaseImplementationClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    TGWeakRuntimeDeallocImplementationClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    if (TGWeakRuntimeReferences == NULL || TGWeakRuntimeSwizzledClasses == NULL || TGWeakRuntimeReleasing == NULL || TGWeakRuntimeReleaseImplementationClasses == NULL || TGWeakRuntimeDeallocImplementationClasses == NULL)
        abort();

    TGWeakReleaseSelector = sel_registerName("release");
    TGWeakOriginalReleaseSelector = sel_registerName("tg_ios4_originalRelease");
    TGWeakDeallocSelector = sel_registerName("dealloc");
    TGWeakOriginalDeallocSelector = sel_registerName("tg_ios4_originalDealloc");
}

static void TGWeakRuntimeEnsureInitialized(void)
{
    pthread_once(&TGWeakRuntimeOnce, TGWeakRuntimeInitialize);
}

static void TGWeakUnregisterLocation(id *location)
{
    pthread_mutex_lock(&TGWeakRuntimeMutex);
    id object = *location;
    if (object != nil)
    {
        CFMutableSetRef locations = (CFMutableSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, object);
        if (locations != NULL)
            CFSetRemoveValue(locations, location);
    }
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
}

static void TGWeakRegisterLocation(id *location, id object)
{
    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFMutableSetRef locations = (CFMutableSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, object);
    if (locations == NULL)
    {
        locations = CFSetCreateMutable(NULL, 0, NULL);
        if (locations == NULL)
            abort();
        CFDictionarySetValue(TGWeakRuntimeReferences, object, locations);
        CFRelease(locations);
    }
    CFSetAddValue(locations, location);
    TGWeakEnsureHooksLocked(object);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
}

id objc_storeWeak(id *location, id value)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeStoreWeak != NULL)
        return TGNativeStoreWeak(location, value);

    TGWeakUnregisterLocation(location);
    *location = value;
    if (value != nil)
        TGWeakRegisterLocation(location, value);
    return value;
}

id objc_initWeak(id *location, id value)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeInitWeak != NULL)
        return TGNativeInitWeak(location, value);

    *location = nil;
    return objc_storeWeak(location, value);
}

void objc_destroyWeak(id *location)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeDestroyWeak != NULL)
    {
        TGNativeDestroyWeak(location);
        return;
    }

    objc_storeWeak(location, nil);
}

id objc_loadWeakRetained(id *location)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeLoadWeakRetained != NULL)
        return TGNativeLoadWeakRetained(location);

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    id value = *location;
    while (value != nil && CFBagContainsValue(TGWeakRuntimeReleasing, value))
    {
        pthread_cond_wait(&TGWeakRuntimeCondition, &TGWeakRuntimeMutex);
        value = *location;
    }
    [value retain];
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
    return value;
}

id objc_loadWeak(id *location)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeLoadWeak != NULL)
        return TGNativeLoadWeak(location);

    return [objc_loadWeakRetained(location) autorelease];
}

void objc_copyWeak(id *destination, id *source)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeCopyWeak != NULL)
    {
        TGNativeCopyWeak(destination, source);
        return;
    }

    id value = objc_loadWeakRetained(source);
    objc_initWeak(destination, value);
    [value release];
}

void objc_moveWeak(id *destination, id *source)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeMoveWeak != NULL)
    {
        TGNativeMoveWeak(destination, source);
        return;
    }

    objc_copyWeak(destination, source);
    objc_destroyWeak(source);
}
