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

            // Diagnostics obligatoires
            _DiagnosticsCard(
              diagnostics: _e.diagnostics,
              onChanged: (d) => _update(_e.copyWith(diagnostics: d)),
            ),

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

// ── Diagnostics card ──────────────────────────────────────────────────────────

const _kDiags = [
  {'id': 'dpe',            'label': 'DPE',                 'icon': Icons.bolt_outlined},
  {'id': 'carrez',         'label': 'Loi Carrez',          'icon': Icons.straighten_outlined},
  {'id': 'amiante',        'label': 'Amiante',             'icon': Icons.warning_amber_outlined},
  {'id': 'electricite',    'label': 'Electricite',         'icon': Icons.electrical_services_outlined},
  {'id': 'gaz',            'label': 'Gaz',                 'icon': Icons.local_fire_department_outlined},
  {'id': 'plomb',          'label': 'Plomb',               'icon': Icons.opacity_outlined},
  {'id': 'termites',       'label': 'Termites',            'icon': Icons.pest_control_outlined},
  {'id': 'erp',            'label': 'ERP',                 'icon': Icons.landscape_outlined},
  {'id': 'assainissement', 'label': 'Assainissement',      'icon': Icons.water_outlined},
  {'id': 'radon',          'label': 'Radon',               'icon': Icons.air_outlined},
  {'id': 'bruit',          'label': 'Bruit aerodrome',     'icon': Icons.volume_up_outlined},
  {'id': 'dgt',            'label': 'DGT (copro)',         'icon': Icons.apartment_outlined},
];

const _kStatuts = ['', 'valide', 'a_refaire', 'nc'];

class _DiagnosticsCard extends StatefulWidget {
  final Map<String, Map<String, String>> diagnostics;
  final ValueChanged<Map<String, Map<String, String>>> onChanged;
  const _DiagnosticsCard({required this.diagnostics, required this.onChanged});

  @override
  State<_DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends State<_DiagnosticsCard> {
  final Map<String, TextEditingController> _dateCtrl = {};

  @override
  void initState() {
    super.initState();
    for (final d in _kDiags) {
      final id = d['id'] as String;
      _dateCtrl[id] = TextEditingController(text: widget.diagnostics[id]?['date'] ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _dateCtrl.values) c.dispose();
    super.dispose();
  }

  void _cycleStatut(String id) {
    final cur = widget.diagnostics[id]?['statut'] ?? '';
    final idx = _kStatuts.indexOf(cur);
    final next = _kStatuts[(idx + 1) % _kStatuts.length];
    final updated = Map<String, Map<String, String>>.from(widget.diagnostics);
    updated[id] = {'statut': next, 'date': widget.diagnostics[id]?['date'] ?? ''};
    widget.onChanged(updated);
  }

  void _setDate(String id, String date) {
    final updated = Map<String, Map<String, String>>.from(widget.diagnostics);
    updated[id] = {'statut': widget.diagnostics[id]?['statut'] ?? '', 'date': date};
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardTitleRow(icon: Icons.fact_check_outlined, label: 'Diagnostics'),
          ...List.generate(_kDiags.length, (i) {
            final def = _kDiags[i];
            final id = def['id'] as String;
            final statut = widget.diagnostics[id]?['statut'] ?? '';
            final showDate = statut == 'valide' || statut == 'a_refaire';
            return Column(children: [
              if (i > 0) const Divider(height: 1, indent: 44),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _iconBg(statut),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(def['icon'] as IconData, size: 16, color: _iconColor(statut)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(def['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kCharcoal))),
                    GestureDetector(
                      onTap: () => _cycleStatut(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _badgeBg(statut),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _badgeBorder(statut), width: 1.5),
                        ),
                        child: Text(_badgeLabel(statut), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _badgeFg(statut))),
                      ),
                    ),
                  ]),
                  if (showDate) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 44),
                      child: TextField(
                        controller: _dateCtrl[id],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12, color: kCharcoal),
                        decoration: InputDecoration(
                          hintText: 'Annee (ex: 2023)',
                          hintStyle: const TextStyle(fontSize: 12, color: kLightGrey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          isDense: true,
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen, width: 1.5)),
                        ),
                        onChanged: (v) => _setDate(id, v),
                      ),
                    ),
                  ],
                ]),
              ),
            ]);
          }),
        ]),
      );

  Color _iconBg(String s) {
    switch (s) {
      case 'valide':    return const Color(0xFFE8F5E9);
      case 'a_refaire': return const Color(0xFFFFF3E0);
      case 'nc':        return const Color(0xFFF5F5F5);
      default:          return const Color(0xFFF5F5F5);
    }
  }

  Color _iconColor(String s) {
    switch (s) {
      case 'valide':    return kGreen;
      case 'a_refaire': return const Color(0xFFE67E22);
      case 'nc':        return kLightGrey;
      default:          return kLightGrey;
    }
  }

  Color _badgeBg(String s) {
    switch (s) {
      case 'valide':    return const Color(0xFFE8F5E9);
      case 'a_refaire': return const Color(0xFFFFF3E0);
      case 'nc':        return const Color(0xFFF5F5F5);
      default:          return Colors.white;
    }
  }

  Color _badgeBorder(String s) {
    switch (s) {
      case 'valide':    return kGreen;
      case 'a_refaire': return const Color(0xFFE67E22);
      case 'nc':        return kLightGrey;
      default:          return kLightGrey;
    }
  }

  Color _badgeFg(String s) {
    switch (s) {
      case 'valide':    return kGreen;
      case 'a_refaire': return const Color(0xFFE67E22);
      case 'nc':        return kLightGrey;
      default:          return kLightGrey;
    }
  }

  String _badgeLabel(String s) {
    switch (s) {
      case 'valide':    return 'Valide';
      case 'a_refaire': return 'A refaire';
      case 'nc':        return 'N/A';
      default:          return 'Non renseigne';
    }
  }
}
