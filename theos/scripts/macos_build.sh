macos_logged_step() {
    local label="$1"
    shift
    local log
    local result
    log="$(mktemp "${TMPDIR:-/tmp}/onegram-macos-setup.XXXXXX")" || return 1
    echo "$label"
    if "$@" >"$log" 2>&1; then
        rm -f "$log"
        return 0
    else
        result=$?
        tail -n 15 "$log"
        echo "Full setup log: $log"
        return "$result"
    fi
}

macos_bootstrap_python() {
    local native_root="${ONEGRAM_NATIVE_ROOT:-$HOME/.cache/onegram/macos}"
    local bootstrap="$native_root/bootstrap"
    local architecture
    local checksum
    local installer
    local actual
    local arguments=(-b -p "$bootstrap")
    if [ -x "$bootstrap/bin/python3" ] && [ -x "$bootstrap/bin/conda" ]; then
        export ONEGRAM_NATIVE_ROOT="$native_root"
        export PATH="$bootstrap/bin:$PATH"
        return 0
    fi
    architecture="$(uname -m)"
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
        architecture=arm64
    fi
    case "$architecture" in
        x86_64) checksum=26a80621b146d60e5ae0d896b83ec138416653b951286361b1f93a804cb6a8d9 ;;
        arm64) checksum=9b3c3d9fa30437592e680390f2b27d45c5d5cfcbfad9a1af233f70a6d8be71a1 ;;
        *) echo "ERROR: Unsupported native macOS architecture: $architecture"; return 1 ;;
    esac
    mkdir -p "$native_root" || return 1
    installer="$(mktemp "$native_root/miniforge.XXXXXX")" || return 1
    if ! macos_logged_step "Downloading native build bootstrap" curl -fL --retry 3 \
        "https://github.com/conda-forge/miniforge/releases/download/24.3.0-0/Miniforge3-MacOSX-$architecture.sh" -o "$installer"; then
        rm -f "$installer"
        return 1
    fi
    actual="$(shasum -a 256 "$installer" | cut -d ' ' -f 1)"
    if [ "$actual" != "$checksum" ]; then
        rm -f "$installer"
        echo "ERROR: Native bootstrap checksum mismatch."
        return 1
    fi
    if [ -d "$bootstrap" ]; then
        arguments+=(-u)
    fi
    if ! macos_logged_step "Installing native build bootstrap" bash "$installer" "${arguments[@]}"; then
        rm -f "$installer"
        return 1
    fi
    rm -f "$installer"
    export ONEGRAM_NATIVE_ROOT="$native_root"
    export PATH="$bootstrap/bin:$PATH"
    [ -x "$bootstrap/bin/python3" ] && [ -x "$bootstrap/bin/conda" ]
}

activate_macos_native_tools() {
    local native_root="${ONEGRAM_NATIVE_ROOT:-$HOME/.cache/onegram/macos}"
    local tools="$native_root/tools/bin"
    if [ -x "$tools/python3" ] && [ -x "$tools/make" ]; then
        export PATH="$tools:$native_root/bootstrap/bin:$PATH"
        MAKE="$tools/make"
    fi
    if [ -x "$THEOS/toolchain/macos/iphone/bin/lipo" ]; then
        LIPO="$THEOS/toolchain/macos/iphone/bin/lipo"
    fi
    export ONEGRAM_LOG_DIR="${ONEGRAM_LOG_DIR:-$BUILD_DIR/logs}"
}

prepare_macos_native_tools() {
    if command -v colima >/dev/null 2>&1 && colima --profile onegram status >/dev/null 2>&1; then
        macos_logged_step "Stopping previous Onegram VM" colima --profile onegram stop || return 1
    fi
    macos_bootstrap_python || return 1
    macos_logged_step "Preparing native macOS build tools" \
        "$ONEGRAM_NATIVE_ROOT/bootstrap/bin/python3" "$PROJECT/scripts/setup_macos_toolchain.py" --tools-only || return 1
    activate_macos_native_tools
}

macos_select_package_manager() {
    if [ -z "${ONEGRAM_MACOS_PACKAGE_MANAGER:-}" ]; then
        if [ -x /opt/local/bin/port ]; then
            export PATH="/opt/local/bin:$PATH"
            ONEGRAM_MACOS_PACKAGE_MANAGER=port
        elif command -v brew >/dev/null 2>&1; then
            ONEGRAM_MACOS_PACKAGE_MANAGER=brew
        fi
    fi
    case "${ONEGRAM_MACOS_PACKAGE_MANAGER:-}" in
        brew) command -v brew >/dev/null 2>&1 ;;
        port) command -v port >/dev/null 2>&1 ;;
        *) echo "ERROR: USB installation needs libimobiledevice and ideviceinstaller from MacPorts or Homebrew."; return 1 ;;
    esac
}

prepare_macos_device_tools() {
    local packages=()
    if ! command -v idevice_id >/dev/null 2>&1 || ! command -v ideviceinfo >/dev/null 2>&1; then
        packages+=(libimobiledevice)
    fi
    if ! command -v ideviceinstaller >/dev/null 2>&1; then
        packages+=(ideviceinstaller)
    fi
    [ "${#packages[@]}" -gt 0 ] || return 0
    macos_select_package_manager || return 1
    if [ "$ONEGRAM_MACOS_PACKAGE_MANAGER" = brew ]; then
        macos_logged_step "Installing USB tools with Homebrew" brew install "${packages[@]}"
    else
        sudo -v || return 1
        macos_logged_step "Installing USB tools with MacPorts" sudo port install "${packages[@]}"
    fi
}
