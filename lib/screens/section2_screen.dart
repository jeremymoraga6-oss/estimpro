import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/mes_notes.dart';

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

  final _annees = ['Avant 1900', '1900-1950', '1950-1980', '1980-2000', '2000-2010', '2010-2020', 'Après 2020'];
  final _chauffages = ['Gaz naturel', 'Électrique', 'Pompe à chaleur', 'Fioul', 'Bois / Pellets', 'Géothermie'];
  final _vueOptions = ['Montagne', 'Dégagée', 'Jardin', 'Rue', 'Cour'];
  final _solOptions = ['Parquet', 'Carrelage', 'Tomettes', 'Béton ciré', 'Moquette'];
  final _orientations = ['N', 'S', 'E', 'O', 'Traversant'];

  @override
  void initState() { super.initState(); _e = widget.estimation; }

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

              StepperField(label: 'Surface habitable', value: _e.surfaceHabitable, unit: ' m²', step: 5,
                  onChange: (v) => _update(_e.copyWith(surfaceHabitable: v))),
              const SizedBox(height: 12),
              StepperField(label: 'Surface terrain', value: _e.surfaceTerrain, unit: ' m²', step: 25,
                  onChange: (v) => _update(_e.copyWith(surfaceTerrain: v))),
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
              Row(children: _orientations.map((o) {
                final sel = _e.orientations.contains(o);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final list = List<String>.from(_e.orientations);
                      sel ? list.remove(o) : list.add(o);
                      _update(_e.copyWith(orientations: list));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: o != 'Traversant' ? 7 : 0),
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel ? kGreen : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: sel ? kGreen : kBorderColor, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(o, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : kGrey)),
                    ),
                  ),
                );
              }).toList()),
            ])),

            // Qualité
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
