import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../services/crash_reporter.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  Future<void> _viewCrashLog(BuildContext context) async {
    final log = await CrashReporter.readLog();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Journal de débogage',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: kCharcoal)),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: kGrey),
              ),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: SingleChildScrollView(
                  controller: scroll,
                  child: SelectableText(
                    log.isEmpty ? 'Aucune erreur enregistrée. ✓' : log,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Color(0xFF333333),
                        height: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: log.isEmpty
                      ? null
                      : () async {
                          await CrashReporter.clear();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Effacer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: log.isEmpty ? null : () => _shareCrashLog(log),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Envoyer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _shareCrashLog(String log) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/estimpro_debug_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(log);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Rapport de débogage EstimPro',
          subject: 'EstimPro — rapport de bug');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: const Text('Profil',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          backgroundColor: kCharcoal,
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Agent card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: kCardDecoration(),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: kGreen, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('J',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jérémy Moraga',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: kCharcoal)),
                        const SizedBox(height: 4),
                        const Text('Conseiller immobilier',
                            style: TextStyle(fontSize: 13, color: kGrey)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: kGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Faucigny Immobilier by Efficity',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kGreen)),
                        ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _Section(title: 'Coordonnées', items: [
              _Item(Icons.phone_outlined, 'Téléphone', '06 12 34 56 78'),
              _Item(Icons.email_outlined, 'Email', 'jeremy.moraga@efficity.com'),
              _Item(Icons.location_on_outlined, 'Zone', 'Faucigny, Haute-Savoie'),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'Paramètres', items: [
              _Item(Icons.palette_outlined, 'Couleur accent',
                  '#7CB342 (Vert Efficity)'),
              _Item(Icons.notifications_outlined, 'Notifications', 'Activées'),
              _Item(Icons.cloud_sync_outlined, 'Sauvegarde', 'Automatique'),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'Application', items: [
              _Item(Icons.info_outline, 'Version', '1.0.0'),
              _Item(Icons.privacy_tip_outlined, 'Confidentialité',
                  'Données locales uniquement'),
            ]),
            const SizedBox(height: 12),
            // Bouton journal de débogage
            Container(
              decoration: kCardDecoration(),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _viewCrashLog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bug_report_outlined,
                          size: 18, color: kAmber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Journal de débogage',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kCharcoal)),
                            SizedBox(height: 2),
                            Text('Voir / envoyer les erreurs récentes',
                                style:
                                    TextStyle(fontSize: 11, color: kGrey)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right,
                        color: kLightGrey, size: 22),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(), style: kSectionLabel),
          ),
          Container(
            decoration: kCardDecoration(),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Icon(item.icon, size: 18, color: kGreen),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(item.label,
                                style: const TextStyle(
                                    fontSize: 14, color: kCharcoal))),
                        Text(item.value,
                            style:
                                const TextStyle(fontSize: 13, color: kGrey)),
                      ]),
                    ),
                    if (i < items.length - 1)
                      const Divider(height: 1, indent: 44),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
}

class _Item {
  final IconData icon;
  final String label;
  final String value;
  const _Item(this.icon, this.label, this.value);
}
