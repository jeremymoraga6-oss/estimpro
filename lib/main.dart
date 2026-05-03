import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'services/crash_reporter.dart';

void main() {
  CrashReporter.install(() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
