import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Một thông báo ngân hàng mà phần Android gốc đã bắt được.
class CapturedNotification {
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;

  CapturedNotification(this.packageName, this.title, this.text, this.postedAt);

  String get fullText => [title, text].where((s) => s.isNotEmpty).join('\n');
}

/// Cầu nối tới NotificationListenerService (chỉ Android).
///
/// Dịch vụ Android chạy nền, lọc thông báo giống biến động số dư và xếp vào
/// hàng đợi. App lấy hàng đợi ra khi mở hoặc khi có thông báo mới.
class NotificationBridge {
  static const _method = MethodChannel('tp_wallet/notifications');
  static const _events = EventChannel('tp_wallet/notification_events');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isPermissionGranted() async {
    if (!supported) return false;
    try {
      return await _method.invokeMethod<bool>('isPermissionGranted') ?? false;
    } catch (e) {
      debugPrint('isPermissionGranted: $e');
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    if (!supported) return;
    try {
      await _method.invokeMethod('openPermissionSettings');
    } catch (e) {
      debugPrint('openPermissionSettings: $e');
    }
  }

  /// Lấy và xóa các thông báo đang chờ.
  static Future<List<CapturedNotification>> drain() async {
    if (!supported) return [];
    try {
      final list = await _method.invokeListMethod<Map>('drainQueue') ?? [];
      return list.map(_fromMap).toList();
    } catch (e) {
      debugPrint('drainQueue: $e');
      return [];
    }
  }

  /// Phát tín hiệu mỗi khi có thông báo ngân hàng mới lúc app đang mở.
  static Stream<void> get onNew {
    if (!supported) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map<void>((_) {})
        .handleError((Object e) => debugPrint('notification_events: $e'));
  }

  static CapturedNotification _fromMap(Map m) => CapturedNotification(
    (m['package'] as String?) ?? '',
    (m['title'] as String?) ?? '',
    (m['text'] as String?) ?? '',
    DateTime.fromMillisecondsSinceEpoch(
      (m['postedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );
}
