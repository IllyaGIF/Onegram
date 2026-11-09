#import "OGUpdateArchive.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>

enum {
    OGUpdateArchiveEndRecordSize = 22,
    OGUpdateArchiveCentralRecordSize = 46,
    OGUpdateArchiveLocalRecordSize = 30,
    OGUpdateArchiveMaximumComment = 65535,
    OGUpdateArchiveMaximumEntries = 20000,
    OGUpdateArchiveMaximumCentralDirectory = 8 * 1024 * 1024,
    OGUpdateArchiveChunkSize = 64 * 1024
};

static const uint32_t OGUpdateArchiveEndSignature = 0x06054b50;
static const uint32_t OGUpdateArchiveCentralSignature = 0x02014b50;
static const uint32_t OGUpdateArchiveLocalSignature = 0x04034b50;
static const uint64_t OGUpdateArchiveMaximumEntrySize = 512ULL * 1024ULL * 1024ULL;
static const uint64_t OGUpdateArchiveMaximumTotalSize = 1024ULL * 1024ULL * 1024ULL;
static const uint64_t OGUpdateArchiveSpaceReserve = 16ULL * 1024ULL * 1024ULL;

typedef struct {
    uint16_t method;
    uint32_t crc;
    uint64_t compressedSize;
    uint64_t uncompressedSize;
    uint64_t localHeaderOffset;
    bool directory;
    bool executable;
} OGUpdateArchiveEntryInfo;

@interface OGUpdateArchiveEntry : NSObject
{
@public
    OGUpdateArchiveEntryInfo _info;
}

@property (nonatomic, strong) NSString *relativePath;

@end

@implementation OGUpdateArchiveEntry

@end

static uint16_t OGUpdateArchiveRead16(const uint8_t *bytes)
{
    return (uint16_t)(bytes[0] | ((uint16_t)bytes[1] << 8));
}

static uint32_t OGUpdateArchiveRead32(const uint8_t *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static bool OGUpdateArchiveReadAt(int fd, void *buffer, size_t length, uint64_t offset)
{
    uint8_t *cursor = buffer;
    while (length > 0)
    {
        ssize_t result = pread(fd, cursor, length, (off_t)offset);
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0)
            return false;
        cursor += result;
        length -= (size_t)result;
        offset += (uint64_t)result;
    }
    return true;
}

static bool OGUpdateArchiveWriteAll(int fd, const uint8_t *bytes, size_t length)
{
    while (length > 0)
    {
        ssize_t result = write(fd, bytes, length);
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0)
            return false;
        bytes += result;
        length -= (size_t)result;
    }
    return true;
}

static OGUpdateArchiveStatus OGUpdateArchiveStatusForErrno(int error)
{
    if (error == EACCES || error == EPERM || error == EROFS)
        return OGUpdateArchiveStatusNotWritable;
    if (error == ENOSPC || error == EDQUOT)
        return OGUpdateArchiveStatusNoSpace;
    return OGUpdateArchiveStatusIO;
}

static OGUpdateArchiveStatus OGUpdateArchiveCreateDirectories(NSString *root, NSString *relativePath)
{
    NSString *current = root;
    for (NSString *component in [relativePath componentsSeparatedByString:@"/"])
    {
        struct stat info;
        if (component.length == 0)
            continue;
        current = [current stringByAppendingPathComponent:component];
        const char *representation = [current fileSystemRepresentation];
        if (lstat(representation, &info) == 0)
        {
            if (S_ISDIR(info.st_mode))
                continue;
            if (unlink(representation) != 0)
                return OGUpdateArchiveStatusForErrno(errno);
        }
        if (mkdir(representation, 0755) != 0 && errno != EEXIST)
            return OGUpdateArchiveStatusForErrno(errno);
    }
    return OGUpdateArchiveStatusOK;
}

static bool OGUpdateArchiveComponentIsSafe(NSString *component)
{
    if (component.length == 0 || [component isEqualToString:@"."] || [component isEqualToString:@".."])
        return false;
    return [component rangeOfString:@"\\"].location == NSNotFound;
}

static NSString *OGUpdateArchiveSafeRelativePath(NSString *path)
{
    if (path.length == 0 || [path hasPrefix:@"/"])
        return nil;
    NSArray *components = [path componentsSeparatedByString:@"/"];
    for (NSString *component in components)
    {
        if (!OGUpdateArchiveComponentIsSafe(component))
            return nil;
    }
    return [components componentsJoinedByString:@"/"];
}

@implementation OGUpdateArchive

+ (void)removeItemAtPath:(NSString *)path
{
    if (path.length == 0)
        return;
    [[[NSFileManager alloc] init] removeItemAtPath:path error:NULL];
}

+ (OGUpdateArchiveStatus)prepareDirectoryAtPath:(NSString *)path
{
    struct stat info;
    if (lstat([path fileSystemRepresentation], &info) == 0)
        [self removeItemAtPath:path];
    if (mkdir([path fileSystemRepresentation], 0755) != 0)
        return OGUpdateArchiveStatusForErrno(errno);
    return OGUpdateArchiveStatusOK;
}

+ (OGUpdateArchiveStatus)readEntries:(NSMutableArray *)entries fromDescriptor:(int)fd archiveSize:(uint64_t)archiveSize centralDirectoryOffset:(uint64_t *)centralDirectoryOffset
{
    size_t tailLength = (size_t)MIN(archiveSize, (uint64_t)(OGUpdateArchiveEndRecordSize + OGUpdateArchiveMaximumComment));
    uint64_t tailOffset = archiveSize - tailLength;
    NSMutableData *tail = [[NSMutableData alloc] initWithLength:tailLength];
    const uint8_t *end = NULL;
    uint64_t endOffset = 0;

    if (tailLength < OGUpdateArchiveEndRecordSize || !OGUpdateArchiveReadAt(fd, tail.mutableBytes, tailLength, tailOffset))
        return OGUpdateArchiveStatusFormat;

    const uint8_t *tailBytes = tail.bytes;
    for (size_t index = tailLength - OGUpdateArchiveEndRecordSize + 1; index-- > 0;)
    {
        if (OGUpdateArchiveRead32(tailBytes + index) != OGUpdateArchiveEndSignature)
            continue;
        if (index + OGUpdateArchiveEndRecordSize + OGUpdateArchiveRead16(tailBytes + index + 20) != tailLength)
            continue;
        end = tailBytes + index;
        endOffset = tailOffset + index;
        break;
    }
    if (end == NULL)
        return OGUpdateArchiveStatusFormat;

    uint16_t diskNumber = OGUpdateArchiveRead16(end + 4);
    uint16_t directoryDisk = OGUpdateArchiveRead16(end + 6);
    uint16_t entriesOnDisk = OGUpdateArchiveRead16(end + 8);
    uint16_t entryCount = OGUpdateArchiveRead16(end + 10);
    uint32_t directorySize = OGUpdateArchiveRead32(end + 12);
    uint32_t directoryOffset = OGUpdateArchiveRead32(end + 16);

    if (entryCount == 0xffff || directorySize == 0xffffffff || directoryOffset == 0xffffffff)
        return OGUpdateArchiveStatusUnsupported;
    if (diskNumber != 0 || directoryDisk != 0 || entriesOnDisk != entryCount)
        return OGUpdateArchiveStatusUnsupported;
    if (entryCount > OGUpdateArchiveMaximumEntries || directorySize > OGUpdateArchiveMaximumCentralDirectory)
        return OGUpdateArchiveStatusLimit;
    if ((uint64_t)directoryOffset + directorySize > endOffset)
        return OGUpdateArchiveStatusFormat;

    NSMutableData *directory = [[NSMutableData alloc] initWithLength:directorySize];
    if (directorySize != 0 && !OGUpdateArchiveReadAt(fd, directory.mutableBytes, directorySize, directoryOffset))
        return OGUpdateArchiveStatusIO;

    const uint8_t *cursor = directory.bytes;
    const uint8_t *limit = cursor + directorySize;
    NSString *applicationName = nil;
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    uint64_t totalSize = 0;

    for (uint16_t index = 0; index < entryCount; index++)
    {
        if ((size_t)(limit - cursor) < OGUpdateArchiveCentralRecordSize || OGUpdateArchiveRead32(cursor) != OGUpdateArchiveCentralSignature)
            return OGUpdateArchiveStatusFormat;

        uint16_t madeBy = OGUpdateArchiveRead16(cursor + 4);
        uint16_t flags = OGUpdateArchiveRead16(cursor + 8);
        uint16_t method = OGUpdateArchiveRead16(cursor + 10);
        uint32_t crc = OGUpdateArchiveRead32(cursor + 16);
        uint32_t compressedSize = OGUpdateArchiveRead32(cursor + 20);
        uint32_t uncompressedSize = OGUpdateArchiveRead32(cursor + 24);
        uint16_t nameLength = OGUpdateArchiveRead16(cursor + 28);
        uint16_t extraLength = OGUpdateArchiveRead16(cursor + 30);
        uint16_t commentLength = OGUpdateArchiveRead16(cursor + 32);
        uint32_t externalAttributes = OGUpdateArchiveRead32(cursor + 38);
        uint32_t localHeaderOffset = OGUpdateArchiveRead32(cursor + 42);
        size_t recordLength = OGUpdateArchiveCentralRecordSize + (size_t)nameLength + extraLength + commentLength;

        if ((size_t)(limit - cursor) < recordLength)
            return OGUpdateArchiveStatusFormat;
        if (compressedSize == 0xffffffff || uncompressedSize == 0xffffffff || localHeaderOffset == 0xffffffff)
            return OGUpdateArchiveStatusUnsupported;
        if ((flags & 0x0041) != 0 || (method != 0 && method != 8))
            return OGUpdateArchiveStatusUnsupported;
        if (memchr(cursor + OGUpdateArchiveCentralRecordSize, 0, nameLength) != NULL)
            return OGUpdateArchiveStatusUnsafeEntry;

        NSString *name = [[NSString alloc] initWithBytes:cursor + OGUpdateArchiveCentralRecordSize length:nameLength encoding:NSUTF8StringEncoding];
        cursor += recordLength;
        if (name == nil)
            return OGUpdateArchiveStatusUnsafeEntry;
        if (![name hasPrefix:@"Payload/"])
            continue;

        NSString *payloadPath = [name substringFromIndex:@"Payload/".length];
        bool directoryEntry = [payloadPath hasSuffix:@"/"];
        if (directoryEntry)
            payloadPath = [payloadPath substringToIndex:payloadPath.length - 1];
        if (payloadPath.length == 0)
            continue;

        NSRange separator = [payloadPath rangeOfString:@"/"];
        NSString *bundleName = separator.location == NSNotFound ? payloadPath : [payloadPath substringToIndex:separator.location];
        if (!OGUpdateArchiveComponentIsSafe(bundleName) || ![[bundleName pathExtension] isEqualToString:@"app"])
            return OGUpdateArchiveStatusUnsafeEntry;
        if (applicationName == nil)
            applicationName = bundleName;
        else if (![applicationName isEqualToString:bundleName])
            return OGUpdateArchiveStatusUnsafeEntry;
        if (separator.location == NSNotFound)
            continue;

        NSString *relativePath = OGUpdateArchiveSafeRelativePath([payloadPath substringFromIndex:separator.location + 1]);
        if (relativePath == nil)
            return OGUpdateArchiveStatusUnsafeEntry;
        if ([knownPaths containsObject:relativePath])
            return OGUpdateArchiveStatusFormat;
        [knownPaths addObject:relativePath];

        uint32_t mode = (madeBy >> 8) == 3 ? (externalAttributes >> 16) : 0;
        if (S_ISLNK(mode))
            return OGUpdateArchiveStatusUnsupported;
        if (S_ISDIR(mode))
            directoryEntry = true;
        if (!directoryEntry && (method == 0 && compressedSize != uncompressedSize))
            return OGUpdateArchiveStatusFormat;
        if (uncompressedSize > OGUpdateArchiveMaximumEntrySize)
            return OGUpdateArchiveStatusLimit;
        totalSize += uncompressedSize;
        if (totalSize > OGUpdateArchiveMaximumTotalSize)
            return OGUpdateArchiveStatusLimit;

        OGUpdateArchiveEntry *entry = [[OGUpdateArchiveEntry alloc] init];
        entry.relativePath = relativePath;
        entry->_info.method = method;
        entry->_info.crc = crc;
        entry->_info.compressedSize = compressedSize;
        entry->_info.uncompressedSize = uncompressedSize;
        entry->_info.localHeaderOffset = localHeaderOffset;
        entry->_info.directory = directoryEntry;
        entry->_info.executable = (mode & 0111) != 0;
        [entries addObject:entry];
    }

    if (applicationName == nil || entries.count == 0)
        return OGUpdateArchiveStatusFormat;

    *centralDirectoryOffset = directoryOffset;
    return OGUpdateArchiveStatusOK;
}

+ (OGUpdateArchiveStatus)extractEntry:(OGUpdateArchiveEntry *)entry fromDescriptor:(int)fd centralDirectoryOffset:(uint64_t)centralDirectoryOffset intoDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t written))progress
{
    uint8_t localHeader[OGUpdateArchiveLocalRecordSize];
    const OGUpdateArchiveEntryInfo *info = &entry->_info;

    if (!OGUpdateArchiveReadAt(fd, localHeader, sizeof(localHeader), info->localHeaderOffset) || OGUpdateArchiveRead32(localHeader) != OGUpdateArchiveLocalSignature)
        return OGUpdateArchiveStatusFormat;

    uint64_t dataOffset = info->localHeaderOffset + OGUpdateArchiveLocalRecordSize + OGUpdateArchiveRead16(localHeader + 26) + OGUpdateArchiveRead16(localHeader + 28);
    if (dataOffset + info->compressedSize > centralDirectoryOffset)
        return OGUpdateArchiveStatusFormat;

    OGUpdateArchiveStatus status = OGUpdateArchiveCreateDirectories(directory, [entry.relativePath stringByDeletingLastPathComponent]);
    if (status != OGUpdateArchiveStatusOK)
        return status;

    NSString *path = [directory stringByAppendingPathComponent:entry.relativePath];
    int output = open([path fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, info->executable ? 0755 : 0644);
    if (output < 0)
        return OGUpdateArchiveStatusForErrno(errno);

    NSMutableData *inputBuffer = [[NSMutableData alloc] initWithLength:OGUpdateArchiveChunkSize];
    NSMutableData *outputBuffer = [[NSMutableData alloc] initWithLength:OGUpdateArchiveChunkSize];
    uint8_t *input = inputBuffer.mutableBytes;
    uint8_t *outputBytes = outputBuffer.mutableBytes;
    uint64_t remaining = info->compressedSize;
    uint64_t produced = 0;
    uLong crc = crc32(0L, Z_NULL, 0);
    z_stream stream;
    bool inflating = info->method == 8;
    bool streamEnded = !inflating || (info->compressedSize == 0 && info->uncompressedSize == 0);

    memset(&stream, 0, sizeof(stream));
    if (inflating && inflateInit2(&stream, -MAX_WBITS) != Z_OK)
    {
        close(output);
        return OGUpdateArchiveStatusIO;
    }

    status = OGUpdateArchiveStatusOK;
    while (status == OGUpdateArchiveStatusOK && remaining > 0)
    {
        if (isCancelled != nil && isCancelled())
        {
            status = OGUpdateArchiveStatusCancelled;
            break;
        }

        size_t chunk = (size_t)MIN(remaining, (uint64_t)OGUpdateArchiveChunkSize);
        if (!OGUpdateArchiveReadAt(fd, input, chunk, dataOffset + (info->compressedSize - remaining)))
        {
            status = OGUpdateArchiveStatusIO;
            break;
        }
        remaining -= chunk;

        if (!inflating)
        {
            crc = crc32(crc, input, (uInt)chunk);
            produced += chunk;
            if (!OGUpdateArchiveWriteAll(output, input, chunk))
                status = OGUpdateArchiveStatusForErrno(errno);
            else if (progress != nil)
                progress(chunk);
            continue;
        }

        stream.next_in = input;
        stream.avail_in = (uInt)chunk;
        while (status == OGUpdateArchiveStatusOK && stream.avail_in > 0 && !streamEnded)
        {
            stream.next_out = outputBytes;
            stream.avail_out = OGUpdateArchiveChunkSize;
            int result = inflate(&stream, Z_NO_FLUSH);
            if (result != Z_OK && result != Z_STREAM_END)
            {
                status = OGUpdateArchiveStatusFormat;
                break;
            }
            size_t length = OGUpdateArchiveChunkSize - stream.avail_out;
            produced += length;
            if (produced > info->uncompressedSize)
            {
                status = OGUpdateArchiveStatusFormat;
                break;
            }
            crc = crc32(crc, outputBytes, (uInt)length);
            if (!OGUpdateArchiveWriteAll(output, outputBytes, length))
            {
                status = OGUpdateArchiveStatusForErrno(errno);
                break;
            }
            if (progress != nil && length != 0)
                progress(length);
            if (result == Z_STREAM_END)
                streamEnded = true;
        }
    }

    if (inflating)
        inflateEnd(&stream);
    if (close(output) != 0 && status == OGUpdateArchiveStatusOK)
        status = OGUpdateArchiveStatusForErrno(errno);

    if (status == OGUpdateArchiveStatusOK && (!streamEnded || produced != info->uncompressedSize))
        status = OGUpdateArchiveStatusFormat;
    if (status == OGUpdateArchiveStatusOK && (uint32_t)crc != info->crc)
        status = OGUpdateArchiveStatusChecksum;
    return status;
}

+ (OGUpdateArchiveStatus)extractApplicationFromArchiveAtPath:(NSString *)archivePath toDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t, uint64_t))progress
{
    int fd = open([archivePath fileSystemRepresentation], O_RDONLY);
    if (fd < 0)
        return OGUpdateArchiveStatusIO;

    struct stat archiveInfo;
    if (fstat(fd, &archiveInfo) != 0 || !S_ISREG(archiveInfo.st_mode))
    {
        close(fd);
        return OGUpdateArchiveStatusIO;
    }

    NSMutableArray *entries = [[NSMutableArray alloc] init];
    uint64_t centralDirectoryOffset = 0;
    OGUpdateArchiveStatus status = [self readEntries:entries fromDescriptor:fd archiveSize:(uint64_t)archiveInfo.st_size centralDirectoryOffset:&centralDirectoryOffset];

    uint64_t total = 0;
    for (OGUpdateArchiveEntry *entry in entries)
        total += entry->_info.uncompressedSize;

    if (status == OGUpdateArchiveStatusOK)
    {
        struct statfs volume;
        if (statfs([directory fileSystemRepresentation], &volume) == 0 && (uint64_t)volume.f_bavail * (uint64_t)volume.f_bsize < total + OGUpdateArchiveSpaceReserve)
            status = OGUpdateArchiveStatusNoSpace;
    }

    __block uint64_t completed = 0;
    void (^written)(uint64_t) = ^(uint64_t length)
    {
        completed += length;
        if (progress != nil)
            progress(completed, total);
    };

    for (OGUpdateArchiveEntry *entry in entries)
    {
        if (status != OGUpdateArchiveStatusOK)
            break;
        if (entry->_info.directory)
            status = OGUpdateArchiveCreateDirectories(directory, entry.relativePath);
        else
            status = [self extractEntry:entry fromDescriptor:fd centralDirectoryOffset:centralDirectoryOffset intoDirectory:directory isCancelled:isCancelled progress:written];
    }

    close(fd);
    if (status == OGUpdateArchiveStatusOK)
        sync();
    return status;
}

+ (void)collectFilesAtPath:(NSString *)root relativePath:(NSString *)relativePath skipping:(NSString *)skippedName files:(NSMutableArray *)files directories:(NSMutableArray *)directories
{
    NSString *path = relativePath.length == 0 ? root : [root stringByAppendingPathComponent:relativePath];
    NSArray *names = [[[NSFileManager alloc] init] contentsOfDirectoryAtPath:path error:NULL];
    for (NSString *name in names)
    {
        if (relativePath.length == 0 && skippedName != nil && [name isEqualToString:skippedName])
            continue;
        NSString *childRelativePath = relativePath.length == 0 ? name : [relativePath stringByAppendingPathComponent:name];
        struct stat info;
        if (lstat([[root stringByAppendingPathComponent:childRelativePath] fileSystemRepresentation], &info) != 0)
            continue;
        if (S_ISDIR(info.st_mode))
        {
            [directories addObject:childRelativePath];
            [self collectFilesAtPath:root relativePath:childRelativePath skipping:skippedName files:files directories:directories];
        }
        else
            [files addObject:childRelativePath];
    }
}

+ (OGUpdateArchiveStatus)replaceBundleAtPath:(NSString *)bundlePath withStagedBundleAtPath:(NSString *)stagedPath executableName:(NSString *)executableName progress:(void (^)(uint64_t, uint64_t))progress
{
    NSString *skippedName = [[stagedPath stringByDeletingLastPathComponent] isEqualToString:bundlePath] ? [stagedPath lastPathComponent] : nil;
    NSMutableArray *stagedFiles = [[NSMutableArray alloc] init];
    NSMutableArray *stagedDirectories = [[NSMutableArray alloc] init];
    [self collectFilesAtPath:stagedPath relativePath:@"" skipping:nil files:stagedFiles directories:stagedDirectories];
    if (![stagedFiles containsObject:executableName] || ![stagedFiles containsObject:@"Info.plist"])
        return OGUpdateArchiveStatusFormat;

    [stagedFiles removeObject:@"Info.plist"];
    [stagedFiles removeObject:executableName];
    [stagedFiles addObject:@"Info.plist"];
    [stagedFiles addObject:executableName];

    uint64_t total = stagedFiles.count;
    uint64_t completed = 0;
    for (NSString *relativePath in stagedFiles)
    {
        NSString *destination = [bundlePath stringByAppendingPathComponent:relativePath];
        OGUpdateArchiveStatus status = OGUpdateArchiveCreateDirectories(bundlePath, [relativePath stringByDeletingLastPathComponent]);
        if (status != OGUpdateArchiveStatusOK)
            return status;

        struct stat info;
        if (lstat([destination fileSystemRepresentation], &info) == 0 && S_ISDIR(info.st_mode))
            [self removeItemAtPath:destination];

        if (rename([[stagedPath stringByAppendingPathComponent:relativePath] fileSystemRepresentation], [destination fileSystemRepresentation]) != 0)
            return OGUpdateArchiveStatusForErrno(errno);

        completed++;
        if (progress != nil)
            progress(completed, total);
    }

    NSSet *newFiles = [[NSSet alloc] initWithArray:stagedFiles];
    NSSet *newDirectories = [[NSSet alloc] initWithArray:stagedDirectories];
    NSMutableArray *currentFiles = [[NSMutableArray alloc] init];
    NSMutableArray *currentDirectories = [[NSMutableArray alloc] init];
    [self collectFilesAtPath:bundlePath relativePath:@"" skipping:skippedName files:currentFiles directories:currentDirectories];

    for (NSString *relativePath in currentFiles)
    {
        if (![newFiles containsObject:relativePath])
            unlink([[bundlePath stringByAppendingPathComponent:relativePath] fileSystemRepresentation]);
    }
    for (NSString *relativePath in [currentDirectories reverseObjectEnumerator])
    {
        if (![newDirectories containsObject:relativePath])
            [self removeItemAtPath:[bundlePath stringByAppendingPathComponent:relativePath]];
    }

    [self removeItemAtPath:stagedPath];
    sync();
    return OGUpdateArchiveStatusOK;
}

@end
