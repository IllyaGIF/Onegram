#ifndef OGHelperProtocol_h
#define OGHelperProtocol_h

#define OGHelperApplicationBundleIdentifier "dev.IllyaGIF.Onegram"

/* Darwin notifications are used only as lightweight "poke" events that ask the
 * other side to re-read the filesystem. All shared state lives in files inside
 * the application container's Documents/onegram-helper directory, because
 * cross-process notify_set_state is unreliable from inside the app sandbox. */
#define OGHelperApplicationStateNotification "dev.IllyaGIF.Onegram.helper.application"
#define OGHelperAuthInfoChangedNotification "dev.IllyaGIF.Onegram.helper.auth"
#define OGHelperDaemonStateNotification "dev.IllyaGIF.onegramd.state"
#define OGHelperLogSnapshotRequestNotification "dev.IllyaGIF.onegramd.logs.request"
#define OGHelperLogSnapshotFileName "push.log"
#define OGHelperDiagnosticsChangedNotification "dev.IllyaGIF.Onegram.helper.diagnostics"

#define OGHelperAuthInfoDirectoryName "onegram-helper"
#define OGHelperAuthInfoFileName "auth.bin"
#define OGHelperDaemonFlagFileName "daemon.flag"
#define OGHelperAppStateFileName "app.flag"

#define OGHelperSharedDirectoryPath "/var/mobile/Library/Onegram"
#define OGHelperDiagnosticsSettingsPath OGHelperSharedDirectoryPath "/diagnostics.plist"
#define OGHelperDiagnosticsOnegramKey "Onegram"
#define OGHelperDiagnosticsHelperKey "OnegramHelper"

#define OGHelperLogDirectoryPath "/var/mobile/Library/Logs"
#define OGHelperLogPath OGHelperLogDirectoryPath "/onegramd.log"
#define OGHelperRotatedLogPath OGHelperLogDirectoryPath "/onegramd.log.1"
#define OGHelperStandardErrorLogPath OGHelperLogDirectoryPath "/onegramd.stderr.log"
#define OGHelperCrashReporterPath OGHelperLogDirectoryPath "/CrashReporter"

/* The app refreshes daemon-flag freshness against this window; the daemon
 * rewrites its flag well within it. */
#define OGHelperDaemonFlagFreshnessSeconds 180.0

#endif
