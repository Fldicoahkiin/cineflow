/// CineFlow 消息协议
/// 
/// 企业级消息协议，支持版本控制和向后兼容性
/// 
/// 协议规范：
/// - 所有消息必须包含 `type` 和 `version` 字段
/// - 可选包含 `payload` 字段用于承载数据
/// - 时间戳使用 UTC 毫秒（int64）
/// - 支持消息ID用于追踪和去重
/// 
/// 消息格式：
/// ```json
/// {
///   "type": "state_update",
///   "version": "1.0",
///   "messageId": "uuid-string",
///   "timestamp": 1690000000000,
///   "payload": {...}
/// }
/// ```
library messages;

/// 协议版本管理
class ProtocolVersion {
  static const String current = '1.0';
  static const String minimum = '1.0';
  
  static const List<String> supported = ['1.0'];
  
  /// 检查版本兼容性
  static bool isCompatible(String version) {
    return supported.contains(version);
  }
  
  /// 比较版本号
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    
    return 0;
  }
}

/// 消息类型定义
class MessageType {
  // WebRTC 信令消息
  static const String offer = 'offer';
  static const String answer = 'answer';
  static const String candidate = 'candidate';
  
  // 房间管理消息
  static const String joinRoom = 'join_room';
  static const String createRoom = 'create_room';
  static const String leaveRoom = 'leave_room';
  static const String roomInfo = 'room_info';
  
  // 播放控制消息
  static const String stateUpdate = 'state_update';
  static const String playCommand = 'play_command';
  static const String pauseCommand = 'pause_command';
  static const String seekCommand = 'seek_command';
  
  // 系统消息
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';
  static const String heartbeat = 'heartbeat';
  
  // 用户消息
  static const String userJoined = 'user_joined';
  static const String userLeft = 'user_left';
  static const String chatMessage = 'chat_message';
}

/// 基础消息类
abstract class BaseMessage {
  const BaseMessage({
    required this.type,
    required this.version,
    required this.messageId,
    required this.timestamp,
  });
  
  final String type;
  final String version;
  final String messageId;
  final int timestamp;
  
  Map<String, dynamic> toJson();
  
  /// 验证消息格式
  bool isValid() {
    return type.isNotEmpty && 
           ProtocolVersion.isCompatible(version) &&
           messageId.isNotEmpty &&
           timestamp > 0;
  }
}

/// 状态更新消息载荷
class StateUpdatePayload {
  const StateUpdatePayload({
    required this.isPlaying,
    required this.positionMs,
    required this.timestampUtcMs,
    this.playbackRate = 1.0,
    this.mediaUri,
    this.mediaDurationMs,
  });

  final bool isPlaying;
  final int positionMs;
  final int timestampUtcMs;
  final double playbackRate;
  final String? mediaUri;
  final int? mediaDurationMs;

  Map<String, dynamic> toJson() => {
        'isPlaying': isPlaying,
        'position': positionMs,
        'timestamp': timestampUtcMs,
        'playbackRate': playbackRate,
        if (mediaUri != null) 'mediaUri': mediaUri,
        if (mediaDurationMs != null) 'mediaDurationMs': mediaDurationMs,
      };

  static StateUpdatePayload fromJson(Map<String, dynamic> json) {
    return StateUpdatePayload(
      isPlaying: json['isPlaying'] as bool? ?? false,
      positionMs: (json['position'] as num? ?? 0).toInt(),
      timestampUtcMs: (json['timestamp'] as num? ?? 0).toInt(),
      playbackRate: (json['playbackRate'] as num? ?? 1.0).toDouble(),
      mediaUri: json['mediaUri'] as String?,
      mediaDurationMs: (json['mediaDurationMs'] as num?)?.toInt(),
    );
  }
  
  StateUpdatePayload copyWith({
    bool? isPlaying,
    int? positionMs,
    int? timestampUtcMs,
    double? playbackRate,
    String? mediaUri,
    int? mediaDurationMs,
  }) {
    return StateUpdatePayload(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      timestampUtcMs: timestampUtcMs ?? this.timestampUtcMs,
      playbackRate: playbackRate ?? this.playbackRate,
      mediaUri: mediaUri ?? this.mediaUri,
      mediaDurationMs: mediaDurationMs ?? this.mediaDurationMs,
    );
  }
}

/// 错误消息载荷
class ErrorPayload {
  const ErrorPayload({
    required this.code,
    required this.message,
    this.details,
  });
  
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  
  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      };
  
  static ErrorPayload fromJson(Map<String, dynamic> json) {
    return ErrorPayload(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'Unknown error occurred',
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

/// 房间信息载荷
class RoomInfoPayload {
  const RoomInfoPayload({
    required this.roomId,
    required this.hostId,
    required this.participants,
    this.roomName,
    this.maxParticipants,
  });
  
  final String roomId;
  final String hostId;
  final List<String> participants;
  final String? roomName;
  final int? maxParticipants;
  
  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'hostId': hostId,
        'participants': participants,
        if (roomName != null) 'roomName': roomName,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
      };
  
  static RoomInfoPayload fromJson(Map<String, dynamic> json) {
    return RoomInfoPayload(
      roomId: json['roomId'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      participants: (json['participants'] as List?)?.cast<String>() ?? [],
      roomName: json['roomName'] as String?,
      maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
    );
  }
}

/// 消息构建器
class MessageBuilder {
  static String _generateMessageId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           '_' + 
           (DateTime.now().microsecond % 1000).toString();
  }
  
  /// 创建状态更新消息
  static Map<String, dynamic> stateUpdate(StateUpdatePayload payload) => {
        'type': MessageType.stateUpdate,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload.toJson(),
      };

  /// 创建ping消息
  static Map<String, dynamic> ping([int? timestamp]) => {
        'type': MessageType.ping,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      };

  /// 创建pong消息
  static Map<String, dynamic> pong(int originalTimestamp) => {
        'type': MessageType.pong,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': {
          'originalTimestamp': originalTimestamp,
        },
      };
  
  /// 创建错误消息
  static Map<String, dynamic> error(ErrorPayload payload) => {
        'type': MessageType.error,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload.toJson(),
      };
  
  /// 创建房间信息消息
  static Map<String, dynamic> roomInfo(RoomInfoPayload payload) => {
        'type': MessageType.roomInfo,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload.toJson(),
      };
  
  /// 创建加入房间消息
  static Map<String, dynamic> joinRoom(String roomId, String userId) => {
        'type': MessageType.joinRoom,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': {
          'roomId': roomId,
          'userId': userId,
        },
      };
  
  /// 创建离开房间消息
  static Map<String, dynamic> leaveRoom(String roomId, String userId) => {
        'type': MessageType.leaveRoom,
        'version': ProtocolVersion.current,
        'messageId': _generateMessageId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': {
          'roomId': roomId,
          'userId': userId,
        },
      };
}

/// 消息解析器
class MessageParser {
  /// 解析消息
  static ParsedMessage? parse(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;
      final version = json['version'] as String? ?? ProtocolVersion.minimum;
      final messageId = json['messageId'] as String? ?? '';
      final timestamp = (json['timestamp'] as num? ?? 0).toInt();
      
      if (type == null || !ProtocolVersion.isCompatible(version)) {
        return null;
      }
      
      return ParsedMessage(
        type: type,
        version: version,
        messageId: messageId,
        timestamp: timestamp,
        payload: json['payload'] as Map<String, dynamic>?,
        rawData: json,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 解析状态更新消息
  static StateUpdatePayload? parseStateUpdate(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    
    try {
      return StateUpdatePayload.fromJson(payload);
    } catch (e) {
      return null;
    }
  }
  
  /// 解析错误消息
  static ErrorPayload? parseError(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    
    try {
      return ErrorPayload.fromJson(payload);
    } catch (e) {
      return null;
    }
  }
}

/// 解析后的消息
class ParsedMessage {
  const ParsedMessage({
    required this.type,
    required this.version,
    required this.messageId,
    required this.timestamp,
    this.payload,
    required this.rawData,
  });
  
  final String type;
  final String version;
  final String messageId;
  final int timestamp;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic> rawData;
  
  /// 检查消息是否有效
  bool get isValid {
    return type.isNotEmpty && 
           ProtocolVersion.isCompatible(version) &&
           messageId.isNotEmpty &&
           timestamp > 0;
  }
  
  /// 获取消息年龄（毫秒）
  int get ageMs {
    return DateTime.now().millisecondsSinceEpoch - timestamp;
  }
}

// 向后兼容的别名
typedef MsgType = MessageType;

// 向后兼容的函数
Map<String, dynamic> makeStateUpdate(StateUpdatePayload payload) => 
    MessageBuilder.stateUpdate(payload);

Map<String, dynamic> makePing(int nowUtcMs) => 
    MessageBuilder.ping(nowUtcMs);

Map<String, dynamic> makePong(int ts) => 
    MessageBuilder.pong(ts);
