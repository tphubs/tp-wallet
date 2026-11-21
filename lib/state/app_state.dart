import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/bank_parser.dart';
import '../services/categorizer.dart';
import '../services/store.dart';
import '../services/notification_bridge.dart';

class CategoryTotal {
  final Category category;
  final int total;
  CategoryTotal(this.category, this.total);
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this._db);

  final TxStore _db;
  Categorizer _categorizer = Categorizer();
  StreamSubscription<void>? _notifSub;

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Transaction> transactions = [];
  int pendingReview = 0;
  bool notificationAccess = false;

  int get totalIncome => transactions
      .where((t) => t.type == TxType.income)
      .fold(0, (s, t) => s + t.amount);
  int get totalExpense => transactions
      .where((t) => t.type == TxType.expense)
      .fold(0, (s, t) => s + t.amount);
  int get balance => totalIncome - totalExpense;

  List<CategoryTotal> totalsByCategory(TxType type) {
    final map = <String, int>{};
    for (final t in transactions.where((t) => t.type == type)) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    final list =
        map.entries
            .map((e) => CategoryTotal(Categories.byId(e.key), e.value))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Future<void> init() async {
    _categorizer = Categorizer(await _db.rules());
    WidgetsBinding.instance.addObserver(this);
    _notifSub = NotificationBridge.onNew.listen((_) => importNotifications());
    await refreshPermission();
    await importNotifications();
    await reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshPermission();
      importNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> refreshPermission() async {
    final v = await NotificationBridge.isPermissionGranted();
    if (v != notificationAccess) {
      notificationAccess = v;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    transactions = await _db.inRange(from, to);
    pendingReview = (await _db.needingReview()).length;
    notifyListeners();
  }

  void changeMonth(int delta) {
    month = DateTime(month.year, month.month + delta);
    reload();
  }

  Future<List<Transaction>> reviewList() => _db.needingReview();

  String suggestCategory(TxType type, String description, [String full = '']) =>
      _categorizer.categorize(
        type: type,
        description: description,
        fullText: full,
      );

  /// Biến văn bản (thông báo / OCR / dán) thành giao dịch nháp.
  Transaction? draftFromText(
    String text, {
    required TxSource source,
    String? packageName,
    DateTime? fallbackDate,
  }) {
    final p = BankParser.parse(
      text,
      packageName: packageName,
      defaultType: TxType.expense,
    );
    if (p == null) return null;
    return Transaction(
      amount: p.amount,
      type: p.type,
      categoryId: suggestCategory(p.type, p.description, text),
      note: p.description,
      date: p.date ?? fallbackDate ?? DateTime.now(),
      source: source,
      bank: p.bank,
      rawText: text,
      needsReview: true,
    );
  }

  Future<int> importNotifications() async {
    final items = await NotificationBridge.drain();
    var added = 0;
    for (final n in items) {
      if (!BankParser.looksLikeTransaction(n.fullText)) continue;
      final t = draftFromText(
        n.fullText,
        source: TxSource.notification,
        packageName: n.packageName,
        fallbackDate: n.postedAt,
      );
      if (t == null) continue;
      // Dùng giờ nhận thông báo nếu ngày đọc được lệch quá xa (ví dụ đọc nhầm).
      final tx = (t.date.difference(n.postedAt).inDays.abs() > 2)
          ? t.copyWith(date: n.postedAt)
          : t;
      if (await _db.hasNear(tx)) continue;
      await _db.insert(tx);
      added++;
    }
    if (added > 0) await reload();
    return added;
  }

  /// Văn bản gửi vào từ bên ngoài (ví dụ Phím tắt iPhone mở link ?text=...).
  /// Tự thêm như một giao dịch cần xem lại. Trả về giao dịch đã thêm.
  Future<Transaction?> addFromIncomingText(String text) async {
    final t = draftFromText(text, source: TxSource.paste);
    if (t == null) return null;
    if (await _db.hasNear(t)) return null;
    final id = await _db.insert(t);
    await reload();
    return t.copyWith(id: id);
  }

  Future<void> save(Transaction t, {Transaction? original}) async {
    if (t.id == null) {
      await _db.insert(t);
    } else {
      await _db.update(t);
    }
    // Học từ lần sửa: nếu người dùng đổi hạng mục của giao dịch tự thêm.
    if (original != null &&
        original.source != TxSource.manual &&
        original.categoryId != t.categoryId &&
        t.note.isNotEmpty) {
      final key = Categorizer.learnKey(t.note);
      if (key.length >= 3) {
        await _db.saveRule(key, t.categoryId);
        _categorizer.learned[key] = t.categoryId;
      }
    }
    await reload();
  }

  @visibleForTesting
  Future<void> insertForTest(Transaction t) async {
    await _db.insert(t);
    await reload();
  }

  Future<void> confirm(Transaction t) => save(t.copyWith(needsReview: false));

  Future<void> delete(Transaction t) async {
    if (t.id != null) await _db.delete(t.id!);
    await reload();
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    _categorizer = Categorizer();
    await reload();
  }
}
