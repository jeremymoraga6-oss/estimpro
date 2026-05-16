import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'services/crash_reporter.dart';
import 'services/dvf_cache.dart';
import 'services/app_settings.dart';

void main() {
  CrashReporter.install(() async {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Charge les settings (clé API, etc.) avant de lancer l'app
    await AppSettings.instance.load();

    // Migration cache DVF : si version < 2, vide le cache (peut contenir
    // des CSV corrompus depuis l'ancienne version sans validation taille)
    const currentDvfCacheVersion = 2;
    if (AppSettings.instance.dvfCacheVersion < currentDvfCacheVersion) {
      await DvfCache().clearAll();
      await AppSettings.instance.setDvfCacheVersion(currentDvfCacheVersion);
    } else {
      // Cleanup standard (fichiers > 90j supprimés)
      DvfCache().cleanup();
    }
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
