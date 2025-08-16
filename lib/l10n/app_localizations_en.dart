import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CineFlow';

  @override
  String get appDescription => 'CineFlow - Multi-device Synchronized Playback App';

  // Navigation
  @override
  String get homeTitle => 'Home';

  @override
  String get joinSessionTitle => 'Join Session';

  @override
  String get createSessionTitle => 'Create Session';

  @override
  String get settingsTitle => 'Settings';

  // P2P Connection
  @override
  String get p2pConnection => 'P2P Connection';

  @override
  String get signalingServer => 'Signaling Server';

  @override
  String get signalingServerHint => 'Enter signaling server address';

  @override
  String get sessionIdHint => 'Enter session ID';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get connected => 'Connected';

  @override
  String get sessionCreated => 'Session Created';

  @override
  String get sessionJoined => 'Session Joined';

  // Media Player
  @override
  String get mediaPlayer => 'Media Player';

  @override
  String get selectFile => 'Select File';

  @override
  String get loadMedia => 'Load Media';

  @override
  String get playerStatus => 'Player Status';

  @override
  String get notLoaded => 'Not Loaded';

  @override
  String get loaded => 'Loaded';

  @override
  String get playing => 'Playing';

  @override
  String get paused => 'Paused';

  // Loopback Test
  @override
  String get rttDisplay => 'RTT: {rtt}ms';

  @override
  String get testStatus => 'Test Status';

  @override
  String get testReady => 'Test Ready';

  @override
  String get testRunning => 'Test Running';

  @override
  String get testStopped => 'Test Stopped';

  @override
  String get stopTest => 'Stop Test';

  // System Log
  @override
  String get systemLog => 'System Log';

  @override
  String get noLogs => 'No Logs';

  // Messages
  @override
  String get pleaseEnterSignalingServer => 'Please enter signaling server address';

  @override
  String get pleaseSelectMediaFile => 'Please select media file';

  @override
  String get pleaseLoadMediaFirst => 'Please load media file first';

  @override
  String get sessionCreatedSuccess => 'Session created successfully';

  @override
  String get disconnectedSuccess => 'Disconnected successfully';

  @override
  String get sessionJoinedSuccess => 'Joined session successfully';

  @override
  String get mediaLoadedSuccess => 'Media loaded successfully';

  // Error Messages
  @override
  String get error_syncCommandFailed => 'Sync command failed';

  @override
  String get error_syncHeartbeatFailed => 'Sync heartbeat failed';

  @override
  String get error_syncNetworkLatencyHigh => 'Network latency too high';

  @override
  String get error_disconnectFailed => 'Disconnect failed';

  @override
  String get sessionCreateFailed => 'Session creation failed';

  @override
  String get load => 'Load';

  @override
  String get welcome => 'Welcome to CineFlow';

  @override
  String get createJoinSession => 'Create/Join Session';

  // Session Management
  @override
  String get signalingServerUrl => 'Signaling Server URL';

  @override
  String get sessionId => 'Session ID';

  @override
  String get mediaPath => 'Media Path';

  @override
  String get createSession => 'Create Session';

  @override
  String get joinSession => 'Join Session';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get startTest => 'Start Test';

  @override
  String get sendTest => 'Send Test';

  @override
  String get systemLogs => 'System Logs';

  @override
  String get exportLogs => 'Export Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get autoScroll => 'Auto Scroll';

  // Sync Playback
  @override
  String get syncPlayback => 'Sync Playback';

  @override
  String get syncEnabled => 'Sync Enabled';

  @override
  String get syncDisabled => 'Sync Disabled';

  @override
  String get hostRole => 'Host';

  @override
  String get participantRole => 'Participant';

  @override
  String get networkDelay => 'Network Delay';

  @override
  String get syncPlay => 'Sync Play';

  @override
  String get syncPause => 'Sync Pause';

  @override
  String get syncSeek => 'Sync Seek';

  @override
  String get syncRate => 'Sync Rate';

  @override
  String get syncCommandSent => 'Sync command sent';

  @override
  String get syncCommandReceived => 'Sync command received';

  @override
  String get syncCommandExecuted => 'Sync command executed';

  @override
  String get syncCommandFailed => 'Sync command failed';

  @override
  String get syncSessionStarted => 'Sync session started';

  @override
  String get syncSessionStopped => 'Sync session stopped';

  @override
  String get syncSessionJoined => 'Joined sync session';

  @override
  String get syncSessionLeft => 'Left sync session';

  @override
  String get syncStateConnected => 'Connected';

  @override
  String get syncStateDisconnected => 'Disconnected';

  @override
  String get syncStateSyncing => 'Syncing';

  @override
  String get syncStateError => 'Sync Error';

  // Player Control
  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get seek => 'Seek';

  @override
  String get rate => 'Rate';

  @override
  String get volume => 'Volume';

  @override
  String get position => 'Position';

  @override
  String get duration => 'Duration';

  @override
  String get selectMediaFile => 'Select Media File';

  @override
  String get noMediaSelected => 'No Media Selected';

  @override
  String get mediaLoadFailed => 'Media load failed';

  @override
  String get playbackControlFailed => 'Playback control failed';

  // Loopback Test
  @override
  String get loopbackTest => 'Loopback Test';

  @override
  String get loopbackTestStarted => 'Loopback test started';

  @override
  String get loopbackTestStopped => 'Loopback test stopped';

  @override
  String get loopbackTestPassed => 'Loopback test passed';

  @override
  String get loopbackTestFailed => 'Loopback test failed';

  @override
  String get loopbackTestStartFailed => 'Failed to start loopback test';

  @override
  String get loopbackTestStopFailed => 'Failed to stop loopback test';

  // Log Levels
  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelWarning => 'Warning';

  @override
  String get logLevelError => 'Error';

  @override
  String get logLevelFatal => 'Fatal';

  @override
  String get noLogsAvailable => 'No logs available';

  @override
  String get all => 'All';

  @override
  String get totalLogs => 'Total';

  @override
  String get logs => 'logs';

  @override
  String get filterLevel => 'Filter Level';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get level => 'Level';

  @override
  String get tag => 'Tag';

  @override
  String get message => 'Message';

  @override
  String get data => 'Data';

  @override
  String get stackTrace => 'Stack Trace';

  @override
  String get exportedTo => 'Logs exported to';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get clearLogsTitle => 'Clear Logs';

  @override
  String get clearLogsConfirm => 'Are you sure you want to clear all logs? This action cannot be undone.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  // Common
  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get about => 'About';

  @override
  String get error_createSessionFailed => 'Failed to create session';

  @override
  String get error_joinSessionFailed => 'Failed to join session';

  @override
  String get playbackProgress => 'Playback Progress';

  @override
  String get syncState => 'Sync State';

  @override
  String get syncRole => 'Sync Role';

  @override
  String get syncHost => 'Host';

  @override
  String get syncParticipant => 'Participant';

  @override
  String get syncLatency => 'Sync Latency';

  @override
  String get syncPeerStates => 'Peer States';

  @override
  String get syncConnected => 'Connected';

  @override
  String get syncSyncing => 'Syncing';

  @override
  String get syncError => 'Error';

  @override
  String get syncDisconnected => 'Disconnected';

  @override
  String get syncIdle => 'Idle';

  @override
  String get error_loopbackFailed => 'Loopback test failed';

  @override
  String get mediaLoading => 'Loading media...';
}
