import 'package:flutter_test/flutter_test.dart';
import 'package:cineflow/core/logger_service.dart';

void main() {
  group('LoggerService Tests', () {
    late LoggerService logger;

    setUp(() {
      logger = LoggerService.instance;
      logger.clearLogs();
    });

    test('should create log entries with correct properties', () {
      const tag = 'TestTag';
      const message = 'Test message';
      
      logger.info(tag, message);
      
      final logs = logger.getLogs();
      expect(logs.length, 1);
      
      final log = logs.first;
      expect(log.level, LogLevel.info);
      expect(log.tag, tag);
      expect(log.message, message);
      expect(log.timestamp, isA<DateTime>());
    });

    test('should filter logs by level', () {
      logger.debug('Test', 'Debug message');
      logger.info('Test', 'Info message');
      logger.warning('Test', 'Warning message');
      logger.error('Test', 'Error message');
      
      final errorLogs = logger.getLogs(minLevel: LogLevel.error);
      expect(errorLogs.length, 1);
      expect(errorLogs.first.level, LogLevel.error);
      
      final warningLogs = logger.getLogs(minLevel: LogLevel.warning);
      expect(warningLogs.length, 2);
    });

    test('should filter logs by tag', () {
      logger.info('Tag1', 'Message 1');
      logger.info('Tag2', 'Message 2');
      logger.info('Tag1', 'Message 3');
      
      final tag1Logs = logger.getLogs(tag: 'Tag1');
      expect(tag1Logs.length, 2);
      expect(tag1Logs.every((log) => log.tag == 'Tag1'), true);
    });

    test('should limit log entries in memory', () {
      logger.configure(maxLogEntries: 5);
      
      for (int i = 0; i < 10; i++) {
        logger.info('Test', 'Message $i');
      }
      
      final logs = logger.getLogs();
      expect(logs.length, 5);
      expect(logs.first.message, 'Message 5');
      expect(logs.last.message, 'Message 9');
    });

    test('should notify listeners when new log is added', () {
      bool listenerCalled = false;
      LogEntry? receivedLog;
      
      void listener(LogEntry log) {
        listenerCalled = true;
        receivedLog = log;
      }
      
      logger.addListener(listener);
      logger.info('Test', 'Test message');
      
      expect(listenerCalled, true);
      expect(receivedLog?.message, 'Test message');
      
      logger.removeListener(listener);
    });

    test('should generate correct log statistics', () {
      logger.debug('Test', 'Debug');
      logger.info('Test', 'Info 1');
      logger.info('Test', 'Info 2');
      logger.error('Test', 'Error');
      
      final stats = logger.getLogStats();
      expect(stats['debug'], 1);
      expect(stats['info'], 2);
      expect(stats['warning'], 0);
      expect(stats['error'], 1);
      expect(stats['fatal'], 0);
    });

    test('should clear all logs', () {
      logger.info('Test', 'Message 1');
      logger.info('Test', 'Message 2');
      
      expect(logger.getLogs().length, 2);
      
      logger.clearLogs();
      
      expect(logger.getLogs().length, 0);
    });

    test('should handle log entry serialization', () {
      final originalLog = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: 'TestTag',
        message: 'Test message',
        data: {'key': 'value'},
      );
      
      final json = originalLog.toJson();
      final deserializedLog = LogEntry.fromJson(json);
      
      expect(deserializedLog.level, originalLog.level);
      expect(deserializedLog.tag, originalLog.tag);
      expect(deserializedLog.message, originalLog.message);
      expect(deserializedLog.data, originalLog.data);
    });
  });

  group('Log Convenience Methods Tests', () {
    setUp(() {
      LoggerService.instance.clearLogs();
    });

    test('should use Log convenience methods correctly', () {
      Log.d('Debug', 'Debug message');
      Log.i('Info', 'Info message');
      Log.w('Warning', 'Warning message');
      Log.e('Error', 'Error message');
      Log.f('Fatal', 'Fatal message');
      
      final logs = LoggerService.instance.getLogs();
      expect(logs.length, 5);
      
      expect(logs[0].level, LogLevel.debug);
      expect(logs[1].level, LogLevel.info);
      expect(logs[2].level, LogLevel.warning);
      expect(logs[3].level, LogLevel.error);
      expect(logs[4].level, LogLevel.fatal);
    });
  });
}
