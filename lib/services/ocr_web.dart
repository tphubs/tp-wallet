import 'dart:js_interop';

@JS('tpwOcr')
external JSPromise<JSString> _tpwOcr(JSString url);

@JS('tpwClearQuery')
external void _tpwClearQuery();

/// Đọc chữ bằng Tesseract.js (khai báo trong web/index.html), chạy trong
/// trình duyệt, ảnh không gửi lên máy chủ.
Future<String> recognizeWeb(String url) async =>
    (await _tpwOcr(url.toJS).toDart).toDart;

/// Xóa ?text=... khỏi địa chỉ để tải lại trang không thêm trùng.
void clearUrlQuery() => _tpwClearQuery();
