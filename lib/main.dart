import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/analysis_provider.dart';
import 'providers/history_provider.dart';
import 'screens/home_screen.dart';
import 'services/history_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final historyService = HistoryService();
  await historyService.init();

  runApp(ScandAidApp(historyService: historyService));
}

class ScandAidApp extends StatelessWidget {
  final HistoryService historyService;

  const ScandAidApp({super.key, required this.historyService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AnalysisProvider(historyService: historyService),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(historyService: historyService),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ScandAid',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
