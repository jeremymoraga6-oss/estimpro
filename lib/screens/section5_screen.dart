import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../services/dvf_service.dart';

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
  DvfFetchResult? _result;
  bool _loading = false;
  // null = tous, 'Maison', 'Appartement'
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _loadDvf();
  }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  Future<void> _loadDvf() async {
    setState(() { _loading = true; _result = null; });
    final r = await DvfService().fetch(
      codeInsee: _e.codeInsee,
      typeLocal: _filterType,
      surface: _e.surfaceHabitable.toDouble(),
    );
    setState(() { _result = r; _loading = false; });
  }

  List<DvfTransaction> get _filtered => _result?.transactions ?? [];

  double get _median {
    final prices = _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).where((p) => p > 0).toList()..sort();
    if (prices.isEmpty) return 0;
    return prices[prices.length ~/ 2];
  }

  double get _min => _e.comparables.isEmpty ? 0 : _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b);
  double get _max => _e.comparables.isEmpty ? 0 : _e.comparables.map<double>((c) => (c['prixM2'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);

  bool _isSelected(DvfTransaction tx) => _e.comparables.any((c) => c['addr'] == tx.toComparable()['addr'] && c['date'] == tx.toComparable()['date']);

  void _toggle(DvfTransaction tx) {
    final comp = tx.toComparable();
    final list = List<Map<String, dynamic>>.from(_e.comparables);
    final idx = list.indexWhere((c) => c['addr'] == comp['addr'] && c['date'] == comp['date']);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(comp);
    }
    _update(_e.copyWith(comparables: list));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'Analyse du marché', reference: _e.reference, step: 5, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // DVF header card
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
              const SizedBox(height: 12),

              // Type filter chips
              Row(children: [
                _TypeChip(label: 'Tous', selected: _filterType == null, onTap: () { setState(() => _filterType = null); _loadDvf(); }),
                const SizedBox(width: 8),
                _TypeChip(label: 'Maison', selected: _filterType == 'Maison', onTap: () { setState(() => _filterType = 'Maison'); _loadDvf(); }),
                const SizedBox(width: 8),
                _TypeChip(label: 'Appartement', selected: _filterType == 'Appartement', onTap: () { setState(() => _filterType = 'Appartement'); _loadDvf(); }),
              ]),
            ])),

            // Debug bandeau
            if (_result != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.bug_report_outlined, size: 13, color: Color(0xFF888888)),
                    const SizedBox(width: 5),
                    const Text('DEBUG DVF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.6)),
                  ]),
                  const SizedBox(height: 4),
                  Text('INSEE : ${_result!.codeInsee}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                  const SizedBox(height: 2),
                  Text('Résultats bruts : ${_result!.nombreBrut}  →  après filtres : ${_filtered.length}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                  const SizedBox(height: 2),
                  Text(_result!.urlUtilisee, style: const TextStyle(fontSize: 9, color: Color(0xFF999999)), overflow: TextOverflow.ellipsis, maxLines: 2),
                  if (_result!.erreur != null) ...[
                    const SizedBox(height: 2),
                    Text('Erreur : ${_result!.erreur}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ]),
              ),

            // Results
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  CircularProgressIndicator(color: kGreen, strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Chargement des ventes DVF…', style: TextStyle(fontSize: 12, color: kGrey)),
                ]),
              )
            else if (_result?.erreur != null && _filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  const Icon(Icons.wifi_off_rounded, color: kLightGrey, size: 36),
                  const SizedBox(height: 10),
                  const Text('Impossible de charger les données DVF', style: TextStyle(fontSize: 13, color: kGrey)),
                  const SizedBox(height: 6),
                  TextButton.icon(onPressed: _loadDvf, icon: const Icon(Icons.refresh, size: 16), label: const Text('Réessayer')),
                ]),
              )
            else if (!_loading && _result != null && _filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  const Icon(Icons.search_off_rounded, color: kLightGrey, size: 36),
                  const SizedBox(height: 10),
                  const Text('Aucune vente trouvée dans ce secteur.', style: TextStyle(fontSize: 13, color: kGrey), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Code INSEE utilisé : ${_result!.codeInsee}', style: const TextStyle(fontSize: 11, color: kLightGrey)),
                  const SizedBox(height: 4),
                  const Text('Essayez d\'élargir la recherche.', style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
                ]),
              )
            else if (_filtered.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_filtered.length} vente${_filtered.length > 1 ? 's' : ''} — appuyez pour sélectionner',
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                  Text('${_e.comparables.length} sélectionné${_e.comparables.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen)),
                ]),
              ),
              ..._filtered.map((tx) => _DvfCard(
                tx: tx,
                selected: _isSelected(tx),
                onTap: () => _toggle(tx),
              )),
            ],

            // Manual add
            GestureDetector(
              onTap: () => _addManual(context),
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
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
                  const Text('Ajouter un comparable manuellement', style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

            // Synthèse
            if (_e.comparables.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
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
                    Text('Synthèse — ${_e.comparables.length} comparable${_e.comparables.length > 1 ? 's' : ''}', style: kCardTitle.copyWith(color: kGreen)),
                  ]),
                  const SizedBox(height: 14),
                  _SynthRow('Prix médian DVF :', '${_median.round()} €/m²', green: true),
                  _SynthRow('Fourchette constatée :', '${_min.round()} — ${_max.round()} €/m²'),
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

  void _addManual(BuildContext context) {
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
                  'date': 'Avr. 2026',
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

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kGreen : kBorderColor, width: 1.5),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : kGrey)),
        ),
      );
}

class _DvfCard extends StatelessWidget {
  final DvfTransaction tx;
  final bool selected;
  final VoidCallback onTap;
  const _DvfCard({required this.tx, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F5E9) : Colors.white,
            border: Border(left: BorderSide(color: selected ? kGreen : const Color(0xFFE0E0E0), width: 4)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  tx.toComparable()['addr'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.typeLocal} · ${tx.surfaceReelleBati.round()} m² · ${tx.nomCommune}',
                  style: const TextStyle(fontSize: 11, color: kGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vendu : ${tx.formattedDate}',
                  style: const TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    '${tx.valeurFonciere.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
                  ),
                  Row(children: [
                    Text(
                      '${tx.prixM2.round()} €/m²',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreen),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: const Text('DVF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.6)),
                    ),
                  ]),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            if (selected) const Icon(Icons.check_circle_rounded, color: kGreen, size: 22)
            else const Icon(Icons.radio_button_unchecked, color: kLightGrey, size: 22),
          ]),
        ),
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
