import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 会话管理器
/// 提供WebRTC连接管理、状态监控和错误恢复机制
class SessionManager {
  SessionManager({
    this.connectionTimeout = const Duration(seconds: 30),
    this.iceGatheringTimeout = const Duration(seconds: 10),
    this.dataChannelTimeout = const Duration(seconds: 15),
  });

  final Duration connectionTimeout;
  final Duration iceGatheringTimeout;
  final Duration dataChannelTimeout;

  RTCPeerConnection? _pc;
  RTCDataChannel? _controlDc;
  Timer? _connectionTimeoutTimer;
  Timer? _iceGatheringTimer;
  
  bool _isDisposed = false;
  SessionManagerState _currentState = SessionManagerState.idle;
  SessionException? _lastError;
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _isRemoteDescriptionSet = false;

  // 事件回调
  void Function(RTCDataChannelMessage message)? onDataMessage;
  void Function(RTCPeerConnectionState state)? onConnectionStateChanged;
  void Function(RTCPeerConnection pc, RTCIceCandidate candidate)? onIceCandidate;
  void Function(RTCDataChannelState state)? onDataChannelState;
  void Function(SessionManagerState state)? onSessionStateChanged;
  void Function(SessionException error)? onError;

  // 状态属性
  bool get hasPeerConnection => _pc != null;
  bool get hasDataChannel => _controlDc != null && _controlDc!.state == RTCDataChannelState.RTCDataChannelOpen;
  SessionManagerState get currentState => _currentState;
  SessionException? get lastError => _lastError;
  bool get isConnected => _currentState == SessionManagerState.connected;
  bool get canSendData => hasDataChannel && isConnected;

  /// 初始化PeerConnection
  Future<RTCPeerConnection> initPeerConnection() async {
    if (_isDisposed) {
      throw StateError('SessionManager has been disposed');
    }

    await dispose();
    _updateState(SessionManagerState.initializing);
    
    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'iceCandidatePoolSize': 10,
      });

      _setupPeerConnectionListeners(pc);
      _pc = pc;
      
      _updateState(SessionManagerState.initialized);
      debugPrint('[SessionManager] PeerConnection initialized');
      
      return pc;
    } catch (e, stackTrace) {
      final error = SessionException('Failed to initialize PeerConnection', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 设置PeerConnection事件监听器
  void _setupPeerConnectionListeners(RTCPeerConnection pc) {
    pc.onConnectionState = (state) {
      debugPrint('[SessionManager] Connection state: $state');
      onConnectionStateChanged?.call(state);
      _handleConnectionStateChange(state);
    };
    
    pc.onIceCandidate = (candidate) {
      debugPrint('[SessionManager] ICE candidate: ${candidate.candidate?.substring(0, 50)}...');
      onIceCandidate?.call(pc, candidate);
    };
    
    pc.onDataChannel = (channel) {
      debugPrint('[SessionManager] Received data channel: ${channel.label}');
      _attachDataChannel(channel);
    };
    
    pc.onIceGatheringState = (state) {
      debugPrint('[SessionManager] ICE gathering state: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _iceGatheringTimer?.cancel();
      }
    };
  }

  /// 创建控制数据通道
  Future<RTCDataChannel> createControlDataChannel() async {
    _validatePeerConnection();
    
    try {
      final pc = _pc!;
      final dc = await pc.createDataChannel(
        'control',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 3,
      );
      
      _attachDataChannel(dc);
      debugPrint('[SessionManager] Control data channel created');
      
      return dc;
    } catch (e, stackTrace) {
      final error = SessionException('Failed to create data channel', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 绑定数据通道事件
  void _attachDataChannel(RTCDataChannel channel) {
    _controlDc = channel;
    
    channel.onMessage = (msg) {
      if (!_isDisposed) {
        onDataMessage?.call(msg);
      }
    };
    
    channel.onDataChannelState = (state) {
      debugPrint('[SessionManager] Data channel state: $state');
      if (!_isDisposed) {
        onDataChannelState?.call(state);
        _handleDataChannelStateChange(state);
      }
    };
  }

  /// 处理连接状态变化
  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _connectionTimeoutTimer?.cancel();
        if (hasDataChannel) {
          _updateState(SessionManagerState.connected);
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _handleError(SessionException('PeerConnection failed'));
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _updateState(SessionManagerState.disconnected);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _updateState(SessionManagerState.closed);
        break;
      default:
        break;
    }
  }

  /// 处理数据通道状态变化
  void _handleDataChannelStateChange(RTCDataChannelState state) {
    switch (state) {
      case RTCDataChannelState.RTCDataChannelOpen:
        if (_pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _updateState(SessionManagerState.connected);
        }
        break;
      case RTCDataChannelState.RTCDataChannelClosed:
        if (_currentState == SessionManagerState.connected) {
          _updateState(SessionManagerState.disconnected);
        }
        break;
      default:
        break;
    }
  }

  /// 发送文本消息
  void sendText(String text) {
    if (_isDisposed) {
      throw StateError('SessionManager has been disposed');
    }
    
    if (!canSendData) {
      throw StateError('Data channel is not ready for sending');
    }
    
    if (text.isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }
    
    try {
      _controlDc!.send(RTCDataChannelMessage(text));
      debugPrint('[SessionManager] Sent text message (${text.length} chars)');
    } catch (e, stackTrace) {
      final error = SessionException('Failed to send text message', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 发送二进制数据
  void sendBinary(List<int> bytes) {
    if (_isDisposed) {
      throw StateError('SessionManager has been disposed');
    }
    
    if (!canSendData) {
      throw StateError('Data channel is not ready for sending');
    }
    
    if (bytes.isEmpty) {
      throw ArgumentError('Binary data cannot be empty');
    }
    
    try {
      _controlDc!.send(RTCDataChannelMessage.fromBinary(Uint8List.fromList(bytes)));
      debugPrint('[SessionManager] Sent binary message (${bytes.length} bytes)');
    } catch (e, stackTrace) {
      final error = SessionException('Failed to send binary message', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 创建Offer
  Future<RTCSessionDescription> createOffer() async {
    _validatePeerConnection();
    _updateState(SessionManagerState.negotiating);
    
    try {
      final pc = _pc!;
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      _startConnectionTimeout();
      debugPrint('[SessionManager] Offer created and set as local description');
      
      return offer;
    } catch (e, stackTrace) {
      final error = SessionException('Failed to create offer', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 创建Answer
  Future<RTCSessionDescription> createAnswer() async {
    _validatePeerConnection();
    _updateState(SessionManagerState.negotiating);
    
    try {
      final pc = _pc!;
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      debugPrint('[SessionManager] Answer created and set as local description');
      
      return answer;
    } catch (e, stackTrace) {
      final error = SessionException('Failed to create answer', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 设置远端描述
  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    _validatePeerConnection();
    
    try {
      final pc = _pc!;
      await pc.setRemoteDescription(desc);
      _isRemoteDescriptionSet = true;
      
      // 处理待处理的ICE候选
      for (final candidate in _pendingIceCandidates) {
        await pc.addCandidate(candidate);
      }
      _pendingIceCandidates.clear();
      
      debugPrint('[SessionManager] Remote description set (${desc.type})');
    } catch (e, stackTrace) {
      final error = SessionException('Failed to set remote description', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 添加ICE候选
  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    _validatePeerConnection();
    
    try {
      final pc = _pc!;
      
      // 如果远端描述还未设置，缓存候选
      if (!_isRemoteDescriptionSet) {
        _pendingIceCandidates.add(candidate);
        debugPrint('[SessionManager] ICE candidate cached (remote description not set yet)');
        return;
      }
      
      await pc.addCandidate(candidate);
      debugPrint('[SessionManager] ICE candidate added');
    } catch (e, stackTrace) {
      final error = SessionException('Failed to add ICE candidate', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 获取本地描述
  Future<RTCSessionDescription?> getLocalDescription() async {
    final pc = _pc;
    if (pc == null) return null;
    
    try {
      return await pc.getLocalDescription();
    } catch (e, stackTrace) {
      final error = SessionException('Failed to get local description', e, stackTrace);
      _handleError(error);
      return null;
    }
  }

  /// 验证PeerConnection状态
  void _validatePeerConnection() {
    if (_isDisposed) {
      throw StateError('SessionManager has been disposed');
    }
    if (_pc == null) {
      throw StateError('PeerConnection not initialized');
    }
  }

  /// 开始连接超时计时
  void _startConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(connectionTimeout, () {
      if (_currentState != SessionManagerState.connected) {
        _handleError(SessionException('Connection timeout'));
      }
    });
  }

  /// 更新会话状态
  void _updateState(SessionManagerState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      debugPrint('[SessionManager] State changed to: $newState');
      onSessionStateChanged?.call(newState);
    }
  }

  /// 处理错误
  void _handleError(SessionException error) {
    _lastError = error;
    _updateState(SessionManagerState.error);
    debugPrint('[SessionManager] Error: $error');
    onError?.call(error);
  }

  /// 清除错误状态
  void clearError() {
    _lastError = null;
    if (_pc != null) {
      _updateState(SessionManagerState.initialized);
    } else {
      _updateState(SessionManagerState.idle);
    }
  }

  /// 关闭数据通道
  Future<void> closeDataChannel() async {
    try {
      await _controlDc?.close();
    } catch (e) {
      debugPrint('[SessionManager] Error closing data channel: $e');
    }
    _controlDc = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    debugPrint('[SessionManager] Disposing');
    _isDisposed = true;
    
    _connectionTimeoutTimer?.cancel();
    _iceGatheringTimer?.cancel();
    
    await closeDataChannel();
    
    try {
      await _pc?.close();
    } catch (e) {
      debugPrint('[SessionManager] Error closing PeerConnection: $e');
    }
    _pc = null;
    
    _pendingIceCandidates.clear();
    _updateState(SessionManagerState.disposed);
    
    // 清理回调
    onDataMessage = null;
    onConnectionStateChanged = null;
    onIceCandidate = null;
    onDataChannelState = null;
    onSessionStateChanged = null;
    onError = null;
  }
}

/// 会话状态枚举
enum SessionManagerState {
  idle,
  initializing,
  initialized,
  negotiating,
  connected,
  disconnected,
  closed,
  error,
  disposed,
}

/// 会话异常类
class SessionException implements Exception {
  const SessionException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'SessionException: $message\nCaused by: $cause';
    }
    return 'SessionException: $message';
  }
}
