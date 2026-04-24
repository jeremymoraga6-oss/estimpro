import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../services/pdf_service.dart';

class Section7Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onFinish;
  const Section7Screen({super.key, required this.estimation, required this.onChanged, required this.onPrev, required this.onFinish});

  @override
  State<Section7Screen> createState() => _Section7ScreenState();
}

class _Section7ScreenState extends State<Section7Screen> {
  late Estimation _e;
  bool _generating = false;
  bool _generated = false;
  final _picker = ImagePicker();

  @override
  void initState() { super.initState(); _e = widget.estimation; }

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

  Future<void> _sendEmail() async {
    try {
      await PdfService().sendByEmail(_e);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur email : $e')));
    }
  }

  Future<void> _pickFromCamera() async {
    if (_e.photosPaths.length >= 20) return;
    final XFile? img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img != null) {
      final paths = List<String>.from(_e.photosPaths)..add(img.path);
      _update(_e.copyWith(photosPaths: paths));
    }
  }

  Future<void> _pickFromGallery() async {
    if (_e.photosPaths.length >= 20) return;
    final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 85, limit: 20 - _e.photosPaths.length);
    if (imgs.isNotEmpty) {
      final paths = List<String>.from(_e.photosPaths)..addAll(imgs.map((x) => x.path));
      _update(_e.copyWith(photosPaths: paths));
    }
  }

  String _fmt(double n) =>
      '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';

  @override
  Widget build(BuildContext context) {
    final price = _e.prixFinal > 0 ? _e.prixFinal : _e.prixCalcule;
    final checklist = [
      {'label': 'Informations générales', 'status': 'ok', 'detail': _e.typeId},
      {'label': 'Description', 'status': 'ok', 'detail': '${_e.typeId[0].toUpperCase()}${_e.typeId.substring(1)} ${_e.surfaceHabitable} m²'},
      {'label': 'État & équipements', 'status': 'ok', 'detail': 'DPE ${_e.dpeClasse}'},
      {'label': 'Analyse marché', 'status': 'ok', 'detail': '${_e.comparables.length} comparable${_e.comparables.length > 1 ? 's' : ''}'},
      {'label': 'Estimation', 'status': 'ok', 'detail': _fmt(price)},
      {'label': '${_e.photosPaths.length} photo${_e.photosPaths.length > 1 ? 's' : ''} incluse${_e.photosPaths.length > 1 ? 's' : ''}', 'status': 'ok', 'detail': ''},
      {'label': 'Signature', 'status': 'opt', 'detail': ''},
    ];

    return Column(children: [
      AppHeader(title: 'Photos & PDF', reference: _e.reference, step: 7, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(children: [

            // Photos card
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const CardTitleRow(icon: Icons.camera_alt_outlined, label: 'Photos du bien'),
                Text('${_e.photosPaths.length} / 20', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
              const SizedBox(height: 12),

              // Photo grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _e.photosPaths.length + (_e.photosPaths.length < 20 ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _e.photosPaths.length) {
                    return GestureDetector(
                      onTap: () => _showPickerDialog(context),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGreen.withValues(alpha: 0.5), width: 2, style: BorderStyle.solid),
                          color: kGreen.withValues(alpha: 0.05),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, size: 22, color: kGreen),
                          const SizedBox(height: 4),
                          const Text('Ajouter', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGreen)),
                        ]),
                      ),
                    );
                  }
                  final path = _e.photosPaths[i];
                  return Stack(
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
                          onTap: () {
                            final paths = List<String>.from(_e.photosPaths)..removeAt(i);
                            _update(_e.copyWith(photosPaths: paths));
                          },
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Caméra', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: kGreen, side: const BorderSide(color: kGreen)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Galerie', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: kGreen, side: const BorderSide(color: kGreen)),
                  ),
                ),
              ]),
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

            // PDF preview
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitleRow(icon: Icons.picture_as_pdf_outlined, label: 'Aperçu du rapport'),
              _PdfPreview(estimation: _e),
            ])),

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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: _sendEmail,
              icon: const Icon(Icons.email_outlined, size: 18),
              label: const Text('Envoyer par email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kCharcoal,
                side: const BorderSide(color: kBorderColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _showPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: kGreen),
            title: const Text('Appareil photo'),
            onTap: () { Navigator.pop(context); _pickFromCamera(); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: kGreen),
            title: const Text('Galerie photos'),
            onTap: () { Navigator.pop(context); _pickFromGallery(); },
          ),
        ]),
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
        Text('${estimation.typeId[0].toUpperCase()}${estimation.typeId.substring(1)} · ${estimation.surfaceHabitable} m²',
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
