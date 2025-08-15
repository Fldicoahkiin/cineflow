import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// 企业级播放器控制器
/// 提供完整的状态管理、错误处理和恢复机制
class PlayerController {
  PlayerController({
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.positionUpdateInterval = const Duration(milliseconds: 100),
  }) {
    _initializePlayer();
  }

  final int retryAttempts;
  final Duration retryDelay;
  final Duration positionUpdateInterval;

  late final Player _player;
  final List<StreamSubscription> _subscriptions = [];
  Timer? _positionTimer;
  
  bool _isDisposed = false;
  bool _isLoading = false;
  String? _currentMediaUri;
  PlayerException? _lastError;
  int _currentRetryAttempt = 0;

  // 状态控制器
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<int>.broadcast();
  final _durationController = StreamController<int>.broadcast();
  final _stateController = StreamController<PlayerState>.broadcast();
  final _errorController = StreamController<PlayerException>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();

  // 公共流
  Stream<bool> get playingStream => _playingController.stream;
  Stream<int> get positionMsStream => _positionController.stream;
  Stream<int> get durationMsStream => _durationController.stream;
  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<PlayerException> get errorStream => _errorController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;

  // 暴露底层 Player，用于创建 VideoController
  Player get rawPlayer => _player;

  // 状态属性
  bool get isPlaying => _player.state.playing;
  int get positionMs => _player.state.position.inMilliseconds;
  int get durationMs => _player.state.duration.inMilliseconds;
  bool get isLoading => _isLoading;
  PlayerState get currentState => _getCurrentState();
  PlayerException? get lastError => _lastError;
  String? get currentMediaUri => _currentMediaUri;

  /// 初始化播放器
  void _initializePlayer() {
    _player = Player();
    _setupPlayerListeners();
    _startPositionTimer();
    _updateState(PlayerState.idle);
  }

  /// 设置播放器监听器
  void _setupPlayerListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen(_onPlayingChanged),
      _player.stream.position.listen(_onPositionChanged),
      _player.stream.duration.listen(_onDurationChanged),
      _player.stream.error.listen(_onPlayerError),
    ]);
  }

  /// 开始位置定时器
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(positionUpdateInterval, (_) {
      if (!_isDisposed && isPlaying) {
        _positionController.add(positionMs);
      }
    });
  }

  /// 播放状态变化处理
  void _onPlayingChanged(bool playing) {
    if (_isDisposed) return;
    
    _playingController.add(playing);
    _updateState(playing ? PlayerState.playing : PlayerState.paused);
    
    debugPrint('[PlayerController] Playing state changed: $playing');
  }

  /// 位置变化处理
  void _onPositionChanged(Duration position) {
    if (_isDisposed) return;
    _positionController.add(position.inMilliseconds);
  }

  /// 时长变化处理
  void _onDurationChanged(Duration duration) {
    if (_isDisposed) return;
    _durationController.add(duration.inMilliseconds);
  }

  /// 播放器错误处理
  void _onPlayerError(String error) {
    if (_isDisposed) return;
    
    final exception = PlayerException('Player error: $error');
    _handleError(exception);
  }

  /// 加载媒体
  Future<void> load(String uri) async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }

    _validateUri(uri);
    
    _setLoading(true);
    _currentRetryAttempt = 0;
    _lastError = null;
    
    try {
      await _loadWithRetry(uri);
      _currentMediaUri = uri;
      _updateState(PlayerState.loaded);
      debugPrint('[PlayerController] Media loaded successfully: $uri');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to load media: $uri', e, stackTrace);
      _handleError(exception);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 带重试的加载
  Future<void> _loadWithRetry(String uri) async {
    while (_currentRetryAttempt < retryAttempts) {
      try {
        await _player.open(Media(uri));
        return;
      } catch (e) {
        _currentRetryAttempt++;
        
        if (_currentRetryAttempt >= retryAttempts) {
          rethrow;
        }
        
        debugPrint('[PlayerController] Load attempt $_currentRetryAttempt failed, retrying in ${retryDelay.inSeconds}s');
        await Future.delayed(retryDelay);
      }
    }
  }

  /// 验证URI
  void _validateUri(String uri) {
    if (uri.isEmpty) {
      throw ArgumentError('Media URI cannot be empty');
    }
    
    // 检查本地文件是否存在
    if (!uri.startsWith('http') && !uri.startsWith('https')) {
      final file = File(uri);
      if (!file.existsSync()) {
        throw ArgumentError('Local file does not exist: $uri');
      }
    }
  }

  /// 播放
  Future<void> play() async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }
    
    try {
      await _player.play();
      debugPrint('[PlayerController] Play command executed');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to play', e, stackTrace);
      _handleError(exception);
      rethrow;
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }
    
    try {
      await _player.pause();
      debugPrint('[PlayerController] Pause command executed');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to pause', e, stackTrace);
      _handleError(exception);
      rethrow;
    }
  }

  /// 跳转到指定位置
  Future<void> seekMs(int ms) async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }
    
    if (ms < 0) {
      throw ArgumentError('Seek position cannot be negative: $ms');
    }
    
    try {
      await _player.seek(Duration(milliseconds: ms));
      debugPrint('[PlayerController] Seek to ${ms}ms executed');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to seek to ${ms}ms', e, stackTrace);
      _handleError(exception);
      rethrow;
    }
  }

  /// 设置播放速率
  Future<void> setRate(double rate) async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }
    
    if (rate <= 0) {
      throw ArgumentError('Playback rate must be positive: $rate');
    }
    
    try {
      await _player.setRate(rate);
      debugPrint('[PlayerController] Playback rate set to $rate');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to set rate to $rate', e, stackTrace);
      _handleError(exception);
      rethrow;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (_isDisposed) {
      throw StateError('PlayerController has been disposed');
    }
    
    try {
      await _player.stop();
      _currentMediaUri = null;
      _updateState(PlayerState.idle);
      debugPrint('[PlayerController] Stop command executed');
    } catch (e, stackTrace) {
      final exception = PlayerException('Failed to stop', e, stackTrace);
      _handleError(exception);
      rethrow;
    }
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    _loadingController.add(loading);
  }

  /// 更新播放器状态
  void _updateState(PlayerState state) {
    _stateController.add(state);
  }

  /// 获取当前状态
  PlayerState _getCurrentState() {
    if (_isLoading) return PlayerState.loading;
    if (_lastError != null) return PlayerState.error;
    if (_currentMediaUri == null) return PlayerState.idle;
    if (isPlaying) return PlayerState.playing;
    return PlayerState.paused;
  }

  /// 处理错误
  void _handleError(PlayerException exception) {
    _lastError = exception;
    _updateState(PlayerState.error);
    _errorController.add(exception);
    
    debugPrint('[PlayerController] Error: $exception');
  }

  /// 清除错误状态
  void clearError() {
    _lastError = null;
    if (_currentMediaUri != null) {
      _updateState(PlayerState.loaded);
    } else {
      _updateState(PlayerState.idle);
    }
  }

  /// 重试上次失败的操作
  Future<void> retry() async {
    if (_currentMediaUri != null) {
      await load(_currentMediaUri!);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    debugPrint('[PlayerController] Disposing');
    _isDisposed = true;
    
    _positionTimer?.cancel();
    _positionTimer = null;
    
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    await _player.dispose();
    
    // 关闭所有流控制器
    await Future.wait([
      _playingController.close(),
      _positionController.close(),
      _durationController.close(),
      _stateController.close(),
      _errorController.close(),
      _loadingController.close(),
    ]);
  }
}

/// 播放器状态枚举
enum PlayerState {
  idle,
  loading,
  loaded,
  playing,
  paused,
  error,
}

/// 播放器异常类
class PlayerException implements Exception {
  const PlayerException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'PlayerException: $message\nCaused by: $cause';
    }
    return 'PlayerException: $message';
  }
}
