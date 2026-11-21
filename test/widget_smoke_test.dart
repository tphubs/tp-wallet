import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tp_wallet/main.dart';
import 'package:tp_wallet/models/transaction.dart';
import 'package:tp_wallet/services/database.dart';
import 'package:tp_wallet/state/app_state.dart';

void main() {
  sqfliteFfiInit();
  // Không có phần Android gốc khi chạy kiểm thử.

  testWidgets('các màn hình chính hiển thị được', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    late AppState s;
    await tester.runAsync(() async {
      await initializeDateFormatting('vi');
      final db = await AppDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      s = AppState(db);
      await s.init();
      await s.clearAll();
      final d = s.draftFromText(
        '-45.000đ ND: Highlands Coffee',
        source: TxSource.paste,
      )!;
      await s.save(d);
    });
    await tester.pumpWidget(TpWalletApp(state: s));
    await tester.pumpAndSettle();

    expect(find.text('TP Wallet'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('1 giao dịch cần xem lại'), findsOneWidget);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng chi'), findsOneWidget);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa toàn bộ dữ liệu'), findsOneWidget);

    await tester.tap(find.text('Sổ thu chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập tay'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);

    // Gõ "Lương" vào ghi chú -> tự chuyển sang khoản thu.
    await tester.enterText(find.widgetWithText(TextField, 'Ghi chú / nội dung'), 'Lương tháng 11');
    await tester.pumpAndSettle();
    expect(find.text('Lương'), findsOneWidget);
    expect(find.text('Ăn uống'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
