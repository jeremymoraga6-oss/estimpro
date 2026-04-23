import 'package:flutter/material.dart';
import '../theme.dart';

class MarcheScreen extends StatelessWidget {
  const MarcheScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: const Text('Marché DVF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          backgroundColor: kCharcoal,
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SynthCard(
              title: 'Faucigny – Médiane DVF',
              subtitle: 'Données notaires 2025-2026',
              stats: const [
                {'label': 'Maisons', 'value': '3 381 €/m²'},
                {'label': 'Appartements', 'value': '2 840 €/m²'},
                {'label': 'Délai moyen', 'value': '47 jours'},
                {'label': 'Volume 12 mois', 'value': '148 ventes'},
              ],
            ),
            const SizedBox(height: 12),
            _SynthCard(
              title: 'Ayse & communes proches',
              subtitle: 'Dernières ventes disponibles',
              stats: const [
                {'label': 'Fourchette', 'value': '3 280–3 437 €/m²'},
                {'label': 'Maisons vendues', 'value': '23 ventes'},
                {'label': 'Surface médiane', 'value': '112 m²'},
                {'label': 'Prix médian', 'value': '385 000 €'},
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: kCardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: kGreen, size: 18),
                  const SizedBox(width: 8),
                  const Text('Source des données', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal)),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'Les données DVF (Demandes de Valeurs Foncières) sont issues des actes notariés publiés par la Direction Générale des Finances Publiques. Elles représentent les transactions réelles enregistrées.',
                  style: TextStyle(fontSize: 12, color: kGrey, height: 1.6),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('SOURCE OFFICIELLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
                ),
              ]),
            ),
          ],
        ),
      );
}

class _SynthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, String>> stats;
  const _SynthCard({required this.title, required this.subtitle, required this.stats});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: kCardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: kGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: kGrey)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          ...stats.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < stats.length - 1 ? 10 : 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(s['label']!, style: const TextStyle(fontSize: 12, color: kGrey)),
                Text(s['value']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              ]),
            );
          }),
        ]),
      );
}
