// FuckDPIBridgeD
// Root launchd bridge for Onegram. The application itself is sandboxed and
// cannot posix_spawn /usr/libexec/fuckdpid (EPERM), even when the helper is
// root:wheel 4755. This daemon is started by launchd outside the app sandbox,
// listens only on loopback, validates the requested verb, and performs the
// privileged spawn on the app's behalf.

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

#define FDPI_BRIDGE_PORT 49321
#define FDPI_MAGIC 0x46445049u /* FDPI */
#define FDPI_VERSION 1u
#define FDPI_FLAG_ALLOW_UNSUPPORTED 1u
#define FDPI_MAX_ARGS 64u
#define FDPI_MAX_ARG 16384u
#define FDPI_MAX_OUTPUT (512u * 1024u)

static int read_full(int fd, void *buffer, size_t length) {
    unsigned char *p = (unsigned char *)buffer;
    while (length != 0) {
        ssize_t n = recv(fd, p, length, 0);
        if (n == 0) return -1;
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        p += n;
        length -= (size_t)n;
    }
    return 0;
}

static int write_full(int fd, const void *buffer, size_t length) {
    const unsigned char *p = (const unsigned char *)buffer;
    while (length != 0) {
        ssize_t n = send(fd, p, length, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        p += n;
        length -= (size_t)n;
    }
    return 0;
}

static int allowed_command(const char *command) {
    static const char *const allowed[] = {
        "probe", "tun-up", "scope-test", "selftest", "hs-selftest",
        "hs-connect", "hs-listen", "warp-connect", "warp-tunnel",
        "stop", "status", "netcheck", "register", "import-conf",
        "sysctl-int", "resolve", "httpsprobe", "kpatch-probe",
        "kpatch-scopedroute", "sysctlr", "sysctlw", "route-dump",
        "scope-probe", "scope-set", "scope-unset", "bench", NULL
    };
    if (command == NULL || command[0] == '\0') return 0;
    for (int i = 0; allowed[i] != NULL; i++)
        if (strcmp(command, allowed[i]) == 0) return 1;
    return 0;
}

static void append_output(unsigned char **data, size_t *length, size_t *capacity,
                          const unsigned char *src, size_t count) {
    if (*length >= FDPI_MAX_OUTPUT || count == 0) return;
    if (count > FDPI_MAX_OUTPUT - *length) count = FDPI_MAX_OUTPUT - *length;
    size_t need = *length + count;
    if (need > *capacity) {
        size_t cap = *capacity == 0 ? 4096 : *capacity;
        while (cap < need) cap *= 2;
        if (cap > FDPI_MAX_OUTPUT) cap = FDPI_MAX_OUTPUT;
        unsigned char *next = (unsigned char *)realloc(*data, cap);
        if (next == NULL) return;
        *data = next;
        *capacity = cap;
    }
    memcpy(*data + *length, src, count);
    *length += count;
}

static int run_helper(char *const argv[], int allow_unsupported,
                      unsigned char **output, size_t *output_len) {
    int pipes[2] = {-1, -1};
    if (pipe(pipes) != 0) return 120;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipes[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipes[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipes[0]);
    posix_spawn_file_actions_addclose(&actions, pipes[1]);

    if (allow_unsupported)
        setenv("NW_ALLOW_UNSUPPORTED_OS", "1", 1);
    else
        unsetenv("NW_ALLOW_UNSUPPORTED_OS");

    // A privileged network helper must not inherit random MobileSubstrate
    // tweaks from SpringBoard/Telegram. On old jailbreaks those hooks are
    // injected into every executable and can alter socket/TLS behaviour.
    // _MSSafeMode is the standard Substrate opt-out for a child process.
    setenv("_MSSafeMode", "1", 1);
    unsetenv("DYLD_INSERT_LIBRARIES");

    pid_t pid = 0;
    int spawn_result = posix_spawn(&pid, "/usr/libexec/fuckdpid", &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipes[1]);

    unsigned char *collected = NULL;
    size_t collected_len = 0, collected_cap = 0;

    if (spawn_result != 0) {
        char message[256];
        int n = snprintf(message, sizeof(message),
                         "FuckDPIBridgeD: posix_spawn failed: %s (%d)\n",
                         strerror(spawn_result), spawn_result);
        if (n > 0) append_output(&collected, &collected_len, &collected_cap,
                                 (const unsigned char *)message, (size_t)n);
        close(pipes[0]);
        *output = collected;
        *output_len = collected_len;
        return spawn_result;
    }

    // Drain before waitpid so a verbose helper cannot deadlock on a full pipe.
    // warp-tunnel double-forks, then redirects its daemon stdout/stderr to
    // /var/log/nekrowarp.log; therefore this pipe naturally reaches EOF after
    // the detached child has redirected its descriptors.
    unsigned char buffer[4096];
    for (;;) {
        ssize_t n = read(pipes[0], buffer, sizeof(buffer));
        if (n > 0) {
            append_output(&collected, &collected_len, &collected_cap, buffer, (size_t)n);
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        break;
    }
    close(pipes[0]);

    int status = 0;
    int result = 121;
    if (waitpid(pid, &status, 0) == pid) {
        if (WIFEXITED(status)) result = WEXITSTATUS(status);
        else if (WIFSIGNALED(status)) result = 128 + WTERMSIG(status);
    }

    *output = collected;
    *output_len = collected_len;
    return result;
}

static void send_response(int fd, int status, const unsigned char *output, size_t output_len) {
    uint32_t header[3];
    header[0] = htonl(FDPI_MAGIC);
    header[1] = htonl((uint32_t)(int32_t)status);
    header[2] = htonl((uint32_t)output_len);
    if (write_full(fd, header, sizeof(header)) != 0) return;
    if (output_len != 0) write_full(fd, output, output_len);
}

static void handle_client(int fd) {
    uint32_t header[4];
    if (read_full(fd, header, sizeof(header)) != 0) return;

    uint32_t magic = ntohl(header[0]);
    uint32_t version = ntohl(header[1]);
    uint32_t flags = ntohl(header[2]);
    uint32_t argc = ntohl(header[3]);
    if (magic != FDPI_MAGIC || version != FDPI_VERSION || argc == 0 || argc > FDPI_MAX_ARGS) {
        static const unsigned char bad[] = "FuckDPIBridgeD: invalid request\n";
        send_response(fd, 122, bad, sizeof(bad) - 1);
        return;
    }

    // argv[0] is always the system helper path; request args start at argv[1].
    char **argv = (char **)calloc((size_t)argc + 2, sizeof(char *));
    if (argv == NULL) return;
    argv[0] = strdup("/usr/libexec/fuckdpid");

    int valid = 1;
    for (uint32_t i = 0; i < argc; i++) {
        uint32_t wire_len = 0;
        if (read_full(fd, &wire_len, sizeof(wire_len)) != 0) { valid = 0; break; }
        uint32_t len = ntohl(wire_len);
        if (len > FDPI_MAX_ARG) { valid = 0; break; }
        argv[i + 1] = (char *)malloc((size_t)len + 1);
        if (argv[i + 1] == NULL) { valid = 0; break; }
        if (len != 0 && read_full(fd, argv[i + 1], len) != 0) { valid = 0; break; }
        argv[i + 1][len] = '\0';
    }

    if (!valid || !allowed_command(argv[1])) {
        static const unsigned char denied[] = "FuckDPIBridgeD: command denied\n";
        send_response(fd, 123, denied, sizeof(denied) - 1);
    } else {
        unsigned char *output = NULL;
        size_t output_len = 0;
        int result = run_helper(argv, (flags & FDPI_FLAG_ALLOW_UNSUPPORTED) != 0,
                                &output, &output_len);
        send_response(fd, result, output, output_len);
        free(output);
    }

    for (uint32_t i = 0; i < argc + 1; i++) free(argv[i]);
    free(argv);
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);

    int server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) return 1;
    fcntl(server, F_SETFD, FD_CLOEXEC);
    int yes = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(FDPI_BRIDGE_PORT);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(server, (struct sockaddr *)&address, sizeof(address)) != 0) {
        fprintf(stderr, "FuckDPIBridgeD: bind failed: %s\n", strerror(errno));
        close(server);
        return 2;
    }
    if (listen(server, 8) != 0) {
        close(server);
        return 3;
    }

    fprintf(stderr, "FuckDPIBridgeD: ready on 127.0.0.1:%d uid=%d euid=%d\n",
            FDPI_BRIDGE_PORT, (int)getuid(), (int)geteuid());

    for (;;) {
        int client = accept(server, NULL, NULL);
        if (client < 0) {
            if (errno == EINTR) continue;
            sleep(1);
            continue;
        }
        fcntl(client, F_SETFD, FD_CLOEXEC);
        handle_client(client);
        close(client);
    }
    return 0;
}
