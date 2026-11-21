import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'month_header.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final totals = s.totalsByCategory(_type);
    final sum = totals.fold(0, (a, b) => a + b.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const MonthHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Chi tiêu')),
                ButtonSegment(value: TxType.income, label: Text('Thu nhập')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
          ),
          const SizedBox(height: 16),
          if (totals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: Text('Chưa có dữ liệu tháng này')),
            )
          else ...[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 62,
                          sections: [
                            for (final t in totals)
                              PieChartSectionData(
                                value: t.total.toDouble(),
                                color: t.category.color,
                                radius: 34,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _type == TxType.expense ? 'Tổng chi' : 'Tổng thu',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            formatShort(sum),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final t in totals)
              ListTile(
                leading: CategoryBadge(
                  icon: t.category.icon,
                  color: t.category.color,
                ),
                title: Text(
                  t.category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: sum == 0 ? 0 : t.total / sum,
                    color: t.category.color,
                    backgroundColor: t.category.color.withValues(alpha: 0.12),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatVnd(t.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${(t.total * 100 / sum).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
