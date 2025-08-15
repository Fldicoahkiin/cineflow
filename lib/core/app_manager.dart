import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'state_service.dart';
import 'file_service.dart';
import '../player/player_controller.dart' hide PlayerState;
import '../session/session_manager.dart';
import '../network/signaling_client.dart';

/// 应用管理器
/// 负责应用的初始化、状态管理和服务协调
class AppManager {
  AppManager._internal();
  static final AppManager _instance = AppManager._internal();
  static AppManager get instance => _instance;

  // 核心服务
  late final StateService _stateService;
  late final FileService _fileService;
  
  // 业务服务
  PlayerController? _playerController;
  SessionManager? _sessionManager;
  SignalingClient? _signalingClient;
  
  // 初始化状态
  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _initializationErrors = [];
  
  // 事件流
  final StreamController<AppEvent> _eventController = StreamController.broadcast();
  
  /// 应用事件流
  Stream<AppEvent> get events => _eventController.stream;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 初始化错误列表
  List<String> get initializationErrors => List.unmodifiable(_initializationErrors);
  
  /// 状态服务
  StateService get stateService => _stateService;
  
  /// 文件服务
  FileService get fileService => _fileService;
  
  /// 播放器控制器
  PlayerController? get playerController => _playerController;
  
  /// 会话管理器
  SessionManager? get sessionManager => _sessionManager;
  
  /// 信令客户端
  SignalingClient? get signalingClient => _signalingClient;

  /// 初始化应用
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[AppManager] Already initialized');
      return;
    }
    
    if (_isDisposed) {
      throw StateError('AppManager has been disposed');
    }

    debugPrint('[AppManager] Starting initialization...');
    _emitEvent(AppEvent.initializationStarted());
    
    try {
      // 1. 初始化状态服务
      await _initializeStateService();
      
      // 2. 初始化文件服务
      await _initializeFileService();
      
      // 3. 注册全局状态
      await _registerGlobalStates();
      
      // 4. 初始化系统服务
      await _initializeSystemServices();
      
      _isInitialized = true;
      _updateAppState(isInitialized: true);
      
      debugPrint('[AppManager] Initialization completed successfully');
      _emitEvent(AppEvent.initializationCompleted());
      
    } catch (e, stackTrace) {
      final error = 'Initialization failed: $e';
      _initializationErrors.add(error);
      debugPrint('[AppManager] $error');
      debugPrint('Stack trace: $stackTrace');
      
      _emitEvent(AppEvent.initializationFailed(error));
      rethrow;
    }
  }

  /// 初始化状态服务
  Future<void> _initializeStateService() async {
    debugPrint('[AppManager] Initializing state service...');
    _stateService = StateService.instance;
  }

  /// 初始化文件服务
  Future<void> _initializeFileService() async {
    debugPrint('[AppManager] Initializing file service...');
    _fileService = FileService(
      allowedExtensions: [
        'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v',
        'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a',
      ],
    );
  }

  /// 注册全局状态
  Future<void> _registerGlobalStates() async {
    debugPrint('[AppManager] Registering global states...');
    
    // 注册应用状态
    _stateService.registerState<AppState>(
      const AppState(),
      validators: [AppStateValidator()],
      serializer: AppStateSerializer(),
    );
    
    // 注册会话状态
    _stateService.registerState<SessionState>(
      const SessionState(),
      validators: [SessionStateValidator()],
    );
    
    // 注册播放器状态
    _stateService.registerState<PlayerState>(
      const PlayerState(),
      validators: [PlayerStateValidator()],
    );
  }

  /// 初始化系统服务
  Future<void> _initializeSystemServices() async {
    debugPrint('[AppManager] Initializing system services...');
    
    // 设置系统UI样式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // 设置首选方向
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 创建播放器控制器
  Future<PlayerController> createPlayerController() async {
    if (!_isInitialized) {
      throw StateError('AppManager not initialized');
    }
    
    if (_playerController != null) {
      debugPrint('[AppManager] Player controller already exists, disposing old one');
      await _playerController!.dispose();
    }
    
    debugPrint('[AppManager] Creating player controller...');
    _playerController = PlayerController();
    
    // 监听播放器状态变化并同步到全局状态
    _playerController!.playingStream.listen((playing) {
      final currentState = _stateService.getState<PlayerState>();
      _stateService.setState(
        currentState.copyWith(isPlaying: playing),
        reason: 'Player playing state changed',
      );
    });
    
    _playerController!.positionMsStream.listen((positionMs) {
      final currentState = _stateService.getState<PlayerState>();
      _stateService.setState(
        currentState.copyWith(position: Duration(milliseconds: positionMs)),
        reason: 'Player position changed',
      );
    });
    
    _playerController!.durationMsStream.listen((durationMs) {
      final currentState = _stateService.getState<PlayerState>();
      _stateService.setState(
        currentState.copyWith(duration: Duration(milliseconds: durationMs)),
        reason: 'Player duration changed',
      );
    });
    
    _playerController!.loadingStream.listen((loading) {
      final currentState = _stateService.getState<PlayerState>();
      _stateService.setState(
        currentState.copyWith(isLoading: loading),
        reason: 'Player loading state changed',
      );
    });
    
    _playerController!.errorStream.listen((error) {
      final currentState = _stateService.getState<PlayerState>();
      _stateService.setState(
        currentState.copyWith(error: error.message),
        reason: 'Player error occurred',
      );
    });
    
    _emitEvent(AppEvent.playerControllerCreated());
    return _playerController!;
  }

  /// 创建会话管理器
  Future<SessionManager> createSessionManager() async {
    if (!_isInitialized) {
      throw StateError('AppManager not initialized');
    }
    
    if (_sessionManager != null) {
      debugPrint('[AppManager] Session manager already exists, disposing old one');
      await _sessionManager!.dispose();
    }
    
    debugPrint('[AppManager] Creating session manager...');
    _sessionManager = SessionManager();
    
    // 监听会话状态变化
    _sessionManager!.onSessionStateChanged = (state) {
      final currentSessionState = _stateService.getState<SessionState>();
      _stateService.setState(
        currentSessionState.copyWith(
          isConnected: state == SessionManagerState.connected,
        ),
        reason: 'Session state changed to $state',
      );
    };
    
    _sessionManager!.onError = (error) {
      final currentSessionState = _stateService.getState<SessionState>();
      _stateService.setState(
        currentSessionState.copyWith(lastError: error.message),
        reason: 'Session error occurred',
      );
      _emitEvent(AppEvent.sessionError(error.message));
    };
    
    _emitEvent(AppEvent.sessionManagerCreated());
    return _sessionManager!;
  }

  /// 创建信令客户端
  SignalingClient createSignalingClient(String url) {
    if (!_isInitialized) {
      throw StateError('AppManager not initialized');
    }
    
    if (_signalingClient != null) {
      debugPrint('[AppManager] Signaling client already exists, disconnecting old one');
      _signalingClient!.disconnect();
    }
    
    debugPrint('[AppManager] Creating signaling client for: $url');
    _signalingClient = SignalingClient(url);
    
    // 监听连接状态变化
    _signalingClient!.onConnected = () {
      final currentSessionState = _stateService.getState<SessionState>();
      _stateService.setState(
        currentSessionState.copyWith(isConnected: true),
        reason: 'Signaling connected',
      );
      _emitEvent(AppEvent.signalingConnected());
    };
    
    _signalingClient!.onDisconnected = () {
      final currentSessionState = _stateService.getState<SessionState>();
      _stateService.setState(
        currentSessionState.copyWith(isConnected: false),
        reason: 'Signaling disconnected',
      );
      _emitEvent(AppEvent.signalingDisconnected());
    };
    
    _signalingClient!.onError = (error, stackTrace) {
      final currentSessionState = _stateService.getState<SessionState>();
      _stateService.setState(
        currentSessionState.copyWith(lastError: error.toString()),
        reason: 'Signaling error occurred',
      );
      _emitEvent(AppEvent.signalingError(error.toString()));
    };
    
    _emitEvent(AppEvent.signalingClientCreated());
    return _signalingClient!;
  }

  /// 更新应用状态
  void _updateAppState({
    bool? isInitialized,
    AppTheme? currentTheme,
    String? language,
    bool? debugMode,
  }) {
    final currentState = _stateService.getState<AppState>();
    _stateService.setState(
      currentState.copyWith(
        isInitialized: isInitialized,
        currentTheme: currentTheme,
        language: language,
        debugMode: debugMode,
      ),
    );
  }

  /// 设置主题
  void setTheme(AppTheme theme) {
    _updateAppState(currentTheme: theme);
    _emitEvent(AppEvent.themeChanged(theme));
  }

  /// 设置语言
  void setLanguage(String language) {
    _updateAppState(language: language);
    _emitEvent(AppEvent.languageChanged(language));
  }

  /// 设置调试模式
  void setDebugMode(bool enabled) {
    _updateAppState(debugMode: enabled);
    _emitEvent(AppEvent.debugModeChanged(enabled));
  }

  /// 发送事件
  void _emitEvent(AppEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    debugPrint('[AppManager] Disposing...');
    _isDisposed = true;
    
    // 释放业务服务
    await _playerController?.dispose();
    await _sessionManager?.dispose();
    _signalingClient?.disconnect();
    
    // 释放核心服务
    _fileService.dispose();
    _stateService.dispose();
    
    // 关闭事件流
    await _eventController.close();
    
    _isInitialized = false;
    debugPrint('[AppManager] Disposed');
  }
}

/// 应用事件
sealed class AppEvent {
  const AppEvent();

  factory AppEvent.initializationStarted() = InitializationStarted;
  factory AppEvent.initializationCompleted() = InitializationCompleted;
  factory AppEvent.initializationFailed(String error) = InitializationFailed;
  factory AppEvent.playerControllerCreated() = PlayerControllerCreated;
  factory AppEvent.sessionManagerCreated() = SessionManagerCreated;
  factory AppEvent.signalingClientCreated() = SignalingClientCreated;
  factory AppEvent.signalingConnected() = SignalingConnected;
  factory AppEvent.signalingDisconnected() = SignalingDisconnected;
  factory AppEvent.signalingError(String error) = SignalingError;
  factory AppEvent.sessionError(String error) = SessionError;
  factory AppEvent.themeChanged(AppTheme theme) = ThemeChanged;
  factory AppEvent.languageChanged(String language) = LanguageChanged;
  factory AppEvent.debugModeChanged(bool enabled) = DebugModeChanged;
}

class InitializationStarted extends AppEvent {
  const InitializationStarted();
}

class InitializationCompleted extends AppEvent {
  const InitializationCompleted();
}

class InitializationFailed extends AppEvent {
  const InitializationFailed(this.error);
  final String error;
}

class PlayerControllerCreated extends AppEvent {
  const PlayerControllerCreated();
}

class SessionManagerCreated extends AppEvent {
  const SessionManagerCreated();
}

class SignalingClientCreated extends AppEvent {
  const SignalingClientCreated();
}

class SignalingConnected extends AppEvent {
  const SignalingConnected();
}

class SignalingDisconnected extends AppEvent {
  const SignalingDisconnected();
}

class SignalingError extends AppEvent {
  const SignalingError(this.error);
  final String error;
}

class SessionError extends AppEvent {
  const SessionError(this.error);
  final String error;
}

class ThemeChanged extends AppEvent {
  const ThemeChanged(this.theme);
  final AppTheme theme;
}

class LanguageChanged extends AppEvent {
  const LanguageChanged(this.language);
  final String language;
}

class DebugModeChanged extends AppEvent {
  const DebugModeChanged(this.enabled);
  final bool enabled;
}

/// 状态验证器实现
class AppStateValidator extends StateValidator<AppState> {
  @override
  ValidationResult validate(AppState currentState, AppState newState) {
    // 验证语言代码格式
    if (!_isValidLanguageCode(newState.language)) {
      return const ValidationResult.invalid('Invalid language code format');
    }
    
    return const ValidationResult.valid();
  }
  
  bool _isValidLanguageCode(String code) {
    // 简单的语言代码验证
    final pattern = RegExp(r'^[a-z]{2}(_[A-Z]{2})?$');
    return pattern.hasMatch(code);
  }
}

class PlayerStateValidator extends StateValidator<PlayerState> {
  @override
  ValidationResult validate(PlayerState currentState, PlayerState newState) {
    // 验证音量范围
    if (newState.volume < 0.0 || newState.volume > 1.0) {
      return const ValidationResult.invalid('Volume must be between 0.0 and 1.0');
    }
    
    // 验证播放速率
    if (newState.playbackRate <= 0.0 || newState.playbackRate > 4.0) {
      return const ValidationResult.invalid('Playback rate must be between 0.0 and 4.0');
    }
    
    // 验证位置不能超过时长
    if (newState.duration > Duration.zero && newState.position > newState.duration) {
      return const ValidationResult.invalid('Position cannot exceed duration');
    }
    
    return const ValidationResult.valid();
  }
}
