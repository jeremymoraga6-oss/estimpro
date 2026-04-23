import 'package:flutter/material.dart';
import '../theme.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: const Text('Profil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('J', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Jérémy Moraga', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCharcoal)),
                    const SizedBox(height: 4),
                    const Text('Conseiller immobilier', style: TextStyle(fontSize: 13, color: kGrey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Faucigny Immobilier by Efficity',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGreen)),
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
              _Item(Icons.palette_outlined, 'Couleur accent', '#7CB342 (Vert Efficity)'),
              _Item(Icons.notifications_outlined, 'Notifications', 'Activées'),
              _Item(Icons.cloud_sync_outlined, 'Sauvegarde', 'Automatique'),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'Application', items: [
              _Item(Icons.info_outline, 'Version', '1.0.0'),
              _Item(Icons.privacy_tip_outlined, 'Confidentialité', 'Données locales uniquement'),
            ]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Icon(item.icon, size: 18, color: kGreen),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14, color: kCharcoal))),
                        Text(item.value, style: const TextStyle(fontSize: 13, color: kGrey)),
                      ]),
                    ),
                    if (i < items.length - 1) const Divider(height: 1, indent: 44),
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
