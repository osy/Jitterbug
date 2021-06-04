Jitterbug
=========
[![Build](https://github.com/osy/Jitterbug/workflows/Build/badge.svg?branch=main&event=push)][1]

此应用程序使用 [libimobiledevice][2] 和 WiFi 配对来使用一台 iOS 设备在另一台 iOS 设备上通过调试器启动应用程序。 这种“系留”启动允许 JIT 在第二个 iOS 设备上工作。

## 下载

[前往GitHub Releases](https://github.com/osy/Jitterbug/releases)

##  编译安装(Building) Jitterbug

1. 确保你克隆了所有子模块  （Make sure you cloned all submodules with) `git submodule update --init --recursive`
2. 打开`Jitterbug.xcodeproj` 并将bundle id 更改为注册到您的Apple Developer 帐户的唯一值。
3. 在您的 iOS 设备上编译安装并运行“Jitterbug”。

## 构建 JitterbugPair

生成配对令牌的软件适用于 macOS、Linux 和 Windows。 (The software to generate a pairing token is available for macOS, Linux, and Windows.)

### macOS

1. 确保您使用 `git submodule update --init --recursive` 克隆了所有子模块
2. 如果您还没有安装 [Homebrew][4]，请安装。
3. 安装依赖项：`brew install meson openssl@1.1 libusbmuxd libimobiledevice`
4. 使用`PKG_CONFIG_PATH="/usr/local/opt/openssl@1.1/lib/pkgconfig" meson build && cd build && meson compile `构建 (Build with `PKG_CONFIG_PATH="/usr/local/opt/openssl@1.1/lib/pkgconfig" meson build && cd build && meson compile`)
4. 构建的可执行文件在 `build/jitterbugpair` 中。 您可以使用“介子安装（meson install)”来安装它。

### Ubuntu 20.04
1. 确保您使用 `git submodule update --init --recursive` 克隆了所有子模块
2. 安装依赖库: `sudo apt install meson libgcrypt-dev libusbmuxd-dev libimobiledevice-dev libunistring-dev`
3. 使用`meson build && cd build && ninja`编译安装
4. 构建的可执行文件在 `build/jitterbugpair` 中。 您可以使用 `sudo ninja install` 安装它。

### Windows

1. 安装 [MSYS][5] 并打开 MSYS shell。
2. 安装依赖：`pacman -Syy git mingw64/mingw-w64-x86_64-gcc mingw64/mingw-w64-x86_64-pkg-config mingw64/mingw-w64-x86_64-meson mingw64/mingw-w64-xlibingw64 w64-x86_64-libimobiledevice`
3. 克隆存储库：`git clone --recursive https://github.com/osy/Jitterbug.git`
4. 关闭 MSYS 外壳并打开 MingW64 shell。
5. 打开克隆的存储库：`cd Jitterbug`
6. 使用 `meson build && cd build && meson compile` 构建
7. 构建的可执行文件是`build/jitterbugpair.exe` 和`build/libwinpthread-1.dll`。 这两个文件需要在同一目录中才能运行。

## 配对

在 macOS 和 Windows 上，请确保已安装 iTunes。 在 Linux 上，确保安装了 `usbmuxd`（`sudo apt install usbmuxd`）。

在插入设备的情况下运行`jitterbugpair`以生成`YOUR-UDID.mobiledevicepairing`。 您需要启用密码并且设备应该被解锁。 第一次运行该工具时，您将收到输入密码的提示。 输入并保持屏幕开启并解锁，然后再次运行该工具以生成配对。

## 开发者形象 (Developer Image)

前往 [此处][3] 并下载与目标设备最接近的 iOS 版本对应的 ZIP文件。 解压下载，你应该得到 `DeveloperDiskImage.dmg` 和 `DeveloperDiskImage.dmg.signature`。

##运行

1. AirDrop（或其他方式）传送`YOUR-UDID.mobiledevicepairing`, `DeveloperDiskImage.dmg`,和`DeveloperDiskImage.dmg.signature` 到安装了 Jitterbug 的设备。
2. 打开 Jitterbug 并在“配对（Pairings）”下导入您的`.mobiledevicepairing`文件。 在“支持文件(Support Files)”下导入`.dmg`和`.dmg.signature`。
3. 在“启动器(Launcher")”中，等待目标设备出现。 确保目标设备连接到同一个 WiFi 并已解锁。
4. 选择目标设备并选择您的`.mobiledevicepairing`文件。 （如果选择器没有自动出现，请点击“配对”。）
5. 点击您希望在启用 JIT 的情况下启动的应用程序。
6. 如果这是第一次在此设备上以这种方法启动应用程序，请选择您的`DeveloperDiskImage.dmg`文件。 （如果选择器(Mount)没有自动出现，请点击“安装（install)”。）

##  故障排除

### 挂载文件失败并显示“ImageMountFailed”

您可能已经安装了开发者映像(developer image)。 尝试启动应用程序。

### 启动失败并显示 "Failed to get the task for process xxx"

此应用程序没有`get-task-allow`权限。 或者这不是一个开发应用程序。

[1]: https://github.com/osy/Jitterbug/actions/workflows/build.yml?query=event%3Apush
[2]: https://libimobiledevice.org
[3]: https://github.com/xushuduo/Xcode-iOS-Developer-Disk-Image/releases
[4]: https://brew.sh
[5]: https://www.msys2.org