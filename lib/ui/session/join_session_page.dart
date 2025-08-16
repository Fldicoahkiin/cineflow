import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../session/p2p_connection_manager.dart';
import '../../session/loopback_service.dart';
import '../../player/player_controller.dart';
import '../../core/file_service.dart';

class JoinSessionPage extends StatefulWidget {
  const JoinSessionPage({super.key});

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage> {
  final _urlCtrl = TextEditingController(text: 'ws://localhost:8080');
  final _sessionIdCtrl = TextEditingController();
  final _mediaCtrl = TextEditingController();
  final List<String> _logs = [];
  
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
  
  // 播放器状态
  bool _isPlaying = false;
  double _positionMs = 0.0;
  
  StreamSubscription? _posSub, _playSub, _fileEventSub;


  void _setupLoopback() async {
    try {
      _loop?.dispose();
      final loop = LoopbackService();
      await loop.setup();
      _loop = loop;
      
      setState(() {
        _loopReady = true;
        _logs.clear();
      });
      _logs.add('环回服务已建立');
      
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
      _showSnackBar('环回建立失败: $e', isError: true);
    }
  }

  void _sendA() {
    // 发送测试消息 - 根据实际LoopbackService API调整
    _logs.add('发送测试消息');
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
  }

  Future<void> _loadMedia() async {
    if (_mediaCtrl.text.isEmpty) return;
    await _ensurePlayer();
    await _player!.load(_mediaCtrl.text);
    _showSnackBar('媒体加载中...', isError: false);
  }

  void _playMedia() async {
    await _ensurePlayer();
    await _player!.play();
  }

  void _pauseMedia() async {
    await _ensurePlayer();
    await _player!.pause();
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
  Future<void> _createP2PSession() async {
    try {
      final manager = P2PConnectionManager(
        signalingUrl: _urlCtrl.text.trim(),
      );
      
      await manager.createSession();
      
      setState(() {
        _p2pManager = manager;
        _connectionState = manager.state;
        _currentRoomId = 'session_created';
      });
      
      _showSnackBar('会话创建成功');
    } catch (e) {
      _showSnackBar('创建会话失败: $e', isError: true);
    }
  }
  
  Future<void> _joinP2PSession() async {
    try {
      final manager = P2PConnectionManager(
        signalingUrl: _urlCtrl.text.trim(),
      );
      
      await manager.joinSession(_sessionIdCtrl.text.trim());
      
      setState(() {
        _p2pManager = manager;
        _connectionState = manager.state;
        _currentRoomId = _sessionIdCtrl.text.trim();
      });
      
      _showSnackBar('加入会话成功');
    } catch (e) {
      _showSnackBar('加入会话失败: $e', isError: true);
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
      _showSnackBar('已断开连接');
    } catch (e) {
      _showSnackBar('断开连接失败: $e', isError: true);
    }
  }
  
  bool _canCreateSession() => _urlCtrl.text.trim().isNotEmpty && _connectionState == P2PConnectionState.idle;
  bool _canJoinSession() => _urlCtrl.text.trim().isNotEmpty && _sessionIdCtrl.text.trim().isNotEmpty && _connectionState == P2PConnectionState.idle;
  bool _canDisconnect() => _connectionState != P2PConnectionState.idle;
  
  @override
  void initState() {
    super.initState();
    _initFileService();
  }
  
  void _initFileService() {
    _fileService = FileService(
      allowedExtensions: ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'],
    );
  }
  
  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _fileEventSub?.cancel();
    _p2pManager?.dispose();
    _loop?.dispose();
    _player?.dispose();
    _fileService?.dispose();
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
                    onPressed: _canCreateSession() ? _createP2PSession : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('创建会话'),
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
                    onPressed: _canJoinSession() ? _joinP2PSession : null,
                    icon: const Icon(Icons.login),
                    label: const Text('加入会话'),
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
                label: const Text('断开连接'),
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
                    label: const Text('加载媒体'),
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
                    label: Text(_isPlaying ? '暂停' : '播放'),
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
          ],
        ),
      ),
    );
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
                    label: const Text('启动测试'),
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
                    label: const Text('发送测试'),
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
                Text('系统日志', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _logs.clear()),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清空'),
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
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}
