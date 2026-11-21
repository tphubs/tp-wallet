import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';

import 'package:flutter/foundation.dart';

import 'services/database.dart';
import 'services/store.dart';
import 'services/web_store.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  final TxStore db = kIsWeb ? await WebStore.open() : await AppDatabase.open();
  final state = AppState(db);
  await state.init();
  runApp(TpWalletApp(state: state));
}

class TpWalletApp extends StatelessWidget {
  const TpWalletApp({super.key, required this.state});

  final AppState state;

  static const seed = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'TP Wallet',
        debugShowCheckedModeBanner: false,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}
