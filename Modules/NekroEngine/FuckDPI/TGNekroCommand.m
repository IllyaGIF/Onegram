#import "TGNekroCommand.h"
#import "TGFuckDPILog.h"

#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>

static NSString *const kFuckDPIUnsupportedOSOverrideKey = @"FuckDPIUnsupportedOSOverride_v5";

static const double kFirstUnsupportedOSRelease = 14.0;

#define FDPI_BRIDGE_PORT 49321
#define FDPI_MAGIC 0x46445049u
#define FDPI_VERSION 1u
#define FDPI_FLAG_ALLOW_UNSUPPORTED 1u

static BOOL TGBridgeWriteFull(int fd, const void *buffer, size_t length)
{
    const uint8_t *p = (const uint8_t *)buffer;
    while (length != 0)
    {
        ssize_t n = send(fd, p, length, 0);
        if (n < 0)
        {
            if (errno == EINTR)
                continue;
            return NO;
        }
        p += n;
        length -= (size_t)n;
    }
    return YES;
}

static BOOL TGBridgeReadFull(int fd, void *buffer, size_t length)
{
    uint8_t *p = (uint8_t *)buffer;
    while (length != 0)
    {
        ssize_t n = recv(fd, p, length, 0);
        if (n == 0)
            return NO;
        if (n < 0)
        {
            if (errno == EINTR)
                continue;
            return NO;
        }
        p += n;
        length -= (size_t)n;
    }
    return YES;
}

static int TGBridgeConnect(void)
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0)
        return -1;

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(FDPI_BRIDGE_PORT);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0)
    {
        close(fd);
        return -1;
    }
    return fd;
}

static BOOL TGBridgeIsAvailable(void)
{
    int fd = TGBridgeConnect();
    if (fd < 0)
        return NO;
    close(fd);
    return YES;
}

static int TGRunViaRootBridge(NSArray *arguments, NSString **output)
{
    NSString *command = [arguments count] != 0 ? [arguments objectAtIndex:0] : @"<none>";
    if (![command isEqualToString:@"netcheck"] && ![command isEqualToString:@"status"])
        NSLog(@"[FuckDPI] bridge command=%@", command);

    int fd = TGBridgeConnect();
    if (fd < 0)
    {
        NSLog(@"[FuckDPI] bridge unavailable command=%@ errno=%d", command, errno);
        FDPILog(@"nekro: root bridge is not running (command %@)", command);
        return 124;
    }

    uint32_t header[4];
    header[0] = htonl(FDPI_MAGIC);
    header[1] = htonl(FDPI_VERSION);
    header[2] = htonl([TGNekroCommand unsupportedOSOverrideEnabled] ? FDPI_FLAG_ALLOW_UNSUPPORTED : 0);
    header[3] = htonl((uint32_t)[arguments count]);

    BOOL ok = TGBridgeWriteFull(fd, header, sizeof(header));
    for (NSString *argument in arguments)
    {
        NSData *data = [argument dataUsingEncoding:NSUTF8StringEncoding];
        uint32_t length = (uint32_t)[data length];
        uint32_t wireLength = htonl(length);
        if (!TGBridgeWriteFull(fd, &wireLength, sizeof(wireLength)) ||
            (length != 0 && !TGBridgeWriteFull(fd, [data bytes], length)))
        {
            ok = NO;
            break;
        }
    }

    if (!ok)
    {
        close(fd);
        FDPILog(@"nekro: root bridge write failed for %@", command);
        return 125;
    }

    uint32_t response[3];
    if (!TGBridgeReadFull(fd, response, sizeof(response)) || ntohl(response[0]) != FDPI_MAGIC)
    {
        close(fd);
        FDPILog(@"nekro: root bridge returned an invalid response for %@", command);
        return 126;
    }

    int result = (int)(int32_t)ntohl(response[1]);
    uint32_t outputLength = ntohl(response[2]);
    if (outputLength > 512 * 1024)
    {
        close(fd);
        FDPILog(@"nekro: root bridge output too large for %@", command);
        return 127;
    }

    NSMutableData *collected = nil;
    if (outputLength != 0)
    {
        collected = [NSMutableData dataWithLength:outputLength];
        if (!TGBridgeReadFull(fd, [collected mutableBytes], outputLength))
        {
            close(fd);
            FDPILog(@"nekro: root bridge output truncated for %@", command);
            return 128;
        }
    }
    close(fd);

    NSString *text = collected.length == 0 ? nil
        : [[NSString alloc] initWithData:collected encoding:NSUTF8StringEncoding];

    if (output != NULL)
        *output = text;

    if (output == NULL && text != nil)
    {
        NSString *home = NSHomeDirectory();
        if (home != nil)
        {
            NSString *stderrPath = [home stringByAppendingPathComponent:@"Documents/fuckdpi-engine.err"];
            [text writeToFile:stderrPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        }
    }

    if (result != 0 && ![command isEqualToString:@"netcheck"] && ![command isEqualToString:@"status"])
    {
        NSLog(@"[FuckDPI] helper exit command=%@ code=%d", command, result);
        NSArray *lines = [text componentsSeparatedByString:@"\n"];
        for (NSString *line in lines)
        {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([trimmed length] == 0)
                continue;
            FDPILog(@"nekro: engine said: %@", trimmed);
            break;
        }
    }

    return result;
}

@implementation TGNekroCommand

+ (double)osRelease
{
    static double release = -1.0;
    if (release < 0.0)
    {
        char value[256] = {0};
        size_t size = sizeof(value);
        release = (sysctlbyname("kern.osrelease", value, &size, NULL, 0) == 0) ? atof(value) : 0.0;
    }
    return release;
}

+ (BOOL)isOSSupported
{
    return [self osRelease] < kFirstUnsupportedOSRelease;
}

+ (NSString *)osVersionDescription
{
    char value[256] = {0};
    size_t size = sizeof(value);
    if (sysctlbyname("kern.osrelease", value, &size, NULL, 0) != 0)
        return @"неизвестная версия";
    return [NSString stringWithFormat:@"%@ (Darwin %s)",
            [self isOSSupported] ? @"iOS 5–6" : @"iOS 7 или новее", value];
}

+ (BOOL)unsupportedOSOverrideEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFuckDPIUnsupportedOSOverrideKey];
}

+ (void)setUnsupportedOSOverrideEnabled:(BOOL)enabled
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kFuckDPIUnsupportedOSOverrideKey];
    [defaults synchronize];
    FDPILog(@"nekro: unsupported-OS override %@ (%@)",
            enabled ? @"ENABLED" : @"disabled", [self osVersionDescription]);
}

static BOOL TGFileIsExecutable(NSString *path, struct stat *result)
{
    if ([path length] == 0)
        return NO;

    struct stat st;
    if (stat([path fileSystemRepresentation], &st) != 0)
        return NO;
    if (!S_ISREG(st.st_mode))
        return NO;
    if ((st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) == 0)
        return NO;

    if (result != NULL)
        *result = st;
    return YES;
}

+ (NSString *)enginePath
{
    NSString *installed = @"/usr/libexec/fuckdpid";
    if (TGFileIsExecutable(installed, NULL))
        return installed;

    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"FuckDPID" ofType:nil];
    if (TGFileIsExecutable(bundled, NULL))
        return bundled;

    return @"/usr/bin/nekrowarp";
}

+ (TGNekroAvailability)availability
{
    NSString *path = [self enginePath];
    struct stat st;
    if (!TGFileIsExecutable(path, &st))
        return TGNekroMissing;

    if ((st.st_mode & S_ISUID) == 0 || st.st_uid != 0)
        return TGNekroNotPrivileged;

    if (!TGBridgeIsAvailable())
        return TGNekroBridgeMissing;

    if (![self isOSSupported] && ![self unsupportedOSOverrideEnabled])
        return TGNekroUnsupportedOS;

    return TGNekroReady;
}

+ (BOOL)isAvailable
{
    return [self availability] == TGNekroReady;
}

+ (int)run:(NSArray *)arguments
{
    return [self run:arguments output:NULL];
}

+ (int)run:(NSArray *)arguments output:(NSString **)output
{
    return TGRunViaRootBridge(arguments, output);

    NSString *path = [self enginePath];
    NSString *command = [arguments count] != 0 ? [arguments objectAtIndex:0] : @"<none>";
    if (![command isEqualToString:@"netcheck"] && ![command isEqualToString:@"status"])
        NSLog(@"[FuckDPI] spawn %@ command=%@", path, command);
    NSUInteger count = [arguments count] + 1;
    char **argv = calloc(count + 1, sizeof(char *));
    argv[0] = strdup([path fileSystemRepresentation]);
    for (NSUInteger i = 0; i < [arguments count]; i++)
        argv[i + 1] = strdup([[arguments objectAtIndex:i] UTF8String]);

    NSString *stderrPath = nil;
    if (output == NULL) {
        NSString *home = NSHomeDirectory();
        if (home != nil)
            stderrPath = [home stringByAppendingPathComponent:@"Documents/fuckdpi-engine.err"];
    }

    int pipeFds[2] = { -1, -1 };
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_t *actionsPtr = NULL;
    if (stderrPath != nil) {
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO,
                                         [stderrPath fileSystemRepresentation],
                                         O_WRONLY | O_CREAT | O_TRUNC, 0644);
        actionsPtr = &actions;
    }
    else if (output != NULL && pipe(pipeFds) == 0) {
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, pipeFds[1], STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, pipeFds[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&actions, pipeFds[0]);
        posix_spawn_file_actions_addclose(&actions, pipeFds[1]);
        actionsPtr = &actions;
    }

    char *envp[2] = { NULL, NULL };
    if ([self unsupportedOSOverrideEnabled])
        envp[0] = (char *)"NW_ALLOW_UNSUPPORTED_OS=1";

    pid_t pid = 0;
    int result = posix_spawn(&pid, [path fileSystemRepresentation], actionsPtr, NULL, argv, envp);

    if (actionsPtr != NULL)
        posix_spawn_file_actions_destroy(actionsPtr);

    if (pipeFds[1] >= 0) close(pipeFds[1]);

    NSMutableData *collected = nil;
    if (result == 0 && pipeFds[0] >= 0) {

        collected = [NSMutableData data];
        uint8_t buf[4096];
        ssize_t n;
        while ((n = read(pipeFds[0], buf, sizeof(buf))) > 0)
            [collected appendBytes:buf length:(NSUInteger)n];
    }
    if (pipeFds[0] >= 0) close(pipeFds[0]);

    if (result == 0)
    {
        int status = 0;
        if (waitpid(pid, &status, 0) == pid && WIFEXITED(status))
            result = WEXITSTATUS(status);
        else
            result = -1;
    }
    else
    {
        NSLog(@"[FuckDPI] posix_spawn failed path=%@ command=%@ error=%d errno=%d", path, command, result, errno);
        FDPILog(@"nekro: spawn of %@ failed (%d)", path, result);
    }

    if (result != 0 && ![command isEqualToString:@"netcheck"] && ![command isEqualToString:@"status"])
        NSLog(@"[FuckDPI] helper exit command=%@ code=%d", command, result);

    if (result != 0 && stderrPath != nil)
    {
        NSString *reason = [NSString stringWithContentsOfFile:stderrPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        NSArray *lines = [reason componentsSeparatedByString:@"\n"];
        for (NSString *line in lines)
        {
            if ([[line stringByTrimmingCharactersInSet:
                  [NSCharacterSet whitespaceCharacterSet]] length] == 0)
                continue;
            FDPILog(@"nekro: engine said: %@", line);
            break;
        }
    }

    if (output != NULL)
        *output = collected.length == 0 ? nil
            : [[NSString alloc] initWithData:collected encoding:NSUTF8StringEncoding];

    for (NSUInteger i = 0; i < count; i++)
        free(argv[i]);
    free(argv);
    return result;
}

@end
