import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'session/join_session_page.dart';

/// 首页占位页面（最小可运行）。
/// 后续将接入：
/// - 创建/加入会话入口
/// - 扫码加入
/// - 最近媒体/选择本地文件
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CineFlow')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)?.welcome ?? 'Welcome to CineFlow'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinSessionPage()),
                );
              },
              child: Text(AppLocalizations.of(context)?.createJoinSession ?? 'Create/Join Session'),
            ),
          ],
        ),
      ),
    );
  }
}
