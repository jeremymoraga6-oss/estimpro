import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'services/crash_reporter.dart';
import 'services/dvf_cache.dart';

void main() {
  CrashReporter.install(() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Cleanup cache DVF en arrière-plan (fichiers > 90j supprimés)
    DvfCache().cleanup();
    runApp(const EstimProApp());
  });
}

class EstimProApp extends StatelessWidget {
  const EstimProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstimPro',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
