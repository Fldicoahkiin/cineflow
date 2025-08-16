# CineFlow

跨平台无服务器同步播放应用，支持 iOS、Android、Windows、macOS、Linux。

## 项目简介

以本地下载为主的跨平台同步播放应用，核心特点：简单、流畅、无审核。用户可以通过选择视频或将视频放入固定目录来使用，两人或多人进入同一会话后可实现视频的精准时间轴同步。

## 功能特性

- **精准时间轴同步**: 通过延迟估算与补偿算法保证画面几乎同时
- **主持人权限管理**: 拥有管理权限的人可以控制播放、暂停、快进等操作
- **多平台支持**: iOS、Android、Windows、macOS、Linux
- **便捷连接方式**: 通过会话 ID 或二维码建立连接
- **本地文件支持**: 手动选择文件或桌面端自动扫描目录
- **无服务器架构**: 基于 WebRTC P2P 连接，无需自建服务器

## 技术栈

- **框架**: Flutter 跨平台开发
- **通信**: flutter_webrtc + WebSocket 信令服务
- **播放器**: media_kit 多媒体播放
- **状态管理**: 自定义状态服务
- **文件处理**: file_picker + path 文件管理
- **网络**: web_socket_channel WebSocket 连接
- **UI设计**: Material Design 3.0 设计语言

## 项目结构

```
lib/
  core/              # 核心服务（状态管理、文件服务、应用管理）
  network/           # 网络通信（信令客户端、消息协议）
  session/           # 会话管理（P2P连接、环回服务）
  player/            # 播放器控制
  ui/                # 用户界面
  main.dart          # 应用入口
```

## 快速开始

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
flutter run
```

### 开发顺序
1. WebSocket 信令连接
2. WebRTC P2P 连接建立
3. 播放器同步控制
4. 用户界面优化

## 相似产品

- [Syncplay for Mobile](https://github.com/yuroyami/syncplay-mobile/)
- [Syncplay](https://github.com/Syncplay/syncplay)
- [VideoTogether](https://videotogether.github.io/zh-cn/guide/local.html)

## 开发进度

- ✅ 基础框架搭建
- ✅ 状态管理服务
- ✅ 文件管理服务
- ✅ 播放器控制器
- ✅ WebSocket 信令客户端
- ✅ P2P 连接建立
- ✅ 会话管理系统
- ✅ Material Design 3.0 UI 重构
- ✅ 代码质量优化和清理
- 🚧 同步播放控制
- 📋 跨平台测试优化

## UI/UX 设计

CineFlow 采用 **Material Design 3.0** 设计语言，确保在所有平台上提供一致、现代的用户体验：

### 设计原则
- **简洁清晰**: 界面布局简洁，功能分区明确
- **一致性**: 跨平台统一的视觉语言和交互模式
- **可访问性**: 支持不同用户群体的使用需求
- **响应式**: 适配不同屏幕尺寸和设备类型

### 视觉特色
- **色彩系统**: 采用蓝色、紫色、绿色、橙色等语义化配色
- **卡片布局**: 使用 Material Card 组件分组功能模块
- **图标系统**: 统一使用 Material Icons 图标库
- **动效反馈**: 连接状态、加载进度等提供动画反馈

### 参考设计
UI 设计参考了 [LocalSend](https://localsend.org/) 的简洁风格，结合 P2P 应用的特点进行优化。

## 后续拓展

- 会话密码
- 多人讨论
- 视频预下载（主持人设置下载链接或用户配置中转服务器）
- 字幕同步
- 倍速播放
- 更多播放格式和协议支持

## 任务清单

详细任务进度请查看 `TODO.md` 文件。
