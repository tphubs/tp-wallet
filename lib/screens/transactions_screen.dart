import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/ocr_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/tx_tile.dart';
import 'edit_transaction_screen.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          await s.importNotifications();
          await s.reload();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Hero(s: s),
            const SizedBox(height: 16),
            const _QuickActions(),
            if (s.pendingReview > 0) _ReviewBanner(count: s.pendingReview),
            if (days.isEmpty) const _EmptyState(),
            for (final d in days) _DayGroup(day: d, items: groups[d]!),
          ],
        ),
      ),
    );
  }
}

Future<void> openEditor(
  BuildContext context,
  Transaction? t, {
  Transaction? original,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditTransactionScreen(initial: t, original: original),
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
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Đang đọc ảnh...')),
        ],
      ),
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
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Không tìm thấy số tiền trong ảnh. Bạn nhập tay nhé.'),
      ),
    );
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
          hintText:
              'Ví dụ: TK 0123 -45,000VND ... ND: Highlands Coffee\n'
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
          child: const Text('Đọc'),
        ),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final draft = s.draftFromText(text, source: TxSource.paste);
  if (draft == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không tìm thấy số tiền. Bạn nhập tay nhé.'),
      ),
    );
    return;
  }
  openEditor(context, draft);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'TP Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PillButton(
                      icon: Icons.chevron_left,
                      onTap: () => s.changeMonth(-1),
                    ),
                    Text(
                      formatMonth(s.month),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _PillButton(
                      icon: Icons.chevron_right,
                      onTap: () => s.changeMonth(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Còn lại tháng này',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatVnd(s.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Thu',
                  value: s.totalIncome,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Chi',
                  value: s.totalExpense,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 20,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: label == 'Thu' ? AppColors.income : AppColors.expense,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              FittedBox(
                child: Text(
                  formatVnd(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, Color c, VoidCallback onTap) =>
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 6,
                ),
                child: Column(
                  children: [
                    CategoryBadge(icon: icon, color: c, size: 44),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Row(
        children: [
          item(
            Icons.edit_rounded,
            'Nhập tay',
            const Color(0xFF6366F1),
            () => openEditor(context, null),
          ),
          item(
            Icons.document_scanner_rounded,
            'Đọc ảnh CK',
            const Color(0xFFF59E0B),
            () => _fromScreenshot(context),
          ),
          item(
            Icons.content_paste_rounded,
            'Dán tin nhắn',
            const Color(0xFF06B6D4),
            () => _fromPaste(context),
          ),
        ],
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFB45309),
          ),
          title: Text(
            '$count giao dịch cần xem lại',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF78350F),
            ),
          ),
          subtitle: const Text(
            'Kiểm tra số tiền và hạng mục',
            style: TextStyle(color: Color(0xFF92400E)),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF78350F)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReviewScreen()),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
    child: Column(
      children: [
        const CategoryBadge(
          icon: Icons.savings_rounded,
          color: AppColors.brand,
          size: 72,
        ),
        const SizedBox(height: 16),
        Text(
          'Chưa có giao dịch nào',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Chọn ảnh chuyển khoản, dán tin nhắn ngân hàng\nhoặc nhập tay ở trên.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.items});
  final DateTime day;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final sum = items.fold(0, (s, t) => s + t.signedAmount);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDay(day),
                    style: TextStyle(fontWeight: FontWeight.w700, color: muted),
                  ),
                ),
                Text(
                  formatVnd(sum, signed: true),
                  style: TextStyle(fontWeight: FontWeight.w600, color: muted),
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  TxTile(
                    tx: items[i],
                    onTap: () =>
                        openEditor(context, items[i], original: items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
