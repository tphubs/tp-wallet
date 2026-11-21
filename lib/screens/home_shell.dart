import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/ocr_web_stub.dart'
    if (dart.library.js_interop) '../services/ocr_web.dart'
    as web;
import '../state/app_state.dart';
import '../utils/format.dart';

import 'report_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _incoming());
    }
  }

  /// Bản web: Phím tắt iPhone mở link có `?text=` kèm tin nhắn ngân hàng.
  Future<void> _incoming() async {
    final text = Uri.base.queryParameters['text'];
    if (text == null || text.trim().isEmpty) return;
    web.clearUrlQuery();
    final t = await context.read<AppState>().addFromIncomingText(text);
    if (!mounted) return;
    final msg = t == null
        ? 'Không đọc được giao dịch từ tin nhắn (hoặc đã thêm rồi)'
        : 'Đã thêm ${formatVnd(t.signedAmount, signed: true)} · ${Categories.byId(t.categoryId).name}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TransactionsScreen(),
          ReportScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sổ thu chi',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Báo cáo',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
