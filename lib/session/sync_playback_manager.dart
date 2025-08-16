import 'dart:async';
import 'dart:convert';


import '../core/logger_service.dart';
import '../player/player_controller.dart';
import 'session_manager.dart';

/// 同步播放管理器
/// 负责协调多个客户端之间的播放状态同步
class SyncPlaybackManager {
  SyncPlaybackManager({
    required this.sessionManager,
    required this.playerController,
    this.syncThresholdMs = 200,
    this.maxSyncDelayMs = 5000,
    this.heartbeatIntervalMs = 1000,
  }) {
    _initializeSync();
  }

  final SessionManager sessionManager;
  final PlayerController playerController;
  
  static const String _localPeerId = 'local-peer';
  final int syncThresholdMs;
  final int maxSyncDelayMs;
  final int heartbeatIntervalMs;

  Timer? _heartbeatTimer;
  Timer? _syncCheckTimer;
  final List<StreamSubscription> _subscriptions = [];
  
  bool _isDisposed = false;
  bool _isSyncEnabled = true;
  bool _isHost = false;
  String? _currentSessionId;
  
  // 同步状态
  int _networkLatencyMs = 0;
  final Map<String, PeerSyncState> _peerStates = {};
  
  // 状态控制器
  final _syncStateController = StreamController<SyncState>.broadcast();
  final _syncErrorController = StreamController<SyncException>.broadcast();
  
  // 公共流
  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  Stream<SyncException> get syncErrorStream => _syncErrorController.stream;
  
  // 状态属性
  bool get isSyncEnabled => _isSyncEnabled;
  bool get isHost => _isHost;
  String? get currentSessionId => _currentSessionId;
  int get networkLatencyMs => _networkLatencyMs;
  Map<String, PeerSyncState> get peerStates => Map.unmodifiable(_peerStates);

  /// 初始化同步系统
  void _initializeSync() {
    _setupSessionListeners();
    _setupPlayerListeners();
    Log.i('SyncPlayback', '同步播放管理器初始化完成');
  }

  /// 设置会话监听器
  void _setupSessionListeners() {
    // 使用回调方式监听会话状态变化
    sessionManager.onSessionStateChanged = _onSessionStateChanged;
    // 使用现有的回调方式监听数据
    sessionManager.onDataReceived = (data) {
      try {
        final text = String.fromCharCodes(data.binary);
        final messageData = jsonDecode(text) as Map<String, dynamic>;
        _onSessionMessage(messageData);
      } catch (e) {
        Log.e('SyncPlayback', 'Failed to parse session message', data: {'error': e.toString()});
      }
    };
    sessionManager.onError = _onSessionError;
  }

  /// 设置播放器监听器
  void _setupPlayerListeners() {
    _subscriptions.addAll([
      playerController.playingStream.listen(_onPlayingChanged),
      playerController.positionMsStream.listen(_onPositionChanged),
      playerController.stateStream.listen(_onPlayerStateChanged),
    ]);
  }

  /// 开始同步会话
  Future<void> startSyncSession(String sessionId, {bool asHost = false}) async {
    if (_isDisposed) {
      throw StateError('SyncPlaybackManager has been disposed');
    }

    _currentSessionId = sessionId;
    _isHost = asHost;
    _peerStates.clear();
    
    _startHeartbeat();
    _startSyncCheck();
    
    _updateSyncState(SyncState.syncing);
    
    Log.i('SyncPlayback', '开始同步会话: $sessionId (主持人: $asHost)');
  }

  /// 停止同步会话
  Future<void> stopSyncSession() async {
    if (_isDisposed) return;

    _stopHeartbeat();
    _stopSyncCheck();
    
    _currentSessionId = null;
    _isHost = false;
    _peerStates.clear();
    
    _updateSyncState(SyncState.idle);
    
    Log.i('SyncPlayback', '停止同步会话');
  }

  /// 启用/禁用同步
  void setSyncEnabled(bool enabled) {
    _isSyncEnabled = enabled;
    
    if (enabled && _currentSessionId != null) {
      _startSyncCheck();
    } else {
      _stopSyncCheck();
    }
    
    Log.i('SyncPlayback', '同步状态: ${enabled ? "启用" : "禁用"}');
  }

  /// 同步播放
  Future<void> syncPlay() async {
    if (!_canSendData()) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final position = playerController.positionMs;
    
    final command = SyncCommand(
      type: SyncCommandType.play,
      timestamp: timestamp,
      position: position,
      senderId: 'local-peer',
    );
    
    _sendSyncCommand(command.type, data: command.toJson());
    
    if (_isHost) {
      await playerController.play();
    }
    
    Log.i('SyncPlayback', '发送同步播放命令: position=${position}ms');
  }

  /// 同步暂停
  Future<void> syncPause() async {
    if (!_canSendData()) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final position = playerController.positionMs;
    
    final command = SyncCommand(
      type: SyncCommandType.pause,
      timestamp: timestamp,
      position: position,
      senderId: 'local-peer',
    );
    
    _sendSyncCommand(command.type, data: command.toJson());
    
    if (_isHost) {
      await playerController.pause();
    }
    
    Log.i('SyncPlayback', '发送同步暂停命令: position=${position}ms');
  }

  /// 同步跳转
  Future<void> syncSeek(int positionMs) async {
    if (!_canSendData()) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final command = SyncCommand(
      type: SyncCommandType.seek,
      timestamp: timestamp,
      position: positionMs,
      senderId: 'local-peer',
    );
    
    _sendSyncCommand(command.type, data: command.toJson());
    
    if (_isHost) {
      await playerController.seekMs(positionMs);
    }
    
    Log.i('SyncPlayback', '发送同步跳转命令: position=${positionMs}ms');
  }

  /// 同步播放速率
  Future<void> syncRate(double rate) async {
    if (!_canSendData()) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final command = SyncCommand(
      type: SyncCommandType.rate,
      timestamp: timestamp,
      rate: rate,
      senderId: 'local-peer',
    );
    
    _sendSyncCommand(command.type, data: command.toJson());
    
    if (_isHost) {
      await playerController.setRate(rate);
    }
    
    Log.i('SyncPlayback', '发送同步播放速率命令: rate=$rate');
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!_canSendData()) return;

    final heartbeat = SyncHeartbeat(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      position: playerController.positionMs,
      isPlaying: playerController.isPlaying,
      senderId: 'local-peer',
    );
    
    _sendSyncMessage('heartbeat', heartbeat.toJson());
  }

  /// 发送同步命令
  void _sendSyncCommand(SyncCommandType type, {Map<String, dynamic>? data}) {
    if (!_canSendData()) return;
    
    try {
      final message = jsonEncode({
        'type': 'sync_command',
        'command_type': type.name,
        'data': data,
      });
      
      sessionManager.sendText(message);
      Log.i('SyncPlayback', 'Sent sync command: ${type.name}', data: data);
    } catch (e) {
      Log.e('SyncPlayback', 'Failed to send sync command', data: {'error': e.toString()});
    }
  }

  /// 发送同步消息
  void _sendSyncMessage(String messageType, Map<String, dynamic> data) {
    if (!_canSendData()) return;
    
    try {
      final message = jsonEncode({
        'type': messageType,
        'data': data,
      });
      
      sessionManager.sendText(message);
      Log.i('SyncPlayback', 'Sent sync message: $messageType', data: data);
    } catch (e) {
      Log.e('SyncPlayback', 'Failed to send sync message', data: {'error': e.toString()});
    }
  }

  /// 开始心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: heartbeatIntervalMs),
      (_) => _sendHeartbeat(),
    );
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 开始同步检查
  void _startSyncCheck() {
    _stopSyncCheck();
    _syncCheckTimer = Timer.periodic(
      Duration(milliseconds: syncThresholdMs),
      (_) => _checkSync(),
    );
  }

  /// 停止同步检查
  void _stopSyncCheck() {
    _syncCheckTimer?.cancel();
    _syncCheckTimer = null;
  }

  /// 检查同步状态
  void _checkSync() {
    if (!_isSyncEnabled || _peerStates.isEmpty) return;

    final currentPosition = playerController.positionMs;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 计算与其他对等端的位置差异
    int maxDifference = 0;
    for (final peerState in _peerStates.values) {
      final timeDiff = currentTime - peerState.lastUpdateTime;
      final expectedPosition = peerState.position + (peerState.isPlaying ? timeDiff : 0);
      final difference = (currentPosition - expectedPosition).abs();
      
      if (difference > maxDifference) {
        maxDifference = difference;
      }
    }
    
    // 如果差异超过阈值，触发同步调整
    if (maxDifference > syncThresholdMs) {
      _performSyncAdjustment(maxDifference);
    }
  }

  /// 执行同步调整
  void _performSyncAdjustment(int difference) {
    if (_isHost) {
      // 主持人不需要调整，其他人跟随主持人
      return;
    }
    
    // 计算目标位置（基于主持人或平均位置）
    final targetPosition = _calculateTargetPosition();
    if (targetPosition == null) return;
    
    final currentPosition = playerController.positionMs;
    final positionDiff = (targetPosition - currentPosition).abs();
    
    if (positionDiff > syncThresholdMs && positionDiff < maxSyncDelayMs) {
      // 执行同步跳转
      playerController.seekMs(targetPosition).catchError((e) {
        Log.e('SyncPlayback', '同步调整失败', data: {'error': e.toString()});
      });
      
      Log.w('SyncPlayback', '执行同步调整: ${currentPosition}ms -> ${targetPosition}ms');
    }
  }

  /// 计算目标位置
  int? _calculateTargetPosition() {
    if (_peerStates.isEmpty) return null;
    
    // 如果有主持人，使用主持人的位置
    final hostState = _peerStates.values.firstWhere(
      (state) => state.isHost,
      orElse: () => _peerStates.values.first,
    );
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = currentTime - hostState.lastUpdateTime;
    
    return hostState.position + (hostState.isPlaying ? timeDiff : 0);
  }

  /// 会话状态变化处理
  void _onSessionStateChanged(SessionManagerState state) {
    switch (state) {
      case SessionManagerState.connected:
        _updateSyncState(SyncState.connected);
        break;
      case SessionManagerState.disconnected:
        _updateSyncState(SyncState.disconnected);
        _peerStates.clear();
        break;
      case SessionManagerState.error:
        _updateSyncState(SyncState.error);
        break;
      default:
        break;
    }
  }

  /// 会话消息处理
  void _onSessionMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'] as String?;
      final data = message['data'] as Map<String, dynamic>?;
      
      if (type == null || data == null) return;
      
      switch (type) {
        case 'sync_command':
          _handleSyncCommand(SyncCommand.fromJson(data));
          break;
        case 'heartbeat':
          _handleHeartbeat(SyncHeartbeat.fromJson(data));
          break;
      }
    } catch (e) {
      Log.e('SyncPlayback', '处理会话消息失败', data: {'error': e.toString()});
    }
  }

  /// 处理同步命令
  Future<void> _handleSyncCommand(SyncCommand command) async {
    if (command.senderId == 'local-peer') return;
    
    try {
      // 计算网络延迟补偿
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final networkDelay = currentTime - command.timestamp;
      _networkLatencyMs = networkDelay;
      
      switch (command.type) {
        case SyncCommandType.play:
          await _executeSyncPlay(command, networkDelay);
          break;
        case SyncCommandType.pause:
          await _executeSyncPause(command, networkDelay);
          break;
        case SyncCommandType.seek:
          await _executeSyncSeek(command, networkDelay);
          break;
        case SyncCommandType.rate:
          if (command.rate != null) {
            await _executeSyncRate(command, networkDelay);
          }
          break;
      }
      
      Log.i('SyncPlayback', '执行同步命令: ${command.type} (延迟: ${networkDelay}ms)');
    } catch (e) {
      final error = SyncException('执行同步命令失败: ${command.type}', e);
      _handleSyncError(error);
    }
  }

  /// 执行同步播放
  Future<void> _executeSyncPlay(SyncCommand command, int networkDelay) async {
    if (command.position != null) {
      final compensatedPosition = command.position! + networkDelay;
      await playerController.seekMs(compensatedPosition);
    }
    await playerController.play();
  }

  /// 执行同步暂停
  Future<void> _executeSyncPause(SyncCommand command, int networkDelay) async {
    if (command.position != null) {
      final compensatedPosition = command.position! + networkDelay;
      await playerController.seekMs(compensatedPosition);
    }
    await playerController.pause();
  }

  /// 执行同步跳转
  Future<void> _executeSyncSeek(SyncCommand command, int networkDelay) async {
    if (command.position != null) {
      final compensatedPosition = command.position! + networkDelay;
      await playerController.seekMs(compensatedPosition);
    }
  }

  /// 执行同步播放速率
  Future<void> _executeSyncRate(SyncCommand command, int networkDelay) async {
    if (command.rate != null) {
      await playerController.setRate(command.rate!);
    }
  }

  /// 处理心跳
  void _handleHeartbeat(SyncHeartbeat heartbeat) {
    if (heartbeat.senderId == 'local-peer') return;
    
    _peerStates[heartbeat.senderId] = PeerSyncState(
      peerId: heartbeat.senderId,
      position: heartbeat.position,
      isPlaying: heartbeat.isPlaying,
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      isHost: false, // TODO: 从会话信息中获取
    );
  }

  /// 播放状态变化处理
  void _onPlayingChanged(bool playing) {
    // 本地播放状态变化时，如果是主持人则广播同步命令
    if (_isHost && _isSyncEnabled && _currentSessionId != null) {
      if (playing) {
        syncPlay();
      } else {
        syncPause();
      }
    }
  }

  /// 位置变化处理
  void _onPositionChanged(int positionMs) {
    // 位置变化处理逻辑
  }

  /// 播放器状态变化处理
  void _onPlayerStateChanged(PlayerState state) {
    // 播放器状态变化处理逻辑
  }

  /// 会话错误处理
  void _onSessionError(SessionException error) {
    _handleSyncError(error);
  }

  /// 发送同步命令
  Future<void> sendSyncCommand(SyncCommandType type, {
    int? position,
    double? rate,
  }) async {
    if (!_canSendData()) return;

    final command = SyncCommand(
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      senderId: _localPeerId,
      position: position,
      rate: rate,
    );

    try {
      final message = jsonEncode({
        'type': 'sync_command',
        'data': command.toJson(),
      });
      
      sessionManager.sendText(message);
      Log.i('SyncPlayback', '_sendSyncCommand(${command.type}, data: ${command.toJson()})');
    } catch (e) {
      Log.e('SyncPlayback', 'Failed to send sync command', data: {'error': e.toString()});
    }
  }

  /// 检查是否可以发送数据
  bool _canSendData() {
    return !_isDisposed && 
           _isSyncEnabled && 
           _currentSessionId != null && 
           sessionManager.canSendData;
  }

  /// 更新同步状态
  void _updateSyncState(SyncState state) {
    _syncStateController.add(state);
  }

  /// 处理同步错误
  void _handleSyncError(Object error) {
    Log.e('SyncPlayback', 'Sync error occurred', data: {'error': error.toString()});
    _updateSyncState(SyncState.error);
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    Log.i('SyncPlayback', '释放同步播放管理器');
    _isDisposed = true;
    
    await stopSyncSession();
    
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    await Future.wait([
      _syncStateController.close(),
      _syncErrorController.close(),
    ]);
  }
}

/// 同步状态枚举
enum SyncState {
  idle,
  syncing,
  connected,
  disconnected,
  error,
}

/// 同步命令类型
enum SyncCommandType {
  play,
  pause,
  seek,
  rate,
}

/// 同步命令
class SyncCommand {
  const SyncCommand({
    required this.type,
    required this.timestamp,
    required this.senderId,
    this.position,
    this.rate,
  });

  final SyncCommandType type;
  final int timestamp;
  final String senderId;
  final int? position;
  final double? rate;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'timestamp': timestamp,
    'senderId': senderId,
    if (position != null) 'position': position,
    if (rate != null) 'rate': rate,
  };

  factory SyncCommand.fromJson(Map<String, dynamic> json) => SyncCommand(
    type: SyncCommandType.values.firstWhere((e) => e.name == json['type']),
    timestamp: json['timestamp'] as int,
    senderId: json['senderId'] as String,
    position: json['position'] as int?,
    rate: json['rate'] as double?,
  );
}

/// 同步心跳
class SyncHeartbeat {
  const SyncHeartbeat({
    required this.timestamp,
    required this.position,
    required this.isPlaying,
    required this.senderId,
  });

  final int timestamp;
  final int position;
  final bool isPlaying;
  final String senderId;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'position': position,
    'isPlaying': isPlaying,
    'senderId': senderId,
  };

  factory SyncHeartbeat.fromJson(Map<String, dynamic> json) => SyncHeartbeat(
    timestamp: json['timestamp'] as int,
    position: json['position'] as int,
    isPlaying: json['isPlaying'] as bool,
    senderId: json['senderId'] as String,
  );
}

/// 对等端同步状态
class PeerSyncState {
  const PeerSyncState({
    required this.peerId,
    required this.position,
    required this.isPlaying,
    required this.lastUpdateTime,
    required this.isHost,
  });

  final String peerId;
  final int position;
  final bool isPlaying;
  final int lastUpdateTime;
  final bool isHost;
}

/// 同步异常
class SyncException implements Exception {
  const SyncException(this.message, [this.cause]);
  
  final String message;
  final Object? cause;
  
  @override
  String toString() {
    if (cause != null) {
      return 'SyncException: $message\nCaused by: $cause';
    }
    return 'SyncException: $message';
  }
}
