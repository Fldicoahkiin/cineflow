import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

/// Callers can lookup localized strings with Localizations.of<AppLocalizations>(context).
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// localizationDelegates list, and the locales they support in the app's
/// supportedLocales list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml file to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you'll need to edit this
/// file.
///
/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project's Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the supportedLocales parameter
/// of your application's MaterialApp.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  // App Title
  String get appTitle;
  String get appDescription;

  // Navigation
  String get homeTitle;
  String get joinSessionTitle;
  String get createSessionTitle;
  String get settingsTitle;

  // P2P Connection
  String get p2pConnection;
  String get signalingServer;
  String get signalingServerUrl;
  String get signalingServerHint;
  String get sessionId;
  String get sessionIdHint;
  String get createSession;
  String get joinSession;
  String get disconnect;
  String get connectionStatus;
  String get notConnected;
  String get connecting;
  String get connected;
  String get sessionCreated;
  String get sessionJoined;

  // Media Player
  String get mediaPlayer;
  String get mediaPath;
  String get selectFile;
  String get selectMediaFile;
  String get loadMedia;
  String get play;
  String get pause;
  String get stop;
  String get seek;
  String get rate;
  String get volume;
  String get position;
  String get duration;
  String get playerStatus;
  String get notLoaded;
  String get loaded;
  String get playing;
  String get paused;
  String get noMediaSelected;
  String get mediaLoadFailed;
  String get playbackControlFailed;

  // Loopback Test
  String get loopbackTest;
  String get startTest;
  String get sendTest;
  String get stopTest;
  String get rttDisplay;
  String get testStatus;
  String get testReady;
  String get testRunning;
  String get testStopped;
  String get loopbackTestStarted;
  String get loopbackTestStopped;
  String get loopbackTestPassed;
  String get loopbackTestFailed;
  String get loopbackTestStartFailed;
  String get loopbackTestStopFailed;

  // Sync Playback
  String get syncPlayback;
  String get syncEnabled;
  String get syncDisabled;
  String get hostRole;
  String get participantRole;
  String get networkDelay;
  String get syncPlay;
  String get syncPause;
  String get syncSeek;
  String get syncRate;
  String get syncCommandSent;
  String get syncCommandReceived;
  String get syncCommandExecuted;
  String get syncCommandFailed;
  String get syncSessionStarted;
  String get syncSessionStopped;
  String get syncSessionJoined;
  String get syncSessionLeft;
  String get syncStateConnected;
  String get syncStateDisconnected;
  String get syncStateSyncing;
  String get syncStateError;

  // System Log
  String get systemLog;
  String get systemLogs;
  String get clearLogs;
  String get exportLogs;
  String get noLogs;
  String get noLogsAvailable;
  String get autoScroll;
  String get all;
  String get totalLogs;
  String get logs;
  String get filterLevel;
  String get copyPath;
  String get timestamp;
  String get level;
  String get tag;
  String get message;
  String get data;
  String get stackTrace;

  // Log Levels
  String get logLevelDebug;
  String get logLevelInfo;
  String get logLevelWarning;
  String get logLevelError;
  String get logLevelFatal;

  // Messages
  String get pleaseEnterSignalingServer;
  String get pleaseSelectMediaFile;
  String get pleaseLoadMediaFirst;
  String get sessionCreatedSuccess;
  String get disconnectedSuccess;
  String get sessionJoinedSuccess;
  String get mediaLoadedSuccess;
  String get exportedTo;
  String get exportFailed;
  String get clearLogsTitle;
  String get clearLogsConfirm;
  String get copiedToClipboard;
  String get welcome;
  String get createJoinSession;

  // Error Messages
  String get error_syncCommandFailed;
  String get error_syncHeartbeatFailed;
  String get error_syncNetworkLatencyHigh;
  String get error_disconnectFailed;
  String get sessionCreateFailed;
  String get error_createSessionFailed;
  String get error_joinSessionFailed;
  String get error_loopbackFailed;
  String get mediaLoading;

  // Additional Sync Properties
  String get playbackProgress;
  String get syncState;
  String get syncRole;
  String get syncHost;
  String get syncParticipant;
  String get syncLatency;
  String get syncPeerStates;
  String get syncConnected;
  String get syncSyncing;
  String get syncError;
  String get syncDisconnected;
  String get syncIdle;

  // Common
  String get ok;
  String get cancel;
  String get confirm;
  String get retry;
  String get close;
  String get copy;
  String get delete;
  String get save;
  String get edit;
  String get settings;
  String get help;
  String get about;
  String get load;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue on GitHub with a '
    'reproducible example app and the exact error message you are seeing.'
  );
}
