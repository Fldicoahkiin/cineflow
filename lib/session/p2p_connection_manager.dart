import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/signaling_client.dart';
import 'session_manager.dart';

/// P2P连接管理器
/// 整合信令客户端和会话管理器，提供完整的P2P连接建立流程
class P2PConnectionManager {
  P2PConnectionManager({
    required this.signalingUrl,
    this.connectionTimeout = const Duration(seconds: 30),
  });

  final String signalingUrl;
  final Duration connectionTimeout;

  SignalingClient? _signalingClient;
  SessionManager? _sessionManager;
  String? _roomId;
  String? _peerId;
  bool _isHost = false;
  bool _isDisposed = false;

  // 连接状态
  P2PConnectionState _state = P2PConnectionState.idle;
  P2PConnectionState get state => _state;
  bool get isConnected => _state == P2PConnectionState.connected;

  // 事件回调
  void Function(P2PConnectionState state)? onStateChanged;
  void Function(String peerId)? onPeerJoined;
  void Function(String peerId)? onPeerLeft;
  void Function(RTCDataChannelMessage message, String fromPeerId)? onDataMessage;
  void Function(P2PConnectionException error)? onError;

  /// 作为主持人创建会话
  Future<String> createSession() async {
    if (_isDisposed) throw StateError('P2PConnectionManager已被释放');
    
    _updateState(P2PConnectionState.connecting);
    
    try {
      // 初始化信令客户端
      await _initSignalingClient();
      
      // 生成房间ID
      _roomId = _generateRoomId();
      _peerId = _generatePeerId();
      _isHost = true;
      
      // 创建会话管理器
      _sessionManager = SessionManager();
      await _sessionManager!.initPeerConnection();
      _setupSessionManagerCallbacks();
      
      // 向信令服务器发送创建房间请求
      _signalingClient!.send({
        'type': 'create_room',
        'roomId': _roomId,
        'peerId': _peerId,
      });
      
      _updateState(P2PConnectionState.waitingForPeers);
      debugPrint('[P2PConnectionManager] 会话创建成功，房间ID: $_roomId');
      
      return _roomId!;
    } catch (e, stackTrace) {
      final error = P2PConnectionException('创建会话失败', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 加入现有会话
  Future<void> joinSession(String roomId) async {
    if (_isDisposed) throw StateError('P2PConnectionManager已被释放');
    
    _updateState(P2PConnectionState.connecting);
    
    try {
      // 初始化信令客户端
      await _initSignalingClient();
      
      _roomId = roomId;
      _peerId = _generatePeerId();
      _isHost = false;
      
      // 创建会话管理器
      _sessionManager = SessionManager();
      await _sessionManager!.initPeerConnection();
      _setupSessionManagerCallbacks();
      
      // 向信令服务器发送加入房间请求
      _signalingClient!.send({
        'type': 'join_room',
        'roomId': _roomId,
        'peerId': _peerId,
      });
      
      debugPrint('[P2PConnectionManager] 正在加入会话: $roomId');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('加入会话失败', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 发送数据消息
  void sendData(String message) {
    if (!isConnected) {
      throw StateError('P2P连接未建立');
    }
    
    try {
      _sessionManager!.sendText(message);
    } catch (e, stackTrace) {
      final error = P2PConnectionException('发送数据失败', e, stackTrace);
      _handleError(error);
      rethrow;
    }
  }

  /// 初始化信令客户端
  Future<void> _initSignalingClient() async {
    _signalingClient = SignalingClient(signalingUrl);
    
    _signalingClient!.onMessage = _handleSignalingMessage;
    _signalingClient!.onError = (error, stackTrace) {
      final p2pError = P2PConnectionException('信令连接错误', error, stackTrace);
      _handleError(p2pError);
    };
    _signalingClient!.onDisconnected = () {
      if (_state == P2PConnectionState.connected) {
        _updateState(P2PConnectionState.disconnected);
      }
    };
    
    await _signalingClient!.connect();
  }

  /// 设置会话管理器回调
  void _setupSessionManagerCallbacks() {
    _sessionManager!.onIceCandidate = (pc, candidate) {
      _signalingClient!.send({
        'type': 'ice_candidate',
        'roomId': _roomId,
        'peerId': _peerId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
    
    _sessionManager!.onDataMessage = (message) {
      onDataMessage?.call(message, 'peer'); // 简化版本，实际应该传递真实的peerId
    };
    
    _sessionManager!.onSessionStateChanged = (state) {
      if (state == SessionManagerState.connected) {
        _updateState(P2PConnectionState.connected);
      } else if (state == SessionManagerState.error) {
        _updateState(P2PConnectionState.error);
      }
    };
    
    _sessionManager!.onError = (error) {
      final p2pError = P2PConnectionException('会话管理器错误', error);
      _handleError(p2pError);
    };
  }

  /// 处理信令消息
  void _handleSignalingMessage(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;
      
      switch (type) {
        case 'room_created':
          debugPrint('[P2PConnectionManager] 房间创建成功');
          break;
          
        case 'peer_joined':
          final peerId = data['peerId'] as String;
          debugPrint('[P2PConnectionManager] 对等端加入: $peerId');
          onPeerJoined?.call(peerId);
          
          // 如果是主持人，创建offer
          if (_isHost) {
            await _createAndSendOffer();
          }
          break;
          
        case 'peer_left':
          final peerId = data['peerId'] as String;
          debugPrint('[P2PConnectionManager] 对等端离开: $peerId');
          onPeerLeft?.call(peerId);
          break;
          
        case 'offer':
          await _handleOffer(data);
          break;
          
        case 'answer':
          await _handleAnswer(data);
          break;
          
        case 'ice_candidate':
          await _handleIceCandidate(data);
          break;
          
        case 'error':
          final message = data['message'] as String? ?? '未知错误';
          final error = P2PConnectionException('信令服务器错误: $message');
          _handleError(error);
          break;
          
        default:
          debugPrint('[P2PConnectionManager] 未知消息类型: $type');
      }
    } catch (e, stackTrace) {
      final error = P2PConnectionException('处理信令消息失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 创建并发送Offer
  Future<void> _createAndSendOffer() async {
    try {
      // 创建数据通道
      await _sessionManager!.createControlDataChannel();
      
      // 创建offer
      final offer = await _sessionManager!.createOffer();
      
      // 发送offer
      _signalingClient!.send({
        'type': 'offer',
        'roomId': _roomId,
        'peerId': _peerId,
        'sdp': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });
      
      debugPrint('[P2PConnectionManager] Offer已发送');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('创建Offer失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 处理Offer
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      final sdpData = data['sdp'] as Map<String, dynamic>;
      final offer = RTCSessionDescription(
        sdpData['sdp'] as String,
        sdpData['type'] as String,
      );
      
      // 设置远端描述
      await _sessionManager!.setRemoteDescription(offer);
      
      // 创建answer
      final answer = await _sessionManager!.createAnswer();
      
      // 发送answer
      _signalingClient!.send({
        'type': 'answer',
        'roomId': _roomId,
        'peerId': _peerId,
        'sdp': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
      
      debugPrint('[P2PConnectionManager] Answer已发送');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('处理Offer失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 处理Answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final sdpData = data['sdp'] as Map<String, dynamic>;
      final answer = RTCSessionDescription(
        sdpData['sdp'] as String,
        sdpData['type'] as String,
      );
      
      // 设置远端描述
      await _sessionManager!.setRemoteDescription(answer);
      
      debugPrint('[P2PConnectionManager] Answer已处理');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('处理Answer失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 处理ICE候选
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidateData = data['candidate'] as Map<String, dynamic>;
      final candidate = RTCIceCandidate(
        candidateData['candidate'] as String,
        candidateData['sdpMid'] as String?,
        candidateData['sdpMLineIndex'] as int?,
      );
      
      await _sessionManager!.addRemoteIceCandidate(candidate);
      debugPrint('[P2PConnectionManager] ICE候选已添加');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('处理ICE候选失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 生成房间ID
  String _generateRoomId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'room_$random';
  }

  /// 生成对等端ID
  String _generatePeerId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000).toString().padLeft(5, '0');
    return 'peer_$random';
  }

  /// 更新连接状态
  void _updateState(P2PConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      debugPrint('[P2PConnectionManager] 状态变更: $newState');
      onStateChanged?.call(newState);
    }
  }

  /// 处理错误
  void _handleError(P2PConnectionException error) {
    _updateState(P2PConnectionState.error);
    debugPrint('[P2PConnectionManager] 错误: $error');
    onError?.call(error);
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (_state == P2PConnectionState.idle) return;
    
    _updateState(P2PConnectionState.disconnecting);
    
    try {
      // 通知信令服务器离开房间
      if (_signalingClient?.isConnected == true && _roomId != null && _peerId != null) {
        _signalingClient!.send({
          'type': 'leave_room',
          'roomId': _roomId,
          'peerId': _peerId,
        });
      }
      
      // 关闭会话管理器
      await _sessionManager?.dispose();
      _sessionManager = null;
      
      // 关闭信令客户端
      await _signalingClient?.disconnect();
      _signalingClient = null;
      
      _roomId = null;
      _peerId = null;
      _isHost = false;
      
      _updateState(P2PConnectionState.idle);
      debugPrint('[P2PConnectionManager] 连接已断开');
    } catch (e, stackTrace) {
      final error = P2PConnectionException('断开连接失败', e, stackTrace);
      _handleError(error);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    await disconnect();
    
    // 清理回调
    onStateChanged = null;
    onPeerJoined = null;
    onPeerLeft = null;
    onDataMessage = null;
    onError = null;
  }
}

/// P2P连接状态
enum P2PConnectionState {
  idle,
  connecting,
  waitingForPeers,
  negotiating,
  connected,
  disconnecting,
  disconnected,
  error,
}

/// P2P连接异常
class P2PConnectionException implements Exception {
  const P2PConnectionException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'P2PConnectionException: $message\nCaused by: $cause';
    }
    return 'P2PConnectionException: $message';
  }
}
