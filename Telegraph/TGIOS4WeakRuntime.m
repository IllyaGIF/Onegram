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

typedef struct TGWeakRuntimeFrame
{
    id target;
    Class methodClass;
    struct TGWeakRuntimeFrame *previous;
} TGWeakRuntimeFrame;

static pthread_once_t TGWeakRuntimeOnce = PTHREAD_ONCE_INIT;
static pthread_mutex_t TGWeakRuntimeMutex;
static pthread_cond_t TGWeakRuntimeCondition;
static pthread_key_t TGWeakReleaseFrameKey;
static pthread_key_t TGWeakDeallocFrameKey;
static CFMutableDictionaryRef TGWeakRuntimeReferences;
static CFMutableBagRef TGWeakRuntimeReleases;
static CFMutableDictionaryRef TGWeakRuntimeReleaseImplementations;
static CFMutableDictionaryRef TGWeakRuntimeDeallocImplementations;
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
static SEL TGWeakDeallocSelector;

static void TGWeakReleaseHook(id target, SEL selector);
static void TGWeakDeallocHook(id target, SEL selector);

static Method TGWeakOwnMethod(Class cls, SEL selector)
{
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method result = NULL;
    for (unsigned int i = 0; i < count; i++)
    {
        if (method_getName(methods[i]) == selector)
        {
            result = methods[i];
            break;
        }
    }
    free(methods);
    return result;
}

static void TGWeakClearLocation(const void *value, void *context)
{
    (void)context;
    id *location = (id *)value;
    *location = nil;
}

static void TGWeakZeroObjectLocked(id object)
{
    CFSetRef locations = (CFSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, object);
    if (locations != NULL)
        CFSetApplyFunction(locations, TGWeakClearLocation, NULL);
    CFDictionaryRemoveValue(TGWeakRuntimeReferences, object);
    pthread_cond_broadcast(&TGWeakRuntimeCondition);
}

static Class TGWeakMethodOwner(Class startClass, SEL selector, IMP implementation)
{
    Class currentClass = startClass;
    while (currentClass != Nil)
    {
        Method method = TGWeakOwnMethod(currentClass, selector);
        if (method != NULL && method_getImplementation(method) == implementation)
            return currentClass;
        currentClass = class_getSuperclass(currentClass);
    }
    return Nil;
}

static IMP TGWeakOriginalImplementationLocked(Class startClass, SEL selector, IMP hook, CFMutableDictionaryRef implementations, CFMutableDictionaryRef implementationClasses, Class *implementationClass)
{
    Class currentClass = startClass;
    while (currentClass != Nil)
    {
        IMP implementation = (IMP)CFDictionaryGetValue(implementations, currentClass);
        if (implementation != NULL)
        {
            Class ownerClass = (Class)CFDictionaryGetValue(implementationClasses, currentClass);
            if (ownerClass == Nil)
                ownerClass = TGWeakMethodOwner(currentClass, selector, implementation);
            if (ownerClass == Nil)
                ownerClass = currentClass;
            if (implementationClass != NULL)
                *implementationClass = ownerClass;
            return implementation;
        }

        Method ownMethod = TGWeakOwnMethod(currentClass, selector);
        if (ownMethod != NULL)
        {
            implementation = method_getImplementation(ownMethod);
            if (implementation != hook)
            {
                if (implementationClass != NULL)
                    *implementationClass = currentClass;
                return implementation;
            }
        }

        currentClass = class_getSuperclass(currentClass);
    }
    return NULL;
}

static IMP TGWeakInstallHookLocked(Class cls, SEL selector, IMP hook, CFMutableDictionaryRef implementations, CFMutableDictionaryRef implementationClasses)
{
    IMP storedImplementation = (IMP)CFDictionaryGetValue(implementations, cls);
    if (storedImplementation != NULL)
        return storedImplementation;

    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL)
        return NULL;

    const char *types = method_getTypeEncoding(method);
    Method ownMethod = TGWeakOwnMethod(cls, selector);
    IMP originalImplementation = NULL;
    Class originalImplementationClass = Nil;

    if (ownMethod != NULL)
    {
        IMP implementation = method_getImplementation(ownMethod);
        if (implementation != hook)
        {
            originalImplementation = implementation;
            originalImplementationClass = cls;
        }
    }
    else
    {
        IMP inheritedImplementation = method_getImplementation(method);
        if (inheritedImplementation != hook)
        {
            originalImplementation = inheritedImplementation;
            originalImplementationClass = TGWeakMethodOwner(class_getSuperclass(cls), selector, inheritedImplementation);
        }
        else
        {
            Class currentClass = class_getSuperclass(cls);
            while (currentClass != Nil)
            {
                originalImplementation = (IMP)CFDictionaryGetValue(implementations, currentClass);
                if (originalImplementation != NULL)
                {
                    originalImplementationClass = (Class)CFDictionaryGetValue(implementationClasses, currentClass);
                    break;
                }
                currentClass = class_getSuperclass(currentClass);
            }
        }
    }

    if (originalImplementation == NULL)
        return NULL;
    if (originalImplementationClass == Nil)
        originalImplementationClass = cls;

    CFDictionarySetValue(implementations, cls, (const void *)originalImplementation);
    CFDictionarySetValue(implementationClasses, cls, originalImplementationClass);

    if (ownMethod != NULL)
    {
        class_replaceMethod(cls, selector, hook, types);
    }
    else if (!class_addMethod(cls, selector, hook, types))
    {
        Method currentMethod = TGWeakOwnMethod(cls, selector);
        if (currentMethod == NULL || method_getImplementation(currentMethod) != hook)
        {
            CFDictionaryRemoveValue(implementations, cls);
            CFDictionaryRemoveValue(implementationClasses, cls);
            return NULL;
        }
    }

    return originalImplementation;
}

static void TGWeakReleaseHook(id target, SEL selector)
{
    TGWeakRuntimeFrame *previousFrame = (TGWeakRuntimeFrame *)pthread_getspecific(TGWeakReleaseFrameKey);
    Class searchClass = object_getClass(target);
    if (previousFrame != NULL && previousFrame->target == target)
        searchClass = class_getSuperclass(previousFrame->methodClass);

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    Class methodClass = Nil;
    IMP originalRelease = TGWeakOriginalImplementationLocked(searchClass, TGWeakReleaseSelector, (IMP)TGWeakReleaseHook, TGWeakRuntimeReleaseImplementations, TGWeakRuntimeReleaseImplementationClasses, &methodClass);
    if (originalRelease == NULL)
    {
        pthread_mutex_unlock(&TGWeakRuntimeMutex);
        abort();
    }
    CFBagAddValue(TGWeakRuntimeReleases, target);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    TGWeakRuntimeFrame frame;
    frame.target = target;
    frame.methodClass = methodClass;
    frame.previous = previousFrame;
    pthread_setspecific(TGWeakReleaseFrameKey, &frame);

    ((void (*)(id, SEL))originalRelease)(target, selector);

    pthread_setspecific(TGWeakReleaseFrameKey, previousFrame);

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    CFBagRemoveValue(TGWeakRuntimeReleases, target);
    pthread_cond_broadcast(&TGWeakRuntimeCondition);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
}

static void TGWeakDeallocHook(id target, SEL selector)
{
    TGWeakRuntimeFrame *previousFrame = (TGWeakRuntimeFrame *)pthread_getspecific(TGWeakDeallocFrameKey);
    Class searchClass = object_getClass(target);
    if (previousFrame != NULL && previousFrame->target == target)
        searchClass = class_getSuperclass(previousFrame->methodClass);

    pthread_mutex_lock(&TGWeakRuntimeMutex);
    TGWeakZeroObjectLocked(target);
    Class methodClass = Nil;
    IMP originalDealloc = TGWeakOriginalImplementationLocked(searchClass, TGWeakDeallocSelector, (IMP)TGWeakDeallocHook, TGWeakRuntimeDeallocImplementations, TGWeakRuntimeDeallocImplementationClasses, &methodClass);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);

    if (originalDealloc == NULL)
        abort();

    TGWeakRuntimeFrame frame;
    frame.target = target;
    frame.methodClass = methodClass;
    frame.previous = previousFrame;
    pthread_setspecific(TGWeakDeallocFrameKey, &frame);

    ((void (*)(id, SEL))originalDealloc)(target, selector);

    pthread_setspecific(TGWeakDeallocFrameKey, previousFrame);
}

static void TGWeakEnsureHooksLocked(id object)
{
    Class cls = object_getClass(object);
    if (cls == Nil)
        abort();

    if (TGWeakInstallHookLocked(cls, TGWeakReleaseSelector, (IMP)TGWeakReleaseHook, TGWeakRuntimeReleaseImplementations, TGWeakRuntimeReleaseImplementationClasses) == NULL)
        abort();
    if (TGWeakInstallHookLocked(cls, TGWeakDeallocSelector, (IMP)TGWeakDeallocHook, TGWeakRuntimeDeallocImplementations, TGWeakRuntimeDeallocImplementationClasses) == NULL)
        abort();
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

    if (TGNativeLoadWeakRetained == NULL || TGNativeStoreWeak == NULL)
    {
        TGNativeLoadWeakRetained = NULL;
        TGNativeLoadWeak = NULL;
        TGNativeStoreWeak = NULL;
        TGNativeInitWeak = NULL;
        TGNativeDestroyWeak = NULL;
        TGNativeCopyWeak = NULL;
        TGNativeMoveWeak = NULL;

        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&TGWeakRuntimeMutex, &attributes);
        pthread_mutexattr_destroy(&attributes);
        pthread_cond_init(&TGWeakRuntimeCondition, NULL);
        if (pthread_key_create(&TGWeakReleaseFrameKey, NULL) != 0)
            abort();
        if (pthread_key_create(&TGWeakDeallocFrameKey, NULL) != 0)
            abort();

        TGWeakRuntimeReferences = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        TGWeakRuntimeReleases = CFBagCreateMutable(NULL, 0, NULL);
        TGWeakRuntimeReleaseImplementations = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        TGWeakRuntimeDeallocImplementations = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        TGWeakRuntimeReleaseImplementationClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        TGWeakRuntimeDeallocImplementationClasses = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        if (TGWeakRuntimeReferences == NULL || TGWeakRuntimeReleases == NULL || TGWeakRuntimeReleaseImplementations == NULL || TGWeakRuntimeDeallocImplementations == NULL || TGWeakRuntimeReleaseImplementationClasses == NULL || TGWeakRuntimeDeallocImplementationClasses == NULL)
            abort();

        TGWeakReleaseSelector = sel_registerName("release");
        TGWeakDeallocSelector = sel_registerName("dealloc");
    }
}

static void TGWeakRuntimeEnsureInitialized(void)
{
    pthread_once(&TGWeakRuntimeOnce, TGWeakRuntimeInitialize);
}

static void TGWeakUnregisterLocationLocked(id *location)
{
    id object = *location;
    if (object == nil)
        return;

    while (*location == object && CFBagContainsValue(TGWeakRuntimeReleases, object))
        pthread_cond_wait(&TGWeakRuntimeCondition, &TGWeakRuntimeMutex);

    object = *location;
    if (object == nil)
        return;

    CFMutableSetRef locations = (CFMutableSetRef)CFDictionaryGetValue(TGWeakRuntimeReferences, object);
    if (locations != NULL)
        CFSetRemoveValue(locations, location);
}

static void TGWeakRegisterLocationLocked(id *location, id object)
{
    TGWeakEnsureHooksLocked(object);

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
}

id objc_storeWeak(id *location, id value)
{
    TGWeakRuntimeEnsureInitialized();
    if (TGNativeStoreWeak != NULL)
        return TGNativeStoreWeak(location, value);

    id retainedValue = [value retain];
    pthread_mutex_lock(&TGWeakRuntimeMutex);
    TGWeakUnregisterLocationLocked(location);
    *location = value;
    if (value != nil)
        TGWeakRegisterLocationLocked(location, value);
    pthread_mutex_unlock(&TGWeakRuntimeMutex);
    [retainedValue release];
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
    while (value != nil && CFBagContainsValue(TGWeakRuntimeReleases, value))
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
