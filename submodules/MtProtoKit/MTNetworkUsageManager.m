#import "MTNetworkUsageManager.h"

#include <sys/mman.h>
#include <string.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKitDynamic/MTSignal.h>
#   import <MTProtoKitDynamic/MTTimer.h>
#   import <MTProtoKitDynamic/MTQueue.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKitMac/MTSignal.h>
#   import <MTProtoKitMac/MTTimer.h>
#   import <MTProtoKitMac/MTQueue.h>
#else
#   import <MTProtoKit/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKit/MTSignal.h>
#   import <MTProtoKit/MTTimer.h>
#   import <MTProtoKit/MTQueue.h>
#endif

@interface MTNetworkUsageManager () {
    MTQueue *_queue;
    MTNetworkUsageCalculationInfo *_info;
    
    NSUInteger _pendingIncomingBytes;
    NSUInteger _pendingOutgoingBytes;
    
    int _fd;
    void *_map;
}

@end

@implementation MTNetworkUsageManager

- (instancetype)initWithInfo:(MTNetworkUsageCalculationInfo *)info {
    self = [super init];
    if (self != nil) {
        _queue = [[MTQueue alloc] init];
        _info = info;
        _fd = -1;
        
        [_queue dispatchOnQueue:^{
            NSString *path = info.filePath;
            int32_t fd = open([path UTF8String], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
            if (fd >= 0) {
                if (ftruncate(fd, 4096) == 0) {
                    void *map = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
                    if (map != MAP_FAILED) {
                        _fd = fd;
                        _map = map;
                    } else {
                        close(fd);
                    }
                } else {
                    close(fd);
                }
            }
        }];
    }
    return self;
}

- (void)dealloc {
    void *map = _map;
    int32_t fd = _fd;
    [_queue dispatchOnQueue:^{
        if (map) {
            munmap(map, 4096);
        }
        if (fd >= 0) {
            close(fd);
        }
    }];
}

static int keyForInterface(MTNetworkUsageCalculationInfo *info, MTNetworkUsageManagerInterface interface, bool incoming) {
    switch (interface) {
        case MTNetworkUsageManagerInterfaceWWAN:
            return incoming ? info.incomingWWANKey : info.outgoingWWANKey;
        case MTNetworkUsageManagerInterfaceOther:
            return incoming ? info.incomingOtherKey : info.outgoingOtherKey;
    }
    return -1;
}

static bool validUsageKey(int key) {
    return key >= 0 && key <= (4096 - (int)sizeof(int64_t)) / 8;
}

static int64_t readUsageValue(void *map, int key) {
    int64_t value = 0;
    memcpy(&value, ((uint8_t *)map) + key * 8, sizeof(value));
    return value;
}

static void writeUsageValue(void *map, int key, int64_t value) {
    memcpy(((uint8_t *)map) + key * 8, &value, sizeof(value));
}

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int key = keyForInterface(_info, interface, true);
            if (validUsageKey(key)) {
                int64_t value = readUsageValue(_map, key);
                value += (int64_t)incomingBytes;
                writeUsageValue(_map, key, value);
            }
        }
    }];
}

- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int key = keyForInterface(_info, interface, false);
            if (validUsageKey(key)) {
                int64_t value = readUsageValue(_map, key);
                value += (int64_t)outgoingBytes;
                writeUsageValue(_map, key, value);
            }
        }
    }];
}

- (void)resetKeys:(NSArray *)keys setKeys:(NSDictionary *)setKeys completion:(void (^)())completion {
    [_queue dispatchOnQueue:^{
        if (_map) {
            for (NSNumber *key in keys) {
                int keyValue = [key intValue];
                if (validUsageKey(keyValue))
                    writeUsageValue(_map, keyValue, 0);
            }
            [setKeys enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSNumber *value, __unused BOOL *stop) {
                int keyValue = [key intValue];
                if (validUsageKey(keyValue))
                    writeUsageValue(_map, keyValue, [value longLongValue]);
            }];
            if (completion) {
                completion();
            }
        }
    }];
}

- (MTSignal *)currentStatsForKeys:(NSArray *)keys {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        [_queue dispatchOnQueue:^{
            if (_map) {
                NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
                for (NSNumber *key in keys) {
                    int keyValue = [key intValue];
                    if (validUsageKey(keyValue))
                        result[key] = @(readUsageValue(_map, keyValue));
                }
                
                [subscriber putNext:result];
            } else {
                [subscriber putNext:nil];
            }
            [subscriber putCompletion];
        }];
        return nil;
    }];
}

@end
