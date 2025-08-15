import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'session_manager.dart';
import '../network/messages.dart' as proto;

/// 本地环回服务
/// 提供企业级的P2P连接测试和状态同步功能
class LoopbackService {
  LoopbackService({
    this.connectionTimeout = const Duration(seconds: 15),
    this.maxRetryAttempts = 3,
  });

  final Duration connectionTimeout;
  final int maxRetryAttempts;

  final SessionManager a = SessionManager();
  final SessionManager b = SessionManager();

  bool _isSetup = false;
  bool _isDisposed = false;
  Timer? _setupTimeoutTimer;
  final List<StreamSubscription> _subscriptions = [];
  final Map<String, DateTime> _pendingPings = {};

  // 事件回调
  void Function(String log)? onLog;
  void Function(RTCDataChannelMessage msg)? onMessageA;
  void Function(RTCDataChannelMessage msg)? onMessageB;
  void Function(String receiver, int rttMs)? onRtt;
  void Function(String receiver, proto.StateUpdatePayload payload)? onStateUpdate;
  void Function(LoopbackException error)? onError;

  /// 服务状态
  LoopbackState get state {
    if (_isDisposed) return LoopbackState.disposed;
    if (_isSetup) return LoopbackState.ready;
    return LoopbackState.initializing;
  }

  bool get isReady => state == LoopbackState.ready;

  /// 初始化环回服务
  Future<void> setup() async {
    if (_isDisposed) {
      throw StateError('LoopbackService has been disposed');
    }
    
    if (_isSetup) {
      _log('Service already setup, skipping');
      return;
    }

    _log('Initializing loopback service');
    
    try {
      await _setupWithTimeout();
      _isSetup = true;
      _log('Loopback service ready');
    } catch (e, stackTrace) {
      final error = LoopbackException('Failed to setup loopback service', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 带超时的初始化
  Future<void> _setupWithTimeout() async {
    final completer = Completer<void>();
    
    _setupTimeoutTimer = Timer(connectionTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Setup timeout', connectionTimeout)
        );
      }
    });

    try {
      await _performSetup();
      
      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (e, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
    } finally {
      _setupTimeoutTimer?.cancel();
      _setupTimeoutTimer = null;
    }

    await completer.future;
  }

  /// 执行实际的初始化过程
  Future<void> _performSetup() async {
    _log('Initializing Peer A and Peer B');

    // 初始化 PeerConnections
    await a.initPeerConnection();
    await b.initPeerConnection();

    // 设置连接状态监听
    a.onConnectionStateChanged = (state) {
      _log('Peer A connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleError(LoopbackException('Peer A connection failed'));
      }
    };
    
    b.onConnectionStateChanged = (state) {
      _log('Peer B connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleError(LoopbackException('Peer B connection failed'));
      }
    };

    // 互相转发 ICE 候选
    a.onIceCandidate = (pc, cand) {
      _log('A->B ICE: ${_truncateString(cand.candidate ?? '', 50)}');
      _safeExecute(() => b.addRemoteIceCandidate(cand));
    };
    
    b.onIceCandidate = (pc, cand) {
      _log('B->A ICE: ${_truncateString(cand.candidate ?? '', 50)}');
      _safeExecute(() => a.addRemoteIceCandidate(cand));
    };

    // 绑定 DataChannel 消息回调
    a.onDataMessage = (msg) {
      _log('A<- ${_msgPreview(msg)}');
      onMessageA?.call(msg);
      _handleIncoming('A', msg);
    };
    
    b.onDataMessage = (msg) {
      _log('B<- ${_msgPreview(msg)}');
      onMessageB?.call(msg);
      _handleIncoming('B', msg);
    };

    // A 主动创建 control DataChannel
    await a.createControlDataChannel();

    // SDP 交换
    await _performSdpExchange();
    
    // 等待 DataChannel 就绪
    await _waitForDataChannelReady();
  }

  /// 执行 SDP 交换
  Future<void> _performSdpExchange() async {
    _log('Starting SDP exchange');
    
    final offer = await a.createOffer();
    _log('Offer generated: ${_truncateString(offer.sdp ?? '', 50)}...');

    await b.setRemoteDescription(offer);
    final answer = await b.createAnswer();
    _log('Answer generated: ${_truncateString(answer.sdp ?? '', 50)}...');

    await a.setRemoteDescription(answer);
    _log('SDP exchange completed');
  }

  /// 等待 DataChannel 就绪
  Future<void> _waitForDataChannelReady() async {
    const maxWaitTime = Duration(seconds: 10);
    const checkInterval = Duration(milliseconds: 100);
    
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < maxWaitTime) {
      if (a.hasDataChannel && b.hasDataChannel) {
        _log('DataChannels are ready');
        return;
      }
      
      await Future.delayed(checkInterval);
    }
    
    throw TimeoutException('DataChannel setup timeout', maxWaitTime);
  }

  /// 从 A 发送状态更新
  Future<void> sendStateUpdateFromA({required bool isPlaying, required int positionMs}) async {
    _validateReady();
    
    try {
      final payload = proto.StateUpdatePayload(
        isPlaying: isPlaying,
        positionMs: positionMs,
        timestampUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      final msg = proto.makeStateUpdate(payload);
      final jsonMsg = jsonEncode(msg);
      
      a.sendText(jsonMsg);
      _log('A-> ${_truncateString(jsonMsg, 100)}');
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to send state update from A', e, stackTrace));
      rethrow;
    }
  }

  /// 从 B 发送状态更新
  Future<void> sendStateUpdateFromB({required bool isPlaying, required int positionMs}) async {
    _validateReady();
    
    try {
      final payload = proto.StateUpdatePayload(
        isPlaying: isPlaying,
        positionMs: positionMs,
        timestampUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      final msg = proto.makeStateUpdate(payload);
      final jsonMsg = jsonEncode(msg);
      
      b.sendText(jsonMsg);
      _log('B-> ${_truncateString(jsonMsg, 100)}');
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to send state update from B', e, stackTrace));
      rethrow;
    }
  }

  /// 从 A 发送测试消息
  Future<void> sendTestFromA() async {
    _validateReady();
    
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pingId = 'ping_a_$now';
      _pendingPings[pingId] = DateTime.now();
      
      final msg = proto.makePing(now);
      final jsonMsg = jsonEncode(msg);
      
      a.sendText(jsonMsg);
      _log('A-> ${_truncateString(jsonMsg, 100)}');
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to send test from A', e, stackTrace));
      rethrow;
    }
  }

  /// 从 B 发送测试消息
  Future<void> sendTestFromB() async {
    _validateReady();
    
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pingId = 'ping_b_$now';
      _pendingPings[pingId] = DateTime.now();
      
      final msg = proto.makePing(now);
      final jsonMsg = jsonEncode(msg);
      
      b.sendText(jsonMsg);
      _log('B-> ${_truncateString(jsonMsg, 100)}');
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to send test from B', e, stackTrace));
      rethrow;
    }
  }

  /// 验证服务是否就绪
  void _validateReady() {
    if (_isDisposed) {
      throw StateError('LoopbackService has been disposed');
    }
    if (!_isSetup) {
      throw StateError('LoopbackService is not setup. Call setup() first.');
    }
  }

  /// 安全执行异步操作
  Future<void> _safeExecute(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Operation failed', e, stackTrace));
    }
  }

  /// 处理错误
  void _handleError(LoopbackException error) {
    debugPrint('[LoopbackService] Error: $error');
    onError?.call(error);
  }

  /// 记录日志
  void _log(String message) {
    debugPrint('[LoopbackService] $message');
    onLog?.call(message);
  }

  /// 截断字符串
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// 消息预览
  String _msgPreview(RTCDataChannelMessage msg) {
    if (msg.isBinary) return '<binary ${msg.binary.length} bytes>';
    return _truncateString(msg.text, 80);
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _log('Disposing loopback service');
    _isDisposed = true;
    
    _setupTimeoutTimer?.cancel();
    _setupTimeoutTimer = null;
    
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    
    _pendingPings.clear();
    
    await Future.wait([
      a.dispose(),
      b.dispose(),
    ]);
    
    // 清理回调
    onLog = null;
    onMessageA = null;
    onMessageB = null;
    onRtt = null;
    onStateUpdate = null;
    onError = null;
  }

  /// 处理接收到的消息
  void _handleIncoming(String receiver, RTCDataChannelMessage msg) {
    if (_isDisposed) return;
    
    try {
      if (msg.isBinary) {
        _log('$receiver received binary message (${msg.binary.length} bytes)');
        return;
      }
      
      final text = msg.text;
      if (text.isEmpty) {
        _log('$receiver received empty message');
        return;
      }
      
      Map<String, dynamic> data;
      try {
        data = jsonDecode(text) as Map<String, dynamic>;
      } catch (e) {
        _log('$receiver received invalid JSON, ignoring: ${_truncateString(text, 50)}');
        return;
      }

      final type = data['type'] as String?;
      if (type == null) {
        _log('$receiver received message without type field');
        return;
      }

      switch (type) {
        case proto.MsgType.ping:
          _handlePingMessage(receiver, data);
          break;
        case proto.MsgType.pong:
          _handlePongMessage(receiver, data);
          break;
        case proto.MsgType.stateUpdate:
          _handleStateUpdateMessage(receiver, data);
          break;
        default:
          _log('$receiver received unknown message type: $type');
          break;
      }
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to handle incoming message', e, stackTrace));
    }
  }

  /// 处理 ping 消息
  void _handlePingMessage(String receiver, Map<String, dynamic> data) {
    final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
    final pong = proto.makePong(ts);
    final jsonPong = jsonEncode(pong);
    
    try {
      if (receiver == 'A') {
        // A 收到 ping，B 发送 pong
        b.sendText(jsonPong);
        _log('B-> ${_truncateString(jsonPong, 100)}');
      } else {
        // B 收到 ping，A 发送 pong
        a.sendText(jsonPong);
        _log('A-> ${_truncateString(jsonPong, 100)}');
      }
    } catch (e, stackTrace) {
      _handleError(LoopbackException('Failed to send pong response', e, stackTrace));
    }
  }

  /// 处理 pong 消息
  void _handlePongMessage(String receiver, Map<String, dynamic> data) {
    final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rtt = now - ts;
    
    // 清理对应的 pending ping
    final pingId = 'ping_${receiver.toLowerCase()}_$ts';
    _pendingPings.remove(pingId);
    
    _log('$receiver RTT: ${rtt}ms');
    onRtt?.call(receiver, rtt);
  }

  /// 处理状态更新消息
  void _handleStateUpdateMessage(String receiver, Map<String, dynamic> data) {
    final payloadMap = (data['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    
    try {
      final payload = proto.StateUpdatePayload.fromJson(payloadMap);
      onStateUpdate?.call(receiver, payload);
    } catch (e, stackTrace) {
      _log('$receiver failed to parse state_update: $e');
      _handleError(LoopbackException('Failed to parse state update', e, stackTrace));
    }
  }
}

/// 环回服务状态
enum LoopbackState {
  initializing,
  ready,
  disposed,
}

/// 环回服务异常
class LoopbackException implements Exception {
  const LoopbackException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'LoopbackException: $message\nCaused by: $cause';
    }
    return 'LoopbackException: $message';
  }
}
