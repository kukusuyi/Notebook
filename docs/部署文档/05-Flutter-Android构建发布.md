# Flutter Android 构建发布

本文档说明如何构建 Android 客户端、如何连接生产后端，以及如何把 APK 发布到当前后端的“版本检查 + MinIO 下载”链路。

## 1. 移动端当前能力

Flutter 工程位于：

- [mobile/flutter_app](../../mobile/flutter_app)

当前已经具备：

- 登录
- 手动录入
- 图片上传
- OCR 确认
- AI 确认
- 列表 / 详情 / 相似题
- API 地址覆盖
- 更新检查与 APK 下载

## 2. 构建环境

建议在开发机而不是服务器上完成 Android 构建。

至少准备：

- Flutter SDK
- Android Studio
- Android SDK / platform-tools
- Java 11

当前项目要求：

- Dart `>= 3.4.0`

## 3. 首次准备

```bash
cd mobile/flutter_app
flutter pub get
flutter doctor
```

如果 `flutter doctor` 仍有 Android toolchain 问题，先补齐再继续。

## 4. API 地址机制

移动端默认 API 地址优先读取：

1. `mobile/flutter_app/config/app_config.json`
2. 如果用户在设置页手动覆盖，则优先使用覆盖值
3. 如果 `app_config.json` 缺失或为空，再回退到 `dart-define=API_BASE_URL`
4. 最后才回退到内置开发默认值 `http://10.0.2.2:8080`

配置文件说明：

- 示例文件：[mobile/flutter_app/config/app_config.example.json](../../mobile/flutter_app/config/app_config.example.json)
- 实际文件：`mobile/flutter_app/config/app_config.json`
- 实际文件已加入仓库根 `.gitignore`，不会提交

正式包构建前，务必先复制并修改实际配置：

```bash
cd mobile/flutter_app
cp config/app_config.example.json config/app_config.json
```

然后把 `apiBaseUrl` 改成真实后端地址，例如：

```json
{
  "flavor": "prod",
  "apiBaseUrl": "https://api.example.com"
}
```

## 5. 开发调试

### Android 模拟器

```bash
flutter run
```

### 真机调试

如果后端跑在局域网某台机器上，修改 `config/app_config.json`：

```json
{
  "flavor": "dev",
  "apiBaseUrl": "http://192.168.1.100:8080"
}
```

## 6. 生产构建

### APK

```bash
flutter build apk --release
```

产物一般位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle

如果后续要接应用商店，也可以构建：

```bash
flutter build appbundle --release
```

## 7. 当前必须补的发布项

当前 Android 配置中，`release` 仍然使用 debug 签名，仅适合内部测试：

- [mobile/flutter_app/android/app/build.gradle.kts](../../mobile/flutter_app/android/app/build.gradle.kts)

正式发布前必须：

1. 创建自己的 keystore
2. 配置 `signingConfigs.release`
3. 让 `buildTypes.release` 使用正式签名

## 8. 网络访问说明

当前主 `AndroidManifest.xml` 已包含：

- `INTERNET`
- `REQUEST_INSTALL_PACKAGES`
- cleartext traffic 配置

相关文件：

- [mobile/flutter_app/android/app/src/main/AndroidManifest.xml](../../mobile/flutter_app/android/app/src/main/AndroidManifest.xml)
- [mobile/flutter_app/android/app/src/main/res/xml/network_security_config.xml](../../mobile/flutter_app/android/app/src/main/res/xml/network_security_config.xml)

说明：

- 开发环境访问 HTTP 本地地址没问题
- 生产环境仍然建议切到 HTTPS API

## 9. 接入后端版本更新

移动端更新接口调用的是：

```text
GET /api/v1/mobile/latest-version
```

后端会根据 `mobile_version` 配置拼出：

```text
{public_base_url}/{bucket}/apk/{apk_filename}
```

也就是说，每次发版后要做两件事：

1. 上传 APK 到 MinIO 的 `apk/` 目录
2. 更新后端 `config.yaml` 中的：
   - `mobile_version.version`
   - `mobile_version.apk_filename`
   - `mobile_version.force_update`
   - `mobile_version.update_description`

## 10. 一个完整的发布示例

### 10.1 构建 APK

```bash
flutter build apk --release
```

### 10.2 重命名产物

例如改成：

```text
math-notebook-1.0.0.apk
```

### 10.3 上传到 MinIO

上传到：

```text
wrong-question-images/apk/math-notebook-1.0.0.apk
```

### 10.4 修改后端配置

```yaml
mobile_version:
  version: "1.0.0"
  apk_filename: "math-notebook-1.0.0.apk"
  force_update: false
  update_description: "新增相似题浏览与若干修复"
```

### 10.5 重启后端

```bash
sudo systemctl restart math-notebook-backend
```

### 10.6 验证接口

```bash
curl https://api.example.com/api/v1/mobile/latest-version
```

确认返回的 `apk_url` 可直接下载。

## 11. 发布前检查清单

- 已用 release keystore 签名
- `config/app_config.json` 已改成生产接口
- 登录流程可用
- 图片上传可用
- OCR 可用
- AI 分析可用
- 错题保存可用
- 相似题检索可用
- `/api/v1/mobile/latest-version` 正常返回
- `apk_url` 可下载
- 安卓设备允许安装更新包

## 12. 推荐验证命令

```bash
flutter analyze
flutter test
flutter build apk --release
```
