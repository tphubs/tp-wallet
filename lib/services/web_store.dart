import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import 'store.dart';

/// Lưu trong bộ nhớ trình duyệt (bản web / thêm vào màn hình chính iPhone).
class WebStore implements TxStore {
  WebStore._(this._prefs, this._items, this._rules, this._nextId);

  static const _kTx = 'tpw_transactions_v1';
  static const _kRules = 'tpw_rules_v1';

  final SharedPreferences _prefs;
  final List<Transaction> _items;
  final Map<String, String> _rules;
  int _nextId;

  static Future<WebStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <Transaction>[];
    final raw = prefs.getString(_kTx);
    if (raw != null) {
      for (final m in (jsonDecode(raw) as List)) {
        items.add(Transaction.fromMap(Map<String, Object?>.from(m as Map)));
      }
    }
    final rules = <String, String>{};
    final rr = prefs.getString(_kRules);
    if (rr != null) {
      rules.addAll(Map<String, String>.from(jsonDecode(rr) as Map));
    }
    final next = items.fold<int>(0, (m, t) => (t.id ?? 0) > m ? t.id! : m) + 1;
    return WebStore._(prefs, items, rules, next);
  }

  Future<void> _persist() =>
      _prefs.setString(_kTx, jsonEncode([for (final t in _items) t.toMap()]));

  List<Transaction> _sorted(Iterable<Transaction> it) =>
      it.toList()..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
      });

  @override
  Future<int> insert(Transaction t) async {
    final id = _nextId++;
    _items.add(t.copyWith(id: id));
    await _persist();
    return id;
  }

  @override
  Future<void> update(Transaction t) async {
    final i = _items.indexWhere((x) => x.id == t.id);
    if (i >= 0) _items[i] = t;
    await _persist();
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((x) => x.id == id);
    await _persist();
  }

  @override
  Future<List<Transaction>> inRange(DateTime from, DateTime to) async =>
      _sorted(
        _items.where((t) => !t.date.isBefore(from) && t.date.isBefore(to)),
      );

  @override
  Future<List<Transaction>> needingReview() async =>
      _sorted(_items.where((t) => t.needsReview));

  @override
  Future<bool> hasNear(
    Transaction t, {
    Duration window = const Duration(minutes: 3),
  }) async => _items.any(
    (x) =>
        x.amount == t.amount &&
        x.type == t.type &&
        x.source != TxSource.manual &&
        (x.bank ?? '') == (t.bank ?? '') &&
        x.date.difference(t.date).abs() <= window,
  );

  @override
  Future<Map<String, String>> rules() async => Map.of(_rules);

  @override
  Future<void> saveRule(String keyword, String categoryId) async {
    _rules[keyword] = categoryId;
    await _prefs.setString(_kRules, jsonEncode(_rules));
  }

  @override
  Future<List<Transaction>> all() async => _sorted(_items);

  @override
  Future<void> clearAll() async {
    _items.clear();
    _rules.clear();
    await _prefs.remove(_kTx);
    await _prefs.remove(_kRules);
  }
}
