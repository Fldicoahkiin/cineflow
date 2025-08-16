import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cineflow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CineFlow Integration Tests', () {
    testWidgets('App launches and shows home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 验证应用启动成功
      expect(find.text('CineFlow'), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Navigate to join session page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 查找并点击加入会话按钮
      final joinButton = find.text('加入会话').first;
      expect(joinButton, findsOneWidget);
      
      await tester.tap(joinButton);
      await tester.pumpAndSettle();

      // 验证导航到加入会话页面
      expect(find.text('P2P 连接'), findsOneWidget);
      expect(find.text('媒体播放器'), findsOneWidget);
      expect(find.text('本地环回测试'), findsOneWidget);
      expect(find.text('系统日志'), findsOneWidget);
    });

    testWidgets('Test signaling server input validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 清空信令服务器地址
      final serverField = find.byType(TextField).first;
      await tester.tap(serverField);
      await tester.pump();
      await tester.enterText(serverField, '');
      await tester.pump();

      // 尝试创建会话
      await tester.tap(find.text('创建会话'));
      await tester.pumpAndSettle();

      // 验证错误提示
      expect(find.text('请输入信令服务器地址'), findsOneWidget);
    });

    testWidgets('Test file picker integration', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 查找文件选择按钮
      final filePickerButton = find.byIcon(Icons.folder_open);
      expect(filePickerButton, findsOneWidget);

      // 点击文件选择按钮（注意：在测试环境中文件选择器可能不会实际打开）
      await tester.tap(filePickerButton);
      await tester.pump();
    });

    testWidgets('Test log system integration', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 验证日志区域存在
      expect(find.text('系统日志'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);

      // 点击清空按钮
      await tester.tap(find.text('清空'));
      await tester.pump();
    });

    testWidgets('Test loopback service controls', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 验证环回测试控件
      expect(find.text('本地环回测试'), findsOneWidget);
      expect(find.text('开始测试'), findsOneWidget);

      // 点击开始测试按钮
      await tester.tap(find.text('开始测试'));
      await tester.pumpAndSettle();

      // 验证状态变化（可能会显示停止按钮或状态信息）
      // 注意：实际的环回测试可能需要网络连接，在测试环境中可能会失败
    });

    testWidgets('Test media player controls', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 验证媒体播放器控件
      expect(find.text('媒体播放器'), findsOneWidget);
      expect(find.text('加载媒体'), findsOneWidget);

      // 验证播放控制按钮存在但可能被禁用
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Test P2P connection controls', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 验证P2P连接控件
      expect(find.text('P2P 连接'), findsOneWidget);
      expect(find.text('创建会话'), findsOneWidget);
      expect(find.text('加入会话'), findsOneWidget);

      // 验证默认服务器地址
      expect(find.text('ws://localhost:8080'), findsOneWidget);
    });

    testWidgets('Test UI responsiveness and Material Design', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 验证Material Design组件
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsWidgets);

      // 测试滚动性能
      await tester.fling(find.byType(SingleChildScrollView).first, const Offset(0, -500), 1000);
      await tester.pumpAndSettle();

      // 验证界面仍然响应
      expect(find.text('P2P 连接'), findsOneWidget);
    });

    testWidgets('Test theme and color scheme', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 获取主题信息
      final BuildContext context = tester.element(find.byType(MaterialApp));
      final ThemeData theme = Theme.of(context);

      // 验证Material 3主题
      expect(theme.useMaterial3, true);
      expect(theme.colorScheme, isNotNull);

      // 验证颜色方案
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.colorScheme.secondary, isNotNull);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Test error states and recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到加入会话页面
      await tester.tap(find.text('加入会话').first);
      await tester.pumpAndSettle();

      // 测试无效输入处理
      final serverField = find.byType(TextField).first;
      await tester.enterText(serverField, 'invalid-url');
      await tester.pump();

      await tester.tap(find.text('创建会话'));
      await tester.pumpAndSettle();

      // 应该显示错误信息或保持在当前页面
      expect(find.byType(SnackBar), findsAny);
    });
  });

  group('Performance Tests', () {
    testWidgets('Test app startup performance', (WidgetTester tester) async {
      final Stopwatch stopwatch = Stopwatch()..start();
      
      app.main();
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // 验证启动时间合理（应该在几秒内）
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      
      // 验证应用正常启动
      expect(find.text('CineFlow'), findsOneWidget);
    });

    testWidgets('Test memory usage during navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 多次导航测试内存泄漏
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('加入会话').first);
        await tester.pumpAndSettle();
        
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // 验证应用仍然响应
      expect(find.text('CineFlow'), findsOneWidget);
    });
  });
}
