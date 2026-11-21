import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tp_wallet/models/transaction.dart';
import 'package:tp_wallet/services/database.dart';
import 'package:tp_wallet/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // Không có phần Android gốc khi chạy kiểm thử.
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  late AppState s;

  setUp(() async {
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    s = AppState(db);
    await s.init();
    await s.clearAll();
  });

  test('dán tin nhắn -> nháp -> lưu -> tổng tháng', () async {
    final now = DateTime.now();
    final d = '${now.day}/${now.month}/${now.year}';
    final draft = s.draftFromText(
      'TK 0123|GD: -45,000VND $d 08:00 |SD: 955,000VND|ND: HIGHLANDS COFFEE',
      source: TxSource.paste,
    )!;
    expect(draft.categoryId, 'cafe');
    expect(draft.needsReview, isTrue);
    await s.save(draft);
    await s.confirm(s.transactions.first);
    expect(s.transactions, hasLength(1));
    expect(s.totalExpense, 45000);
    expect(s.transactions.first.needsReview, isFalse);
  });

  test('học hạng mục khi người dùng sửa', () async {
    final draft = s.draftFromText(
      '-200.000 VND ND: NGUYEN THI LAN chuyen tien',
      source: TxSource.paste,
    )!;
    expect(draft.categoryId, 'chuyen_tien');
    await s.insertForTest(draft);
    final saved = s.transactions.first;
    await s.save(saved.copyWith(categoryId: 'nha_cua'), original: saved);
    final next = s.draftFromText(
      '-300.000 VND ND: NGUYEN THI LAN chuyen tien thang 12',
      source: TxSource.paste,
    )!;
    expect(next.categoryId, 'nha_cua');
  });
}
