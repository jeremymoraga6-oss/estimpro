import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/carnet_note.dart';
import '../models/estimation.dart';
import '../theme.dart';
import '../services/voice_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Point d'entrée public
// ─────────────────────────────────────────────────────────────────────────────

/// Ouvre le carnet de visite en bottom sheet plein-écran par-dessus la section
/// courante.  [step] est l'index 0-based (0 = Vendeur … 6 = Photos) ; chaque
/// nouvelle note est automatiquement taguée avec la section active.
Future<void> showCarnetVisite(
  BuildContext context,
  Estimation estimation,
  int step,
  ValueChanged<Estimation> onChanged,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CarnetVisiteSheet(
        estimation: estimation,
        step: step,
        onChanged: onChanged,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CarnetVisiteSheet extends StatefulWidget {
  final Estimation estimation;
  final int step;
  final ValueChanged<Estimation> onChanged;

  const _CarnetVisiteSheet({
    required this.estimation,
    required this.step,
    required this.onChanged,
  });

  @override
  State<_CarnetVisiteSheet> createState() => _CarnetVisiteSheetState();
}

class _CarnetVisiteSheetState extends State<_CarnetVisiteSheet> {
  late List<CarnetNote> _notes;
  late Estimation _e;

  // Saisie en cours
  final _textCtrl = TextEditingController();
  bool _showSketch = false;
  bool _showVoice = false;

  // Strokes du croquis en cours (non encore sauvegardés — correctif 1)
  final List<List<Offset>> _draftStrokes = [];
  List<Offset> _currentStroke = [];

  // Debounce texte (correctif 2)
  Timer? _debounce;

  String get _sectionKey => 'section${widget.step + 1}';
  Color get _sectionColor =>
      widget.step < kSectionColors.length ? kSectionColors[widget.step] : kGreen;
  String get _sectionLabel =>
      widget.step < kSectionLabels.length ? kSectionLabels[widget.step] : '';

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _notes = List<CarnetNote>.from(_e.carnetNotes);
  }

  @override
  void dispose() {
    // Correctif 3 : AUCUN save dans dispose
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  bool get _canAdd =>
      _textCtrl.text.trim().isNotEmpty || _draftStrokes.isNotEmpty;

  void _addNote() {
    if (!_canAdd) return;
    HapticFeedback.lightImpact();
    _debounce?.cancel();

    final note = CarnetNote(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      sectionOrigine: _sectionKey,
      texte: _textCtrl.text.trim(),
      strokesJson: CarnetNote.strokesToJson(List.from(_draftStrokes)),
    );

    final updated = [note, ..._notes];
    final newE = _e.copyWith(carnetNotes: updated);

    setState(() {
      _notes = updated;
      _e = newE;
      _textCtrl.clear();
      _draftStrokes.clear();
      _currentStroke = [];
      _showSketch = false;
      _showVoice = false;
    });
    widget.onChanged(newE);
  }

  void _deleteNote(String id) {
    final updated = _notes.where((n) => n.id != id).toList();
    final newE = _e.copyWith(carnetNotes: updated);
    setState(() { _notes = updated; _e = newE; });
    widget.onChanged(newE);
  }

  // ── Strokes canvas (correctifs 1 & 4) ────────────────────────────────────

  void _strokeStart(Offset pos) =>
      setState(() => _currentStroke = [pos]);

  void _strokeUpdate(Offset pos) =>
      setState(() => _currentStroke.add(pos));

  void _strokeEnd() {
    if (_currentStroke.isNotEmpty) {
      setState(() {
        _draftStrokes.add(List.from(_currentStroke));
        _currentStroke = [];
      });
    }
  }

  // Correctif 4 : pointer annulé (ex. appel téléphonique)
  void _strokeCancel() => setState(() => _currentStroke = []);

  void _undoStroke() {
    if (_draftStrokes.isNotEmpty) setState(() => _draftStrokes.removeLast());
  }

  void _clearStrokes() => setState(() {
        _draftStrokes.clear();
        _currentStroke = [];
      });

  // ── Voice transcript ──────────────────────────────────────────────────────

  void _onTranscript(String text) {
    final cur = _textCtrl.text;
    _textCtrl.text = cur.isEmpty ? text : '$cur\n$text';
    setState(() => _showVoice = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.45, 0.92, 1.0],
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _Handle(),
              _Header(
                noteCount: _notes.length,
                sectionLabel: _sectionLabel,
                sectionColor: _sectionColor,
                onClose: () => Navigator.pop(ctx),
              ),
              Expanded(
                child: _notes.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding:
                            const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        itemCount: _notes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NoteCard(
                          note: _notes[i],
                          onDelete: () => _deleteNote(_notes[i].id),
                        ),
                      ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      );

  // ── Zone de saisie collée en bas ──────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Canvas croquis
              if (_showSketch) ...[
                _SketchCanvas(
                  strokes: _draftStrokes,
                  currentStroke: _currentStroke,
                  onStrokeStart: _strokeStart,
                  onStrokeUpdate: _strokeUpdate,
                  onStrokeEnd: _strokeEnd,
                  onStrokeCancel: _strokeCancel,
                  onUndo: _undoStroke,
                  onClear: _clearStrokes,
                ),
                const SizedBox(height: 8),
              ],

              // Recorder vocal
              if (_showVoice) ...[
                _VoiceRecorder(onTranscript: _onTranscript),
                const SizedBox(height: 8),
              ],

              // Champ texte + boutons
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Tag section
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _sectionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _sectionLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _sectionColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // TextField
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 3,
                      minLines: 1,
                      // Correctif 2 : pas de save direct, debounce 600ms
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 600),
                          () { if (mounted) setState(() {}); },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Observation rapide...',
                        hintStyle:
                            const TextStyle(color: kLightGrey, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style:
                          const TextStyle(fontSize: 13, color: kCharcoal),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Bouton croquis
                  _IconBtn(
                    icon: Icons.draw_outlined,
                    active: _showSketch,
                    activeColor: kGreen,
                    onTap: () => setState(() {
                      _showSketch = !_showSketch;
                      if (_showSketch) _showVoice = false;
                    }),
                  ),
                  const SizedBox(width: 4),

                  // Bouton micro
                  _IconBtn(
                    icon: Icons.mic_none_rounded,
                    active: _showVoice,
                    activeColor: kGreen,
                    onTap: () => setState(() {
                      _showVoice = !_showVoice;
                      if (_showVoice) _showSketch = false;
                    }),
                  ),
                  const SizedBox(width: 4),

                  // Bouton ajouter
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _canAdd ? 1.0 : 0.4,
                    child: GestureDetector(
                      onTap: _addNote,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets de la sheet
// ─────────────────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final int noteCount;
  final String sectionLabel;
  final Color sectionColor;
  final VoidCallback onClose;

  const _Header({
    required this.noteCount,
    required this.sectionLabel,
    required this.sectionColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(
          children: [
            const Text('📓', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Carnet de visite',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kCharcoal),
            ),
            const SizedBox(width: 8),
            if (noteCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$noteCount',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kGreen),
                ),
              ),
            const Spacer(),
            // Section active
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: sectionColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                sectionLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: sectionColor),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, color: kLightGrey, size: 20),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📝', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text(
              'Aucune note pour l\'instant',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kCharcoal),
            ),
            SizedBox(height: 6),
            Text(
              'Saisissez une observation, un croquis\nou une note vocale ci-dessous',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kGrey),
            ),
          ],
        ),
      );
}

class _NoteCard extends StatelessWidget {
  final CarnetNote note;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final time =
        '${note.timestamp.hour.toString().padLeft(2, '0')}:${note.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: note.sectionColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : section tag + heure + delete
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: note.sectionColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    note.sectionLabel,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: note.sectionColor),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: kLightGrey),
                ),
                if (note.hasSketch) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.draw_outlined,
                      size: 12, color: kLightGrey),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: kLightGrey),
                ),
              ],
            ),

            // Texte
            if (note.hasText) ...[
              const SizedBox(height: 6),
              Text(
                note.texte,
                style: const TextStyle(
                    fontSize: 13, color: kCharcoal, height: 1.5),
              ),
            ],

            // Miniature croquis
            if (note.hasSketch) ...[
              const SizedBox(height: 8),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _StrokePainter(strokes: note.strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas croquis (avec correctifs 1, 4)
// ─────────────────────────────────────────────────────────────────────────────

class _SketchCanvas extends StatelessWidget {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;
  final VoidCallback onStrokeCancel; // correctif 4
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _SketchCanvas({
    required this.strokes,
    required this.currentStroke,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onStrokeCancel,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Listener(
              // Correctif 4 : onPointerCancel stoppe le trait proprement
              onPointerDown: (e) => onStrokeStart(e.localPosition),
              onPointerMove: (e) => onStrokeUpdate(e.localPosition),
              onPointerUp: (e) => onStrokeEnd(),
              onPointerCancel: (e) => onStrokeCancel(),
              child: CustomPaint(
                painter: _StrokePainter(
                    strokes: [...strokes, currentStroke]),
                child: strokes.isEmpty && currentStroke.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✏️', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 4),
                            Text(
                              'Dessinez un plan ou une annotation',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: kLightGrey,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CanvasBtn(Icons.undo, false, onUndo),
              const SizedBox(width: 8),
              _CanvasBtn(Icons.delete_outline, false, onClear),
            ],
          ),
        ],
      );
}

class _CanvasBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CanvasBtn(this.icon, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? kGreen.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  active ? kGreen : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
          ),
          child: Icon(icon,
              size: 16, color: active ? kGreen : const Color(0xFF95A5A6)),
        ),
      );
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const _StrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGreen
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      bool first = true;
      for (final pt in stroke) {
        if (first) {
          path.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice recorder (correctif 3 : pas de save dans dispose)
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceRecorder extends StatefulWidget {
  final ValueChanged<String> onTranscript;

  const _VoiceRecorder({required this.onTranscript});

  @override
  State<_VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<_VoiceRecorder> {
  final _voice = VoiceService.instance;
  bool _recording = false;
  bool _processing = false;
  String _partial = '';
  final _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    _voice.init();
  }

  @override
  void dispose() {
    // Correctif 3 : AUCUNE sauvegarde ici
    _sw.stop();
    super.dispose();
  }

  String get _dur {
    final s = _sw.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _start() async {
    if (_recording || _processing) return;
    HapticFeedback.mediumImpact();
    _sw.reset();
    _sw.start();
    setState(() { _recording = true; _partial = ''; });
    await _voice.start(
        onPartial: (t) { if (mounted) setState(() => _partial = t); });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    HapticFeedback.lightImpact();
    _sw.stop();
    setState(() { _recording = false; _processing = true; });
    final (text, _) = await _voice.stop();
    if (!mounted) return;
    setState(() => _processing = false);
    if (text.isNotEmpty) widget.onTranscript(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kGreen)),
          SizedBox(width: 10),
          Text('Transcription en cours…',
              style: TextStyle(fontSize: 12, color: kGrey)),
        ]),
      );
    }

    return Column(
      children: [
        Listener(
          onPointerDown: (_) => _start(),
          onPointerUp: (_) => _stop(),
          // Correctif 4 : annulation pointeur = stop propre
          onPointerCancel: (_) => _stop(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _recording ? 68 : 56,
            height: _recording ? 68 : 56,
            decoration: BoxDecoration(
              color: _recording ? kGreen : const Color(0xFFF0F9F0),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _recording ? kGreen : const Color(0xFFB2DFB2),
                  width: 2),
              boxShadow: _recording
                  ? [
                      BoxShadow(
                          color: kGreen.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 4)
                    ]
                  : null,
            ),
            child: Icon(
              _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _recording ? Colors.white : kGreen,
              size: _recording ? 30 : 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        StreamBuilder<int>(
          stream: _recording
              ? Stream.periodic(const Duration(seconds: 1), (i) => i)
              : const Stream.empty(),
          builder: (_, __) => Text(
            _recording
                ? 'Relâchez pour transcrire · $_dur'
                : 'Maintenez pour enregistrer',
            style: TextStyle(
              fontSize: 11,
              color: _recording ? kGreen : kLightGrey,
              fontWeight:
                  _recording ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (_partial.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FFF7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB2DFB2)),
            ),
            child: Text(
              _partial,
              style: const TextStyle(
                  fontSize: 12,
                  color: kCharcoal,
                  height: 1.5,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton icône de la barre de saisie
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: activeColor.withValues(alpha: 0.4))
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? activeColor : kLightGrey,
          ),
        ),
      );
}
