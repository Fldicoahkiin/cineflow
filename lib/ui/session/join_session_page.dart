import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../network/signaling_client.dart';
import '../../session/loopback_service.dart';
import '../../network/messages.dart' as proto;
import '../../player/player_controller.dart';
import '../../core/file_service.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 创建/加入会话页面
/// - 输入信令服务器 URL
/// - 输入会话 ID
/// - WebSocket 连接管理
class JoinSessionPage extends StatefulWidget {
  const JoinSessionPage({super.key});

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage> {
  final _urlCtrl = TextEditingController(text: 'wss://example.com/signaling');
  final _roomCtrl = TextEditingController();
  SignalingClient? _client;
  StreamSubscription? _autoClose;
  bool _connecting = false;
  bool _connected = false;

  // Loopback
  LoopbackService? _loop;
  bool _loopReady = false;
  final List<String> _logs = [];
  int? _rttA;
  int? _rttB;
  bool _isPlaying = false;
  double _positionMs = 0;
  proto.StateUpdatePayload? _lastStateA;
  proto.StateUpdatePayload? _lastStateB;

  // Player
  PlayerController? _player;
  final _mediaCtrl = TextEditingController(text: '');
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _playerErrorSub;
  StreamSubscription? _playerLoadingSub;
  int _mediaPos = 0;
  int _mediaDur = 0;
  bool _playerLoading = false;
  String? _playerError;

  // File Service
  FileService? _fileService;
  StreamSubscription? _fileEventSub;
  MediaFileInfo? _selectedFile;
  bool _fileSelecting = false;
  bool _playerPlaying = false;
  VideoController? _video;
  Timer? _rateResetTimer;
  double _currentRate = 1.0;

  void _bindClient(SignalingClient c) {
    c.onConnected = () {
      setState(() {
        _connecting = false;
        _connected = true;
      });
      _showSnackBar('已连接');
    };
    c.onDisconnected = () {
      setState(() {
        _connected = false;
      });
      _showSnackBar('已断开');
    };
    c.onError = (error, stackTrace) {
      setState(() {
        _connecting = false;
      });
      _showSnackBar('连接错误: $error', isError: true);
    };
    c.onReconnecting = (attempt, maxAttempts) {
      _showSnackBar('重连中 ($attempt/$maxAttempts)');
    };
    c.onMessage = (data) {
      // 使用新的消息解析器
      final parsed = proto.MessageParser.parse(data);
      if (parsed != null && parsed.isValid) {
        debugPrint('WS <- [${parsed.type}] ${parsed.messageId}');
      } else {
        debugPrint('WS <- Invalid message: ${jsonEncode(data)}');
      }
    };
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showSnackBar('请输入信令服务器 URL', isError: true);
      return;
    }
    setState(() {
      _connecting = true;
    });
    final c = SignalingClient(url);
    _bindClient(c);
    try {
      await c.connect();
      setState(() {
        _client = c;
      });
    } catch (_) {}
  }

  Future<void> _disconnect() async {
    await _client?.disconnect();
  }

  Future<void> _setupLoopback() async {
    final loop = LoopbackService();
    setState(() {
      _loop = loop;
      _loopReady = false;
      _logs.clear();
    });
    
    // 设置事件监听器
    loop.onLog = (l) {
      if (mounted) {
        setState(() {
          _logs.add(l);
          // 保持日志数量在合理范围内
          if (_logs.length > 100) {
            _logs.removeAt(0);
          }
        });
      }
    };
    
    loop.onError = (error) {
      _showSnackBar('环回服务错误: ${error.message}', isError: true);
    };
    
    try {
      await loop.setup();
      if (mounted) {
        setState(() {
          _loopReady = true;
        });
        _showSnackBar('本地环回就绪');
      }
    } catch (e) {
      _showSnackBar('环回服务初始化失败: $e', isError: true);
      return;
    }

    loop.onRtt = (receiver, rtt) {
      if (mounted) {
        setState(() {
          if (receiver == 'A') {
            _rttA = rtt;
          } else {
            _rttB = rtt;
          }
        });
      }
    };
    
    loop.onStateUpdate = (receiver, payload) {
      if (mounted) {
        setState(() {
          if (receiver == 'A') {
            _lastStateA = payload;
          } else {
            _lastStateB = payload;
          }
          // 同步到页面上的演示控件
          _isPlaying = payload.isPlaying;
          _positionMs = payload.positionMs.toDouble();
        });
        // 驱动播放器（被动跟随）
        _applyStateToPlayer(payload);
      }
    };
  }

  Future<void> _sendA() async {
    final loop = _loop;
    if (loop == null || !_loopReady) return;
    await loop.sendTestFromA();
  }

  Future<void> _sendB() async {
    final loop = _loop;
    if (loop == null || !_loopReady) return;
    await loop.sendTestFromB();
  }

  Future<void> _sendStateA() async {
    final loop = _loop;
    if (loop == null || !_loopReady) return;
    await loop.sendStateUpdateFromA(isPlaying: _isPlaying, positionMs: _positionMs.toInt());
  }

  Future<void> _sendStateB() async {
    final loop = _loop;
    if (loop == null || !_loopReady) return;
    await loop.sendStateUpdateFromB(isPlaying: _isPlaying, positionMs: _positionMs.toInt());
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    
    final p = PlayerController();
    
    // 监听播放器状态变化
    _playSub = p.playingStream.listen((v) {
      if (mounted) {
        setState(() => _playerPlaying = v);
      }
    });
    
    _posSub = p.positionMsStream.listen((v) {
      if (mounted) {
        setState(() => _mediaPos = v);
      }
    });
    
    _durSub = p.durationMsStream.listen((v) {
      if (mounted) {
        setState(() => _mediaDur = v);
      }
    });
    
    // 监听播放器错误
    p.errorStream.listen((error) {
      _showSnackBar('播放器错误: ${error.message}', isError: true);
    });
    
    // 监听加载状态
    p.loadingStream.listen((loading) {
      if (mounted) {
        setState(() {
          // 可以在这里显示加载指示器
        });
      }
    });
    
    setState(() => _player = p);
    
    // 绑定视频渲染控制器
    try {
      _video = VideoController(p.rawPlayer);
    } catch (e) {
      _showSnackBar('视频控制器初始化失败: $e', isError: true);
    }
  }

  Future<void> _loadMedia() async {
    await _ensurePlayer();
    final uri = _mediaCtrl.text.trim();
    if (uri.isEmpty) {
      _showSnackBar('请输入媒体地址', isError: true);
      return;
    }
    
    try {
      await _player!.load(uri);
      _showSnackBar('媒体加载成功');
    } catch (e) {
      _showSnackBar('媒体加载失败: $e', isError: true);
    }
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await _fileService!.pickSingleFile(
        dialogTitle: '选择媒体文件',
        type: FileType.custom,
      );
      if (result != null) {
        setState(() => _mediaCtrl.text = result.path);
        await _loadMedia();
      }
    } catch (e) {
      _showSnackBar('选择文件失败: $e', isError: true);
    }
  }

  Future<void> _togglePlayPause() async {
    final p = _player;
    if (p == null) return;
    if (p.isPlaying) {
      await p.pause();
    } else {
      await p.play();
    }
    // 主动广播（以 A 为示例）
    final loop = _loop;
    if (loop != null && _loopReady) {
      await loop.sendStateUpdateFromA(isPlaying: p.isPlaying, positionMs: p.positionMs);
    }
  }

  Future<void> _seekPlayer(double v) async {
    final p = _player;
    if (p == null) return;
    final target = v.toInt();
    await p.seekMs(target);
    final loop = _loop;
    if (loop != null && _loopReady) {
      await loop.sendStateUpdateFromA(isPlaying: p.isPlaying, positionMs: target);
    }
  }

  void _applyStateToPlayer(proto.StateUpdatePayload payload) async {
    final p = _player;
    if (p == null) return;
    // 估算到达时刻的应有位置：对端 positionMs + RTT/2
    final oneWay = _oneWayDelayMs();
    final expectedPos = payload.positionMs + oneWay;
    final nowPos = p.positionMs;
    final drift = nowPos - expectedPos; // 正数表示本地超前

    // 阈值与变速参数（演示用）
    const seekThresholdMs = 600; // 漂移过大直接跳
    const smallDriftMs = 150; // 小漂移采用变速
    const rateFast = 1.05; // 轻微加速
    const rateSlow = 0.95; // 轻微减速
    const rateHoldMs = 2000; // 变速维持时长

    if (drift.abs() > seekThresholdMs) {
      setState(() {
        _logs.add('[sync] drift=${drift}ms > ${seekThresholdMs}ms, seek -> $expectedPos, rate=1.0');
      });
      await p.seekMs(expectedPos);
      await _setRateSafely(1.0);
    } else if (drift.abs() > smallDriftMs) {
      // 使用轻微变速拉回
      final targetRate = drift > 0 ? rateSlow : rateFast;
      setState(() {
        _logs.add('[sync] drift=${drift}ms ~ 调整速率 -> $targetRate');
      });
      await _setRateSafely(targetRate);
      _rateResetTimer?.cancel();
      _rateResetTimer = Timer(const Duration(milliseconds: rateHoldMs), () {
        setState(() {
          _logs.add('[sync] 速率恢复 1.0');
        });
        _setRateSafely(1.0);
      });
    } else {
      // 漂移很小，回到常速
      await _setRateSafely(1.0);
    }

    // 同步播放/暂停状态
    if (payload.isPlaying && !p.isPlaying) {
      await p.play();
    } else if (!payload.isPlaying && p.isPlaying) {
      await p.pause();
    }
  }

  int _oneWayDelayMs() {
    // 取可用 RTT 的一半（演示）：优先较小的 RTT
    final candidates = <int>[];
    if (_rttA != null) candidates.add(_rttA!);
    if (_rttB != null) candidates.add(_rttB!);
    if (candidates.isEmpty) return 0;
    candidates.sort();
    return (candidates.first / 2).round();
  }

  Future<void> _setRateSafely(double rate) async {
    if ((_currentRate - rate).abs() < 0.001) return;
    final p = _player;
    if (p == null) return;
    await p.setRate(rate);
    _currentRate = rate;
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

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _initServices() {
    _initPlayer();
    _initFileService();
  }

  void _initPlayer() {
    _player = PlayerController();
    
    // 监听播放状态
    _playSub = _player!.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
    
    // 监听播放位置
    _posSub = _player!.positionMsStream.listen((pos) {
      if (mounted) {
        setState(() {
          _mediaPos = pos;
          _positionMs = pos.toDouble();
        });
      }
    });
    
    // 监听媒体时长
    _durSub = _player!.durationMsStream.listen((dur) {
      if (mounted) {
        setState(() {
          _mediaDur = dur;
        });
      }
    });
    
    // 监听加载状态
    _playerLoadingSub = _player!.loadingStream.listen((loading) {
      if (mounted) {
        setState(() {
          _playerLoading = loading;
        });
      }
    });
    
    // 监听错误
    _playerErrorSub = _player!.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _playerError = error?.toString();
        });
        if (error != null) {
          _showSnackBar('播放器错误: $error', isError: true);
        }
      }
    });
  }

  void _initFileService() {
    _fileService = FileService(
      allowedExtensions: ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'],
    );
    
    _fileEventSub = _fileService!.events.listen((event) {
      if (!mounted) return;
      
      switch (event) {
        case FileSelected(file: final file):
          setState(() {
            _selectedFile = file;
            _mediaCtrl.text = file.path;
            _fileSelecting = false;
          });
          _showSnackBar('文件已选择: ${file.name}', isError: false);
          break;
        case FileSelectionCancelled():
          setState(() {
            _fileSelecting = false;
          });
          break;
        case FileServiceError(error: final error):
          setState(() {
            _fileSelecting = false;
          });
          _showSnackBar('文件选择错误: ${error.message}', isError: true);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _pickFile() async {
    if (_fileService == null) {
      _showSnackBar('文件服务未初始化', isError: true);
      return;
    }
    
    setState(() {
      _fileSelecting = true;
    });
    
    try {
      await _fileService!.pickSingleFile(
        dialogTitle: '选择媒体文件',
        type: FileType.custom,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileSelecting = false;
        });
        _showSnackBar('选择文件失败: $e', isError: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  @override
  void dispose() {
    _client?.disconnect();
    _autoClose?.cancel();
    _loop?.dispose();
    _player?.dispose();
    _fileService?.dispose();
    
    // 取消所有订阅
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _playerErrorSub?.cancel();
    _playerLoadingSub?.cancel();
    _fileEventSub?.cancel();
    
    // 释放控制器
    _urlCtrl.dispose();
    _roomCtrl.dispose();
    _mediaCtrl.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建/加入会话')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: '信令服务器 URL',
                hintText: '例如 wss://example.com/signaling',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: '会话 ID（加入时必填，创建可留空）',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _connecting || _connected ? null : _connect,
                    child: Text(_connecting ? '连接中…' : '连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _connected ? _disconnect : null,
                    child: const Text('断开'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    _connected ? Icons.wifi : (_connecting ? Icons.wifi_off : Icons.signal_wifi_off),
                    color: _connected ? Colors.green : (_connecting ? Colors.orange : Colors.red),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connected ? '状态：已连接' : (_connecting ? '状态：连接中' : '状态：未连接'),
                    style: TextStyle(
                      color: _connected ? Colors.green : (_connecting ? Colors.orange : Colors.red),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),
            const Text('本地环回测试（无服务端）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _setupLoopback,
                    child: const Text('建立本地环回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loopReady ? _sendA : null,
                    child: const Text('A -> 发送 ping'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loopReady ? _sendB : null,
                    child: const Text('B -> 发送 pong'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(_logs[i]),
              ),
            ),

            const Divider(height: 32),
            const Text('RTT / 状态同步', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('RTT(A): ${_rttA?.toString() ?? '-'} ms')),
                Expanded(child: Text('RTT(B): ${_rttB?.toString() ?? '-'} ms')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('播放中'),
                const SizedBox(width: 8),
                Switch(
                  value: _isPlaying,
                  onChanged: (v) => setState(() => _isPlaying = v),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('位置: ${_positionMs.toInt()} ms'),
                      Slider(
                        value: _positionMs,
                        min: 0,
                        max: 300000,
                        divisions: 300,
                        label: '${_positionMs.toInt()}ms',
                        onChanged: (v) => setState(() => _positionMs = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loopReady ? _sendStateA : null,
                    child: const Text('A -> state_update'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loopReady ? _sendStateB : null,
                    child: const Text('B -> state_update'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('A 收到的最新状态: ${_lastStateA == null ? '-' : 'isPlaying=${_lastStateA!.isPlaying}, pos=${_lastStateA!.positionMs}ms, ts=${_lastStateA!.timestampUtcMs}'}'),
            Text('B 收到的最新状态: ${_lastStateB == null ? '-' : 'isPlaying=${_lastStateB!.isPlaying}, pos=${_lastStateB!.positionMs}ms, ts=${_lastStateB!.timestampUtcMs}'}'),

            const Divider(height: 32),
            const Text('播放器联动（环回演示）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mediaCtrl,
                    decoration: const InputDecoration(
                      labelText: '媒体地址（本地路径或网络 URL）',
                      hintText: '/path/to/file.mp4 或 https://.../video.mp4',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _fileSelecting ? null : _pickFile,
                  child: _fileSelecting 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('选择文件'),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_formatFileSize(_selectedFile!.size)} • ${_selectedFile!.extension.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loadMedia,
                  child: const Text('加载'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _player == null ? null : _togglePlayPause,
                  child: Text(_playerPlaying ? '暂停' : '播放'),
                ),
                const SizedBox(width: 12),
                Text('进度: ${_mediaPos ~/ 1000}s / ${_mediaDur == 0 ? '-' : _mediaDur ~/ 1000}s'),
              ],
            ),
            if (_mediaDur > 0)
              Slider(
                value: _mediaPos.toDouble().clamp(0, _mediaDur.toDouble()),
                min: 0,
                max: _mediaDur.toDouble(),
                onChanged: (v) => _seekPlayer(v),
              ),
            const SizedBox(height: 12),
            if (_video != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Video(controller: _video!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
