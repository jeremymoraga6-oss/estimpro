import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../services/annonce_service.dart';
import '../services/app_settings.dart';
import '../services/concurrence_service.dart';

class AnnonceIaScreen extends StatefulWidget {
  final Estimation estimation;
  const AnnonceIaScreen({super.key, required this.estimation});

  @override
  State<AnnonceIaScreen> createState() => _AnnonceIaScreenState();
}

class _AnnonceIaScreenState extends State<AnnonceIaScreen> {
  AnnonceImmo? _annonce;
  String? _error;
  bool _loading = false;
  // Controllers pour édition inline
  late TextEditingController _titreCtrl;
  late TextEditingController _accrocheCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController();
    _accrocheCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    if (AppSettings.instance.hasAnthropicKey) _generate();
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _accrocheCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await AnnonceService().generate(widget.estimation);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _annonce = r.annonce;
      _error = r.error;
      if (r.annonce != null) {
        _titreCtrl.text = r.annonce!.titre;
        _accrocheCtrl.text = r.annonce!.accroche;
        _descCtrl.text = r.annonce!.description;
      }
    });
  }

  AnnonceImmo? get _currentAnnonce {
    if (_annonce == null) return null;
    return _annonce!.copyWith(
      titre: _titreCtrl.text,
      accroche: _accrocheCtrl.text,
      description: _descCtrl.text,
    );
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié'),
        duration: const Duration(seconds: 2),
        backgroundColor: kGreen,
      ),
    );
  }

  Future<void> _share() async {
    final a = _currentAnnonce;
    if (a == null) return;
    await Share.share(
      a.fullText,
      subject: a.titre.isNotEmpty ? a.titre : 'Annonce immobilière',
    );
  }

  Future<void> _openPortail(ConcurrencePortail p) async {
    final a = _currentAnnonce;
    if (a == null) return;
    // Copie l'annonce avant d'ouvrir le portail
    await Clipboard.setData(ClipboardData(text: a.fullText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Annonce copiée — colle-la sur ${p.nom}'),
          duration: const Duration(seconds: 3),
          backgroundColor: kGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = AppSettings.instance.hasAnthropicKey;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 18),
          SizedBox(width: 8),
          Text('Annonce IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (_annonce != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Régénérer',
              onPressed: _loading ? null : _generate,
            ),
        ],
      ),
      body: !hasKey
          ? _buildNoKey()
          : _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _annonce == null
                      ? _buildInitial()
                      : _buildAnnonce(),
      bottomNavigationBar: _annonce != null && hasKey ? _buildBottomBar() : null,
    );
  }

  Widget _buildNoKey() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.key_rounded, size: 48, color: kAmber),
            const SizedBox(height: 16),
            const Text('Clé API Anthropic manquante',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCharcoal)),
            const SizedBox(height: 8),
            const Text(
              'Pour activer la génération d\'annonce IA, configure ta clé API dans Profil → Clé API Anthropic.',
              style: TextStyle(fontSize: 13, color: kGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crée ta clé sur console.anthropic.com (env. \$5 de crédit suffit pour des centaines d\'annonces).',
              style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );

  Widget _buildLoading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: kGreen),
            SizedBox(height: 16),
            Text('Rédaction en cours…',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCharcoal)),
            SizedBox(height: 4),
            Text('L\'IA analyse les données et écrit ton annonce',
                style: TextStyle(fontSize: 11, color: kGrey)),
          ]),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFC0392B)),
            const SizedBox(height: 16),
            Text(_error ?? 'Erreur inconnue',
                style: const TextStyle(fontSize: 13, color: kCharcoal),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
            ),
          ]),
        ),
      );

  Widget _buildInitial() => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Générer l\'annonce'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            ),
          ),
        ),
      );

  Widget _buildAnnonce() {
    final a = _annonce!;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Titre
        _editableSection('Titre', _titreCtrl, maxLines: 2, onCopy: () => _copy(_titreCtrl.text, 'Titre')),
        if (a.titreAlt1.isNotEmpty || a.titreAlt2.isNotEmpty) ...[
          const SizedBox(height: 6),
          _altTitres([a.titreAlt1, a.titreAlt2]),
        ],
        const SizedBox(height: 14),

        // Accroche
        _editableSection('Accroche', _accrocheCtrl, maxLines: 3, onCopy: () => _copy(_accrocheCtrl.text, 'Accroche')),
        const SizedBox(height: 14),

        // Description
        _editableSection('Description', _descCtrl, maxLines: 12, onCopy: () => _copy(_descCtrl.text, 'Description')),
        const SizedBox(height: 14),

        // Points forts
        if (a.pointsForts.isNotEmpty) ...[
          _sectionLabel('Points forts'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: a.pointsForts.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.check_rounded, color: kGreen, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: kCharcoal))),
                ]),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Hashtags
        if (a.hashtags.isNotEmpty) ...[
          Row(children: [
            _sectionLabel('Hashtags réseaux sociaux'),
            const Spacer(),
            GestureDetector(
              onTap: () => _copy(a.hashtags.join(' '), 'Hashtags'),
              child: const Icon(Icons.copy_rounded, size: 16, color: kGrey),
            ),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Wrap(spacing: 6, runSpacing: 6,
              children: a.hashtags.map((h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGreen)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Version courte LeBonCoin
        if (a.versionCourte.isNotEmpty) ...[
          Row(children: [
            _sectionLabel('Version courte (LeBonCoin)'),
            const Spacer(),
            GestureDetector(
              onTap: () => _copy(a.versionCourte, 'Version courte'),
              child: const Icon(Icons.copy_rounded, size: 16, color: kGrey),
            ),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Text(a.versionCourte, style: const TextStyle(fontSize: 13, color: kCharcoal, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],

        // Copie directe vers portails
        _sectionLabel('Publication multi-portails'),
        const SizedBox(height: 4),
        const Text(
          'Tape un portail → l\'annonce complète est copiée dans le presse-papier, prête à coller.',
          style: TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        ...ConcurrenceService.allPortails(widget.estimation).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _portailBtn(p),
            )),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _portailBtn(ConcurrencePortail p) => GestureDetector(
        onTap: () => _openPortail(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(p.couleur).withOpacity(0.3), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Color(p.couleur), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: const Icon(Icons.public_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                Text(p.description, style: const TextStyle(fontSize: 11, color: kGrey)),
              ]),
            ),
            const Icon(Icons.copy_rounded, color: kLightGrey, size: 18),
          ]),
        ),
      );

  Widget _editableSection(String label, TextEditingController ctrl,
          {required int maxLines, required VoidCallback onCopy}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sectionLabel(label),
          const Spacer(),
          GestureDetector(onTap: onCopy, child: const Icon(Icons.copy_rounded, size: 16, color: kGrey)),
        ]),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 13, color: kCharcoal, height: 1.5),
        ),
      ]);

  Widget _altTitres(List<String> alts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alts.where((a) => a.isNotEmpty).map((alt) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: GestureDetector(
            onTap: () {
              _titreCtrl.text = alt;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 14, color: kGrey),
                const SizedBox(width: 6),
                Expanded(child: Text(alt, style: const TextStyle(fontSize: 12, color: kGrey, fontStyle: FontStyle.italic))),
              ]),
            ),
          ),
        )).toList(),
      );

  Widget _sectionLabel(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGrey, letterSpacing: 0.5)),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
      );

  Widget _buildBottomBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kBorderColor))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(_currentAnnonce?.fullText ?? '', 'Annonce complète'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCharcoal,
                  side: const BorderSide(color: kBorderColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
      );
}
