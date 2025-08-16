import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'core/app_manager.dart';
import 'core/state_service.dart';
import 'core/logger_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化全局错误捕获
  GlobalErrorHandler.initialize();
  
  // 初始化日志系统
  await LoggerService.instance.initialize();
  Log.i('Main', 'CineFlow application starting');
  
  // 初始化MediaKit
  MediaKit.ensureInitialized();
  Log.i('Main', 'MediaKit initialized');
  
  // 初始化应用管理器
  try {
    await AppManager.instance.initialize();
    Log.i('Main', 'AppManager initialized successfully');
    runApp(const CineFlowApp());
  } catch (e, stackTrace) {
    Log.e('Main', 'Failed to initialize AppManager', data: {'error': e.toString()}, stackTrace: stackTrace);
    // 如果初始化失败，显示错误页面
    runApp(CineFlowErrorApp(error: e.toString()));
  }
}

class CineFlowApp extends StatefulWidget {
  const CineFlowApp({super.key});

  @override
  State<CineFlowApp> createState() => _CineFlowAppState();
}

class _CineFlowAppState extends State<CineFlowApp> {
  late final AppManager _appManager;
  AppTheme _currentTheme = AppTheme.light;
  String _currentLanguage = 'zh_CN';

  @override
  void initState() {
    super.initState();
    _appManager = AppManager.instance;
    
    // 监听应用状态变化
    _appManager.stateService.watchState<AppState>().listen((appState) {
      if (mounted) {
        setState(() {
          _currentTheme = appState.currentTheme;
          _currentLanguage = appState.language;
        });
      }
    });
    
    // 监听应用事件
    _appManager.events.listen((event) {
      if (!mounted) return;
      
      switch (event) {
        case InitializationFailed(error: final error):
          _showErrorSnackBar('应用初始化失败: $error');
          break;
        case SignalingError(error: final error):
          _showErrorSnackBar('信令错误: $error');
          break;
        case SessionError(error: final error):
          _showErrorSnackBar('会话错误: $error');
          break;
        default:
          break;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineFlow',
      theme: _buildTheme(_currentTheme),
      locale: _buildLocale(_currentLanguage),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // 固定文字缩放比例
          ),
          child: child!,
        );
      },
    );
  }

  ThemeData _buildTheme(AppTheme themeType) {
    final colorScheme = switch (themeType) {
      AppTheme.light => ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      AppTheme.dark => ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      AppTheme.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: Brightness.dark,
            )
          : ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: Brightness.light,
            ),
    };

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Locale _buildLocale(String languageCode) {
    final parts = languageCode.split('_');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}

/// 错误应用，当初始化失败时显示
class CineFlowErrorApp extends StatelessWidget {
  const CineFlowErrorApp({super.key, required this.error});
  
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineFlow - Error',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'CineFlow 初始化失败',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // 重启应用
                    main();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
