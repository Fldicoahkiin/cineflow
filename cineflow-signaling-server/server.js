const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// 配置CORS
app.use(cors({
  origin: true,
  credentials: true
}));

// 配置Socket.io
const io = socketIo(server, {
  cors: {
    origin: true,
    methods: ["GET", "POST"],
    credentials: true
  },
  transports: ['websocket', 'polling']
});

// 房间管理
const rooms = new Map();
const peerConnections = new Map();

// 日志函数
function log(message, data = null) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${message}`, data ? JSON.stringify(data, null, 2) : '');
}

// 健康检查端点
app.get('/', (req, res) => {
  res.json({
    status: 'CineFlow Signaling Server Running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    activeRooms: rooms.size,
    activePeers: peerConnections.size
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

// Socket.io连接处理
io.on('connection', (socket) => {
  log('Client connected', { socketId: socket.id });
  
  // 存储socket信息
  peerConnections.set(socket.id, {
    socketId: socket.id,
    roomId: null,
    peerId: null,
    connectedAt: new Date()
  });

  // 创建房间
  socket.on('create_room', (data) => {
    try {
      const { roomId, peerId } = data;
      log('Creating room', { roomId, peerId, socketId: socket.id });
      
      if (!roomId || !peerId) {
        socket.emit('error', { message: 'roomId and peerId are required' });
        return;
      }

      // 创建房间
      if (!rooms.has(roomId)) {
        rooms.set(roomId, {
          id: roomId,
          host: socket.id,
          peers: new Map(),
          createdAt: new Date()
        });
      }

      const room = rooms.get(roomId);
      room.peers.set(socket.id, {
        socketId: socket.id,
        peerId: peerId,
        isHost: true,
        joinedAt: new Date()
      });

      // 更新peer信息
      const peerInfo = peerConnections.get(socket.id);
      peerInfo.roomId = roomId;
      peerInfo.peerId = peerId;

      // 加入Socket.io房间
      socket.join(roomId);

      socket.emit('room_created', {
        roomId: roomId,
        peerId: peerId,
        isHost: true
      });

      log('Room created successfully', { roomId, peerId, socketId: socket.id });
    } catch (error) {
      log('Error creating room', { error: error.message, socketId: socket.id });
      socket.emit('error', { message: 'Failed to create room' });
    }
  });

  // 加入房间
  socket.on('join_room', (data) => {
    try {
      const { roomId, peerId } = data;
      log('Joining room', { roomId, peerId, socketId: socket.id });

      if (!roomId || !peerId) {
        socket.emit('error', { message: 'roomId and peerId are required' });
        return;
      }

      const room = rooms.get(roomId);
      if (!room) {
        socket.emit('error', { message: 'Room not found' });
        return;
      }

      // 添加到房间
      room.peers.set(socket.id, {
        socketId: socket.id,
        peerId: peerId,
        isHost: false,
        joinedAt: new Date()
      });

      // 更新peer信息
      const peerInfo = peerConnections.get(socket.id);
      peerInfo.roomId = roomId;
      peerInfo.peerId = peerId;

      // 加入Socket.io房间
      socket.join(roomId);

      // 通知房间内其他用户
      socket.to(roomId).emit('peer_joined', {
        peerId: peerId,
        socketId: socket.id
      });

      // 发送房间内现有用户列表
      const existingPeers = Array.from(room.peers.values())
        .filter(peer => peer.socketId !== socket.id)
        .map(peer => ({ peerId: peer.peerId, socketId: peer.socketId }));

      socket.emit('room_joined', {
        roomId: roomId,
        peerId: peerId,
        isHost: false,
        existingPeers: existingPeers
      });

      log('Joined room successfully', { 
        roomId, 
        peerId, 
        socketId: socket.id, 
        roomSize: room.peers.size 
      });
    } catch (error) {
      log('Error joining room', { error: error.message, socketId: socket.id });
      socket.emit('error', { message: 'Failed to join room' });
    }
  });

  // WebRTC信令消息转发
  socket.on('offer', (data) => {
    try {
      const { roomId, offer, targetPeer } = data;
      log('Forwarding offer', { roomId, targetPeer, socketId: socket.id });
      
      if (targetPeer) {
        socket.to(targetPeer).emit('offer', {
          offer: offer,
          fromPeer: socket.id
        });
      } else {
        socket.to(roomId).emit('offer', {
          offer: offer,
          fromPeer: socket.id
        });
      }
    } catch (error) {
      log('Error forwarding offer', { error: error.message });
    }
  });

  socket.on('answer', (data) => {
    try {
      const { roomId, answer, targetPeer } = data;
      log('Forwarding answer', { roomId, targetPeer, socketId: socket.id });
      
      if (targetPeer) {
        socket.to(targetPeer).emit('answer', {
          answer: answer,
          fromPeer: socket.id
        });
      } else {
        socket.to(roomId).emit('answer', {
          answer: answer,
          fromPeer: socket.id
        });
      }
    } catch (error) {
      log('Error forwarding answer', { error: error.message });
    }
  });

  socket.on('ice_candidate', (data) => {
    try {
      const { roomId, candidate, targetPeer } = data;
      log('Forwarding ICE candidate', { roomId, targetPeer, socketId: socket.id });
      
      if (targetPeer) {
        socket.to(targetPeer).emit('ice_candidate', {
          candidate: candidate,
          fromPeer: socket.id
        });
      } else {
        socket.to(roomId).emit('ice_candidate', {
          candidate: candidate,
          fromPeer: socket.id
        });
      }
    } catch (error) {
      log('Error forwarding ICE candidate', { error: error.message });
    }
  });

  // 心跳处理
  socket.on('ping', (data) => {
    socket.emit('pong', {
      timestamp: data.timestamp,
      serverTime: Date.now()
    });
  });

  // 断开连接处理
  socket.on('disconnect', (reason) => {
    try {
      log('Client disconnected', { socketId: socket.id, reason });
      
      const peerInfo = peerConnections.get(socket.id);
      if (peerInfo && peerInfo.roomId) {
        const room = rooms.get(peerInfo.roomId);
        if (room) {
          // 从房间中移除
          room.peers.delete(socket.id);
          
          // 通知房间内其他用户
          socket.to(peerInfo.roomId).emit('peer_left', {
            peerId: peerInfo.peerId,
            socketId: socket.id
          });

          // 如果房间为空，删除房间
          if (room.peers.size === 0) {
            rooms.delete(peerInfo.roomId);
            log('Room deleted (empty)', { roomId: peerInfo.roomId });
          }
        }
      }

      // 清理连接信息
      peerConnections.delete(socket.id);
    } catch (error) {
      log('Error handling disconnect', { error: error.message });
    }
  });

  // 错误处理
  socket.on('error', (error) => {
    log('Socket error', { error: error.message, socketId: socket.id });
  });
});

// 定期清理过期房间
setInterval(() => {
  const now = new Date();
  const maxAge = 24 * 60 * 60 * 1000; // 24小时

  for (const [roomId, room] of rooms.entries()) {
    if (now - room.createdAt > maxAge && room.peers.size === 0) {
      rooms.delete(roomId);
      log('Cleaned up expired room', { roomId });
    }
  }
}, 60 * 60 * 1000); // 每小时清理一次

// 启动服务器
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  log(`CineFlow Signaling Server started on port ${PORT}`);
  log('Server configuration', {
    port: PORT,
    nodeVersion: process.version,
    environment: process.env.NODE_ENV || 'development'
  });
});

// 优雅关闭
process.on('SIGTERM', () => {
  log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  log('SIGINT received, shutting down gracefully');
  server.close(() => {
    log('Server closed');
    process.exit(0);
  });
});
