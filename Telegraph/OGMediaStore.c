#include "OGMediaStore.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define OGMediaStoreIndexMagic 0x534d474fu
#define OGMediaStoreIndexHeaderLength 40
#define OGMediaStoreSegmentCacheSize 4
#define OGMediaStoreCopyChunk (64 * 1024)

typedef struct {
    int64_t offset;
    size_t length;
    uint8_t *bytes;
} OGMediaStorePart;

typedef struct {
    int64_t index;
    int fd;
    uint32_t stamp;
} OGMediaStoreSegment;

struct OGMediaStore {
    pthread_mutex_t lock;
    char *path;
    char *indexPath;
    int fd;
    bool transient;
    bool sequential;
    bool indexDirty;
    bool hasSegments;
    bool failed;
    bool finished;
    int64_t size;
    int64_t prefix;
    int64_t origin;
    int64_t memoryWindow;
    int64_t pendingBytes;
    int64_t farBytes;
    uint8_t *bitmap;
    size_t bitmapLength;
    OGMediaStorePart *parts;
    size_t partCount;
    size_t partCapacity;
    OGMediaStoreSegment segments[OGMediaStoreSegmentCacheSize];
    uint32_t segmentStamp;
    uint8_t *scratch;
    uint8_t *state;
    size_t stateLength;
    void *context;
    OGMediaStoreTransform transform;
    OGMediaStoreDeliver deliver;
};

static inline int64_t OGMediaStoreAlignDown(int64_t value)
{
    return value - value % OGMediaStoreBlockSize;
}

static inline int64_t OGMediaStoreMin(int64_t a, int64_t b)
{
    return a < b ? a : b;
}

static inline int64_t OGMediaStoreMax(int64_t a, int64_t b)
{
    return a > b ? a : b;
}

static inline int64_t OGMediaStoreBlockCount(int64_t length)
{
    return length / OGMediaStoreBlockSize + (length % OGMediaStoreBlockSize != 0 ? 1 : 0);
}

static inline int64_t OGMediaStoreBlockOffset(int64_t block, int64_t endBlock, int64_t limit)
{
    if (block >= endBlock)
        return limit;
    return OGMediaStoreMin(block * OGMediaStoreBlockSize, limit);
}

static inline int64_t OGMediaStoreBlockLength(const OGMediaStore *store, int64_t block)
{
    int64_t start = block * OGMediaStoreBlockSize;
    if (store->size > 0)
        return OGMediaStoreMin(OGMediaStoreBlockSize, store->size - start);
    return OGMediaStoreBlockSize;
}

static bool OGMediaStoreEnsureBitmap(OGMediaStore *store, int64_t blockCount)
{
    size_t length = (size_t)((blockCount + 7) / 8);
    if (length <= store->bitmapLength)
        return true;
    size_t capacity = store->bitmapLength == 0 ? 64 : store->bitmapLength;
    while (capacity < length)
        capacity *= 2;
    uint8_t *bitmap = (uint8_t *)realloc(store->bitmap, capacity);
    if (bitmap == NULL)
        return false;
    memset(bitmap + store->bitmapLength, 0, capacity - store->bitmapLength);
    store->bitmap = bitmap;
    store->bitmapLength = capacity;
    return true;
}

static inline bool OGMediaStoreBit(const OGMediaStore *store, int64_t block)
{
    size_t byte = (size_t)(block >> 3);
    if (byte >= store->bitmapLength)
        return false;
    return (store->bitmap[byte] & (uint8_t)(1u << (block & 7))) != 0;
}

static void OGMediaStoreSetBits(OGMediaStore *store, int64_t startBlock, int64_t endBlock, bool value)
{
    if (endBlock <= startBlock)
        return;
    if (value && !OGMediaStoreEnsureBitmap(store, endBlock))
    {
        store->failed = true;
        return;
    }
    int64_t limit = (int64_t)store->bitmapLength * 8;
    if (endBlock > limit)
        endBlock = limit;
    int64_t block = startBlock;
    while (block < endBlock && (block & 7) != 0)
    {
        if (value)
            store->bitmap[block >> 3] |= (uint8_t)(1u << (block & 7));
        else
            store->bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
        block++;
    }
    if (endBlock - block >= 8)
    {
        int64_t bytes = (endBlock - block) >> 3;
        memset(store->bitmap + (block >> 3), value ? 0xff : 0x00, (size_t)bytes);
        block += bytes << 3;
    }
    while (block < endBlock)
    {
        if (value)
            store->bitmap[block >> 3] |= (uint8_t)(1u << (block & 7));
        else
            store->bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
        block++;
    }
}

static int64_t OGMediaStoreScan(const OGMediaStore *store, int64_t block, int64_t endBlock, bool value)
{
    uint8_t skip = value ? 0x00 : 0xff;
    int64_t limit = (int64_t)store->bitmapLength * 8;
    while (block < endBlock)
    {
        if (block >= limit)
            return value ? endBlock : block;
        if ((block & 7) == 0 && endBlock - block >= 8 && store->bitmap[block >> 3] == skip)
        {
            block += 8;
            continue;
        }
        if (OGMediaStoreBit(store, block) == value)
            return block;
        block++;
    }
    return endBlock;
}

static int64_t OGMediaStoreEndBlock(const OGMediaStore *store)
{
    if (store->size > 0)
        return OGMediaStoreBlockCount(store->size);
    return (int64_t)store->bitmapLength * 8;
}

static char *OGMediaStoreSegmentPath(const OGMediaStore *store, int64_t index)
{
    size_t length = strlen(store->path) + 24;
    char *path = (char *)malloc(length);
    if (path != NULL)
        snprintf(path, length, "%s.%lld", store->path, (long long)index);
    return path;
}

static void OGMediaStoreCloseSegment(OGMediaStore *store, int64_t index)
{
    for (int i = 0; i < OGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0 && store->segments[i].index == index)
        {
            close(store->segments[i].fd);
            store->segments[i].fd = -1;
        }
    }
}

static void OGMediaStoreRemoveSegment(OGMediaStore *store, int64_t index)
{
    OGMediaStoreCloseSegment(store, index);
    char *path = OGMediaStoreSegmentPath(store, index);
    if (path != NULL)
    {
        unlink(path);
        free(path);
    }
}

static int OGMediaStoreSegmentDescriptor(OGMediaStore *store, int64_t index, bool create)
{
    store->segmentStamp++;
    int victim = 0;
    for (int i = 0; i < OGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0 && store->segments[i].index == index)
        {
            store->segments[i].stamp = store->segmentStamp;
            return store->segments[i].fd;
        }
        if (store->segments[i].fd < 0)
            victim = i;
        else if (store->segments[victim].fd >= 0 && store->segments[i].stamp < store->segments[victim].stamp)
            victim = i;
    }
    char *path = OGMediaStoreSegmentPath(store, index);
    if (path == NULL)
        return -1;
    int fd = open(path, create ? (O_RDWR | O_CREAT) : O_RDWR, S_IRUSR | S_IWUSR);
    free(path);
    if (fd < 0)
        return -1;
    if (store->segments[victim].fd >= 0)
        close(store->segments[victim].fd);
    store->segments[victim].fd = fd;
    store->segments[victim].index = index;
    store->segments[victim].stamp = store->segmentStamp;
    return fd;
}

static bool OGMediaStoreWriteAll(int fd, const uint8_t *bytes, size_t length, int64_t offset)
{
    while (length != 0)
    {
        ssize_t result = pwrite(fd, bytes, length, (off_t)offset);
        if (result < 0)
        {
            if (errno == EINTR)
                continue;
            return false;
        }
        if (result == 0)
            return false;
        bytes += result;
        length -= (size_t)result;
        offset += result;
    }
    return true;
}

static bool OGMediaStoreReadAll(int fd, uint8_t *bytes, size_t length, int64_t offset)
{
    while (length != 0)
    {
        ssize_t result = pread(fd, bytes, length, (off_t)offset);
        if (result < 0)
        {
            if (errno == EINTR)
                continue;
            return false;
        }
        if (result == 0)
            return false;
        bytes += result;
        length -= (size_t)result;
        offset += result;
    }
    return true;
}

static bool OGMediaStoreSegmentIO(OGMediaStore *store, int64_t offset, uint8_t *bytes, size_t length, bool write)
{
    while (length != 0)
    {
        int64_t index = offset / OGMediaStoreSegmentSize;
        int64_t within = offset % OGMediaStoreSegmentSize;
        size_t chunk = (size_t)OGMediaStoreMin((int64_t)length, OGMediaStoreSegmentSize - within);
        int fd = OGMediaStoreSegmentDescriptor(store, index, write);
        if (fd < 0)
            return false;
        bool result = write ? OGMediaStoreWriteAll(fd, bytes, chunk, within) : OGMediaStoreReadAll(fd, bytes, chunk, within);
        if (!result)
            return false;
        offset += (int64_t)chunk;
        bytes += chunk;
        length -= chunk;
    }
    return true;
}

static inline void OGMediaStorePutUInt32(uint8_t *bytes, uint32_t value)
{
    bytes[0] = (uint8_t)value;
    bytes[1] = (uint8_t)(value >> 8);
    bytes[2] = (uint8_t)(value >> 16);
    bytes[3] = (uint8_t)(value >> 24);
}

static inline uint32_t OGMediaStoreGetUInt32(const uint8_t *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static inline void OGMediaStorePutInt64(uint8_t *bytes, int64_t value)
{
    OGMediaStorePutUInt32(bytes, (uint32_t)((uint64_t)value & 0xffffffffu));
    OGMediaStorePutUInt32(bytes + 4, (uint32_t)((uint64_t)value >> 32));
}

static inline int64_t OGMediaStoreGetInt64(const uint8_t *bytes)
{
    return (int64_t)((uint64_t)OGMediaStoreGetUInt32(bytes) | ((uint64_t)OGMediaStoreGetUInt32(bytes + 4) << 32));
}

static uint32_t OGMediaStoreChecksum(const uint8_t *bytes, size_t length)
{
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < length; i++)
    {
        if (i >= 32 && i < 36)
            continue;
        hash ^= bytes[i];
        hash *= 16777619u;
    }
    return hash;
}

static bool OGMediaStoreWriteIndex(OGMediaStore *store)
{
    size_t bitmapBytes = 0;
    if (store->size > 0 && store->farBytes > 0)
        bitmapBytes = (size_t)((OGMediaStoreBlockCount(store->size) + 7) / 8);
    size_t length = OGMediaStoreIndexHeaderLength + store->stateLength + bitmapBytes;
    uint8_t *buffer = (uint8_t *)calloc(1, length);
    if (buffer == NULL)
        return false;
    OGMediaStorePutUInt32(buffer, OGMediaStoreIndexMagic);
    OGMediaStorePutUInt32(buffer + 4, OGMediaStoreBlockSize);
    OGMediaStorePutInt64(buffer + 8, store->size);
    OGMediaStorePutInt64(buffer + 16, store->prefix);
    OGMediaStorePutUInt32(buffer + 24, (uint32_t)store->stateLength);
    OGMediaStorePutUInt32(buffer + 28, (uint32_t)bitmapBytes);
    OGMediaStorePutUInt32(buffer + 36, OGMediaStoreSegmentSize);
    if (store->stateLength != 0)
        memcpy(buffer + OGMediaStoreIndexHeaderLength, store->state, store->stateLength);
    if (bitmapBytes != 0)
    {
        uint8_t *bitmap = buffer + OGMediaStoreIndexHeaderLength + store->stateLength;
        size_t available = bitmapBytes < store->bitmapLength ? bitmapBytes : store->bitmapLength;
        memcpy(bitmap, store->bitmap, available);
        for (size_t i = 0; i < store->partCount; i++)
        {
            int64_t endBlock = OGMediaStoreBlockCount(store->parts[i].offset + (int64_t)store->parts[i].length);
            for (int64_t block = store->parts[i].offset / OGMediaStoreBlockSize; block < endBlock; block++)
            {
                if ((size_t)(block >> 3) < bitmapBytes)
                    bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
            }
        }
    }
    OGMediaStorePutUInt32(buffer + 32, OGMediaStoreChecksum(buffer, length));
    int fd = open(store->indexPath, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR);
    bool result = fd >= 0 && OGMediaStoreWriteAll(fd, buffer, length, 0) && ftruncate(fd, (off_t)length) == 0;
    if (fd >= 0)
        close(fd);
    free(buffer);
    if (result)
        store->indexDirty = false;
    return result;
}

typedef struct {
    bool valid;
    int64_t size;
    int64_t prefix;
    uint8_t *payload;
    size_t bitmapBytes;
} OGMediaStoreIndex;

static OGMediaStoreIndex OGMediaStoreReadIndex(OGMediaStore *store)
{
    OGMediaStoreIndex index;
    memset(&index, 0, sizeof(index));
    int fd = open(store->indexPath, O_RDONLY);
    if (fd < 0)
        return index;
    struct stat value;
    if (fstat(fd, &value) != 0 || value.st_size < OGMediaStoreIndexHeaderLength || value.st_size > 16 * 1024 * 1024)
    {
        close(fd);
        return index;
    }
    size_t length = (size_t)value.st_size;
    uint8_t *buffer = (uint8_t *)malloc(length);
    bool read = buffer != NULL && OGMediaStoreReadAll(fd, buffer, length, 0);
    close(fd);
    if (!read)
    {
        free(buffer);
        return index;
    }
    uint32_t stateLength = OGMediaStoreGetUInt32(buffer + 24);
    uint32_t bitmapBytes = OGMediaStoreGetUInt32(buffer + 28);
    bool valid = OGMediaStoreGetUInt32(buffer) == OGMediaStoreIndexMagic &&
        OGMediaStoreGetUInt32(buffer + 4) == OGMediaStoreBlockSize &&
        OGMediaStoreGetUInt32(buffer + 36) == OGMediaStoreSegmentSize &&
        stateLength == store->stateLength &&
        (size_t)OGMediaStoreIndexHeaderLength + stateLength + bitmapBytes == length &&
        OGMediaStoreGetUInt32(buffer + 32) == OGMediaStoreChecksum(buffer, length);
    if (!valid)
    {
        free(buffer);
        return index;
    }
    index.valid = true;
    index.size = OGMediaStoreGetInt64(buffer + 8);
    index.prefix = OGMediaStoreGetInt64(buffer + 16);
    index.bitmapBytes = bitmapBytes;
    index.payload = buffer;
    return index;
}

static void OGMediaStoreRemoveAllSegments(OGMediaStore *store)
{
    if (!store->hasSegments || store->size <= 0)
        return;
    int64_t count = (store->size + OGMediaStoreSegmentSize - 1) / OGMediaStoreSegmentSize;
    for (int64_t i = 0; i < count; i++)
        OGMediaStoreRemoveSegment(store, i);
    store->hasSegments = false;
}

static void OGMediaStoreCommitPrefix(OGMediaStore *store, uint8_t *bytes, size_t length, bool owned)
{
    uint8_t *buffer = bytes;
    bool allocated = false;
    if (store->transform != NULL)
    {
        if (!owned)
        {
            buffer = (uint8_t *)malloc(length);
            if (buffer == NULL)
            {
                store->failed = true;
                return;
            }
            memcpy(buffer, bytes, length);
            allocated = true;
        }
        store->transform(store->context, store->state, buffer, length);
    }
    int64_t offset = store->prefix;
    if (store->transient)
    {
        int64_t skip = store->origin - offset;
        if (skip < (int64_t)length && store->deliver != NULL)
        {
            size_t start = skip > 0 ? (size_t)skip : 0;
            store->deliver(store->context, buffer + start, length - start);
        }
    }
    else if (!OGMediaStoreWriteAll(store->fd, buffer, length, offset))
    {
        store->failed = true;
    }
    if (allocated)
        free(buffer);
    if (store->failed)
        return;
    OGMediaStoreSetBits(store, offset / OGMediaStoreBlockSize, OGMediaStoreBlockCount(offset + (int64_t)length), true);
    store->prefix = offset + (int64_t)length;
    if (!store->transient && store->stateLength != 0 && !OGMediaStoreWriteIndex(store))
        store->failed = true;
    if (store->hasSegments)
    {
        int64_t first = offset / OGMediaStoreSegmentSize;
        int64_t last = store->prefix / OGMediaStoreSegmentSize;
        for (int64_t index = first; index < last; index++)
            OGMediaStoreRemoveSegment(store, index);
    }
}

static bool OGMediaStoreInsertPart(OGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    if (store->partCount == store->partCapacity)
    {
        size_t capacity = store->partCapacity == 0 ? 8 : store->partCapacity * 2;
        OGMediaStorePart *parts = (OGMediaStorePart *)realloc(store->parts, capacity * sizeof(OGMediaStorePart));
        if (parts == NULL)
            return false;
        store->parts = parts;
        store->partCapacity = capacity;
    }
    uint8_t *copy = (uint8_t *)malloc(length);
    if (copy == NULL)
        return false;
    memcpy(copy, bytes, length);
    size_t position = store->partCount;
    while (position > 0 && store->parts[position - 1].offset > offset)
    {
        store->parts[position] = store->parts[position - 1];
        position--;
    }
    store->parts[position].offset = offset;
    store->parts[position].length = length;
    store->parts[position].bytes = copy;
    store->partCount++;
    store->pendingBytes += (int64_t)length;
    return true;
}

static const OGMediaStorePart *OGMediaStorePartAt(const OGMediaStore *store, int64_t offset)
{
    for (size_t i = 0; i < store->partCount; i++)
    {
        const OGMediaStorePart *part = &store->parts[i];
        if (part->offset > offset)
            break;
        if (offset < part->offset + (int64_t)part->length)
            return part;
    }
    return NULL;
}

static int64_t OGMediaStoreNextPartStart(const OGMediaStore *store, int64_t offset)
{
    for (size_t i = 0; i < store->partCount; i++)
    {
        if (store->parts[i].offset > offset)
            return store->parts[i].offset;
    }
    return INT64_MAX;
}

static int64_t OGMediaStoreSegmentRunEnd(const OGMediaStore *store, int64_t offset)
{
    int64_t endBlock = OGMediaStoreEndBlock(store);
    int64_t segmentEnd = (offset / OGMediaStoreSegmentSize + 1) * OGMediaStoreSegmentSize;
    int64_t end = OGMediaStoreBlockOffset(OGMediaStoreScan(store, offset / OGMediaStoreBlockSize, endBlock, false), endBlock, segmentEnd);
    end = OGMediaStoreMin(end, OGMediaStoreNextPartStart(store, offset));
    if (store->size > 0)
        end = OGMediaStoreMin(end, store->size);
    return end;
}

static void OGMediaStoreDrain(OGMediaStore *store)
{
    while (!store->failed && (store->size <= 0 || store->prefix < store->size))
    {
        if (store->partCount != 0 && store->parts[0].offset == store->prefix)
        {
            OGMediaStorePart part = store->parts[0];
            memmove(store->parts, store->parts + 1, (store->partCount - 1) * sizeof(OGMediaStorePart));
            store->partCount--;
            store->pendingBytes -= (int64_t)part.length;
            OGMediaStoreCommitPrefix(store, part.bytes, part.length, true);
            free(part.bytes);
            continue;
        }
        if (store->transient || !OGMediaStoreBit(store, store->prefix / OGMediaStoreBlockSize))
            break;
        int64_t end = OGMediaStoreSegmentRunEnd(store, store->prefix);
        if (end <= store->prefix)
            break;
        if (store->scratch == NULL)
        {
            store->scratch = (uint8_t *)malloc(OGMediaStoreCopyChunk);
            if (store->scratch == NULL)
            {
                store->failed = true;
                break;
            }
        }
        size_t chunk = (size_t)OGMediaStoreMin(end - store->prefix, OGMediaStoreCopyChunk);
        if (!OGMediaStoreSegmentIO(store, store->prefix, store->scratch, chunk, false))
        {
            int64_t block = store->prefix / OGMediaStoreBlockSize;
            int64_t lost = OGMediaStoreSegmentRunEnd(store, store->prefix);
            int64_t lostBytes = lost - store->prefix;
            OGMediaStoreSetBits(store, block, OGMediaStoreBlockCount(lost), false);
            store->farBytes -= lostBytes;
            store->indexDirty = true;
            break;
        }
        store->farBytes -= (int64_t)chunk;
        store->indexDirty = true;
        OGMediaStoreCommitPrefix(store, store->scratch, chunk, true);
    }
}

static void OGMediaStoreStoreRun(OGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    if (offset == store->prefix)
    {
        OGMediaStoreCommitPrefix(store, (uint8_t *)bytes, length, false);
        return;
    }
    int64_t distance = offset - store->prefix + (int64_t)length;
    bool memory = store->sequential || store->transient || (distance <= store->memoryWindow && store->pendingBytes + (int64_t)length <= store->memoryWindow);
    if (memory)
    {
        if (!OGMediaStoreInsertPart(store, offset, bytes, length))
        {
            store->failed = true;
            return;
        }
    }
    else
    {
        if (!OGMediaStoreSegmentIO(store, offset, (uint8_t *)bytes, length, true))
        {
            store->failed = true;
            return;
        }
        store->hasSegments = true;
        store->farBytes += (int64_t)length;
        store->indexDirty = true;
    }
    OGMediaStoreSetBits(store, offset / OGMediaStoreBlockSize, OGMediaStoreBlockCount(offset + (int64_t)length), true);
}

OGMediaStore *OGMediaStoreCreate(const char *path, const OGMediaStoreConfiguration *configuration)
{
    OGMediaStore *store = (OGMediaStore *)calloc(1, sizeof(OGMediaStore));
    if (store == NULL)
        return NULL;
    pthread_mutex_init(&store->lock, NULL);
    store->fd = -1;
    for (int i = 0; i < OGMediaStoreSegmentCacheSize; i++)
        store->segments[i].fd = -1;
    store->size = configuration->size > 0 ? configuration->size : 0;
    store->origin = configuration->origin > 0 ? configuration->origin : 0;
    store->memoryWindow = configuration->memoryWindow;
    store->sequential = configuration->sequential;
    store->context = configuration->context;
    store->transform = configuration->transform;
    store->deliver = configuration->deliver;
    store->stateLength = configuration->stateLength;
    if (store->stateLength != 0)
    {
        store->state = (uint8_t *)malloc(store->stateLength);
        if (store->state == NULL)
        {
            OGMediaStoreDestroy(store);
            return NULL;
        }
        memcpy(store->state, configuration->initialState, store->stateLength);
    }

    if (path == NULL)
    {
        store->transient = true;
        store->prefix = OGMediaStoreAlignDown(store->origin);
        OGMediaStoreSetBits(store, 0, store->prefix / OGMediaStoreBlockSize, true);
        if (store->failed)
        {
            OGMediaStoreDestroy(store);
            return NULL;
        }
        return store;
    }

    size_t pathLength = strlen(path);
    store->path = strdup(path);
    store->indexPath = (char *)malloc(pathLength + 7);
    if (store->path == NULL || store->indexPath == NULL)
    {
        OGMediaStoreDestroy(store);
        return NULL;
    }
    memcpy(store->indexPath, path, pathLength);
    memcpy(store->indexPath + pathLength, ".index", 7);

    store->fd = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    struct stat value;
    if (store->fd < 0 || fstat(store->fd, &value) != 0)
    {
        OGMediaStoreDestroy(store);
        return NULL;
    }
    int64_t fileLength = (int64_t)value.st_size;
    bool reset = false;

    OGMediaStoreIndex index = OGMediaStoreReadIndex(store);
    if (index.valid && store->size > 0 && index.size > 0 && index.size != store->size)
    {
        int64_t configured = store->size;
        store->size = index.size;
        store->hasSegments = true;
        OGMediaStoreRemoveAllSegments(store);
        store->size = configured;
        free(index.payload);
        memset(&index, 0, sizeof(index));
        reset = true;
    }
    if (index.valid && store->size == 0 && index.size > 0)
        store->size = index.size;

    int64_t prefix = 0;
    if (!reset && store->stateLength != 0)
    {
        if (index.valid && index.prefix <= fileLength && (store->size == 0 || index.prefix <= store->size))
        {
            prefix = index.prefix;
            memcpy(store->state, index.payload + OGMediaStoreIndexHeaderLength, store->stateLength);
        }
    }
    else if (!reset)
    {
        prefix = fileLength;
        if (store->size > 0 && prefix > store->size)
            prefix = 0;
        if (store->size == 0 || prefix != store->size)
            prefix = OGMediaStoreAlignDown(prefix);
    }
    if (prefix != fileLength && ftruncate(store->fd, (off_t)prefix) != 0)
    {
        free(index.payload);
        OGMediaStoreDestroy(store);
        return NULL;
    }
    store->prefix = prefix;

    int64_t prefixBlocks = OGMediaStoreBlockCount(prefix);
    if (store->size > 0)
    {
        int64_t blockCount = OGMediaStoreBlockCount(store->size);
        if (!OGMediaStoreEnsureBitmap(store, blockCount))
        {
            free(index.payload);
            OGMediaStoreDestroy(store);
            return NULL;
        }
        if (index.valid && store->stateLength == 0 && index.bitmapBytes == (size_t)((blockCount + 7) / 8))
        {
            memcpy(store->bitmap, index.payload + OGMediaStoreIndexHeaderLength + store->stateLength, index.bitmapBytes);
            int64_t mergedBlocks = OGMediaStoreBlockCount(index.prefix);
            if (mergedBlocks > prefixBlocks)
                OGMediaStoreSetBits(store, prefixBlocks, mergedBlocks, false);
            for (int64_t block = prefixBlocks; block < blockCount; block++)
            {
                if (OGMediaStoreBit(store, block))
                    store->farBytes += OGMediaStoreBlockLength(store, block);
            }
            store->hasSegments = store->farBytes > 0;
        }
    }
    OGMediaStoreSetBits(store, 0, prefixBlocks, true);
    if (store->stateLength == 0 && store->farBytes == 0)
        store->indexDirty = true;
    free(index.payload);
    if (store->failed)
    {
        OGMediaStoreDestroy(store);
        return NULL;
    }
    OGMediaStoreDrain(store);
    return store;
}

static void OGMediaStoreSpill(OGMediaStore *store)
{
    if (store->transient || store->sequential || store->failed)
        return;
    for (size_t i = 0; i < store->partCount; i++)
    {
        OGMediaStorePart *part = &store->parts[i];
        if (OGMediaStoreSegmentIO(store, part->offset, part->bytes, part->length, true))
        {
            store->hasSegments = true;
            store->farBytes += (int64_t)part->length;
        }
        else
        {
            OGMediaStoreSetBits(store, part->offset / OGMediaStoreBlockSize, OGMediaStoreBlockCount(part->offset + (int64_t)part->length), false);
        }
        store->indexDirty = true;
        free(part->bytes);
    }
    store->partCount = 0;
    store->pendingBytes = 0;
}

void OGMediaStoreDestroy(OGMediaStore *store)
{
    if (store == NULL)
        return;
    if (!store->transient && !store->finished && store->fd >= 0)
    {
        pthread_mutex_lock(&store->lock);
        OGMediaStoreSpill(store);
        pthread_mutex_unlock(&store->lock);
        OGMediaStoreSynchronize(store);
    }
    if (store->fd >= 0)
        close(store->fd);
    for (int i = 0; i < OGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0)
            close(store->segments[i].fd);
    }
    for (size_t i = 0; i < store->partCount; i++)
        free(store->parts[i].bytes);
    free(store->parts);
    free(store->bitmap);
    free(store->scratch);
    free(store->state);
    free(store->path);
    free(store->indexPath);
    pthread_mutex_destroy(&store->lock);
    free(store);
}

int64_t OGMediaStoreSize(OGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t size = store->size;
    pthread_mutex_unlock(&store->lock);
    return size;
}

void OGMediaStoreSetSize(OGMediaStore *store, int64_t size)
{
    pthread_mutex_lock(&store->lock);
    if (size > 0 && (store->size == 0 || size < store->size) && size >= store->prefix)
    {
        store->size = size;
        if (!OGMediaStoreEnsureBitmap(store, OGMediaStoreBlockCount(size)))
            store->failed = true;
        OGMediaStoreDrain(store);
    }
    pthread_mutex_unlock(&store->lock);
}

void OGMediaStoreSetMemoryWindow(OGMediaStore *store, int64_t memoryWindow)
{
    pthread_mutex_lock(&store->lock);
    store->memoryWindow = memoryWindow;
    pthread_mutex_unlock(&store->lock);
}

int64_t OGMediaStorePrefix(OGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t prefix = store->prefix;
    pthread_mutex_unlock(&store->lock);
    return prefix;
}

int64_t OGMediaStorePresentBytes(OGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t bytes = store->prefix + store->pendingBytes + store->farBytes;
    pthread_mutex_unlock(&store->lock);
    return bytes;
}

bool OGMediaStoreIsComplete(OGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    bool complete = store->size > 0 && store->prefix >= store->size;
    pthread_mutex_unlock(&store->lock);
    return complete;
}

bool OGMediaStoreIsSequential(OGMediaStore *store)
{
    return store->sequential;
}

bool OGMediaStoreWrite(OGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    pthread_mutex_lock(&store->lock);
    if (store->failed || store->finished || offset < 0 || offset % OGMediaStoreBlockSize != 0)
    {
        pthread_mutex_unlock(&store->lock);
        return false;
    }
    int64_t end = offset + (int64_t)length;
    if (store->size > 0)
        end = OGMediaStoreMin(end, store->size);
    if (store->size == 0 || end < store->size)
        end = OGMediaStoreAlignDown(end);
    int64_t cursor = OGMediaStoreMax(offset, store->prefix);
    if (cursor < end && !OGMediaStoreEnsureBitmap(store, OGMediaStoreBlockCount(end)))
        store->failed = true;
    while (!store->failed && cursor < end)
    {
        int64_t block = cursor / OGMediaStoreBlockSize;
        int64_t endBlock = OGMediaStoreBlockCount(end);
        if (OGMediaStoreBit(store, block))
        {
            cursor = OGMediaStoreBlockOffset(OGMediaStoreScan(store, block, endBlock, false), endBlock, end);
            continue;
        }
        int64_t runEnd = OGMediaStoreBlockOffset(OGMediaStoreScan(store, block, endBlock, true), endBlock, end);
        OGMediaStoreStoreRun(store, cursor, bytes + (cursor - offset), (size_t)(runEnd - cursor));
        cursor = runEnd;
    }
    if (!store->failed)
        OGMediaStoreDrain(store);
    bool result = !store->failed;
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t OGMediaStoreFirstMissing(OGMediaStore *store, int64_t from, int64_t to)
{
    pthread_mutex_lock(&store->lock);
    int64_t result = -1;
    if (store->size > 0)
        to = OGMediaStoreMin(to, store->size);
    int64_t start = OGMediaStoreMax(OGMediaStoreAlignDown(from), store->prefix);
    if (start < to)
    {
        int64_t endBlock = OGMediaStoreBlockCount(to);
        int64_t block = OGMediaStoreScan(store, start / OGMediaStoreBlockSize, endBlock, false);
        if (block < endBlock && block * OGMediaStoreBlockSize < to)
            result = block * OGMediaStoreBlockSize;
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t OGMediaStoreMissingRunEnd(OGMediaStore *store, int64_t from, int64_t to)
{
    pthread_mutex_lock(&store->lock);
    if (store->size > 0)
        to = OGMediaStoreMin(to, store->size);
    int64_t result = from;
    if (from < to)
    {
        int64_t endBlock = OGMediaStoreBlockCount(to);
        result = OGMediaStoreBlockOffset(OGMediaStoreScan(store, from / OGMediaStoreBlockSize, endBlock, true), endBlock, to);
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t OGMediaStoreAvailableLength(OGMediaStore *store, int64_t offset)
{
    pthread_mutex_lock(&store->lock);
    int64_t result = 0;
    if (offset >= 0 && (store->size == 0 || offset < store->size))
    {
        int64_t start = OGMediaStoreMax(offset, store->prefix);
        int64_t endBlock = OGMediaStoreEndBlock(store);
        int64_t end = OGMediaStoreBlockOffset(OGMediaStoreScan(store, start / OGMediaStoreBlockSize, endBlock, false), endBlock, INT64_MAX);
        if (store->size > 0)
            end = OGMediaStoreMin(end, store->size);
        else if (store->partCount != 0)
        {
            const OGMediaStorePart *last = &store->parts[store->partCount - 1];
            end = OGMediaStoreMin(end, last->offset + (int64_t)last->length);
        }
        else
            end = OGMediaStoreMin(end, store->prefix);
        result = OGMediaStoreMax(0, end - offset);
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

ssize_t OGMediaStoreRead(OGMediaStore *store, int64_t offset, uint8_t *buffer, size_t length)
{
    pthread_mutex_lock(&store->lock);
    ssize_t result = 0;
    if (!store->transient && !store->failed && length != 0 && offset >= 0 && (store->size == 0 || offset < store->size))
    {
        if (offset < store->prefix)
        {
            size_t chunk = (size_t)OGMediaStoreMin((int64_t)length, store->prefix - offset);
            if (store->fd >= 0 && OGMediaStoreReadAll(store->fd, buffer, chunk, offset))
                result = (ssize_t)chunk;
            else
                result = -1;
        }
        else if (OGMediaStoreBit(store, offset / OGMediaStoreBlockSize))
        {
            const OGMediaStorePart *part = OGMediaStorePartAt(store, offset);
            if (part != NULL)
            {
                size_t chunk = (size_t)OGMediaStoreMin((int64_t)length, part->offset + (int64_t)part->length - offset);
                memcpy(buffer, part->bytes + (offset - part->offset), chunk);
                result = (ssize_t)chunk;
            }
            else
            {
                int64_t end = OGMediaStoreSegmentRunEnd(store, offset);
                size_t chunk = (size_t)OGMediaStoreMin((int64_t)length, end - offset);
                if (chunk != 0)
                    result = OGMediaStoreSegmentIO(store, offset, buffer, chunk, false) ? (ssize_t)chunk : -1;
            }
        }
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

bool OGMediaStoreSynchronize(OGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    bool result = !store->failed;
    if (!store->transient && !store->finished)
    {
        if (store->farBytes == 0 && store->stateLength == 0)
        {
            if (store->indexDirty)
            {
                unlink(store->indexPath);
                store->indexDirty = false;
            }
        }
        else if (store->indexDirty)
        {
            result = OGMediaStoreWriteIndex(store) && result;
        }
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

bool OGMediaStoreFinish(OGMediaStore *store, int64_t length)
{
    pthread_mutex_lock(&store->lock);
    bool result = !store->failed && store->size > 0 && store->prefix >= store->size;
    if (result && !store->transient)
    {
        if (length > 0 && length < store->prefix)
            result = ftruncate(store->fd, (off_t)length) == 0;
        close(store->fd);
        store->fd = -1;
        unlink(store->indexPath);
        store->hasSegments = true;
        OGMediaStoreRemoveAllSegments(store);
        for (int i = 0; i < OGMediaStoreSegmentCacheSize; i++)
        {
            if (store->segments[i].fd >= 0)
            {
                close(store->segments[i].fd);
                store->segments[i].fd = -1;
            }
        }
    }
    if (result)
        store->finished = true;
    pthread_mutex_unlock(&store->lock);
    return result;
}
