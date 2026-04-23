import 'package:flutter/material.dart';
import '../theme.dart';

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
                  const _VoiceRecorder(),
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
  const _VoiceRecorder();

  @override
  State<_VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<_VoiceRecorder> {
  bool _recording = false;
  bool _hasSaved = false;
  int _seconds = 0;

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  final _bars = [3,6,10,8,5,12,9,7,11,8,6,9,4,11,7,5,10,8,6,9,7,11,5,8,10,7,9,6,4,8];

  @override
  Widget build(BuildContext context) {
    if (_hasSaved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _bars.map((h) => Expanded(
                child: Container(
                  height: h.toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.7), borderRadius: BorderRadius.circular(1)),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmt(_seconds), style: const TextStyle(fontSize: 11, color: kGrey, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() { _hasSaved = false; _seconds = 0; }),
            child: const Icon(Icons.delete_outline, color: kRed, size: 18),
          ),
        ]),
      );
    }

    return Column(children: [
      GestureDetector(
        onTapDown: (_) => setState(() { _recording = true; _seconds = 0; }),
        onTapUp: (_) => setState(() { _recording = false; _hasSaved = _seconds > 0; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _recording ? kRed : kGreen,
            shape: BoxShape.circle,
            boxShadow: _recording ? [BoxShadow(color: kRed.withOpacity(0.4), blurRadius: 16, spreadRadius: 4)] : null,
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 28),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _recording ? 'En cours... ${_fmt(_seconds)}' : 'Appuyer pour enregistrer',
        style: TextStyle(fontSize: 11, color: _recording ? kRed : const Color(0xFF95A5A6), fontWeight: _recording ? FontWeight.w600 : FontWeight.w400),
      ),
    ]);
  }
}
