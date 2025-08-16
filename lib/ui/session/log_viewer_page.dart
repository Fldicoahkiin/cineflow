import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// import 'package:share_plus/share_plus.dart'; // Removed - not in dependencies
import '../../core/logger_service.dart';
import '../../l10n/app_localizations.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<LogEntry> _logs = [];
  LogLevel? _filterLevel;
  String? _filterTag;
  late final Function(LogEntry) _logListener;
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // 设置日志监听器
    _logListener = (LogEntry entry) {
      if (mounted) {
        _refreshLogs();
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    };
    LoggerService.instance.addListener(_logListener);
    
    _refreshLogs();
  }

  @override
  void dispose() {
    LoggerService.instance.removeListener(_logListener);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshLogs() {
    setState(() {
      _logs = LoggerService.instance.getLogs(
        minLevel: _filterLevel,
        tag: _filterTag,
      );
      
      // 应用搜索过滤
      final searchText = _searchController.text.toLowerCase();
      if (searchText.isNotEmpty) {
        _logs = _logs.where((log) => 
          log.message.toLowerCase().contains(searchText) ||
          log.tag.toLowerCase().contains(searchText)
        ).toList();
      }
    });
  }

  Color _getLogColor(LogLevel level, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (level) {
      case LogLevel.debug:
        return colorScheme.outline;
      case LogLevel.info:
        return colorScheme.primary;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return colorScheme.error;
      case LogLevel.fatal:
        return Colors.red[800]!;
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.fatal:
        return Icons.dangerous;
    }
  }

  Future<void> _exportLogs() async {
    try {
      final path = await LoggerService.instance.exportLogs(
        minLevel: _filterLevel,
        tag: _filterTag,
      );
      
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('${AppLocalizations.of(context)?.exportedTo ?? 'Logs exported to'}: $path')),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: AppLocalizations.of(context)?.copyPath ?? 'Copy Path',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: path));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.exportFailed ?? 'Export failed'}: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.clearLogsTitle ?? 'Clear Logs'),
        content: Text(AppLocalizations.of(context)?.clearLogsConfirm ?? 'Are you sure you want to clear all logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              LoggerService.instance.clearLogs();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)?.confirm ?? 'Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = LoggerService.instance.getLogStats();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.systemLogs ?? 'System Logs'),
        actions: [
          IconButton(
            onPressed: _exportLogs,
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)?.exportLogs ?? 'Export Logs',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: AppLocalizations.of(context)?.clearLogs ?? 'Clear Logs',
          ),
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: AppLocalizations.of(context)?.filterLevel ?? 'Filter Level',
            onSelected: (level) {
              setState(() {
                _filterLevel = level;
              });
              _refreshLogs();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text(AppLocalizations.of(context)?.all ?? 'All'),
              ),
              ...LogLevel.values.map((level) => PopupMenuItem(
                value: level,
                child: Row(
                  children: [
                    Icon(_getLogIcon(level), size: 16),
                    const SizedBox(width: 8),
                    Text(level.name.toUpperCase()),
                    const Spacer(),
                    Text('${stats[level.name] ?? 0}'),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索日志内容或标签...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _refreshLogs();
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
              onChanged: (_) => _refreshLogs(),
            ),
          ),
          
          // 统计信息
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Row(
              children: [
                Text(
                  '${AppLocalizations.of(context)?.totalLogs ?? 'Total'} ${_logs.length} ${AppLocalizations.of(context)?.logs ?? 'logs'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Switch(
                  value: _autoScroll,
                  onChanged: (value) {
                    setState(() {
                      _autoScroll = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)?.autoScroll ?? 'Auto Scroll',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          
          // 日志列表
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)?.noLogsAvailable ?? 'No logs available',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final color = _getLogColor(log.level, context);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _showLogDetails(log),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _getLogIcon(log.level),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              log.level.name.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              log.tag,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            log.timestamp.toString().substring(11, 23),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        log.message,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (log.data != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Data: ${log.data}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.outline,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getLogIcon(log.level), color: _getLogColor(log.level, context)),
            const SizedBox(width: 8),
            Text(log.level.name.toUpperCase()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(AppLocalizations.of(context)?.timestamp ?? 'Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)),
              _buildDetailRow(AppLocalizations.of(context)?.tag ?? 'Tag', log.tag),
              _buildDetailRow(AppLocalizations.of(context)?.message ?? 'Message', log.message),
              if (log.data != null)
                _buildDetailRow(AppLocalizations.of(context)?.data ?? 'Data', log.data.toString()),
              if (log.stackTrace != null)
                _buildDetailRow(AppLocalizations.of(context)?.stackTrace ?? 'Stack Trace', log.stackTrace.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.toString()));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)?.copiedToClipboard ?? 'Copied to clipboard')),
              );
            },
            child: Text(AppLocalizations.of(context)?.copy ?? 'Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.close ?? 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
