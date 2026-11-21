import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/ocr_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/tx_tile.dart';
import 'edit_transaction_screen.dart';
import 'month_header.dart';
import 'review_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final groups = <DateTime, List<Transaction>>{};
    for (final t in s.transactions) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(d, () => []).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('TP Wallet'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await s.importNotifications();
          await s.reload();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const MonthHeader(),
            _SummaryCard(s: s),
            if (s.pendingReview > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text('${s.pendingReview} giao dịch tự thêm cần xem lại'),
                    subtitle: const Text('Kiểm tra số tiền và hạng mục'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ReviewScreen())),
                  ),
                ),
              ),
            if (days.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Column(children: [
                  Icon(Icons.savings_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('Chưa có giao dịch nào trong tháng này.\n'
                      'Bấm "Thêm" để nhập tay, chọn ảnh chuyển khoản\n'
                      'hoặc dán tin nhắn ngân hàng.',
                      textAlign: TextAlign.center),
                ]),
              ),
            for (final d in days) ...[
              _DayHeader(day: d, items: groups[d]!),
              for (final t in groups[d]!)
                TxTile(
                  tx: t,
                  onTap: () => openEditor(context, t, original: t),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> openEditor(BuildContext context, Transaction? t,
    {Transaction? original}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditTransactionScreen(initial: t, original: original),
    ),
  );
}

void _showAddSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Nhập tay'),
          onTap: () {
            Navigator.pop(sheet);
            openEditor(context, null);
          },
        ),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Từ ảnh chụp chuyển khoản'),
          subtitle: const Text('App tự đọc số tiền, nội dung'),
          onTap: () {
            Navigator.pop(sheet);
            _fromScreenshot(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.content_paste),
          title: const Text('Dán tin nhắn / thông báo ngân hàng'),
          onTap: () {
            Navigator.pop(sheet);
            _fromPaste(context);
          },
        ),
      ]),
    ),
  );
}

Future<void> _fromScreenshot(BuildContext context) async {
  final s = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final path = await OcrService.pickImage();
  if (path == null || !context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Đang đọc ảnh...')),
      ]),
    ),
  );
  String text = '';
  try {
    text = await OcrService.readText(path);
  } catch (e) {
    debugPrint('OCR lỗi: $e');
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  final draft = s.draftFromText(text, source: TxSource.screenshot);
  if (draft == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Không tìm thấy số tiền trong ảnh. Bạn nhập tay nhé.')));
    openEditor(context, null);
    return;
  }
  openEditor(context, draft);
}

Future<void> _fromPaste(BuildContext context) async {
  final s = context.read<AppState>();
  final ctrl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Dán nội dung'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Ví dụ: TK 0123 -45,000VND ... ND: Highlands Coffee\n'
              'hoặc gõ nhanh: 35k cafe',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final c = await Clipboard.getData(Clipboard.kTextPlain);
            if (c?.text != null) ctrl.text = c!.text!;
          },
          icon: const Icon(Icons.content_paste),
          label: const Text('Dán'),
        ),
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Hủy')),
        FilledButton(
            onPressed: () => Navigator.pop(d, ctrl.text),
            child: const Text('Đọc')),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final draft = s.draftFromText(text, source: TxSource.paste);
  if (draft == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy số tiền. Bạn nhập tay nhé.')));
    return;
  }
  openEditor(context, draft);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget col(String label, int v, Color c) => Expanded(
          child: Column(children: [
            Text(label, style: t.labelMedium),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(formatVnd(v),
                  style: t.titleMedium?.copyWith(color: c, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(children: [
          col('Thu', s.totalIncome, const Color(0xFF0E9F6E)),
          col('Chi', s.totalExpense, const Color(0xFFE53935)),
          col('Còn lại', s.balance, Theme.of(context).colorScheme.onSurface),
        ]),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});
  final DateTime day;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final sum = items.fold(0, (s, t) => s + t.signedAmount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Expanded(
            child: Text(formatDay(day),
                style: Theme.of(context).textTheme.labelLarge)),
        Text(formatVnd(sum, signed: true),
            style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}
