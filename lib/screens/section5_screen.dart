import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../models/reference_locale.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../services/dvf_service.dart';
import '../services/georisques_service.dart';
import '../services/base_locale_service.dart';
import '../services/pricehubble_parser.dart';
import '../services/concurrence_service.dart';

class Section5Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final ValueChanged<int>? onStepTap;
  const Section5Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev, this.onStepTap});

  @override
  State<Section5Screen> createState() => _Section5ScreenState();
}

class _Section5ScreenState extends State<Section5Screen> {
  late Estimation _e;
  DvfFetchResult? _result;
  bool _loading = false;
  bool _loadingRisques = false;
  List<ReferenceLocale> _localRefs = [];
  // null = tous, 'Maison', 'Appartement'
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _loadDvf();
    _loadLocalRefs();
    if (_e.risques == null) _loadRisques();
  }

  Future<void> _loadLocalRefs() async {
    final refs = await BaseLocaleService().loadByCommune(_e.codeInsee);
    if (mounted) setState(() => _localRefs = refs);
  }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  Future<void> _loadDvf() async {
    setState(() { _loading = true; _result = null; });
    final r = await DvfService().fetch(
      codeInsee: _e.codeInsee,
      typeLocal: _filterType,
      surface: _e.surfaceHabitable.toDouble(),
      radiusKm: _e.dvfRadiusKm > 0 ? _e.dvfRadiusKm : null,
      latitude: _e.latitude,
      longitude: _e.longitude,
    );
    setState(() { _result = r; _loading = false; });
  }

  void _setRadius(double km) {
    if (_e.dvfRadiusKm == km) return;
    _update(_e.copyWith(dvfRadiusKm: km));
    _loadDvf();
  }

  Future<void> _loadRisques() async {
    if (_e.codeInsee.isEmpty) return;
    setState(() => _loadingRisques = true);
    final r = await GeorisquesService().fetch(
      codeInsee: _e.codeInsee,
      latitude: _e.latitude,
      longitude: _e.longitude,
    );
    if (!mounted) return;
    setState(() => _loadingRisques = false);
    _update(_e.copyWith(risques: r));
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

  bool _isLocalSelected(ReferenceLocale r) =>
      _e.comparables.any((c) => c['refId'] == r.id);

  void _toggleLocal(ReferenceLocale r) {
    final list = List<Map<String, dynamic>>.from(_e.comparables);
    final idx = list.indexWhere((c) => c['refId'] == r.id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(r.toComparable());
    }
    _update(_e.copyWith(comparables: list));
  }

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
      AppHeader(title: 'Analyse du marché', reference: _e.reference, step: 5, totalSteps: 7, onBack: widget.onPrev, onStepTap: widget.onStepTap),
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
              const SizedBox(height: 10),

              // Radius filter
              Row(children: [
                const Icon(Icons.radar_rounded, size: 14, color: kGrey),
                const SizedBox(width: 6),
                const Text('Rayon :', style: TextStyle(fontSize: 11, color: kGrey, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _TypeChip(label: 'Commune', selected: _e.dvfRadiusKm == 0, onTap: () => _setRadius(0)),
                const SizedBox(width: 6),
                _TypeChip(label: '1 km', selected: _e.dvfRadiusKm == 1, onTap: () => _setRadius(1)),
                const SizedBox(width: 6),
                _TypeChip(label: '3 km', selected: _e.dvfRadiusKm == 3, onTap: () => _setRadius(3)),
                const SizedBox(width: 6),
                _TypeChip(label: '5 km', selected: _e.dvfRadiusKm == 5, onTap: () => _setRadius(5)),
              ]),
            ])),

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
                  Text(
                      _e.dvfRadiusKm > 0
                          ? '${_filtered.length} vente${_filtered.length > 1 ? 's' : ''} dans un rayon de ${_e.dvfRadiusKm.toInt()} km'
                          : '${_filtered.length} vente${_filtered.length > 1 ? 's' : ''} sur la commune',
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                  Text('${_e.comparables.length} sélectionné${_e.comparables.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen)),
                ]),
              ),
              _MarketStatsCard(transactions: _filtered),
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

            // Mes ventes locales
            if (_localRefs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: const Color(0xFF7B1FA2), width: 4)),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const Icon(Icons.bookmark_rounded, color: Color(0xFF7B1FA2), size: 16),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Mes ventes validées', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                        Text('${_localRefs.length} référence${_localRefs.length > 1 ? 's' : ''} · ${_e.commune.isNotEmpty ? _e.commune : 'Cette commune'}',
                            style: const TextStyle(fontSize: 11, color: kGrey)),
                      ]),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('MA BASE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7B1FA2), letterSpacing: 0.8)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ..._localRefs.map((r) => _LocalRefCard(
                    ref: r,
                    selected: _isLocalSelected(r),
                    onTap: () => _toggleLocal(r),
                  )),
                ]),
              ),
              const SizedBox(height: 4),
            ],

            // Risques naturels & technologiques (IAL)
            _RisquesCard(
              data: _e.risques,
              loading: _loadingRisques,
              onRefresh: _loadRisques,
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
                  if (_e.comparables.length < 3) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kAmber.withOpacity(0.35)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded, color: kAmber, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Échantillon DVF limité (${_e.comparables.length} vente${_e.comparables.length > 1 ? 's' : ''}) — médiane peu représentative. '
                            'Élargissez le rayon ou ajoutez des comparables manuels pour fiabiliser l\'estimation.',
                            style: const TextStyle(fontSize: 11, color: kAmber, height: 1.45),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    _e.comparables.length < 3
                        ? 'Prudence : valeur indicative — données DVF insuffisantes sur ce secteur.'
                        : 'Votre bien se positionne dans la médiane du marché local.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _e.comparables.length < 3 ? kAmber : kGreen,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ]),
              ),

            // Veille concurrence — deep-links portails immobiliers
            _ConcurrenceCard(estimation: _e),

            // Synthèse pondérée DVF / PH / Annonces
            _SynthesePondereeCard(
              estimation: _e,
              dvfMediane: _median,
              onChanged: _update,
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
                Row(children: [
                  Text(
                    'Vendu : ${tx.formattedDate}',
                    style: const TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic),
                  ),
                  if (tx.distanceKm != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.near_me_rounded, size: 9, color: kGreen),
                        const SizedBox(width: 2),
                        Text(
                          '${tx.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen),
                        ),
                      ]),
                    ),
                  ],
                ]),
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

class _RisquesCard extends StatelessWidget {
  final GeorisquesData? data;
  final bool loading;
  final VoidCallback onRefresh;
  const _RisquesCard({required this.data, required this.loading, required this.onRefresh});

  Color _sismiqueColor(String z) {
    final n = int.tryParse(z) ?? 0;
    if (n >= 4) return kRed;
    if (n == 3) return kAmber;
    if (n >= 1) return kGreen;
    return kGrey;
  }

  Color _radonColor(String r) {
    if (r == 'Important') return kRed;
    if (r == 'Moyen') return kAmber;
    if (r == 'Faible') return kGreen;
    return kGrey;
  }

  Color _argileColor(String a) {
    if (a == 'Fort') return kRed;
    if (a == 'Moyen') return kAmber;
    if (a == 'Faible') return kGreen;
    return kGrey;
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: kAmber, size: 18),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Risques naturels & technologiques',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
              Text('IAL — Source Géorisques (officiel)',
                  style: TextStyle(fontSize: 11, color: kGrey)),
            ]),
          ]),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kGreen))
                : const Icon(Icons.refresh_rounded, color: kGreen, size: 20),
            tooltip: 'Actualiser',
          ),
        ]),
        const SizedBox(height: 6),

        if (data == null && !loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune donnée chargée — appuyez sur ↻ pour interroger Géorisques.',
                style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
          )
        else if (data != null && data!.erreur != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Erreur : ${data!.erreur}', style: const TextStyle(fontSize: 11, color: Colors.red)),
          )
        else if (data != null) ...[
          const SizedBox(height: 4),
          // Indicateurs principaux
          Row(children: [
            Expanded(child: _RiskTile(
              icon: Icons.public_rounded,
              label: 'Sismicité',
              value: data!.niveauSismique.isEmpty ? '—' : 'Zone ${data!.niveauSismique}/5',
              color: _sismiqueColor(data!.niveauSismique),
            )),
            const SizedBox(width: 8),
            Expanded(child: _RiskTile(
              icon: Icons.air_rounded,
              label: 'Radon',
              value: data!.potentielRadon.isEmpty ? '—' : data!.potentielRadon,
              color: _radonColor(data!.potentielRadon),
            )),
            const SizedBox(width: 8),
            Expanded(child: _RiskTile(
              icon: Icons.layers_rounded,
              label: 'Argile (RGA)',
              value: data!.niveauArgile.isEmpty ? '—' : data!.niveauArgile,
              color: _argileColor(data!.niveauArgile),
            )),
          ]),
          const SizedBox(height: 12),

          if (data!.risquesNaturels.isNotEmpty) ...[
            const Text('Risques naturels recensés', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCharcoal)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: data!.risquesNaturels.map((r) => _RiskChip(label: r, color: kAmber)).toList()),
            const SizedBox(height: 10),
          ],

          if (data!.risquesTechnologiques.isNotEmpty) ...[
            const Text('Risques technologiques', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCharcoal)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: data!.risquesTechnologiques.map((r) => _RiskChip(label: r, color: kRed)).toList()),
            const SizedBox(height: 10),
          ],

          if (data!.nbCatnat > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${data!.nbCatnat} arrêté${data!.nbCatnat > 1 ? 's' : ''} de catastrophe naturelle sur la commune',
                style: const TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic),
              ),
            ),

          const SizedBox(height: 4),
          const Text(
            'Information transmise au futur acquéreur (obligation IAL — Code de l\'environnement L.125-5).',
            style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic),
          ),
        ],
      ]),
    );
  }
}

class _RiskTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _RiskTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
        ]),
      );
}

class _RiskChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RiskChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}

/// Carte statistiques de marché calculées depuis les DVF chargés
class _MarketStatsCard extends StatelessWidget {
  final List<DvfTransaction> transactions;
  const _MarketStatsCard({required this.transactions});

  double? _medianM2(List<DvfTransaction> txs) {
    final prices = txs.map((t) => t.prixM2).where((p) => p > 0).toList()..sort();
    if (prices.isEmpty) return null;
    return prices[prices.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoff12 = now.subtract(const Duration(days: 365));
    final cutoff36 = now.subtract(const Duration(days: 3 * 365));

    final recent = transactions.where((tx) {
      if (tx.dateMutation.isEmpty) return false;
      try {
        return DateTime.parse(tx.dateMutation).isAfter(cutoff12);
      } catch (_) {
        return false;
      }
    }).toList();

    final older = transactions.where((tx) {
      if (tx.dateMutation.isEmpty) return false;
      try {
        final d = DateTime.parse(tx.dateMutation);
        return d.isBefore(cutoff12) && d.isAfter(cutoff36);
      } catch (_) {
        return false;
      }
    }).toList();

    final med12 = _medianM2(recent);
    final med36 = _medianM2(older);

    double? trend;
    if (med12 != null && med36 != null && med36 > 0) {
      trend = ((med12 - med36) / med36) * 100;
    }

    if (med12 == null && med36 == null) return const SizedBox.shrink();

    final trendColor = trend == null
        ? kGrey
        : trend >= 2
            ? kGreen
            : trend <= -2
                ? kRed
                : kAmber;
    final trendLabel = trend == null
        ? 'N/A'
        : '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEE8), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.trending_up_rounded, size: 14, color: kGreen),
          const SizedBox(width: 6),
          const Text('Tendance marché — données DVF',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _StatCell(
              label: '12 derniers mois',
              value: med12 != null ? '${med12.round()} €/m²' : '—',
              sub: '${recent.length} vente${recent.length > 1 ? 's' : ''}',
              color: kGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCell(
              label: '13–36 mois',
              value: med36 != null ? '${med36.round()} €/m²' : '—',
              sub: '${older.length} vente${older.length > 1 ? 's' : ''}',
              color: kGrey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCell(
              label: 'Tendance',
              value: trendLabel,
              sub: trend != null
                  ? (trend >= 2 ? 'marché en hausse' : trend <= -2 ? 'marché en recul' : 'marché stable')
                  : 'données insuffisantes',
              color: trendColor,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _StatCell({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9, color: kGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ── Synthèse pondérée DVF / PH / Annonces ──────────────────────
class _SynthesePondereeCard extends StatefulWidget {
  final Estimation estimation;
  final double dvfMediane;
  final ValueChanged<Estimation> onChanged;
  const _SynthesePondereeCard({required this.estimation, required this.dvfMediane, required this.onChanged});

  @override
  State<_SynthesePondereeCard> createState() => _SynthesePondereeCardState();
}

class _SynthesePondereeCardState extends State<_SynthesePondereeCard> {
  late TextEditingController _phCtrl;
  late TextEditingController _annCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.estimation;
    _phCtrl = TextEditingController(text: e.prixPricehubble > 0 ? e.prixPricehubble.round().toString() : '');
    _annCtrl = TextEditingController(text: e.prixAnnonces > 0 ? e.prixAnnonces.round().toString() : '');
  }

  @override
  void dispose() { _phCtrl.dispose(); _annCtrl.dispose(); super.dispose(); }

  Estimation get _e => widget.estimation;

  void _update(Estimation e) => widget.onChanged(e);

  void _setPond(int dvf, int ph, int ann) => _update(_e.copyWith(ponderationDvf: dvf, ponderationPh: ph, ponderationAnnonces: ann));

  Future<void> _importPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
      withReadStream: false,
    );
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Lecture du PDF…'),
        ]),
      ),
    );

    final result = await PricehubbleParser.parseFile(path);

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le rapport PriceHubble. Vérifiez le fichier.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation bottom sheet
    _showConfirmSheet(result);
  }

  void _showConfirmSheet(PricehubbleResult result) {
    String fmtP(double v) {
      if (v <= 0) return '—';
      final s = v.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
      return '$s €';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: Color(0xFF5C6BC0), shape: BoxShape.circle),
              child: const Icon(Icons.hub_outlined, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Rapport PriceHubble détecté', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal)),
          ]),
          const SizedBox(height: 16),
          _ConfirmRow(label: 'Valeur estimée', value: fmtP(result.prixEstime), highlight: true),
          if (result.hasRange) ...[
            _ConfirmRow(label: 'Fourchette basse', value: fmtP(result.fourchetteBasse)),
            _ConfirmRow(label: 'Fourchette haute', value: fmtP(result.fourchetteHaute)),
          ],
          if (result.prixM2 > 0)
            _ConfirmRow(label: 'Prix / m²', value: '${result.prixM2.round()} €/m²'),
          if (result.surface > 0)
            _ConfirmRow(label: 'Surface', value: '${result.surface} m²'),
          if (result.adresse.isNotEmpty)
            _ConfirmRow(label: 'Adresse', value: result.adresse),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _phCtrl.text = result.prixEstime.round().toString();
                _update(_e.copyWith(
                  prixPricehubble: result.prixEstime,
                  fourchetteBasse: result.hasRange ? result.fourchetteBasse : _e.fourchetteBasse,
                  fourchetteHaute: result.hasRange ? result.fourchetteHaute : _e.fourchetteHaute,
                ));
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Importer ces valeurs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler', style: TextStyle(color: kGrey)),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  Widget _pondRow(String label, int val, int total, Color color, void Function(int) onInc, void Function(int) onDec) {
    final pct = total > 0 ? (val / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal))),
        GestureDetector(
          onTap: () { if (val > 0) onDec(val); },
          child: Container(width: 28, height: 28, decoration: BoxDecoration(border: Border.all(color: kBorderColor), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center, child: const Icon(Icons.remove, size: 14, color: kGrey)),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 38, child: Text('$val%', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onInc(val),
          child: Container(width: 28, height: 28, decoration: BoxDecoration(border: Border.all(color: kBorderColor), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center, child: const Icon(Icons.add, size: 14, color: kGrey)),
        ),
        const SizedBox(width: 10),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? val / total : 0,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 32, child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: kGrey))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPh = _e.prixPricehubble > 0;
    final hasAnn = _e.prixAnnonces > 0;
    final fondamentalM2 = _e.prixFondamentalM2;
    final surf = _e.surfaceHabitable;
    final fondamental = (fondamentalM2 * surf / 1000).round() * 1000;
    final totalW = _e.ponderationDvf + (hasPh ? _e.ponderationPh : 0) + (hasAnn ? _e.ponderationAnnonces : 0);
    final totalPct = _e.ponderationDvf + _e.ponderationPh + _e.ponderationAnnonces;
    final sumOk = totalPct == 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGreen.withOpacity(0.3), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.balance_rounded, color: kGreen, size: 18),
          const SizedBox(width: 8),
          const Text('Synthèse pondérée', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: const Text('DVF · PH · ANNONCES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.6)),
          ),
        ]),
        const SizedBox(height: 12),

        // DVF row (auto)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF7F9F6), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.bar_chart_rounded, size: 15, color: kGreen),
            const SizedBox(width: 8),
            const Text('DVF (médiane)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
            const Spacer(),
            Text(
              widget.dvfMediane > 0 ? '${widget.dvfMediane.round()} €/m²  ·  ${_fmt(widget.dvfMediane * surf)}' : '—',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // PriceHubble: import button + manual entry field
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: _importPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF5C6BC0)),
                SizedBox(width: 5),
                Text('Importer PDF PriceHubble', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5C6BC0))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        _PriceSourceField(
          label: 'PriceHubble',
          icon: Icons.hub_outlined,
          controller: _phCtrl,
          surface: surf,
          onChanged: (v) => _update(_e.copyWith(prixPricehubble: v)),
        ),
        const SizedBox(height: 8),

        // Annonces field
        _PriceSourceField(
          label: 'Annonces portails',
          icon: Icons.apartment_rounded,
          controller: _annCtrl,
          surface: surf,
          onChanged: (v) => _update(_e.copyWith(prixAnnonces: v)),
        ),

        // Bandeau écart PH vs DVF
        if (hasPh && widget.dvfMediane > 0) ...[
          const SizedBox(height: 10),
          _EcartBandeau(
            dvfTotal: widget.dvfMediane * surf,
            phTotal: _e.prixPricehubble,
          ),
        ],
        const SizedBox(height: 14),

        const Text('Pondération', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
        const SizedBox(height: 6),
        _pondRow('DVF', _e.ponderationDvf, totalW, kGreen,
          (v) => _setPond(v + 5, _e.ponderationPh, _e.ponderationAnnonces),
          (v) => _setPond(v - 5, _e.ponderationPh, _e.ponderationAnnonces),
        ),
        _pondRow('PriceHubble', _e.ponderationPh, totalW, const Color(0xFF5C6BC0),
          (v) => _setPond(_e.ponderationDvf, v + 5, _e.ponderationAnnonces),
          (v) => _setPond(_e.ponderationDvf, v - 5, _e.ponderationAnnonces),
        ),
        _pondRow('Annonces', _e.ponderationAnnonces, totalW, kAmber,
          (v) => _setPond(_e.ponderationDvf, _e.ponderationPh, v + 5),
          (v) => _setPond(_e.ponderationDvf, _e.ponderationPh, v - 5),
        ),

        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Total : $totalPct%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sumOk ? kGreen : kAmber)),
          if (!sumOk) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded, size: 13, color: kAmber),
          ],
        ]),

        const Divider(height: 20),

        // Prix fondamental
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRIX FONDAMENTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGrey, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text('${fondamentalM2.round()} €/m²', style: const TextStyle(fontSize: 11, color: kGrey)),
          ]),
          Text(_fmt(fondamental.toDouble()),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: -0.5)),
        ]),
        if (!hasPh && !hasAnn)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Saisissez l\'estimation PH et/ou annonces pour activer la pondération.',
              style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

class _EcartBandeau extends StatelessWidget {
  final double dvfTotal;
  final double phTotal;
  const _EcartBandeau({required this.dvfTotal, required this.phTotal});

  @override
  Widget build(BuildContext context) {
    final ecartPct = ((phTotal - dvfTotal) / dvfTotal) * 100;
    final absEcart = ecartPct.abs();
    final Color bg;
    final Color border;
    final Color textColor;
    final IconData icon;
    if (absEcart < 5) {
      bg = const Color(0xFFE8F5E9); border = const Color(0xFF81C784); textColor = const Color(0xFF2E7D32); icon = Icons.check_circle_outline;
    } else if (absEcart < 10) {
      bg = const Color(0xFFFFF9E6); border = const Color(0xFFF9A825); textColor = const Color(0xFF7A5800); icon = Icons.warning_amber_outlined;
    } else {
      bg = const Color(0xFFFFEBEE); border = const Color(0xFFEF9A9A); textColor = const Color(0xFFC62828); icon = Icons.error_outline;
    }
    final sign = ecartPct >= 0 ? '+' : '';
    final label = ecartPct >= 0
        ? 'PH $sign${ecartPct.toStringAsFixed(1)}% au-dessus DVF — vérifier les comparables'
        : 'PH $sign${ecartPct.toStringAsFixed(1)}% en-dessous DVF — vérifier les comparables';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor))),
      ]),
    );
  }
}

class _PriceSourceField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final int surface;
  final ValueChanged<double> onChanged;
  const _PriceSourceField({required this.label, required this.icon, required this.controller, required this.surface, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final val = double.tryParse(controller.text.replaceAll(' ', '').replaceAll('€', '')) ?? 0;
    final m2 = val > 0 && surface > 0 ? '${(val / surface).round()} €/m²' : '';
    return Row(children: [
      Icon(icon, size: 15, color: kGrey),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal))),
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal),
          decoration: InputDecoration(
            hintText: '0 €',
            hintStyle: const TextStyle(fontSize: 13, color: kLightGrey),
            suffixText: m2,
            suffixStyle: const TextStyle(fontSize: 10, color: kGrey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v.replaceAll(' ', '')) ?? 0;
            onChanged(parsed);
          },
        ),
      ),
    ]);
  }
}


// ── Carte référence locale (Ma base) ────────────────────────────
class _LocalRefCard extends StatelessWidget {
  final ReferenceLocale ref;
  final bool selected;
  final VoidCallback onTap;
  const _LocalRefCard({required this.ref, required this.selected, required this.onTap});

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7B1FA2);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected ? purple.withValues(alpha: 0.06) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? purple.withValues(alpha: 0.4) : kBorderColor, width: 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              ref.adresse.isNotEmpty ? ref.adresse : 'Adresse non renseignée',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal),
            ),
            const SizedBox(height: 2),
            Text(
              '${ref.typeId[0].toUpperCase()}${ref.typeId.substring(1)} · ${ref.surface} m² · DPE ${ref.dpeClasse}',
              style: const TextStyle(fontSize: 11, color: kGrey),
            ),
            const SizedBox(height: 2),
            Text(
              'Vendu ${ReferenceLocale.fmtDate(ref.dateVente)}',
              style: const TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(ref.prixVente.toDouble()),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              Row(children: [
                Text('${ref.prixM2.round()} €/m²',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: purple)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: const Text('MA BASE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: purple, letterSpacing: 0.6)),
                ),
              ]),
            ]),
          ])),
          const SizedBox(width: 8),
          if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFF7B1FA2), size: 22)
          else const Icon(Icons.radio_button_unchecked, color: kLightGrey, size: 22),
        ]),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ConfirmRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 15 : 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? const Color(0xFF5C6BC0) : kCharcoal,
            ),
          ),
        ]),
      );
}

// ── Veille concurrence — Deep-links portails immobiliers ───────────────────
class _ConcurrenceCard extends StatelessWidget {
  final Estimation estimation;
  const _ConcurrenceCard({required this.estimation});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le portail')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = estimation;
    final canQuery = ConcurrenceService.canQuery(e);

    if (!canQuery) {
      return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardTitleRow(
              icon: Icons.travel_explore_rounded, label: 'Veille concurrence'),
          const SizedBox(height: 4),
          Text(
            e.typeId == 'terrain'
                ? 'Non disponible pour les terrains'
                : 'Renseignez l\'adresse et la surface pour activer la veille.',
            style: const TextStyle(
                fontSize: 12, color: kGrey, fontStyle: FontStyle.italic),
          ),
        ]),
      );
    }

    final portails = ConcurrenceService.allPortails(e);
    final smin = (e.surfaceHabitable * 0.8).round();
    final smax = (e.surfaceHabitable * 1.2).round();
    final filterDesc = '${e.typeId == 'appartement' ? 'Appartements' : 'Maisons'}'
        ' · $smin–$smax m² · ${e.codePostal}';

    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitleRow(
            icon: Icons.travel_explore_rounded, label: 'Veille concurrence'),
        const SizedBox(height: 2),
        Text(filterDesc,
            style: const TextStyle(fontSize: 11, color: kGrey)),
        if (e.prixCalcule > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Fourchette prix : ${(e.prixCalcule * 0.8 / 1000).round()}K – ${(e.prixCalcule * 1.2 / 1000).round()}K €',
              style: const TextStyle(fontSize: 11, color: kGrey),
            ),
          ),
        const SizedBox(height: 10),
        ...portails.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _open(context, p.url),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(p.couleur),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.nom.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nom,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kCharcoal)),
                            Text(p.description,
                                style: const TextStyle(
                                    fontSize: 11, color: kGrey)),
                          ]),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 18, color: kGreen),
                  ]),
                ),
              ),
            )),
        const SizedBox(height: 4),
        const Text(
          'S\'ouvre dans l\'app du portail si installée, sinon navigateur.',
          style: TextStyle(
              fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }
}
