#if !defined(ONEGRAM_ARMV6)

#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

static int32_t OGPlatformAvailabilityVersion[3] = {0, 0, 0};
static pthread_once_t OGPlatformAvailabilityOnce = PTHREAD_ONCE_INIT;

static CFDataRef OGPlatformAvailabilityCopyFile(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (file == NULL)
        return NULL;
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    uint8_t buffer[4096];
    size_t count = 0;
    while ((count = fread(buffer, 1, sizeof(buffer), file)) > 0)
        CFDataAppendBytes(data, buffer, (CFIndex)count);
    bool failed = ferror(file) != 0;
    fclose(file);
    if (failed)
    {
        CFRelease(data);
        return NULL;
    }
    return data;
}

static void OGPlatformAvailabilityLoad(void)
{
    CFDataRef data = OGPlatformAvailabilityCopyFile("/System/Library/CoreServices/SystemVersion.plist");
    if (data == NULL)
        return;
    CFPropertyListRef list = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListImmutable, NULL, NULL);
    CFRelease(data);
    if (list == NULL)
        return;
    if (CFGetTypeID(list) == CFDictionaryGetTypeID())
    {
        CFTypeRef value = CFDictionaryGetValue((CFDictionaryRef)list, CFSTR("ProductVersion"));
        char text[32];
        if (value != NULL && CFGetTypeID(value) == CFStringGetTypeID() && CFStringGetCString((CFStringRef)value, text, sizeof(text), kCFStringEncodingASCII))
        {
            int major = 0;
            int minor = 0;
            int subminor = 0;
            if (sscanf(text, "%d.%d.%d", &major, &minor, &subminor) >= 1)
            {
                OGPlatformAvailabilityVersion[0] = major;
                OGPlatformAvailabilityVersion[1] = minor;
                OGPlatformAvailabilityVersion[2] = subminor;
            }
        }
    }
    CFRelease(list);
}

int32_t __isOSVersionAtLeast(int32_t major, int32_t minor, int32_t subminor)
{
    pthread_once(&OGPlatformAvailabilityOnce, OGPlatformAvailabilityLoad);
    if (OGPlatformAvailabilityVersion[0] != major)
        return OGPlatformAvailabilityVersion[0] > major;
    if (OGPlatformAvailabilityVersion[1] != minor)
        return OGPlatformAvailabilityVersion[1] > minor;
    return OGPlatformAvailabilityVersion[2] >= subminor;
}

#endif
