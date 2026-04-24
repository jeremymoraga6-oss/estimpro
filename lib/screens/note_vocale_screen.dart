import 'package:flutter/material.dart';
import '../models/vendeur_note.dart';
import '../services/voice_service.dart';
import '../theme.dart';

Future<VendeurNote?> showNoteVocaleSheet(
    BuildContext context, VendeurNote? existing) {
  return showModalBottomSheet<VendeurNote>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NoteVocaleSheet(existing: existing),
  );
}

enum _State { idle, recording, processing, done }

class _NoteVocaleSheet extends StatefulWidget {
  final VendeurNote? existing;
  const _NoteVocaleSheet({this.existing});

  @override
  State<_NoteVocaleSheet> createState() => _NoteVocaleSheetState();
}

class _NoteVocaleSheetState extends State<_NoteVocaleSheet>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceService.instance;
  _State _state = _State.idle;
  String _transcript = '';
  String _error = '';
  VendeurNote? _note;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _note = widget.existing;
    if (_note != null) _state = _State.done;
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _voice.init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _state = _State.recording;
      _transcript = '';
      _error = '';
    });
    await _voice.start(
      onPartial: (text) => setState(() => _transcript = text),
    );
  }

  Future<void> _stopRecording() async {
    if (_state != _State.recording) return;
    setState(() => _state = _State.processing);

    final (text, audioPath) = await _voice.stop();
    if (text.isEmpty) {
      setState(() {
        _state = _State.idle;
        _error = 'Aucune parole détectée. Réessayez.';
      });
      return;
    }

    final note = await _voice.structureWithClaude(text, audioPath);
    setState(() {
      _note = note;
      _state = _State.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _state == _State.done ? 0.85 : 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Note vocale vendeur',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kCharcoal)),
                if (_state == _State.done)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _note),
                    child: const Text('Sauvegarder',
                        style: TextStyle(
                            color: kGreen, fontWeight: FontWeight.w700)),
                  )
                else
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: kGrey),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _buildBody(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _State.idle:
      case _State.recording:
        return _buildRecorder();
      case _State.processing:
        return _buildProcessing();
      case _State.done:
        return _buildResults();
    }
  }

  Widget _buildRecorder() {
    final isRec = _state == _State.recording;
    return Column(children: [
      const SizedBox(height: 16),
      Text(
        isRec ? 'Enregistrement en cours…' : 'Maintenez pour enregistrer',
        style: TextStyle(
            fontSize: 14,
            color: isRec ? kGreen : kGrey,
            fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 28),
      // Mic button — hold to record
      GestureDetector(
        onTapDown: (_) => _startRecording(),
        onTapUp: (_) => _stopRecording(),
        onTapCancel: _stopRecording,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: isRec ? _pulse.value : 1.0,
            child: child,
          ),
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRec ? kGreen : const Color(0xFFF0F9F0),
              border: Border.all(
                  color: isRec ? kGreen : const Color(0xFFB2DFB2), width: 2.5),
              boxShadow: isRec
                  ? [BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)]
                  : [],
            ),
            child: Icon(Icons.mic_rounded,
                size: 42, color: isRec ? Colors.white : kGreen),
          ),
        ),
      ),
      const SizedBox(height: 24),
      // Live transcript
      if (_transcript.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FFF7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB2DFB2)),
          ),
          child: Text(_transcript,
              style: const TextStyle(
                  fontSize: 14, color: kCharcoal, height: 1.6)),
        ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(_error,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFFE53935))),
      ],
      const SizedBox(height: 16),
      if (isRec)
        OutlinedButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('Arrêter'),
          style: OutlinedButton.styleFrom(
              foregroundColor: kGreen, side: const BorderSide(color: kGreen)),
        ),
    ]);
  }

  Widget _buildProcessing() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          CircularProgressIndicator(color: kGreen, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Analyse en cours…',
              style: TextStyle(fontSize: 14, color: kGrey)),
          SizedBox(height: 4),
          Text('Structuration par Claude',
              style: TextStyle(fontSize: 12, color: kLightGrey)),
        ]),
      );

  Widget _buildResults() {
    final n = _note!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Re-record button
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _state = _State.idle;
            _transcript = '';
            _note = null;
          }),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Recommencer'),
          style: TextButton.styleFrom(foregroundColor: kGrey),
        ),
      ]),

      // Transcription brute
      if (n.transcription.isNotEmpty) ...[
        _SectionLabel('Transcription brute'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Text(n.transcription,
              style: const TextStyle(
                  fontSize: 12, color: kGrey, height: 1.6,
                  fontStyle: FontStyle.italic)),
        ),
        const SizedBox(height: 16),
      ],

      if (!n.hasStructuredData)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Structuration Claude non disponible (clé API manquante).\nLa transcription brute est conservée.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF795548))),
            ),
          ]),
        ),

      if (n.pointsForts.isNotEmpty) ...[
        _NoteCard(
          color: const Color(0xFFE8F5E9),
          borderColor: kGreen,
          icon: Icons.thumb_up_alt_rounded,
          iconColor: kGreen,
          title: 'Points forts',
          items: n.pointsForts,
        ),
        const SizedBox(height: 10),
      ],
      if (n.pointsFaibles.isNotEmpty) ...[
        _NoteCard(
          color: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFE53935),
          icon: Icons.thumb_down_alt_rounded,
          iconColor: const Color(0xFFE53935),
          title: 'Points faibles',
          items: n.pointsFaibles,
        ),
        const SizedBox(height: 10),
      ],
      if (n.motivationVente.isNotEmpty || n.delaiSouhaite.isNotEmpty) ...[
        _InfoCard(
          color: const Color(0xFFF3E5F5),
          borderColor: const Color(0xFF9C27B0),
          icon: Icons.gps_fixed_rounded,
          iconColor: const Color(0xFF9C27B0),
          title: 'Motivation / Délai',
          rows: [
            if (n.motivationVente.isNotEmpty)
              _Row('Motivation', n.motivationVente),
            if (n.delaiSouhaite.isNotEmpty)
              _Row('Délai souhaité', n.delaiSouhaite),
          ],
        ),
        const SizedBox(height: 10),
      ],
      if (n.prixSouhaite.isNotEmpty) ...[
        _InfoCard(
          color: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFF9A825),
          icon: Icons.euro_rounded,
          iconColor: const Color(0xFFF9A825),
          title: 'Prix souhaité',
          rows: [_Row('Prix vendeur', n.prixSouhaite)],
        ),
        const SizedBox(height: 10),
      ],
      if (n.travauxDeclares.isNotEmpty) ...[
        _InfoCard(
          color: const Color(0xFFFBE9E7),
          borderColor: const Color(0xFFFF7043),
          icon: Icons.construction_rounded,
          iconColor: const Color(0xFFFF7043),
          title: 'Travaux déclarés',
          rows: [_Row('Travaux', n.travauxDeclares)],
        ),
        const SizedBox(height: 10),
      ],
      if (n.situationPersonnelle.isNotEmpty) ...[
        _InfoCard(
          color: const Color(0xFFE3F2FD),
          borderColor: const Color(0xFF1E88E5),
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFF1E88E5),
          title: 'Situation personnelle',
          rows: [_Row('Contexte', n.situationPersonnelle)],
        ),
      ],
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kGrey,
                letterSpacing: 0.5)),
      );
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _NoteCard extends StatelessWidget {
  final Color color, borderColor, iconColor;
  final IconData icon;
  final String title;
  final List<String> items;
  const _NoteCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor)),
          ]),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.circle, size: 6, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 12, color: kCharcoal, height: 1.5))),
                ]),
              )),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  final Color color, borderColor, iconColor;
  final IconData icon;
  final String title;
  final List<_Row> rows;
  const _InfoCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor)),
          ]),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: iconColor.withValues(alpha: 0.8))),
                      Flexible(
                          child: Text(r.value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kCharcoal))),
                    ]),
              )),
        ]),
      );
}
