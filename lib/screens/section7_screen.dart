import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../services/pdf_service.dart';
import '../services/zip_service.dart';
import '../models/carnet_note.dart';
import 'annonce_ia_screen.dart';

const _maxPhotos = 10;

class Section7Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onFinish;
  final ValueChanged<int>? onStepTap;
  const Section7Screen({super.key, required this.estimation, required this.onChanged, required this.onPrev, required this.onFinish, this.onStepTap});

  @override
  State<Section7Screen> createState() => _Section7ScreenState();
}

class _Section7ScreenState extends State<Section7Screen> {
  late Estimation _e;
  bool _generating = false;
  bool _generated = false;
  bool _generatingR2 = false;
  bool _exportingZip = false;
  final _picker = ImagePicker();
  late final TextEditingController _etapesCtrl;

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _etapesCtrl = TextEditingController(text: _e.prochainesEtapes);
  }

  @override
  void dispose() { _etapesCtrl.dispose(); super.dispose(); }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  Future<void> _generatePdf() async {
    setState(() => _generating = true);
    try {
      await PdfService().generate(_e);
      setState(() { _generating = false; _generated = true; });
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  Future<void> _generatePdfR2() async {
    setState(() => _generatingR2 = true);
    try {
      await PdfService().generatePresentation(_e);
      setState(() => _generatingR2 = false);
    } catch (e) {
      setState(() => _generatingR2 = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur PDF R2 : $e')));
    }
  }

  Future<void> _exportZip() async {
    setState(() => _exportingZip = true);
    try {
      await ZipService().exportDossier(_e);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export : $e')));
    } finally {
      if (mounted) setState(() => _exportingZip = false);
    }
  }

  Future<void> _sendEmail() async {
    try {
      await PdfService().sendByEmail(_e);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur email : $e')));
    }
  }

  Future<void> _pickFromCamera() async {
    if (_e.photosPaths.length >= _maxPhotos) return;
    final XFile? img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear, // force caméra arrière
    );
    if (img == null) return;
    final cacheDir = await getTemporaryDirectory();
    final dest = File('${cacheDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(img.path).copy(dest.path);
    final paths = List<String>.from(_e.photosPaths)..add(dest.path);
    _update(_e.copyWith(photosPaths: paths));
  }

  Future<void> _pickFromGallery() async {
    if (_e.photosPaths.length >= _maxPhotos) return;
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90, // galerie : qualité légèrement plus haute (pas de re-compression Android)
    );
    if (img == null) return;
    final cacheDir = await getTemporaryDirectory();
    final dest = File('${cacheDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(img.path).copy(dest.path);
    final paths = List<String>.from(_e.photosPaths)..add(dest.path);
    _update(_e.copyWith(photosPaths: paths));
  }

  void _showAddPhotoSheet() {
    if (_e.photosPaths.length >= _maxPhotos) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
          ),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, color: kGreen, size: 20),
            ),
            title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Caméra arrière', style: TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _pickFromCamera(); },
          ),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1565C0), size: 20),
            ),
            title: const Text('Importer depuis la galerie', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Photos, panoramas…', style: TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _pickFromGallery(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _deletePhoto(int index) async {
    final paths = List<String>.from(_e.photosPaths)..removeAt(index);
    _update(_e.copyWith(photosPaths: paths));
  }

  String _fmt(double n) =>
      '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';

  @override
  Widget build(BuildContext context) {
    final price = _e.prixFinal > 0 ? _e.prixFinal : _e.prixCalcule;
    final checklist = [
      {'label': 'Informations générales', 'status': 'ok', 'detail': _e.typeId},
      {'label': 'Description', 'status': 'ok', 'detail': '${_e.typeId[0].toUpperCase()}${_e.typeId.substring(1)} · ${_e.typeId == 'terrain' ? _e.surfaceTerrain : _e.surfaceHabitable} m²'},
      {'label': 'État & équipements', 'status': 'ok', 'detail': 'DPE ${_e.dpeClasse}'},
      {'label': 'Analyse marché', 'status': 'ok', 'detail': '${_e.comparables.length} comparable${_e.comparables.length > 1 ? 's' : ''}'},
      {'label': 'Estimation', 'status': 'ok', 'detail': _fmt(price)},
      {'label': '${_e.photosPaths.length} photo${_e.photosPaths.length > 1 ? 's' : ''} incluse${_e.photosPaths.length > 1 ? 's' : ''}', 'status': 'ok', 'detail': ''},
      {'label': 'Signature', 'status': 'opt', 'detail': ''},
    ];

    return Column(children: [
      AppHeader(title: 'Photos & PDF', reference: _e.reference, step: 7, totalSteps: 7, onBack: widget.onPrev, onStepTap: widget.onStepTap),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Photos card
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const CardTitleRow(icon: Icons.camera_alt_outlined, label: 'Photos du bien'),
                Text('${_e.photosPaths.length} / $_maxPhotos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
              const SizedBox(height: 12),

              // Photo grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _e.photosPaths.length + (_e.photosPaths.length < _maxPhotos ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _e.photosPaths.length) {
                    return GestureDetector(
                      onTap: _showAddPhotoSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGreen.withValues(alpha: 0.5), width: 2, style: BorderStyle.solid),
                          color: kGreen.withValues(alpha: 0.05),
                        ),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, size: 22, color: kGreen),
                          SizedBox(height: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGreen)),
                        ]),
                      ),
                    );
                  }
                  final path = _e.photosPaths[i];
                  return GestureDetector(
                    onLongPress: () => _confirmDelete(context, i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(color: const Color(0xFFD4C5A9), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.broken_image_outlined, color: Color(0xFF8B7355)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _deletePhoto(i),
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _e.photosPaths.length < _maxPhotos ? _showAddPhotoSheet : null,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: Text(
                    _e.photosPaths.length < _maxPhotos ? 'Ajouter une photo' : 'Maximum atteint ($_maxPhotos photos)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: kGreen, side: const BorderSide(color: kGreen)),
                ),
              ),
            ])),

            // Checklist card
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.description_outlined, label: 'Contenu du rapport'),
              ...checklist.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isOk = item['status'] == 'ok';
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOk ? kGreen.withValues(alpha: 0.1) : const Color(0xFFFFF9E6),
                          border: Border.all(color: isOk ? kGreen : const Color(0xFFF9A825), width: 1.5),
                        ),
                        child: Icon(isOk ? Icons.check : Icons.warning_amber_rounded,
                            size: 12, color: isOk ? kGreen : const Color(0xFFF9A825)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(children: [
                          Text(item['label']!, style: const TextStyle(fontSize: 13, color: kCharcoal, fontWeight: FontWeight.w500)),
                          if ((item['detail'] as String).isNotEmpty)
                            Text(' · ${item['detail']}', style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
                        ]),
                      ),
                      if (!isOk)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFF9E6), border: Border.all(color: const Color(0xFFF9A825)), borderRadius: BorderRadius.circular(6)),
                          child: const Text('OPTIONNEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF9A825))),
                        ),
                    ]),
                  ),
                  if (i < checklist.length - 1) const Divider(height: 1, color: Color(0xFFF5F5F5)),
                ]);
              }),
            ])),

            // Prochaines étapes (affiché en page de synthèse PDF)
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.checklist_outlined, label: 'Prochaines étapes'),
              const SizedBox(height: 4),
              const Text('Affiché en page de synthèse. Laisser vide pour le texte par défaut.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF95A5A6))),
              const SizedBox(height: 10),
              TextFormField(
                controller: _etapesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '1. Validation du prix et signature du mandat\n2. Reportage photo + diffusion sous 7 jours\n3. Premier point hebdomadaire',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFFB2BEC3)),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => _update(_e.copyWith(prochainesEtapes: v)),
              ),
            ])),

            // PDF preview
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.picture_as_pdf_outlined, label: 'Aperçu du rapport'),
              _PdfPreview(estimation: _e),
            ])),

            // Annonce IA
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AnnonceIaScreen(estimation: _e))),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Générer l\'annonce par IA',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Titre + accroche + description prête à publier sur les portails',
                          style: TextStyle(color: Color(0xFFD1E4F7), fontSize: 11)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                ]),
              ),
            ),

            // Carnet de visite (lecture)
            _CarnetCard(notes: _e.carnetNotes),

            const SizedBox(height: 16),
          ]),
        ),
      ),

      // Bottom bar
      Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(children: [
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generatePdf,
              icon: _generating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Icon(_generated ? Icons.check : Icons.picture_as_pdf_outlined, size: 20),
              label: Text(_generating ? 'Génération en cours…' : _generated ? 'PDF généré ✓ — Partager à nouveau' : 'Générer et partager le PDF',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _generated ? const Color(0xFFE8F5E9) : kGreen,
                foregroundColor: _generated ? kGreen : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton.icon(
              onPressed: _generatingR2 ? null : _generatePdfR2,
              icon: _generatingR2
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B1FA2)))
                  : const Icon(Icons.slideshow_outlined, size: 18),
              label: Text(_generatingR2 ? 'Génération…' : 'PDF présentation R2 (sans prix)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7B1FA2),
                side: const BorderSide(color: Color(0xFFCE93D8), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendEmail,
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCharcoal,
                  side: const BorderSide(color: kBorderColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportingZip ? null : _exportZip,
                icon: _exportingZip
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.folder_zip_outlined, size: 18),
                label: Text(_exportingZip ? '…' : 'Dossier ZIP',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5C6BC0),
                  side: const BorderSide(color: Color(0xFF9FA8DA), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deletePhoto(index); },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  final Estimation estimation;
  const _PdfPreview({required this.estimation});

  Widget _blurLine(double w, {double opacity = 0.12}) => Container(
        height: 8, width: w,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(color: kCharcoal.withValues(alpha: opacity), borderRadius: BorderRadius.circular(4)),
      );

  String _fmt(double n) =>
      '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';

  @override
  Widget build(BuildContext context) {
    final price = estimation.prixFinal > 0 ? estimation.prixFinal : estimation.prixCalcule;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: kCharcoal, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FAUCIGNY IMMOBILIER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: 0.8)),
            Text('by Efficity', style: TextStyle(fontSize: 8, color: Color(0xFF95A5A6), letterSpacing: 0.5)),
          ]),
        ]),
        const SizedBox(height: 8),
        Container(height: 2, color: const Color(0xFFC9A84C)),
        const SizedBox(height: 10),
        const Center(child: Text('RAPPORT D\'ESTIMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: 1.0))),
        Center(child: Text('Réf. ${estimation.reference} · ${_fmtDate(estimation.dateVisite)}', style: const TextStyle(fontSize: 9, color: Color(0xFF95A5A6)))),
        const SizedBox(height: 10),
        Container(height: 1, color: const Color(0xFFF0F0F0)),
        const SizedBox(height: 10),
        Text('${estimation.typeId[0].toUpperCase()}${estimation.typeId.substring(1)} · ${estimation.typeId == 'terrain' ? estimation.surfaceTerrain : estimation.surfaceHabitable} m²',
            style: const TextStyle(fontSize: 10, color: kGrey)),
        const SizedBox(height: 4),
        Text(_fmt(price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kGreen)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (ctx, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _blurLine(c.maxWidth * 0.9),
          _blurLine(c.maxWidth * 0.75),
          _blurLine(c.maxWidth * 0.85),
          _blurLine(c.maxWidth * 0.60, opacity: 0.08),
          _blurLine(c.maxWidth * 0.80, opacity: 0.08),
          _blurLine(c.maxWidth * 0.70, opacity: 0.08),
        ])),
        const SizedBox(height: 8),
        const Align(alignment: Alignment.centerRight, child: Text('Page 1 / 8', style: TextStyle(fontSize: 9, color: kLightGrey))),
      ]),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Carte carnet de visite (lecture seule, dépliable) ─────────────────────────

class _CarnetCard extends StatefulWidget {
  final List<CarnetNote> notes;
  const _CarnetCard({required this.notes});

  @override
  State<_CarnetCard> createState() => _CarnetCardState();
}

class _CarnetCardState extends State<_CarnetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: kCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // En-tête dépliable
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Text('📓', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Carnet de visite',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kCharcoal)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.notes.length} note${widget.notes.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kGreen),
                ),
              ),
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: kLightGrey,
                size: 20,
              ),
            ]),
          ),
        ),

        // Liste des notes
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: widget.notes.map((note) {
              final time =
                  '${note.timestamp.hour.toString().padLeft(2, '0')}:${note.timestamp.minute.toString().padLeft(2, '0')}';
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: note.sectionColor, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: note.sectionColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(note.sectionLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: note.sectionColor)),
                      ),
                      const SizedBox(width: 6),
                      Text(time,
                          style: const TextStyle(
                              fontSize: 10, color: kLightGrey)),
                      if (note.hasSketch) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.draw_outlined,
                            size: 12, color: kLightGrey),
                      ],
                    ]),
                    if (note.hasText) ...[
                      const SizedBox(height: 5),
                      Text(note.texte,
                          style: const TextStyle(
                              fontSize: 12, color: kCharcoal, height: 1.5)),
                    ],
                    if (note.hasSketch) ...[
                      const SizedBox(height: 6),
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CustomPaint(
                            painter: _MiniStrokePainter(
                                strokes: note.strokes),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }
}

class _MiniStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _MiniStrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGreen
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      bool first = true;
      for (final pt in stroke) {
        if (first) { path.moveTo(pt.dx, pt.dy); first = false; }
        else { path.lineTo(pt.dx, pt.dy); }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MiniStrokePainter old) => false;
}
