import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';

class Section5Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const Section5Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev});

  @override
  State<Section5Screen> createState() => _Section5ScreenState();
}

class _Section5ScreenState extends State<Section5Screen> {
  late Estimation _e;

  static const _defaultComps = [
    {'addr': '14 Chemin des Granges', 'desc': 'Maison · 112 m² · Bonneville', 'date': 'Mars 2026', 'prix': 385000.0, 'prixM2': 3437.0},
    {'addr': '7 Route du Môle', 'desc': 'Maison · 125 m² · Ayse', 'date': 'Janvier 2026', 'prix': 410000.0, 'prixM2': 3280.0},
    {'addr': 'Les Granges Dessus', 'desc': 'Maison · 108 m² · Saint-Pierre-en-Faucigny', 'date': 'Février 2026', 'prix': 370000.0, 'prixM2': 3426.0},
  ];

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    if (_e.comparables.isEmpty) {
      _e = _e.copyWith(comparables: List<Map<String, dynamic>>.from(_defaultComps));
      widget.onChanged(_e);
    }
  }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  double get _median {
    final prices = _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).where((p) => p > 0).toList()..sort();
    if (prices.isEmpty) return 0;
    return prices[prices.length ~/ 2];
  }

  double get _min => _e.comparables.isEmpty ? 0 : _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b);
  double get _max => _e.comparables.isEmpty ? 0 : _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'Analyse du marché', reference: _e.reference, step: 5, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // DVF card
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Icon(Icons.bar_chart_rounded, color: kGreen, size: 18),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ventes DVF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                    const Text('Données officielles notaires', style: TextStyle(fontSize: 11, color: kGrey)),
                  ]),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('SOURCE OFFICIELLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
                ),
              ]),
              const SizedBox(height: 14),

              // Comparables
              ..._e.comparables.asMap().entries.map((entry) => _CompCard(
                comp: entry.value,
                onDelete: () {
                  final list = List<Map<String, dynamic>>.from(_e.comparables)..removeAt(entry.key);
                  _update(_e.copyWith(comparables: list));
                },
              )),

              // Add comparable
              GestureDetector(
                onTap: () => _addComparable(context),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGreen.withOpacity(0.4), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 2, style: BorderStyle.solid)),
                      child: const Icon(Icons.add, size: 16, color: kGreen),
                    ),
                    const SizedBox(height: 6),
                    const Text('Ajouter un comparable DVF', style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600)),
                    const Text('Rechercher dans DVF', style: TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
                  ]),
                ),
              ),
            ])),

            // Synthèse
            if (_e.comparables.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGreen.withOpacity(0.25), width: 1.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.check_circle_outline, color: kGreen, size: 18),
                    const SizedBox(width: 8),
                    Text('Synthèse DVF', style: kCardTitle.copyWith(color: kGreen)),
                  ]),
                  const SizedBox(height: 14),
                  _SynthRow('Prix médian DVF :', '${_median.round()} €/m²', green: true),
                  _SynthRow('Fourchette constatée :', '${_min.round()} — ${_max.round()} €/m²'),
                  _SynthRow('Délai moyen constaté :', '47 jours'),
                  const Divider(color: Color(0xFFB8DFB8), height: 20),
                  Text(
                    'Votre bien se positionne dans la médiane du marché local.',
                    style: TextStyle(fontSize: 12, color: kGreen, fontStyle: FontStyle.italic, height: 1.5),
                  ),
                ]),
              ),

            const SizedBox(height: 16),
          ]),
        ),
      ),
      SectionBottomBar(onPrev: widget.onPrev, onNext: widget.onNext),
    ]);
  }

  void _addComparable(BuildContext context) {
    final addrCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final m2Ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ajouter un comparable', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCharcoal)),
          const SizedBox(height: 16),
          _modalField(addrCtrl, 'Adresse'),
          const SizedBox(height: 10),
          _modalField(descCtrl, 'Type · Surface · Commune'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _modalField(prixCtrl, 'Prix total (€)', num: true)),
            const SizedBox(width: 10),
            Expanded(child: _modalField(m2Ctrl, 'Prix/m² (€)', num: true)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                final comp = {
                  'addr': addrCtrl.text,
                  'desc': descCtrl.text,
                  'date': 'Avril 2026',
                  'prix': double.tryParse(prixCtrl.text) ?? 0.0,
                  'prixM2': double.tryParse(m2Ctrl.text) ?? 0.0,
                };
                final list = List<Map<String, dynamic>>.from(_e.comparables)..add(comp);
                _update(_e.copyWith(comparables: list));
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint, {bool num = false}) => TextField(
        controller: ctrl,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5))),
        style: const TextStyle(fontSize: 14, color: kCharcoal),
      );
}

class _CompCard extends StatelessWidget {
  final Map<String, dynamic> comp;
  final VoidCallback onDelete;
  const _CompCard({required this.comp, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: kGreen, width: 4)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(comp['addr'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal))),
            GestureDetector(onTap: onDelete, child: const Icon(Icons.close, size: 16, color: kLightGrey)),
          ]),
          const SizedBox(height: 2),
          Text(comp['desc'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
          const SizedBox(height: 2),
          Text('Vendu : ${comp['date'] ?? ''}', style: const TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(comp['prix'] as num?)?.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
            Row(children: [
              Text('${(comp['prixM2'] as num?)?.round()} €/m²',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreen)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: const Text('DVF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.6))),
            ]),
          ]),
        ]),
      );
}

class _SynthRow extends StatelessWidget {
  final String label;
  final String value;
  final bool green;
  const _SynthRow(this.label, this.value, {this.green = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: green ? kGreen : kCharcoal)),
        ]),
      );
}
