import 'package:flutter_test/flutter_test.dart';
import 'package:cineflow/session/sync_playback_manager.dart';

void main() {
  group('SyncPlaybackManager Simple Tests', () {
    test('should create SyncCommand with correct JSON format', () {
      final command = SyncCommand(
        type: SyncCommandType.play,
        timestamp: 1000,
        position: 5000,
        rate: 1.0,
        senderId: 'test-peer',
      );

      final json = command.toJson();
      
      expect(json['type'], 'play');
      expect(json['timestamp'], 1000);
      expect(json['position'], 5000);
      expect(json['rate'], 1.0);
      expect(json['senderId'], 'test-peer');
    });

    test('should parse SyncCommand from JSON', () {
      final json = {
        'type': 'pause',
        'timestamp': 2000,
        'position': 10000,
        'rate': 1.5,
        'senderId': 'peer-123',
      };

      final command = SyncCommand.fromJson(json);
      
      expect(command.type, SyncCommandType.pause);
      expect(command.timestamp, 2000);
      expect(command.position, 10000);
      expect(command.rate, 1.5);
      expect(command.senderId, 'peer-123');
    });

    test('should create SyncHeartbeat with correct JSON format', () {
      final heartbeat = SyncHeartbeat(
        timestamp: 3000,
        position: 15000,
        isPlaying: true,
        senderId: 'test-peer-2',
      );

      final json = heartbeat.toJson();
      
      expect(json['timestamp'], 3000);
      expect(json['position'], 15000);
      expect(json['isPlaying'], true);
      expect(json['senderId'], 'test-peer-2');
    });

    test('should parse SyncHeartbeat from JSON', () {
      final json = {
        'timestamp': 4000,
        'position': 20000,
        'isPlaying': false,
        'senderId': 'peer-456',
      };

      final heartbeat = SyncHeartbeat.fromJson(json);
      
      expect(heartbeat.timestamp, 4000);
      expect(heartbeat.position, 20000);
      expect(heartbeat.isPlaying, false);
      expect(heartbeat.senderId, 'peer-456');
    });

    test('should handle SyncCommandType enum conversion', () {
      expect(SyncCommandType.play.toString(), 'SyncCommandType.play');
      expect(SyncCommandType.pause.toString(), 'SyncCommandType.pause');
      expect(SyncCommandType.seek.toString(), 'SyncCommandType.seek');
      expect(SyncCommandType.rate.toString(), 'SyncCommandType.rate');
    });

    test('should create PeerSyncState with correct values', () {
      final state = PeerSyncState(
        peerId: 'peer-789',
        position: 25000,
        isPlaying: true,
        lastUpdateTime: 5000,
        isHost: false,
      );

      expect(state.peerId, 'peer-789');
      expect(state.position, 25000);
      expect(state.isPlaying, true);
      expect(state.lastUpdateTime, 5000);
      expect(state.isHost, false);
    });
  });
}
