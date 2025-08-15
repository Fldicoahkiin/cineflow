# CineFlow 项目技术详述文档

## 1. 产品定位

以本地视频文件播放为主，主打移动端体验的跨平台、无服务器同步播放应用。核心优势在于**简单、流畅、无审核**，为用户提供私密的同步观影体验。

### 1.1. 竞品分析摘要

| 产品 | 优点 | 缺点 | CineFlow 定位 |
| :--- | :--- | :--- | :--- |
| **Syncplay** | 功能强大，同步精准，开源社区活跃 | 缺少官方移动端，桌面端设置对新手不友好 | 借鉴其精准的同步协议，但提供移动优先、UI/UX 更佳的体验 |
| **VideoTogether** | 基于 Web，跨平台性好，使用简单 | 本地文件播放受限于浏览器，流畅度依赖主持人网络 | 提供原生应用的性能和流畅度，摆脱浏览器限制 |
| **Syncplay for Mobile** | 解决了 Syncplay 的移动端有无问题 | UI/UX 较为基础，可能专注于功能实现 | 在其基础上，提供更现代、更易用的交互设计和用户界面 |

## 2. 主要功能详述

一个基于点对点（Peer-to-Peer, P2P）架构的跨平台同步播放应用，支持 iOS、Android、Windows、macOS 和 Linux。用户可通过手动选择视频文件或让桌面端应用自动扫描指定目录来加载媒体。应用通过一个轻量级的信令服务器（Signaling Server）进行会话协商，一旦P2P连接建立，视频播放数据和控制信令将在用户之间直接传输，无需中心服务器中转。

### 2.1. 核心功能点

* **跨平台原生体验**: 使用单一代码库覆盖所有主流操作系统。
* **去中心化播放**: 视频播放控制（播放、暂停、搜寻）和时间轴同步信令通过 P2P 通道直接在客户端之间传输。
* **精准时间轴同步**:
  * **主持人权限管理**: 主持人（或被授权用户）作为时间轴的基准源。
  * **实时状态同步**: 主持人的播放、暂停、快进/快退操作被封装成标准化信令，广播给会话内所有客户端。
  * **延迟估算与补偿**: 客户端之间通过时间戳交换来计算网络往返延迟（Round-Trip Time, RTT）。 客户端接收到主持人带有时间戳的播放位置信令后，会结合估算的单向延迟（约 RTT/2），对本地播放器时间轴进行微调，从而实现多端画面的精准同步。
* **多样化媒体来源**:
  * **移动端**: 通过系统文件选择器手动选取视频文件。
  * **桌面端**: 支持手动选择文件，以及设定特定目录进行自动扫描和媒体库管理。
* **便捷的会话连接**:
  * **会话 ID**: 主持人创建会话后生成一个唯一的 ID，其他用户可通过输入此 ID 加入。
  * **二维码扫描**: 应用内生成包含会话 ID 的二维码，其他用户可通过扫码快速加入，简化移动端操作。

## 3. 技术框架

### 3.1. 技术栈

* **核心框架**: Flutter
* **P2P 通信**: WebRTC (通过 `flutter-webrtc` 插件实现)
* **视频播放**: `media_kit` 或 `video_player`
* **状态管理**: Riverpod 或 Bloc
* **本地文件处理**: `file_picker` (手动选择), `dart:io` (桌面端目录扫描)
* **二维码**: `qr_flutter` (生成), `flutter_zxing` (扫描)

### 3.2. 无服务器（P2P）架构详解

CineFlow 的 "无服务器" 指的是视频数据流和播放控制信令的传输是去中心化的。但是，为了让处于不同网络环境下的用户能够发现彼此并建立 P2P 连接，仍然需要一个**信令服务器（Signaling Server）**。

1. **会话创建 (主持人)**:
    * 主持人客户端向信令服务器发送请求，创建一个新的会话房间。
    * 信令服务器生成一个唯一的会话 ID，并将主持人注册到该房间。
    * 主持人客户端初始化本地 WebRTC `RTCPeerConnection` 对象。

2. **会话加入 (参与者)**:
    * 参与者通过输入会话 ID 或扫描二维码，向信令服务器请求加入指定房间。
    * 信令服务器通知房间内的所有成员（包括主持人）有新用户加入。

3. **P2P 连接建立 (WebRTC Handshake)**:
    * 新加入的参与者与房间内其他每个成员通过信令服务器交换 WebRTC 连接所需的元数据（SDP offers/answers 和 ICE candidates）。
    * WebRTC 尝试使用 STUN/TURN 服务器进行 NAT 穿透，在客户端之间建立直接的 `RTCDataChannel`。
    * 一旦 `RTCDataChannel` 建立，后续的播放控制信令将通过此通道直接传输，不再经过信令服务器。

4. **同步播放**:
    * 拥有权限的用户（例如主持人）在本地播放器上进行操作（如暂停在 15.3 秒）。
    * 该操作被封装成一个 JSON 消息，例如 `{"event": "pause", "position": 15.3, "timestamp": 1678886400123}`，并附上当前系统时间戳。
    * 此消息通过 `RTCDataChannel` 广播给所有其他对等端。
    * 接收端收到消息后，计算消息传输延迟，并命令本地播放器执行相应操作（例如，暂停并精确跳转到 15.3 秒 + 估算延迟的位置）。

## 4. 功能实现与代码任务清单 (List for Agent)

### 模块 1: 核心 P2P 网络

* **任务 1.1: 整合 WebRTC 插件**
  * **描述**: 在 `pubspec.yaml` 中添加 `flutter_webrtc` 依赖。
  * **代码/指令**: `flutter pub add flutter_webrtc`
  * **验收标准**: 能够在各平台项目中成功编译，并能创建 `RTCPeerConnection` 对象。

* **任务 1.2: 实现信令客户端 (Signaling Client)**
  * **描述**: 创建一个 `SignalingClient` 类，使用 `web_socket_channel` 连接信令服务器。该类需要处理创建房间、加入房间、发送和接收 SDP/ICE candidate 消息的逻辑。
  * **代码框架**:

        ```dart
        class SignalingClient {
          final WebSocketChannel _channel;
          Function(RTCSessionDescription description) onOffer;
          Function(RTCSessionDescription description) onAnswer;
          Function(RTCIceCandidate candidate) onCandidate;

          SignalingClient(String url) : _channel = WebSocketChannel.connect(Uri.parse(url));

          void send(Map<String, dynamic> message) {
            _channel.sink.add(jsonEncode(message));
          }

          void listen() {
            _channel.stream.listen((message) {
              final data = jsonDecode(message);
              // 处理传入的 offers, answers, candidates
            });
          }
        }
        ```

* **任务 1.3: 创建会话管理逻辑 (Session Manager)**
  * **描述**: 创建一个 `SessionManager` 类，负责管理 `RTCPeerConnection` 的生命周期。它将使用 `SignalingClient` 来协商连接，并为每个对等端维护一个 `RTCPeerConnection` 实例。
  * **代码框架**:

        ```dart
        class SessionManager {
          final SignalingClient _signaling;
          final Map<String, RTCPeerConnection> _peerConnections = {};
          final String _selfId;

          Future<void> createPeerConnection(String peerId) async {
            RTCPeerConnection pc = await createPeerConnection({
              'iceServers': [
                {'urls': 'stun:stun.l.google.com:19302'},
              ]
            });
            // ... 设置 onIceCandidate, onDataChannel 等监听器
            _peerConnections[peerId] = pc;
          }
        }
        ```

* **任务 1.4: 实现 P2P 数据通道**
  * **描述**: 在 `RTCPeerConnection` 上创建 `RTCDataChannel`，用于发送和接收播放控制命令。
  * **代码片段**:

        ```dart
        // 在 SessionManager 中，创建 RTCPeerConnection 之后
        RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
        RTCDataChannel dataChannel = await pc.createDataChannel('control', dataChannelDict);

        dataChannel.onMessage = (RTCDataChannelMessage message) {
          // 处理传入的同步命令 (play, pause, seek)
        };
        ```

### 模块 2: 视频播放与控制

* **任务 2.1: 整合视频播放库**
  * **描述**: 添加 `media_kit` 依赖，并创建一个基础的视频播放器 widget。
  * **代码/指令**: `flutter pub add media_kit`
  * **验收标准**: 能够从本地文件路径加载并播放视频。

* **任务 2.2: 创建统一的播放器控制接口**
  * **描述**: 实现一个 `PlayerController` 类，封装 `media_kit` 的 `Player` 对象。该控制器将提供 `play()`, `pause()`, `seek(Duration position)`, `getPosition()` 等方法，并将用户操作转换为同步信令发送到 `SessionManager`。
  * **代码框架**:

        ```dart
        class PlayerController {
          final Player _player;
          final SessionManager _sessionManager;

          void play() {
            _player.play();
            _sessionManager.broadcastCommand({'event': 'play', 'position': _player.state.position.inMilliseconds});
          }
          // ... 其他方法
        }
        ```

* **任务 2.3: 实现本地文件处理**
  * **描述**: 在移动端使用 `file_picker` 让用户选择视频。在桌面端，使用 `dart:io` 的 `Directory` 和 `FileSystemEntity` API 扫描指定文件夹下的视频文件。
  * **代码/指令**: `flutter pub add file_picker`
  * **代码片段 (桌面端扫描)**:

        ```dart
        Future<List<File>> scanDirectory(String path) async {
          final dir = Directory(path);
          final List<File> videoFiles = [];
          await for (var entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File && _isVideoFile(entity.path)) {
              videoFiles.add(entity);
            }
          }
          return videoFiles;
        }
        bool _isVideoFile(String path) => ['.mp4', '.mkv', '.avi'].any((ext) => path.toLowerCase().endsWith(ext));
        ```

### 模块 3: 同步逻辑

* **任务 3.1: 定义播放状态命令协议**
  * **描述**: 以 JSON 格式定义清晰的 P2P 消息结构，包括事件类型（play, pause, seek）、播放位置、时间戳等。
  * **数据结构示例**:

        ```json
        {
          "type": "state_update",
          "payload": {
            "isPlaying": true,
            "position": 123456, // 单位：毫秒
            "timestamp": 1678886400123 // UTC 毫秒
          }
        }
        ```

* **任务 3.2: 实现延迟估算 (RTT)**
  * **描述**: 定期通过 `RTCDataChannel` 发送一个带有发送时间戳的 `ping` 消息。接收方收到后立即返回一个 `pong` 消息。发送方根据接收到 `pong` 的时间计算 RTT。
  * **代码框架**:

        ```dart
        // 发送方
        void sendPing() {
          final payload = {'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch};
          _dataChannel.send(RTCDataChannelMessage(jsonEncode(payload)));
        }

        // 接收方, 在 onMessage 处理器中
        if (data['type'] == 'ping') {
          final pongPayload = {'type': 'pong', 'timestamp': data['timestamp']};
          _dataChannel.send(RTCDataChannelMessage(jsonEncode(pongPayload)));
        } else if (data['type'] == 'pong') {
          final rtt = DateTime.now().millisecondsSinceEpoch - data['timestamp'];
          // 更新 RTT 值
        }
        ```

* **任务 3.3: 实现时间轴补偿算法**
  * **描述**: 当客户端接收到主持人的 `state_update` 命令时，它会执行以下计算：`estimated_server_time = message.timestamp + (rtt / 2)`。然后计算出视频应该在的位置：`target_position = message.position + (DateTime.now().millisecondsSinceEpoch - estimated_server_time)`。最后命令本地播放器 `seek` 到 `target_position`。
  * **代码框架**:

        ```dart
        // 在 'state_update' 的 onMessage 处理器中
        final payload = data['payload'];
        final rtt = _sessionManager.getRTT(); // 获取平均 RTT
        final estimatedServerTime = payload['timestamp'] + (rtt / 2);
        final timeSinceUpdate = DateTime.now().millisecondsSinceEpoch - estimatedServerTime;
        final targetPosition = payload['position'] + (payload['isPlaying'] ? timeSinceUpdate : 0);

        _playerController.seek(Duration(milliseconds: targetPosition.round()));
        if (payload['isPlaying']) {
          _playerController.play();
        } else {
          _playerController.pause();
        }
        ```

### 模块 4: 用户界面与体验

* **任务 4.1: 实现创建/加入会话界面**
  * **描述**: 创建一个包含 "创建会话" 和 "加入会话" 按钮的页面。点击加入时，弹出对话框要求输入会话 ID。
  * **验收标准**: UI 布局清晰，功能可交互。

* **任务 4.2: 实现二维码生成与扫描**
  * **描述**: 主持人创建会话后，在界面上使用 `qr_flutter` widget 显示包含会话 ID 的二维码。加入方可以启动一个使用 `flutter_zxing` 的扫描页面来读取二维码并自动填入会话 ID。
  * **代码/指令**: `flutter pub add qr_flutter flutter_zxing`

* **任务 4.3: 实现主持人权限控制**
  * **描述**: 在会话数据结构中增加一个 `hostId` 和一个 `adminIds` 列表。只有 ID 在这些列表中的用户发送的控制命令才被其他客户端接受和执行。
  * **验收标准**: 非权限用户的操作不会影响其他人的播放进度。

## 5. 后续拓展规划

* **会话密码**: 在信令服务器的 "加入房间" 逻辑中增加密码验证。客户端在加入时需额外提供密码字段。
* **多人讨论**: 在 P2P 数据通道中增加一种新的消息类型 `chat_message`，并在 UI 上实现一个聊天面板。
* **视频预下载**:
  * **主持人提供链接**: 主持人将下载链接通过 `RTCDataChannel` 广播。客户端接收到链接后，使用 `background_downloader` 等插件在后台下载文件。
  * **中转服务器**: 这是付费功能。用户可以将文件上传到官方提供的临时存储，服务器生成一个唯一的资源 ID。此 ID 随会话信息分发，其他用户通过此 ID 从中转服务器高速下载。
* **字幕同步**: 加载外部字幕文件（如 .srt）。同步时，除了播放位置，还需同步当前选择的字幕轨道。
* **倍速播放**: 在 `state_update` 消息中增加 `playback_rate` 字段，同步所有客户端的播放速率。`video_player` 和 `media_kit` 均支持此功能。

## 6. 付费点

* **官方下载中转服务器**:
  * **技术实现**: 需要一个后端服务（如 Node.js + S3/GCS）来处理文件上传、存储和分发。
  * **流程**: 主持人上传视频 -> 后端返回资源 ID -> 主持人将 ID 分享到会话 -> 其他用户通过此 ID 向后端请求下载 -> 后端提供带有 CDN 加速的下载链接。
  * **价值**: 为网络环境不佳或不想提前下载视频的用户提供便利，是核心的增值服务。
