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
    CFMutableDictionaryRef releaseClasses;
    CFMutableDictionaryRef deallocClasses;
} TGWeakThreadState;

static pthread_once_t TGWeakRuntimeOnce = PTHREAD_ONCE_INIT;
static pthread_mutex_t TGWeakRuntimeMutex;
static pthread_cond_t TGWeakRuntimeCondition;
static pthread_key_t TGWeakRuntimeThreadKey;
static CFMutableDictionaryRef TGWeakRuntimeReferences;
static CFMutableSetRef TGWeakRuntimeSwizzledClasses;
static CFMutableBagRef TGWeakRuntimeReleasing;
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
    if (state->releaseClasses != NULL)
        CFRelease(state->releaseClasses);
    if (state->deallocClasses != NULL)
        CFRelease(state->deallocClasses);
    free(state);
}

static TGWeakThreadState *TGWeakGetThreadState(void)
{
    TGWeakThreadState *state = (TGWeakThreadState *)pthread_getspecific(TGWeakRuntimeThreadKey);
    if (state == NULL)
    {
        state = (TGWeakThreadState *)calloc(1, sizeof(TGWeakThreadState));
        if (state == NULL)
            abort();
        state->releaseClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        state->deallocClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        if (state->releaseClasses == NULL || state->deallocClasses == NULL)
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

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFBagAddValue(TGWeakRuntimeReleasing, target);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    Class lastClass = (Class)CFDictionaryGetValue(state->releaseClasses, target);
    Class targetClass = lastClass == Nil ? object_getClass(target) : class_getSuperclass(lastClass);
    if (targetClass != Nil)
        targetClass = TGWeakTopClassImplementingMethod(targetClass, TGWeakOriginalReleaseSelector);

    if (targetClass == Nil || !class_respondsToSelector(targetClass, TGWeakOriginalReleaseSelector))
    {
        targetClass = object_getClass(target);
        if (targetClass != Nil)
            targetClass = TGWeakTopClassImplementingMethod(targetClass, TGWeakOriginalReleaseSelector);
    }

    if (targetClass == Nil || !class_respondsToSelector(targetClass, TGWeakOriginalReleaseSelector))
        abort();

    CFDictionarySetValue(state->releaseClasses, target, targetClass);

    IMP implementation = class_getMethodImplementation(targetClass, TGWeakOriginalReleaseSelector);
    if (implementation == NULL)
        abort();
    ((void (*)(id, SEL))implementation)(target, selector);

    CFDictionaryRemoveValue(state->releaseClasses, target);

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFBagRemoveValue(TGWeakRuntimeReleasing, target);
    pthread_cond_broadcast(&TGWeakRuntimeCondition);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
}

static void TGWeakDeallocHook(id target, SEL selector)
{
    TGWeakThreadState *state = TGWeakGetThreadState();

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFSetRef locations = (CFSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, target);
    if (locations != NULL)
        CFSetApplyFunction(locations, TGWeakClearLocation, NULL);
    CFDictionaryRemoveValue(TGWeakRuntimeReferences, target);
    pthread_cond_broadcast(&TGWeakRuntimeCondition);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    Class lastClass = (Class)CFDictionaryGetValue(state->deallocClasses, target);
    Class targetClass = lastClass == Nil ? object_getClass(target) : class_getSuperclass(lastClass);
    targetClass = TGWeakTopClassImplementingMethod(targetClass, TGWeakOriginalDeallocSelector);
    if (targetClass == Nil)
        abort();
    CFDictionarySetValue(state->deallocClasses, target, targetClass);

    IMP implementation = class_getMethodImplementation(targetClass, TGWeakOriginalDeallocSelector);
    if (implementation == NULL)
        abort();
    ((void (*)(id, SEL))implementation)(target, selector);

    CFDictionaryRemoveValue(state->deallocClasses, target);
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
    if (TGWeakRuntimeReferences == NULL || TGWeakRuntimeSwizzledClasses == NULL || TGWeakRuntimeReleasing == NULL)
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
