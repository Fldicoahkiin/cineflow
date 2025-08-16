import 'app_localizations.dart';

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CineFlow';

  @override
  String get appDescription => 'CineFlow - 多端同步播放应用';

  // Navigation
  @override
  String get homeTitle => '首页';

  @override
  String get joinSessionTitle => '加入会话';

  @override
  String get createSessionTitle => '创建会话';

  @override
  String get settingsTitle => '设置';

  // P2P Connection
  @override
  String get p2pConnection => 'P2P连接';

  @override
  String get signalingServer => '信令服务器';

  @override
  String get signalingServerHint => '请输入信令服务器地址';

  @override
  String get sessionIdHint => '请输入会话ID';

  @override
  String get connectionStatus => '连接状态';

  @override
  String get notConnected => '未连接';

  @override
  String get connecting => '连接中';

  @override
  String get connected => '已连接';

  // Log Export
  @override
  String get logExport => '日志导出';

  @override
  String get logStatistics => '日志统计';

  @override
  String get filteredLogs => '过滤后的日志';

  @override
  String get filters => '过滤器';

  @override
  String get logLevel => '日志级别';

  @override
  String get all => '全部';

  @override
  String get tag => '标签';

  @override
  String get sinceDate => '起始日期';

  @override
  String get noFilter => '无过滤';

  @override
  String get exportFormat => '导出格式';

  @override
  String get exportLogs => '导出日志';

  @override
  String get exporting => '导出中...';

  @override
  String get copyToClipboard => '复制到剪贴板';

  @override
  String get logPreview => '日志预览';

  @override
  String get noLogsFound => '未找到日志';

  @override
  String get refresh => '刷新';

  @override
  String get clearLogs => '清空日志';

  @override
  String get sessionCreated => '会话已创建';

  @override
  String get sessionJoined => '已加入会话';

  // Media Player
  @override
  String get mediaPlayer => '媒体播放器';

  @override
  String get selectFile => '选择文件';

  @override
  String get loadMedia => '加载媒体';

  @override
  String get playerStatus => '播放器状态';

  @override
  String get notLoaded => '未加载';

  @override
  String get loaded => '已加载';

  @override
  String get playing => '播放中';

  @override
  String get paused => '已暂停';

  // Loopback Test
  @override
  String get rttDisplay => 'RTT: {rtt}ms';

  @override
  String get testStatus => '测试状态';

  @override
  String get testReady => '测试就绪';

  @override
  String get testRunning => '测试运行中';

  @override
  String get testStopped => '测试已停止';

  @override
  String get stopTest => '停止测试';

  // System Log
  @override
  String get systemLog => '系统日志';

  @override
  String get noLogs => '暂无日志';

  // Messages
  @override
  String get pleaseEnterSignalingServer => '请输入信令服务器地址';

  @override
  String get pleaseSelectMediaFile => '请选择媒体文件';

  @override
  String get pleaseLoadMediaFirst => '请先加载媒体文件';

  @override
  String get sessionCreatedSuccess => '会话创建成功';

  @override
  String get disconnectedSuccess => '断开连接成功';

  @override
  String get sessionJoinedSuccess => '加入会话成功';

  @override
  String get mediaLoadedSuccess => '媒体加载成功';

  // Error Messages
  @override
  String get error_syncCommandFailed => '同步命令失败';

  @override
  String get error_syncHeartbeatFailed => '同步心跳失败';

  @override
  String get error_syncNetworkLatencyHigh => '网络延迟过高';

  @override
  String get error_disconnectFailed => '断开连接失败';

  @override
  String get sessionCreateFailed => '会话创建失败';

  @override
  String get load => '加载';

  @override
  String get welcome => '欢迎使用 CineFlow';

  @override
  String get createJoinSession => '创建/加入会话';

  // Session Management
  @override
  String get signalingServerUrl => '信令服务器URL';

  @override
  String get sessionId => '会话ID';

  @override
  String get mediaPath => '媒体路径';

  @override
  String get createSession => '创建会话';

  @override
  String get joinSession => '加入会话';

  @override
  String get disconnect => '断开连接';

  @override
  String get startTest => '启动测试';

  @override
  String get sendTest => '发送测试';

  @override
  String get systemLogs => '系统日志';

  @override
  String get exportLogs => '导出日志';

  @override
  String get clearLogs => '清空日志';

  @override
  String get autoScroll => '自动滚动';

  // Sync Playback
  @override
  String get syncPlayback => '同步播放';

  @override
  String get syncEnabled => '同步已启用';

  @override
  String get syncDisabled => '同步已禁用';

  @override
  String get hostRole => '主持人';

  @override
  String get participantRole => '参与者';

  @override
  String get networkDelay => '网络延迟';

  @override
  String get syncPlay => '同步播放';

  @override
  String get syncPause => '同步暂停';

  @override
  String get syncSeek => '同步跳转';

  @override
  String get syncRate => '同步速率';

  @override
  String get syncCommandSent => '同步命令已发送';

  @override
  String get syncCommandReceived => '收到同步命令';

  @override
  String get syncCommandExecuted => '同步命令已执行';

  @override
  String get syncCommandFailed => '同步命令失败';

  @override
  String get syncSessionStarted => '同步会话已开始';

  @override
  String get syncSessionStopped => '同步会话已停止';

  @override
  String get syncSessionJoined => '已加入同步会话';

  @override
  String get syncSessionLeft => '已离开同步会话';

  @override
  String get syncStateConnected => '已连接';

  @override
  String get syncStateDisconnected => '已断开';

  @override
  String get syncStateSyncing => '同步中';

  @override
  String get syncStateError => '同步错误';

  // Player Control
  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get stop => '停止';

  @override
  String get seek => '跳转';

  @override
  String get rate => '速率';

  @override
  String get volume => '音量';

  @override
  String get position => '位置';

  @override
  String get duration => '时长';

  @override
  String get selectMediaFile => '选择媒体文件';

  @override
  String get noMediaSelected => '未选择媒体';

  @override
  String get mediaLoadFailed => '媒体加载失败';

  @override
  String get playbackControlFailed => '播放控制失败';

  // Loopback Test
  @override
  String get loopbackTest => '环回测试';

  @override
  String get loopbackTestStarted => '环回测试已开始';

  @override
  String get loopbackTestStopped => '环回测试已停止';

  @override
  String get loopbackTestPassed => '环回测试通过';

  @override
  String get loopbackTestFailed => '环回测试失败';

  @override
  String get loopbackTestStartFailed => '环回测试启动失败';

  @override
  String get loopbackTestStopFailed => '环回测试停止失败';

  // Log Levels
  @override
  String get logLevelDebug => '调试';

  @override
  String get logLevelInfo => '信息';

  @override
  String get logLevelWarning => '警告';

  @override
  String get logLevelError => '错误';

  @override
  String get logLevelFatal => '致命';

  @override
  String get noLogsAvailable => '暂无日志';

  @override
  String get all => '全部';

  @override
  String get totalLogs => '共';

  @override
  String get logs => '条日志';

  @override
  String get filterLevel => '筛选级别';

  @override
  String get copyPath => '复制路径';

  @override
  String get timestamp => '时间戳';

  @override
  String get level => '级别';

  @override
  String get tag => '标签';

  @override
  String get message => '消息';

  @override
  String get data => '数据';

  @override
  String get stackTrace => '堆栈跟踪';

  @override
  String get exportedTo => '日志已导出到';

  @override
  String get exportFailed => '导出失败';

  @override
  String get clearLogsTitle => '清空日志';

  @override
  String get clearLogsConfirm => '确定要清空所有日志吗？此操作不可撤销。';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  // Common
  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get retry => '重试';

  @override
  String get close => '关闭';

  @override
  String get copy => '复制';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get edit => '编辑';

  @override
  String get settings => '设置';

  @override
  String get help => '帮助';

  @override
  String get about => '关于';

  @override
  String get error_createSessionFailed => '创建会话失败';

  @override
  String get error_joinSessionFailed => '加入会话失败';

  @override
  String get playbackProgress => '播放进度';

  @override
  String get syncState => '同步状态';

  @override
  String get syncRole => '同步角色';

  @override
  String get syncHost => '主机';

  @override
  String get syncParticipant => '参与者';

  @override
  String get syncLatency => '同步延迟';

  @override
  String get syncPeerStates => '对等状态';

  @override
  String get syncConnected => '已连接';

  @override
  String get syncSyncing => '同步中';

  @override
  String get syncError => '错误';

  @override
  String get syncDisconnected => '已断开';

  @override
  String get syncIdle => '空闲';

  @override
  String get error_loopbackFailed => '环回测试失败';

  @override
  String get mediaLoading => '正在加载媒体...';
}
