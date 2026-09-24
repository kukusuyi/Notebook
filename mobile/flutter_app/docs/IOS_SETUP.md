# iOS 编译与安装

Questrace 2.0 的 iOS 客户端源码位于 `mobile/flutter_app/`。iOS 构建必须在 macOS 上完成；仓库已经包含原生工程，不要再次执行 `flutter create .`。

## 环境要求

- 与仓库发行配置一致的 Flutter 3.44.0
- 最新稳定版 Xcode，以及 Xcode Command Line Tools
- CocoaPods
- iOS 15.0 或更高版本

首次准备环境：

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor -v
cd mobile/flutter_app
cp config/app_config.example.json config/app_config.json
flutter pub get
cd ios && pod install && cd ..
```

将 `config/app_config.json` 的 `apiBaseUrl` 设为空字符串，可在应用设置页填写电脑的局域网地址；也可在构建前直接写入 `http://电脑局域网IP:端口`。这个文件已被 Git 忽略，不会提交到仓库。

## 无开发者账号：编译无签名 release

无需 Apple ID 即可确认 iOS release 代码能够通过 Xcode 编译：

```sh
cd mobile/flutter_app
flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=production
```

输出位于 `build/ios/iphoneos/Runner.app`。它是无签名的设备版应用，只用于编译验证；没有 Apple 签名和 Provisioning Profile 时不能安装到 iPhone，也不能将这个目录改名为 `.ipa` 后分发。

## 无开发者账号：在模拟器运行

模拟器不需要 Apple ID 或签名证书：

```sh
cd mobile/flutter_app
open -a Simulator
flutter devices
flutter run -d SIMULATOR_ID --dart-define=APP_FLAVOR=production
```

Flutter 不支持 iOS 模拟器的 release 模式；请指定 `flutter devices` 输出的具体模拟器 ID，以 debug 模式运行并验证功能。模拟器运行在 Mac 上，连接本机服务可使用 `http://127.0.0.1:8080`；如果服务实际选择了其他端口，以桌面程序显示的地址为准。

## 免费 Apple ID：安装到自己的 iPhone

免费 Apple ID 可以进行个人真机调试，但不能发布到 App Store 或 TestFlight，配置描述文件也可能需要定期重新签名。

1. 用数据线连接并信任 iPhone，在手机上启用“开发者模式”。
2. 打开 `mobile/flutter_app/ios/Runner.xcworkspace`，不要打开 `.xcodeproj`。
3. 在 Xcode 的 **Settings > Accounts** 登录 Apple ID。
4. 选择 **Runner > Signing & Capabilities**，启用 **Automatically manage signing**，在 **Team** 中选择个人团队。
5. `com.mathnotebook.mobile` 是为兼容旧安装而保留的标识。如果它已被占用，把 Bundle Identifier 改为自己唯一的值，例如 `com.yourname.questrace`。这只影响本机签名身份，不影响服务端连接。
6. 选择已连接的 iPhone 后在 Xcode 中运行，或执行：

```sh
flutter devices
flutter run -d IPHONE_DEVICE_ID --dart-define=APP_FLAVOR=production
```

真机不能使用 `127.0.0.1` 连接电脑。请确保手机和电脑位于可互通的网络，并在应用设置页填写桌面端显示的地址，例如 `http://192.168.1.10:8080`。首次访问时允许“本地网络”权限，电脑防火墙也需允许 Questrace 接收入站连接。

## 付费开发者账号：归档、IPA 与 TestFlight

对外分发需要有效的 Apple Developer Program 会员、唯一 Bundle Identifier、Distribution 证书和相应 Provisioning Profile。完成 Xcode 的 Team 与签名设置后执行：

```sh
flutter build ipa --release --dart-define=APP_FLAVOR=production
```

归档位于 `build/ios/archive/Runner.xcarchive`，导出结果位于 `build/ios/ipa/`。也可以在 Xcode 中打开 `Runner.xcworkspace`，选择 **Product > Archive**，然后通过 Organizer 上传 App Store Connect/TestFlight 或按证书能力导出 IPA。

没有付费会员时，无法生成可长期安装、可公开分发或可上传 TestFlight/App Store 的正式 iOS 包；自签名或 ad-hoc 方式不能替代 Apple 的设备注册和配置描述文件机制。因此 v2.0.0 Release 只保留 iOS 源码，不附带 IPA。

## 构建前检查

```sh
flutter doctor -v
flutter analyze
flutter test
flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=production
```

如果 CocoaPods 状态异常，可在 `mobile/flutter_app/` 下执行：

```sh
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
```

如果签名失败，先在 Xcode 的 Runner target 中确认 Team、Bundle Identifier 和自动签名状态。不要把个人证书、`.p12`、Provisioning Profile 或包含密钥的配置文件提交到 Git。
