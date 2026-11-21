import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/format.dart';

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onTap, this.trailing});

  final Transaction tx;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Categories.byId(tx.categoryId);
    final isIncome = tx.type == TxType.income;
    final sub = [
      if (tx.note.isNotEmpty) tx.note,
      if (tx.bank != null) tx.bank!,
      DateFormat('HH:mm').format(tx.date),
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: c.color.withValues(alpha: 0.15),
        child: Icon(c.icon, color: c.color),
      ),
      title: Row(
        children: [
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          if (tx.needsReview) ...[
            const SizedBox(width: 6),
            Icon(Icons.auto_awesome,
                size: 16, color: Theme.of(context).colorScheme.tertiary),
          ],
        ],
      ),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          formatVnd(tx.signedAmount, signed: true),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isIncome ? const Color(0xFF0E9F6E) : const Color(0xFFE53935),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}
