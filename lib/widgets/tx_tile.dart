import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CategoryBadge(icon: c.icon, color: c.color),
      title: Row(
        children: [
          Flexible(
            child: Text(
              c.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (tx.needsReview) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Color(0xFFF59E0B),
            ),
          ],
        ],
      ),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatVnd(tx.signedAmount, signed: true),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
