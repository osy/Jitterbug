Jitterbug
=========
[![Build](https://github.com/osy/Jitterbug/workflows/Build/badge.svg?branch=main&event=push)][1]

This app uses [libimobiledevice][2] and WiFi pairing to use one iOS device to launch apps with the debugger on another iOS device. This "tethered" launch allows JIT to work on the second iOS device.

## Download

[Go to Releases](https://github.com/osy/Jitterbug/releases)

## Building Jitterbug

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Open `Jitterbug.xcodeproj` and change the bundle id to a unique value registered to your Apple Developer account.
3. Build and run "Jitterbug" on your iOS device.

## Building JitterbugPair

The software to generate a pairing token is available for macOS, Linux, and Windows.

### macOS

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Install [Homebrew][4] if you have not already.
3. Install dependencies: `brew install meson openssl@1.1 libusbmuxd libimobiledevice pkg-config`
4. Build with `PKG_CONFIG_PATH="/usr/local/opt/openssl@1.1/lib/pkgconfig" meson build && cd build && meson compile`
4. The built executable is in `build/jitterbugpair`. You can install it with `meson install`.

### Ubuntu 20.04

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Install dependencies: `sudo apt install meson libgcrypt-dev libusbmuxd-dev libimobiledevice-dev libunistring-dev`
3. Build with `meson build && cd build && ninja`
4. The built executable is in `build/jitterbugpair`. You can install it with `sudo ninja install`.

### Windows

1. Install [MSYS][5] and open MSYS shell.
2. Install dependencies: `pacman -Syy git mingw64/mingw-w64-x86_64-gcc mingw64/mingw-w64-x86_64-pkg-config mingw64/mingw-w64-x86_64-meson mingw64/mingw-w64-x86_64-libusbmuxd mingw64/mingw-w64-x86_64-libimobiledevice`
3. Clone the repository: `git clone --recursive https://github.com/osy/Jitterbug.git`
4. Close the MSYS shell and open the MingW64 shell.
5. Open the cloned repository: `cd Jitterbug`
6. Build with `meson build && cd build && meson compile`
7. The built executable is `build/jitterbugpair.exe` and `build/libwinpthread-1.dll`. Both files needs to be in the same directory to run.

## Pairing

On macOS and Windows, make sure you have iTunes installed. On Linux, make sure `usbmuxd` is installed (`sudo apt install usbmuxd`).

### macOS 11

Jitterbug is also available for macOS 11 and higher. Run the app and connect your device via USB. Select the device and press the export button on the top toolbar to export `YOUR-UDID.mobiledevicepairing`.

### Other Systems

Run `jitterbugpair` with your device plugged in to generate `YOUR-UDID.mobiledevicepairing`. You need to have a passcode enabled and the device should be unlocked. The first time you run the tool, you will get a prompt for your passcode. Type it in and keep the screen on and unlocked and run the tool again to generate the pairing.

## Developer Image

Go [here][3] and download the ZIP corresponding to the closest iOS version to the target device. Unzip the download and you should get `DeveloperDiskImage.dmg` and `DeveloperDiskImage.dmg.signature`.

## Running

1. AirDrop (or email or another means) `YOUR-UDID.mobiledevicepairing`, `DeveloperDiskImage.dmg`, and `DeveloperDiskImage.dmg.signature` to the device with Jitterbug installed.
2. Open Jitterbug and under "Pairings" import your ".mobiledevicepairing". Under "Support Files" import both the ".dmg" and the ".dmg.signature".
3. In "Launcher", wait for the target device to appear. Make sure the target device is connected to the same WiFi and is unlocked.
4. Choose the target device and choose your ".mobiledevicepairing". (Tap "Pair" if the chooser does not appear automatically.)
5. Tap the app you wish to launch with JIT enabled.
6. Choose your "DeveloperDiskImage.dmg" if this is the first time launching an app on this device. (Tap "Mount" if the chooser does not appear automatically.)

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
