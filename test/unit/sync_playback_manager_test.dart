import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cineflow/session/sync_playback_manager.dart';
import 'package:cineflow/session/session_manager.dart';
import 'package:cineflow/player/player_controller.dart';

// Mock classes for testing
class MockSessionManager extends SessionManager {
  MockSessionManager() : super();
  
  final String _localPeerId = 'test-peer-id';
  bool _canSendData = true;
  
  String get localPeerId => _localPeerId;
  
  @override
  bool get canSendData => _canSendData;
  
  void setCanSendData(bool value) {
    _canSendData = value;
  }
  
  final List<String> sentMessages = [];
  
  @override
  void sendText(String text) {
    if (!_canSendData) {
      throw StateError('Cannot send data');
    }
    sentMessages.add(text);
  }
}

class MockPlayerController extends PlayerController {
  MockPlayerController() : super();
  
  int _positionMs = 0;
  bool _isPlaying = false;
  
  @override
  int get positionMs => _positionMs;
  
  @override
  bool get isPlaying => _isPlaying;
  
  void setPosition(int position) {
    _positionMs = position;
  }
  
  void setPlaying(bool playing) {
    _isPlaying = playing;
  }
  
  final List<String> executedCommands = [];
  
  @override
  Future<void> play() async {
    executedCommands.add('play');
    _isPlaying = true;
  }
  
  @override
  Future<void> pause() async {
    executedCommands.add('pause');
    _isPlaying = false;
  }
  
  @override
  Future<void> seekMs(int ms) async {
    executedCommands.add('seek:$ms');
    _positionMs = ms;
  }
  
  @override
  Future<void> setRate(double rate) async {
    executedCommands.add('rate:$rate');
  }
}

void main() {
  group('SyncPlaybackManager Tests', () {
    late SyncPlaybackManager syncManager;
    late MockSessionManager mockSession;
    late MockPlayerController mockPlayer;

    setUp(() {
      mockSession = MockSessionManager();
      mockPlayer = MockPlayerController();
      syncManager = SyncPlaybackManager(
        sessionManager: mockSession,
        playerController: mockPlayer,
        syncThresholdMs: 100,
        heartbeatIntervalMs: 500,
      );
    });

    tearDown(() async {
      await syncManager.dispose();
    });

    test('should initialize with correct default values', () {
      expect(syncManager.isSyncEnabled, true);
      expect(syncManager.isHost, false);
      expect(syncManager.currentSessionId, null);
      expect(syncManager.peerStates, isEmpty);
    });

    test('should start sync session as host', () async {
      const sessionId = 'test-session-123';
      
      await syncManager.startSyncSession(sessionId, asHost: true);
      
      expect(syncManager.currentSessionId, sessionId);
      expect(syncManager.isHost, true);
    });

    test('should start sync session as participant', () async {
      const sessionId = 'test-session-456';
      
      await syncManager.startSyncSession(sessionId, asHost: false);
      
      expect(syncManager.currentSessionId, sessionId);
      expect(syncManager.isHost, false);
    });

    test('should stop sync session', () async {
      const sessionId = 'test-session-789';
      
      await syncManager.startSyncSession(sessionId, asHost: true);
      expect(syncManager.currentSessionId, sessionId);
      
      await syncManager.stopSyncSession();
      
      expect(syncManager.currentSessionId, null);
      expect(syncManager.isHost, false);
    });

    test('should enable and disable sync', () {
      expect(syncManager.isSyncEnabled, true);
      
      syncManager.setSyncEnabled(false);
      expect(syncManager.isSyncEnabled, false);
      
      syncManager.setSyncEnabled(true);
      expect(syncManager.isSyncEnabled, true);
    });

    test('should send sync play command when enabled', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      mockPlayer.setPosition(5000);
      
      await syncManager.syncPlay();
      
      expect(mockSession.sentMessages, hasLength(1));
      expect(mockSession.sentMessages.first, contains('sync_command'));
      expect(mockSession.sentMessages.first, contains('play'));
      expect(mockPlayer.executedCommands, contains('play'));
    });

    test('should send sync pause command when enabled', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      mockPlayer.setPosition(3000);
      mockPlayer.setPlaying(true);
      
      await syncManager.syncPause();
      
      expect(mockSession.sentMessages, hasLength(1));
      expect(mockSession.sentMessages.first, contains('sync_command'));
      expect(mockSession.sentMessages.first, contains('pause'));
      expect(mockPlayer.executedCommands, contains('pause'));
    });

    test('should send sync seek command when enabled', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      const targetPosition = 10000;
      
      await syncManager.syncSeek(targetPosition);
      
      expect(mockSession.sentMessages, hasLength(1));
      expect(mockSession.sentMessages.first, contains('sync_command'));
      expect(mockSession.sentMessages.first, contains('seek'));
      expect(mockPlayer.executedCommands, contains('seek:$targetPosition'));
    });

    test('should send sync rate command when enabled', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      const targetRate = 1.5;
      
      await syncManager.syncRate(targetRate);
      
      expect(mockSession.sentMessages, hasLength(1));
      expect(mockSession.sentMessages.first, contains('sync_command'));
      expect(mockSession.sentMessages.first, contains('rate'));
      expect(mockPlayer.executedCommands, contains('rate:$targetRate'));
    });

    test('should not send commands when sync is disabled', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      syncManager.setSyncEnabled(false);
      
      await syncManager.syncPlay();
      await syncManager.syncPause();
      await syncManager.syncSeek(5000);
      
      expect(mockSession.sentMessages, isEmpty);
    });

    test('should not send commands when session is not started', () async {
      await syncManager.syncPlay();
      await syncManager.syncPause();
      await syncManager.syncSeek(5000);
      
      expect(mockSession.sentMessages, isEmpty);
    });

    test('should not send commands when cannot send data', () async {
      await syncManager.startSyncSession('test-session', asHost: true);
      mockSession.setCanSendData(false);
      
      await syncManager.syncPlay();
      await syncManager.syncPause();
      
      expect(mockSession.sentMessages, isEmpty);
    });

    test('should handle sync command from peer', () async {
      await syncManager.startSyncSession('test-session', asHost: false);
      
      final command = SyncCommand(
        type: SyncCommandType.play,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        position: 2000,
        senderId: 'peer-456',
      );
      
      // Simulate receiving sync command
      final message = {
        'type': 'sync_command',
        'data': command.toJson(),
      };
      
      // This would normally be called by the session manager
      // 模拟接收消息
      if (mockSession.onDataMessage != null) {
        final messageData = RTCDataChannelMessage.fromBinary(
          Uint8List.fromList(utf8.encode(jsonEncode(message)))
        );
        mockSession.onDataMessage!(messageData);
      }
      
      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(mockPlayer.executedCommands, contains('play'));
    });

    test('should handle heartbeat from peer', () async {
      await syncManager.startSyncSession('test-session', asHost: false);
      
      final heartbeat = SyncHeartbeat(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        position: 5000,
        isPlaying: true,
        senderId: 'peer-789',
      );
      
      // Simulate receiving heartbeat
      final message = {
        'type': 'heartbeat',
        'data': heartbeat.toJson(),
      };
      
      // 验证数据发送能力
      expect(mockSession.canSendData, isTrue);
      
      // 模拟接收心跳消息
      if (mockSession.onDataMessage != null) {
        final messageData = RTCDataChannelMessage.fromBinary(
          Uint8List.fromList(utf8.encode(jsonEncode(message)))
        );
        mockSession.onDataMessage!(messageData);
      }
      
      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(syncManager.peerStates, hasLength(1));
      expect(syncManager.peerStates['peer-789']?.position, 5000);
      expect(syncManager.peerStates['peer-789']?.isPlaying, true);
    });

    test('should create valid sync command JSON', () {
      final command = SyncCommand(
        type: SyncCommandType.play,
        timestamp: 1234567890,
        position: 5000,
        senderId: 'test-peer',
      );
      
      final json = command.toJson();
      
      expect(json['type'], 'play');
      expect(json['timestamp'], 1234567890);
      expect(json['position'], 5000);
      expect(json['senderId'], 'test-peer');
    });

    test('should parse sync command from JSON', () {
      final json = {
        'type': 'pause',
        'timestamp': 1234567890,
        'position': 3000,
        'senderId': 'test-peer',
      };
      
      final command = SyncCommand.fromJson(json);
      
      expect(command.type, SyncCommandType.pause);
      expect(command.timestamp, 1234567890);
      expect(command.position, 3000);
      expect(command.senderId, 'test-peer');
    });

    test('should create valid heartbeat JSON', () {
      final heartbeat = SyncHeartbeat(
        timestamp: 1234567890,
        position: 7000,
        isPlaying: false,
        senderId: 'test-peer',
      );
      
      final json = heartbeat.toJson();
      
      expect(json['timestamp'], 1234567890);
      expect(json['position'], 7000);
      expect(json['isPlaying'], false);
      expect(json['senderId'], 'test-peer');
    });

    test('should parse heartbeat from JSON', () {
      final json = {
        'timestamp': 1234567890,
        'position': 8000,
        'isPlaying': true,
        'senderId': 'test-peer',
      };
      
      final heartbeat = SyncHeartbeat.fromJson(json);
      
      expect(heartbeat.timestamp, 1234567890);
      expect(heartbeat.position, 8000);
      expect(heartbeat.isPlaying, true);
      expect(heartbeat.senderId, 'test-peer');
    });
  });

  group('SyncCommand Tests', () {
    test('should support all command types', () {
      for (final type in SyncCommandType.values) {
        final command = SyncCommand(
          type: type,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          senderId: 'test-peer',
        );
        
        expect(command.type, type);
        
        final json = command.toJson();
        final parsed = SyncCommand.fromJson(json);
        
        expect(parsed.type, type);
      }
    });

    test('should handle optional parameters', () {
      final commandWithPosition = SyncCommand(
        type: SyncCommandType.seek,
        timestamp: 1234567890,
        position: 5000,
        senderId: 'test-peer',
      );
      
      expect(commandWithPosition.position, 5000);
      expect(commandWithPosition.rate, null);
      
      final commandWithRate = SyncCommand(
        type: SyncCommandType.rate,
        timestamp: 1234567890,
        rate: 1.5,
        senderId: 'test-peer',
      );
      
      expect(commandWithRate.rate, 1.5);
      expect(commandWithRate.position, null);
    });
  });

  group('SyncException Tests', () {
    test('should create exception with message only', () {
      const exception = SyncException('Test error');
      
      expect(exception.message, 'Test error');
      expect(exception.cause, null);
      expect(exception.toString(), 'SyncException: Test error');
    });

    test('should create exception with cause', () {
      final cause = Exception('Root cause');
      final exception = SyncException('Test error', cause);
      
      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Root cause'));
    });
  });
}
