import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/mes_notes.dart';
import '../widgets/star_rating.dart';

class Section6Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const Section6Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev});

  @override
  State<Section6Screen> createState() => _Section6ScreenState();
}

class _Section6ScreenState extends State<Section6Screen> {
  late Estimation _e;
  late TextEditingController _conclusionCtrl;

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _conclusionCtrl = TextEditingController(text: _e.conclusion.isEmpty
        ? 'Bien positionné dans la médiane DVF du secteur. Valeur cohérente avec les transactions récentes et le contexte de marché local.'
        : _e.conclusion);
  }

  @override
  void dispose() { _conclusionCtrl.dispose(); super.dispose(); }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    final base = _e.prixBase;
    final totalPct = _e.ajustVue + _e.ajustEtat + _e.ajustDpe + _e.ajustExposition + _e.ajustEnvironnement;
    final impact = base * totalPct / 100 - _e.ajustTravaux + _e.ajustParking;
    final raw = base + impact;
    final rounded = (raw / 1000).round() * 1000.0;
    final low = _e.fourchetteBasse > 0 ? _e.fourchetteBasse : (rounded * 0.95 / 1000).round() * 1000.0;
    final high = _e.fourchetteHaute > 0 ? _e.fourchetteHaute : (rounded * 1.05 / 1000).round() * 1000.0;

    return Column(children: [
      AppHeader(title: 'Estimation', reference: _e.reference, step: 6, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Hero card
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: BoxDecoration(
                color: kGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VALEUR ESTIMÉE', style: TextStyle(fontSize: 10, color: Color(0xCCFFFFFF), fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(_fmt(rounded), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1.5, height: 1.1)),
                const SizedBox(height: 4),
                Text('${_e.prixMoyen.round()} €/m² · Calculé depuis DVF',
                    style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
                const SizedBox(height: 14),
                Container(height: 1, color: Colors.white.withOpacity(0.25)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fourchette basse', style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF))),
                    const SizedBox(height: 2),
                    Text(_fmt(low), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Fourchette haute', style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF))),
                    const SizedBox(height: 2),
                    Text(_fmt(high), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check, size: 11, color: kGreen),
                      const SizedBox(width: 4),
                      Text('Basé sur ${_e.comparables.length} comparable${_e.comparables.length > 1 ? 's' : ''} DVF',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen)),
                    ]),
                  ),
                ),
              ]),
            ),

            // Base DVF
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.bar_chart_rounded, label: 'Prix de référence DVF'),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Prix médian constaté :', style: TextStyle(fontSize: 12, color: kGrey)),
                  Text('Sur ${_e.comparables.length} ventes · Ayse et communes proches',
                      style: const TextStyle(fontSize: 11, color: kLightGrey)),
                ]),
                Text('${_e.prixMoyen.round()} €/m²', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
              const SizedBox(height: 8),
              Text('Surface du bien : ${_e.surfaceHabitable} m²', style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
              const CardDivider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Text('${_e.prixMoyen.round()} €/m² × ${_e.surfaceHabitable} m² = ${_fmt(base)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
                  child: const Text('POINT DE DÉPART', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF95A5A6), letterSpacing: 0.5)),
                ),
              ]),
            ])),

            // Prestations
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.workspace_premium_outlined, label: 'Qualité des prestations'),
              StarDisplay(label: 'Cuisine', rating: _e.noteCuisine),
              StarDisplay(label: 'Sol', rating: _e.noteSol),
              StarDisplay(label: 'Salle de bain', rating: _e.noteSdb),
              StarDisplay(label: 'Fenêtres / Menuiseries', rating: _e.noteFenetres),
              StarDisplay(label: 'Chauffage', rating: _e.noteChauffage),
              StarDisplay(label: 'État général', rating: _e.noteEtatPrestation),
              const CardDivider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Score pondéré : ${_e.scorePrestations.toStringAsFixed(1)}/4',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                Text('${_e.coefficientPrestations >= 0 ? '+' : ''}${_e.coefficientPrestations.toInt()}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: _e.coefficientPrestations > 0 ? kGreen : _e.coefficientPrestations < 0 ? kRed : kGrey)),
              ]),
              const SizedBox(height: 2),
              Text(_e.labelCoefficientPrestations,
                  style: const TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF7F9F6), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _PriceDetailRow('Prix m² médian DVF :', '${_e.prixMoyen.round()} €/m²'),
                  _PriceDetailRow('Ajust. prestations :', '${_e.coefficientPrestations >= 0 ? '+' : ''}${_e.coefficientPrestations.toInt()}%'),
                  _PriceDetailRow('Prix m² retenu :', '${_e.prixM2Retenu.round()} €/m²', bold: true),
                  if (_e.ajustExposition != 0)
                    _PriceDetailRow('Exposition :', '${_e.ajustExposition >= 0 ? '+' : ''}${_e.ajustExposition.toStringAsFixed(1)}%'),
                  if (_e.ajustParking != 0)
                    _PriceDetailRow('Parking :', '${_e.ajustParking >= 0 ? '+' : '−'}${_fmt((_e.ajustParking.abs()).toDouble())}'),
                  if (_e.ajustPiscine > 0)
                    _PriceDetailRow('Piscine :', '+${_fmt(_e.ajustPiscine.toDouble())}'),
                ]),
              ),
            ])),

            // Ajustements
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.tune_rounded, label: 'Coefficients d\'ajustement'),
              const Text('Glissez pour ajuster · Impact calculé en temps réel',
                  style: TextStyle(fontSize: 11, color: Color(0xFF95A5A6), fontStyle: FontStyle.italic)),
              const SizedBox(height: 14),

              _AdjRow(label: 'Vue dégagée', val: _e.ajustVue, min: 0, max: 8,
                  onChanged: (v) => _update(_e.copyWith(ajustVue: v))),
              _AdjRow(label: 'Rénové / Bon état', val: _e.ajustEtat, min: -5, max: 8,
                  onChanged: (v) => _update(_e.copyWith(ajustEtat: v))),
              _AdjRow(
                label: 'Performance énergétique (DPE ${_e.dpeClasse})',
                val: _e.ajustDpe,
                min: -8,
                max: 3,
                note: 'DPE ${_e.dpeClasse} · ${_e.ajustDpe < 0 ? 'décote' : _e.ajustDpe > 0 ? 'bonus' : 'neutre'}',
                recommended: _e.recommendedAjustDpe,
                onChanged: (v) => _update(_e.copyWith(ajustDpe: v)),
                onReset: () => _update(_e.copyWith(ajustDpe: _e.recommendedAjustDpe)),
              ),
              _AdjRow(
                label: 'Exposition / Orientation${_e.orientations.isNotEmpty ? ' (${_e.orientations.join(', ')})' : ''}',
                val: _e.ajustExposition,
                min: -5,
                max: 3,
                note: _e.ajustExposition < -2 ? 'exposition défavorable' : _e.ajustExposition > 1 ? 'exposition favorable' : 'exposition neutre',
                recommended: _e.recommendedAjustExposition,
                onChanged: (v) => _update(_e.copyWith(ajustExposition: v)),
                onReset: () => _update(_e.copyWith(ajustExposition: _e.recommendedAjustExposition)),
              ),
              _AdjRow(
                label: 'Environnement / Nuisances',
                val: _e.ajustEnvironnement,
                min: -5,
                max: 0,
                note: _e.ajustEnvironnement < -3 ? 'nuisances importantes' : _e.ajustEnvironnement < -1 ? 'nuisances modérées' : 'environnement neutre',
                onChanged: (v) => _update(_e.copyWith(ajustEnvironnement: v)),
              ),

              // Parking stepper
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Parking / Stationnement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                  Text(
                    _e.ajustParking == 0
                        ? 'Inclus'
                        : _e.ajustParking < 0
                            ? '−${_fmt((-_e.ajustParking).toDouble())}'
                            : '+${_fmt(_e.ajustParking.toDouble())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _e.ajustParking < 0 ? kRed : _e.ajustParking > 0 ? kGreen : const Color(0xFF95A5A6),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF7F9F6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8EDE8), width: 1.5)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(
                      onTap: () => _update(_e.copyWith(ajustParking: _e.ajustParking - 1000)),
                      child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLightGrey, width: 1.5), color: Colors.white),
                          child: const Icon(Icons.remove, size: 14, color: kGrey)),
                    ),
                    Column(children: [
                      Text(
                        _e.ajustParking == 0
                            ? 'Parking inclus'
                            : _e.ajustParking < 0
                                ? 'Malus : ${_fmt((-_e.ajustParking).toDouble())}'
                                : 'Bonus : +${_fmt(_e.ajustParking.toDouble())}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
                      ),
                      if (_e.ajustParking != 0)
                        Text(_e.ajustParking < 0 ? 'Sans stationnement' : 'Parking supplémentaire',
                            style: const TextStyle(fontSize: 9, color: kGrey)),
                    ]),
                    GestureDetector(
                      onTap: () => _update(_e.copyWith(ajustParking: _e.ajustParking + 1000)),
                      child: Container(width: 32, height: 32, decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
                          child: const Icon(Icons.add, size: 14, color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                const Text('−8 000 € sans parking · +5 000 € avec parking supplémentaire', style: TextStyle(fontSize: 10, color: kLightGrey)),
              ]),
              const SizedBox(height: 14),

              // Piscine stepper (visible si piscine active)
              if (_e.annexesActives['piscine'] == true) ...[
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Row(children: [
                      Icon(Icons.pool_outlined, size: 14, color: kGreen),
                      SizedBox(width: 6),
                      Text('Prime piscine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                    ]),
                    Text(
                      _e.ajustPiscine > 0 ? '+${_fmt(_e.ajustPiscine.toDouble())}' : 'Non valorisée',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _e.ajustPiscine > 0 ? kGreen : const Color(0xFF95A5A6)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreen.withOpacity(0.2), width: 1.5)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      GestureDetector(
                        onTap: () => _update(_e.copyWith(ajustPiscine: _e.ajustPiscine > 0 ? _e.ajustPiscine - 1000 : 0)),
                        child: Container(width: 32, height: 32,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLightGrey, width: 1.5), color: Colors.white),
                            child: const Icon(Icons.remove, size: 14, color: kGrey)),
                      ),
                      Column(children: [
                        Text(
                          _e.ajustPiscine > 0 ? '+${_fmt(_e.ajustPiscine.toDouble())}' : '0 €',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal),
                        ),
                        const Text('PriceHubble ne la valorise pas', style: TextStyle(fontSize: 9, color: kGrey)),
                      ]),
                      GestureDetector(
                        onTap: () => _update(_e.copyWith(ajustPiscine: _e.ajustPiscine + 1000)),
                        child: Container(width: 32, height: 32,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
                            child: const Icon(Icons.add, size: 14, color: Colors.white)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const Text('Calibré terrain : +10 000 € (piscine standard) à +20 000 € (piscine récente / équipée)',
                      style: TextStyle(fontSize: 10, color: kLightGrey)),
                ]),
                const SizedBox(height: 14),
              ],

              // Travaux stepper
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Travaux à prévoir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                  Text(_e.ajustTravaux > 0 ? '−${_fmt(_e.ajustTravaux.toDouble())}' : '0 €',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _e.ajustTravaux > 0 ? kRed : const Color(0xFF95A5A6))),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF7F9F6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8EDE8), width: 1.5)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(
                      onTap: () => _update(_e.copyWith(ajustTravaux: _e.ajustTravaux > 0 ? _e.ajustTravaux - 5000 : 0)),
                      child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLightGrey, width: 1.5), color: Colors.white),
                          child: const Icon(Icons.remove, size: 14, color: kGrey)),
                    ),
                    Text(_e.ajustTravaux > 0 ? '${_e.ajustTravaux.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €' : '0 €',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
                    GestureDetector(
                      onTap: () => _update(_e.copyWith(ajustTravaux: _e.ajustTravaux + 5000)),
                      child: Container(width: 32, height: 32, decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
                          child: const Icon(Icons.add, size: 14, color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                const Text('Déduit de la valeur finale', style: TextStyle(fontSize: 10, color: kLightGrey)),
              ]),

              const CardDivider(),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Impact total des ajustements : ${totalPct >= 0 ? '+' : ''}${totalPct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreen)),
                  const SizedBox(height: 2),
                  Text(
                    '${impact >= 0 ? '+' : ''}${impact.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €'
                    '${_e.ajustParking != 0 ? ' (dont parking ${_e.ajustParking < 0 ? '−' : '+'}${_fmt((_e.ajustParking.abs()).toDouble())})' : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6)),
                  ),
                ]),
              ]),
            ])),

            // Résultat
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.gps_fixed_rounded, label: 'Résultat'),
              Center(
                child: Column(children: [
                  Text(_fmt(base), style: const TextStyle(fontSize: 12, color: kLightGrey, decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: 4),
                  Text('↓ ajustements appliqués', style: TextStyle(fontSize: 11, color: kGreen)),
                  const SizedBox(height: 4),
                  Text(_fmt(raw), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_fmt(rounded), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kGreen)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
                      child: const Text('ARRONDI RECOMMANDÉ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF95A5A6), letterSpacing: 0.5)),
                    ),
                  ]),
                ]),
              ),
              const CardDivider(),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_fmt(low), style: const TextStyle(fontSize: 14, color: Color(0xFF95A5A6))),
                const Text('  —  ', style: TextStyle(color: kLightGrey)),
                Text(_fmt(high), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
              const SizedBox(height: 4),
              const Center(child: Text('Fourchette ± 5%', style: TextStyle(fontSize: 10, color: kLightGrey))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Fourchette basse'),
                  TextField(
                    controller: TextEditingController(text: _fmt(low)),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(_e.copyWith(fourchetteBasse: _parsePrice(v))),
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5))),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal),
                  ),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Fourchette haute'),
                  TextField(
                    controller: TextEditingController(text: _fmt(high)),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(_e.copyWith(fourchetteHaute: _parsePrice(v))),
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5))),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal),
                  ),
                ])),
              ]),
              const SizedBox(height: 4),
              const Text('Modifiez si nécessaire', style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
            ])),

            // Prix de mandat
            _PrixMandatCard(estimation: _e, onChanged: _update),

            // Auto vigilance
            _AutoVigilanceCard(estimation: _e, onInsert: (text) {
              final cur = _conclusionCtrl.text;
              final updated = cur.isEmpty ? text : '$cur\n$text';
              _conclusionCtrl.text = updated;
              _update(_e.copyWith(conclusion: updated));
            }),

            // Conclusion
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.edit_note_rounded, label: 'Conclusion'),
              const FieldLabel('Justification'),
              TextField(
                controller: _conclusionCtrl,
                maxLines: 3,
                onChanged: (v) => _update(_e.copyWith(conclusion: v)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 12, color: kCharcoal, height: 1.6),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Valide jusqu\'au', style: TextStyle(fontSize: 11, color: kGrey)),
                    const SizedBox(height: 2),
                    Text(_fmtDate(_e.validiteJusquau), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                    const Text('Auto +12 mois', style: TextStyle(fontSize: 10, color: kGreen)),
                  ]),
                  const Icon(Icons.edit_outlined, color: kGreen, size: 16),
                ]),
              ),

              MesNotes(sectionKey: 'section6', initialData: _e.notes['section6'] ?? {}, onChanged: (data) {
                final n = Map<String, Map<String, dynamic>>.from(_e.notes); n['section6'] = data;
                _update(_e.copyWith(notes: n, prixFinal: rounded, fourchetteBasse: low, fourchetteHaute: high));
              }),
            ])),

            const SizedBox(height: 16),
          ]),
        ),
      ),
      SectionBottomBar(onPrev: widget.onPrev, onNext: () {
        _update(_e.copyWith(prixFinal: rounded, fourchetteBasse: low, fourchetteHaute: high, conclusion: _conclusionCtrl.text));
        widget.onNext();
      }, nextLabel: 'Photos & PDF'),
    ]);
  }

  double _parsePrice(String s) => double.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  String _fmtDate(DateTime d) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _PriceDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceDetailRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: kGrey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? kGreen : kCharcoal)),
        ]),
      );
}

class _AdjRow extends StatelessWidget {
  final String label;
  final double val;
  final double min;
  final double max;
  final String? note;
  final double? recommended;
  final VoidCallback? onReset;
  final ValueChanged<double> onChanged;
  const _AdjRow({required this.label, required this.val, required this.min, required this.max, this.note, this.recommended, this.onReset, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pct = val.round();
    final impactStr = pct >= 0 ? '+$pct%' : '$pct%';
    final color = pct > 0 ? kGreen : pct < 0 ? kRed : const Color(0xFF95A5A6);
    final showResetHint = recommended != null && (val - recommended!).abs() > 0.4;
    final recPct = recommended?.round() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (showResetHint && onReset != null)
              GestureDetector(
                onTap: onReset,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kAmber.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_fix_high_rounded, size: 10, color: kAmber),
                    const SizedBox(width: 3),
                    Text(
                      'Calibré : ${recPct >= 0 ? '+' : ''}$recPct%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kAmber),
                    ),
                  ]),
                ),
              ),
            Text(impactStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ]),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: kGreen,
            inactiveTrackColor: const Color(0xFFE0E0E0),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackHeight: 4,
          ),
          child: Slider(value: val.clamp(min, max), min: min, max: max, divisions: ((max - min) * 2).round(),
              onChanged: onChanged),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(min >= 0 ? '+${min.round()}%' : '${min.round()}%', style: const TextStyle(fontSize: 10, color: kLightGrey)),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
          Text(max >= 0 ? '+${max.round()}%' : '${max.round()}%', style: const TextStyle(fontSize: 10, color: kLightGrey)),
        ]),
      ]),
    );
  }
}

/// Génère des points de vigilance automatiques basés sur les caractéristiques du bien
class _AutoVigilanceCard extends StatelessWidget {
  final Estimation estimation;
  final ValueChanged<String> onInsert;
  const _AutoVigilanceCard({required this.estimation, required this.onInsert});

  List<({String text, Color color, IconData icon})> _buildPoints() {
    final e = estimation;
    final points = <({String text, Color color, IconData icon})>[];

    // DPE
    if (e.dpeClasse == 'NC') {
      final annee = int.tryParse(e.anneeConstruction) ?? 0;
      final risquePre75 = annee > 0 && annee < 1975;
      points.add((
        text: 'DPE non communiqué — à exiger impérativement avant toute estimation définitive. '
            '${risquePre75 ? 'Bâtiment de $annee : forte probabilité DPE E ou F (isolation pré-réglementation thermique 1975). ' : ''}'
            'Un DPE F décalerait la valeur de −5% ; un DPE G de −8%. Ne pas publier sans DPE.',
        color: kAmber,
        icon: Icons.quiz_outlined,
      ));
    } else if (e.dpeClasse == 'G') {
      points.add((
        text: 'DPE G : interdit à la location depuis le 1ᵉʳ janv. 2025 — investisseurs exclus (≈40% du marché). '
            'Décote forte + délai de vente long. Travaux obligatoires avant toute relocation. '
            'Estimer le coût de rénovation énergétique et l\'intégrer en ajustement travaux.',
        color: kRed,
        icon: Icons.energy_savings_leaf_outlined,
      ));
      points.add((
        text: 'Marché cible restreint aux acquéreurs occupants uniquement — '
            'orienter la prospection vers primo-accédants et seniors résidents.',
        color: kAmber,
        icon: Icons.people_outline_rounded,
      ));
    } else if (e.dpeClasse == 'F') {
      points.add((
        text: 'DPE F : interdit à la location au 1ᵉʳ janv. 2028 — investisseurs exclus dès aujourd\'hui. '
            'Décote structurelle −5% + risque délai de vente élevé (cas documenté : comparable DPE F invendu 329 jours). '
            'Travaux de rénovation énergétique conseillés : +20 000 à +40 000 € pour atteindre DPE D.',
        color: kRed,
        icon: Icons.energy_savings_leaf_outlined,
      ));
      points.add((
        text: 'Stratégie commerciale : cibler acquéreurs occupants, valoriser les atouts locaux '
            '(services, accessibilité). Prévoir marge de négociation généreuse (3–5%).',
        color: kAmber,
        icon: Icons.people_outline_rounded,
      ));
    } else if (e.dpeClasse == 'E') {
      points.add((
        text: 'DPE E : performance énergétique limitée — légère décote probable, évoquer les aides MaPrimeRénov\'.',
        color: kAmber,
        icon: Icons.energy_savings_leaf_outlined,
      ));
    } else if (e.dpeClasse == 'C') {
      points.add((
        text: 'DPE C : bonne performance énergétique — atout commercial vs concurrence, légère prime justifiée.',
        color: kGreen,
        icon: Icons.energy_savings_leaf_outlined,
      ));
    } else if (e.dpeClasse == 'A' || e.dpeClasse == 'B') {
      points.add((
        text: 'DPE ${e.dpeClasse} : excellente performance énergétique — atout commercial majeur, prime significative justifiée.',
        color: kGreen,
        icon: Icons.energy_savings_leaf_outlined,
      ));
    }

    // État général
    if (e.etatGeneral == 0) {
      points.add((
        text: 'État dégradé : travaux importants à prévoir — positionnement prix prudent, budget travaux à communiquer.',
        color: kRed,
        icon: Icons.build_outlined,
      ));
    } else if (e.etatGeneral == 1) {
      points.add((
        text: 'Quelques travaux d\'entretien à prévoir — intégrer dans la négociation.',
        color: kAmber,
        icon: Icons.build_outlined,
      ));
    }

    // Travaux planifiés
    if (e.ajustTravaux > 20000) {
      points.add((
        text: 'Budget travaux significatif (${(e.ajustTravaux / 1000).round()}k€) — bien communiquer aux acquéreurs pour justifier le prix.',
        color: kAmber,
        icon: Icons.home_repair_service_outlined,
      ));
    }

    // Piscine
    if (e.annexesActives['piscine'] == true && e.ajustPiscine == 0) {
      points.add((
        text: 'Piscine présente mais non valorisée — appliquer +10 000 à +20 000 € (PriceHubble ne la prend pas en compte).',
        color: kGreen,
        icon: Icons.pool_outlined,
      ));
    }

    // Grande surface maison
    if (e.typeId == 'maison' && e.surfaceHabitable > 160) {
      points.add((
        text: 'Grande surface (${e.surfaceHabitable} m²) : cible acheteurs familiale, délai de vente potentiellement plus long.',
        color: kAmber,
        icon: Icons.straighten_outlined,
      ));
    }

    // Construction ancienne
    if (e.anneeConstruction == 'Avant 1949' || e.anneeConstruction == '1949-1970') {
      points.add((
        text: 'Construction ancienne : attention aux diagnostics (plomb, amiante) — prévoir avant mise en vente.',
        color: kAmber,
        icon: Icons.warning_amber_outlined,
      ));
    }

    // Exposition Nord
    if (e.orientations.contains('N') && !e.orientations.contains('S')) {
      points.add((
        text: 'Exposition Nord : point faible structurel — décote 3–5% vs exposition Sud sur ce marché.',
        color: kAmber,
        icon: Icons.explore_outlined,
      ));
    }

    // Sans parking (appartement)
    if (e.typeId == 'appartement' &&
        e.annexesActives['parking'] != true &&
        e.annexesActives['garage'] != true) {
      points.add((
        text: 'Pas de stationnement : frein significatif — décote estimée 5 000–8 000 € selon marché local.',
        color: kAmber,
        icon: Icons.local_parking_outlined,
      ));
    }

    // Sans ascenseur (appartement)
    if (e.typeId == 'appartement' && !e.ascenseur) {
      points.add((
        text: 'Sans ascenseur : frein pour acquéreurs seniors — décote 2–3% selon étage. À mentionner impérativement.',
        color: kAmber,
        icon: Icons.elevator_outlined,
      ));
    }

    // Bien loué (non libre d'occupation)
    if (!e.libreOccupation) {
      points.add((
        text: 'Bien occupé (loué) : décote habituelle de 10–15% vs bien libre — obligation d\'informer l\'acquéreur.',
        color: kRed,
        icon: Icons.key_outlined,
      ));
    }

    // Libre d'occupation → atout pour appartement
    if (e.libreOccupation && e.typeId == 'appartement') {
      points.add((
        text: 'Libre d\'occupation : atout fort vs parc locatif — arguable pour primo-accédants et investisseurs.',
        color: kGreen,
        icon: Icons.key_outlined,
      ));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAmber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tips_and_updates_rounded, color: kAmber, size: 16),
          const SizedBox(width: 8),
          const Text('Points de vigilance suggérés',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
          const Spacer(),
          const Text('Appuyer pour insérer', style: TextStyle(fontSize: 10, color: kGrey, fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(height: 10),
        ...points.map((p) => GestureDetector(
          onTap: () => onInsert(p.text),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.color.withOpacity(0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(p.icon, size: 14, color: p.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.text,
                    style: TextStyle(fontSize: 11, color: kCharcoal.withOpacity(0.85), height: 1.45)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.add_circle_outline_rounded, size: 16, color: p.color.withOpacity(0.7)),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ── Prix de mandat ──────────────────────────────────────────────
class _PrixMandatCard extends StatelessWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  const _PrixMandatCard({required this.estimation, required this.onChanged});

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    final e = estimation;
    final netVendeur = e.prixCalcule;
    final mandat = e.prixMandat;
    final plancher = (netVendeur * 0.95 / 1000).round() * 1000.0;
    final marge = e.margeNegociation;

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitleRow(icon: Icons.sell_outlined, label: 'Prix de commercialisation'),
      const SizedBox(height: 4),

      // Net vendeur
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Prix net vendeur', style: TextStyle(fontSize: 12, color: kGrey)),
        Text(_fmt(netVendeur), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
      ]),
      const SizedBox(height: 14),

      // Marge slider
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Marge de négociation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('+${marge.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
        ),
      ]),
      Slider(
        value: marge,
        min: 0,
        max: 20,
        divisions: 20,
        activeColor: kGreen,
        inactiveColor: kGreen.withOpacity(0.15),
        onChanged: (v) => onChanged(e.copyWith(margeNegociation: v)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('0%', style: TextStyle(fontSize: 10, color: kLightGrey)),
        const Text('10%', style: TextStyle(fontSize: 10, color: kLightGrey)),
        const Text('20%', style: TextStyle(fontSize: 10, color: kLightGrey)),
      ]),
      const SizedBox(height: 14),

      // Prix mandat — hero
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kGreen.withOpacity(0.08), kGreen.withOpacity(0.04)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGreen.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRIX DE MANDAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text('Net vendeur +${marge.toInt()}% de marge', style: const TextStyle(fontSize: 11, color: kGrey)),
          ]),
          Text(_fmt(mandat), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: -0.5)),
        ]),
      ),
      const SizedBox(height: 8),

      // Prix plancher
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.south_rounded, size: 13, color: kLightGrey),
          const SizedBox(width: 4),
          const Text('Prix plancher (−5%)', style: TextStyle(fontSize: 11, color: kGrey)),
        ]),
        Text(_fmt(plancher), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGrey)),
      ]),
      const SizedBox(height: 4),
      const Text('Ne pas descendre en dessous sans accord vendeur', style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
    ]));
  }
}
