# CineFlow 跨平台构建和测试指南

## 环境要求

### 通用要求
- Flutter SDK 3.19.0+
- Dart SDK 3.3.0+
- Git 2.30+

### 平台特定要求

#### Android
- Android Studio 2023.1+
- Android SDK 34+
- Android NDK 25.1.8937393
- Java JDK 17+

#### iOS
- Xcode 15.0+
- iOS SDK 17.0+
- CocoaPods 1.12.0+
- macOS 12.0+ (构建环境)

#### Windows
- Visual Studio 2022 Community/Professional
- Windows 10 SDK (10.0.19041.0+)
- CMake 3.21+

#### macOS
- Xcode 15.0+
- macOS SDK 13.0+
- CMake 3.21+

#### Linux
- GCC 9.0+ 或 Clang 10.0+
- CMake 3.21+
- GTK 3.0+
- pkg-config
- ninja-build

## 项目初始化

### 1. 克隆项目
```bash
git clone <repository-url>
cd cineflow
```

### 2. 安装依赖
```bash
flutter pub get
```

### 3. 验证环境
```bash
flutter doctor -v
```

## 平台构建流程

### Android 构建

#### 开发构建
```bash
# Debug APK
flutter build apk --debug

# Profile APK
flutter build apk --profile

# Release APK
flutter build apk --release
```

#### AAB 构建 (Google Play)
```bash
flutter build appbundle --release
```

#### 签名配置
1. 创建 `android/key.properties`:
```properties
storePassword=<store-password>
keyPassword=<key-password>
keyAlias=<key-alias>
storeFile=<keystore-file-path>
```

2. 配置 `android/app/build.gradle`:
```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### iOS 构建

#### 开发构建
```bash
# 模拟器
flutter build ios --simulator

# 真机 Debug
flutter build ios --debug

# 真机 Release
flutter build ios --release
```

#### App Store 构建
```bash
flutter build ipa --release
```

#### 证书配置
1. 在 Xcode 中配置 Team ID
2. 设置 Bundle Identifier
3. 配置 Provisioning Profile

### Windows 构建

#### 开发构建
```bash
flutter build windows --debug
flutter build windows --profile
flutter build windows --release
```

#### 安装包构建
使用 Inno Setup 或 WiX Toolset:
```bash
# 生成 MSI 安装包
flutter pub run msix:create
```

### macOS 构建

#### 开发构建
```bash
flutter build macos --debug
flutter build macos --release
```

#### App Store 构建
```bash
flutter build macos --release
# 然后使用 Xcode 上传到 App Store Connect
```

#### 公证配置
```bash
# 代码签名
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" build/macos/Build/Products/Release/CineFlow.app

# 公证
xcrun notarytool submit build/macos/Build/Products/Release/CineFlow.app.zip --keychain-profile "notarytool-profile" --wait
```

### Linux 构建

#### 开发构建
```bash
flutter build linux --debug
flutter build linux --release
```

#### 打包构建
```bash
# AppImage
flutter pub run flutter_distributor:distribute --name appimage --jobs release-linux-appimage

# Snap
flutter pub run flutter_distributor:distribute --name snap --jobs release-linux-snap

# Flatpak
flutter pub run flutter_distributor:distribute --name flatpak --jobs release-linux-flatpak
```

## 测试流程

### 单元测试
```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/unit/session_manager_test.dart

# 生成覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 集成测试
```bash
# Android
flutter test integration_test/app_test.dart -d android

# iOS
flutter test integration_test/app_test.dart -d ios

# Windows
flutter test integration_test/app_test.dart -d windows

# macOS
flutter test integration_test/app_test.dart -d macos

# Linux
flutter test integration_test/app_test.dart -d linux
```

### 性能测试
```bash
# 性能分析
flutter run --profile --trace-startup --verbose

# 内存分析
flutter run --profile --enable-software-rendering
```

## 调试配置

### VS Code 配置 (.vscode/launch.json)
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "CineFlow (Debug)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "debug"
        },
        {
            "name": "CineFlow (Profile)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "profile"
        },
        {
            "name": "CineFlow (Release)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release"
        }
    ]
}
```

### Android Studio 配置
1. 创建运行配置
2. 设置目标设备
3. 配置启动参数

## 持续集成

### GitHub Actions 配置 (.github/workflows/build.yml)
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.19.0'
    - run: flutter pub get
    - run: flutter analyze
    - run: flutter test

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - uses: actions/setup-java@v3
      with:
        distribution: 'zulu'
        java-version: '17'
    - run: flutter pub get
    - run: flutter build apk --release

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - run: flutter pub get
    - run: flutter build ios --release --no-codesign

  build-windows:
    needs: test
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - run: flutter pub get
    - run: flutter build windows --release

  build-macos:
    needs: test
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - run: flutter pub get
    - run: flutter build macos --release

  build-linux:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
    - run: |
        sudo apt-get update -y
        sudo apt-get install -y ninja-build libgtk-3-dev
    - run: flutter pub get
    - run: flutter build linux --release
```

## 发布流程

### 版本管理
1. 更新 `pubspec.yaml` 中的版本号
2. 更新 `CHANGELOG.md`
3. 创建 Git 标签

### Android 发布
1. 构建 AAB: `flutter build appbundle --release`
2. 上传到 Google Play Console
3. 配置发布轨道
4. 提交审核

### iOS 发布
1. 构建 IPA: `flutter build ipa --release`
2. 使用 Xcode 上传到 App Store Connect
3. 配置应用信息
4. 提交审核

### Windows 发布
1. 构建 MSI: `flutter pub run msix:create`
2. 上传到 Microsoft Store
3. 或通过官网直接分发

### macOS 发布
1. 构建并公证应用
2. 上传到 App Store Connect
3. 或通过官网直接分发

### Linux 发布
1. 构建 AppImage/Snap/Flatpak
2. 上传到对应的应用商店
3. 或通过官网直接分发

## 故障排除

### 常见问题

#### Flutter Doctor 问题
```bash
# Android 许可证问题
flutter doctor --android-licenses

# iOS 开发者工具问题
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

#### 构建失败
```bash
# 清理构建缓存
flutter clean
flutter pub get

# 重新生成平台代码
flutter create --platforms=android,ios,windows,macos,linux .
```

#### 依赖冲突
```bash
# 更新依赖
flutter pub upgrade

# 解决版本冲突
flutter pub deps
```

### 日志收集
- Android: `adb logcat | grep flutter`
- iOS: Xcode Console
- Windows: Visual Studio Output
- macOS: Console.app
- Linux: Terminal output

## 性能优化

### 构建优化
- 启用 R8/ProGuard (Android)
- 启用 Tree Shaking
- 优化资源文件
- 使用 Profile 模式测试

### 运行时优化
- 内存泄漏检测
- 网络请求优化
- UI 渲染优化
- 电池使用优化

## 安全配置

### 网络安全
- HTTPS 证书验证
- WebRTC 安全配置
- 数据传输加密

### 应用安全
- 代码混淆
- 防逆向工程
- 敏感数据保护
