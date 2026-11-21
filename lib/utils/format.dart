import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('vi_VN');

/// 1234567 -> "1.234.567 ₫"
String formatVnd(int amount, {bool signed = false}) {
  final s = _money.format(amount.abs());
  final sign = signed ? (amount >= 0 ? '+' : '-') : (amount < 0 ? '-' : '');
  return '$sign$s ₫';
}

/// Rút gọn cho biểu đồ: 1.2tr, 450k
String formatShort(int amount) {
  final a = amount.abs();
  if (a >= 1000000000) return '${(a / 1e9).toStringAsFixed(1)} tỷ';
  if (a >= 1000000) return '${(a / 1e6).toStringAsFixed(1)}tr';
  if (a >= 1000) return '${(a / 1e3).round()}k';
  return '$a';
}

String formatDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(d);
}

String formatMonth(DateTime d) => 'Tháng ${d.month}/${d.year}';
