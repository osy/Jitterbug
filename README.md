Jitterbug
=========
[![Build](https://github.com/osy/Jitterbug/workflows/Build/badge.svg?branch=main&event=push)][1]

This app uses [libimobiledevice][2] and WiFi pairing to use one iOS device to launch apps with the debugger on another iOS device. This "tethered" launch allows JIT to work on the second iOS device. It can also create a VPN tunnel to allow a device to debug itself.

## Download

[Go to Releases](https://github.com/osy/Jitterbug/releases)

## Installation

[AltStore][6] is the preferred way to install Jitterbug. You can also sideload the IPA through other means or install it on a jailbroken device using [AppSync Unified][7].

## Pairing

Install Jitterbug on your *primary* device and the app you wish to launch on your *secondary* device.

On macOS and Windows, make sure you have iTunes installed. On Linux, make sure `usbmuxd` is installed (`sudo apt install usbmuxd`).

Run `jitterbugpair` with your secondary device plugged in to generate `YOUR-UDID.mobiledevicepairing`. You need to have a passcode enabled and the device should be unlocked. The first time you run the tool, you will get a prompt for your passcode. Type it in and keep the screen on and unlocked and run the tool again to generate the pairing.

## Running

Use AirDrop, email, or another means to copy the `.mobiledevicepairing` to your primary iOS device. When you open it, it should launch Jitterbug and import automatically.

Download the [Developer Image][3] for the iOS version running on your *secondary* iOS device (or the closest version if your version is not listed) and copy both `DeveloperDiskImage.dmg` and `DeveloperDiskImage.dmg.signature` to your *primary* iOS device. Open Jitterbug, go to "Support Files" and import both files.

Open Jitterbug, go to "Launcher", and look for your secondary iOS device to show up. If it is not showing up, make sure both devices are connected to the same network (tethering from primary to secondary OR secondary to primary is OK). Select the device and choose the pairing file. Then choose the app to launch and choose the `DeveloperDiskImage.dmg` file.

## Development

### Building Jitterbug

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Rename `CodeSigning.xcconfig.sample` to `CodeSigning.xcconfig` and edit it, filling in the information detailed in the next section.
3. Open `Jitterbug.xcodeproj`.
4. Build and run "Jitterbug" or "JitterbugLite" on your iOS device.

#### Entitlements

Jitterbug can create a VPN tunnel so a device can debug itself. This requires the "Network Extensions" entitlement which is not available to free developer accounts. If you have a free account, you will get a code signing error when trying to build. Jitterbug Lite is a build target that does not require Network Extensions and can be built with a free account.

Because Apple requires unique bundle IDs for developers, you need to choose a unique bundle ID prefix and fill it in `CodeSigning.xcconfig`.

If you have a paid account, you can find `DEVELOPMENT_TEAM` by going [here](https://developer.apple.com/account/#!/membership). If you have a free account, you can find your Team ID by creating a new Xcode project for iOS, selecting your team under Signing & Capabilities, and looking for the value of `DEVELOPMENT_TEAM` build setting.

### Building JitterbugPair

The software to generate a pairing token is available for macOS, Linux, and Windows.

#### macOS

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Install [Homebrew][4] if you have not already.
3. Install dependencies: `brew install meson openssl@1.1 libusbmuxd libimobiledevice pkg-config`
4. Build with `PKG_CONFIG_PATH="/usr/local/opt/openssl@1.1/lib/pkgconfig" meson build && cd build && meson compile`
4. The built executable is in `build/jitterbugpair`. You can install it with `meson install`.

#### Ubuntu 20.04

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Install dependencies: `sudo apt install meson libgcrypt-dev libusbmuxd-dev libimobiledevice-dev libunistring-dev`
3. Build with `meson build && cd build && ninja`
4. The built executable is in `build/jitterbugpair`. You can install it with `sudo ninja install`.

#### Windows

1. Install [MSYS][5] and open MSYS shell.
2. Install dependencies: `pacman -Syy git mingw64/mingw-w64-x86_64-gcc mingw64/mingw-w64-x86_64-pkg-config mingw64/mingw-w64-x86_64-meson mingw64/mingw-w64-x86_64-libusbmuxd mingw64/mingw-w64-x86_64-libimobiledevice`
3. Clone the repository: `git clone --recursive https://github.com/osy/Jitterbug.git`
4. Close the MSYS shell and open the MingW64 shell.
5. Open the cloned repository: `cd Jitterbug`
6. Build with `meson build && cd build && meson compile`
7. The built executable is `build/jitterbugpair.exe` and `build/libwinpthread-1.dll`. Both files needs to be in the same directory to run.

## Troubleshooting

### Mount fails with "ImageMountFailed"

You may have already mounted the developer image. Try launching an app.

### Launch fails with "Failed to get the task for process xxx"

This application does not have the `get-task-allow` entitlement. Or this is not an development app.

[1]: https://github.com/osy/Jitterbug/actions/workflows/build.yml?query=event%3Apush
[2]: https://libimobiledevice.org
[3]: https://github.com/xushuduo/Xcode-iOS-Developer-Disk-Image/releases
[4]: https://brew.sh
[5]: https://www.msys2.org
[6]: https://altstore.io
[7]: https://cydia.akemi.ai/?page/net.angelxwind.appsyncunified
