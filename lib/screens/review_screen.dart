import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../widgets/tx_tile.dart';
import 'transactions_screen.dart';

/// Danh sách giao dịch app tự thêm, chờ người dùng xác nhận.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Transaction> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<AppState>().reviewList();
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cần xem lại'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                for (final t in _items) {
                  await s.confirm(t);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Đúng hết'),
            ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('Không còn giao dịch nào cần xem lại'))
          : ListView(
              children: [
                for (final t in _items)
                  TxTile(
                    tx: t,
                    onTap: () async {
                      await openEditor(context, t, original: t);
                      _load();
                    },
                    trailing: IconButton(
                      tooltip: 'Đúng rồi',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () async {
                        await s.confirm(t);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
