Jitterbug
=========

This app uses [libimobiledevice][1] and WiFi pairing to use one iOS device to launch apps with the debugger on another iOS device. This "tethered" launch allows JIT to work on the second iOS device.

## Building

1. Make sure you cloned all submodules with `git submodule update --init --recursive`
2. Open `Jitterbug.xcodeproj` and change the bundle id to a unique value registered to your Apple Developer account.
3. Build and run "JitterbugPair" on your macOS device.
4. Build and run "Jitterbug" on your iOS device.

## Pairing

(Note in the future, there will be a GUI app but right now we only have a CLI tool. There will also be a CLI tool for other operating systems.)

With the iOS device that you wish to target connected to your Mac, run `jitterbugpair` to generate `YOUR-UDID.mobiledevicepairing`.

If you get an error about OpenSSL, try running `jitterbugpair` from Xcode. You may have to run it two times (after entering your passcode). If you ran from Xcode, the generated file will be in the Products directory.

## Developer Image

Go [here][2] and download the ZIP corresponding to the closest iOS version to the target device. Unzip the download and you should get `DeveloperDiskImage.dmg` and `DeveloperDiskImage.dmg.signature`.

## Running

1. AirDrop (or email or another means) `YOUR-UDID.mobiledevicepairing`, `DeveloperDiskImage.dmg`, and `DeveloperDiskImage.dmg.signature` to the device with Jitterbug installed.
2. Open Jitterbug and under "Pairings" import your ".mobiledevicepairing". Under "Support Files" import both the ".dmg" and the ".dmg.signature".
3. In "Launcher", wait for the target device to appear. Make sure the target device is connected to the same WiFi and is unlocked.
4. Choose the target device and tap "Pair" and choose your ".mobiledevicepairing".
5. Tap "Mount" and choose your "DeveloperDiskImage.dmg".
6. Tap the app you wish to launch with JIT enabled.

## Troubleshooting

### Stuck on "Querying device..." for a long time

Your ".mobiledevicepairing" is outdated. You need to generate a new one with the steps above.

### Mount fails with "ImageMountFailed"

You may have already mounted the developer image. Try launching an app.

### Launch fails with "Efailed to get the task for process xxx"

This application does not have the `get-task-allow` entitlement. Or this is not an development app.

[1]: https://libimobiledevice.org
[2]: https://github.com/xushuduo/Xcode-iOS-Developer-Disk-Image/releases
