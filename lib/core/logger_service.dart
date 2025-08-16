import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? data;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.data,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'tag': tag,
      'message': message,
      'data': data,
      'stackTrace': stackTrace?.toString(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere((e) => e.name == json['level']),
      tag: json['tag'],
      message: json['message'],
      data: json['data'],
      stackTrace: json['stackTrace'] != null 
          ? StackTrace.fromString(json['stackTrace']) 
          : null,
    );
  }

  @override
  String toString() {
    final levelStr = level.name.toUpperCase().padRight(7);
    final timeStr = timestamp.toString().substring(11, 23);
    return '[$timeStr] $levelStr [$tag] $message';
  }
}

class LoggerService {
  static LoggerService? _instance;
  static LoggerService get instance => _instance ??= LoggerService._();
  
  LoggerService._();

  final List<LogEntry> _logs = [];
  final List<Function(LogEntry)> _listeners = [];
  
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  bool _enableFileLogging = true;
  bool _enableConsoleLogging = true;
  int _maxLogEntries = 1000;
  
  File? _logFile;

  // 配置方法
  void configure({
    LogLevel? minLevel,
    bool? enableFileLogging,
    bool? enableConsoleLogging,
    int? maxLogEntries,
  }) {
    _minLevel = minLevel ?? _minLevel;
    _enableFileLogging = enableFileLogging ?? _enableFileLogging;
    _enableConsoleLogging = enableConsoleLogging ?? _enableConsoleLogging;
    _maxLogEntries = maxLogEntries ?? _maxLogEntries;
  }

  // 初始化日志文件
  Future<void> initialize() async {
    if (_enableFileLogging) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        final now = DateTime.now();
        final fileName = 'cineflow_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
        _logFile = File('${logDir.path}/$fileName');
      } catch (e) {
        debugPrint('日志文件初始化失败: $e');
        _enableFileLogging = false;
      }
    }
  }

  // 添加日志监听器
  void addListener(Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  // 移除日志监听器
  void removeListener(Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  // 记录日志
  void _log(LogLevel level, String tag, String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      data: data,
      stackTrace: stackTrace,
    );

    // 添加到内存日志
    _logs.add(entry);
    
    // 限制内存中的日志数量
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }

    // 控制台输出
    if (_enableConsoleLogging) {
      debugPrint(entry.toString());
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }

    // 文件输出
    if (_enableFileLogging && _logFile != null) {
      _writeToFile(entry);
    }

    // 通知监听器
    for (final listener in _listeners) {
      try {
        listener(entry);
      } catch (e) {
        debugPrint('日志监听器错误: $e');
      }
    }
  }

  // 写入文件
  Future<void> _writeToFile(LogEntry entry) async {
    try {
      final jsonStr = jsonEncode(entry.toJson());
      await _logFile!.writeAsString('$jsonStr\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('写入日志文件失败: $e');
    }
  }

  // 公共日志方法
  void debug(String tag, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, tag, message, data: data);
  }

  void info(String tag, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, tag, message, data: data);
  }

  void warning(String tag, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.warning, tag, message, data: data);
  }

  void error(String tag, String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, tag, message, data: data, stackTrace: stackTrace);
  }

  void fatal(String tag, String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.fatal, tag, message, data: data, stackTrace: stackTrace);
  }

  // 获取日志
  List<LogEntry> getLogs({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
    int? limit,
  }) {
    var filtered = _logs.where((entry) {
      if (minLevel != null && entry.level.index < minLevel.index) return false;
      if (tag != null && entry.tag != tag) return false;
      if (since != null && entry.timestamp.isBefore(since)) return false;
      return true;
    }).toList();

    if (limit != null && filtered.length > limit) {
      filtered = filtered.sublist(filtered.length - limit);
    }

    return filtered;
  }

  // 清空日志
  void clearLogs() {
    _logs.clear();
  }

  // 导出日志
  Future<String?> exportLogs({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
    String? format = 'json', // 'json' or 'text'
  }) async {
    try {
      final logs = getLogs(minLevel: minLevel, tag: tag, since: since);
      
      if (kIsWeb) {
        // Web平台返回内容字符串，由UI层处理下载
        if (format == 'json') {
          final jsonList = logs.map((e) => e.toJson()).toList();
          return jsonEncode(jsonList);
        } else {
          return logs.map((e) => e.toString()).join('\n');
        }
      } else {
        // 移动端和桌面端写入文件
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = format == 'json' ? 'json' : 'txt';
        final exportFile = File('${directory.path}/cineflow_logs_export_$timestamp.$extension');
        
        String content;
        if (format == 'json') {
          final jsonList = logs.map((e) => e.toJson()).toList();
          content = jsonEncode(jsonList);
        } else {
          content = logs.map((e) => e.toString()).join('\n');
        }
        
        await exportFile.writeAsString(content);
        return exportFile.path;
      }
    } catch (e) {
      error('LoggerService', 'Failed to export logs: $e');
      return null;
    }
  }

  // Web平台导出日志内容
  String exportLogsAsString({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
    String format = 'text',
  }) {
    final logs = getLogs(minLevel: minLevel, tag: tag, since: since);
    
    if (format == 'json') {
      final jsonList = logs.map((e) => e.toJson()).toList();
      return jsonEncode(jsonList);
    } else {
      final buffer = StringBuffer();
      buffer.writeln('CineFlow 应用日志导出');
      buffer.writeln('导出时间: ${DateTime.now()}');
      buffer.writeln('日志条数: ${logs.length}');
      buffer.writeln('=' * 50);
      buffer.writeln();
      
      for (final log in logs) {
        buffer.writeln(log.toString());
        if (log.data != null) {
          buffer.writeln('  数据: ${jsonEncode(log.data)}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('  堆栈跟踪:');
          buffer.writeln('    ${log.stackTrace.toString().replaceAll('\n', '\n    ')}');
        }
        buffer.writeln();
      }
      
      return buffer.toString();
    }
  }

  // 获取日志统计
  Map<String, int> getLogStats() {
    final stats = <String, int>{};
    for (final level in LogLevel.values) {
      stats[level.name] = _logs.where((e) => e.level == level).length;
    }
    return stats;
  }

  // 清理旧日志文件
  Future<void> cleanupOldLogs({int keepDays = 7}) async {
    if (!_enableFileLogging) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (await logDir.exists()) {
        final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
        
        await for (final entity in logDir.list()) {
          if (entity is File && entity.path.endsWith('.log')) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
              info('LoggerService', 'Deleted old log file: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      error('LoggerService', 'Failed to cleanup old logs: $e');
    }
  }
}

// 全局错误捕获器
class GlobalErrorHandler {
  static void initialize() {
    // Flutter错误捕获
    FlutterError.onError = (FlutterErrorDetails details) {
      Log.e('FlutterError', details.exception.toString(),
          data: {
            'library': details.library,
            'context': details.context?.toString(),
          },
          stackTrace: details.stack);
    };

    // 异步错误捕获
    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('AsyncError', error.toString(), stackTrace: stack);
      return true;
    };
  }

  // 手动报告错误
  static void reportError(Object error, StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? data,
  }) {
    final errorData = <String, dynamic>{
      if (context != null) 'context': context,
      ...?data,
    };
    
    Log.e('ManualError', error.toString(),
        data: errorData.isNotEmpty ? errorData : null,
        stackTrace: stackTrace);
  }
}

// 便捷的全局日志方法
class Log {
  static final _logger = LoggerService.instance;

  static void d(String tag, String message, {Map<String, dynamic>? data}) {
    _logger.debug(tag, message, data: data);
  }

  static void i(String tag, String message, {Map<String, dynamic>? data}) {
    _logger.info(tag, message, data: data);
  }

  static void w(String tag, String message, {Map<String, dynamic>? data}) {
    _logger.warning(tag, message, data: data);
  }

  static void e(String tag, String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    _logger.error(tag, message, data: data, stackTrace: stackTrace);
  }

  static void f(String tag, String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    _logger.fatal(tag, message, data: data, stackTrace: stackTrace);
  }

  // 捕获并记录异常的包装器
  static T? catchError<T>(T Function() operation, String tag, String context) {
    try {
      return operation();
    } catch (error, stackTrace) {
      e(tag, 'Error in $context: $error', 
          data: {'context': context}, 
          stackTrace: stackTrace);
      return null;
    }
  }

  // 异步操作错误捕获
  static Future<T?> catchAsyncError<T>(
      Future<T> Function() operation, String tag, String context) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      e(tag, 'Async error in $context: $error',
          data: {'context': context},
          stackTrace: stackTrace);
      return null;
    }
  }
}
