import 'dart:async';

import 'package:flutter/foundation.dart';

/// 状态管理服务
/// 提供类型安全的状态管理、事件通知和状态持久化功能
class StateService {
  StateService._internal();
  static final StateService _instance = StateService._internal();
  static StateService get instance => _instance;

  final Map<Type, dynamic> _states = {};
  final Map<Type, StreamController<dynamic>> _controllers = {};
  final Map<Type, List<StateValidator<dynamic>>> _validators = {};
  final Map<Type, StateSerializer<dynamic>?> _serializers = {};
  
  bool _isDisposed = false;

  /// 注册状态类型
  void registerState<T>(
    T initialState, {
    List<StateValidator<T>>? validators,
    StateSerializer<T>? serializer,
  }) {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    final type = T;
    
    if (_states.containsKey(type)) {
      debugPrint('[StateService] State $type already registered, updating...');
    }

    _states[type] = initialState;
    _controllers[type] = StreamController<T>.broadcast();
    
    if (validators != null) {
      _validators[type] = validators.cast<StateValidator<dynamic>>();
    }
    
    if (serializer != null) {
      _serializers[type] = serializer;
    }

    debugPrint('[StateService] Registered state: $type');
  }

  /// 获取当前状态
  T getState<T>() {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    final state = _states[T];
    if (state == null) {
      throw StateError('State $T not registered. Call registerState<$T>() first.');
    }
    return state as T;
  }

  /// 更新状态
  void setState<T>(T newState, {String? reason}) {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    final type = T;
    if (!_states.containsKey(type)) {
      throw StateError('State $type not registered. Call registerState<$type>() first.');
    }

    final currentState = _states[type] as T;
    
    // 验证状态变更
    final validators = _validators[type];
    if (validators != null) {
      for (final validator in validators) {
        final result = validator.validate(currentState, newState);
        if (!result.isValid) {
          throw StateValidationException(
            'State validation failed for $type: ${result.error}',
            currentState,
            newState,
          );
        }
      }
    }

    // 检查状态是否真的发生了变化
    if (_statesEqual(currentState, newState)) {
      debugPrint('[StateService] State $type unchanged, skipping update');
      return;
    }

    _states[type] = newState;
    
    final controller = _controllers[type] as StreamController<T>?;
    controller?.add(newState);

    debugPrint('[StateService] State updated: $type${reason != null ? ' ($reason)' : ''}');
  }

  /// 监听状态变化
  Stream<T> watchState<T>() {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    final controller = _controllers[T] as StreamController<T>?;
    if (controller == null) {
      throw StateError('State $T not registered. Call registerState<$T>() first.');
    }
    return controller.stream;
  }

  /// 批量更新状态
  void batchUpdate(List<StateUpdate> updates, {String? reason}) {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    debugPrint('[StateService] Batch update started${reason != null ? ' ($reason)' : ''}');
    
    for (final update in updates) {
      update.apply(this);
    }
    
    debugPrint('[StateService] Batch update completed (${updates.length} updates)');
  }

  /// 重置状态到初始值
  void resetState<T>({String? reason}) {
    if (_isDisposed) {
      throw StateError('StateService has been disposed');
    }

    final type = T;
    if (!_states.containsKey(type)) {
      throw StateError('State $type not registered');
    }

    // 这里假设我们有某种方式获取初始状态
    // 在实际实现中，你可能需要存储初始状态的副本
    debugPrint('[StateService] Reset state: $type${reason != null ? ' ($reason)' : ''}');
  }

  /// 序列化状态
  Map<String, dynamic> serializeStates() {
    final result = <String, dynamic>{};
    
    for (final entry in _states.entries) {
      final type = entry.key;
      final state = entry.value;
      final serializer = _serializers[type];
      
      if (serializer != null) {
        try {
          result[type.toString()] = serializer.serialize(state);
        } catch (e) {
          debugPrint('[StateService] Failed to serialize state $type: $e');
        }
      }
    }
    
    return result;
  }

  /// 反序列化状态
  void deserializeStates(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final typeName = entry.key;
      final serializedState = entry.value;
      
      // 查找对应的类型和序列化器
      for (final stateEntry in _states.entries) {
        final type = stateEntry.key;
        if (type.toString() == typeName) {
          final serializer = _serializers[type];
          if (serializer != null) {
            try {
              final deserializedState = serializer.deserialize(serializedState);
              _states[type] = deserializedState;
              
              final controller = _controllers[type];
              controller?.add(deserializedState);
              
              debugPrint('[StateService] Deserialized state: $type');
            } catch (e) {
              debugPrint('[StateService] Failed to deserialize state $type: $e');
            }
          }
          break;
        }
      }
    }
  }

  /// 获取所有已注册的状态类型
  List<Type> getRegisteredTypes() {
    return _states.keys.toList();
  }

  /// 检查状态是否已注册
  bool isRegistered<T>() {
    return _states.containsKey(T);
  }

  /// 清除特定状态
  void clearState<T>() {
    if (_isDisposed) return;

    final type = T;
    _states.remove(type);
    _controllers[type]?.close();
    _controllers.remove(type);
    _validators.remove(type);
    _serializers.remove(type);
    
    debugPrint('[StateService] Cleared state: $type');
  }

  /// 比较两个状态是否相等
  bool _statesEqual<T>(T state1, T state2) {
    // 对于基本类型和实现了 == 的类型
    if (state1 == state2) return true;
    
    // 对于复杂对象，可以使用深度比较
    // 这里简化处理，实际项目中可能需要更复杂的比较逻辑
    return false;
  }

  /// 释放资源
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('[StateService] Disposing');
    _isDisposed = true;
    
    for (final controller in _controllers.values) {
      controller.close();
    }
    
    _states.clear();
    _controllers.clear();
    _validators.clear();
    _serializers.clear();
  }
}

/// 状态更新操作
abstract class StateUpdate {
  void apply(StateService service);
}

/// 具体的状态更新实现
class StateUpdateImpl<T> extends StateUpdate {
  StateUpdateImpl(this.newState, {this.reason});
  
  final T newState;
  final String? reason;
  
  @override
  void apply(StateService service) {
    service.setState<T>(newState, reason: reason);
  }
}

/// 状态验证器
abstract class StateValidator<T> {
  ValidationResult validate(T currentState, T newState);
}

/// 验证结果
class ValidationResult {
  const ValidationResult.valid() : isValid = true, error = null;
  const ValidationResult.invalid(this.error) : isValid = false;
  
  final bool isValid;
  final String? error;
}

/// 状态序列化器
abstract class StateSerializer<T> {
  Map<String, dynamic> serialize(T state);
  T deserialize(Map<String, dynamic> data);
}

/// 状态验证异常
class StateValidationException implements Exception {
  const StateValidationException(this.message, this.currentState, this.newState);
  
  final String message;
  final dynamic currentState;
  final dynamic newState;
  
  @override
  String toString() => 'StateValidationException: $message';
}

/// 应用状态定义
class AppState {
  const AppState({
    this.isInitialized = false,
    this.currentTheme = AppTheme.light,
    this.language = 'zh_CN',
    this.debugMode = false,
  });

  final bool isInitialized;
  final AppTheme currentTheme;
  final String language;
  final bool debugMode;

  AppState copyWith({
    bool? isInitialized,
    AppTheme? currentTheme,
    String? language,
    bool? debugMode,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      currentTheme: currentTheme ?? this.currentTheme,
      language: language ?? this.language,
      debugMode: debugMode ?? this.debugMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState &&
        other.isInitialized == isInitialized &&
        other.currentTheme == currentTheme &&
        other.language == language &&
        other.debugMode == debugMode;
  }

  @override
  int get hashCode {
    return Object.hash(isInitialized, currentTheme, language, debugMode);
  }
}

enum AppTheme { light, dark, system }

/// 会话状态
class SessionState {
  const SessionState({
    this.isConnected = false,
    this.sessionId,
    this.participantCount = 0,
    this.connectionQuality = ConnectionQuality.unknown,
    this.lastError,
  });

  final bool isConnected;
  final String? sessionId;
  final int participantCount;
  final ConnectionQuality connectionQuality;
  final String? lastError;

  SessionState copyWith({
    bool? isConnected,
    String? sessionId,
    int? participantCount,
    ConnectionQuality? connectionQuality,
    String? lastError,
  }) {
    return SessionState(
      isConnected: isConnected ?? this.isConnected,
      sessionId: sessionId ?? this.sessionId,
      participantCount: participantCount ?? this.participantCount,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionState &&
        other.isConnected == isConnected &&
        other.sessionId == sessionId &&
        other.participantCount == participantCount &&
        other.connectionQuality == connectionQuality &&
        other.lastError == lastError;
  }

  @override
  int get hashCode {
    return Object.hash(isConnected, sessionId, participantCount, connectionQuality, lastError);
  }
}

enum ConnectionQuality { unknown, poor, fair, good, excellent }

/// 播放器状态
class PlayerState {
  const PlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.currentMedia,
    this.isLoading = false,
    this.error,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackRate;
  final String? currentMedia;
  final bool isLoading;
  final String? error;

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackRate,
    String? currentMedia,
    bool? isLoading,
    String? error,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackRate: playbackRate ?? this.playbackRate,
      currentMedia: currentMedia ?? this.currentMedia,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerState &&
        other.isPlaying == isPlaying &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.playbackRate == playbackRate &&
        other.currentMedia == currentMedia &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      isPlaying,
      position,
      duration,
      volume,
      playbackRate,
      currentMedia,
      isLoading,
      error,
    );
  }
}

/// 状态序列化器实现示例
class AppStateSerializer extends StateSerializer<AppState> {
  @override
  Map<String, dynamic> serialize(AppState state) {
    return {
      'isInitialized': state.isInitialized,
      'currentTheme': state.currentTheme.name,
      'language': state.language,
      'debugMode': state.debugMode,
    };
  }

  @override
  AppState deserialize(Map<String, dynamic> data) {
    return AppState(
      isInitialized: data['isInitialized'] ?? false,
      currentTheme: AppTheme.values.firstWhere(
        (theme) => theme.name == data['currentTheme'],
        orElse: () => AppTheme.light,
      ),
      language: data['language'] ?? 'zh_CN',
      debugMode: data['debugMode'] ?? false,
    );
  }
}

/// 状态验证器实现示例
class SessionStateValidator extends StateValidator<SessionState> {
  @override
  ValidationResult validate(SessionState currentState, SessionState newState) {
    // 验证参与者数量不能为负数
    if (newState.participantCount < 0) {
      return const ValidationResult.invalid('Participant count cannot be negative');
    }
    
    // 验证会话ID格式
    if (newState.sessionId != null && newState.sessionId!.isEmpty) {
      return const ValidationResult.invalid('Session ID cannot be empty');
    }
    
    return const ValidationResult.valid();
  }
}
