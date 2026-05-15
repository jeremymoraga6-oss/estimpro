import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/mes_notes.dart';
import '../widgets/star_rating.dart';

class _ScoreBadge extends StatelessWidget {
  final double score;
  final double coeff;
  final String label;
  const _ScoreBadge({required this.score, required this.coeff, required this.label});

  @override
  Widget build(BuildContext context) {
    final positive = coeff >= 0;
    final color = coeff > 0 ? kGreen : coeff < 0 ? kRed : kGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Score pondéré : ${score.toStringAsFixed(1)}/4', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontStyle: FontStyle.italic)),
        ]),
        Text('${positive ? '+' : ''}${coeff.toInt()}%',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class Section2Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const Section2Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev});

  @override
  State<Section2Screen> createState() => _Section2ScreenState();
}

class _Section2ScreenState extends State<Section2Screen> {
  late Estimation _e;
  late TextEditingController _surfCtrl;
  late TextEditingController _terrCtrl;
  late TextEditingController _balconCtrl;
  late TextEditingController _caveCtrl;
  late TextEditingController _terrasseCtrl;

  final _annees = ['Avant 1900', '1900-1950', '1950-1980', '1980-2000', '2000-2010', '2010-2020', 'Après 2020'];
  final _chauffages = ['Gaz naturel', 'Électrique', 'Pompe à chaleur', 'Fioul', 'Bois / Pellets', 'Géothermie'];
  final _vueOptions = ['Montagne', 'Dégagée', 'Jardin', 'Rue', 'Cour'];
  final _solOptions = ['Parquet', 'Carrelage', 'Tomettes', 'Béton ciré', 'Moquette'];
  final _orientations = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO', 'Traversant'];

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _surfCtrl = TextEditingController(text: _e.surfaceHabitable > 0 ? _e.surfaceHabitable.toString() : '');
    _terrCtrl = TextEditingController(text: _e.surfaceTerrain > 0 ? _e.surfaceTerrain.toString() : '');
    _balconCtrl = TextEditingController(text: _e.surfaceBalcon > 0 ? _e.surfaceBalcon.toString() : '');
    _caveCtrl = TextEditingController(text: _e.surfaceCave > 0 ? _e.surfaceCave.toString() : '');
    _terrasseCtrl = TextEditingController(text: _e.surfaceTerrasse > 0 ? _e.surfaceTerrasse.toString() : '');
  }

  @override
  void dispose() { _surfCtrl.dispose(); _terrCtrl.dispose(); _balconCtrl.dispose(); _caveCtrl.dispose(); _terrasseCtrl.dispose(); super.dispose(); }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'Description du bien', reference: _e.reference, step: 2, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Surfaces
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.straighten_rounded, label: 'Surfaces'),

              _SurfaceField(
                label: 'Surface habitable',
                controller: _surfCtrl,
                onChanged: (v) => _update(_e.copyWith(surfaceHabitable: v)),
              ),
              const SizedBox(height: 12),
              _SurfaceField(
                label: 'Surface terrain',
                controller: _terrCtrl,
                onChanged: (v) => _update(_e.copyWith(surfaceTerrain: v)),
                hint: '0 si appartement',
              ),
              if (_e.typeId != 'appartement' && _e.surfaceTerrain > 500) ...[
                const SizedBox(height: 10),
                _TerrainConstructibleWidget(
                  estimation: _e,
                  onChanged: _update,
                ),
              ],
              const CardDivider(),

              // Surfaces annexes pondérées
              const FieldLabel('Surfaces annexes'),
              const SizedBox(height: 4),
              const Text('Balcon ×50%  ·  Cave ×20%  ·  Terrasse ×30%',
                  style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _AnnexeField(label: 'Balcon', controller: _balconCtrl,
                    onChanged: (v) => _update(_e.copyWith(surfaceBalcon: v)))),
                const SizedBox(width: 8),
                Expanded(child: _AnnexeField(label: 'Cave', controller: _caveCtrl,
                    onChanged: (v) => _update(_e.copyWith(surfaceCave: v)))),
                const SizedBox(width: 8),
                Expanded(child: _AnnexeField(label: 'Terrasse', controller: _terrasseCtrl,
                    onChanged: (v) => _update(_e.copyWith(surfaceTerrasse: v)))),
              ]),
              if (_e.surfacePonderee > _e.surfaceHabitable) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGreen.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, size: 14, color: kGreen),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Surface pondérée : ${_e.surfacePonderee.toStringAsFixed(1)} m²'
                      '  ·  +${(_e.surfacePonderee - _e.surfaceHabitable).toStringAsFixed(1)} m² équivalent',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen),
                    )),
                  ]),
                ),
              ],
              const CardDivider(),
              Row(children: [
                Expanded(child: StepperField(label: 'Pièces', value: _e.pieces, onChange: (v) => _update(_e.copyWith(pieces: v)))),
                const SizedBox(width: 10),
                Expanded(child: StepperField(label: 'Chambres', value: _e.chambres, onChange: (v) => _update(_e.copyWith(chambres: v)))),
              ]),

              MesNotes(sectionKey: 'section2', initialData: _e.notes['section2'] ?? {}, onChanged: (data) {
                final n = Map<String, Map<String, dynamic>>.from(_e.notes); n['section2'] = data;
                _update(_e.copyWith(notes: n));
              }),
            ])),

            // Construction
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.business_outlined, label: 'Construction'),

              DropdownField(label: 'Année de construction', value: _e.anneeConstruction, items: _annees,
                  onChanged: (v) => _update(_e.copyWith(anneeConstruction: v))),
              const SizedBox(height: 12),

              const FieldLabel('État général'),
              const SizedBox(height: 6),
              EtatSelector(selected: _e.etatGeneral, onSelect: (v) => _update(_e.copyWith(etatGeneral: v))),
              const CardDivider(),

              const FieldLabel('Orientation'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _orientations.map((o) {
                  final sel = _e.orientations.contains(o);
                  return GestureDetector(
                    onTap: () {
                      final list = List<String>.from(_e.orientations);
                      sel ? list.remove(o) : list.add(o);
                      _update(_e.copyWith(orientations: list));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? kGreen : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: sel ? kGreen : kBorderColor, width: 1.5),
                      ),
                      child: Text(o, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : kGrey)),
                    ),
                  );
                }).toList(),
              ),
            ])),

            // Qualité des prestations
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.workspace_premium_outlined, label: 'Qualité des prestations'),
              const Text('Impact sur le prix m² retenu', style: TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              StarRating(label: 'Cuisine', icon: '🍳', rating: _e.noteCuisine,
                  onRatingChange: (v) => _update(_e.copyWith(noteCuisine: v))),
              StarRating(label: 'Sol', icon: '🪵', rating: _e.noteSol,
                  onRatingChange: (v) => _update(_e.copyWith(noteSol: v))),
              StarRating(label: 'Salle de bain / Eau', icon: '🚿', rating: _e.noteSdb,
                  onRatingChange: (v) => _update(_e.copyWith(noteSdb: v))),
              StarRating(label: 'Fenêtres / Menuiseries', icon: '🪟', rating: _e.noteFenetres,
                  onRatingChange: (v) => _update(_e.copyWith(noteFenetres: v))),
              StarRating(label: 'Chauffage', icon: '🔥', rating: _e.noteChauffage,
                  onRatingChange: (v) => _update(_e.copyWith(noteChauffage: v))),
              StarRating(label: 'État général', icon: '🏠', rating: _e.noteEtatPrestation,
                  onRatingChange: (v) => _update(_e.copyWith(noteEtatPrestation: v))),
              const SizedBox(height: 10),
              _ScoreBadge(score: _e.scorePrestations, coeff: _e.coefficientPrestations, label: _e.labelCoefficientPrestations),
            ])),

            // Qualité complémentaire
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.star_outline_rounded, label: 'Qualité'),

              const FieldLabel('Vue'),
              const SizedBox(height: 6),
              ChipGroup(options: _vueOptions, selected: _e.vues, onToggle: (v) {
                final list = List<String>.from(_e.vues);
                list.contains(v) ? list.remove(v) : list.add(v);
                _update(_e.copyWith(vues: list));
              }),
              const SizedBox(height: 12),

              const FieldLabel('Diagnostic de Performance Énergétique (DPE)'),
              const SizedBox(height: 6),
              DpeSelector(selected: _e.dpeClasse, onSelect: (v) => _update(_e.copyWith(dpeClasse: v))),
              const CardDivider(),

              DropdownField(label: 'Chauffage', value: _e.chauffageType, items: _chauffages,
                  onChanged: (v) => _update(_e.copyWith(chauffageType: v))),
              const SizedBox(height: 12),

              const FieldLabel('Revêtement de sol'),
              const SizedBox(height: 6),
              ChipGroup(options: _solOptions, selected: _e.revetementsol, onToggle: (v) {
                final list = List<String>.from(_e.revetementsol);
                list.contains(v) ? list.remove(v) : list.add(v);
                _update(_e.copyWith(revetementsol: list));
              }),
            ])),

            const SizedBox(height: 16),
          ]),
        ),
      ),
      SectionBottomBar(onPrev: widget.onPrev, onNext: widget.onNext),
    ]);
  }
}

class _AnnexeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  const _AnnexeField({required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGrey)),
    const SizedBox(height: 4),
    TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        suffixText: 'm²',
        suffixStyle: const TextStyle(fontSize: 11, color: kGrey),
        hintText: '0',
        hintStyle: const TextStyle(color: kLightGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
      ),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    ),
  ]);
}

class _TerrainConstructibleWidget extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  const _TerrainConstructibleWidget({required this.estimation, required this.onChanged});
  @override
  State<_TerrainConstructibleWidget> createState() => _TerrainConstructibleWidgetState();
}

class _TerrainConstructibleWidgetState extends State<_TerrainConstructibleWidget> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final v = widget.estimation.terrainConstructibleM2;
    _ctrl = TextEditingController(text: v > 0 ? v.toString() : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estimation;
    final excedent = e.surfaceTerrain - 500;
    final hasConstructible = e.terrainConstructibleM2 > 0;
    final prime = e.primeTerrain;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGreen.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.landscape_outlined, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text('Prime terrain (+$excedent m² excédentaires)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Terrain constructible ?', style: TextStyle(fontSize: 12, color: kCharcoal)),
          Switch(
            value: hasConstructible,
            activeColor: kGreen,
            onChanged: (v) {
              if (!v) {
                _ctrl.clear();
                widget.onChanged(e.copyWith(terrainConstructibleM2: 0));
              } else {
                widget.onChanged(e.copyWith(terrainConstructibleM2: (excedent * 0.3).round()));
                _ctrl.text = (excedent * 0.3).round().toString();
              }
            },
          ),
        ]),
        if (hasConstructible) ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
                decoration: InputDecoration(
                  suffixText: 'm²',
                  hintText: 'ex: ${(excedent * 0.3).round()}',
                  hintStyle: const TextStyle(color: kLightGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen, width: 2)),
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v) ?? 0;
                  widget.onChanged(e.copyWith(terrainConstructibleM2: parsed.clamp(0, excedent)));
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('/ $excedent m²', style: const TextStyle(fontSize: 12, color: kGrey)),
          ]),
          const SizedBox(height: 4),
          Text('Constructible × 80 €/m²  ·  Non-constructible × 8 €/m²',
              style: const TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
        ] else ...[
          const Text('Non précisé → 8 €/m² (zone agricole / naturelle)',
              style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
        ],
        if (prime > 0) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('Prime terrain estimée : +${_fmt(prime)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
          ),
        ],
      ]),
    );
  }
}

class _SurfaceField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final String? hint;
  const _SurfaceField({required this.label, required this.controller, required this.onChanged, this.hint});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel(label),
    const SizedBox(height: 6),
    TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal),
      decoration: InputDecoration(
        suffixText: 'm²',
        suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kGrey),
        hintText: hint ?? 'ex: 75',
        hintStyle: const TextStyle(color: kLightGrey, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onChanged(parsed.round());
      },
    ),
  ]);
}
