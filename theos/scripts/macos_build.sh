macos_logged_step() {
    local label="$1"
    shift
    local log
    local result
    log="$(mktemp "${TMPDIR:-/tmp}/onegram-macos-setup.XXXXXX")"
    echo "$label"
    if "$@" >"$log" 2>&1; then
        return 0
    else
        result=$?
        awk '
        /[Ee]rror:|fatal:|Failed to|requires full Xcode/ {
            if (!seen[$0]++ && count++ < 6) print
        }
        ' "$log"
        tail -n 15 "$log"
        echo "Full setup log: $log"
        return "$result"
    fi
}

macos_select_package_manager() {
    local major
    local port_bin
    major="$(sw_vers -productVersion 2>/dev/null | cut -d . -f 1)"
    port_bin="$(command -v port || true)"
    if [ -z "$port_bin" ] && [ -x /opt/local/bin/port ]; then
        port_bin=/opt/local/bin/port
    fi
    if [ -z "${ONEGRAM_MACOS_PACKAGE_MANAGER:-}" ]; then
        case "$major" in
            10|11|12|13)
                if [ -n "$port_bin" ]; then
                    ONEGRAM_MACOS_PACKAGE_MANAGER=port
                fi
                ;;
        esac
        if [ -z "${ONEGRAM_MACOS_PACKAGE_MANAGER:-}" ]; then
            if command -v brew >/dev/null 2>&1; then
                ONEGRAM_MACOS_PACKAGE_MANAGER=brew
            elif [ -n "$port_bin" ]; then
                ONEGRAM_MACOS_PACKAGE_MANAGER=port
            fi
        fi
    fi
    case "${ONEGRAM_MACOS_PACKAGE_MANAGER:-}" in
        port)
            if [ -z "$port_bin" ]; then
                echo "ERROR: MacPorts was selected but port is unavailable."
                return 1
            fi
            export PATH="$(dirname "$port_bin"):$PATH"
            ;;
        brew)
            command -v brew >/dev/null 2>&1 || return 1
            ;;
        *)
            echo "ERROR: Homebrew or MacPorts is required to install the Linux build runtime."
            return 1
            ;;
    esac
}

macos_install_packages() {
    local packages=()
    local package
    macos_select_package_manager || return 1
    if [ "$ONEGRAM_MACOS_PACKAGE_MANAGER" = brew ]; then
        macos_logged_step "Installing build tools with Homebrew" brew install "$@"
    else
        for package in "$@"; do
            case "$package" in
                docker-buildx) packages+=(docker-buildx-plugin) ;;
                *) packages+=("$package") ;;
            esac
        done
        sudo -v || return 1
        macos_logged_step "Installing build tools with MacPorts" sudo port install "${packages[@]}"
    fi
}

prepare_macos_device_tools() {
    local packages=()
    macos_select_package_manager || return 1
    if ! command -v idevice_id >/dev/null 2>&1 || ! command -v ideviceinfo >/dev/null 2>&1; then
        packages+=(libimobiledevice)
    fi
    if ! command -v ideviceinstaller >/dev/null 2>&1; then
        packages+=(ideviceinstaller)
    fi
    if [ "${#packages[@]}" -gt 0 ]; then
        macos_install_packages "${packages[@]}" || return 1
    fi
}

colima_supports_flag() {
    printf '%s\n' "$1" | grep -Eq -- "(^|[[:space:],])--$2([[:space:]=]|$)"
}

start_macos_colima() {
    local help
    local cpus="$JOBS"
    local arguments=(--profile onegram start)
    help="$(colima start --help 2>&1)" || return 1
    [ "$cpus" -le 4 ] || cpus=4
    if colima_supports_flag "$help" arch; then
        arguments+=(--arch x86_64)
    elif [ "$(uname -m)" != x86_64 ]; then
        echo "ERROR: This Colima version cannot select the x86_64 build architecture."
        return 1
    fi
    if colima_supports_flag "$help" vm-type; then
        arguments+=(--vm-type qemu)
    fi
    if colima_supports_flag "$help" cpu; then
        arguments+=(--cpu "$cpus")
    elif colima_supports_flag "$help" cpus; then
        arguments+=(--cpus "$cpus")
    fi
    if colima_supports_flag "$help" memory; then
        arguments+=(--memory 4)
    fi
    if colima_supports_flag "$help" disk; then
        arguments+=(--disk 40)
    fi
    if colima_supports_flag "$help" runtime; then
        arguments+=(--runtime docker)
    fi
    if colima_supports_flag "$help" activate; then
        arguments+=(--activate=false)
    fi
    macos_logged_step "Starting Linux build runtime" colima "${arguments[@]}"
}

prepare_macos_runtime() {
    local packages=()
    local buildx
    local port_bin
    macos_select_package_manager || return 1
    if ! command -v docker >/dev/null 2>&1; then
        packages+=(docker)
    fi
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        if ! command -v colima >/dev/null 2>&1; then
            packages+=(colima)
        fi
        if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
            packages+=(qemu)
        fi
        if [ "${#packages[@]}" -gt 0 ]; then
            macos_install_packages "${packages[@]}" || return 1
        fi
        start_macos_colima || return 1
        export DOCKER_HOST="unix://${COLIMA_HOME:-$HOME/.colima}/onegram/docker.sock"
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: Linux build runtime is unavailable."
        return 1
    fi
    if ! docker buildx version >/dev/null 2>&1; then
        macos_install_packages docker-buildx || return 1
        if ! docker buildx version >/dev/null 2>&1; then
            buildx="$(command -v docker-buildx || true)"
            if [ -z "$buildx" ] && [ "$ONEGRAM_MACOS_PACKAGE_MANAGER" = brew ]; then
                buildx="$(brew --prefix docker-buildx)/bin/docker-buildx"
            elif [ -z "$buildx" ] && [ "$ONEGRAM_MACOS_PACKAGE_MANAGER" = port ]; then
                port_bin="$(command -v port)"
                buildx="$(dirname "$(dirname "$port_bin")")/libexec/docker/cli-plugins/docker-buildx"
            fi
            if [ -z "$buildx" ] || [ ! -x "$buildx" ]; then
                echo "ERROR: Docker Buildx was installed but its executable is unavailable."
                return 1
            fi
            mkdir -p "${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins"
            ln -sf "$buildx" "${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins/docker-buildx"
        fi
        if ! docker buildx version >/dev/null 2>&1; then
            echo "ERROR: Docker Buildx is unavailable after installation."
            return 1
        fi
    fi
    prepare_macos_device_tools || return 1
    macos_logged_step "Preparing Linux build image" docker build --platform linux/amd64 \
        -t onegram-builder:ubuntu22.04 "$PROJECT/container" || return 1
}

run_macos_container() {
    local action="$1"
    local architecture="$2"
    local project_id
    local interactive=()
    project_id="$(printf '%s' "$ROOT" | shasum -a 256 | cut -c 1-12)"
    if [ -t 0 ] && [ -t 1 ]; then
        interactive=(-it)
    fi
    docker run --rm "${interactive[@]}" --platform linux/amd64 \
        --mount "type=bind,source=$ROOT,target=/workspace" \
        --mount type=volume,source=onegram-theos,target=/root/theos \
        --mount type=volume,source=onegram-ccache,target=/root/.cache/ccache \
        --mount "type=volume,source=onegram-generated-$project_id,target=/workspace/theos/generated" \
        --mount "type=volume,source=onegram-objects-$project_id,target=/workspace/theos/.theos" \
        -e ONEGRAM_DIAGNOSTICS="$ONEGRAM_DIAGNOSTICS" \
        -e ONEGRAM_SKIP_DEVICE_INSTALL=1 \
        -e CORE_JOBS=4 \
        -e ONEGRAM_JOBS=4 \
        -e TMPDIR=/workspace/theos/build/logs \
        onegram-builder:ubuntu22.04 bash -c \
        'mkdir -p "$TMPDIR"; exec bash /workspace/build.sh "$@"' onegram "$action" "$architecture"
}

run_macos_build() {
    local architecture="$1"
    prepare_macos_runtime || return 1
    run_macos_container --build "$architecture" || return 1
    case "$architecture" in
        armv6) LAST_BUILT_IPA="$BUILD_DIR/armv6/Onegram.ipa" ;;
        armv7) LAST_BUILT_IPA="$BUILD_DIR/Onegram.ipa" ;;
        universal3) LAST_BUILT_IPA="$BUILD_DIR/universal3/Onegram.ipa" ;;
    esac
    if [ ! -f "$LAST_BUILT_IPA" ]; then
        LAST_BUILT_IPA="$(find_newest_ipa "$architecture")"
    fi
    if [ -z "$LAST_BUILT_IPA" ] || [ ! -f "$LAST_BUILT_IPA" ]; then
        echo "ERROR: Built IPA could not be found."
        return 1
    fi
}
