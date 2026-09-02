import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../models/pathologie_item.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../services/materiaux_scan_service.dart';
import '../services/app_settings.dart';

class Section4Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final ValueChanged<int>? onStepTap;
  const Section4Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev, this.onStepTap});

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
    // Initialize pathologies from referentiel if empty
    if (_e.pathologies.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _update(_e.copyWith(pathologies: buildPathologiesReferentiel()));
      });
    }
  }

  @override
  void dispose() { _anneeCtrl.dispose(); super.dispose(); }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'État & équipements', reference: _e.reference, step: 4, totalSteps: 7, onBack: widget.onPrev, onStepTap: widget.onStepTap),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Structure extérieure
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: CardTitleRow(icon: Icons.home_outlined, label: 'Structure extérieure')),
                _ScanMateriauxButton(onDetected: (result) {
                  var updated = _e;
                  if (result.facade != null) updated = updated.copyWith(facade: result.facade);
                  if (result.toiture != null) updated = updated.copyWith(toiture: result.toiture);
                  if (result.menuiseriesType.isNotEmpty) updated = updated.copyWith(menuiseriesType: result.menuiseriesType);
                  if (result.vitrage.isNotEmpty) updated = updated.copyWith(vitrage: result.vitrage);
                  _update(updated);
                }),
              ]),

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

            // Réseaux & équipements
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.cable_outlined, label: 'Réseaux & équipements'),

              const FieldLabel('Assainissement'),
              const SizedBox(height: 6),
              PillSelector(
                options: const ['Tout-à-l\'égout', 'Fosse septique', 'Micro-station'],
                selected: _e.assainissement,
                onSelect: (v) => _update(_e.copyWith(assainissement: _e.assainissement == v ? '' : v)),
              ),
              const SizedBox(height: 12),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Row(children: [
                  Icon(Icons.wifi_outlined, size: 16, color: kGreen),
                  SizedBox(width: 8),
                  Text('Fibre optique', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                ]),
                Switch(
                  value: _e.fibreOptique,
                  activeThumbColor: kGreen,
                  onChanged: (v) => _update(_e.copyWith(fibreOptique: v)),
                ),
              ]),
              const CardDivider(),

              const FieldLabel('Équipements'),
              const SizedBox(height: 6),
              ChipGroup(
                options: const [
                  'Piscine', 'Garage', 'Box', 'Parking', 'Cave', 'Grenier',
                  'Ascenseur', 'Interphone', 'Digicode', 'Alarme', 'Climatisation',
                  'Cheminée', 'Poêle', 'Véranda', 'Portail élec.', 'Volets élec.',
                  'Cuisine équipée', 'Dressing', 'Borne élec.', 'Panneaux solaires',
                ],
                selected: _e.equipements,
                onToggle: (v) {
                  final list = List<String>.from(_e.equipements);
                  list.contains(v) ? list.remove(v) : list.add(v);
                  _update(_e.copyWith(equipements: list));
                },
              ),
            ])),

            // Diagnostics obligatoires
            _DiagnosticsCard(
              estimation: _e,
              onChanged: (d) => _update(_e.copyWith(diagnostics: d)),
            ),

            // DPE Recap — masqué pour terrain (pas de bâti)
            if (_e.typeId != 'terrain')
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGreen.withValues(alpha: 0.25), width: 1.5),
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

            // Documents de mise en vente
            _DocumentsVenteCard(
              estimation: _e,
              onChanged: (docs) => _update(_e.copyWith(documentsChecked: docs)),
            ),

            // Pathologies bâti
            _PathologiesCard(
              estimation: _e,
              onChanged: _update,
            ),

            const SizedBox(height: 80),
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

// ── Documents mise en vente ───────────────────────────────────────────────────

/// Un document dans le dossier de vente.
class _DocItem {
  final String id;
  final String label;
  final String? note; // précision optionnelle affichée en italique
  const _DocItem(this.id, this.label, {this.note});
}

/// Groupe de documents (ex: "Identité & propriété").
class _DocGroup {
  final String title;
  final IconData icon;
  final List<_DocItem> items;
  const _DocGroup({required this.title, required this.icon, required this.items});
}

/// Calcule la liste des groupes de documents en fonction du bien.
List<_DocGroup> _buildDocGroups(Estimation e) {
  final annee = e.anneeConstruction;
  final isAppart = e.typeId == 'appartement';
  final isMaison = e.typeId == 'maison' || e.typeId == 'chalet';

  // Dates utiles
  const recents = ['2010-2020', 'Après 2020'];       // < ~15 ans → décennale possible
  const apresPermis = ['1980-2000', '2000-2010', '2010-2020', 'Après 2020']; // permis de construire courant
  const veryOld = ['Avant 1900', '1900-1950'];       // chaîne de propriété longue

  final groups = <_DocGroup>[];

  // ── 1. Identité & propriété ────────────────────────────────────────────────
  final identite = <_DocItem>[
    const _DocItem('titre_propriete', 'Titre de propriété', note: 'Acte notarié d\'achat'),
    const _DocItem('identite', 'Pièce d\'identité du/des vendeur(s)'),
    const _DocItem('situation_famille', 'Situation de famille',
        note: 'Livret de famille, jugement de divorce si applicable'),
    const _DocItem('taxe_fonciere', 'Dernier avis de taxe foncière'),
  ];
  if (veryOld.contains(annee)) {
    identite.add(const _DocItem('chaine_propriete',
        'Chaîne de propriété (30 ans)', note: 'Actes antérieurs — bien avant 1950'));
  }
  identite.add(const _DocItem('credit_hypothecaire',
      'Capital restant dû / mainlevée', note: 'Si crédit immobilier en cours'));

  groups.add(_DocGroup(
    title: 'Identité & propriété',
    icon: Icons.badge_outlined,
    items: identite,
  ));

  // ── 2. Urbanisme & construction (maison / chalet) ─────────────────────────
  if (isMaison) {
    final urba = <_DocItem>[];
    if (apresPermis.contains(annee)) {
      urba.add(const _DocItem('permis_construire', 'Permis de construire'));
      urba.add(const _DocItem('certificat_conformite',
          'Certificat de conformité / DAACT', note: 'Déclaration attestant l\'achèvement'));
    }
    if (recents.contains(annee)) {
      urba.add(const _DocItem('decennale',
          'Garantie décennale des constructeurs', note: 'Construction < 10 ans'));
    }
    urba.add(const _DocItem('plan_masse', 'Plan de masse / plan côté'));
    urba.add(const _DocItem('factures_travaux',
        'Factures & garanties des travaux importants', note: 'Si rénovation ou extension'));
    urba.add(const _DocItem('certificat_urbanisme',
        'Certificat d\'urbanisme', note: 'Optionnel, facilite la vente'));

    if (urba.isNotEmpty) {
      groups.add(_DocGroup(
        title: 'Urbanisme & construction',
        icon: Icons.construction_outlined,
        items: urba,
      ));
    }
  }

  // ── 3. Copropriété (appartement) ──────────────────────────────────────────
  if (isAppart) {
    groups.add(const _DocGroup(
      title: 'Copropriété',
      icon: Icons.apartment_outlined,
      items: [
        _DocItem('reglement_copro',
            'Règlement de copropriété', note: 'Et état descriptif de division'),
        _DocItem('pv_ag', '3 derniers PV d\'assemblée générale'),
        _DocItem('carnet_entretien', 'Carnet d\'entretien de l\'immeuble'),
        _DocItem('fiche_synthetique', 'Fiche synthétique de copropriété'),
        _DocItem('releve_charges',
            'Relevés de charges (2 dernières années)'),
        _DocItem('pre_etat_date',
            'Pré-état daté du syndic', note: 'Art. 20 loi 10 juillet 1965'),
      ],
    ));
  }

  // ── 4. Technique & diagnostics ────────────────────────────────────────────
  // Ancienneté — mêmes seuils légaux que la section Diagnostics
  const avantAmiante = ['Avant 1900', '1900-1950', '1950-1980', '1980-2000']; // permis avant juillet 1997
  const avantPlomb   = ['Avant 1900', '1900-1950'];                            // avant 1949

  final tech = <_DocItem>[
    const _DocItem('dpe_doc', 'DPE — Diagnostic de Performance Énergétique'),
    const _DocItem('erp_doc', 'ERP — État des Risques et Pollutions'),
  ];

  if (avantPlomb.contains(annee)) {
    tech.add(const _DocItem('crep',
        'CREP — Constat de Risque d\'Exposition au Plomb',
        note: 'Obligatoire — construction avant 1949'));
  }

  if (avantAmiante.contains(annee)) {
    tech.add(const _DocItem('amiante_doc',
        'Diagnostic Amiante (DTA / État mentionnant l\'absence)',
        note: 'Obligatoire — permis de construire avant juillet 1997'));
  }

  if (annee != 'Après 2020') {
    tech.add(const _DocItem('elec_doc',
        'Diagnostic électricité', note: 'Installation > 15 ans'));
  }

  if (e.chauffageType.toLowerCase().contains('gaz') ||
      e.chauffageType.toLowerCase().contains('fioul')) {
    tech.add(const _DocItem('gaz_doc',
        'Diagnostic gaz', note: 'Installation > 15 ans'));
  }

  if (isMaison) {
    tech.add(const _DocItem('assainissement_indiv',
        'Rapport de contrôle assainissement', note: 'Assainissement non collectif'));
  }

  tech.add(const _DocItem('factures_energie',
      'Factures d\'énergie récentes', note: 'Gaz, électricité — 12 derniers mois'));

  groups.add(_DocGroup(
    title: 'Technique & diagnostics',
    icon: Icons.fact_check_outlined,
    items: tech,
  ));

  return groups;
}

class _DocumentsVenteCard extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Map<String, bool>> onChanged;
  const _DocumentsVenteCard({required this.estimation, required this.onChanged});

  @override
  State<_DocumentsVenteCard> createState() => _DocumentsVenteCardState();
}

class _DocumentsVenteCardState extends State<_DocumentsVenteCard> {
  bool _expanded = false;

  void _toggle(String id, bool val) {
    final updated = Map<String, bool>.from(widget.estimation.documentsChecked);
    updated[id] = val;
    widget.onChanged(updated);
  }

  bool _checked(String id) => widget.estimation.documentsChecked[id] ?? false;

  @override
  Widget build(BuildContext context) {
    final groups = _buildDocGroups(widget.estimation);
    final allItems = groups.expand((g) => g.items).toList();
    final total = allItems.length;
    final done = allItems.where((d) => _checked(d.id)).length;
    final pct = total == 0 ? 1.0 : done / total;

    final Color progressColor;
    if (pct >= 1.0) {
      progressColor = kGreen;
    } else if (pct >= 0.5) {
      progressColor = const Color(0xFFF09000);
    } else {
      progressColor = kRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header — toujours visible
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16),
              bottom: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              const Icon(Icons.folder_open_outlined, size: 18, color: kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Documents de mise en vente', style: kCardTitle),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$done / $total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: progressColor)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20, color: kGrey),
            ]),
          ),
        ),

        // Corps — dépliable
        if (_expanded) ...[
          const Divider(height: 1, color: kBorderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                  child: Text(group.title.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: kLightGrey, letterSpacing: 0.8)),
                ),
                for (int i = 0; i < group.items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 36, color: kBorderColor),
                  _DocRow(
                    item: group.items[i],
                    checked: _checked(group.items[i].id),
                    onToggle: (v) => _toggle(group.items[i].id, v),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

class _DocRow extends StatelessWidget {
  final _DocItem item;
  final bool checked;
  final ValueChanged<bool> onToggle;
  const _DocRow({required this.item, required this.checked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? kGreen : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: checked ? kGreen : kLightGrey,
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: checked ? kGrey : kCharcoal,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: kGrey,
                  )),
              if (item.note != null) ...[
                const SizedBox(height: 2),
                Text(item.note!,
                    style: const TextStyle(fontSize: 11, color: kLightGrey,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Scanner matériaux ──────────────────────────────────────────────────────────

class _ScanMateriauxButton extends StatefulWidget {
  final ValueChanged<MateriauxResult> onDetected;
  const _ScanMateriauxButton({required this.onDetected});
  @override
  State<_ScanMateriauxButton> createState() => _ScanMateriauxButtonState();
}

class _ScanMateriauxButtonState extends State<_ScanMateriauxButton> {
  bool _loading = false;

  Future<void> _scan(ImageSource src) async {
    Navigator.pop(context);

    if (!AppSettings.instance.hasAnthropicKey) {
      _showError('Clé API Anthropic manquante. Configure-la dans Profil → IA.');
      return;
    }

    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      _showError('Impossible d\'accéder à la photo : $e');
      return;
    }
    if (file == null) return;

    setState(() => _loading = true);
    final result = await MateriauxScanService().analyzeImage(file.path);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.hasData) {
      _showError('Matériaux non détectés. Essaie avec une photo de la façade plus nette et bien cadrée.');
      return;
    }
    _showConfirm(result);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kRed),
    );
  }

  void _showConfirm(MateriauxResult r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_awesome, size: 20, color: kGreen),
          SizedBox(width: 8),
          Text('Matériaux détectés', style: TextStyle(fontSize: 16)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Les champs cochés seront appliqués :',
                style: TextStyle(fontSize: 11, color: kGrey)),
            const SizedBox(height: 10),
            if (r.facade != null) ...[
              _resultRow('Façade — état', r.facade!),
              if (r.facadeMatiere != null)
                _resultRow('Façade — matériau', r.facadeMatiere!, secondary: true),
            ],
            if (r.toiture != null) ...[
              _resultRow('Toiture — état', r.toiture!),
              if (r.toitureMatiere != null)
                _resultRow('Toiture — matériau', r.toitureMatiere!, secondary: true),
            ],
            if (r.menuiseriesType.isNotEmpty)
              _resultRow('Menuiseries', r.menuiseriesType.join(', ')),
            if (r.vitrage.isNotEmpty)
              _resultRow('Vitrage estimé', r.vitrage.join(', ')),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              widget.onDetected(r);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Matériaux appliqués ✓')),
              );
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool secondary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: secondary ? 11 : 12,
                  color: secondary ? kLightGrey : kGrey,
                  fontStyle: secondary ? FontStyle.italic : FontStyle.normal)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: secondary ? 11 : 13,
                fontWeight: secondary ? FontWeight.w500 : FontWeight.w700,
                color: secondary ? kLightGrey : kCharcoal)),
      ]),
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: kGreen),
            title: const Text('Photographier la façade'),
            subtitle: const Text('Cadre la maison en entier si possible'),
            onTap: () => _scan(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: kGreen),
            title: const Text('Choisir depuis la galerie'),
            onTap: () => _scan(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: kGrey),
            title: const Text('Annuler'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading ? null : _showPicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kGreen.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
            )
          else
            const Icon(Icons.photo_camera_outlined, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text(
            _loading ? 'Analyse…' : 'Scanner façade',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen),
          ),
        ]),
      ),
    );
  }
}

// ── Diagnostics card ──────────────────────────────────────────────────────────

// Catalogue complet — libellé + icône
const _kAllDiags = <String, Map<String, Object>>{
  'dpe':            {'label': 'DPE',              'icon': Icons.bolt_outlined},
  'carrez':         {'label': 'Loi Carrez',       'icon': Icons.straighten_outlined},
  'amiante':        {'label': 'Amiante',          'icon': Icons.warning_amber_outlined},
  'electricite':    {'label': 'Electricite',      'icon': Icons.electrical_services_outlined},
  'gaz':            {'label': 'Gaz',              'icon': Icons.local_fire_department_outlined},
  'plomb':          {'label': 'Plomb',            'icon': Icons.opacity_outlined},
  'termites':       {'label': 'Termites',         'icon': Icons.pest_control_outlined},
  'erp':            {'label': 'ERP',              'icon': Icons.landscape_outlined},
  'assainissement': {'label': 'Assainissement',   'icon': Icons.water_outlined},
  'radon':          {'label': 'Radon',            'icon': Icons.air_outlined},
  'bruit':          {'label': 'Bruit aerodrome',  'icon': Icons.volume_up_outlined},
  'dgt':            {'label': 'DGT (copro)',      'icon': Icons.apartment_outlined},
};

// Groupes : obligatoires calculés + zone (toujours visibles)
const _kZoneDiags = ['termites', 'radon', 'bruit'];

List<String> _obligatoireIds(Estimation e) {
  // Terrain nu : seul l'ERP est obligatoire (pas de bâti → pas de DPE,
  // amiante, plomb, électricité, gaz, Carrez)
  if (e.typeId == 'terrain') return ['erp'];

  final ids = <String>['dpe', 'erp'];
  final annee = e.anneeConstruction;

  // Avant 1997 → Amiante
  const avantAmiante = ['Avant 1900', '1900-1950', '1950-1980', '1980-2000'];
  if (avantAmiante.contains(annee)) ids.add('amiante');

  // Avant 1949 → Plomb
  const avantPlomb = ['Avant 1900', '1900-1950'];
  if (avantPlomb.contains(annee)) ids.add('plomb');

  // Installation électrique : tout sauf construction très récente
  if (annee != 'Après 2020') ids.add('electricite');

  // Gaz : si installation gaz présente
  if (e.chauffageType.toLowerCase().contains('gaz') ||
      e.chauffageType.toLowerCase().contains('fioul')) {
    ids.add('gaz');
  }

  // Loi Carrez + DGT : appartement uniquement
  if (e.typeId == 'appartement') {
    ids.add('carrez');
    ids.add('dgt');
  }

  // Assainissement non collectif : maison / chalet
  if (e.typeId == 'maison' || e.typeId == 'chalet') {
    ids.add('assainissement');
  }

  return ids;
}

const _kStatuts = ['', 'valide', 'a_refaire', 'nc'];

class _DiagnosticsCard extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Map<String, Map<String, String>>> onChanged;
  const _DiagnosticsCard({required this.estimation, required this.onChanged});

  @override
  State<_DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends State<_DiagnosticsCard> {
  final Map<String, TextEditingController> _dateCtrl = {};

  Map<String, Map<String, String>> get _diags => widget.estimation.diagnostics;

  @override
  void initState() {
    super.initState();
    for (final id in _kAllDiags.keys) {
      _dateCtrl[id] = TextEditingController(text: _diags[id]?['date'] ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _dateCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _cycleStatut(String id) {
    final cur = _diags[id]?['statut'] ?? '';
    final idx = _kStatuts.indexOf(cur);
    final next = _kStatuts[(idx + 1) % _kStatuts.length];
    final updated = Map<String, Map<String, String>>.from(_diags);
    updated[id] = {'statut': next, 'date': _diags[id]?['date'] ?? ''};
    widget.onChanged(updated);
  }

  void _setDate(String id, String date) {
    final updated = Map<String, Map<String, String>>.from(_diags);
    updated[id] = {'statut': _diags[id]?['statut'] ?? '', 'date': date};
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final obligatoires = _obligatoireIds(widget.estimation);
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitleRow(icon: Icons.fact_check_outlined, label: 'Diagnostics'),
        _diagGroup('OBLIGATOIRES POUR CE BIEN', obligatoires),
        _diagGroup('SELON ZONE GEOGRAPHIQUE', _kZoneDiags),
      ]),
    );
  }

  Widget _diagGroup(String title, List<String> ids) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kLightGrey, letterSpacing: 0.8)),
      ),
      ...List.generate(ids.length, (i) {
        final id = ids[i];
        final def = _kAllDiags[id]!;
        final statut = _diags[id]?['statut'] ?? '';
        final showDate = statut == 'valide' || statut == 'a_refaire';
        return Column(children: [
          if (i > 0) const Divider(height: 1, indent: 44),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _iconBg(statut), borderRadius: BorderRadius.circular(8)),
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
    ]);
  }

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

// ── Checklist pathologies ──────────────────────────────────────────────────

class _PathologiesCard extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  const _PathologiesCard({required this.estimation, required this.onChanged});
  @override
  State<_PathologiesCard> createState() => _PathologiesCardState();
}

class _PathologiesCardState extends State<_PathologiesCard> {
  late List<PathologieItem> _items;
  late Map<String, TextEditingController> _noteCtrlMap;
  late Map<String, TextEditingController> _provCtrlMap;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.estimation.pathologies.isNotEmpty
        ? widget.estimation.pathologies
        : buildPathologiesReferentiel());
    _noteCtrlMap = {for (final p in _items) p.id: TextEditingController(text: p.note)};
    _provCtrlMap = {for (final p in _items) p.id: TextEditingController(text: '${p.provision}')};
  }

  @override
  void didUpdateWidget(_PathologiesCard old) {
    super.didUpdateWidget(old);
    if (widget.estimation.pathologies != old.estimation.pathologies) {
      _items = List.from(widget.estimation.pathologies.isNotEmpty
          ? widget.estimation.pathologies
          : buildPathologiesReferentiel());
    }
  }

  @override
  void dispose() {
    for (final c in _noteCtrlMap.values) {
      c.dispose();
    }
    for (final c in _provCtrlMap.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    widget.onChanged(widget.estimation.copyWith(pathologies: List.from(_items)));
  }

  void _setEtat(int idx, int etat) {
    setState(() {
      final item = _items[idx];
      final newProvision = etat == 3 && item.provision == 0
          ? item.provisionBasse
          : (etat != 3 ? 0 : item.provision);
      _items[idx] = item.copyWith(etat: etat, provision: newProvision);
      // Sync provision controller
      if (etat == 3 && item.provision == 0) {
        _provCtrlMap[item.id]?.text = '${item.provisionBasse}';
      } else if (etat != 3) {
        _provCtrlMap[item.id]?.text = '0';
      }
    });
    _save();
  }

  int get _totalProvisions => _items.fold(0, (s, p) => s + (p.defaut ? p.provision : 0));
  int get _nbVerifies => _items.where((p) => p.verifie).length;

  void _showAide(BuildContext context, PathologieItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.construction_rounded, size: 18, color: kGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(item.libelle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kCharcoal))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF7F9F6), borderRadius: BorderRadius.circular(10)),
            child: Text(item.aideMemo,
                style: const TextStyle(fontSize: 13, color: kCharcoal, height: 1.6)),
          ),
          if (item.provisionHaute > 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.euro_rounded, size: 14, color: kAmber),
              const SizedBox(width: 6),
              Text(
                'Provision si défaut : ${_fmtEuro(item.provisionBasse)} – ${_fmtEuro(item.provisionHaute)}',
                style: const TextStyle(fontSize: 12, color: kAmber, fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  String _fmtEuro(int n) => '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}\u202f')} €';

  @override
  Widget build(BuildContext context) {
    final totalProv = _totalProvisions;
    final estimation = widget.estimation;

    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitleRow(icon: Icons.checklist_rounded, label: 'Lecture du bâti — Méthode Moraga'),
      const Text(
        'Grille d\'observation visuelle — 13 points de contrôle. Sans sondage destructif.',
        style: TextStyle(fontSize: 11, color: kGrey, height: 1.4),
      ),
      const SizedBox(height: 12),

      // Liste des 13 points
      ...List.generate(_items.length, (i) {
        final item = _items[i];
        final isDefaut = item.defaut;
        final isSurveiller = item.etat == 2;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: isDefaut
                ? kRed.withValues(alpha: 0.04)
                : isSurveiller
                    ? kAmber.withValues(alpha: 0.04)
                    : const Color(0xFFFAFBFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDefaut
                  ? kRed.withValues(alpha: 0.25)
                  : isSurveiller
                      ? kAmber.withValues(alpha: 0.25)
                      : const Color(0xFFECEFEC),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ligne principale : libellé + aide + boutons segmentés
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text(item.libelle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal))),
              // Bouton aide-mémoire
              GestureDetector(
                onTap: () => _showAide(context, item),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.info_outline_rounded, size: 16, color: kLightGrey),
                ),
              ),
              // Boutons segmentés OK / Surveiller / Défaut
              Row(mainAxisSize: MainAxisSize.min, children: [
                _EtatBtn(label: '✓', active: item.etat == 1, activeColor: kGreen,
                    onTap: () => _setEtat(i, item.etat == 1 ? 0 : 1)),
                const SizedBox(width: 4),
                _EtatBtn(label: '👁', active: item.etat == 2, activeColor: kAmber,
                    onTap: () => _setEtat(i, item.etat == 2 ? 0 : 2)),
                const SizedBox(width: 4),
                _EtatBtn(label: '⚠', active: item.etat == 3, activeColor: kRed,
                    onTap: () => _setEtat(i, item.etat == 3 ? 0 : 3)),
              ]),
            ]),

            // Note (si surveiller ou défaut)
            if (isSurveiller || isDefaut) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrlMap[item.id],
                onChanged: (v) {
                  setState(() { _items[i] = _items[i].copyWith(note: v); });
                  _save();
                },
                decoration: InputDecoration(
                  hintText: isDefaut ? 'Note / observation...' : 'Observation...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDefaut ? kRed.withValues(alpha: 0.3) : kAmber.withValues(alpha: 0.3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDefaut ? kRed.withValues(alpha: 0.3) : kAmber.withValues(alpha: 0.3))),
                ),
                style: const TextStyle(fontSize: 11, color: kCharcoal),
                maxLines: 2,
              ),
            ],

            // Provision (si défaut uniquement)
            if (isDefaut) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.euro_rounded, size: 12, color: kRed),
                const SizedBox(width: 4),
                const Text('Provision :', style: TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _provCtrlMap[item.id],
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? item.provisionBasse;
                      setState(() { _items[i] = _items[i].copyWith(provision: parsed); });
                      _save();
                    },
                    decoration: InputDecoration(
                      suffix: const Text('€', style: TextStyle(fontSize: 11, color: kRed)),
                      hintText: '${item.provisionBasse}',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kRed, width: 1)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: kRed.withValues(alpha: 0.35))),
                    ),
                    style: const TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'fourchette : ${_fmtEuro(item.provisionBasse)}–${_fmtEuro(item.provisionHaute)}',
                  style: const TextStyle(fontSize: 9, color: kLightGrey),
                ),
              ]),
            ],
          ]),
        );
      }),

      const CardDivider(),

      // Footer : compteur + total + bouton report
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_nbVerifies/13 vérifiés',
              style: const TextStyle(fontSize: 11, color: kGrey, fontWeight: FontWeight.w600)),
          if (totalProv > 0)
            Text('Total provisions : ${_fmtEuro(totalProv)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRed)),
        ]),
        const Spacer(),
        if (totalProv > 0)
          GestureDetector(
            onTap: () {
              final last = estimation.pathologiesLastReport;
              final newTravaux = estimation.ajustTravaux - last + totalProv;
              widget.onChanged(estimation.copyWith(
                pathologies: List.from(_items),
                ajustTravaux: newTravaux.clamp(0, 999999),
                pathologiesLastReport: totalProv,
              ));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${_fmtEuro(totalProv)} reportés dans Travaux à prévoir'),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Reporter ${_fmtEuro(totalProv)} dans Travaux',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
      ]),
    ]));
  }
}

class _EtatBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _EtatBtn({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 28,
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.5) : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              fontSize: active ? 13 : 12,
              color: active ? activeColor : kLightGrey,
            )),
      ),
    ),
  );
}
