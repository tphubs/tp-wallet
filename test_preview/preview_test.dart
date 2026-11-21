// Tạo ảnh xem trước giao diện: flutter test test_preview --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tp_wallet/main.dart';
import 'package:tp_wallet/models/transaction.dart';
import 'package:tp_wallet/screens/edit_transaction_screen.dart';
import 'package:tp_wallet/services/database.dart';
import 'package:tp_wallet/state/app_state.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  sqfliteFfiInit();
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

  testWidgets('preview', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    late AppState s;
    late Transaction draft;
    await tester.runAsync(() async {
      await _font('Roboto', ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf', '$fonts/Roboto-Bold.ttf']);
      await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
      await initializeDateFormatting('vi');
      final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      s = AppState(db);
      await s.init();
      await s.clearAll();
      final now = DateTime.now();
      String d(int daysAgo, String hm) {
        final x = now.subtract(Duration(days: daysAgo));
        return '${x.day}/${x.month}/${x.year} $hm';
      }
      final samples = [
        'TK 0123|GD: +15,000,000VND ${d(3, '09:00')} |SD: 18,000,000VND|ND: CTY ABC TRA LUONG',
        'TK 0123|GD: -1,250,000VND ${d(2, '20:10')} |SD: 16,750,000VND|ND: SHOPEE thanh toan don hang',
        'TK 0123|GD: -320,000VND ${d(1, '19:30')} |SD: 16,430,000VND|ND: Lau Nam Hai San di choi cung ban',
        'TK 0123|GD: -78,000VND ${d(1, '08:15')} |SD: 16,352,000VND|ND: GRAB*Di lam',
        'TK 0123|GD: +200,000VND ${d(0, '12:05')} |SD: 16,552,000VND|ND: TRAN THI B chuyen tien an trua',
        'TK 0123|GD: -55,000VND ${d(0, '08:40')} |SD: 16,497,000VND|ND: HIGHLANDS COFFEE',
      ];
      for (var i = 0; i < samples.length; i++) {
        final t = s.draftFromText(samples[i], source: TxSource.notification)!;
        await s.save(i < 4 ? t.copyWith(needsReview: false) : t);
      }
      draft = s.draftFromText(
          'Chuyển tiền thành công\n500.000 VND\n${d(0, '10:23')}\nTên người nhận\nLE VAN C\nNội dung\nTra tien ve xem phim CGV',
          source: TxSource.screenshot)!;
    });

    final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: TpWalletApp.seed), fontFamily: 'Roboto');
    await tester.pumpWidget(TpWalletApp(state: s));
    // Ghi đè font cho ảnh xem trước.
    await tester.pumpWidget(Theme(data: theme, child: TpWalletApp(state: s)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/1_so_thu_chi.png'));

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/2_bao_cao.png'));

    await tester.tap(find.text('Sổ thu chi'));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => EditTransactionScreen(initial: draft)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/3_tu_anh_chuyen_khoan.png'));

    nav.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/4_cai_dat.png'));
  });
}
