# Onegram Build

## Requirements

- Theos installed in `$HOME/theos`
- Python 3
- ccache
- iPhoneOS 6.1 SDK for armv7 builds
- iPhoneOS 11.2 SDK for arm64 builds
- GNU Make

The SDKs must be available as:

```text
$HOME/theos/sdks/iPhoneOS6.1.sdk
$HOME/theos/sdks/iPhoneOS11.2.sdk
```

On macOS, install the required build tools with Homebrew:

```bash
brew install make ccache python3
```

On Linux, use your distribution packages for `make`, `ccache`, and `python3`.

## Configure Telegram API credentials

Create the local configuration file:

```bash
cp config.h.example config.h
```

Open `config.h` and replace the example API ID and API hash with credentials for your own Telegram application.

`config.h` is local and must not be committed.

## Generate build files

From the repository root:

### macOS

```bash
cd theos
gmake generate
```

### Linux

```bash
cd theos
make generate
```

## Build armv7

### macOS

```bash
cd theos
gmake -j"$(sysctl -n hw.logicalcpu)" CORE_JOBS=8
```

### Linux

```bash
cd theos
make -j"$(nproc)" CORE_JOBS=8
```

The IPA is written to:

```text
theos/build/Onegram.ipa
```

## Build armv7 + arm64

### macOS

```bash
cd theos
gmake -j"$(sysctl -n hw.logicalcpu)" CORE_JOBS=8 universal
```

### Linux

```bash
cd theos
make -j"$(nproc)" CORE_JOBS=8 universal
```

The universal IPA is written to:

```text
theos/build/universal/Onegram.ipa
```

## Clean rebuild

### macOS

```bash
cd theos
gmake clean
gmake ONEGRAM_ARCH=arm64 clean
rm -rf .theos generated build
gmake generate
gmake -j"$(sysctl -n hw.logicalcpu)" CORE_JOBS=8 universal
```

### Linux

```bash
cd theos
make clean
make ONEGRAM_ARCH=arm64 clean
rm -rf .theos generated build
make generate
make -j"$(nproc)" CORE_JOBS=8 universal
```
