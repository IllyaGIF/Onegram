#!/bin/bash

set -e

OS_NAME="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

if [ -d "$SCRIPT_DIR/theos" ] && [ -f "$SCRIPT_DIR/Telegraph/Telegraph-Info.plist" ]; then
    ROOT="$SCRIPT_DIR"
    PROJECT="$SCRIPT_DIR/theos"
elif [ "$(basename "$SCRIPT_DIR")" = "theos" ] && [ -f "$SCRIPT_DIR/../Telegraph/Telegraph-Info.plist" ]; then
    PROJECT="$SCRIPT_DIR"
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
else
    echo
    echo "ERROR: Could not determine Onegram project directory."
    echo
    echo "Place this script either:"
    echo "1) In the Onegram project root"
    echo "2) Inside the Onegram/theos directory"
    exit 1
fi

case "$OS_NAME" in
    Darwin)
        MAKE="make"
        LIPO=""
        JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
        MAC_MEMORY_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)"
        MAC_MEMORY_JOBS=$((MAC_MEMORY_BYTES / 2147483648))
        [ "$MAC_MEMORY_JOBS" -ge 1 ] || MAC_MEMORY_JOBS=1
        [ "$JOBS" -le "$MAC_MEMORY_JOBS" ] || JOBS="$MAC_MEMORY_JOBS"
        ;;
    Linux)
        MAKE="make"

        if [ -x "$HOME/theos/toolchain/linux/iphone/bin/lipo" ]; then
            LIPO="$HOME/theos/toolchain/linux/iphone/bin/lipo"
        else
            LIPO="$(command -v lipo 2>/dev/null || true)"
        fi

        if command -v nproc >/dev/null 2>&1; then
            JOBS="$(nproc)"
        else
            JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
        fi
        ;;
    *)
        echo "Unsupported operating system: $OS_NAME"
        exit 1
        ;;
esac

THEOS="${THEOS:-$HOME/theos}"
export THEOS

BUILD_DIR="$PROJECT/build"
INFO_PLIST="$ROOT/Telegraph/Telegraph-Info.plist"
CONFIG_XCCONFIG="$ROOT/Config.xcconfig"

JOBS="${ONEGRAM_JOBS:-$JOBS}"
if [ "$OS_NAME" = Darwin ]; then
    CORE_JOBS="${CORE_JOBS:-$JOBS}"
else
    CORE_JOBS="${CORE_JOBS:-8}"
fi

BUILD_LOG=""
BUILD_CACHE_LOG=""
SELECTED_BUILD_ARCH=""
LAST_BUILT_IPA=""
SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/onegram/build-mode"
DEVICE_HOST_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/onegram/device-host"
PUSH_TRANSPORT=""
DEVICE_HOST=""
DEVICE_PORT=22
DEVICE_HOST_KEY_ALIAS=""
DEVICE_LABEL=""
DEVICE_PASSWORD=""
PUSH_WORK_DIR=""
IPROXY_PID=""
MENU_SELECTION=0

load_settings() {
    local saved_mode=""

    if [ -f "$SETTINGS_FILE" ]; then
        IFS= read -r saved_mode < "$SETTINGS_FILE" || true
    fi

    case "${ONEGRAM_DIAGNOSTICS:-$saved_mode}" in
        1) ONEGRAM_DIAGNOSTICS=1 ;;
        *) ONEGRAM_DIAGNOSTICS=0 ;;
    esac
}

build_mode_label() {
    if [ "$ONEGRAM_DIAGNOSTICS" -eq 1 ]; then
        echo "Diagnostics"
    else
        echo "Release"
    fi
}

menu_select() {
    local title="$1"
    local selected="$2"
    shift 2
    local options=("$@")
    local count="${#options[@]}"
    local index
    local key
    local prefix
    local choice

    echo
    echo "$title"

    if [ ! -t 0 ] || [ ! -t 1 ] || [ "${TERM:-dumb}" = dumb ]; then
        for ((index = 0; index < count; index++)); do
            printf '%d) %s\n' "$((index + 1))" "${options[index]}"
        done
        while true; do
            printf 'Select [1-%d, 0 to go back]: ' "$count"
            IFS= read -r choice || return 1
            case "$choice" in
                0) return 1 ;;
                ''|*[!0-9]*) continue ;;
            esac
            for ((index = 0; index < count; index++)); do
                if [ "$choice" = "$((index + 1))" ]; then
                    MENU_SELECTION="$index"
                    return 0
                fi
            done
        done
    fi

    while true; do
        for ((index = 0; index < count; index++)); do
            if [ "$index" -eq "$selected" ]; then
                printf '\r\033[2K\033[7m > %s \033[0m\n' "${options[index]}"
            else
                printf '\r\033[2K   %s\n' "${options[index]}"
            fi
        done

        IFS= read -r -s -n 1 key || return 1
        case "$key" in
            ''|$'\r')
                MENU_SELECTION="$selected"
                return 0
                ;;
            $'\033')
                IFS= read -r -s -n 1 -t 1 prefix || return 1
                if [ "$prefix" = '[' ] || [ "$prefix" = O ]; then
                    IFS= read -r -s -n 1 -t 1 key || return 1
                    case "$key" in
                        A) selected=$(((selected + count - 1) % count)) ;;
                        B) selected=$(((selected + 1) % count)) ;;
                    esac
                fi
                ;;
        esac
        printf '\033[%dA' "$count"
    done
}

settings_menu() {
    local selected=0

    while true; do
        menu_select "Settings" "$selected" \
            "Change version ($CURRENT_VERSION, build $CURRENT_BUILD)" \
            "Build mode: $(build_mode_label)" \
            "Back" || return 0
        selected="$MENU_SELECTION"

        case "$MENU_SELECTION" in
            0)
                change_version
                ;;
            1)
                menu_select "Build mode" "$ONEGRAM_DIAGNOSTICS" \
                    "Release" "Diagnostics" || continue
                mkdir -p "$(dirname "$SETTINGS_FILE")"
                printf '%s\n' "$MENU_SELECTION" > "$SETTINGS_FILE"
                ONEGRAM_DIAGNOSTICS="$MENU_SELECTION"
                echo
                echo "Build mode: $(build_mode_label)"
                ;;
            2)
                return 0
                ;;
        esac
    done
}

friendly_device_name() {
    case "$1" in
        iPhone1,1) echo "iPhone" ;;
        iPhone1,2) echo "iPhone 3G" ;;
        iPhone2,1) echo "iPhone 3GS" ;;
        iPhone3,1|iPhone3,2|iPhone3,3) echo "iPhone 4" ;;
        iPhone4,1) echo "iPhone 4s" ;;
        iPhone5,1|iPhone5,2) echo "iPhone 5" ;;
        iPhone5,3|iPhone5,4) echo "iPhone 5c" ;;
        iPhone6,1|iPhone6,2) echo "iPhone 5s" ;;
        iPhone7,2) echo "iPhone 6" ;;
        iPhone7,1) echo "iPhone 6 Plus" ;;
        iPhone8,1) echo "iPhone 6s" ;;
        iPhone8,2) echo "iPhone 6s Plus" ;;
        iPhone8,4) echo "iPhone SE" ;;
        iPhone9,1|iPhone9,3) echo "iPhone 7" ;;
        iPhone9,2|iPhone9,4) echo "iPhone 7 Plus" ;;
        iPhone10,1|iPhone10,4) echo "iPhone 8" ;;
        iPhone10,2|iPhone10,5) echo "iPhone 8 Plus" ;;
        iPhone10,3|iPhone10,6) echo "iPhone X" ;;

        iPad1,1) echo "iPad 1" ;;
        iPad2,1|iPad2,2|iPad2,3|iPad2,4) echo "iPad 2" ;;
        iPad2,5|iPad2,6|iPad2,7) echo "iPad mini" ;;
        iPad3,1|iPad3,2|iPad3,3) echo "iPad 3" ;;
        iPad3,4|iPad3,5|iPad3,6) echo "iPad 4" ;;
        iPad4,1|iPad4,2|iPad4,3) echo "iPad Air" ;;
        iPad4,4|iPad4,5|iPad4,6) echo "iPad mini 2" ;;
        iPad4,7|iPad4,8|iPad4,9) echo "iPad mini 3" ;;
        iPad5,1|iPad5,2) echo "iPad mini 4" ;;
        iPad5,3|iPad5,4) echo "iPad Air 2" ;;

        iPod1,1) echo "iPod touch" ;;
        iPod2,1) echo "iPod touch 2" ;;
        iPod3,1) echo "iPod touch 3" ;;
        iPod4,1) echo "iPod touch 4" ;;
        iPod5,1) echo "iPod touch 5" ;;
        iPod7,1) echo "iPod touch 6" ;;

        *) echo "$1" ;;
    esac
}

file_mtime() {
    python3 - "$1" <<'PY'
import os
import sys

print(int(os.path.getmtime(sys.argv[1])))
PY
}

format_timestamp() {
    python3 - "$1" <<'PY'
import datetime
import sys

timestamp = int(sys.argv[1])
print(datetime.datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d %H:%M:%S"))
PY
}

interrupt_build() {
    echo
    echo "Build interrupted."

    if [ -n "$BUILD_LOG" ] && [ -f "$BUILD_LOG" ]; then
        echo
        echo "Build log:"
        echo "$BUILD_LOG"
    fi

    close_device_connection
    stop_usb_ssh_forward

    exit 130
}

trap interrupt_build INT TERM

show_ccache_stats() {
    if ! command -v ccache >/dev/null 2>&1; then
        return
    fi

    echo
    local stats
    if [ -n "$BUILD_CACHE_LOG" ] && [ -f "$BUILD_CACHE_LOG" ]; then
        echo "ccache (this build):"
        stats="$(ccache --show-log-stats --verbose 2>/dev/null)" || return 0
    else
        echo "ccache (all builds):"
        stats="$(ccache -s)" || return 0
    fi

    printf '%s\n' "$stats" | awk '
        /Cacheable calls:/ && !cacheable {
            print
            cacheable = 1
        }

        /^[[:space:]]*Hits:/ && !hits {
            print
            hits = 1
        }

        /^[[:space:]]*Misses:/ && !misses {
            print
            misses = 1
        }

        /Could not use modules/ || /Compilation failed/ || /Uncacheable calls:/ {
            print
        }

        /^[[:space:]]*Cache size/ && !size {
            print
            size = 1
        }
    '
}

prepare_ccache_stats() {
    BUILD_CACHE_LOG=""
    if command -v ccache >/dev/null 2>&1 && ccache --help 2>/dev/null | grep -q -- '--show-log-stats'; then
        BUILD_CACHE_LOG="$(create_build_log onegram-ccache)" || return 1
        export CCACHE_STATSLOG="$BUILD_CACHE_LOG"
    fi
}

get_ipa_architecture() {
    local ipa="$1"
    python3 - "$ipa" <<'PY'
import struct
import sys
import zipfile

try:
    with zipfile.ZipFile(sys.argv[1]) as archive:
        name = next(name for name in archive.namelist()
                    if name.startswith('Payload/') and '.app/' in name and name.endswith('/Telegram'))
        with archive.open(name) as binary:
            header = binary.read(8)
            magic = header[:4]
            fat = {b'\xca\xfe\xba\xbe': ('>', 20), b'\xbe\xba\xfe\xca': ('<', 20),
                   b'\xca\xfe\xba\xbf': ('>', 32), b'\xbf\xba\xfe\xca': ('<', 32)}
            if magic in fat:
                endian, size = fat[magic]
                count = struct.unpack(endian + 'I', header[4:8])[0]
                if count > 64:
                    raise ValueError('Invalid architecture count')
                table = binary.read(count * size)
                if len(table) != count * size:
                    raise ValueError('Truncated Mach-O header')
                entries = [struct.unpack_from(endian + 'II', table, index * size) for index in range(count)]
            else:
                thin = {b'\xce\xfa\xed\xfe': '<', b'\xcf\xfa\xed\xfe': '<',
                        b'\xfe\xed\xfa\xce': '>', b'\xfe\xed\xfa\xcf': '>'}
                endian = thin[magic]
                entries = [struct.unpack(endian + 'II', header[4:8] + binary.read(4))]
    architectures = set()
    for cpu, subtype in entries:
        subtype &= 0x00ffffff
        if cpu == 12 and subtype == 6:
            architectures.add('armv6')
        elif cpu == 12 and subtype == 9:
            architectures.add('armv7')
        elif cpu == 0x0100000c and subtype in (0, 1):
            architectures.add('arm64')
    labels = {
        frozenset(('armv6', 'armv7', 'arm64')): 'universal3',
        frozenset(('armv7', 'arm64')): 'universal',
        frozenset(('armv6', 'armv7')): 'armv6-armv7',
        frozenset(('armv6', 'arm64')): 'armv6-arm64',
    }
    print(labels.get(frozenset(architectures), next(iter(architectures)) if len(architectures) == 1 else 'unknown'))
except (OSError, ValueError, KeyError, StopIteration, struct.error, zipfile.BadZipFile):
    print('unknown')
PY
}

architecture_label() {
    case "$1" in
        armv6) echo "armv6" ;;
        armv7) echo "armv7" ;;
        arm64) echo "arm64" ;;
        universal) echo "armv7 + arm64" ;;
        universal3) echo "armv7 + arm64 + armv6" ;;
        armv6-armv7) echo "armv6 + armv7" ;;
        armv6-arm64) echo "armv6 + arm64" ;;
        *) echo "unknown" ;;
    esac
}

architecture_matches() {
    local architecture="$1"
    local required="$2"

    case "$required" in
        armv6)
            [ "$architecture" = "armv6" ]
            ;;
        armv7)
            [ "$architecture" = "armv7" ]
            ;;
        universal)
            [ "$architecture" = "universal" ]
            ;;
        universal3)
            [ "$architecture" = "universal3" ]
            ;;
        armv6-compatible)
            [ "$architecture" = "armv6" ] ||
            [ "$architecture" = "armv6-armv7" ] ||
            [ "$architecture" = "armv6-arm64" ] ||
            [ "$architecture" = "universal3" ]
            ;;
        armv7-compatible)
            [ "$architecture" = "armv7" ] ||
            [ "$architecture" = "armv6-armv7" ] ||
            [ "$architecture" = "universal" ] ||
            [ "$architecture" = "universal3" ]
            ;;
        arm64-compatible)
            [ "$architecture" = "arm64" ] ||
            [ "$architecture" = "armv6-arm64" ] ||
            [ "$architecture" = "universal" ] ||
            [ "$architecture" = "universal3" ]
            ;;
        *)
            return 1
            ;;
    esac
}

find_newest_ipa() {
    local required="$1"
    local newest=""
    local newest_time=0
    local ipa
    local architecture
    local mtime

    if [ ! -d "$BUILD_DIR" ]; then
        return
    fi

    while IFS= read -r -d '' ipa; do
        architecture="$(get_ipa_architecture "$ipa")"

        if ! architecture_matches "$architecture" "$required"; then
            continue
        fi

        mtime="$(file_mtime "$ipa" 2>/dev/null || echo 0)"

        if [ "$mtime" -gt "$newest_time" ]; then
            newest_time="$mtime"
            newest="$ipa"
        fi
    done < <(
        find "$BUILD_DIR" \
            -type f \
            -iname '*.ipa' \
            -print0 \
            2>/dev/null
    )

    printf '%s\n' "$newest"
}

verify_ipa() {
    local ipa="$1"
    local expected="$2"
    local architecture

    if [ ! -f "$ipa" ]; then
        echo
        echo "ERROR: IPA not found:"
        echo "$ipa"
        exit 1
    fi

    architecture="$(get_ipa_architecture "$ipa")"

    if ! architecture_matches "$architecture" "$expected"; then
        echo
        echo "ERROR: IPA architecture mismatch."
        echo "Expected: $expected"
        echo "Found:    $(architecture_label "$architecture")"
        echo "$ipa"
        exit 1
    fi

    echo
    echo "IPA verified"
    echo
    echo "Architectures: $(architecture_label "$architecture")"
    echo
    echo "IPA:"
    echo "$ipa"
    python3 - "$ipa" <<'PY'
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    info = plistlib.loads(archive.read("Payload/Telegram.app/Info.plist"))
    print("Build ID:", info.get("OGOnegramBuildIdentifier", "unrecorded"))
    print("Build mode:", "Diagnostics" if info.get("OGOnegramBuildDiagnostics") else "Release")
PY
}

select_build_architecture() {
    menu_select "Select architecture" 0 \
        "armv6" "armv7" "armv7 + arm64 + armv6" || return 1

    case "$MENU_SELECTION" in
        0)
            SELECTED_BUILD_ARCH="armv6"
            ;;
        1)
            SELECTED_BUILD_ARCH="armv7"
            ;;
        2)
            SELECTED_BUILD_ARCH="universal3"
            ;;
    esac
}

stream_build() {
    local log="$1"
    shift
    local interactive=0
    [ -t 1 ] && interactive=1

    "$@" \
        2>&1 |
        tee -a "$log" |
        awk -v interactive="$interactive" '
        /Compiling|Linking|Merging|Signing|Packaging|Stripping|Copying|Bundling|Creating/ {
            count++

            line = $0
            gsub(/\033\[[0-9;]*[A-Za-z]/, "", line)

            if (length(line) > 110) {
                line = substr(line, 1, 107) "..."
            }

            now = systime()
            if (interactive && now != last_update) {
                printf "\r[%d] %-110s", count, line
                fflush()
                last_update = now
            } else if (!interactive && count % 100 == 0) {
                printf "[%d] %s\n", count, line
                fflush()
            }
        }

        /error:|fatal error:|Unavailable:/ {
            if (!seen[$0]++ && errors++ < 8) {
                printf "\n%s\n", $0
                fflush()
            }
        }

        END {
            if (interactive && count) printf "\r[%d] %-110s", count, line
            printf "\n"
        }
        '

    return "${PIPESTATUS[0]}"
}

create_build_log() {
    local directory="${ONEGRAM_LOG_DIR:-${TMPDIR:-/tmp}}"
    mkdir -p "$directory" || return 1
    mktemp "$directory/$1.XXXXXX"
}

ensure_python3() {
    if [ "$OS_NAME" = Darwin ]; then
        macos_bootstrap_python || return 1
        activate_macos_native_tools
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        return 0
    fi

    echo "Python 3 is missing; preparing its installation."
    local command=()
    if [ "$OS_NAME" = Linux ]; then
        if command -v apt-get >/dev/null 2>&1; then
            command=(apt-get install -y python3)
        elif command -v pacman >/dev/null 2>&1; then
            command=(pacman -S --needed --noconfirm python)
        elif command -v dnf >/dev/null 2>&1; then
            command=(dnf install -y python3)
        elif command -v zypper >/dev/null 2>&1; then
            command=(zypper --non-interactive install python3)
        elif command -v apk >/dev/null 2>&1; then
            command=(apk add --no-cache python3)
        elif command -v xbps-install >/dev/null 2>&1; then
            command=(xbps-install -Sy python3)
        elif command -v emerge >/dev/null 2>&1; then
            command=(emerge --noreplace dev-lang/python)
        elif command -v eopkg >/dev/null 2>&1; then
            command=(eopkg install -y python3)
        elif command -v yum >/dev/null 2>&1; then
            command=(yum install -y python3)
        else
            echo "ERROR: No supported package manager found for installing Python 3."
            return 1
        fi
        if [ "$(id -u)" -ne 0 ]; then
            if ! command -v sudo >/dev/null 2>&1; then
                echo "ERROR: sudo is required to install Python 3."
                return 1
            fi
            command=(sudo "${command[@]}")
        fi
    elif command -v brew >/dev/null 2>&1; then
        command=(brew install python3)
    elif command -v port >/dev/null 2>&1; then
        command=(sudo port install python3)
    else
        echo "ERROR: Python 3 requires Homebrew or MacPorts on macOS."
        return 1
    fi
    "${command[@]}" || return 1
    command -v python3 >/dev/null 2>&1
}

prepare_build_environment() {
    local architecture="$1"
    local setup_log
    local setup_result
    local restore_pipefail=0

    if [ "$OS_NAME" = Darwin ]; then
        prepare_macos_native_tools || return 1
    fi

    ensure_python3 || return 1
    setup_log="$(create_build_log onegram-setup)" || return 1
    echo "Preparing build environment"
    if ! [[ -o pipefail ]]; then
        restore_pipefail=1
        set -o pipefail
    fi
    if python3 "$PROJECT/scripts/bootstrap_build.py" --architecture "$architecture" 2>&1 |
        tee "$setup_log" |
        awk '
        /^\[Onegram setup\]/ {
            if (/Missing system packages:/) print "Installing system packages"
            else if (/Theos is missing/) print "Installing Theos"
            else if (/Selecting installed Xcode:/) print "Selecting installed Xcode"
            else if (/replacing it/) print "Updating incompatible iOS toolchain"
            else if (/Linux iOS toolchain is missing/) print "Installing iOS toolchain"
            else if (/Building corrected .* iOS linker/) print "Preparing corrected iOS linker"
            else if (/Installing iPhoneOS/) {
                line = $0
                sub(/^.*Installing /, "Installing ", line)
                sub(/ from .*/, "...", line)
                print line
            }
            else if (/ERROR:/) print
            fflush()
        }
        '; then
        [ "$restore_pipefail" -eq 0 ] || set +o pipefail
        echo "Build environment ready."
    else
        setup_result=$?
        [ "$restore_pipefail" -eq 0 ] || set +o pipefail
        echo "Environment setup failed. Last output:"
        tail -n 15 "$setup_log"
        echo "Full setup log: $setup_log"
        return "$setup_result"
    fi

    if ! command -v "$MAKE" >/dev/null 2>&1; then
        echo "ERROR: GNU Make ($MAKE) is unavailable after bootstrap."
        return 1
    fi

    if [ "$OS_NAME" = Darwin ]; then
        LIPO="$THEOS/toolchain/macos/iphone/bin/lipo"
    else
        if [ -x "$THEOS/toolchain/linux/iphone/bin/lipo" ]; then
            LIPO="$THEOS/toolchain/linux/iphone/bin/lipo"
        else
            LIPO="$(command -v lipo 2>/dev/null || true)"
        fi
    fi
    if [ -z "$LIPO" ] || [ ! -x "$LIPO" ]; then
        echo "ERROR: lipo is unavailable after bootstrap."
        return 1
    fi
}

ensure_api_config() {
    python3 "$PROJECT/scripts/setup_api_config.py" "$ROOT/config.h"
}

run_build() {
    local architecture="$1"
    local result=0
    local start_time
    local end_time
    local elapsed
    local minutes
    local seconds
    LAST_BUILT_IPA=""

    ensure_api_config || return 1

    prepare_build_environment "$architecture" || return 1

    echo
    echo "Building Onegram"
    echo "Project: $ROOT"
    echo "Build mode: $(build_mode_label)"

    case "$architecture" in
        armv6)
            echo "Architectures: armv6"
            echo "armv6 SDK:     iOS 3.1.3"
            echo "armv6 target:  iOS 3.1.3"
            ;;
        armv7)
            echo "Architectures: armv7"
            echo "armv7 SDK:     iOS 6.1"
            echo "armv7 target:  iOS 4.3"
            ;;
        universal3)
            echo "Architectures: armv7 + arm64 + armv6"
            echo "armv6 SDK:     iOS 3.1.3"
            echo "armv6 target:  iOS 3.1.3"
            echo "armv7 SDK:     iOS 6.1"
            echo "armv7 target:  iOS 4.3"
            echo "arm64 SDK:     iOS 11.2"
            echo "arm64 target:  iOS 7.0"
            ;;
    esac

    echo "Parallel jobs: $JOBS"
    echo "Core jobs:     $CORE_JOBS"

    if command -v ccache >/dev/null 2>&1; then
        echo "ccache:        ENABLED"
    else
        echo "ccache:        NOT FOUND"
    fi

    echo

    BUILD_LOG="$(create_build_log onegram-build)" || return 1
    prepare_ccache_stats || return 1
    start_time="$(date +%s)"

    set +e

    case "$architecture" in
        armv6)
            stream_build \
                "$BUILD_LOG" \
                "$MAKE" \
                -j"$JOBS" \
                CORE_JOBS="$CORE_JOBS" \
                ONEGRAM_DIAGNOSTICS="$ONEGRAM_DIAGNOSTICS" \
                ARMV6_JOBS="$JOBS" \
                ONEGRAM_ARCH=armv6 \
                --output-sync=line \
                all

            result=$?
            ;;
        armv7)
            stream_build \
                "$BUILD_LOG" \
                "$MAKE" \
                -j"$JOBS" \
                CORE_JOBS="$CORE_JOBS" \
                ONEGRAM_DIAGNOSTICS="$ONEGRAM_DIAGNOSTICS" \
                ONEGRAM_ARCH=armv7 \
                --output-sync=line

            result=$?
            ;;
        universal3)
            stream_build \
                "$BUILD_LOG" \
                "$MAKE" \
                -j"$JOBS" \
                CORE_JOBS="$CORE_JOBS" \
                ONEGRAM_DIAGNOSTICS="$ONEGRAM_DIAGNOSTICS" \
                ARMV6_JOBS="$JOBS" \
                --output-sync=line \
                universal3

            result=$?
            ;;
    esac

    set -e

    end_time="$(date +%s)"
    elapsed=$((end_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))

    if [ "$result" -ne 0 ]; then
        echo
        echo "BUILD FAILED"
        printf "Build time: %dm %02ds\n" "$minutes" "$seconds"
        echo
        python3 "$PROJECT/scripts/build_diagnostics.py" "$BUILD_LOG" || tail -n 15 "$BUILD_LOG"
        show_ccache_stats

        echo
        echo "Full build log:"
        echo "$BUILD_LOG"

        exit "$result"
    fi

    case "$architecture" in
        armv6)
            LAST_BUILT_IPA="$BUILD_DIR/armv6/Onegram.ipa"
            ;;
        armv7)
            LAST_BUILT_IPA="$BUILD_DIR/Onegram.ipa"
            ;;
        universal3)
            LAST_BUILT_IPA="$BUILD_DIR/universal3/Onegram-armv6-armv7-arm64.ipa"
            ;;
    esac

    if [ -z "$LAST_BUILT_IPA" ]; then
        echo
        echo "ERROR: Built IPA could not be found."
        echo
        echo "Build directory:"
        echo "$BUILD_DIR"
        exit 1
    fi

    verify_ipa "$LAST_BUILT_IPA" "$architecture"

    end_time="$(date +%s)"
    elapsed=$((end_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))

    echo
    echo "Build complete"
    printf "Build time: %dm %02ds\n" "$minutes" "$seconds"
    echo "Architectures: $(architecture_label "$architecture")"

    show_ccache_stats

    if [ -n "$BUILD_CACHE_LOG" ]; then
        rm -f "$BUILD_CACHE_LOG"
        BUILD_CACHE_LOG=""
        unset CCACHE_STATSLOG
    fi
    rm -f "$BUILD_LOG"
    BUILD_LOG=""
}

clean_project() {
    local start_time
    local end_time
    local elapsed

    [ "$OS_NAME" != Darwin ] || activate_macos_native_tools

    echo
    echo "Cleaning Onegram"
    echo

    start_time="$(date +%s)"

    if command -v "$MAKE" >/dev/null 2>&1 && [ -f "$THEOS/makefiles/common.mk" ] && { [ "$OS_NAME" != Darwin ] || [ -x "$THEOS/toolchain/macos/iphone/bin/clang" ]; }; then
        "$MAKE" clean || true
        "$MAKE" ONEGRAM_ARCH=armv6 clean || true
        "$MAKE" ONEGRAM_ARCH=arm64 clean || true
    fi

    rm -rf "$BUILD_DIR/universal3"

    if [ -d "$PROJECT/.theos" ]; then
        echo
        echo "Removing $PROJECT/.theos"
        rm -rf "$PROJECT/.theos"
    fi

    end_time="$(date +%s)"
    elapsed=$((end_time - start_time))

    echo
    echo "Clean complete."
    printf "Clean time: %dm %02ds\n" \
        $((elapsed / 60)) \
        $((elapsed % 60))
}

get_version_info() {
    python3 - "$INFO_PLIST" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    plist = plistlib.load(f)

print(plist.get("CFBundleShortVersionString", "?"))
print(plist.get("CFBundleVersion", "?"))
PY
}

change_version() {
    if [ ! -f "$INFO_PLIST" ]; then
        echo
        echo "ERROR: Info.plist not found:"
        echo "$INFO_PLIST"
        exit 1
    fi

    VERSION_INFO="$(get_version_info)"
    CURRENT_VERSION="$(printf '%s\n' "$VERSION_INFO" | sed -n '1p')"
    CURRENT_BUILD="$(printf '%s\n' "$VERSION_INFO" | sed -n '2p')"

    echo
    echo "Current version: $CURRENT_VERSION"
    echo "Current build:   $CURRENT_BUILD"
    echo

    printf "New version: "
    read -e -r NEW_VERSION || return 0

    if [ -z "$NEW_VERSION" ]; then
        echo
        echo "Version was not changed."
        return
    fi

    case "$NEW_VERSION" in
        *[!0-9.]*|.*|*..*|*.)
            echo
            echo "Invalid version."
            return
            ;;
    esac

    echo
    printf "New build [%s]: " "$CURRENT_BUILD"
    read -e -r NEW_BUILD || return 0

    if [ -z "$NEW_BUILD" ]; then
        NEW_BUILD="$CURRENT_BUILD"
    fi

    case "$NEW_BUILD" in
        *[!0-9.]*|.*|*..*|*.)
            echo
            echo "Invalid build number."
            return
            ;;
    esac

    python3 - "$INFO_PLIST" "$NEW_VERSION" "$NEW_BUILD" <<'PY'
import plistlib
import sys

path = sys.argv[1]
version = sys.argv[2]
build = sys.argv[3]

with open(path, "rb") as f:
    plist = plistlib.load(f)

plist["CFBundleShortVersionString"] = version
plist["CFBundleVersion"] = build

with open(path, "wb") as f:
    plistlib.dump(
        plist,
        f,
        fmt=plistlib.FMT_XML,
        sort_keys=False
    )
PY

    if [ -f "$CONFIG_XCCONFIG" ]; then
        python3 - "$CONFIG_XCCONFIG" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text()

text, count = re.subn(
    r"(?m)^TELEGRAM_APP_VERSION\s*=.*$",
    "TELEGRAM_APP_VERSION = " + version,
    text,
    count=1
)

if count != 1:
    raise SystemExit(
        "TELEGRAM_APP_VERSION not found in Config.xcconfig"
    )

path.write_text(text)
PY
    fi

    echo
    echo "Version changed"
    echo "Version: $NEW_VERSION"
    echo "Build:   $NEW_BUILD"
    CURRENT_VERSION="$NEW_VERSION"
    CURRENT_BUILD="$NEW_BUILD"
}

select_device() {
    local device_ids=()
    local device_options=()

    DEVICES="$(idevice_id -l 2>/dev/null)"

    if [ -z "$DEVICES" ]; then
        echo "No iOS devices found."
        exit 1
    fi

    DEVICE_COUNT="$(printf '%s\n' "$DEVICES" | grep -c .)"

    if [ "$DEVICE_COUNT" -eq 1 ]; then
        UDID="$(printf '%s\n' "$DEVICES" | head -n 1)"
        return
    fi

    while IFS= read -r DEVICE_UDID; do
        [ -z "$DEVICE_UDID" ] && continue

        PRODUCT_TYPE="$(
            ideviceinfo \
                -u "$DEVICE_UDID" \
                -k ProductType \
                2>/dev/null ||
                true
        )"

        IOS_VERSION="$(
            ideviceinfo \
                -u "$DEVICE_UDID" \
                -k ProductVersion \
                2>/dev/null ||
                true
        )"

        if [ -z "$PRODUCT_TYPE" ]; then
            DEVICE_NAME="Unknown device"
            PRODUCT_TYPE="?"
        else
            DEVICE_NAME="$(friendly_device_name "$PRODUCT_TYPE")"
        fi

        [ -z "$IOS_VERSION" ] && IOS_VERSION="?"

        device_ids+=("$DEVICE_UDID")
        device_options+=("$DEVICE_NAME ($PRODUCT_TYPE) - iOS $IOS_VERSION")
    done <<< "$DEVICES"

    menu_select "Connected devices" 0 "${device_options[@]}" || return 1
    UDID="${device_ids[MENU_SELECTION]}"
}

device_requires_armv6() {
    local product_type="$1"

    case "$product_type" in
        iPhone1,1|iPhone1,2|iPod1,1|iPod2,1)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

device_requires_arm64() {
    local product_type="$1"

    case "$product_type" in
        iPhone6,*|iPhone7,*|iPhone8,*|iPhone9,*|iPhone10,*|iPhone11,*|iPhone12,*|iPhone13,*|iPhone14,*|iPhone15,*|iPhone16,*|iPhone17,*)
            return 0
            ;;
        iPad4,*|iPad5,*|iPad6,*|iPad7,*|iPad8,*|iPad9,*|iPad10,*|iPad11,*|iPad12,*|iPad13,*|iPad14,*|iPad15,*|iPad16,*|iPad17,*)
            return 0
            ;;
        iPod7,*|iPod8,*|iPod9,*|iPod10,*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

post_build_install() {
    if [ "${ONEGRAM_SKIP_DEVICE_INSTALL:-0}" = 1 ]; then
        return 0
    fi
    if ! command -v idevice_id >/dev/null 2>&1 ||
       ! command -v ideviceinfo >/dev/null 2>&1 ||
       ! command -v ideviceinstaller >/dev/null 2>&1; then
        echo "IPA is ready: $LAST_BUILT_IPA"
        echo "Device installation tools are not available; installation skipped."
        return 0
    fi

    if [ -z "$(idevice_id -l 2>/dev/null || true)" ]; then
        echo "IPA is ready: $LAST_BUILT_IPA"
        echo "No connected iOS device; installation skipped."
        return 0
    fi

    install_onegram
}

install_onegram() {
    local result
    local required_arch
    local ipa_architecture
    local ipa_time
    local ipa_mtime

    if [ "$OS_NAME" = Darwin ]; then
        prepare_macos_device_tools || return 1
    fi

    if ! command -v idevice_id >/dev/null 2>&1; then
        echo
        echo "ERROR: idevice_id not found."
        exit 1
    fi

    if ! command -v ideviceinfo >/dev/null 2>&1; then
        echo
        echo "ERROR: ideviceinfo not found."
        exit 1
    fi

    if ! command -v ideviceinstaller >/dev/null 2>&1; then
        echo
        echo "ERROR: ideviceinstaller not found."
        exit 1
    fi

    select_device || return 0

    PRODUCT_TYPE="$(
        ideviceinfo \
            -u "$UDID" \
            -k ProductType \
            2>/dev/null ||
            true
    )"

    IOS_VERSION="$(
        ideviceinfo \
            -u "$UDID" \
            -k ProductVersion \
            2>/dev/null ||
            true
    )"

    if [ -z "$PRODUCT_TYPE" ]; then
        DEVICE_NAME="Unknown device"
        PRODUCT_TYPE="?"
    else
        DEVICE_NAME="$(friendly_device_name "$PRODUCT_TYPE")"
    fi

    [ -z "$IOS_VERSION" ] && IOS_VERSION="?"

    if device_requires_armv6 "$PRODUCT_TYPE"; then
        required_arch="armv6-compatible"
        IPA="$(find_newest_ipa armv6-compatible)"
    elif device_requires_arm64 "$PRODUCT_TYPE"; then
        required_arch="arm64-compatible"
        IPA="$(find_newest_ipa arm64-compatible)"
    else
        required_arch="armv7-compatible"
        IPA="$(find_newest_ipa armv7-compatible)"
    fi

    if [ -n "$LAST_BUILT_IPA" ] && [ -f "$LAST_BUILT_IPA" ] &&
       architecture_matches "$(get_ipa_architecture "$LAST_BUILT_IPA")" "$required_arch"; then
        IPA="$LAST_BUILT_IPA"
    fi

    if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
        echo
        echo "ERROR: No compatible IPA found."
        echo
        echo "Device: $DEVICE_NAME ($PRODUCT_TYPE)"
        echo "iOS:    $IOS_VERSION"

        case "$required_arch" in
            armv6-compatible)
                echo "Required: armv6 or armv6 + armv7 + arm64"
                ;;
            arm64-compatible)
                echo "Required: arm64 compatible IPA"
                ;;
            armv7-compatible)
                echo "Required: armv7 compatible IPA"
                ;;
        esac

        echo
        echo "Build directory:"
        echo "$BUILD_DIR"
        exit 1
    fi

    verify_ipa "$IPA" "$required_arch"

    ipa_architecture="$(get_ipa_architecture "$IPA")"
    ipa_mtime="$(file_mtime "$IPA" 2>/dev/null || echo "")"

    if [ -n "$ipa_mtime" ]; then
        ipa_time="$(format_timestamp "$ipa_mtime" 2>/dev/null || true)"
    else
        ipa_time=""
    fi

    echo
    echo "Selected:"
    echo "Device: $DEVICE_NAME ($PRODUCT_TYPE)"
    echo "iOS:    $IOS_VERSION"
    echo "UDID:   $UDID"
    echo
    echo "IPA architecture: $(architecture_label "$ipa_architecture")"

    if [ -n "$ipa_time" ]; then
        echo "IPA modified:     $ipa_time"
    fi

    echo
    echo "Installing:"
    echo "$IPA"
    echo

    set +e

    ideviceinstaller \
        -u "$UDID" \
        install "$IPA"

    result=$?

    set -e

    if [ "$result" -eq 0 ]; then
        echo
        echo "Onegram installed successfully"
        echo "Device: $DEVICE_NAME"
        echo "iOS:    $IOS_VERSION"
        echo "IPA:    $(architecture_label "$ipa_architecture")"
    else
        echo
        echo "ERROR: ideviceinstaller failed."
        exit "$result"
    fi
}

if [ ! -d "$PROJECT" ]; then
    echo
    echo "ERROR: Project directory not found:"
    echo "$PROJECT"
    exit 1
fi

if [ ! -f "$INFO_PLIST" ]; then
    echo
    echo "ERROR: Info.plist not found:"
    echo "$INFO_PLIST"
    exit 1
fi

if [ "$OS_NAME" = Darwin ]; then
    source "$PROJECT/scripts/macos_build.sh"
fi

make_push_deb() {
    local binpath="$1"
    local debarch="$2"
    local out="$3"
    local prefix="$4"
    local firmware="$5"
    local stage="$BUILD_DIR/push/stage"
    local data="$stage/data"
    local daemon_path="$prefix/usr/local/bin/onegramd"
    local plist_path="$prefix/Library/LaunchDaemons/dev.IllyaGIF.onegramd.plist"

    rm -rf "$stage"
    mkdir -p "$stage/DEBIAN" "$data$prefix/usr/local/bin" "$data$prefix/Library/LaunchDaemons"

    cat > "$stage/DEBIAN/control" <<CTL
Package: dev.illyagif.onegramd
Name: Onegram Push Helper
Version: $CURRENT_VERSION
Architecture: $debarch
Description: Instant push helper daemon for Onegram
Maintainer: IllyaGIF
Author: IllyaGIF
Section: Tweaks
Depends: firmware (>= $firmware)
CTL

    cat > "$stage/DEBIAN/postinst" <<PI
#!/bin/sh
launchctl unload $plist_path 2>/dev/null
mkdir -p /var/mobile/Library/Onegram/daemon
chown -R mobile:mobile /var/mobile/Library/Onegram
chmod 700 /var/mobile/Library/Onegram/daemon
for log in /var/mobile/Library/Logs/onegramd.log /var/mobile/Library/Logs/onegramd.log.1 /var/mobile/Library/Logs/onegramd.stderr.log; do
    [ -e "\$log" ] && chown mobile:mobile "\$log"
done
launchctl load $plist_path 2>/dev/null
exit 0
PI

    cat > "$stage/DEBIAN/prerm" <<PR
#!/bin/sh
launchctl unload $plist_path 2>/dev/null
exit 0
PR

    chmod 755 "$stage/DEBIAN/postinst" "$stage/DEBIAN/prerm"
    cp "$binpath" "$data$daemon_path"
    chmod 755 "$data$daemon_path"
    python3 - "$ROOT/OnegramPushHelper/dev.IllyaGIF.onegramd.plist" "$data$plist_path" "$daemon_path" <<'PY' || return 1
import plistlib
import sys

with open(sys.argv[1], "rb") as source:
    launchd = plistlib.load(source)
launchd["Program"] = sys.argv[3]
launchd["ProgramArguments"] = [sys.argv[3]] + list(launchd.get("ProgramArguments", []))[1:]
with open(sys.argv[2], "wb") as target:
    plistlib.dump(launchd, target)
PY
    chmod 644 "$data$plist_path"

    assemble_deb "$stage" "$out"
}

assemble_deb() {
    local stage="$1"
    local out="$2"

    rm -f "$out"
    (
        cd "$stage"
        echo "2.0" > debian-binary
        tar --numeric-owner --group=0 --owner=0 -czf control.tar.gz -C DEBIAN .
        tar --numeric-owner --group=0 --owner=0 -czf data.tar.gz -C data .
        ar rc "$out" debian-binary control.tar.gz data.tar.gz
    )
}

app_binary_suffix() {
    sed -n 's/^#define OGSystemApplicationBinarySuffix "\(.*\)"$/\1/p' "$ROOT/OnegramLauncher/OGSystemApplication.h"
}

build_app_launcher() {
    local binary="$1"
    local out="$2"
    local work="$BUILD_DIR/app-deb/launcher-build"
    local tcbin="$THEOS/toolchain/linux/iphone"
    [ "$OS_NAME" = Darwin ] && tcbin="$THEOS/toolchain/macos/iphone"
    local legacy="$ROOT/theos/generated/toolchains/clang+llvm-3.2-x86_64-linux-ubuntu-12.04/bin/clang"
    local info
    local arch
    local cc
    local sdk
    local ctriple
    local ltriple
    local startfiles
    local slices=()

    info="$("$LIPO" -info "$binary" 2>/dev/null)" || {
        echo "ERROR: Cannot read architectures of $binary"
        return 1
    }

    rm -rf "$work"
    mkdir -p "$work"

    for arch in armv6 armv7 arm64; do
        printf '%s\n' "$info" | grep -qw "$arch" || continue
        startfiles=""
        case "$arch" in
            armv6)
                cc="$legacy"
                sdk="$THEOS/sdks/iPhoneOS3.1.3.sdk"
                ctriple="-target armv6-apple-ios3.1.3 -miphoneos-version-min=3.1.3"
                ltriple="-target armv6-apple-ios3.1.3 -miphoneos-version-min=3.1.3"
                startfiles="-nostartfiles $ROOT/theos/generated/armv6/products/crt1.3.1-armv6.o"
                ;;
            armv7)
                cc="$legacy"
                sdk="$THEOS/sdks/iPhoneOS6.1.sdk"
                ctriple="-target armv7-apple-darwin11 -miphoneos-version-min=4.3"
                ltriple="-target armv7-apple-ios4.3"
                ;;
            arm64)
                cc="$tcbin/bin/clang"
                sdk="$THEOS/sdks/iPhoneOS11.2.sdk"
                ctriple="-target arm64-apple-ios7.0"
                ltriple="-target arm64-apple-ios7.0"
                ;;
        esac

        echo "cc [$arch] launcher"
        LD_LIBRARY_PATH="$tcbin/lib:$LD_LIBRARY_PATH" "$cc" $ctriple -isysroot "$sdk" -std=gnu99 -Os -Wall \
            -c "$ROOT/OnegramLauncher/main.c" -o "$work/launcher.$arch.o" || return 1
        echo "ld [$arch] launcher"
        LD_LIBRARY_PATH="$tcbin/lib:$LD_LIBRARY_PATH" "$tcbin/bin/clang" $ltriple -isysroot "$sdk" $startfiles \
            "$work/launcher.$arch.o" -o "$work/launcher.$arch" || return 1
        slices+=("$work/launcher.$arch")
    done

    if [ "${#slices[@]}" -eq 0 ]; then
        echo "ERROR: $binary contains no supported architecture: $info"
        return 1
    fi

    "$LIPO" -create "${slices[@]}" -output "$out" || return 1
    LD_LIBRARY_PATH="$tcbin/lib:$LD_LIBRARY_PATH" "$tcbin/bin/ldid" -S "$out"
}

uicache_command() {
    local prefix="$1"
    local action="$2"
    local application="$prefix/Applications/Onegram.app"

    if [ -n "$prefix" ]; then
        case "$action" in
            register) echo "$prefix/usr/bin/uicache -p $application" ;;
            unregister) echo "$prefix/usr/bin/uicache -u $application" ;;
        esac
    else
        echo "su mobile -c /usr/bin/uicache 2>/dev/null || /usr/bin/uicache"
    fi
}

make_app_deb() {
    local bundle="$1"
    local executable="$2"
    local launcher="$3"
    local prefix="$4"
    local debarch="$5"
    local firmware="$6"
    local thin="$7"
    local out="$8"
    local stage="$BUILD_DIR/app-deb/stage"
    local data="$stage/data"
    local application="$data$prefix/Applications/Onegram.app"
    local suffix
    local binary

    suffix="$(app_binary_suffix)"
    if [ -z "$suffix" ]; then
        echo "ERROR: Cannot read the launcher binary suffix."
        return 1
    fi

    rm -rf "$stage"
    mkdir -p "$stage/DEBIAN" "$data$prefix/Applications"
    cp -R "$bundle" "$application" || return 1

    binary="$application/$executable$suffix"
    mv "$application/$executable" "$binary" || return 1
    if [ -n "$thin" ]; then
        "$LIPO" "$binary" -thin "$thin" -output "$binary.thin" || return 1
        mv "$binary.thin" "$binary"
        "$LIPO" "$launcher" -thin "$thin" -output "$application/$executable" || return 1
    else
        cp "$launcher" "$application/$executable" || return 1
    fi

    find "$data" -type d -exec chmod 755 {} +
    find "$data" -type f -exec chmod 644 {} +
    chmod 755 "$binary" "$application/$executable"

    cat > "$stage/DEBIAN/control" <<CTL
Package: dev.illyagif.onegram
Name: Onegram
Version: $CURRENT_VERSION-$CURRENT_BUILD
Architecture: $debarch
Description: Telegram client for iOS 3 and newer
Maintainer: IllyaGIF
Author: IllyaGIF
Section: Networking
Depends: firmware (>= $firmware), uikittools
CTL

    cat > "$stage/DEBIAN/postinst" <<PI
#!/bin/sh
$(uicache_command "$prefix" register)
exit 0
PI

    if [ -n "$prefix" ]; then
        cat > "$stage/DEBIAN/prerm" <<PR
#!/bin/sh
case "\$1" in
    remove|purge) $(uicache_command "$prefix" unregister) ;;
esac
exit 0
PR
        chmod 755 "$stage/DEBIAN/prerm"
    else
        cat > "$stage/DEBIAN/postrm" <<PR
#!/bin/sh
case "\$1" in
    remove|purge) $(uicache_command "$prefix" register) ;;
esac
exit 0
PR
        chmod 755 "$stage/DEBIAN/postrm"
    fi
    chmod 755 "$stage/DEBIAN/postinst"

    assemble_deb "$stage" "$out"
}

package_app_tweak() {
    local ipa="$1"
    local pdir="$BUILD_DIR/app-deb"
    local extracted="$pdir/extracted"
    local bundle="$extracted/Payload/Telegram.app"
    local executable
    local firmware
    local slices
    local package="$pdir/onegram_${CURRENT_VERSION}-${CURRENT_BUILD}_iphoneos-arm.deb"
    local rootless_package="$pdir/onegram_${CURRENT_VERSION}-${CURRENT_BUILD}_iphoneos-arm64.deb"

    if [ ! -f "$ipa" ]; then
        echo "ERROR: IPA not found: $ipa"
        return 1
    fi

    echo
    echo "Packaging Onegram tweak from $(basename "$ipa")"

    rm -rf "$extracted"
    mkdir -p "$extracted"
    python3 - "$ipa" "$extracted" <<'PY' || return 1
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall(sys.argv[2])
PY

    read -r executable firmware < <(python3 - "$bundle/Info.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as source:
    info = plistlib.load(source)
print(info["CFBundleExecutable"], info.get("MinimumOSVersion", "3.0"))
PY
)
    if [ -z "$executable" ] || [ ! -f "$bundle/$executable" ]; then
        echo "ERROR: Application executable not found in $ipa"
        return 1
    fi

    slices="$("$LIPO" -info "$bundle/$executable" 2>/dev/null || true)"
    build_app_launcher "$bundle/$executable" "$pdir/Telegram-launcher" || return 1

    rm -f "$pdir"/onegram_*.deb
    make_app_deb "$bundle" "$executable" "$pdir/Telegram-launcher" "" iphoneos-arm "$firmware" "" "$package" || return 1
    if printf '%s\n' "$slices" | grep -qw arm64; then
        make_app_deb "$bundle" "$executable" "$pdir/Telegram-launcher" /var/jb iphoneos-arm64 15.0 arm64 "$rootless_package" || return 1
    fi
    rm -rf "$extracted" "$pdir/stage" "$pdir/launcher-build" "$pdir/Telegram-launcher"

    echo
    echo "Onegram tweak built"
    echo "Architectures: $(architecture_label "$(get_ipa_architecture "$ipa")")"
    echo "DEB rootful:   $package (iOS $firmware+)"
    if [ -f "$rootless_package" ]; then
        echo "DEB rootless:  $rootless_package (iOS 15+, arm64)"
    else
        echo "DEB rootless:  not built, the IPA has no arm64 slice"
    fi
    echo "App data:      /var/mobile/Library/Onegram/Home"
}

build_app_tweak() {
    run_build "$1"
    package_app_tweak "$LAST_BUILT_IPA"
}

push_build_one() {
    local arch="$1"
    local out="$2"
    local tcbin="$THEOS/toolchain/linux/iphone"
    [ "$OS_NAME" = Darwin ] && tcbin="$THEOS/toolchain/macos/iphone"
    export LD_LIBRARY_PATH="$tcbin/lib:$LD_LIBRARY_PATH"
    local LD="$tcbin/bin/clang++"
    local LDID="$tcbin/bin/ldid"
    local legacy="$ROOT/theos/generated/toolchains/clang+llvm-3.2-x86_64-linux-ubuntu-12.04/bin/clang"
    local CC SDK CTRIPLE LTRIPLE PROD SSL ELD FW ARCLITE CRT UNDEF

    case "$arch" in
        arm64)
            CC="$tcbin/bin/clang"
            SDK="$THEOS/sdks/iPhoneOS11.2.sdk"
            CTRIPLE="-target arm64-apple-ios7.0"
            LTRIPLE="-target arm64-apple-ios7.0"
            PROD="$ROOT/theos/generated/arm64/products"
            SSL="$PROD/libssl.a $PROD/libcrypto.a"
            ARCLITE="$ROOT/theos/lib/libarclite_iphoneos.a"
            CRT=""
            ELD=""
            FW="-framework CoreTelephony"
            UNDEF=""
            ;;
        armv7)
            CC="$legacy"
            SDK="$THEOS/sdks/iPhoneOS6.1.sdk"
            CTRIPLE="-target armv7-apple-darwin11 -miphoneos-version-min=4.3"
            LTRIPLE="-target armv7-apple-ios6.0"
            PROD="$ROOT/theos/generated/products"
            SSL="$ROOT/submodules/MtProtoKit/openssl/iOS/libcrypto.a"
            ARCLITE="$ROOT/theos/lib/libarclite_iphoneos.a"
            CRT="$ROOT/theos/lib/libclang_rt.ios.a"
            ELD=""
            FW="-framework CoreTelephony"
            UNDEF="-Wl,-U,_SSL_CTX_ctrl -Wl,-U,_SSL_CTX_free -Wl,-U,_SSL_CTX_get_cert_store -Wl,-U,_SSL_CTX_new -Wl,-U,_SSL_CTX_set_cipher_list -Wl,-U,_SSL_CTX_set_verify -Wl,-U,_SSL_CTX_set_verify_depth -Wl,-U,_SSL_connect -Wl,-U,_SSL_ctrl -Wl,-U,_SSL_free -Wl,-U,_SSL_get0_param -Wl,-U,_SSL_get_error -Wl,-U,_SSL_get_ex_data -Wl,-U,_SSL_get_ex_data_X509_STORE_CTX_idx -Wl,-U,_SSL_get_verify_result -Wl,-U,_SSL_library_init -Wl,-U,_SSL_load_error_strings -Wl,-U,_SSL_new -Wl,-U,_SSL_pending -Wl,-U,_SSL_read -Wl,-U,_SSL_set_bio -Wl,-U,_SSL_set_connect_state -Wl,-U,_SSL_set_ex_data -Wl,-U,_SSL_set_fd -Wl,-U,_SSL_write -Wl,-U,_TLSv1_2_client_method"
            ;;
        armv6)
            CC="$legacy"
            SDK="$THEOS/sdks/iPhoneOS3.1.3.sdk"
            CTRIPLE="-target armv6-apple-ios3.1.3 -miphoneos-version-min=3.1.3"
            LTRIPLE="-target armv6-apple-ios3.1.3 -miphoneos-version-min=3.1.3"
            PROD="$ROOT/theos/generated/armv6/products"
            SSL="$PROD/libssl.a $PROD/libcrypto.a"
            ARCLITE="$PROD/libarclite_iphoneos.a"
            CRT="$PROD/libclang_rt.ios.a"
            UNDEF="-Wl,-U,_objc_storeWeak -Wl,-U,_objc_loadWeak -Wl,-U,_objc_loadWeakRetained -Wl,-U,_objc_initWeak -Wl,-U,_objc_copyWeak -Wl,-U,_objc_destroyWeak"
            ELD="-nostartfiles $PROD/crt1.3.1-armv6.o $PROD/libdispatch.a -L$PROD -Wl,-alias_list,$ROOT/theos/compat/ios3/OnegramBlocksRuntimeAliases.txt -Wl,-unexported_symbols_list,$ROOT/theos/compat/ios3/OnegramRuntimePrivateSymbols.txt"
            FW=""
            ;;
        *)
            echo "ERROR: unsupported push arch $arch"
            return 1
            ;;
    esac

    local lib
    for lib in libMtProtoKit libOnegramPlatform libOnegramRuntime; do
        if [ ! -f "$PROD/$lib.a" ]; then
            echo "ERROR: $PROD/$lib.a missing. Build the $arch app once first."
            return 1
        fi
    done

    local gendir="$ROOT/theos/generated"
    [ "$arch" = armv7 ] || gendir="$ROOT/theos/generated/$arch"
    local libflags
    libflags="$(grep '^libLegacyDatabase_CFLAGS = ' "$gendir/libLegacyDatabase.mk" | sed 's/^libLegacyDatabase_CFLAGS = //' | sed "s#\$(ONEGRAM_ROOT)#$ROOT#g" | sed "s#\$(XCODE_DEVELOPER_FRAMEWORKS_DIR)#$SDK/Developer/Library/Frameworks#g")"
    if [ -z "$libflags" ]; then
        echo "ERROR: $gendir/libLegacyDatabase.mk missing. Build the $arch app once first."
        return 1
    fi

    local od="$BUILD_DIR/push/obj/$arch"
    mkdir -p "$od"

    local tcbin2="$THEOS/toolchain/linux/iphone"
    [ "$OS_NAME" = Darwin ] && tcbin2="$THEOS/toolchain/macos/iphone"
    local MTLIB="$od/libMtProtoKit.a"
    if [ ! "$MTLIB" -nt "$PROD/libMtProtoKit.a" ]; then
        "$tcbin2/bin/lipo" "$PROD/libMtProtoKit.a" -thin "$arch" -output "$MTLIB" 2>/dev/null || cp "$PROD/libMtProtoKit.a" "$MTLIB"
        local pingmember
        pingmember="$("$tcbin2/bin/llvm-ar" t "$MTLIB" 2>/dev/null | grep -E "PingFoundation" | head -1)"
        if [ -n "$pingmember" ]; then
            ( cd "$od" && "$tcbin2/bin/llvm-ar" x "libMtProtoKit.a" "$pingmember" )
            printf '_BN_init
_EVP_MD_CTX_init
_EVP_MD_CTX_cleanup
' > "$od/ping_hide.txt"
            if "$tcbin2/bin/ld" -r -arch "$arch" "$od/$pingmember" -unexported_symbols_list "$od/ping_hide.txt" -o "$od/$pingmember.patched"; then
                mv "$od/$pingmember.patched" "$od/$pingmember"
                "$tcbin2/bin/llvm-ar" r "$MTLIB" "$od/$pingmember"
                echo "patched PingFoundation (localized duplicate openssl symbols)"
            else
                touch -r "$PROD/libMtProtoKit.a" "$MTLIB"
                echo "WARN: PingFoundation patch failed; link may hit duplicate symbols"
            fi
        fi
    fi
    local CF="-fobjc-arc -std=gnu99 -Os $CTRIPLE -isysroot $SDK -DTARGET_OS_IPHONE=1 -I$ROOT -I$ROOT/submodules/MtProtoKit $libflags"

    local launcher=""
    if command -v ccache >/dev/null 2>&1; then
        launcher="ccache"
        local headermaps="" flag
        for flag in $libflags; do
            case "$flag" in
                -I*.hmap) headermaps="${headermaps:+$headermaps:}${flag#-I}" ;;
            esac
        done
        export CCACHE_DIRECT=true
        export CCACHE_DEPEND=true
        export CCACHE_SLOPPINESS=modules
        export CCACHE_EXTRAFILES="$headermaps"
    fi

    local srcs=("$ROOT/OnegramPushHelper/main.m" "$ROOT/OnegramPushHelper/OGPushDaemon.m" "$ROOT/OnegramPushHelper/OGPushDispatchCompat.m" "$ROOT/OnegramPushHelper/OGPushSerialization.m")
    local objs=()
    local pids=()
    local f o pid failed=0
    for f in "${srcs[@]}"; do
        o="$od/$(basename "${f%.m}").o"
        echo "cc [$arch] $(basename "$f")"
        $launcher $CC $CF -MD -MF "$o.d" -c "$f" -o "$o" &
        pids+=("$!")
        objs+=("$o")
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done
    [ "$failed" -eq 0 ] || return 1

    echo "ld [$arch] onegramd"
    LD_LIBRARY_PATH="$tcbin/lib:$LD_LIBRARY_PATH" $LD $LTRIPLE -isysroot "$SDK" -stdlib=libstdc++ \
        "${objs[@]}" \
        -force_load "$MTLIB" \
        "$PROD/libOnegramPlatform.a" \
        "$PROD/libOnegramRuntime.a" \
        $SSL \
        -force_load "$ARCLITE" $CRT \
        -framework Foundation -framework UIKit -framework Security -framework CFNetwork \
        -framework SystemConfiguration -framework CoreGraphics -framework QuartzCore $FW \
        -lz -lresolv -lstdc++ -lsqlite3 -Wl,-multiply_defined,suppress $UNDEF $ELD \
        -o "$out" || return 1

    "$LDID" -S"$ROOT/OnegramPushHelper/onegramd.entitlements" "$out"
}

build_push_tweak() {
    local pdir="$BUILD_DIR/push"
    local tcbin="$THEOS/toolchain/linux/iphone"
    [ "$OS_NAME" = Darwin ] && tcbin="$THEOS/toolchain/macos/iphone"
    local slices
    local slice

    ensure_api_config || return 1
    prepare_build_environment universal3 || return 1
    mkdir -p "$pdir"

    echo
    echo "Building Onegram push helper ($(architecture_label universal3))"
    if command -v ccache >/dev/null 2>&1; then
        echo "ccache:        ENABLED"
    else
        echo "ccache:        NOT FOUND"
    fi
    prepare_ccache_stats || return 1

    push_build_one armv6 "$pdir/onegramd.armv6" || return 1
    push_build_one armv7 "$pdir/onegramd.armv7" || return 1
    push_build_one arm64 "$pdir/onegramd.arm64" || return 1
    "$LIPO" -create "$pdir/onegramd.armv6" "$pdir/onegramd.armv7" "$pdir/onegramd.arm64" -output "$pdir/onegramd" || return 1
    "$tcbin/bin/ldid" -S"$ROOT/OnegramPushHelper/onegramd.entitlements" "$pdir/onegramd"

    slices="$("$LIPO" -info "$pdir/onegramd" 2>/dev/null || true)"
    for slice in armv6 armv7 arm64; do
        if ! printf '%s\n' "$slices" | grep -qw "$slice"; then
            echo "ERROR: Push helper binary is missing the $slice slice: $slices"
            return 1
        fi
    done

    local package="$pdir/onegramd_${CURRENT_VERSION}_iphoneos-arm.deb"
    local rootless_package="$pdir/onegramd_${CURRENT_VERSION}_iphoneos-arm64.deb"
    make_push_deb "$pdir/onegramd" iphoneos-arm "$package" "" 3.0 || return 1
    make_push_deb "$pdir/onegramd.arm64" iphoneos-arm64 "$rootless_package" /var/jb 15.0 || return 1

    echo
    echo "Push helper built"
    echo "Binary:       $pdir/onegramd"
    echo "DEB rootful:  $package"
    echo "DEB rootless: $rootless_package"

    show_ccache_stats
    if [ -n "$BUILD_CACHE_LOG" ]; then
        rm -f "$BUILD_CACHE_LOG"
        BUILD_CACHE_LOG=""
        unset CCACHE_STATSLOG
    fi
}

read_device_host() {
    local saved=""
    local host

    if [ -n "${ONEGRAM_DEVICE_HOST:-}" ]; then
        DEVICE_HOST="$ONEGRAM_DEVICE_HOST"
        return 0
    fi

    if [ -f "$DEVICE_HOST_FILE" ]; then
        IFS= read -r saved < "$DEVICE_HOST_FILE" || true
    fi

    echo
    if [ -n "$saved" ]; then
        printf 'Device IP [%s]: ' "$saved"
    else
        printf 'Device IP: '
    fi
    IFS= read -r host || return 1
    host="${host:-$saved}"
    [ -n "$host" ] || return 1
    DEVICE_HOST="$host"
}

device_ssh() {
    local target_options=(-p "$DEVICE_PORT")
    if [ -n "$DEVICE_HOST_KEY_ALIAS" ]; then
        target_options+=(-o HostKeyAlias="$DEVICE_HOST_KEY_ALIAS")
    fi

    OPENSSL_ENABLE_SHA1_SIGNATURES=1 \
    SSH_ASKPASS="$PUSH_WORK_DIR/askpass" \
    SSH_ASKPASS_REQUIRE=force \
    ONEGRAM_DEVICE_PASSWORD="$DEVICE_PASSWORD" \
    ssh \
        "${target_options[@]}" \
        -o ControlPath="$PUSH_WORK_DIR/control" \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=15 \
        -o StrictHostKeyChecking=accept-new \
        -o KexAlgorithms=+diffie-hellman-group14-sha1 \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o NumberOfPasswordPrompts=1 \
        -o LogLevel=ERROR \
        "$@"
}

open_device_connection() {
    local output

    if output="$(device_ssh -o ControlMaster=yes -o ControlPersist=120 -f -N "root@$DEVICE_HOST" 2>&1)"; then
        return 0
    fi

    if printf '%s\n' "$output" | grep -q 'Permission denied'; then
        return 2
    fi

    printf '%s\n' "$output" >&2
    if printf '%s\n' "$output" | grep -q -e 'Connection refused' -e 'Connection reset by peer' -e 'Connection closed by remote host'; then
        return 3
    fi
    return 1
}

device_run() {
    device_ssh "root@$DEVICE_HOST" "export PATH=/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin; $1"
}

close_device_connection() {
    if [ -n "$PUSH_WORK_DIR" ] && [ -S "$PUSH_WORK_DIR/control" ]; then
        device_ssh -O exit "root@$DEVICE_HOST" >/dev/null 2>&1 || true
    fi
    if [ -n "$PUSH_WORK_DIR" ]; then
        rm -rf "$PUSH_WORK_DIR"
    fi
    PUSH_WORK_DIR=""
}

deb_requires_respring() {
    ar p "$1" data.tar.gz | tar -tzf - | grep -q 'Library/MobileSubstrate/DynamicLibraries/'
}

package_name() {
    case "$1" in
        push) echo "onegramd" ;;
        app) echo "onegram" ;;
    esac
}

package_label() {
    case "$1" in
        push) echo "push helper" ;;
        app) echo "Onegram" ;;
    esac
}

package_directory() {
    case "$1" in
        push) echo "$BUILD_DIR/push" ;;
        app) echo "$BUILD_DIR/app-deb" ;;
    esac
}

deploy_package() {
    local kind="$1"
    local deb
    local deb_time
    local layout
    local dpkg_path
    local status

    if ! command -v ssh >/dev/null 2>&1; then
        echo "ERROR: ssh not found."
        return 1
    fi

    DEVICE_PASSWORD="${ONEGRAM_DEVICE_PASSWORD:-alpine}"

    PUSH_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/onegram-push.XXXXXX")" || return 1
    cat > "$PUSH_WORK_DIR/askpass" <<'ASKPASS'
#!/bin/sh
printf '%s\n' "$ONEGRAM_DEVICE_PASSWORD"
ASKPASS
    chmod 700 "$PUSH_WORK_DIR/askpass"

    echo
    echo "Connecting to $DEVICE_LABEL"

    status=0
    open_device_connection || status=$?
    if [ "$status" -eq 2 ]; then
        printf 'Password for %s: ' "$DEVICE_LABEL"
        IFS= read -r -s DEVICE_PASSWORD || DEVICE_PASSWORD=""
        echo
        status=0
        open_device_connection || status=$?
    fi
    if [ "$status" -ne 0 ]; then
        case "$status" in
            2) echo "ERROR: Authentication failed for $DEVICE_LABEL." ;;
            3) echo "ERROR: No SSH server is listening on port 22 of $DEVICE_LABEL. Install OpenSSH on the device and make sure the jailbreak is active." ;;
            *) echo "ERROR: Could not connect to $DEVICE_LABEL." ;;
        esac
        close_device_connection
        return 1
    fi

    layout="$(device_run 'if [ -x /var/jb/usr/bin/dpkg ]; then echo rootless; elif [ -x /usr/bin/dpkg ]; then echo rootful; fi' 2>/dev/null || true)"
    case "$layout" in
        rootless)
            deb="$(find_newest_deb "$kind" iphoneos-arm64)"
            dpkg_path=/var/jb/usr/bin/dpkg
            ;;
        rootful)
            deb="$(find_newest_deb "$kind" iphoneos-arm)"
            dpkg_path=/usr/bin/dpkg
            ;;
        *)
            echo "ERROR: dpkg not found on $DEVICE_LABEL."
            close_device_connection
            return 1
            ;;
    esac

    if [ -z "$deb" ]; then
        echo "ERROR: No $layout $(package_label "$kind") package found. Build it first."
        close_device_connection
        return 1
    fi

    deb_time="$(format_timestamp "$(file_mtime "$deb")" 2>/dev/null || true)"
    echo "Jailbreak:    $layout"
    echo "DEB:          $(basename "$deb")"
    [ -n "$deb_time" ] && echo "DEB modified: $deb_time"

    echo "Uploading"
    if ! device_ssh "root@$DEVICE_HOST" "cat > /tmp/$(package_name "$kind").deb" < "$deb"; then
        echo "ERROR: Upload failed."
        close_device_connection
        return 1
    fi

    echo "Installing"
    status=0
    device_run "$dpkg_path -i /tmp/$(package_name "$kind").deb; result=\$?; rm -f /tmp/$(package_name "$kind").deb; exit \$result" || status=$?
    if [ "$status" -ne 0 ]; then
        echo "ERROR: Installation failed on device (exit $status)."
        close_device_connection
        return 1
    fi

    if deb_requires_respring "$deb"; then
        echo "Restarting SpringBoard"
        device_run 'sbreload >/dev/null 2>&1 || killall -9 SpringBoard' || true
    fi

    if [ "$kind" = push ]; then
        sleep 2
        if device_run 'launchctl list | grep -q dev.IllyaGIF.onegramd'; then
            echo
            echo "Push helper installed and loaded on $DEVICE_LABEL"
            device_run 'tail -n 3 /var/mobile/Library/Logs/onegramd.log 2>/dev/null' || true
        else
            echo
            echo "WARNING: Package installed, but dev.IllyaGIF.onegramd is not loaded."
        fi
    else
        echo
        echo "Onegram installed on $DEVICE_LABEL"
    fi

    close_device_connection
}

local_port_open() {
    python3 - "$1" <<'PY'
import socket
import sys

connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
connection.settimeout(0.5)
try:
    connection.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    connection.close()
PY
}

find_free_usb_port() {
    local port="${ONEGRAM_USB_SSH_PORT:-2222}"
    local last=$((port + 50))

    while [ "$port" -le "$last" ]; do
        if ! local_port_open "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
        port=$((port + 1))
    done
    return 1
}

stop_usb_ssh_forward() {
    if [ -n "$IPROXY_PID" ]; then
        kill "$IPROXY_PID" 2>/dev/null || true
        wait "$IPROXY_PID" 2>/dev/null || true
    fi
    IPROXY_PID=""
}

start_usb_ssh_forward() {
    local port
    local attempt

    if [ "$OS_NAME" = Darwin ]; then
        prepare_macos_device_tools || return 1
    fi

    if ! command -v iproxy >/dev/null 2>&1 || ! command -v idevice_id >/dev/null 2>&1; then
        echo "ERROR: iproxy and idevice_id are required for USB installation (libusbmuxd, libimobiledevice)."
        return 1
    fi

    if [ -z "$(idevice_id -l 2>/dev/null || true)" ]; then
        echo "ERROR: No iOS device connected over USB."
        return 1
    fi

    select_device || return 1

    if ! port="$(find_free_usb_port)"; then
        echo "ERROR: No free local port for the USB SSH forward."
        return 1
    fi

    if iproxy --help 2>&1 | grep -q -- '--udid'; then
        iproxy -u "$UDID" "$port" 22 >/dev/null 2>&1 &
    else
        iproxy "$port" 22 "$UDID" >/dev/null 2>&1 &
    fi
    IPROXY_PID=$!

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if local_port_open "$port"; then
            DEVICE_HOST=127.0.0.1
            DEVICE_PORT="$port"
            DEVICE_HOST_KEY_ALIAS="onegram-usb-$UDID"
            DEVICE_LABEL="USB device $UDID (127.0.0.1:$port)"
            return 0
        fi
        kill -0 "$IPROXY_PID" 2>/dev/null || break
        sleep 0.5
    done

    echo "ERROR: iproxy did not start forwarding on port $port."
    stop_usb_ssh_forward
    return 1
}

reset_device_target() {
    DEVICE_PORT=22
    DEVICE_HOST_KEY_ALIAS=""
    DEVICE_LABEL=""
}

deploy_package_wifi() {
    local kind="$1"

    reset_device_target
    read_device_host || return 0
    DEVICE_LABEL="root@$DEVICE_HOST"

    deploy_package "$kind" || return 1

    mkdir -p "$(dirname "$DEVICE_HOST_FILE")"
    printf '%s\n' "$DEVICE_HOST" > "$DEVICE_HOST_FILE"
}

deploy_package_usb() {
    local kind="$1"
    local status=0

    reset_device_target
    start_usb_ssh_forward || return 1

    deploy_package "$kind" || status=$?

    stop_usb_ssh_forward
    reset_device_target
    return "$status"
}

select_push_transport() {
    menu_select "Connection" 0 "USB" "Wi-Fi" || return 1

    case "$MENU_SELECTION" in
        0) PUSH_TRANSPORT=usb ;;
        1) PUSH_TRANSPORT=wifi ;;
    esac
}

deploy_package_over() {
    case "$1" in
        usb) deploy_package_usb "$2" ;;
        wifi) deploy_package_wifi "$2" ;;
    esac
}

offer_package_deploy() {
    local kind="$1"

    menu_select "Install $(package_label "$kind")" 0 "Install over USB" "Install over Wi-Fi" "Skip" || return 0

    case "$MENU_SELECTION" in
        0) deploy_package_usb "$kind" || true ;;
        1) deploy_package_wifi "$kind" || true ;;
    esac
}

find_newest_deb() {
    local kind="$1"
    local architecture="$2"
    local directory
    local newest=""
    local newest_time=0
    local deb
    local mtime

    directory="$(package_directory "$kind")"
    [ -d "$directory" ] || return 0

    while IFS= read -r -d '' deb; do
        mtime="$(file_mtime "$deb" 2>/dev/null || echo 0)"
        if [ "$mtime" -gt "$newest_time" ]; then
            newest_time="$mtime"
            newest="$deb"
        fi
    done < <(
        find "$directory" \
            -maxdepth 1 \
            -type f \
            -name "$(package_name "$kind")_*_${architecture}.deb" \
            -print0 \
            2>/dev/null
    )

    printf '%s\n' "$newest"
}

install_package() {
    local kind="$1"

    if [ -z "$(find_newest_deb "$kind" iphoneos-arm)" ] && [ -z "$(find_newest_deb "$kind" iphoneos-arm64)" ]; then
        echo
        echo "ERROR: $(package_label "$kind") package not found. Build it first."
        return 1
    fi

    select_push_transport || return 0
    deploy_package_over "$PUSH_TRANSPORT" "$kind"
}

install_menu() {
    menu_select "Install" 0 "IPA" "DEB (Onegram)" "DEB (push helper)" || return 0

    case "$MENU_SELECTION" in
        0)
            install_onegram
            ;;
        1)
            install_package app || true
            ;;
        2)
            install_package push || true
            ;;
    esac
}

cd "$PROJECT"
ensure_python3 || exit 1
load_settings

VERSION_INFO="$(get_version_info)"
CURRENT_VERSION="$(printf '%s\n' "$VERSION_INFO" | sed -n '1p')"
CURRENT_BUILD="$(printf '%s\n' "$VERSION_INFO" | sed -n '2p')"

if [ "$#" -gt 0 ]; then
    case "$1" in
        --build|--prepare|--clean)
            if [ "$#" -ne 2 ]; then
                echo "Usage: ./build.sh $1 armv6|armv7|universal3"
                exit 2
            fi
            case "$2" in
                armv6|armv7|universal3) ;;
                *) echo "ERROR: Unsupported architecture $2"; exit 2 ;;
            esac
            if [ "$1" = --clean ]; then
                clean_project
            elif [ "$1" = --prepare ]; then
                prepare_build_environment "$2"
            else
                run_build "$2"
                post_build_install
            fi
            exit 0
            ;;
        --tweak)
            if [ "$#" -gt 2 ]; then
                echo "Usage: ./build.sh --tweak [DEVICE_IP|usb]"
                exit 2
            fi
            build_push_tweak
            if [ "$#" -eq 2 ] && [ "$2" = usb ]; then
                deploy_package_usb push
            elif [ "$#" -eq 2 ]; then
                ONEGRAM_DEVICE_HOST="$2" deploy_package_wifi push
            fi
            exit 0
            ;;
        --app-tweak)
            if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
                echo "Usage: ./build.sh --app-tweak armv6|armv7|universal3 [DEVICE_IP|usb]"
                exit 2
            fi
            case "$2" in
                armv6|armv7|universal3) ;;
                *) echo "ERROR: Unsupported architecture $2"; exit 2 ;;
            esac
            build_app_tweak "$2"
            if [ "$#" -eq 3 ] && [ "$3" = usb ]; then
                deploy_package_usb app
            elif [ "$#" -eq 3 ]; then
                ONEGRAM_DEVICE_HOST="$3" deploy_package_wifi app
            fi
            exit 0
            ;;
        *)
            echo "Usage: ./build.sh --prepare|--build|--clean armv6|armv7|universal3"
            echo "       ./build.sh --app-tweak armv6|armv7|universal3 [DEVICE_IP|usb]"
            echo "       ./build.sh --tweak [DEVICE_IP|usb]"
            exit 2
            ;;
    esac
fi

while true; do
    menu_select "Onegram | Version $CURRENT_VERSION ($CURRENT_BUILD) | $(build_mode_label)" 0 \
        "Build" "Clean Build" "Clean" "Settings" "Install" "Build App Tweak" "Build Push Tweak" "Exit" || break

    case "$MENU_SELECTION" in
        0)
            select_build_architecture || continue
            run_build "$SELECTED_BUILD_ARCH"
            post_build_install
            ;;
        1)
            select_build_architecture || continue
            ensure_api_config || continue
            clean_project
            run_build "$SELECTED_BUILD_ARCH"
            post_build_install
            ;;
        2)
            clean_project
            ;;
        3)
            settings_menu
            ;;
        4)
            install_menu
            ;;
        5)
            select_build_architecture || continue
            build_app_tweak "$SELECTED_BUILD_ARCH" && offer_package_deploy app
            ;;
        6)
            build_push_tweak && offer_package_deploy push
            ;;
        7)
            break
            ;;
    esac
done
