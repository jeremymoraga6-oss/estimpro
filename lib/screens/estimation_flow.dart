import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/carnet_visite.dart';

class EstimationFlow extends StatefulWidget {
  final Estimation? existing;
  const EstimationFlow({super.key, this.existing});

  @override
  State<EstimationFlow> createState() => _EstimationFlowState();
}

class _EstimationFlowState extends State<EstimationFlow>
    with WidgetsBindingObserver {
  late Estimation _e;
  int _step = 0;
  final _db = DatabaseService();

  /// Sauvegarde différée : la saisie déclenche un `onChanged` par caractère,
  /// on regroupe les rafales pour ne pas réécrire tout le fichier à chaque
  /// frappe. Toujours vidé (flush) avant de quitter ou de passer en arrière-plan.
  Timer? _saveTimer;
  static const _saveDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    // L'écran disparaît : on écrit sans attendre (le service sérialise en
    // interne, l'écriture aboutit même après le dispose du widget).
    _saveTimer?.cancel();
    _db.saveEstimation(_e);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android peut tuer l'app en arrière-plan sans autre préavis.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushSave();
    }
  }

  Future<void> _onChanged(Estimation updated) async {
    setState(() => _e = updated);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => _db.saveEstimation(_e));
  }

  /// Force l'écriture immédiate de toute sauvegarde en attente.
  Future<void> _flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    return _db.saveEstimation(_e);
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
    // Dictée pièce par pièce : fusionne avec les pièces déjà saisies
    // (met à jour la surface si la pièce existe déjà, ajoute sinon).
    if (x.piecesSurfaces.isNotEmpty) {
      final merged = List<Map<String, dynamic>>.from(u.piecesSurfaces);
      for (final p in x.piecesSurfaces) {
        final nom = (p['nom'] ?? '').toString().trim();
        if (nom.isEmpty) continue;
        final idx = merged.indexWhere(
          (m) => (m['nom'] ?? '').toString().trim().toLowerCase() == nom.toLowerCase(),
        );
        if (idx >= 0) {
          if (p['surface'] != null) {
            merged[idx] = {...merged[idx], 'surface': p['surface']};
          }
        } else {
          merged.add({'nom': nom, if (p['surface'] != null) 'surface': p['surface']});
        }
      }
      u = u.copyWith(piecesSurfaces: merged);
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
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _goToStep(int step) {
    if (step >= 1 && step <= 7) {
      HapticFeedback.selectionClick();
      setState(() => _step = step - 1);
    }
  }

  void _finish() {
    _flushSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: _buildStep()),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Carnet de visite
          FloatingActionButton.small(
            heroTag: 'carnet',
            tooltip: 'Carnet de visite',
            backgroundColor: _e.carnetNotes.isNotEmpty
                ? kGreen
                : const Color(0xFF37474F),
            onPressed: () => showCarnetVisite(context, _e, _step, (updated) {
              setState(() => _e = updated);
              _flushSave();
            }),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 18),
              if (_e.carnetNotes.isNotEmpty)
                Positioned(
                  top: 3, right: 3,
                  child: Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          // Note vocale vendeur (inchangée)
          _MicFab(
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
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Section1Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onStepTap: _goToStep);
      case 1:
        return Section2Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev, onStepTap: _goToStep);
      case 2:
        return Section3Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev, onStepTap: _goToStep);
      case 3:
        return Section4Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev, onStepTap: _goToStep);
      case 4:
        return Section5Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev, onStepTap: _goToStep);
      case 5:
        return Section6Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev, onStepTap: _goToStep);
      case 6:
        return Section7Screen(estimation: _e, onChanged: _onChanged, onPrev: _prev, onFinish: _finish, onStepTap: _goToStep);
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
