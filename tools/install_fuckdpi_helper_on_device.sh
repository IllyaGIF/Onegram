#!/bin/sh
set -eu

if [ "$(id -u)" != "0" ]; then
    echo "Run this script on the jailbroken iPhone as root."
    exit 1
fi

HELPER="${1:-}"
APP_DIR=""
if [ -z "$HELPER" ]; then
    for ROOT in /var/mobile/Applications /var/containers/Bundle/Application; do
        [ -d "$ROOT" ] || continue
        HELPER=$(find "$ROOT" -type f -name FuckDPID -path '*.app/FuckDPID' 2>/dev/null | head -n 1 || true)
        [ -n "$HELPER" ] && break
    done
fi

if [ -z "$HELPER" ] || [ ! -f "$HELPER" ]; then
    echo "FuckDPID was not found inside the app bundle. Build/install Onegram first."
    echo "You may also pass the helper path explicitly: $0 /path/to/FuckDPID"
    exit 1
fi

APP_DIR=$(dirname "$HELPER")
BRIDGE="$APP_DIR/FuckDPIBridgeD"
if [ ! -f "$BRIDGE" ]; then
    echo "FuckDPIBridgeD was not found next to FuckDPID."
    echo "Install the Onegram build containing v27 first."
    exit 1
fi

mkdir -p /usr/libexec /Library/LaunchDaemons

cp "$HELPER" /usr/libexec/fuckdpid
chown root:wheel /usr/libexec/fuckdpid
chmod 4755 /usr/libexec/fuckdpid

cp "$BRIDGE" /usr/libexec/fuckdpibridged
chown root:wheel /usr/libexec/fuckdpibridged
chmod 0755 /usr/libexec/fuckdpibridged

PLIST=/Library/LaunchDaemons/com.onegram.fuckdpi.bridge.plist
cat > "$PLIST" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.onegram.fuckdpi.bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/fuckdpibridged</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>root</string>
    <key>StandardOutPath</key>
    <string>/var/log/fuckdpibridge.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/fuckdpibridge.log</string>
</dict>
</plist>
PLISTEOF
chown root:wheel "$PLIST"
chmod 0644 "$PLIST"

# Reload if an older copy is already active. iOS 5/6 launchctl accepts load/unload.
launchctl unload "$PLIST" >/dev/null 2>&1 || true
killall FuckDPIBridgeD >/dev/null 2>&1 || true
killall fuckdpibridged >/dev/null 2>&1 || true
launchctl load "$PLIST"
sleep 1

echo "Installed:"
ls -l /usr/libexec/fuckdpid /usr/libexec/fuckdpibridged "$PLIST"

echo "Bridge process:"
ps aux | grep '[f]uckdpibridged' || ps aux | grep '[F]uckDPIBridgeD' || true

echo "Bridge log:"
tail -n 5 /var/log/fuckdpibridge.log 2>/dev/null || true

/usr/libexec/fuckdpid status >/dev/null 2>&1 || true

echo "FuckDPI helper + root bridge installed. Reopen Onegram -> Settings -> FuckDPI."
