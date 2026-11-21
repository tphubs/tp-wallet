import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';

class MonthHeader extends StatelessWidget {
  const MonthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: () => s.changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          formatMonth(s.month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: () => s.changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
