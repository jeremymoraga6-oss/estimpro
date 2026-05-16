import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../services/crash_reporter.dart';
import '../services/app_settings.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {

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
              _Item(Icons.phone_outlined, 'Téléphone', '06 68 03 64 03'),
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
            // Avis Google + Page Efficity
            _ActionCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFBBC05),
              iconBg: const Color(0xFFFFF8E1),
              title: 'Laisser un avis Google',
              subtitle: 'Aidez-moi à développer mon activité',
              trailing: 'Ouvrir',
              trailingColor: const Color(0xFF4285F4),
              onTap: () => launchUrl(
                Uri.parse('https://share.google/fQtR1My2s6T0rH9GB'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.share_rounded,
              iconColor: kGreen,
              iconBg: Color(0xFFE8F5E9),
              title: 'Partager ma page Efficity',
              subtitle: 'www.efficity.com/jmoraga',
              trailing: 'Partager',
              trailingColor: kGreen,
              onTap: () => Share.share(
                'Découvrez mon profil de conseiller immobilier :\nhttps://www.efficity.com/jmoraga/\n\nJérémy Moraga — Faucigny Immobilier by Efficity',
                subject: 'Mon profil Efficity',
              ),
            ),
            const SizedBox(height: 12),
            // Configuration clé API Anthropic (pour features IA)
            _ApiKeyCard(onChanged: () => setState(() {})),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.iconColor, required this.iconBg, required this.title, required this.subtitle, required this.trailing, required this.trailingColor, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: kCardDecoration(),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: kGrey)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: trailingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(trailing, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: trailingColor)),
          ),
        ]),
      ),
    ),
  );
}


class _ApiKeyCard extends StatefulWidget {
  final VoidCallback onChanged;
  const _ApiKeyCard({required this.onChanged});
  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  Future<void> _edit() async {
    final ctrl = TextEditingController(text: AppSettings.instance.anthropicKey);
    bool obscure = true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Clé API Anthropic'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Active la transcription vocale structurée et la génération d\'annonces par IA.\n\nObtiens ta clé sur console.anthropic.com → API Keys.',
              style: TextStyle(fontSize: 12, color: kGrey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                hintStyle: const TextStyle(fontSize: 12, color: kLightGrey),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stockée localement uniquement (jamais envoyée ailleurs).',
              style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic),
            ),
          ]),
          actions: [
            if (AppSettings.instance.hasAnthropicKey)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Supprimer', style: TextStyle(color: Color(0xFFC0392B))),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Annuler', style: TextStyle(color: kGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await AppSettings.instance.setAnthropicKey(result);
      if (mounted) {
        setState(() {});
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = AppSettings.instance.hasAnthropicKey;
    return Container(
      decoration: kCardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _edit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (hasKey ? kGreen : kAmber).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 18, color: hasKey ? kGreen : kAmber),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clé API Anthropic',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal)),
                SizedBox(height: 2),
                Text('Active la transcription IA et la génération d\'annonces',
                    style: TextStyle(fontSize: 11, color: kGrey)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (hasKey ? kGreen : kAmber).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(hasKey ? 'Configurée' : 'À configurer',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hasKey ? kGreen : kAmber)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: kLightGrey, size: 22),
          ]),
        ),
      ),
    );
  }
}
