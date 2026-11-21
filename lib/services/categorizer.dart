import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/text.dart';

/// Tự gán hạng mục dựa vào nội dung giao dịch.
///
/// Thứ tự ưu tiên:
/// 1. Quy tắc người dùng đã "dạy" (khi họ sửa hạng mục của một giao dịch).
/// 2. Từ khóa có sẵn của từng hạng mục, khớp dài nhất thắng.
/// 3. Hạng mục mặc định theo chiều thu/chi.
class Categorizer {
  /// từ khóa (không dấu) -> id hạng mục
  final Map<String, String> learned;

  Categorizer([Map<String, String>? learned]) : learned = learned ?? {};

  static bool _containsWord(String haystack, String kw) {
    if (kw.isEmpty) return false;
    final re = RegExp('(^|[^a-z0-9])${RegExp.escape(kw)}([^a-z0-9]|\$)');
    return re.hasMatch(haystack);
  }

  /// Khóa để ghi nhớ: bỏ số, ký tự đặc biệt, lấy tối đa 4 từ đầu.
  static String learnKey(String description) {
    final n = normalizeVi(description)
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.isEmpty) return '';
    final words = n.split(' ').take(4).toList();
    return words.join(' ');
  }

  /// Văn bản có từ khóa rõ là khoản thu (lương, thưởng, hoàn tiền...)?
  static bool hasIncomeHint(String text) {
    final n = normalizeVi(text);
    if (n.trim().isEmpty) return false;
    for (final c in Categories.ofType(TxType.income)) {
      if (_isTransfer(c.id) || c.id == Categories.otherIncomeId) continue;
      if (c.keywords.any((kw) => _containsWord(n, kw))) return true;
    }
    return false;
  }

  static bool _isTransfer(String id) =>
      id == Categories.transferOutId || id == Categories.transferInId;

  String categorize({
    required TxType type,
    required String description,
    String fullText = '',
  }) {
    final desc = normalizeVi(description);
    final full = normalizeVi(fullText);

    // 1. Quy tắc đã học
    String? bestLearned;
    var bestLen = 0;
    for (final e in learned.entries) {
      final cat = Categories.byId(e.value);
      if (cat.type != type) continue;
      if ((_containsWord(desc, e.key) || _containsWord(full, e.key)) &&
          e.key.length > bestLen) {
        bestLearned = e.value;
        bestLen = e.key.length;
      }
    }
    if (bestLearned != null) return bestLearned;

    // 2. Từ khóa có sẵn: ưu tiên khớp trong mô tả, sau đó toàn văn.
    for (final hay in [desc, full]) {
      if (hay.isEmpty) continue;
      String? best;
      var len = 0;
      for (final c in Categories.ofType(type)) {
        if (_isTransfer(c.id)) continue;
        for (final kw in c.keywords) {
          if (kw.length > len && _containsWord(hay, kw)) {
            best = c.id;
            len = kw.length;
          }
        }
      }
      if (best != null) return best;
    }

    // 3. Chuyển tiền chung chung (chỉ khi không khớp gì cụ thể hơn)
    for (final c in Categories.ofType(type).where((c) => _isTransfer(c.id))) {
      for (final kw in c.keywords) {
        if (_containsWord(desc, kw) || _containsWord(full, kw)) return c.id;
      }
    }

    // 4. Mặc định
    return Categories.fallbackFor(type);
  }
}
