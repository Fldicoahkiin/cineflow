import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 信令客户端
/// 提供企业级的连接管理、错误处理和重连机制
class SignalingClient {
  SignalingClient(this.url, {
    this.reconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 2),
    this.connectionTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  final String url;
  final int reconnectAttempts;
  final Duration reconnectDelay;
  final Duration connectionTimeout;
  final Duration heartbeatInterval;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  int _currentReconnectAttempt = 0;
  bool _isDisposed = false;
  bool _isConnecting = false;
  DateTime? _lastHeartbeat;

  // 回调函数
  void Function(Map<String, dynamic> data)? onMessage;
  void Function(Object error, StackTrace? stackTrace)? onError;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  void Function(int attempt, int maxAttempts)? onReconnecting;

  /// 连接状态
  ConnectionState get connectionState {
    if (_isDisposed) return ConnectionState.disposed;
    if (_isConnecting) return ConnectionState.connecting;
    if (_channel != null) return ConnectionState.connected;
    return ConnectionState.disconnected;
  }

  bool get isConnected => connectionState == ConnectionState.connected;

  /// 建立连接
  Future<void> connect() async {
    if (_isDisposed) {
      throw StateError('SignalingClient has been disposed');
    }
    
    if (_isConnecting) {
      debugPrint('[SignalingClient] Already connecting, ignoring duplicate request');
      return;
    }

    await disconnect();
    _isConnecting = true;
    _currentReconnectAttempt = 0;

    try {
      await _attemptConnection();
    } catch (e, stackTrace) {
      _isConnecting = false;
      onError?.call(e, stackTrace);
      rethrow;
    }
  }

  /// 尝试建立连接
  Future<void> _attemptConnection() async {
    try {
      debugPrint('[SignalingClient] Connecting to $url');
      
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['cineflow-signaling-v1'],
      );

      // 设置连接超时
      final connectionCompleter = Completer<void>();
      Timer? timeoutTimer;
      
      _sub = _channel!.stream.listen(
        (event) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete();
            timeoutTimer?.cancel();
            _onConnectionEstablished();
          }
          _handleMessage(event);
        },
        onError: (error, stackTrace) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(error, stackTrace);
            timeoutTimer?.cancel();
          }
          _handleConnectionError(error, stackTrace);
        },
        onDone: () {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(
              const SocketException('Connection closed unexpectedly')
            );
            timeoutTimer?.cancel();
          }
          _handleDisconnection();
        },
        cancelOnError: false,
      );

      // 连接超时处理
      timeoutTimer = Timer(connectionTimeout, () {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.completeError(
            TimeoutException('Connection timeout', connectionTimeout)
          );
          disconnect();
        }
      });

      await connectionCompleter.future;
    } catch (e, stackTrace) {
      await disconnect();
      throw SignalingException('Failed to connect to $url', e, stackTrace);
    }
  }

  /// 连接建立成功处理
  void _onConnectionEstablished() {
    _isConnecting = false;
    _currentReconnectAttempt = 0;
    _lastHeartbeat = DateTime.now();
    
    debugPrint('[SignalingClient] Connected successfully');
    onConnected?.call();
    _startHeartbeat();
  }

  /// 发送消息（Map 会被编码为 JSON 字符串）
  void send(Map<String, dynamic> message) {
    if (_isDisposed) {
      throw StateError('SignalingClient has been disposed');
    }
    
    final ch = _channel;
    if (ch == null || connectionState != ConnectionState.connected) {
      throw StateError('WebSocket is not connected');
    }

    try {
      final jsonString = jsonEncode(message);
      ch.sink.add(jsonString);
      debugPrint('[SignalingClient] Sent: ${jsonString.length > 200 ? '${jsonString.substring(0, 200)}...' : jsonString}');
    } catch (e, stackTrace) {
      onError?.call(SignalingException('Failed to send message', e, stackTrace), stackTrace);
      rethrow;
    }
  }

  /// 处理接收到的消息
  void _handleMessage(dynamic event) {
    try {
      _lastHeartbeat = DateTime.now();
      
      final decoded = event is String ? jsonDecode(event) : event;
      if (decoded is Map<String, dynamic>) {
        debugPrint('[SignalingClient] Received: ${event.toString().length > 200 ? '${event.toString().substring(0, 200)}...' : event}');
        onMessage?.call(decoded);
      } else {
        debugPrint('[SignalingClient] Received non-JSON message: $event');
      }
    } catch (e, stackTrace) {
      onError?.call(SignalingException('Failed to parse message', e, stackTrace), stackTrace);
    }
  }

  /// 处理连接错误
  void _handleConnectionError(Object error, StackTrace? stackTrace) {
    debugPrint('[SignalingClient] Connection error: $error');
    onError?.call(error, stackTrace);
    
    if (!_isDisposed && connectionState == ConnectionState.connected) {
      _scheduleReconnect();
    }
  }

  /// 处理连接断开
  void _handleDisconnection() {
    debugPrint('[SignalingClient] Connection closed');
    _stopHeartbeat();
    onDisconnected?.call();
    
    if (!_isDisposed && !_isConnecting) {
      _scheduleReconnect();
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_currentReconnectAttempt >= reconnectAttempts) {
      debugPrint('[SignalingClient] Max reconnect attempts reached');
      return;
    }

    _currentReconnectAttempt++;
    final delay = Duration(
      milliseconds: reconnectDelay.inMilliseconds * _currentReconnectAttempt,
    );
    
    debugPrint('[SignalingClient] Scheduling reconnect attempt $_currentReconnectAttempt/$reconnectAttempts in ${delay.inSeconds}s');
    onReconnecting?.call(_currentReconnectAttempt, reconnectAttempts);
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        _attemptConnection().catchError((e, stackTrace) {
          onError?.call(e, stackTrace);
        });
      }
    });
  }

  /// 开始心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_isDisposed || connectionState != ConnectionState.connected) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      if (_lastHeartbeat != null && 
          now.difference(_lastHeartbeat!).inMilliseconds > heartbeatInterval.inMilliseconds * 2) {
        debugPrint('[SignalingClient] Heartbeat timeout, reconnecting');
        _scheduleReconnect();
        return;
      }
      
      try {
        send({
          'type': 'ping',
          'timestamp': now.millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('[SignalingClient] Failed to send heartbeat: $e');
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 关闭连接
  Future<void> disconnect() async {
    debugPrint('[SignalingClient] Disconnecting');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    
    await _sub?.cancel();
    _sub = null;
    
    try {
      await _channel?.sink.close(1000, 'Normal closure');
    } catch (e) {
      debugPrint('[SignalingClient] Error closing WebSocket: $e');
    }
    _channel = null;
    _isConnecting = false;
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    debugPrint('[SignalingClient] Disposing');
    _isDisposed = true;
    
    await disconnect();
    
    // 清理回调
    onMessage = null;
    onError = null;
    onConnected = null;
    onDisconnected = null;
    onReconnecting = null;
  }
}

/// 连接状态枚举
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disposed,
}

/// 信令异常类
class SignalingException implements Exception {
  const SignalingException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'SignalingException: $message\nCaused by: $cause';
    }
    return 'SignalingException: $message';
  }
}

typedef VoidCallback = void Function();
