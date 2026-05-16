import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/estimation.dart';
import '../services/database_service.dart';
import '../theme.dart';
import 'section1_screen.dart';
import 'section2_screen.dart';
import 'section3_screen.dart';
import 'section4_screen.dart';
import 'section5_screen.dart';
import 'section6_screen.dart';
import 'section7_screen.dart';
import 'note_vocale_screen.dart';
import '../services/voice_service.dart';

class EstimationFlow extends StatefulWidget {
  final Estimation? existing;
  const EstimationFlow({super.key, this.existing});

  @override
  State<EstimationFlow> createState() => _EstimationFlowState();
}

class _EstimationFlowState extends State<EstimationFlow> {
  late Estimation _e;
  int _step = 0;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _e = widget.existing!;
    } else {
      final now = DateTime.now();
      final ref = 'EST-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      _e = Estimation(
        id: const Uuid().v4(),
        reference: ref,
        createdAt: now,
        updatedAt: now,
        dateVisite: now,
        validiteJusquau: now.add(const Duration(days: 365)),
      );
      // Sauvegarde immédiate pour ne pas perdre l'estimation si l'user quitte
      _db.saveEstimation(_e);
    }
  }

  Future<void> _onChanged(Estimation updated) async {
    setState(() => _e = updated);
    await _db.saveEstimation(_e);
  }

  /// Applique une extraction IA des champs du bien (depuis note vocale).
  /// N'écrase QUE les champs détectés, conserve les valeurs déjà saisies pour le reste.
  Future<void> _applyBienExtraction(BienExtraction x) async {
    var u = _e;
    if (x.dpeClasse != null) u = u.copyWith(dpeClasse: x.dpeClasse);
    if (x.noteCuisine != null) u = u.copyWith(noteCuisine: x.noteCuisine);
    if (x.noteSol != null) u = u.copyWith(noteSol: x.noteSol);
    if (x.noteSdb != null) u = u.copyWith(noteSdb: x.noteSdb);
    if (x.noteFenetres != null) u = u.copyWith(noteFenetres: x.noteFenetres);
    if (x.noteChauffage != null) u = u.copyWith(noteChauffage: x.noteChauffage);
    if (x.etatGeneral != null) u = u.copyWith(noteEtatPrestation: x.etatGeneral);
    if (x.orientations.isNotEmpty) u = u.copyWith(orientations: x.orientations);
    if (x.ajustEnvironnement != null) u = u.copyWith(ajustEnvironnement: x.ajustEnvironnement);
    // Vue dégagée : pas de champ booléen direct, mais on peut indiquer un ajust positif
    if (x.vueDegagee == true && u.ajustVue == 0) {
      u = u.copyWith(ajustVue: 5.0); // +5% par défaut, l'utilisateur peut ajuster
    }
    await _onChanged(u);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Champs appliqués : ${x.detectedFields.length}'),
          backgroundColor: const Color(0xFF1976D2),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _next() {
    if (_step < 6) setState(() => _step++);
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
    else Navigator.pop(context);
  }

  void _finish() {
    _db.saveEstimation(_e);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: _buildStep()),
      floatingActionButton: _MicFab(
        hasNote: _e.notesVendeur != null,
        onTap: () async {
          final note = await showNoteVocaleSheet(
            context,
            _e.notesVendeur,
            onApplyBien: _applyBienExtraction,
          );
          if (note != null) await _onChanged(_e.copyWith(notesVendeur: note));
        },
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Section1Screen(estimation: _e, onChanged: _onChanged, onNext: _next);
      case 1:
        return Section2Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 2:
        return Section3Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 3:
        return Section4Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 4:
        return Section5Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 5:
        return Section6Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 6:
        return Section7Screen(estimation: _e, onChanged: _onChanged, onPrev: _prev, onFinish: _finish);
      default:
        return Section1Screen(estimation: _e, onChanged: _onChanged, onNext: _next);
    }
  }
}

class _MicFab extends StatelessWidget {
  final bool hasNote;
  final VoidCallback onTap;
  const _MicFab({required this.hasNote, required this.onTap});

  @override
  Widget build(BuildContext context) => FloatingActionButton(
        onPressed: onTap,
        backgroundColor: hasNote ? kGreen : const Color(0xFF37474F),
        tooltip: 'Note vocale vendeur',
        child: Stack(alignment: Alignment.center, children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          if (hasNote)
            Positioned(
              top: 4, right: 4,
              child: Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
        ]),
      );
}
