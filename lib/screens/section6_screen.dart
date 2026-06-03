import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../models/facture.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/mes_notes.dart';
import '../widgets/star_rating.dart';
import '../services/base_locale_service.dart';
import '../services/facture_service.dart';

class Section6Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final ValueChanged<int>? onStepTap;
  const Section6Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev, this.onStepTap});

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
    final occupPct = _e.libreOccupation ? 0.0 : -12.0;
    final totalPct = _e.ajustVue + _e.ajustEtat + _e.ajustDpe + _e.ajustExposition +
        _e.ajustEnvironnement + _e.ajustConjoncture + _e.decoteSurface + occupPct +
        _e.ajustEtageAuto + _e.decoteCharges;
    final impact = base * totalPct / 100 - _e.ajustTravaux + _e.ajustParking + _e.primeTerrain;
    final raw = base + impact;
    final rounded = (raw / 1000).round() * 1000.0;
    final low = _e.fourchetteBasse > 0 ? _e.fourchetteBasse : (rounded * 0.95 / 1000).round() * 1000.0;
    final high = _e.fourchetteHaute > 0 ? _e.fourchetteHaute : (rounded * 1.05 / 1000).round() * 1000.0;

    return Column(children: [
      AppHeader(title: 'Estimation', reference: _e.reference, step: 6, totalSteps: 7, onBack: widget.onPrev, onStepTap: widget.onStepTap),
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
              Row(children: [
                Text('Surface habitable : ${_e.surfaceHabitable} m²', style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
                if (_e.surfacePonderee > _e.surfaceHabitable) ...[
                  const Text('  ·  ', style: TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
                  Text('Pondérée : ${_e.surfacePonderee.toStringAsFixed(1)} m²',
                      style: const TextStyle(fontSize: 11, color: kGreen, fontWeight: FontWeight.w600)),
                ],
              ]),
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
              if (_e.surfacePonderee > _e.surfaceHabitable && rounded > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calculate_outlined, size: 12, color: kGrey),
                  const SizedBox(width: 6),
                  Text(
                    '€/m² pondéré réel : ${(rounded / _e.surfacePonderee).round()} €/m² '
                    '(annexes : ${(_e.surfacePonderee - _e.surfaceHabitable).toStringAsFixed(1)} m² eq.)',
                    style: const TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic),
                  ),
                ]),
              ],
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
              const CardTitleRow(icon: Icons.tune_rounded, label: 'Ajustements du prix'),
              const Text(
                'Chaque critère ajuste le prix de base à la hausse ou à la baisse. '
                'L\'impact en euros est recalculé en direct.',
                style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D), height: 1.35),
              ),
              const SizedBox(height: 8),
              // Légende couleurs
              Row(children: [
                _AdjLegend(color: kGreen, label: 'Plus-value (+)'),
                const SizedBox(width: 14),
                _AdjLegend(color: kRed, label: 'Décote (−)'),
              ]),
              const SizedBox(height: 14),

              _AdjRow(label: 'Vue dégagée', val: _e.ajustVue, min: 0, max: 8, base: base,
                  note: 'Vue montagne, lac ou panorama valorisant',
                  onChanged: (v) => _update(_e.copyWith(ajustVue: v))),
              _AdjRow(label: 'Rénové / Bon état', val: _e.ajustEtat, min: -5, max: 8, base: base,
                  note: 'Travaux récents (+) ou rafraîchissement à prévoir (−)',
                  onChanged: (v) => _update(_e.copyWith(ajustEtat: v))),
              _AdjRow(
                label: 'Performance énergétique (DPE ${_e.dpeClasse})',
                val: _e.ajustDpe,
                min: -8,
                max: 3,
                base: base,
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
                base: base,
                note: _e.ajustExposition < -2 ? 'exposition défavorable' : _e.ajustExposition > 1 ? 'exposition favorable' : 'exposition neutre',
                recommended: _e.recommendedAjustExposition,
                onChanged: (v) => _update(_e.copyWith(ajustExposition: v)),
                onReset: () => _update(_e.copyWith(ajustExposition: _e.recommendedAjustExposition)),
              ),
              _AdjRow(
                label: 'Environnement / Nuisances',
                val: _e.ajustEnvironnement,
                min: -12,
                max: 0,
                base: base,
                note: _e.ajustEnvironnement <= -9
                    ? 'nuisances sévères (route < 50m ou double source)'
                    : _e.ajustEnvironnement <= -6
                        ? 'nuisances importantes (route < 100m ou voie ferrée)'
                        : _e.ajustEnvironnement <= -3
                            ? 'nuisances modérées (55–65 dB)'
                            : _e.ajustEnvironnement < 0
                                ? 'nuisances légères (< 55 dB)'
                                : 'environnement neutre',
                onChanged: (v) => _update(_e.copyWith(ajustEnvironnement: v)),
              ),
              _AdjRow(
                label: 'Conjoncture marché',
                val: _e.ajustConjoncture,
                min: -8,
                max: 2,
                base: base,
                note: _e.ajustConjoncture <= -5
                    ? 'marché acheteur — forte pression à la baisse'
                    : _e.ajustConjoncture <= -2
                        ? 'marché ralenti — taux élevés, demande en retrait'
                        : _e.ajustConjoncture == 0
                            ? 'marché neutre'
                            : 'marché vendeur — forte demande',
                onChanged: (v) => _update(_e.copyWith(ajustConjoncture: v)),
              ),

              // Prime terrain (lecture seule si calculée automatiquement)
              if (_e.primeTerrain > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withOpacity(0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('PRIME TERRAIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    _PriceDetailRow(
                      'Terrain ${_e.surfaceTerrain} m² (>500 m²) :',
                      '+${_fmt(_e.primeTerrain)}',
                    ),
                    if (_e.terrainConstructibleM2 > 0) ...[
                      _PriceDetailRow('  Constructible :', '${_e.terrainConstructibleM2} m² × 80 €/m²'),
                      _PriceDetailRow('  Non-constructible :', '${_e.surfaceTerrain - 500 - _e.terrainConstructibleM2} m² × 8 €/m²'),
                    ] else
                      _PriceDetailRow('  Zone non précisée :', '${_e.surfaceTerrain - 500} m² × 8 €/m²'),
                  ]),
                ),
                const SizedBox(height: 6),
              ],

              // Décotes automatiques (lecture seule)
              if (!_e.libreOccupation || _e.decoteSurface < 0 || _e.ajustEtageAuto != 0 || _e.decoteCharges < 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('DÉCOTES / BONUS AUTOMATIQUES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7A5800), letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    if (!_e.libreOccupation)
                      _PriceDetailRow('Bien loué (occupation) :', '−12%'),
                    if (_e.decoteSurface < 0)
                      _PriceDetailRow(
                        'Grande surface (${_e.surfaceHabitable} m²) :',
                        '${_e.decoteSurface.toStringAsFixed(1)}%',
                      ),
                    if (_e.ajustEtageAuto != 0)
                      _PriceDetailRow(
                        _e.etage == 0 ? 'Rez-de-chaussée :' : _e.dernierEtage ? 'Dernier étage :' : 'Étage ${_e.etage} :',
                        '${_e.ajustEtageAuto >= 0 ? '+' : ''}${_e.ajustEtageAuto.toStringAsFixed(0)}%',
                      ),
                    if (_e.decoteCharges < 0)
                      _PriceDetailRow(
                        'Charges copro (${_e.chargesCopro} €/an) :',
                        '${_e.decoteCharges.toStringAsFixed(1)}%',
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
              ],

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

            // Calibration locale
            _CalibrationLocaleCard(estimation: _e, onChanged: _update),

            // Historique négociation
            _HistoriqueCard(estimation: _e, onChanged: _update),

            // Simulation crédit acheteur
            _SimulationCreditCard(prixMandat: _e.prixMandat),

            // Auto vigilance
            _AutoVigilanceCard(estimation: _e, onInsert: (text) {
              final cur = _conclusionCtrl.text;
              final updated = cur.isEmpty ? text : '$cur\n$text';
              _conclusionCtrl.text = updated;
              _update(_e.copyWith(conclusion: updated));
            }),

            // Plus-value
            _PlusValueCard(estimation: _e),

            // Documents à réunir
            _DocumentsCard(
              estimation: _e,
              onChanged: (docs) => _update(_e.copyWith(documentsChecked: docs)),
            ),

            // Facturation
            _FactureCard(estimation: _e),

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

/// Petite légende colorée (point + texte) sous le titre des ajustements.
class _AdjLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _AdjLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600)),
      ]);
}

class _AdjRow extends StatelessWidget {
  final String label;
  final double val;
  final double min;
  final double max;
  final String? note;
  final double? recommended;
  final double base; // prix de base, pour afficher l'impact en €
  final VoidCallback? onReset;
  final ValueChanged<double> onChanged;
  const _AdjRow({required this.label, required this.val, required this.min, required this.max, this.note, this.recommended, this.base = 0, this.onReset, required this.onChanged});

  static String _fmtEuro(double n) {
    final s = n.abs().round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    final pct = val.round();
    final impactStr = pct >= 0 ? '+$pct %' : '$pct %';
    final color = pct > 0 ? kGreen : pct < 0 ? kRed : const Color(0xFF95A5A6);
    final euro = base * val / 100;
    final euroStr = euro == 0 ? null : '${euro > 0 ? '+' : '−'}${_fmtEuro(euro)}';
    final showResetHint = recommended != null && (val - recommended!).abs() > 0.4;
    final recPct = recommended?.round() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECEFEC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Titre + badge (% et € côte à côte)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCharcoal)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(impactStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              if (euroStr != null)
                Text(euroStr, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ]),
        // Note descriptive sur toute la largeur
        if (note != null) ...[
          const SizedBox(height: 3),
          Text(note!, style: const TextStyle(fontSize: 10.5, color: Color(0xFF95A5A6))),
        ],
        // Valeur conseillée (cliquable)
        if (showResetHint && onReset != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAmber.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_fix_high_rounded, size: 11, color: kAmber),
                const SizedBox(width: 4),
                Text('Conseillé : ${recPct >= 0 ? '+' : ''}$recPct % — appuyer pour appliquer',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kAmber)),
              ]),
            ),
          ),
        ],
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
        // Bornes min / max
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(min >= 0 ? '+${min.round()} %' : '${min.round()} %',
                style: const TextStyle(fontSize: 9.5, color: kLightGrey)),
            Text(max >= 0 ? '+${max.round()} %' : '${max.round()} %',
                style: const TextStyle(fontSize: 9.5, color: kLightGrey)),
          ]),
        ),
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

    // Nuisances environnement
    if (e.ajustEnvironnement <= -9) {
      points.add((
        text: 'Nuisances sévères (décote ${e.ajustEnvironnement.round()}%) — route < 50m ou double source acoustique. '
            'Marché cible réduit : acquéreurs contraints par le budget ou non-sensibles. '
            'Valoriser impérativement les atouts compensatoires (transports, commerces, luminosité).',
        color: kRed,
        icon: Icons.volume_up_outlined,
      ));
    } else if (e.ajustEnvironnement <= -5) {
      points.add((
        text: 'Nuisances importantes (décote ${e.ajustEnvironnement.round()}%) — évoquer le double vitrage ou mur antibruit comme point de négociation. '
            'Impact sur la rapidité de vente à anticiper.',
        color: kAmber,
        icon: Icons.volume_up_outlined,
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

    // Étage RDC appartement
    if (e.typeId == 'appartement' && e.etage == 0) {
      points.add((
        text: 'Rez-de-chaussée : décote automatique −5% appliquée — sécurité, luminosité et intimité réduite perçue. '
            'Compensez par un jardin privatif ou terrasse si présente.',
        color: kAmber,
        icon: Icons.layers_outlined,
      ));
    }

    // Charges copropriété élevées
    if (e.typeId == 'appartement' && e.chargesCopro > 2000) {
      points.add((
        text: 'Charges copropriété élevées (${e.chargesCopro} €/an soit ~${(e.chargesCopro / 12).round()} €/mois) — '
            'décote ${e.decoteCharges.toStringAsFixed(1)}% appliquée. '
            'Exiger le détail du budget copro et signaler travaux votés avant vente.',
        color: kRed,
        icon: Icons.receipt_long_outlined,
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
    final fraisAgence = e.fraisAgenceEstimes;
    final fraisNotaire = e.fraisNotaireAcquereur;
    final budgetAcquereur = e.budgetTotalAcquereur;

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitleRow(icon: Icons.sell_outlined, label: 'Prix de commercialisation'),
      const SizedBox(height: 4),

      // Net vendeur
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Prix net vendeur estimé', style: TextStyle(fontSize: 12, color: kGrey)),
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
            const Text('PRIX DE MANDAT (FAI)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
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

      const CardDivider(),

      // Section vendeur
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF1565C0)),
            SizedBox(width: 6),
            Text('CÔTÉ VENDEUR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1565C0), letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 8),
          // Taux agence slider
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Honoraires agence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('${e.tauxAgence.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF1565C0),
              inactiveTrackColor: const Color(0xFF1565C0).withOpacity(0.15),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackHeight: 4,
            ),
            child: Slider(
              value: e.tauxAgence,
              min: 2,
              max: 8,
              divisions: 12,
              onChanged: (v) => onChanged(e.copyWith(tauxAgence: v)),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('2%', style: TextStyle(fontSize: 10, color: kLightGrey)),
            const Text('5%', style: TextStyle(fontSize: 10, color: kLightGrey)),
            const Text('8%', style: TextStyle(fontSize: 10, color: kLightGrey)),
          ]),
          const SizedBox(height: 10),
          _PriceDetailRow('Prix mandat (FAI) :', _fmt(mandat)),
          _PriceDetailRow('Honoraires agence (~${e.tauxAgence.toStringAsFixed(1)}%) :', '−${_fmt(fraisAgence)}'),
          const Divider(height: 12),
          _PriceDetailRow('Net vendeur après frais :', _fmt(mandat - fraisAgence), bold: true),
        ]),
      ),
      const SizedBox(height: 10),

      // Section acquéreur
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAmber.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.group_outlined, size: 14, color: kAmber),
            SizedBox(width: 6),
            Text('CÔTÉ ACQUÉREUR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kAmber, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 8),
          _PriceDetailRow('Prix de vente (FAI) :', _fmt(mandat)),
          _PriceDetailRow('Frais de notaire (~8%) :', '+${_fmt(fraisNotaire)}'),
          const Divider(height: 12),
          _PriceDetailRow('Budget total acquéreur :', _fmt(budgetAcquereur), bold: true),
          const SizedBox(height: 4),
          const Text('Frais notaire sur bien ancien · Hors frais bancaires', style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
        ]),
      ),
    ]));
  }
}

class _HistoriqueCard extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  const _HistoriqueCard({required this.estimation, required this.onChanged});

  @override
  State<_HistoriqueCard> createState() => _HistoriqueCardState();
}

class _HistoriqueCardState extends State<_HistoriqueCard> {
  bool _open = false;

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2,'0')}h${d.minute.toString().padLeft(2,'0')}';
  }

  void _snapshot() {
    final e = widget.estimation;
    final entry = {
      'date': DateTime.now().toIso8601String(),
      'prixNet': e.prixCalcule,
      'prixMandat': e.prixMandat,
      'marge': e.margeNegociation,
    };
    final newHistorique = [...e.historique, entry];
    widget.onChanged(e.copyWith(historique: newHistorique));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estimation;
    final entries = e.historique.reversed.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              const Icon(Icons.history_rounded, size: 17, color: kGrey),
              const SizedBox(width: 8),
              const Text('Historique des prix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              const SizedBox(width: 8),
              if (entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
                  child: Text('${entries.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGrey)),
                ),
              const Spacer(),
              GestureDetector(
                onTap: _snapshot,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Snapshot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen)),
                ),
              ),
              const SizedBox(width: 8),
              Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kLightGrey, size: 18),
            ]),
          ),
        ),
        if (_open) ...[
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Appuyez sur "Snapshot" pour enregistrer l\'estimation actuelle.',
                  style: TextStyle(fontSize: 12, color: kLightGrey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
              itemBuilder: (_, i) {
                final entry = entries[i];
                final prixNet = (entry['prixNet'] as num?)?.toDouble() ?? 0;
                final prixMandat = (entry['prixMandat'] as num?)?.toDouble() ?? 0;
                final marge = (entry['marge'] as num?)?.toDouble() ?? 0;
                final isFirst = i == 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(children: [
                    Column(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: isFirst ? kGreen : const Color(0xFFBDBDBD),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < entries.length - 1)
                        Container(width: 1.5, height: 32, color: const Color(0xFFE0E0E0)),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_fmtDate(entry['date'] as String? ?? ''),
                          style: const TextStyle(fontSize: 10, color: kLightGrey)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('Net vendeur : ${_fmt(prixNet)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: isFirst ? kGreen : kCharcoal)),
                        const SizedBox(width: 8),
                        Text('Mandat : ${_fmt(prixMandat)}',
                            style: const TextStyle(fontSize: 11, color: kGrey)),
                      ]),
                      Text('Marge négociation : ${marge.toInt()}%',
                          style: const TextStyle(fontSize: 10, color: kLightGrey)),
                    ])),
                  ]),
                );
              },
            ),
        ],
      ]),
    );
  }
}

// ── Simulation crédit acheteur ──────────────────────────────────
class _SimulationCreditCard extends StatefulWidget {
  final double prixMandat;
  const _SimulationCreditCard({required this.prixMandat});

  @override
  State<_SimulationCreditCard> createState() => _SimulationCreditCardState();
}

class _SimulationCreditCardState extends State<_SimulationCreditCard> {
  bool _open = false;
  double _revenus = 3500;
  late double _apport;
  int _duree = 20;
  double _taux = 3.7;

  static const _durees = [10, 15, 20, 25];

  @override
  void initState() {
    super.initState();
    _apport = _defaultApport;
  }

  @override
  void didUpdateWidget(_SimulationCreditCard old) {
    super.didUpdateWidget(old);
    // Si le prix de mandat change, recalibrer l'apport par défaut (sauf si user a déjà choisi)
    if (old.prixMandat != widget.prixMandat && _apport == _defaultApportFor(old.prixMandat)) {
      _apport = _defaultApport;
    }
  }

  // Apport par défaut : 20% du prix de mandat (médiane primo-accédant 2025 = 22.7%)
  double _defaultApportFor(double prix) {
    if (prix <= 0) return 30000;
    return ((prix * 0.20) / 5000).round() * 5000;
  }

  double get _defaultApport => _defaultApportFor(widget.prixMandat);

  // Maximum apport sur le slider : 60% du prix (rares cas d'apport très élevé)
  double get _apportMax {
    if (widget.prixMandat <= 0) return 200000;
    return ((widget.prixMandat * 0.60) / 10000).ceil() * 10000;
  }

  // Apport minimum conseillé : couvre les frais de notaire (banque finance pas les frais)
  double get _apportMin => _fraisNotaire;

  // % apport / prix mandat
  double get _apportPct => widget.prixMandat > 0 ? (_apport / widget.prixMandat * 100) : 0;

  // Capacité bancaire (35% des revenus = règle HCSF)
  double get _mensualiteMax => _revenus * 0.35;

  // Frais de notaire ancien 2026 : ~8% (DMTO majoré 74 + émoluments + débours)
  double get _fraisNotaire => widget.prixMandat * 0.08;
  // Coût total acquéreur = prix + frais notaire (ce que la banque évalue)
  double get _coutTotal => widget.prixMandat + _fraisNotaire;

  // Mensualité réelle si on finance (coutTotal - apport) sur _duree ans
  double get _mensualiteRequise {
    final montant = (_coutTotal - _apport).clamp(0, double.infinity);
    if (montant == 0) return 0;
    final r = _taux / 100 / 12;
    final n = _duree * 12;
    if (r == 0) return montant / n;
    return montant * r / (1 - pow(1 + r, -n.toDouble()));
  }

  // Capacité d'emprunt basée sur ce que la banque accepte (35% revenus)
  double get _capaciteEmprunt {
    final r = _taux / 100 / 12;
    final n = _duree * 12;
    if (r == 0) return _mensualiteMax * n;
    return _mensualiteMax * (1 - pow(1 + r, -n.toDouble())) / r;
  }

  double get _budgetTotal => _capaciteEmprunt + _apport;
  double get _gap => _coutTotal - _budgetTotal;
  // Vrai critère : la mensualité requise dépasse-t-elle le max autorisé ?
  bool get _accessible => _mensualiteRequise <= _mensualiteMax && _budgetTotal >= _coutTotal;

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  double pow(double base, double exp) {
    if (exp == 0) return 1;
    double result = 1;
    for (int i = 0; i < exp.abs().round(); i++) {
      result *= base;
    }
    return exp < 0 ? 1 / result : result;
  }

  Widget _profilChip(String label, double pct) {
    final target = (widget.prixMandat * pct / 5000).round() * 5000.0;
    final selected = (_apport - target).abs() < 100;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _apport = target.clamp(0, _apportMax)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? kGreen : kBorderColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : kGrey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessible = _accessible;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              const Icon(Icons.calculate_outlined, size: 17, color: kGrey),
              const SizedBox(width: 8),
              const Text('Simulation crédit acquéreur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (accessible ? kGreen : kRed).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  accessible ? 'Accessible' : 'Hors budget',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accessible ? kGreen : kRed),
                ),
              ),
              const SizedBox(width: 8),
              Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kLightGrey, size: 18),
            ]),
          ),
        ),
        if (_open) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Profil acquéreur type · Taux d\'effort max 35%',
                  style: TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 14),

              // Revenus slider
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Revenus ménage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                Text('${_revenus.round()} €/mois', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
              ]),
              Slider(
                value: _revenus,
                min: 1500,
                max: 12000,
                divisions: 85,
                activeColor: kGreen,
                inactiveColor: kGreen.withOpacity(0.15),
                onChanged: (v) => setState(() => _revenus = (v / 100).round() * 100),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('1 500 €', style: TextStyle(fontSize: 10, color: kLightGrey)),
                Text('Capacité max : ${_mensualiteMax.round()} €/mois', style: const TextStyle(fontSize: 10, color: kGrey)),
                const Text('12 000 €', style: TextStyle(fontSize: 10, color: kLightGrey)),
              ]),
              const SizedBox(height: 12),

              // Presets apport selon profil acquéreur typique
              if (widget.prixMandat > 0) ...[
                Row(children: [
                  const Text('Profil :', style: TextStyle(fontSize: 11, color: kGrey)),
                  const SizedBox(width: 8),
                  _profilChip('Primo 15%', 0.15),
                  const SizedBox(width: 6),
                  _profilChip('Secondo 25%', 0.25),
                  const SizedBox(width: 6),
                  _profilChip('Frontalier 40%', 0.40),
                ]),
                const SizedBox(height: 8),
              ],

              // Apport slider — calibré sur le prix de mandat
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Apport personnel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                Row(children: [
                  Text(_fmt(_apport), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  if (widget.prixMandat > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _apport < _apportMin ? kRed.withOpacity(0.12) : kGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_apportPct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: _apport < _apportMin ? kRed : kGreen)),
                    ),
                  ],
                ]),
              ]),
              Slider(
                value: _apport.clamp(0, _apportMax),
                min: 0,
                max: _apportMax,
                divisions: (_apportMax / 5000).round().clamp(20, 100),
                activeColor: kGreen,
                inactiveColor: kGreen.withOpacity(0.15),
                onChanged: (v) => setState(() => _apport = (v / 5000).round() * 5000),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('0 €', style: TextStyle(fontSize: 10, color: kLightGrey)),
                if (widget.prixMandat > 0)
                  Text('Mini frais notaire : ${_fmt(_apportMin)}',
                      style: TextStyle(fontSize: 10,
                          color: _apport < _apportMin ? kRed : kGrey,
                          fontWeight: _apport < _apportMin ? FontWeight.w700 : FontWeight.w400)),
                Text(_fmt(_apportMax), style: const TextStyle(fontSize: 10, color: kLightGrey)),
              ]),
              const SizedBox(height: 12),

              // Durée chips
              Row(children: [
                const Text('Durée : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                const SizedBox(width: 8),
                ..._durees.map((d) {
                  final sel = _duree == d;
                  return GestureDetector(
                    onTap: () => setState(() => _duree = d),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? kGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? kGreen : kBorderColor, width: 1.5),
                      ),
                      child: Text('${d} ans', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : kGrey)),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 10),

              // Taux slider
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Taux estimé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal)),
                Text('${_taux.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
              ]),
              Slider(
                value: _taux,
                min: 2.0,
                max: 6.0,
                divisions: 16,
                activeColor: kGrey,
                inactiveColor: kGrey.withOpacity(0.15),
                onChanged: (v) => setState(() => _taux = (v * 4).round() / 4),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('2%', style: TextStyle(fontSize: 10, color: kLightGrey)),
                const Text('Taux marché 2025 : ~3.5–4%', style: TextStyle(fontSize: 10, color: kGrey)),
                const Text('6%', style: TextStyle(fontSize: 10, color: kLightGrey)),
              ]),
              const SizedBox(height: 14),

              // Résultat
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accessible ? kGreen.withOpacity(0.06) : kRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (accessible ? kGreen : kRed).withOpacity(0.25)),
                ),
                child: Column(children: [
                  // Mensualité requise vs mensualité max — la comparaison clé
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text(
                          '${_mensualiteRequise.round()} €/mois',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _mensualiteRequise > _mensualiteMax ? kRed : kCharcoal),
                        ),
                        const SizedBox(height: 2),
                        const Text('Mensualité pour ce bien', style: TextStyle(fontSize: 9, color: kGrey), textAlign: TextAlign.center),
                      ])),
                      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text(
                          '${_mensualiteMax.round()} €/mois',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kGreen),
                        ),
                        const SizedBox(height: 2),
                        const Text('Capacité max (35% revenus)', style: TextStyle(fontSize: 9, color: kGrey), textAlign: TextAlign.center),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Prix de mandat :', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmt(widget.prixMandat), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Frais de notaire (~8%) :', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmt(_fraisNotaire), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Coût total acquéreur :', style: TextStyle(fontSize: 12, color: kGrey, fontWeight: FontWeight.w600)),
                    Text(_fmt(_coutTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kCharcoal)),
                  ]),
                  const Divider(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Montant emprunté :', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmt((_coutTotal - _apport).clamp(0, double.infinity)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Capacité d\'emprunt :', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmt(_capaciteEmprunt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Apport :', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmt(_apport), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                  ]),
                  const Divider(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Budget total acquéreur :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                    Text(_fmt(_budgetTotal), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accessible ? kGreen : kRed)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: (accessible ? kGreen : kRed).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(accessible ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 14, color: accessible ? kGreen : kRed),
                      const SizedBox(width: 6),
                      Text(
                        accessible
                            ? 'Accessible · budget excédentaire ${_fmt(-_gap)}'
                            : _mensualiteRequise > _mensualiteMax
                                ? 'Mensualité trop élevée · ${_fmt(_mensualiteRequise - _mensualiteMax)} de plus que la capacité'
                                : 'Budget insuffisant · déficit ${_fmt(_gap)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accessible ? kGreen : kRed),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              const Text('Simulation indicative · hors assurance et frais bancaires', style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Calibration locale (Ma base) ────────────────────────────────
class _CalibrationLocaleCard extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  const _CalibrationLocaleCard({required this.estimation, required this.onChanged});

  @override
  State<_CalibrationLocaleCard> createState() => _CalibrationLocaleCardState();
}

class _CalibrationLocaleCardState extends State<_CalibrationLocaleCard> {
  Map<String, dynamic>? _calib;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CalibrationLocaleCard old) {
    super.didUpdateWidget(old);
    if (old.estimation.codeInsee != widget.estimation.codeInsee) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await BaseLocaleService().getCalibration(widget.estimation.codeInsee);
    if (mounted) setState(() { _calib = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final count = _calib?['count'] as int? ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final countWithEstime = _calib?['countWithEstime'] as int? ?? 0;
    final ecartMoyen = (_calib?['ecartMoyen'] as num?)?.toDouble() ?? 0.0;
    final prixM2Moyen = (_calib?['prixM2Moyen'] as num?)?.toDouble() ?? 0.0;
    final hasCalib = countWithEstime > 0 && ecartMoyen.abs() > 0.5;

    final calibColor = ecartMoyen > 3
        ? kRed
        : ecartMoyen < -3
            ? kGreen
            : kAmber;

    // Suggestion d'ajustement conjoncture basée sur l'écart moyen
    final suggestedDelta = -ecartMoyen.clamp(-4.0, 4.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: const Color(0xFF7B1FA2), width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bookmark_rounded, size: 16, color: Color(0xFF7B1FA2)),
          const SizedBox(width: 8),
          const Text('Calibration — Ma base locale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('$count vente${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7B1FA2))),
          ),
        ]),
        const SizedBox(height: 12),

        // Stats
        Row(children: [
          if (prixM2Moyen > 0) ...[
            Expanded(child: _CalibStat(label: 'Prix m² moyen\n(mes ventes)', value: '${prixM2Moyen.round()} €/m²', color: const Color(0xFF7B1FA2))),
            const SizedBox(width: 8),
          ],
          if (hasCalib)
            Expanded(child: _CalibStat(
              label: 'Écart estimé/vendu\n($countWithEstime vente${countWithEstime > 1 ? 's' : ''})',
              value: '${ecartMoyen >= 0 ? '+' : ''}${ecartMoyen.toStringAsFixed(1)}%',
              color: calibColor,
            )),
        ]),

        if (hasCalib) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: calibColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: calibColor.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                  ecartMoyen > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14, color: calibColor,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  ecartMoyen > 3
                      ? 'Tendance : vos estimations sont en dessous du marché réel sur ce secteur.'
                      : ecartMoyen < -3
                          ? 'Tendance : vos estimations sont au-dessus du marché réel sur ce secteur.'
                          : 'Estimations calibrées — écart moyen faible sur ce secteur.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: calibColor),
                )),
              ]),
              if (ecartMoyen.abs() > 2) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(
                    'Ajustement suggéré sur la conjoncture : '
                    '${suggestedDelta >= 0 ? '+' : ''}${suggestedDelta.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: calibColor),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final newConj = (widget.estimation.ajustConjoncture + suggestedDelta).clamp(-8.0, 2.0);
                      widget.onChanged(widget.estimation.copyWith(ajustConjoncture: newConj));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: calibColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Appliquer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Basé sur vos ${count} vente${count > 1 ? 's' : ''} enregistrées · ${widget.estimation.commune.isNotEmpty ? widget.estimation.commune : 'ce secteur'}',
          style: const TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }
}

class _CalibStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CalibStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: kGrey, height: 1.4)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

// ── Plus-value ────────────────────────────────────────────────────────────────

class _PlusValueCard extends StatelessWidget {
  final Estimation estimation;
  const _PlusValueCard({required this.estimation});

  // Abattement IR : 6%/an de 6 à 21 ans, 4% à 22 ans, total à 22 ans
  double _abattIR(int ans) {
    if (ans <= 5) return 0;
    if (ans <= 21) return (ans - 5) * 6.0;
    if (ans == 22) return 16 * 6 + 4.0; // 96 + 4 = 100
    return 100;
  }

  // Abattement PS : 1.65%/an de 6 à 21 ans, 1.60% à 22 ans, 9%/an de 23 à 30 ans
  double _abattPS(int ans) {
    if (ans <= 5) return 0;
    if (ans <= 21) return (ans - 5) * 1.65;
    if (ans == 22) return 16 * 1.65 + 1.60; // 26.4 + 1.60 = 28
    if (ans <= 30) return 16 * 1.65 + 1.60 + (ans - 22) * 9.0;
    return 100;
  }

  // Surtaxe PV > 50 000 € — barème article 1609 nonies G CGI
  // Calcul sur la PV imposable à l'IR (après abattement durée de détention)
  double _surtaxe(double pv) {
    if (pv <= 50000) return 0;
    if (pv <= 60000) return 0.02 * pv - (60000 - pv) * 1 / 20;
    if (pv <= 100000) return 0.02 * pv;
    if (pv <= 110000) return 0.03 * pv - (110000 - pv) * 1 / 10;
    if (pv <= 150000) return 0.03 * pv;
    if (pv <= 160000) return 0.04 * pv - (160000 - pv) * 15 / 100;
    if (pv <= 200000) return 0.04 * pv;
    if (pv <= 210000) return 0.05 * pv - (210000 - pv) * 20 / 100;
    if (pv <= 250000) return 0.05 * pv;
    if (pv <= 260000) return 0.06 * pv - (260000 - pv) * 25 / 100;
    return 0.06 * pv;
  }

  @override
  Widget build(BuildContext context) {
    final e = estimation;
    // Ne pas afficher si résidence principale (exonéré) ou données manquantes
    if (e.residencePrincipale) {
      return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitleRow(icon: Icons.account_balance_outlined, label: 'Plus-value'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, color: kGreen, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Résidence principale — exonération totale de plus-value.',
                style: TextStyle(fontSize: 13, color: kGreen, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]));
    }

    if (e.prixAchat == 0 || e.anneeAchat == 0 || e.prixFinal == 0) {
      return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitleRow(icon: Icons.account_balance_outlined, label: 'Plus-value'),
        const Text('Renseignez le prix d\'achat et l\'année d\'acquisition (Section 1) pour calculer la plus-value.',
            style: TextStyle(fontSize: 12, color: kGrey, fontStyle: FontStyle.italic)),
      ]));
    }

    final annee = DateTime.now().year;
    final ans = (annee - e.anneeAchat).clamp(0, 50);
    final fraisAcq = (e.prixAchat * 0.075).round(); // forfait frais d'acquisition 7.5%
    // Forfait travaux 15% : article 150 VB II 4° CGI, applicable si détention > 5 ans
    final forfaitTravaux = ans > 5 ? (e.prixAchat * 0.15).round() : 0;
    final prixRevientNet = e.prixAchat + fraisAcq + forfaitTravaux;
    final pvBrute = (e.prixFinal - prixRevientNet).toDouble();

    if (pvBrute <= 0) {
      return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitleRow(icon: Icons.account_balance_outlined, label: 'Plus-value'),
        const Text('Moins-value — aucune imposition.',
            style: TextStyle(fontSize: 13, color: kGrey)),
      ]));
    }

    final abIR = _abattIR(ans).clamp(0.0, 100.0);
    final abPS = _abattPS(ans).clamp(0.0, 100.0);
    final pvImposIR = pvBrute * (1 - abIR / 100);
    final pvImposPS = pvBrute * (1 - abPS / 100);
    final impotIR = pvImposIR * 0.19;
    final impotPS = pvImposPS * 0.172;
    // Surtaxe sur PV imposable IR > 50 000 € (résidence secondaire, hors terrain à bâtir)
    final surtaxe = _surtaxe(pvImposIR);
    final totalImpot = impotIR + impotPS + surtaxe;

    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';

    final exonereIR = abIR >= 100;
    final exonerePS = abPS >= 100;
    final exonereTotale = exonereIR && exonerePS;

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitleRow(icon: Icons.account_balance_outlined, label: 'Plus-value estimée'),
      const SizedBox(height: 4),
      Text('Résidence secondaire · $ans ans de détention', style: const TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic)),
      const SizedBox(height: 12),
      _pvRow('Prix d\'acquisition', fmt(e.prixAchat.toDouble())),
      _pvRow('Frais d\'acquisition forfaitaires (7,5%)', '+${fmt(fraisAcq.toDouble())}'),
      if (forfaitTravaux > 0)
        _pvRow('Forfait travaux (15%, détention >5 ans)', '+${fmt(forfaitTravaux.toDouble())}'),
      _pvRow('Prix de revient net', fmt(prixRevientNet.toDouble()), bold: true),
      _pvRow('Prix de vente estimé', fmt(e.prixFinal)),
      const Divider(height: 16),
      _pvRow('Plus-value brute', fmt(pvBrute), bold: true, color: const Color(0xFFE67E22)),
      if (!exonereIR) _pvRow('Abattement IR (${abIR.toStringAsFixed(0)}%)', '−${fmt(pvBrute * abIR / 100)}'),
      if (!exonerePS) _pvRow('Abattement PS (${abPS.toStringAsFixed(0)}%)', '−${fmt(pvBrute * abPS / 100)}'),
      const SizedBox(height: 8),
      if (exonereTotale)
        _alertBox(kGreen, Icons.check_circle_outline, 'Exonération totale — ${ans} ans de détention.')
      else ...[
        if (!exonereIR) _pvRow('Impôt sur le revenu (19%)', fmt(impotIR), color: kRed),
        if (!exonerePS) _pvRow('Prélèvements sociaux (17,2%)', fmt(impotPS), color: kRed),
        if (surtaxe > 0) _pvRow('Surtaxe PV > 50 K€ (2-6%)', fmt(surtaxe), color: kRed),
        _pvRow('Imposition totale estimée', fmt(totalImpot), bold: true, color: kRed),
        const SizedBox(height: 8),
        _alertBox(
          exonereIR ? kGreen : const Color(0xFFE67E22),
          Icons.info_outline,
          exonereIR
              ? 'Exonéré d\'IR. Prélèvements sociaux jusqu\'à ${30 - ans} ans de détention supplémentaires.'
              : 'Exonération IR à ${22 - ans} ans, totale à ${30 - ans} ans. Conseiller un notaire.',
        ),
      ],
    ]));
  }

  Widget _pvRow(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12, color: kGrey, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? kCharcoal)),
        ]),
      );

  Widget _alertBox(Color color, IconData icon, String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}

// ── Documents à réunir ────────────────────────────────────────────────────────

List<Map<String, String>> requiredDocs(Estimation e) {
  final docs = <Map<String, String>>[];

  // Toujours obligatoires
  docs.addAll([
    {'id': 'titre_propriete',    'label': 'Titre de propriété (acte notarié)'},
    {'id': 'identite',           'label': 'Pièce(s) d\'identité du/des vendeur(s)'},
    {'id': 'situation_familiale','label': 'Justificatif situation familiale (livret de famille, jugement…)'},
    {'id': 'taxe_fonciere',      'label': 'Dernier avis de taxe foncière'},
    {'id': 'diagnostics',        'label': 'Dossier de diagnostics techniques (DPE…)'},
  ]);

  // Appartement — copropriété
  if (e.typeId == 'appartement') {
    docs.addAll([
      {'id': 'reglement_copro',  'label': 'Règlement de copropriété + état descriptif de division'},
      {'id': 'pv_ag',            'label': '3 derniers PV d\'Assemblée Générale'},
      {'id': 'carnet_entretien', 'label': 'Carnet d\'entretien de l\'immeuble'},
      {'id': 'fiche_synth',      'label': 'Fiche synthétique de la copropriété'},
      {'id': 'etat_date',        'label': 'État daté syndic (à demander avant compromis)'},
    ]);
  }

  // Maison / Chalet
  if (e.typeId == 'maison' || e.typeId == 'chalet') {
    docs.add({'id': 'plans', 'label': 'Plans du bien (si disponibles)'});
    if (e.anneeConstruction == '2010-2020' || e.anneeConstruction == 'Après 2020') {
      docs.add({'id': 'permis', 'label': 'Permis de construire + déclaration d\'achèvement'});
    }
  }

  // Piscine
  if (e.annexesActives['piscine'] == true) {
    docs.add({'id': 'piscine_conf', 'label': 'Attestation de conformité piscine'});
  }

  // Bien loué
  if (!e.libreOccupation) {
    docs.add({'id': 'bail', 'label': 'Bail en cours + 3 dernières quittances de loyer'});
  }

  // Hypothèque
  docs.add({'id': 'etat_hypo', 'label': 'Mainlevée ou état hypothécaire (si prêt en cours)'});

  return docs;
}

class _DocumentsCard extends StatelessWidget {
  final Estimation estimation;
  final ValueChanged<Map<String, bool>> onChanged;
  const _DocumentsCard({required this.estimation, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final docs = requiredDocs(estimation);
    final checked = estimation.documentsChecked;
    final nbOk = docs.where((d) => checked[d['id']] == true).length;

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const CardTitleRow(icon: Icons.checklist_rounded, label: 'Documents à réunir'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: nbOk == docs.length ? kGreen.withValues(alpha: 0.12) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$nbOk / ${docs.length}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: nbOk == docs.length ? kGreen : const Color(0xFFE67E22)),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Adapté à ce bien — cochez les documents collectés', style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
      const SizedBox(height: 10),
      ...docs.asMap().entries.map((entry) {
        final i = entry.key;
        final doc = entry.value;
        final id = doc['id']!;
        final isChecked = checked[id] == true;
        return Column(children: [
          if (i > 0) const Divider(height: 1, indent: 44),
          InkWell(
            onTap: () {
              final updated = Map<String, bool>.from(checked);
              updated[id] = !isChecked;
              onChanged(updated);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isChecked ? kGreen : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isChecked ? kGreen : kBorderColor, width: 1.5),
                  ),
                  child: isChecked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  doc['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isChecked ? kGrey : kCharcoal,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                )),
              ]),
            ),
          ),
        ]);
      }),
    ]));
  }
}

// ── Facturation ───────────────────────────────────────────────────────────────

class _FactureCard extends StatefulWidget {
  final Estimation estimation;
  const _FactureCard({required this.estimation});

  @override
  State<_FactureCard> createState() => _FactureCardState();
}

class _FactureCardState extends State<_FactureCard> {
  final _svc = FactureService();
  Facture? _facture;
  bool _loading = true;
  bool _generating = false;
  double _montantTtc = 200.0;
  final _customCtrl = TextEditingController();
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final f = await _svc.forEstimation(widget.estimation.id);
    if (mounted) setState(() { _facture = f; _loading = false; });
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final e = widget.estimation;
      final adresseParts = e.adresseComplete.split(',');
      final f = await _svc.create(
        estimationId: e.id,
        clientNom: e.proprietaireNom.isNotEmpty ? e.proprietaireNom : 'Client',
        clientAdresse: adresseParts.isNotEmpty ? adresseParts[0].trim() : e.adresseComplete,
        clientVille: adresseParts.length > 1 ? adresseParts.sublist(1).join(',').trim() : '',
        montantTtc: _montantTtc,
      );
      if (mounted) setState(() { _facture = f; _generating = false; });
      await _svc.openOrShare(f);
    } catch (ex) {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _markPaid() async {
    if (_facture == null) return;
    final updated = _facture!.copyWith(statut: 'payee');
    await _svc.save(updated);
    if (mounted) setState(() => _facture = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitleRow(icon: Icons.receipt_long_outlined, label: 'Facturation'),

      if (_facture != null) ...[
        // Facture existante
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _facture!.statut == 'payee'
                ? kGreen.withOpacity(0.08)
                : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _facture!.statut == 'payee' ? kGreen : const Color(0xFFFFB300),
              width: 1.5,
            ),
          ),
          child: Row(children: [
            Icon(
              _facture!.statut == 'payee' ? Icons.check_circle : Icons.schedule,
              color: _facture!.statut == 'payee' ? kGreen : const Color(0xFFFFB300),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Facture n° ${_facture!.numero}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              Text(
                '${_fmtMontant(_facture!.montantTtc)} TTC · '
                '${_facture!.statut == 'payee' ? 'Payée' : 'En attente'}',
                style: TextStyle(
                  fontSize: 11,
                  color: _facture!.statut == 'payee' ? kGreen : const Color(0xFFE65100),
                ),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _generating ? null : () => _svc.openOrShare(_facture!),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Voir / Partager'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                side: const BorderSide(color: kGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          if (_facture!.statut != 'payee') ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _markPaid,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Marquer payée'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ]),
      ] else ...[
        // Sélection du montant
        const FieldLabel('Montant TTC'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in [150.0, 200.0, 250.0, 300.0])
            GestureDetector(
              onTap: () => setState(() { _montantTtc = m; _showCustom = false; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _montantTtc == m && !_showCustom ? kGreen : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _montantTtc == m && !_showCustom ? kGreen : kBorderColor,
                    width: 1.5,
                  ),
                ),
                child: Text('${m.toInt()} €',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _montantTtc == m && !_showCustom ? Colors.white : kGrey,
                    )),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _showCustom = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _showCustom ? kGreen : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _showCustom ? kGreen : kBorderColor, width: 1.5),
              ),
              child: Text('Autre', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _showCustom ? Colors.white : kGrey,
              )),
            ),
          ),
        ]),
        if (_showCustom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Montant TTC en €',
              hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
              suffixText: '€',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed > 0) setState(() => _montantTtc = parsed);
            },
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long, size: 18),
            label: Text(_generating ? 'Génération...' : 'Générer la facture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'HT : ${_fmtMontant(_montantTtc / 1.20)} · TVA 20% : ${_fmtMontant(_montantTtc / 1.20 * 0.20)} · TTC : ${_fmtMontant(_montantTtc)}',
          style: const TextStyle(fontSize: 11, color: kLightGrey),
          textAlign: TextAlign.center,
        ),
      ],
    ]));
  }

  String _fmtMontant(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final euros = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$euros,${parts[1]} €';
  }
}
