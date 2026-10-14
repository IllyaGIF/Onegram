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
        MAKE="gmake"
        LIPO="$(xcrun --find lipo 2>/dev/null || command -v lipo || true)"
        JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
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

BUILD_DIR="$PROJECT/build"
INFO_PLIST="$ROOT/Telegraph/Telegraph-Info.plist"
CONFIG_XCCONFIG="$ROOT/Config.xcconfig"

CORE_JOBS="${CORE_JOBS:-8}"

BUILD_LOG=""
SELECTED_BUILD_ARCH=""
LAST_BUILT_IPA=""
SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/onegram/build-mode"
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

    exit 130
}

trap interrupt_build INT TERM

show_ccache_stats() {
    if ! command -v ccache >/dev/null 2>&1; then
        return
    fi

    echo
    echo "ccache:"

    ccache -s | awk '
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

        /^[[:space:]]*Cache size/ && !size {
            print
            size = 1
        }
    '
}

get_ipa_architecture() {
    local ipa="$1"
    local binary
    local has_armv6=0
    local has_armv7=0
    local has_arm64=0

    binary="$(mktemp "${TMPDIR:-/tmp}/onegram-ipa-binary.XXXXXX")"

    if ! python3 - "$ipa" "$binary" <<'PY'
import sys
import zipfile

ipa = sys.argv[1]
output = sys.argv[2]

with zipfile.ZipFile(ipa, "r") as z:
    candidates = [
        name
        for name in z.namelist()
        if name.startswith("Payload/")
        and ".app/" in name
        and name.endswith("/Telegram")
    ]

    if not candidates:
        raise SystemExit(1)

    data = z.read(candidates[0])

with open(output, "wb") as f:
    f.write(data)
PY
    then
        rm -f "$binary"
        echo "unknown"
        return
    fi

    if "$LIPO" "$binary" -verify_arch armv6 >/dev/null 2>&1; then
        has_armv6=1
    fi

    if "$LIPO" "$binary" -verify_arch armv7 >/dev/null 2>&1; then
        has_armv7=1
    fi

    if "$LIPO" "$binary" -verify_arch arm64 >/dev/null 2>&1; then
        has_arm64=1
    fi

    rm -f "$binary"

    if [ "$has_armv6" -eq 1 ] && [ "$has_armv7" -eq 1 ] && [ "$has_arm64" -eq 1 ]; then
        echo "universal3"
    elif [ "$has_armv7" -eq 1 ] && [ "$has_arm64" -eq 1 ]; then
        echo "universal"
    elif [ "$has_armv6" -eq 1 ] && [ "$has_armv7" -eq 1 ]; then
        echo "armv6-armv7"
    elif [ "$has_armv6" -eq 1 ] && [ "$has_arm64" -eq 1 ]; then
        echo "armv6-arm64"
    elif [ "$has_armv6" -eq 1 ]; then
        echo "armv6"
    elif [ "$has_armv7" -eq 1 ]; then
        echo "armv7"
    elif [ "$has_arm64" -eq 1 ]; then
        echo "arm64"
    else
        echo "unknown"
    fi
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

    if [ -z "$LIPO" ] || [ ! -x "$LIPO" ]; then
        echo
        echo "ERROR: lipo not found."
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

    "$@" \
        2>&1 |
        tee -a "$log" |
        awk '
        /Compiling|Linking|Merging|Signing|Packaging|Stripping|Copying|Bundling|Creating/ {
            count++

            line = $0
            gsub(/\033\[[0-9;]*[A-Za-z]/, "", line)

            if (length(line) > 110) {
                line = substr(line, 1, 107) "..."
            }

            printf "\r[%d] %-110s", count, line
            fflush()
        }

        /error:|fatal error:|Unavailable:/ {
            printf "\n%s\n", $0
            fflush()
        }

        END {
            printf "\n"
        }
        '

    return "${PIPESTATUS[0]}"
}

extract_ipa_binary() {
    local ipa="$1"
    local output="$2"

    python3 - "$ipa" "$output" <<'PY'
import os
import sys
import zipfile

ipa = sys.argv[1]
output = sys.argv[2]

with zipfile.ZipFile(ipa, "r") as z:
    candidates = [
        name
        for name in z.namelist()
        if name.startswith("Payload/")
        and ".app/" in name
        and name.endswith("/Telegram")
    ]

    if not candidates:
        raise SystemExit("Telegram executable not found in IPA")

    data = z.read(candidates[0])

with open(output, "wb") as f:
    f.write(data)

os.chmod(output, 0o755)
PY
}

find_ldid() {
    if command -v ldid >/dev/null 2>&1; then
        command -v ldid
        return
    fi

    if [ -n "${THEOS:-}" ] && [ -x "$THEOS/bin/ldid" ]; then
        echo "$THEOS/bin/ldid"
        return
    fi

    if [ -n "${THEOS:-}" ] && [ -x "$THEOS/toolchain/linux/iphone/bin/ldid" ]; then
        echo "$THEOS/toolchain/linux/iphone/bin/ldid"
        return
    fi

    if [ -x "$HOME/theos/bin/ldid" ]; then
        echo "$HOME/theos/bin/ldid"
        return
    fi

    if [ -x "$HOME/theos/toolchain/linux/iphone/bin/ldid" ]; then
        echo "$HOME/theos/toolchain/linux/iphone/bin/ldid"
        return
    fi

    if [ -x "$PROJECT/../theos/bin/ldid" ]; then
        echo "$PROJECT/../theos/bin/ldid"
        return
    fi

    if [ -x "$PROJECT/../theos/toolchain/linux/iphone/bin/ldid" ]; then
        echo "$PROJECT/../theos/toolchain/linux/iphone/bin/ldid"
        return
    fi

    echo ""
}

create_universal3_ipa() {
    local armv6_ipa="$1"
    local universal_ipa="$2"
    local output_dir
    local output_ipa
    local work_dir
    local universal_root
    local armv6_binary
    local app_dir
    local app_binary
    local merged_binary
    local plist
    local ldid_path
    local entitlements
    local have_entitlements=0

    if [ ! -f "$armv6_ipa" ]; then
        echo
        echo "ERROR: armv6 IPA not found."
        exit 1
    fi

    if [ ! -f "$universal_ipa" ]; then
        echo
        echo "ERROR: armv7 + arm64 IPA not found."
        exit 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo
        echo "ERROR: unzip not found."
        exit 1
    fi

    if ! command -v zip >/dev/null 2>&1; then
        echo
        echo "ERROR: zip not found."
        exit 1
    fi

    if [ -z "$LIPO" ] || [ ! -x "$LIPO" ]; then
        echo
        echo "ERROR: lipo not found."
        exit 1
    fi

    ldid_path="$(find_ldid)"

    if [ -z "$ldid_path" ]; then
        echo
        echo "ERROR: ldid not found."
        exit 1
    fi

    output_dir="$BUILD_DIR/universal3"
    output_ipa="$output_dir/Onegram-armv6-armv7-arm64.ipa"

    mkdir -p "$output_dir"

    work_dir="$(mktemp -d "${TMPDIR:-/tmp}/onegram-universal3.XXXXXX")"
    universal_root="$work_dir/universal"
    armv6_binary="$work_dir/Telegram-armv6"
    merged_binary="$work_dir/Telegram-universal3"
    entitlements="$work_dir/entitlements.plist"

    mkdir -p "$universal_root"

    unzip -q "$universal_ipa" -d "$universal_root"

    app_dir="$(
        find "$universal_root/Payload" \
            -maxdepth 1 \
            -type d \
            -name '*.app' \
            -print \
            -quit
    )"

    if [ -z "$app_dir" ] || [ ! -d "$app_dir" ]; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Application bundle not found in universal IPA."
        exit 1
    fi

    app_binary="$app_dir/Telegram"
    plist="$app_dir/Info.plist"

    if [ ! -f "$app_binary" ]; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Telegram binary not found in universal IPA."
        exit 1
    fi

    if [ ! -f "$plist" ]; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Info.plist not found in universal IPA."
        exit 1
    fi

    extract_ipa_binary "$armv6_ipa" "$armv6_binary"

    if "$ldid_path" -e "$app_binary" > "$entitlements" 2>/dev/null; then
        if grep -q "<plist" "$entitlements" 2>/dev/null; then
            have_entitlements=1
        fi
    fi

    "$LIPO" \
        -create \
        "$armv6_binary" \
        "$app_binary" \
        -output "$merged_binary"

    if ! "$LIPO" "$merged_binary" -verify_arch armv6 >/dev/null 2>&1; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Merged binary does not contain armv6."
        exit 1
    fi

    if ! "$LIPO" "$merged_binary" -verify_arch armv7 >/dev/null 2>&1; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Merged binary does not contain armv7."
        exit 1
    fi

    if ! "$LIPO" "$merged_binary" -verify_arch arm64 >/dev/null 2>&1; then
        rm -rf "$work_dir"
        echo
        echo "ERROR: Merged binary does not contain arm64."
        exit 1
    fi

    chmod 755 "$merged_binary"
    mv "$merged_binary" "$app_binary"

    python3 - "$plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]

with open(path, "rb") as f:
    plist = plistlib.load(f)

plist["MinimumOSVersion"] = "3.1.3"
plist.pop("UIRequiredDeviceCapabilities", None)

with open(path, "wb") as f:
    plistlib.dump(
        plist,
        f,
        fmt=plistlib.FMT_XML,
        sort_keys=False
    )
PY

    python3 "$PROJECT/scripts/build_identity.py" --app "$app_dir" --architecture armv6+armv7+arm64

    rm -rf "$app_dir/_CodeSignature"
    rm -f "$app_dir/CodeResources"

    if [ "$have_entitlements" -eq 1 ]; then
        "$ldid_path" "-S$entitlements" "$app_binary"
    else
        "$ldid_path" -S "$app_binary"
    fi

    rm -f "$output_ipa"

    (
        cd "$universal_root"
        zip -qry "$output_ipa" .
    )

    rm -rf "$work_dir"

    verify_ipa "$output_ipa" universal3

    LAST_BUILT_IPA="$output_ipa"
}

run_build() {
    local architecture="$1"
    local result=0
    local start_time
    local end_time
    local elapsed
    local minutes
    local seconds
    local armv6_ipa
    local universal_ipa
    LAST_BUILT_IPA=""

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

    BUILD_LOG="$(mktemp "${TMPDIR:-/tmp}/onegram-build.XXXXXX")"
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
            echo "Building armv6..."
            echo

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

            if [ "$result" -eq 0 ]; then
                armv6_ipa="$BUILD_DIR/armv6/Onegram.ipa"

                if [ ! -f "$armv6_ipa" ]; then
                    echo
                    echo "ERROR: armv6 IPA could not be found."
                    result=1
                fi
            fi

            if [ "$result" -eq 0 ]; then
                echo
                echo "Building armv7 + arm64..."
                echo

                stream_build \
                    "$BUILD_LOG" \
                    "$MAKE" \
                    -j"$JOBS" \
                    CORE_JOBS="$CORE_JOBS" \
                    ONEGRAM_DIAGNOSTICS="$ONEGRAM_DIAGNOSTICS" \
                    --output-sync=line \
                    universal

                result=$?
            fi

            if [ "$result" -eq 0 ]; then
                universal_ipa="$BUILD_DIR/universal/Onegram.ipa"

                if [ ! -f "$universal_ipa" ]; then
                    echo
                    echo "ERROR: armv7 + arm64 IPA could not be found."
                    result=1
                fi
            fi

            if [ "$result" -eq 0 ]; then
                echo
                echo "Merging armv6 + armv7 + arm64..."
                echo

                create_universal3_ipa "$armv6_ipa" "$universal_ipa"
                result=$?
            fi
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
        echo "Last build output:"
        echo

        tail -n 100 "$BUILD_LOG"

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
            if [ -z "$LAST_BUILT_IPA" ]; then
                LAST_BUILT_IPA="$(find_newest_ipa universal3)"
            fi
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

    echo
    echo "Build complete"
    printf "Build time: %dm %02ds\n" "$minutes" "$seconds"
    echo "Architectures: $(architecture_label "$architecture")"

    show_ccache_stats

    rm -f "$BUILD_LOG"
    BUILD_LOG=""
}

clean_project() {
    local start_time
    local end_time
    local elapsed

    echo
    echo "Cleaning Onegram..."
    echo

    start_time="$(date +%s)"

    "$MAKE" clean || true
    "$MAKE" ONEGRAM_ARCH=armv6 clean || true
    "$MAKE" ONEGRAM_ARCH=arm64 clean || true

    rm -rf "$BUILD_DIR/universal3"

    if [ -d "$PROJECT/.theos" ]; then
        echo
        echo "Removing $PROJECT/.theos..."
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

install_onegram() {
    local result
    local required_arch
    local ipa_architecture
    local ipa_time
    local ipa_mtime

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

if ! command -v "$MAKE" >/dev/null 2>&1; then
    echo
    echo "ERROR: $MAKE not found."
    exit 1
fi

if [ -z "$LIPO" ] || [ ! -x "$LIPO" ]; then
    echo
    echo "ERROR: lipo not found."
    exit 1
fi

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

cd "$PROJECT"
load_settings

VERSION_INFO="$(get_version_info)"
CURRENT_VERSION="$(printf '%s\n' "$VERSION_INFO" | sed -n '1p')"
CURRENT_BUILD="$(printf '%s\n' "$VERSION_INFO" | sed -n '2p')"

while true; do
    menu_select "Onegram | Version $CURRENT_VERSION ($CURRENT_BUILD) | $(build_mode_label)" 0 \
        "Build" "Clean Build" "Clean" "Settings" "Install IPA" "Exit" || break

    case "$MENU_SELECTION" in
        0)
            select_build_architecture || continue
            run_build "$SELECTED_BUILD_ARCH"
            install_onegram
            ;;
        1)
            select_build_architecture || continue
            clean_project
            run_build "$SELECTED_BUILD_ARCH"
            install_onegram
            ;;
        2)
            clean_project
            ;;
        3)
            settings_menu
            ;;
        4)
            install_onegram
            ;;
        5)
            break
            ;;
    esac
done
