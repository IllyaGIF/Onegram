#ifndef OGPushHelperProtocol_h
#define OGPushHelperProtocol_h

#define OGPushHelperApplicationBundleIdentifier "dev.IllyaGIF.Onegram"

/* Darwin notifications are used only as lightweight "poke" events that ask the
 * other side to re-read the filesystem. All shared state lives in files inside
 * the application container's Documents/onegram-helper directory, because
 * cross-process notify_set_state is unreliable from inside the app sandbox. */
#define OGPushHelperApplicationStateNotification "dev.IllyaGIF.Onegram.helper.application"
#define OGPushHelperAuthInfoChangedNotification "dev.IllyaGIF.Onegram.helper.auth"
#define OGPushHelperDaemonStateNotification "dev.IllyaGIF.onegramd.state"

#define OGPushHelperAuthInfoDirectoryName "onegram-helper"
#define OGPushHelperAuthInfoFileName "auth.bin"
#define OGPushHelperDaemonFlagFileName "daemon.flag"
#define OGPushHelperAppStateFileName "app.flag"

/* The app refreshes daemon-flag freshness against this window; the daemon
 * rewrites its flag well within it. */
#define OGPushHelperDaemonFlagFreshnessSeconds 180.0

#endif
