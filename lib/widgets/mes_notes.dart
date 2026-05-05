import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/voice_service.dart';

class MesNotes extends StatefulWidget {
  final String sectionKey;
  final Map<String, dynamic> initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const MesNotes({super.key, required this.sectionKey, required this.initialData, required this.onChanged});

  @override
  State<MesNotes> createState() => _MesNotesState();
}

class _MesNotesState extends State<MesNotes> {
  bool _open = false;
  bool _saved = false;
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialData['text'] ?? '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onChanged({'text': _textCtrl.text});
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Toggle bar
            GestureDetector(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                height: 48,
                color: const Color(0xFFF0F4EF),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Text('📝', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text('Mes notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                    ]),
                    Row(children: [
                      Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kGreen)),
                      const SizedBox(width: 6),
                      Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kLightGrey, size: 18),
                    ]),
                  ],
                ),
              ),
            ),

            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                color: const Color(0xFFF7F9F6),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Text section
                  Text('TEXTE LIBRE', style: kSectionLabel),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      TextField(
                        controller: _textCtrl,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Vos observations personnelles...',
                          hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
                          counterText: '',
                          contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                        ),
                        style: const TextStyle(fontSize: 13, color: kCharcoal, height: 1.6),
                        onChanged: (_) => setState(() {}),
                      ),
                      Positioned(
                        bottom: 8, right: 10,
                        child: Text('${_textCtrl.text.length} / 500', style: const TextStyle(fontSize: 10, color: kLightGrey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sketch section
                  Text('CROQUIS / PLAN', style: kSectionLabel),
                  const SizedBox(height: 8),
                  _SketchCanvas(),
                  const SizedBox(height: 16),

                  // Voice section
                  Text('NOTE VOCALE', style: kSectionLabel),
                  const SizedBox(height: 8),
                  _VoiceRecorder(onTranscript: (t) {
                    final cur = _textCtrl.text;
                    _textCtrl.text = cur.isEmpty ? t : '$cur\n$t';
                    setState(() {});
                  }),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(_saved ? Icons.check : Icons.save_outlined, size: 16),
                      label: Text(_saved ? 'Sauvegardé ✓' : 'Sauvegarder les notes',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saved ? const Color(0xFFE8F5E9) : kGreen,
                        foregroundColor: _saved ? kGreen : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      );
}

// ── Sketch canvas ─────────────────────────────────────────────
class _SketchCanvas extends StatefulWidget {
  @override
  State<_SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<_SketchCanvas> {
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _current = [];
  bool _hasStrokes = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              onPanStart: (d) {
                _current = [d.localPosition];
                _hasStrokes = true;
                setState(() {});
              },
              onPanUpdate: (d) {
                _current.add(d.localPosition);
                setState(() {});
              },
              onPanEnd: (_) {
                _strokes.add(List.from(_current));
                _current = [];
                setState(() {});
              },
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _SketchPainter(strokes: [..._strokes, _current]),
                    size: Size.infinite,
                  ),
                  if (!_hasStrokes)
                    const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('✏️', style: TextStyle(fontSize: 28)),
                        SizedBox(height: 6),
                        Text('Dessinez un plan ou une annotation', style: TextStyle(fontSize: 11, color: kLightGrey, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _CanvasBtn(Icons.edit, true, () {}),
            const SizedBox(width: 10),
            _CanvasBtn(Icons.undo, false, () => setState(() { if (_strokes.isNotEmpty) { _strokes.removeLast(); _hasStrokes = _strokes.isNotEmpty; } })),
            const SizedBox(width: 10),
            _CanvasBtn(Icons.delete_outline, false, () => setState(() { _strokes.clear(); _current = []; _hasStrokes = false; })),
          ]),
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
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: active ? kGreen.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? kGreen : const Color(0xFFE0E0E0), width: 1.5),
          ),
          child: Icon(icon, size: 16, color: active ? kGreen : const Color(0xFF95A5A6)),
        ),
      );
}

class _SketchPainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  _SketchPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGreen
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      final path = Path();
      bool first = true;
      for (final pt in stroke) {
        if (pt == null) continue;
        if (first) { path.moveTo(pt.dx, pt.dy); first = false; }
        else { path.lineTo(pt.dx, pt.dy); }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) => true;
}

// ── Voice recorder ────────────────────────────────────────────
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
    _sw.reset(); _sw.start();
    setState(() { _recording = true; _partial = ''; });
    await _voice.start(onPartial: (t) { if (mounted) setState(() => _partial = t); });
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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kGreen)),
          SizedBox(width: 10),
          Text('Transcription en cours…', style: TextStyle(fontSize: 12, color: kGrey)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Mic button — Listener for reliable hold detection
      Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _recording ? 72 : 60,
          height: _recording ? 72 : 60,
          decoration: BoxDecoration(
            color: _recording ? kGreen : const Color(0xFFF0F9F0),
            shape: BoxShape.circle,
            border: Border.all(color: _recording ? kGreen : const Color(0xFFB2DFB2), width: 2),
            boxShadow: _recording
                ? [BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 4)]
                : null,
          ),
          child: Icon(
            _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: _recording ? Colors.white : kGreen,
            size: _recording ? 32 : 26,
          ),
        ),
      ),
      const SizedBox(height: 6),
      StreamBuilder<int>(
        stream: _recording ? Stream.periodic(const Duration(seconds: 1), (i) => i) : const Stream.empty(),
        builder: (_, __) => Text(
          _recording ? 'Relâchez pour transcrire · $_dur' : 'Maintenez pour enregistrer',
          style: TextStyle(
            fontSize: 11,
            color: _recording ? kGreen : kLightGrey,
            fontWeight: _recording ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      if (_partial.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FFF7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB2DFB2)),
          ),
          child: Text(_partial, style: const TextStyle(fontSize: 12, color: kCharcoal, height: 1.5, fontStyle: FontStyle.italic)),
        ),
      ],
    ]);
  }
}
