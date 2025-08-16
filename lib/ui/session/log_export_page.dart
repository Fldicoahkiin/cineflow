import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/logger_service.dart';
import '../../l10n/app_localizations.dart';

class LogExportPage extends StatefulWidget {
  const LogExportPage({super.key});

  @override
  State<LogExportPage> createState() => _LogExportPageState();
}

class _LogExportPageState extends State<LogExportPage> {
  final _logger = LoggerService.instance;
  LogLevel? _selectedLevel;
  String? _selectedTag;
  DateTime? _sinceDate;
  String _exportFormat = 'text';
  bool _isExporting = false;

  final List<String> _availableTags = [
    'Main',
    'AppManager',
    'SessionManager',
    'PlayerController',
    'SyncPlayback',
    'P2PConnectionManager',
    'SignalingClient',
    'JoinSessionPage',
    'FlutterError',
    'AsyncError',
    'ManualError',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logs = _logger.getLogs(
      minLevel: _selectedLevel,
      tag: _selectedTag,
      since: _sinceDate,
    );
    final stats = _logger.getLogStats();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.logExport ?? 'Log Export'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: l10n?.refresh ?? 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _showClearLogsDialog,
            tooltip: l10n?.clearLogs ?? 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.logStatistics ?? 'Log Statistics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: stats.entries.map((entry) {
                      final color = _getLevelColor(entry.key);
                      return Chip(
                        label: Text('${entry.key.toUpperCase()}: ${entry.value}'),
                        backgroundColor: color.withOpacity(0.1),
                        side: BorderSide(color: color),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n?.filteredLogs ?? 'Filtered Logs'}: ${logs.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // 过滤器
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.filters ?? 'Filters',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  
                  // 日志级别过滤
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<LogLevel?>(
                          value: _selectedLevel,
                          decoration: InputDecoration(
                            labelText: l10n?.logLevel ?? 'Log Level',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<LogLevel?>(
                              value: null,
                              child: Text(l10n?.all ?? 'All'),
                            ),
                            ...LogLevel.values.map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.name.toUpperCase()),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedLevel = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 标签过滤
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedTag,
                          decoration: InputDecoration(
                            labelText: l10n?.tag ?? 'Tag',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n?.all ?? 'All'),
                            ),
                            ..._availableTags.map((tag) => DropdownMenuItem(
                              value: tag,
                              child: Text(tag),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedTag = value),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 时间过滤和导出格式
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectSinceDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n?.sinceDate ?? 'Since Date',
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              _sinceDate?.toString().substring(0, 19) ?? 
                              (l10n?.noFilter ?? 'No Filter'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 导出格式
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _exportFormat,
                          decoration: InputDecoration(
                            labelText: l10n?.exportFormat ?? 'Export Format',
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'text', child: Text('Text')),
                            DropdownMenuItem(value: 'json', child: Text('JSON')),
                          ],
                          onChanged: (value) => setState(() => _exportFormat = value!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 导出按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportLogs,
                    icon: _isExporting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isExporting 
                        ? (l10n?.exporting ?? 'Exporting...') 
                        : (l10n?.exportLogs ?? 'Export Logs')),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: Text(l10n?.copyToClipboard ?? 'Copy'),
                ),
              ],
            ),
          ),

          // 日志预览
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${l10n?.logPreview ?? 'Log Preview'} (${logs.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: logs.isEmpty
                        ? Center(
                            child: Text(
                              l10n?.noLogsFound ?? 'No logs found',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return _buildLogItem(log);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final color = _getLevelColor(log.level.name);
    
    return ExpansionTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        log.message,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${log.timestamp.toString().substring(11, 23)} [${log.tag}] ${log.level.name.toUpperCase()}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        if (log.data != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Data: ${jsonEncode(log.data)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        if (log.stackTrace != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stack Trace:\n${log.stackTrace}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Colors.grey;
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'fatal':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectSinceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sinceDate ?? DateTime.now().subtract(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_sinceDate ?? DateTime.now()),
      );
      
      if (time != null) {
        setState(() {
          _sinceDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _exportLogs() async {
    setState(() => _isExporting = true);
    
    try {
      final result = await _logger.exportLogs(
        minLevel: _selectedLevel,
        tag: _selectedTag,
        since: _sinceDate,
        format: _exportFormat,
      );

      if (!mounted) return;

      if (kIsWeb) {
        // Web平台：触发下载
        _downloadFile(result!, _exportFormat);
        _showSnackBar('日志已准备下载');
      } else {
        // 移动端和桌面端：显示文件路径
        if (result != null) {
          _showSnackBar('日志已导出到: $result');
        } else {
          _showSnackBar('导出失败', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('导出失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final content = _logger.exportLogsAsString(
      minLevel: _selectedLevel,
      tag: _selectedTag,
      since: _sinceDate,
      format: _exportFormat,
    );

    await Clipboard.setData(ClipboardData(text: content));
    _showSnackBar('日志已复制到剪贴板');
  }

  void _downloadFile(String content, String format) {
    // Web平台文件下载实现
    // 这里需要使用dart:html，但为了避免平台特定代码，
    // 我们先显示内容，让用户手动保存
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出内容'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(context);
              _showSnackBar('内容已复制到剪贴板');
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _showClearLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _logger.clearLogs();
              Navigator.pop(context);
              setState(() {});
              _showSnackBar('日志已清空');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
