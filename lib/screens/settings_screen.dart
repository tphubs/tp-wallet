import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/notification_bridge.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt'), centerTitle: true),
      body: ListView(
        children: [
          const _Section('Tự động ghi giao dịch'),
          if (NotificationBridge.supported)
            ListTile(
              leading: Icon(
                s.notificationAccess
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: s.notificationAccess ? const Color(0xFF0E9F6E) : null,
              ),
              title: const Text('Đọc thông báo ngân hàng'),
              subtitle: Text(
                s.notificationAccess
                    ? 'Đang bật. Giao dịch từ app ngân hàng, ví sẽ tự được thêm.'
                    : 'Chưa bật. Bấm để cấp quyền "Truy cập thông báo" cho TP Wallet.',
              ),
              trailing: s.notificationAccess
                  ? const Icon(Icons.check_circle, color: Color(0xFF0E9F6E))
                  : const Icon(Icons.chevron_right),
              onTap: NotificationBridge.openPermissionSettings,
            )
          else
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Trên iPhone'),
              subtitle: Text(
                'iPhone không cho app khác đọc thông báo ngân hàng. Bạn chụp '
                'màn hình chuyển khoản rồi bấm Thêm > Từ ảnh chụp, hoặc sao chép '
                'tin nhắn / thông báo ngân hàng rồi bấm Thêm > Dán.',
              ),
            ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Quyền riêng tư'),
            subtitle: Text(
              'Nội dung thông báo và ảnh được đọc ngay trên máy '
              '(bản web: trong trình duyệt), '
              'không gửi đi đâu. Chỉ thông báo giống biến động số dư mới được giữ lại.',
            ),
          ),
          const _Section('Dữ liệu'),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Sao lưu đám mây'),
            subtitle: Text(
              'Sắp có: đăng nhập để sao lưu và chuyển máy không mất dữ liệu.',
            ),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Xóa toàn bộ dữ liệu'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Xóa toàn bộ dữ liệu?'),
                  content: const Text(
                    'Mọi giao dịch trên máy này sẽ bị xóa và không khôi phục được.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
              if (ok == true) await s.clearAll();
            },
          ),
          const _Section('Thông tin'),
          const ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('TP Wallet'),
            subtitle: Text('Phiên bản 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
