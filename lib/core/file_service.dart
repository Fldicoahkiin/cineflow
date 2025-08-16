import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// 文件管理服务
/// 提供文件选择、验证、缓存和元数据管理功能
class FileService {
  FileService({
    this.maxFileSize = 2 * 1024 * 1024 * 1024, // 2GB
    this.allowedExtensions = const [
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v',
      'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a',
    ],
    this.cacheDirectory,
  });

  final int maxFileSize;
  final List<String> allowedExtensions;
  final String? cacheDirectory;

  final Map<String, MediaFileInfo> _fileCache = {};
  final StreamController<FileServiceEvent> _eventController = StreamController.broadcast();
  
  bool _isDisposed = false;

  /// 文件服务事件流
  Stream<FileServiceEvent> get events => _eventController.stream;

  /// 选择单个媒体文件
  Future<MediaFileInfo?> pickSingleFile({
    String? dialogTitle,
    FileType type = FileType.any,
  }) async {
    if (_isDisposed) {
      throw StateError('FileService has been disposed');
    }

    try {
      _emitEvent(FileServiceEvent.selectionStarted());

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom ? allowedExtensions : null,
        dialogTitle: dialogTitle ?? 'Select Media File',
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        _emitEvent(FileServiceEvent.selectionCancelled());
        return null;
      }

      final platformFile = result.files.first;
      final fileInfo = await _processFile(platformFile);
      
      if (fileInfo != null) {
        _fileCache[fileInfo.id] = fileInfo;
        _emitEvent(FileServiceEvent.fileSelected(fileInfo));
      }

      return fileInfo;
    } catch (e, stackTrace) {
      final error = FileServiceException('Failed to pick file', e, stackTrace);
      _emitEvent(FileServiceEvent.error(error));
      rethrow;
    }
  }

  /// 选择多个媒体文件
  Future<List<MediaFileInfo>> pickMultipleFiles({
    String? dialogTitle,
    FileType type = FileType.any,
    int? maxFiles,
  }) async {
    if (_isDisposed) {
      throw StateError('FileService has been disposed');
    }

    try {
      _emitEvent(FileServiceEvent.selectionStarted());

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom ? allowedExtensions : null,
        dialogTitle: dialogTitle ?? 'Select Media Files',
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        _emitEvent(FileServiceEvent.selectionCancelled());
        return [];
      }

      final files = result.files;
      if (maxFiles != null && files.length > maxFiles) {
        throw FileServiceException('Too many files selected. Maximum: $maxFiles');
      }

      final fileInfos = <MediaFileInfo>[];
      for (final platformFile in files) {
        final fileInfo = await _processFile(platformFile);
        if (fileInfo != null) {
          _fileCache[fileInfo.id] = fileInfo;
          fileInfos.add(fileInfo);
        }
      }

      _emitEvent(FileServiceEvent.multipleFilesSelected(fileInfos));
      return fileInfos;
    } catch (e, stackTrace) {
      final error = FileServiceException('Failed to pick files', e, stackTrace);
      _emitEvent(FileServiceEvent.error(error));
      rethrow;
    }
  }

  /// 处理文件并创建MediaFileInfo
  Future<MediaFileInfo?> _processFile(PlatformFile platformFile) async {
    try {
      if (kIsWeb) {
        // Web平台处理
        return _processWebFile(platformFile);
      } else {
        // 移动端和桌面端处理
        return _processNativeFile(platformFile);
      }
    } catch (e, stackTrace) {
      debugPrint('[FileService] Failed to process file ${platformFile.name}: $e');
      _emitEvent(FileServiceEvent.error(
        FileServiceException('Failed to process file ${platformFile.name}', e, stackTrace)
      ));
      return null;
    }
  }

  /// 处理Web平台文件
  Future<MediaFileInfo?> _processWebFile(PlatformFile platformFile) async {
    // Web平台文件大小验证
    final fileSize = platformFile.size;
    if (fileSize > maxFileSize) {
      throw FileServiceException(
        'File too large: ${_formatFileSize(fileSize)} (max: ${_formatFileSize(maxFileSize)})'
      );
    }

    // 验证文件扩展名
    final extension = p.extension(platformFile.name).toLowerCase().replaceFirst('.', '');
    if (allowedExtensions.isNotEmpty && !allowedExtensions.contains(extension)) {
      throw FileServiceException(
        'Unsupported file type: .$extension (allowed: ${allowedExtensions.join(', ')})'
      );
    }

    // Web平台创建文件信息（使用文件名作为路径）
    final fileInfo = MediaFileInfo(
      id: _generateFileId(platformFile.name + fileSize.toString()),
      name: platformFile.name,
      path: platformFile.name, // Web平台使用文件名
      size: fileSize,
      extension: extension,
      mimeType: _getMimeType(extension),
      lastModified: DateTime.now(), // Web平台无法获取真实修改时间
      isValid: true,
      metadata: {
        'isWeb': true,
        'bytes': platformFile.bytes, // 保存文件字节数据
      },
    );

    debugPrint('[FileService] Processed web file: ${fileInfo.name} (${_formatFileSize(fileSize)})');
    return fileInfo;
  }

  /// 处理原生平台文件
  Future<MediaFileInfo?> _processNativeFile(PlatformFile platformFile) async {
    // 验证文件路径
    final filePath = platformFile.path;
    if (filePath == null) {
      throw FileServiceException('File path is null');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileServiceException('File does not exist: $filePath');
    }

    // 验证文件大小
    final fileSize = await file.length();
    if (fileSize > maxFileSize) {
      throw FileServiceException(
        'File too large: ${_formatFileSize(fileSize)} (max: ${_formatFileSize(maxFileSize)})'
      );
    }

    // 验证文件扩展名
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    if (allowedExtensions.isNotEmpty && !allowedExtensions.contains(extension)) {
      throw FileServiceException(
        'Unsupported file type: .$extension (allowed: ${allowedExtensions.join(', ')})'
      );
    }

    // 创建文件信息
    final fileInfo = MediaFileInfo(
      id: _generateFileId(filePath),
      name: platformFile.name,
      path: filePath,
      size: fileSize,
      extension: extension,
      mimeType: _getMimeType(extension),
      lastModified: await file.lastModified(),
      isValid: true,
    );

    debugPrint('[FileService] Processed native file: ${fileInfo.name} (${_formatFileSize(fileSize)})');
    return fileInfo;
  }

  /// 验证文件是否仍然有效
  Future<bool> validateFile(String fileId) async {
    if (_isDisposed) return false;

    final fileInfo = _fileCache[fileId];
    if (fileInfo == null) return false;

    try {
      if (kIsWeb) {
        // Web平台：检查是否有字节数据
        final isWebFile = fileInfo.metadata?['isWeb'] == true;
        final hasBytes = fileInfo.metadata?['bytes'] != null;
        return isWebFile && hasBytes;
      } else {
        // 原生平台：检查文件是否存在
        final file = File(fileInfo.path);
        final exists = await file.exists();
        
        if (!exists) {
          _fileCache.remove(fileId);
          _emitEvent(FileServiceEvent.fileInvalidated(fileInfo));
          return false;
        }

        // 检查文件是否被修改
        final lastModified = await file.lastModified();
        if (lastModified != fileInfo.lastModified) {
          // 文件已被修改，更新缓存
          final updatedInfo = fileInfo.copyWith(lastModified: lastModified);
          _fileCache[fileId] = updatedInfo;
          _emitEvent(FileServiceEvent.fileUpdated(updatedInfo));
        }

        return true;
      }
    } catch (e) {
      debugPrint('[FileService] Error validating file $fileId: $e');
      return false;
    }
  }

  /// 获取文件信息
  MediaFileInfo? getFileInfo(String fileId) {
    return _fileCache[fileId];
  }

  /// 获取所有缓存的文件
  List<MediaFileInfo> getAllFiles() {
    return _fileCache.values.toList();
  }

  /// 清除文件缓存
  void clearCache() {
    final clearedFiles = _fileCache.values.toList();
    _fileCache.clear();
    _emitEvent(FileServiceEvent.cacheCleared(clearedFiles));
    debugPrint('[FileService] Cache cleared (${clearedFiles.length} files)');
  }

  /// 移除特定文件
  void removeFile(String fileId) {
    final fileInfo = _fileCache.remove(fileId);
    if (fileInfo != null) {
      _emitEvent(FileServiceEvent.fileRemoved(fileInfo));
      debugPrint('[FileService] Removed file: ${fileInfo.name}');
    }
  }

  /// 生成文件ID
  String _generateFileId(String filePath) {
    return filePath.hashCode.abs().toString();
  }

  /// 获取MIME类型
  String _getMimeType(String extension) {
    const mimeTypes = {
      // 视频
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'mov': 'video/quicktime',
      'wmv': 'video/x-ms-wmv',
      'flv': 'video/x-flv',
      'webm': 'video/webm',
      'm4v': 'video/x-m4v',
      // 音频
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'm4a': 'audio/mp4',
    };
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 发送事件
  void _emitEvent(FileServiceEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  /// 释放资源
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('[FileService] Disposing');
    _isDisposed = true;
    
    _fileCache.clear();
    _eventController.close();
  }
}

/// 媒体文件信息
class MediaFileInfo {
  const MediaFileInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.extension,
    required this.mimeType,
    required this.lastModified,
    required this.isValid,
    this.metadata,
  });

  final String id;
  final String name;
  final String path;
  final int size;
  final String extension;
  final String mimeType;
  final DateTime lastModified;
  final bool isValid;
  final Map<String, dynamic>? metadata;

  /// 是否为视频文件
  bool get isVideo => mimeType.startsWith('video/');

  /// 是否为音频文件
  bool get isAudio => mimeType.startsWith('audio/');

  /// 文件URI
  String get uri {
    if (metadata?['isWeb'] == true) {
      // Web平台返回blob URL或data URL
      return 'blob:$name';
    }
    return 'file://$path';
  }

  /// 是否为Web平台文件
  bool get isWebFile => metadata?['isWeb'] == true;

  /// 获取Web平台文件字节数据
  Uint8List? get webBytes => metadata?['bytes'] as Uint8List?;

  /// 复制并更新属性
  MediaFileInfo copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    String? extension,
    String? mimeType,
    DateTime? lastModified,
    bool? isValid,
    Map<String, dynamic>? metadata,
  }) {
    return MediaFileInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      extension: extension ?? this.extension,
      mimeType: mimeType ?? this.mimeType,
      lastModified: lastModified ?? this.lastModified,
      isValid: isValid ?? this.isValid,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'MediaFileInfo(id: $id, name: $name, size: $size, type: $mimeType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaFileInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 文件服务事件
sealed class FileServiceEvent {
  const FileServiceEvent();

  factory FileServiceEvent.selectionStarted() = FileSelectionStarted;
  factory FileServiceEvent.selectionCancelled() = FileSelectionCancelled;
  factory FileServiceEvent.fileSelected(MediaFileInfo file) = FileSelected;
  factory FileServiceEvent.multipleFilesSelected(List<MediaFileInfo> files) = MultipleFilesSelected;
  factory FileServiceEvent.fileRemoved(MediaFileInfo file) = FileRemoved;
  factory FileServiceEvent.fileUpdated(MediaFileInfo file) = FileUpdated;
  factory FileServiceEvent.fileInvalidated(MediaFileInfo file) = FileInvalidated;
  factory FileServiceEvent.cacheCleared(List<MediaFileInfo> files) = CacheCleared;
  factory FileServiceEvent.error(FileServiceException error) = FileServiceError;
}

class FileSelectionStarted extends FileServiceEvent {
  const FileSelectionStarted();
}

class FileSelectionCancelled extends FileServiceEvent {
  const FileSelectionCancelled();
}

class FileSelected extends FileServiceEvent {
  const FileSelected(this.file);
  final MediaFileInfo file;
}

class MultipleFilesSelected extends FileServiceEvent {
  const MultipleFilesSelected(this.files);
  final List<MediaFileInfo> files;
}

class FileRemoved extends FileServiceEvent {
  const FileRemoved(this.file);
  final MediaFileInfo file;
}

class FileUpdated extends FileServiceEvent {
  const FileUpdated(this.file);
  final MediaFileInfo file;
}

class FileInvalidated extends FileServiceEvent {
  const FileInvalidated(this.file);
  final MediaFileInfo file;
}

class CacheCleared extends FileServiceEvent {
  const CacheCleared(this.files);
  final List<MediaFileInfo> files;
}

class FileServiceError extends FileServiceEvent {
  const FileServiceError(this.error);
  final FileServiceException error;
}

/// 文件服务异常
class FileServiceException implements Exception {
  const FileServiceException(this.message, [this.cause, this.stackTrace]);
  
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (cause != null) {
      return 'FileServiceException: $message\nCaused by: $cause';
    }
    return 'FileServiceException: $message';
  }
}
