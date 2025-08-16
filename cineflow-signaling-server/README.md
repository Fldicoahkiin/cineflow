# CineFlow 信令服务器

基于 Node.js + Socket.io 的 WebRTC 信令服务器，用于 CineFlow P2P 连接建立。

## 功能特性

- **房间管理**: 创建和加入会话房间
- **WebRTC 信令**: SDP offer/answer 和 ICE candidate 交换
- **心跳机制**: 连接状态监控
- **自动清理**: 过期房间和连接清理
- **健康检查**: 服务器状态监控端点
- **跨域支持**: 完整的 CORS 配置

## 快速部署

### 本地开发

```bash
cd cineflow-signaling-server
npm install
npm run dev  # 开发模式（自动重启）
# 或
npm start    # 生产模式
```

### Railway 部署

1. **准备代码**
```bash
git add cineflow-signaling-server/
git commit -m "Add signaling server"
git push origin main
```

2. **部署到 Railway**
```bash
# 安装 Railway CLI
npm install -g @railway/cli

# 登录 Railway
railway login

# 初始化项目
railway init

# 选择从 GitHub 部署
# 设置根目录为 cineflow-signaling-server/

# 部署
railway up
```

3. **配置环境变量**
```bash
railway variables set NODE_ENV=production
railway variables set PORT=8080
```

4. **选择香港节点**
- 在 Railway 控制台选择 Asia Pacific 区域

## API 端点

### HTTP 端点

- `GET /` - 服务器状态和统计信息
- `GET /health` - 健康检查

### WebSocket 事件

#### 客户端发送

- `create_room` - 创建房间
  ```json
  { "roomId": "room123", "peerId": "peer456" }
  ```

- `join_room` - 加入房间
  ```json
  { "roomId": "room123", "peerId": "peer789" }
  ```

- `offer` - WebRTC offer
  ```json
  { "roomId": "room123", "offer": {...}, "targetPeer": "socketId" }
  ```

- `answer` - WebRTC answer
  ```json
  { "roomId": "room123", "answer": {...}, "targetPeer": "socketId" }
  ```

- `ice_candidate` - ICE 候选
  ```json
  { "roomId": "room123", "candidate": {...}, "targetPeer": "socketId" }
  ```

- `ping` - 心跳检测
  ```json
  { "timestamp": 1234567890 }
  ```

#### 服务器发送

- `room_created` - 房间创建成功
- `room_joined` - 加入房间成功
- `peer_joined` - 新用户加入
- `peer_left` - 用户离开
- `offer` - 转发的 offer
- `answer` - 转发的 answer
- `ice_candidate` - 转发的 ICE 候选
- `pong` - 心跳响应
- `error` - 错误信息

## 服务器配置

### 环境变量

- `PORT` - 服务器端口 (默认: 8080)
- `NODE_ENV` - 运行环境 (development/production)

### 特性

- **自动清理**: 24小时后清理空房间
- **错误处理**: 完整的错误捕获和日志
- **CORS 支持**: 支持跨域请求
- **健康监控**: 提供监控端点

## 使用示例

### Flutter 客户端配置

```dart
// 更新信令服务器地址
final signalingServers = [
  'wss://your-app.railway.app',  // Railway 部署地址
  'ws://localhost:8080',         // 本地开发
];
```

## 监控和日志

服务器提供详细的日志输出，包括：
- 连接和断开事件
- 房间创建和管理
- 消息转发状态
- 错误和异常信息

## 部署检查清单

- [ ] 代码推送到 GitHub
- [ ] Railway 项目创建
- [ ] 环境变量配置
- [ ] 香港节点选择
- [ ] 域名 HTTPS 配置
- [ ] Flutter 客户端地址更新
- [ ] 连接测试验证
