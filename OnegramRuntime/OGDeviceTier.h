#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OGDeviceTier)
{
    OGDeviceTierLow,
    OGDeviceTierMedium,
    OGDeviceTierHigh
};

FOUNDATION_EXPORT OGDeviceTier OGDeviceTierCurrent(void);
FOUNDATION_EXPORT uint64_t OGDevicePhysicalMemory(void);
