import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/star_rating.dart';
import '../services/dpe_ocr_service.dart';

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
  final ValueChanged<int>? onStepTap;
  const Section2Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev, this.onStepTap});

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
  late TextEditingController _carrezCtrl;
  late TextEditingController _cadastreCtrl;
  late TextEditingController _syndicCtrl;
  late TextEditingController _nbLotsCtrl;
  late TextEditingController _tantiemesCtrl;
  late TextEditingController _fondsCtrl;
  late TextEditingController _terrainCosCtrl;
  late TextEditingController _terrainServitudesCtrl;

  final _annees = ['Avant 1900', '1900-1950', '1950-1980', '1980-2000', '2000-2010', '2010-2020', 'Après 2020'];
  final _chauffages = ['Gaz naturel', 'Électrique', 'Pompe à chaleur', 'Fioul', 'Bois / Pellets', 'Géothermie'];
  final _vueOptions = ['Montagne', 'Dégagée', 'Jardin', 'Rue', 'Cour'];
  final _solOptions = ['Parquet', 'Carrelage', 'Tomettes', 'Béton ciré', 'Moquette'];
  final _orientations = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO', 'Traversant'];
  final _typesCuisine = ['Non précisé', 'Indépendante', 'Ouverte', 'Américaine', 'Kitchenette'];
  final _comblesOptions = ['Non précisé', 'Aucun', 'Aménagés', 'Aménageables', 'Non aménageables'];
  final _zonesPlu = ['Non précisé', 'UA', 'UB', 'UC', '1AU', '2AU', 'AU', 'A', 'N'];

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _surfCtrl = TextEditingController(text: _e.surfaceHabitable > 0 ? _e.surfaceHabitable.toString() : '');
    _terrCtrl = TextEditingController(text: _e.surfaceTerrain > 0 ? _e.surfaceTerrain.toString() : '');
    _balconCtrl = TextEditingController(text: _e.surfaceBalcon > 0 ? _e.surfaceBalcon.toString() : '');
    _caveCtrl = TextEditingController(text: _e.surfaceCave > 0 ? _e.surfaceCave.toString() : '');
    _terrasseCtrl = TextEditingController(text: _e.surfaceTerrasse > 0 ? _e.surfaceTerrasse.toString() : '');
    _carrezCtrl = TextEditingController(text: _e.surfaceCarrez > 0 ? _e.surfaceCarrez.toString() : '');
    _cadastreCtrl = TextEditingController(text: _e.referenceCadastrale);
    _syndicCtrl = TextEditingController(text: _e.syndicNom);
    _nbLotsCtrl = TextEditingController(text: _e.nombreLots > 0 ? _e.nombreLots.toString() : '');
    _tantiemesCtrl = TextEditingController(text: _e.tantiemes > 0 ? _e.tantiemes.toString() : '');
    _fondsCtrl = TextEditingController(text: _e.fondsTravaux > 0 ? _e.fondsTravaux.toString() : '');
    _terrainCosCtrl = TextEditingController(text: _e.terrainCos > 0 ? _e.terrainCos.toString() : '');
    _terrainServitudesCtrl = TextEditingController(text: _e.terrainServitudes);
  }

  @override
  void dispose() {
    _surfCtrl.dispose(); _terrCtrl.dispose(); _balconCtrl.dispose(); _caveCtrl.dispose(); _terrasseCtrl.dispose();
    _carrezCtrl.dispose(); _cadastreCtrl.dispose(); _syndicCtrl.dispose(); _nbLotsCtrl.dispose(); _tantiemesCtrl.dispose(); _fondsCtrl.dispose();
    _terrainCosCtrl.dispose(); _terrainServitudesCtrl.dispose();
    super.dispose();
  }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'Description du bien', reference: _e.reference, step: 2, totalSteps: 7, onBack: widget.onPrev, onStepTap: widget.onStepTap),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Surfaces
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.straighten_rounded, label: 'Surfaces'),

              // Surface habitable — masquée pour terrain (pas de bâti)
              if (_e.typeId != 'terrain') ...[
                _SurfaceField(
                  label: 'Surface habitable',
                  controller: _surfCtrl,
                  onChanged: (v) => _update(_e.copyWith(surfaceHabitable: v)),
                ),
              ],
              if (_e.typeId != 'appartement') ...[
                if (_e.typeId != 'terrain') const SizedBox(height: 12),
                _SurfaceField(
                  label: 'Surface terrain',
                  controller: _terrCtrl,
                  onChanged: (v) => _update(_e.copyWith(surfaceTerrain: v)),
                ),
                if (_e.typeId != 'terrain' && _e.surfaceTerrain > 500) ...[
                  const SizedBox(height: 10),
                  _TerrainConstructibleWidget(
                    estimation: _e,
                    onChanged: _update,
                  ),
                ],
              ],

              // Surfaces annexes pondérées — non pertinentes pour un terrain nu
              if (_e.typeId != 'terrain') ...[
                const CardDivider(),
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
                // Plafonds pondération — indication grise individuelle sous chaque champ
                if (_e.surfaceBalcon > 12 || _e.surfaceCave > 15 || _e.surfaceTerrasse > 20) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(child: _e.surfaceBalcon > 12
                        ? Text('Plafonné à 12 m²\ndans le calcul',
                            style: TextStyle(fontSize: 9, color: kLightGrey))
                        : const SizedBox()),
                    const SizedBox(width: 8),
                    Expanded(child: _e.surfaceCave > 15
                        ? Text('Plafonné à 15 m²\ndans le calcul',
                            style: TextStyle(fontSize: 9, color: kLightGrey))
                        : const SizedBox()),
                    const SizedBox(width: 8),
                    Expanded(child: _e.surfaceTerrasse > 20
                        ? Text('Plafonné à 20 m²\ndans le calcul',
                            style: TextStyle(fontSize: 9, color: kLightGrey))
                        : const SizedBox()),
                  ]),
                ],
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
                const SizedBox(height: 12),

                // Détail des surfaces par pièce
                _PiecesSurfacesWidget(
                  pieces: _e.piecesSurfaces,
                  onChanged: (list) => _update(_e.copyWith(piecesSurfaces: list)),
                ),
              ],

            ])),

            // Caractéristiques du terrain — visible uniquement pour typeId == 'terrain'
            if (_e.typeId == 'terrain')
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CardTitleRow(icon: Icons.terrain_outlined, label: 'Caractéristiques du terrain'),

                DropdownField(
                  label: 'Zone PLU',
                  value: _e.zonePlu.isEmpty ? 'Non précisé' : _e.zonePlu,
                  items: _zonesPlu,
                  onChanged: (v) => _update(_e.copyWith(zonePlu: v == 'Non précisé' ? '' : v)),
                ),
                const SizedBox(height: 14),

                // Constructibilité (widget existant réutilisé)
                if (_e.surfaceTerrain > 0) ...[
                  _TerrainConstructibleWidget(
                    estimation: _e,
                    onChanged: _update,
                  ),
                  const SizedBox(height: 12),
                ],

                // COS si terrain constructible
                if (_e.terrainConstructibleM2 > 0) ...[
                  const FieldLabel('COS / CES (coefficient d\'occupation des sols)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _terrainCosCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal),
                    decoration: InputDecoration(
                      hintText: 'ex: 0.40',
                      hintStyle: const TextStyle(color: kLightGrey),
                      helperText: _e.terrainCos > 0 && _e.surfaceTerrain > 0
                          ? 'SHON max ≈ ${(_e.surfaceTerrain * _e.terrainCos).round()} m²'
                          : null,
                      helperStyle: const TextStyle(fontSize: 11, color: kGreen),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
                    ),
                    onChanged: (v) {
                      final cos = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                      _update(_e.copyWith(terrainCos: cos));
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                const CardDivider(),

                const FieldLabel('Viabilisation'),
                const SizedBox(height: 6),
                ChipGroup(
                  options: const ['Eau', 'Électricité', 'Assainissement', 'Gaz', 'Fibre'],
                  selected: _e.viabilisation,
                  onToggle: (v) {
                    final list = List<String>.from(_e.viabilisation);
                    list.contains(v) ? list.remove(v) : list.add(v);
                    _update(_e.copyWith(viabilisation: list));
                  },
                ),
                const SizedBox(height: 14),

                const FieldLabel('Accès'),
                const SizedBox(height: 6),
                PillSelector(
                  options: const ['Voie publique', 'Chemin privé', 'Impasse'],
                  selected: _e.terrainAcces,
                  onSelect: (v) => _update(_e.copyWith(terrainAcces: _e.terrainAcces == v ? '' : v)),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Pente'),
                const SizedBox(height: 6),
                PillSelector(
                  options: const ['Plat', 'Légère pente', 'Forte pente'],
                  selected: _e.terrainPente,
                  onSelect: (v) => _update(_e.copyWith(terrainPente: _e.terrainPente == v ? '' : v)),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Forme'),
                const SizedBox(height: 6),
                ChipGroup(
                  options: const ['Rectangulaire', 'Irrégulière', 'En drapeau', 'En bande'],
                  selected: _e.terrainForme.isEmpty ? [] : [_e.terrainForme],
                  onToggle: (v) => _update(_e.copyWith(terrainForme: _e.terrainForme == v ? '' : v)),
                ),
                const CardDivider(),

                const FieldLabel('Servitudes / contraintes'),
                const SizedBox(height: 6),
                TextField(
                  controller: _terrainServitudesCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: kCharcoal),
                  decoration: InputDecoration(
                    hintText: 'Ex : servitude de passage, zone inondable, recul PLU…',
                    hintStyle: const TextStyle(color: kLightGrey, fontSize: 12),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
                  ),
                  onChanged: (v) => _update(_e.copyWith(terrainServitudes: v)),
                ),
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

            // Détail technique
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.bathtub_outlined, label: 'Détail technique'),
              Row(children: [
                Expanded(child: StepperField(label: 'Salles de bain', value: _e.nbSallesBain, onChange: (v) => _update(_e.copyWith(nbSallesBain: v < 0 ? 0 : v)))),
                const SizedBox(width: 10),
                Expanded(child: StepperField(label: "Salles d'eau", value: _e.nbSallesEau, onChange: (v) => _update(_e.copyWith(nbSallesEau: v < 0 ? 0 : v)))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StepperField(label: 'WC', value: _e.nbWc, onChange: (v) => _update(_e.copyWith(nbWc: v < 0 ? 0 : v)))),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ]),
              const CardDivider(),
              DropdownField(label: 'Type de cuisine', value: _e.typeCuisine.isEmpty ? 'Non précisé' : _e.typeCuisine, items: _typesCuisine,
                  onChanged: (v) => _update(_e.copyWith(typeCuisine: v == 'Non précisé' ? '' : v))),
              const SizedBox(height: 12),
              DropdownField(label: 'Combles', value: _e.combles.isEmpty ? 'Non précisé' : _e.combles, items: _comblesOptions,
                  onChanged: (v) => _update(_e.copyWith(combles: v == 'Non précisé' ? '' : v))),
            ])),

            // Informations juridiques / cadastre / copropriété
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.gavel_outlined, label: 'Informations juridiques'),
              const FieldLabel('Référence cadastrale'),
              const SizedBox(height: 6),
              TextField(
                controller: _cadastreCtrl,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal),
                decoration: InputDecoration(
                  hintText: 'ex: AB 0123',
                  hintStyle: const TextStyle(color: kLightGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
                ),
                onChanged: (v) => _update(_e.copyWith(referenceCadastrale: v)),
              ),
              if (_e.typeId == 'appartement') ...[
                const SizedBox(height: 12),
                _SurfaceField(
                  label: 'Surface loi Carrez',
                  controller: _carrezCtrl,
                  hint: 'ex: 72',
                  onChanged: (v) => _update(_e.copyWith(surfaceCarrez: v)),
                ),
                const CardDivider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Expanded(child: Text('Bien en copropriété', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal))),
                  Switch(
                    value: _e.enCopropriete,
                    activeColor: kGreen,
                    onChanged: (v) => _update(_e.copyWith(enCopropriete: v)),
                  ),
                ]),
                if (_e.enCopropriete) ...[
                  const SizedBox(height: 4),
                  const Text('Informations ALUR (obligatoires en copropriété)',
                      style: TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  const FieldLabel('Syndic'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _syndicCtrl,
                    style: const TextStyle(fontSize: 14, color: kCharcoal),
                    decoration: InputDecoration(
                      hintText: 'Nom du syndic',
                      hintStyle: const TextStyle(color: kLightGrey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
                    ),
                    onChanged: (v) => _update(_e.copyWith(syndicNom: v)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _NumField(label: 'Nombre de lots', controller: _nbLotsCtrl,
                        onChanged: (v) => _update(_e.copyWith(nombreLots: v)))),
                    const SizedBox(width: 10),
                    Expanded(child: _NumField(label: 'Tantièmes', controller: _tantiemesCtrl,
                        onChanged: (v) => _update(_e.copyWith(tantiemes: v)))),
                  ]),
                  const SizedBox(height: 12),
                  _NumField(label: 'Fonds de travaux (€)', controller: _fondsCtrl, suffix: '€',
                      onChanged: (v) => _update(_e.copyWith(fondsTravaux: v))),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Expanded(child: Text('Procédures en cours', style: TextStyle(fontSize: 13, color: kCharcoal))),
                    Switch(
                      value: _e.coproProceduresEnCours,
                      activeColor: kRed,
                      onChanged: (v) => _update(_e.copyWith(coproProceduresEnCours: v)),
                    ),
                  ]),
                ],
              ],
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

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const FieldLabel('Diagnostic de Performance Énergétique (DPE)'),
                _ScanDpeButton(
                  onDetected: (classe) =>
                      _update(_e.copyWith(dpeClasse: classe)),
                ),
              ]),
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

class _ScanDpeButton extends StatefulWidget {
  final ValueChanged<String> onDetected;
  const _ScanDpeButton({required this.onDetected});
  @override
  State<_ScanDpeButton> createState() => _ScanDpeButtonState();
}

class _ScanDpeButtonState extends State<_ScanDpeButton> {
  bool _loading = false;

  Future<void> _scan(ImageSource src) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: src,
        maxWidth: 2000,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear, // force caméra arrière pour lire l'étiquette DPE
      );
    } catch (e) {
      _showError('Impossible d\'accéder à la photo : $e');
      return;
    }
    if (file == null) return;

    setState(() => _loading = true);
    final result = await DpeOcrService().extractFromImage(file.path);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.hasData) {
      _showError('Aucune information DPE détectée. Réessayez avec une photo plus nette ou cadrée sur l\'étiquette.');
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

  void _showConfirm(DpeOcrResult r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_awesome, size: 20, color: kGreen),
          SizedBox(width: 8),
          Text('DPE détecté', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.classeEnergie != null)
            _resultRow('Classe énergie', r.classeEnergie!, big: true),
          if (r.consoKwh != null)
            _resultRow('Consommation', '${r.consoKwh} kWh/m²/an'),
          if (r.classeGes != null)
            _resultRow('Classe GES', r.classeGes!),
          if (r.emissionsGes != null)
            _resultRow('Émissions', '${r.emissionsGes} kgCO₂/m²/an'),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline, size: 13, color: kGrey),
            const SizedBox(width: 4),
            Text('Confiance : ${(r.confidence * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: kGrey)),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          if (r.classeEnergie != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: () {
                widget.onDetected(r.classeEnergie!);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('DPE classe ${r.classeEnergie} appliqué')),
                );
              },
              child: const Text('Appliquer'),
            ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 18 : 13,
            fontWeight: big ? FontWeight.w800 : FontWeight.w700,
            color: big ? kGreen : kCharcoal,
          ),
        ),
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
            title: const Text('Prendre une photo'),
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
          color: kGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kGreen.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
            )
          else
            const Icon(Icons.document_scanner_outlined, size: 14, color: kGreen),
          const SizedBox(width: 6),
          Text(
            _loading ? 'Analyse…' : 'Scanner',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kGreen),
          ),
        ]),
      ),
    );
  }
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
          Text(
            'Constructible × ${e.parcelleDivisible ? 280 : 100} €/m²  ·  Non-constructible × 8 €/m²',
            style: const TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic),
          ),
        ] else ...[
          const Text('Non précisé → 8 €/m² (zone agricole / naturelle)',
              style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 10),
        // Parcelle divisible
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Flexible(child: Text('Parcelle potentiellement divisible', style: TextStyle(fontSize: 12, color: kCharcoal))),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            child: Switch(
              value: e.parcelleDivisible,
              activeColor: kGreen,
              onChanged: (v) => widget.onChanged(e.copyWith(parcelleDivisible: v)),
            ),
          ),
        ]),
        if (e.parcelleDivisible)
          const Text(
            'Terrain à bâtir détachable → 280 €/m² (vs 100 €/m² non divisible)',
            style: TextStyle(fontSize: 10, color: kGreen, fontStyle: FontStyle.italic),
          ),
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

// ── Détail surfaces par pièce ────────────────────────────────────────────────

class _PiecesSurfacesWidget extends StatefulWidget {
  final List<Map<String, dynamic>> pieces;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  const _PiecesSurfacesWidget({required this.pieces, required this.onChanged});

  @override
  State<_PiecesSurfacesWidget> createState() => _PiecesSurfacesWidgetState();
}

class _PiecesSurfacesWidgetState extends State<_PiecesSurfacesWidget> {
  bool _open = false;

  static const _suggestions = [
    'Séjour', 'Cuisine', 'Chambre 1', 'Chambre 2', 'Chambre 3',
    'Salle de bain', 'WC', 'Entrée', 'Couloir', 'Bureau',
    'Dressing', 'Buanderie', 'Garage', 'Cave',
  ];

  List<Map<String, dynamic>> get _list => List<Map<String, dynamic>>.from(widget.pieces);

  void _add() {
    final list = _list;
    list.add({'nom': '', 'surface': 0.0});
    widget.onChanged(list);
  }

  void _remove(int i) {
    final list = _list;
    list.removeAt(i);
    widget.onChanged(list);
  }

  void _updateNom(int i, String nom) {
    final list = _list;
    list[i] = {'nom': nom, 'surface': list[i]['surface'] ?? 0.0};
    widget.onChanged(list);
  }

  void _updateSurface(int i, double surface) {
    final list = _list;
    list[i] = {'nom': list[i]['nom'] ?? '', 'surface': surface};
    widget.onChanged(list);
  }

  double get _total => widget.pieces.fold(0.0, (s, p) => s + ((p['surface'] as num?)?.toDouble() ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header toggle
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            color: const Color(0xFFF7FAF7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.grid_view_rounded, size: 16, color: kGreen),
                const SizedBox(width: 8),
                const Text('Détail des pièces', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                if (widget.pieces.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: kGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('${widget.pieces.length} pièces · ${total.toStringAsFixed(0)} m²',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGreen)),
                  ),
                ],
              ]),
              Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kLightGrey, size: 18),
            ]),
          ),
        ),

        if (_open) ...[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Ajout rapide : chips des pièces non encore ajoutées
              Builder(builder: (_) {
                final used = widget.pieces
                    .map((p) => ((p['nom'] as String?) ?? '').trim().toLowerCase())
                    .toSet();
                final available =
                    _suggestions.where((s) => !used.contains(s.toLowerCase())).toList();
                if (available.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Ajout rapide',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGrey)),
                    ),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: available.map((s) => GestureDetector(
                        onTap: () {
                          final list = _list;
                          list.add({'nom': s, 'surface': 0.0});
                          widget.onChanged(list);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGreen.withOpacity(0.3)),
                          ),
                          child: Text('+ $s', style: const TextStyle(fontSize: 11, color: kGreen, fontWeight: FontWeight.w600)),
                        ),
                      )).toList(),
                    ),
                  ]),
                );
              }),

              if (widget.pieces.isNotEmpty) ...[
                // Header colonnes
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(flex: 5, child: Text('Pièce', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGrey))),
                    SizedBox(width: 8),
                    SizedBox(width: 80, child: Text('Surface', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGrey), textAlign: TextAlign.center)),
                    SizedBox(width: 32),
                  ]),
                ),

                // Lignes
                ...List.generate(widget.pieces.length, (i) {
                  final p = widget.pieces[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      // Nom
                      Expanded(
                        flex: 5,
                        child: _PieceTextField(
                          initialValue: (p['nom'] as String?) ?? '',
                          suggestions: _suggestions,
                          onChanged: (v) => _updateNom(i, v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Surface
                      SizedBox(
                        width: 80,
                        child: _SurfaceSmallField(
                          initialValue: (p['surface'] as num?)?.toDouble() ?? 0.0,
                          onChanged: (v) => _updateSurface(i, v),
                        ),
                      ),
                      // Supprimer
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: const Icon(Icons.close_rounded, color: kLightGrey),
                          onPressed: () => _remove(i),
                        ),
                      ),
                    ]),
                  );
                }),

                // Total
                if (total > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGreen.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total détaillé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
                      Text('${total.toStringAsFixed(1)} m²',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kGreen)),
                    ]),
                  ),
              ],

              // Bouton ajouter
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _add,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: kGreen.withOpacity(0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, size: 16, color: kGreen),
                    SizedBox(width: 6),
                    Text('Ajouter une pièce', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGreen)),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _PieceTextField extends StatefulWidget {
  final String initialValue;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  const _PieceTextField({required this.initialValue, required this.suggestions, required this.onChanged});

  @override
  State<_PieceTextField> createState() => _PieceTextFieldState();
}

class _PieceTextFieldState extends State<_PieceTextField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: widget.initialValue),
    optionsBuilder: (v) => v.text.isEmpty
        ? widget.suggestions
        : widget.suggestions.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
    onSelected: (s) { _ctrl.text = s; widget.onChanged(s); },
    fieldViewBuilder: (ctx, ctrl, focusNode, onSub) => TextField(
      controller: ctrl,
      focusNode: focusNode,
      style: const TextStyle(fontSize: 13, color: kCharcoal),
      decoration: InputDecoration(
        hintText: 'Séjour, Chambre…',
        hintStyle: const TextStyle(color: kLightGrey, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen, width: 2)),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class _SurfaceSmallField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  const _SurfaceSmallField({required this.initialValue, required this.onChanged});

  @override
  State<_SurfaceSmallField> createState() => _SurfaceSmallFieldState();
}

class _SurfaceSmallFieldState extends State<_SurfaceSmallField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toStringAsFixed(widget.initialValue == widget.initialValue.roundToDouble() ? 0 : 1) : '',
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
    decoration: InputDecoration(
      suffixText: 'm²',
      suffixStyle: const TextStyle(fontSize: 10, color: kGrey),
      hintText: '0',
      hintStyle: const TextStyle(color: kLightGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen, width: 2)),
    ),
    onChanged: (v) => widget.onChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0.0),
  );
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final String? suffix;
  const _NumField({required this.label, required this.controller, required this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel(label),
    const SizedBox(height: 6),
    TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 12, color: kGrey),
        hintText: '0',
        hintStyle: const TextStyle(color: kLightGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
      ),
      onChanged: (v) => onChanged(int.tryParse(v.replaceAll(' ', '')) ?? 0),
    ),
  ]);
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
