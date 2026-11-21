import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Tự thêm dấu chấm phân cách hàng nghìn khi gõ: 1500000 -> 1.500.000
class ThousandsFormatter extends TextInputFormatter {
  static final _f = NumberFormat.decimalPattern('vi_VN');

  static int? parse(String s) =>
      int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));

  static String format(int v) => _f.format(v);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final v = int.parse(digits.length > 15 ? digits.substring(0, 15) : digits);
    final text = _f.format(v);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
