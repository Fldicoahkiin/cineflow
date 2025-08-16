import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../session/p2p_connection_manager.dart';
import '../../../session/loopback_service.dart';
import '../../../session/sync_playback_manager.dart';
import '../../player/player_controller.dart';
import '../../core/logger_service.dart';
import '../../core/file_service.dart';
import '../../l10n/app_localizations.dart';

class JoinSessionPage extends StatefulWidget {
  const JoinSessionPage({super.key});

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage> {
  final _urlCtrl = TextEditingController(text: 'ws://localhost:8080');
  final _sessionIdCtrl = TextEditingController();
  final _mediaCtrl = TextEditingController();
  List<LogEntry> _logs = [];
  late final Function(LogEntry) _logListener;
  
  P2PConnectionManager? _p2pManager;
  P2PConnectionState _connectionState = P2PConnectionState.idle;
  String? _currentRoomId;
  // 环回测试相关
  LoopbackService? _loop;
  bool _loopReady = false;
  int? _rttA, _rttB;
  
  PlayerController? _player;
  FileService? _fileService;
  bool _fileSelecting = false;
  
  // 同步播放管理器
  SyncPlaybackManager? _syncManager;
  SyncState _syncState = SyncState.idle;
  bool _isSyncEnabled = true;
  bool _isHost = false;
  
  // 播放器状态
  bool _isPlaying = false;
  double _positionMs = 0.0;
  
  StreamSubscription? _posSub, _playSub, _fileEventSub, _syncStateSub, _syncErrorSub;


  void _setupLoopback() async {
    try {
      _loop?.dispose();
      final loop = LoopbackService();
      await loop.setup();
      _loop = loop;
      
      setState(() {
        _loopReady = true;
      });
      Log.i('LoopbackService', AppLocalizations.of(context)?.loopbackTestStarted ?? 'Loopback service established');
      
      _loop?.onRtt = (receiver, rttMs) {
        if (mounted) {
          setState(() {
            if (receiver == 'A') {
              _rttA = rttMs;
            } else {
              _rttB = rttMs;
            }
          });
        }
      };
      
      loop.onStateUpdate = (receiver, payload) {
        if (mounted) {
          setState(() {
            _isPlaying = payload.isPlaying;
            _positionMs = payload.positionMs.toDouble();
          });
          _applyStateToPlayer(payload);
        }
      };
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n?.error_loopbackFailed ?? 'Failed to setup loopback'}: $e', isError: true);
    }
  }

  void _sendA() {
    // 发送测试消息 - 根据实际LoopbackService API调整
    Log.i('LoopbackService', 'Send test message');
    setState(() {});
  }


  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    
    final p = PlayerController();
    
    _playSub = p.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    _posSub = p.positionMsStream.listen((pos) {
      if (mounted) setState(() => _positionMs = pos.toDouble());
    });
    
    setState(() => _player = p);
    
    // 初始化同步播放管理器
    await _initializeSyncManager();
  }

  Future<void> _initializeSyncManager() async {
    if (_player == null || _p2pManager?.sessionManager == null) return;
    
    _syncManager?.dispose();
    
    final syncManager = SyncPlaybackManager(
      sessionManager: _p2pManager!.sessionManager!,
      playerController: _player!,
    );
    
    _syncStateSub = syncManager.syncStateStream.listen((state) {
      if (mounted) setState(() => _syncState = state);
    });
    
    _syncErrorSub = syncManager.syncErrorStream.listen((error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showSnackBar('${l10n?.syncError ?? 'Sync error'}: ${error.message}', isError: true);
        Log.e('SyncPlayback', error.message);
      }
    });
    
    setState(() => _syncManager = syncManager);
    Log.i('SyncPlayback', 'Sync playback manager initialized');
  }

  Future<void> _loadMedia() async {
    if (_mediaCtrl.text.isEmpty) return;
    await _ensurePlayer();
    await _player!.load(_mediaCtrl.text);
    final l10n = AppLocalizations.of(context);
    _showSnackBar(l10n?.mediaLoading ?? 'Media loading...', isError: false);
  }

  void _playMedia() async {
    await _ensurePlayer();
    
    if (_isSyncEnabled && _syncManager != null) {
      await _syncManager!.syncPlay();
    } else {
      await _player!.play();
    }
  }

  void _pauseMedia() async {
    await _ensurePlayer();
    
    if (_isSyncEnabled && _syncManager != null) {
      await _syncManager!.syncPause();
    } else {
      await _player!.pause();
    }
  }

  void _seekMedia(double positionMs) async {
    await _ensurePlayer();
    
    if (_isSyncEnabled && _syncManager != null) {
      await _syncManager!.syncSeek(positionMs.toInt());
    } else {
      await _player!.seekMs(positionMs.toInt());
    }
  }

  void _setPlaybackRate(double rate) async {
    await _ensurePlayer();
    
    if (_isSyncEnabled && _syncManager != null) {
      await _syncManager!.syncRate(rate);
    } else {
      await _player!.setRate(rate);
    }
  }

  void _pickFile() async {
    setState(() => _fileSelecting = true);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          _mediaCtrl.text = file.path!;
          _showSnackBar('已选择文件: ${file.name}');
        }
      }
    } finally {
      setState(() => _fileSelecting = false);
    }
  }

  void _applyStateToPlayer(payload) {
    // 实现播放器状态同步
    if (_player != null) {
      if (payload.isPlaying && !_isPlaying) {
        _player!.play();
      } else if (!payload.isPlaying && _isPlaying) {
        _player!.pause();
      }
      // TODO: 同步播放位置
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }


  // P2P连接管理
  Future<void> _createSession() async {
    if (_urlCtrl.text.isEmpty) return;
    
    try {
      _p2pManager?.dispose();
      final manager = P2PConnectionManager(signalingUrl: _urlCtrl.text);
      
      manager.onStateChanged = (state) {
        if (mounted) {
          setState(() => _connectionState = state);
        }
      };
      
      final roomId = await manager.createSession();
      if (mounted) {
        setState(() {
          _currentRoomId = roomId;
          _isHost = true; // 创建者为主持人
          _p2pManager = manager;
        });
        final l10n = AppLocalizations.of(context);
        _showSnackBar('${l10n?.sessionCreatedSuccess ?? 'Room created successfully'}: $roomId', isError: false);
        
        // 启动同步会话
        _startSyncSession(roomId, asHost: true);
      }
      
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n?.error_createSessionFailed ?? 'Failed to create session'}: $e', isError: true);
    }
  }

  void _joinSession() async {
    if (_urlCtrl.text.isEmpty || _sessionIdCtrl.text.isEmpty) return;
    
    try {
      _p2pManager?.dispose();
      final manager = P2PConnectionManager(signalingUrl: _urlCtrl.text);
      
      manager.onStateChanged = (state) {
        if (mounted) {
          setState(() => _connectionState = state);
        }
      };
      
      await manager.joinSession(_sessionIdCtrl.text);
      if (mounted) {
        setState(() {
          _p2pManager = manager;
          _currentRoomId = _sessionIdCtrl.text;
          _isHost = false; // 加入者不是主持人
        });
        
        // 启动同步会话
        _startSyncSession(_sessionIdCtrl.text, asHost: false);
      }
      
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n?.error_joinSessionFailed ?? 'Failed to join session'}: $e', isError: true);
    }
  }

  void _startSyncSession(String sessionId, {required bool asHost}) async {
    if (_syncManager != null) {
      await _syncManager!.startSyncSession(sessionId, asHost: asHost);
      Log.i('SyncPlayback', 'Start sync session: $sessionId (host: $asHost)');
    }
  }
  
  Future<void> _disconnectP2P() async {
    try {
      await _p2pManager?.dispose();
      setState(() {
        _p2pManager = null;
        _connectionState = P2PConnectionState.idle;
        _currentRoomId = null;
      });
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n?.disconnectedSuccess ?? 'Disconnected successfully');
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n?.error_disconnectFailed ?? 'Failed to disconnect'}: $e', isError: true);
    }
  }
  
  bool _canCreateSession() => _urlCtrl.text.trim().isNotEmpty && _connectionState == P2PConnectionState.idle;
  bool _canJoinSession() => _urlCtrl.text.trim().isNotEmpty && _sessionIdCtrl.text.trim().isNotEmpty && _connectionState == P2PConnectionState.idle;
  bool _canDisconnect() => _connectionState != P2PConnectionState.idle;
  
  @override
  void initState() {
    super.initState();
    
    // 设置日志监听器
    _logListener = (LogEntry entry) {
      if (mounted) {
        setState(() {
          _logs = LoggerService.instance.getLogs(limit: 100);
        });
      }
    };
    LoggerService.instance.addListener(_logListener);
    
    // 初始化日志列表
    _logs = LoggerService.instance.getLogs(limit: 100);
    
    Log.i('JoinSessionPage', 'Page initialized');
    
    _initFileService();
  }
  
  void _initFileService() {
    _fileService = FileService(
      allowedExtensions: ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'],
    );
  }
  
  @override
  void dispose() {
    _urlCtrl.dispose();
    _sessionIdCtrl.dispose();
    _mediaCtrl.dispose();
    _p2pManager?.dispose();
    _loop?.dispose();
    _player?.dispose();
    _fileService?.dispose();
    _syncManager?.dispose();
    _posSub?.cancel();
    _playSub?.cancel();
    _fileEventSub?.cancel();
    _syncStateSub?.cancel();
    _syncErrorSub?.cancel();
    LoggerService.instance.removeListener(_logListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('CineFlow'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 16),
            _buildPlayerCard(),
            const SizedBox(height: 16),
            _buildLoopbackCard(),
            const SizedBox(height: 16),
            _buildLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('P2P连接', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: '信令服务器URL',
                hintText: 'ws://localhost:8080',
                prefixIcon: const Icon(Icons.cloud_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sessionIdCtrl,
              decoration: InputDecoration(
                labelText: '会话ID',
                hintText: '输入要加入的会话ID',
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentRoomId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '当前会话: $_currentRoomId',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canCreateSession() ? _createSession : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(AppLocalizations.of(context)?.createSession ?? 'Create Session'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _canJoinSession() ? _joinSession : null,
                    icon: const Icon(Icons.login),
                    label: Text(AppLocalizations.of(context)?.joinSession ?? 'Join Session'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canDisconnect() ? _disconnectP2P : null,
                icon: const Icon(Icons.logout),
                label: Text(AppLocalizations.of(context)?.disconnect ?? 'Disconnect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library_outlined, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 12),
                Text('媒体播放器', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mediaCtrl,
                    decoration: InputDecoration(
                      labelText: '媒体地址',
                      hintText: '选择本地文件或输入URL',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _fileSelecting ? null : _pickFile,
                  icon: _fileSelecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_fileSelecting ? '选择中...' : '选择文件'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _mediaCtrl.text.isNotEmpty ? _loadMedia : null,
                    icon: const Icon(Icons.play_circle_fill),
                    label: Text(AppLocalizations.of(context)?.loadMedia ?? 'Load Media'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isPlaying ? _pauseMedia : _playMedia,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying ? (AppLocalizations.of(context)?.pause ?? 'Pause') : (AppLocalizations.of(context)?.play ?? 'Play')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 播放进度控制
            _buildProgressControls(),
            const SizedBox(height: 16),
            // 同步播放控制
            _buildSyncControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressControls() {
    final duration = _player?.durationMs ?? 0;
    final position = _positionMs.clamp(0.0, duration.toDouble());
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.playbackProgress ?? 'Playback Progress',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _formatDuration(position.toInt()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: duration > 0 ? position / duration : 0.0,
                  onChanged: duration > 0 ? (value) {
                    final newPosition = (value * duration).toDouble();
                    setState(() => _positionMs = newPosition);
                  } : null,
                  onChangeEnd: duration > 0 ? (value) {
                    final newPosition = (value * duration).toDouble();
                    _seekMedia(newPosition);
                  } : null,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _setPlaybackRate(0.5),
                icon: const Icon(Icons.speed),
                tooltip: '0.5x',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _setPlaybackRate(1.0),
                icon: const Icon(Icons.play_circle_outline),
                tooltip: '1.0x',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _setPlaybackRate(1.5),
                icon: const Icon(Icons.fast_forward),
                tooltip: '1.5x',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _setPlaybackRate(2.0),
                icon: const Icon(Icons.fast_forward),
                tooltip: '2.0x',
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSyncControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSyncStateColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSyncStateIcon(),
                color: _getSyncStateColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.syncPlayback ?? 'Sync Playback',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getSyncStateColor(),
                ),
              ),
              const Spacer(),
              Switch(
                value: _isSyncEnabled,
                onChanged: (value) {
                  setState(() => _isSyncEnabled = value);
                  _syncManager?.setSyncEnabled(value);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.syncState ?? 'State',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSyncStateText(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _getSyncStateColor(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.syncRole ?? 'Role',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isHost ? (AppLocalizations.of(context)?.syncHost ?? 'Host') : (AppLocalizations.of(context)?.syncParticipant ?? 'Participant'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _isHost ? Colors.orange[700] : Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              if (_syncManager?.networkLatencyMs != null && _syncManager!.networkLatencyMs > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.syncLatency ?? 'Latency',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_syncManager!.networkLatencyMs}ms',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _getLatencyColor(_syncManager!.networkLatencyMs),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_syncManager?.peerStates.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              '${AppLocalizations.of(context)?.syncPeerStates ?? 'Peer States'} (${_syncManager!.peerStates.length})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...(_syncManager!.peerStates.entries.take(3).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    entry.value.isPlaying ? Icons.play_arrow : Icons.pause,
                    size: 16,
                    color: entry.value.isPlaying ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${entry.key.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${(entry.value.position / 1000).toStringAsFixed(1)}s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ))),
          ],
        ],
      ),
    );
  }

  Color _getSyncStateColor() {
    switch (_syncState) {
      case SyncState.connected:
        return Colors.green[600]!;
      case SyncState.syncing:
        return Colors.blue[600]!;
      case SyncState.error:
        return Colors.red[600]!;
      case SyncState.disconnected:
        return Colors.orange[600]!;
      case SyncState.idle:
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getSyncStateIcon() {
    switch (_syncState) {
      case SyncState.connected:
        return Icons.sync;
      case SyncState.syncing:
        return Icons.sync_outlined;
      case SyncState.error:
        return Icons.sync_problem;
      case SyncState.disconnected:
        return Icons.sync_disabled;
      case SyncState.idle:
      default:
        return Icons.sync_alt;
    }
  }

  String _getSyncStateText() {
    final l10n = AppLocalizations.of(context);
    switch (_syncState) {
      case SyncState.connected:
        return l10n?.syncConnected ?? 'Connected';
      case SyncState.syncing:
        return l10n?.syncSyncing ?? 'Syncing';
      case SyncState.error:
        return l10n?.syncError ?? 'Error';
      case SyncState.disconnected:
        return l10n?.syncDisconnected ?? 'Disconnected';
      case SyncState.idle:
      default:
        return l10n?.syncIdle ?? 'Idle';
    }
  }

  Color _getLatencyColor(int latencyMs) {
    if (latencyMs < 100) return Colors.green[600]!;
    if (latencyMs < 300) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  Widget _buildLoopbackCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 12),
                Text('本地环回测试', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _setupLoopback,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(AppLocalizations.of(context)?.startTest ?? 'Start Test'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loopReady ? _sendA : null,
                    icon: const Icon(Icons.send),
                    label: Text(AppLocalizations.of(context)?.sendTest ?? 'Send Test'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RTT A', style: Theme.of(context).textTheme.labelSmall),
                            Text('${_rttA ?? '-'} ms', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RTT B', style: Theme.of(context).textTheme.labelSmall),
                            Text('${_rttB ?? '-'} ms', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isPlaying ? Icons.play_circle : Icons.pause_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('播放状态', style: Theme.of(context).textTheme.labelMedium),
                const Spacer(),
                Switch(
                  value: _isPlaying,
                  onChanged: (v) => setState(() => _isPlaying = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('播放位置: ${(_positionMs / 1000).toStringAsFixed(1)}s', 
                  style: Theme.of(context).textTheme.labelMedium),
                Slider(
                  value: _positionMs,
                  min: 0,
                  max: 300000,
                  onChanged: (v) => setState(() => _positionMs = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)?.systemLogs ?? 'System Logs', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _logs.clear()),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(AppLocalizations.of(context)?.clearLogs ?? 'Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '暂无日志',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final color = _getLogColor(log.level, context);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log.toString(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: color,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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

}
