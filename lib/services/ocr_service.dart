import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_web_stub.dart' if (dart.library.js_interop) 'ocr_web.dart' as web;

/// Đọc chữ từ ảnh chụp màn hình chuyển khoản, chạy ngay trên máy
/// (không gửi ảnh đi đâu).
class OcrService {
  static final _picker = ImagePicker();

  /// Cho người dùng chọn ảnh từ thư viện. Trả về đường dẫn hoặc null.
  static Future<String?> pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    return f?.path;
  }

  static Future<String> readText(String imagePath) async {
    if (kIsWeb) return web.recognizeWeb(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      // Giữ thứ tự từ trên xuống dưới, mỗi dòng một hàng.
      final lines = <TextLine>[
        for (final b in result.blocks) ...b.lines,
      ]..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      return lines.map((l) => l.text).join('\n');
    } finally {
      await recognizer.close();
    }
  }
}
