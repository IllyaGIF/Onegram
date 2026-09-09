# Onegram

Onegram is an unofficial Telegram client for legacy iOS devices.

The project brings modern Telegram functionality to devices and iOS versions that are no longer supported by the official Telegram client, with a particular focus on keeping old hardware usable instead of simply dropping unsupported APIs and features.

Onegram supports **iOS 4.3–10** and includes a full compatibility layer for running a large part of the modern client functionality even on an **iPhone 4 with iOS 4.3**.

## Onegram

Version 1.0 is the largest Onegram update so far.

A major part of the client has been reworked for iOS 4 compatibility, including Objective-C++, ARC, C++, libstdc++, GCD, UIKit, CoreImage, MapKit, GLKit, libtgvoip and WebRTC.

Around **85% of the main Onegram functionality is currently implemented and working on iOS 4.3**.

### Highlights

Full iOS 4.3 port
iOS 4.3–10 support
Telegram channels
Channel post comments
Forums and topics
Chat folders
Voice calls
WebRTC calling engine on iOS 4
Voice message / video message switching
Modern message history
Large chat and channel history pagination
Media and image loading
Video handling on iOS 4
Channel notification controls
Legacy iOS UI compatibility
Classic iOS 6 interface
Optimizations for 512 MB devices

## iOS 4

Onegram does not simply raise the minimum deployment target or disable functionality that does not work on iOS 4.

A large part of the application has been ported to work with the runtime and frameworks available on **iOS 4.3**.

This includes:

ARC support through ARCLite
Objective-C runtime compatibility
Objective-C++ compatibility
C++ code running through the old libstdc++ runtime
libtgvoip compatibility with libstdc++
TgVoipWebrtc port for iOS 4.3
WebRTC DSP compatibility with the old C++ runtime
Legacy GCD / libdispatch support
UIKit compatibility
CoreImage fallbacks
Operation without GLKit where it is unavailable
MapKit compatibility
Replacements for APIs and symbols introduced in iOS 5+

The main C++ part of Onegram and its calling engine can now be built with a real **iOS 4.3 deployment target** without increasing the minimum version to iOS 5.

## Performance

Onegram 1.0 contains major database and performance improvements, especially for older devices.

Some database operations that previously took approximately:

**1.5–1.7 seconds**

now take approximately:

**0.37–0.39 seconds**

Other improvements include:

Reduced unnecessary database access
Batch processing for several expensive database operations
Fewer unnecessary network requests while loading chats
Reduced CPU usage while loading the chat list
Faster chat-folder switching
Reduced unnecessary message-list reloads
Optimized user and contact loading
Lower application startup load
Improved asynchronous media loading

## 512 MB Devices

Special attention has been given to devices such as the **iPhone 4 and iPhone 4S**.

Onegram includes:

Memory usage improvements
Reduced CPU load
Improved chat scrolling stability
Fewer crashes while rapidly switching chats
Improved asynchronous media loading
Optimized database access
More stable loading of large chats and channels

## Current Status

Onegram is now usable as a regular Telegram client, although some crashes and unfinished functionality may still exist.

The iOS 4 port is approximately **85% complete**.

Video messages / video circles are currently one of the main remaining limitations on iOS 4.

Development is ongoing, with additional work focused on stability, compatibility and removing dependencies on APIs and runtime symbols introduced after iOS 4.

## Building

The project uses the legacy Telegram iOS architecture and contains Objective-C, Objective-C++, C and C++ code.

Reference development environment:

macOS Mavericks
Xcode 4.6.3
iPhoneOS SDK 6.1
Deployment target: iOS 4.3

1. Clone the repository, including its submodules:

   ```bash
   git clone --recursive https://github.com/IllyaGIF/Onegram.git
   cd Onegram
   ```

2. Create a local configuration file:

   ```bash
   cp config.h.example config.h
   ```

3. Add your own Telegram API credentials to `config.h`.

4. Open `Telegram.xcworkspace` in Xcode.

5. Select the `Telegraph` scheme and configure your bundle identifier and signing settings.

6. Build for an iOS device or simulator.

Do not publish `config.h`, signing certificates, provisioning profiles or other private credentials.

## Download

Prebuilt releases are available from the **GitHub Releases** section.

## License

Onegram is distributed under the **GNU General Public License v2.0**.

Parts of the project are based on the legacy Telegram for iOS codebase and other open-source components included in the repository.

## Disclaimer

Onegram is an unofficial Telegram client and is not affiliated with or endorsed by Telegram.

The project exists to keep Telegram usable on legacy iOS devices that are no longer supported by current official releases.
