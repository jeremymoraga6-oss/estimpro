import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';

class Section4Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const Section4Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev});

  @override
  State<Section4Screen> createState() => _Section4ScreenState();
}

class _Section4ScreenState extends State<Section4Screen> {
  late Estimation _e;
  late TextEditingController _anneeCtrl;

  final _chauffages = ['Gaz naturel', 'Électrique', 'Pompe à chaleur', 'Fioul', 'Bois / Pellets', 'Géothermie'];

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _anneeCtrl = TextEditingController(text: '${_e.anneeChaudiere}');
  }

  @override
  void dispose() { _anneeCtrl.dispose(); super.dispose(); }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'État & équipements', reference: _e.reference, step: 4, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Structure extérieure
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.home_outlined, label: 'Structure extérieure'),

              const FieldLabel('Façade'),
              const SizedBox(height: 6),
              PillSelector(options: const ['Bon', 'Moyen', 'À refaire'], selected: _e.facade,
                  onSelect: (v) => _update(_e.copyWith(facade: v))),
              const SizedBox(height: 12),

              const FieldLabel('Toiture'),
              const SizedBox(height: 6),
              PillSelector(options: const ['Bon', 'Moyen', 'À refaire'], selected: _e.toiture,
                  onSelect: (v) => _update(_e.copyWith(toiture: v))),
              const CardDivider(),

              const FieldLabel('Menuiseries — Type'),
              const SizedBox(height: 6),
              ChipGroup(options: const ['PVC', 'Bois', 'Alu', 'Mixte'], selected: _e.menuiseriesType, onToggle: (v) {
                final list = List<String>.from(_e.menuiseriesType);
                list.contains(v) ? list.remove(v) : list.add(v);
                _update(_e.copyWith(menuiseriesType: list));
              }),
              const SizedBox(height: 12),

              const FieldLabel('Vitrage'),
              const SizedBox(height: 6),
              ChipGroup(options: const ['Simple', 'Double', 'Triple'], selected: _e.vitrage, onToggle: (v) {
                final list = List<String>.from(_e.vitrage);
                list.contains(v) ? list.remove(v) : list.add(v);
                _update(_e.copyWith(vitrage: list));
              }),
            ])),

            // Chauffage & énergie
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.bolt_outlined, label: 'Chauffage & énergie'),

              DropdownField(label: 'Type de chauffage', value: _e.chauffageType, items: _chauffages,
                  onChanged: (v) => _update(_e.copyWith(chauffageType: v))),
              const SizedBox(height: 12),

              const FieldLabel('État du chauffage'),
              const SizedBox(height: 6),
              PillSelector(options: const ['Bon', 'Moyen', 'Vétuste'], selected: _e.chauffageEtat,
                  onSelect: (v) => _update(_e.copyWith(chauffageEtat: v))),
              const SizedBox(height: 12),

              const FieldLabel('Année de la chaudière'),
              TextField(
                controller: _anneeCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => _update(_e.copyWith(anneeChaudiere: int.tryParse(v) ?? _e.anneeChaudiere)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 14, color: kCharcoal, fontWeight: FontWeight.w600),
              ),
            ])),

            // Installations
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.construction_outlined, label: 'Installations'),

              const FieldLabel('Électricité'),
              const SizedBox(height: 6),
              PillSelector(options: const ['Aux normes', 'Partiel', 'À refaire'], selected: _e.electricite,
                  onSelect: (v) => _update(_e.copyWith(electricite: v))),
              const SizedBox(height: 12),

              const FieldLabel('Isolation'),
              const SizedBox(height: 6),
              PillSelector(options: const ['Bonne', 'Moyenne', 'Mauvaise'], selected: _e.isolation,
                  onSelect: (v) => _update(_e.copyWith(isolation: v))),
            ])),

            // DPE Recap
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGreen.withOpacity(0.25), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.eco_outlined, color: kGreen, size: 18),
                  const SizedBox(width: 8),
                  Text('Récapitulatif DPE', style: kCardTitle.copyWith(color: kGreen)),
                ]),
                const SizedBox(height: 16),
                DpeSelector(selected: _e.dpeClasse, onSelect: (v) => _update(_e.copyWith(dpeClasse: v))),
                const SizedBox(height: 10),
                Center(
                  child: Column(children: [
                    Text('${_dpeKwh(_e.dpeClasse)} kWh/m².an · Classe ${_e.dpeClasse}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                    const SizedBox(height: 2),
                    Text('GES : Classe ${_gesClass(_e.dpeClasse)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
                  ]),
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

  String _dpeKwh(String classe) {
    const map = {'A': '<50', 'B': '75', 'C': '120', 'D': '180', 'E': '280', 'F': '390', 'G': '>450'};
    return map[classe] ?? '180';
  }

  String _gesClass(String dpe) {
    const map = {'A': 'A', 'B': 'B', 'C': 'C', 'D': 'E', 'E': 'F', 'F': 'G', 'G': 'G'};
    return map[dpe] ?? 'E';
  }
}
