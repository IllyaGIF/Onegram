#ifndef OGMediaStore_h
#define OGMediaStore_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OGMediaStoreBlockSize 4096
#define OGMediaStoreSegmentSize (1024 * 1024)

typedef struct OGMediaStore OGMediaStore;

typedef void (*OGMediaStoreTransform)(void *context, void *state, uint8_t *bytes, size_t length);
typedef void (*OGMediaStoreDeliver)(void *context, const uint8_t *bytes, size_t length);

typedef struct {
    int64_t size;
    int64_t origin;
    int64_t memoryWindow;
    bool sequential;
    size_t stateLength;
    const void *initialState;
    void *context;
    OGMediaStoreTransform transform;
    OGMediaStoreDeliver deliver;
} OGMediaStoreConfiguration;

OGMediaStore *OGMediaStoreCreate(const char *path, const OGMediaStoreConfiguration *configuration);
void OGMediaStoreDestroy(OGMediaStore *store);

int64_t OGMediaStoreSize(OGMediaStore *store);
void OGMediaStoreSetSize(OGMediaStore *store, int64_t size);
void OGMediaStoreSetMemoryWindow(OGMediaStore *store, int64_t memoryWindow);
int64_t OGMediaStorePrefix(OGMediaStore *store);
int64_t OGMediaStorePresentBytes(OGMediaStore *store);
bool OGMediaStoreIsComplete(OGMediaStore *store);
bool OGMediaStoreIsSequential(OGMediaStore *store);

bool OGMediaStoreWrite(OGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length);

int64_t OGMediaStoreFirstMissing(OGMediaStore *store, int64_t from, int64_t to);
int64_t OGMediaStoreMissingRunEnd(OGMediaStore *store, int64_t from, int64_t to);
int64_t OGMediaStoreAvailableLength(OGMediaStore *store, int64_t offset);
ssize_t OGMediaStoreRead(OGMediaStore *store, int64_t offset, uint8_t *buffer, size_t length);

bool OGMediaStoreSynchronize(OGMediaStore *store);
bool OGMediaStoreFinish(OGMediaStore *store, int64_t length);

#ifdef __cplusplus
}
#endif

#endif
