import '../models/transaction.dart';

/// Nơi lưu giao dịch. Có 2 bản: SQLite (app Android/iPhone) và bộ nhớ
/// trình duyệt (bản web).
abstract class TxStore {
  Future<int> insert(Transaction t);
  Future<void> update(Transaction t);
  Future<void> delete(int id);
  Future<List<Transaction>> inRange(DateTime from, DateTime to);
  Future<List<Transaction>> needingReview();

  /// Đã có giao dịch tự thêm giống hệt (cùng số tiền, chiều, ngân hàng)
  /// trong khoảng ±[window] chưa? Thông báo ngân hàng hay bị gửi lặp lại.
  Future<bool> hasNear(Transaction t, {Duration window = const Duration(minutes: 3)});
  Future<Map<String, String>> rules();
  Future<void> saveRule(String keyword, String categoryId);
  Future<List<Transaction>> all();
  Future<void> clearAll();
}
