const _from =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

final Map<String, String> _map = {
  for (var i = 0; i < _from.length; i++) _from[i]: _to[i],
};

/// Bỏ dấu tiếng Việt, chuyển chữ thường. Giữ nguyên độ dài chuỗi
/// (trừ các ký tự tổ hợp dấu rời được loại bỏ).
String normalizeVi(String input) {
  final lower = input.toLowerCase().replaceAll(RegExp('[̀-ͯ]'), '');
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    sb.write(_map[ch] ?? ch);
  }
  return sb.toString();
}
