import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';
import '../widgets/mes_notes.dart';
import '../widgets/adresse_field.dart';

class Section1Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  const Section1Screen({super.key, required this.estimation, required this.onChanged, required this.onNext});

  @override
  State<Section1Screen> createState() => _Section1ScreenState();
}

class _Section1ScreenState extends State<Section1Screen> {
  late Estimation _e;
  late TextEditingController _nomCtrl, _telCtrl, _emailCtrl;

  final _types = ['maison', 'appartement', 'chalet', 'terrain'];
  final _typeLabels = ['Maison', 'Appartement', 'Chalet', 'Terrain'];
  final _motifs = ['Vente', 'Succession', 'Divorce', 'Donation', 'Autre'];

  @override
  void initState() {
    super.initState();
    _e = widget.estimation;
    _nomCtrl = TextEditingController(text: _e.proprietaireNom);
    _telCtrl = TextEditingController(text: _e.proprietaireTel);
    _emailCtrl = TextEditingController(text: _e.proprietaireEmail);
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _telCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = _e.copyWith(
      proprietaireNom: _nomCtrl.text,
      proprietaireTel: _telCtrl.text,
      proprietaireEmail: _emailCtrl.text,
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          title: 'Nouvelle estimation',
          reference: _e.reference,
          step: 1,
          totalSteps: 7,
          onBack: () => Navigator.pop(context),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(children: [

              // Le bien
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CardTitleRow(icon: Icons.home_rounded, label: 'Le bien'),

                const FieldLabel('Adresse du bien'),
                const SizedBox(height: 5),
                AdresseField(
                  initialValue: _e.adresseComplete,
                  onSelected: (s) => setState(() {
                    _e = _e.copyWith(
                      adresseComplete: s.label,
                      codeInsee: s.codeInsee,
                      codePostal: s.codePostal,
                      latitude: s.latitude,
                      longitude: s.longitude,
                      commune: s.commune,
                    );
                    _save();
                  }),
                ),
                if (_e.codeInsee.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 12, color: kGreen),
                      const SizedBox(width: 4),
                      Text(
                        'INSEE ${_e.codeInsee} · ${_e.commune} · ${_e.codePostal}',
                        style:
                            const TextStyle(fontSize: 11, color: kGreen),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),

                const FieldLabel('Type de bien'),
                const SizedBox(height: 5),
                Row(
                  children: List.generate(_types.length, (i) {
                    final sel = _e.typeId == _types[i];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { _e = _e.copyWith(typeId: _types[i]); _save(); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: i < _types.length - 1 ? 7 : 0),
                          height: 40,
                          decoration: BoxDecoration(
                            color: sel ? kGreen : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: sel ? kGreen : kBorderColor, width: sel ? 0 : 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(_typeLabels[i],
                              style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? Colors.white : kGrey)),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                DropdownField(label: 'Motif', value: _e.motif, items: _motifs,
                    onChanged: (v) => setState(() { _e = _e.copyWith(motif: v); _save(); })),
                const SizedBox(height: 12),

                const FieldLabel('Date de visite'),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _e.dateVisite,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() { _e = _e.copyWith(dateVisite: date); _save(); });
                  },
                  child: Container(
                    height: 46, padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor, width: 1.5),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_fmtDate(_e.dateVisite), style: const TextStyle(fontSize: 14, color: kCharcoal)),
                      const Icon(Icons.calendar_today_outlined, color: kGreen, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                const FieldLabel('Notes générales'),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Observations...', hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
                    contentPadding: const EdgeInsets.all(12),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
                  ),
                  style: const TextStyle(fontSize: 13, color: kCharcoal),
                ),

                MesNotes(
                  sectionKey: 'section1',
                  initialData: _e.notes['section1'] ?? {},
                  onChanged: (data) {
                    final notes = Map<String, Map<String, dynamic>>.from(_e.notes);
                    notes['section1'] = data;
                    _e = _e.copyWith(notes: notes);
                    _save();
                  },
                ),
              ])),

              // Propriétaire
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CardTitleRow(icon: Icons.person_outline_rounded, label: 'Propriétaire'),

                const FieldLabel('Nom complet'),
                _inputField(_nomCtrl, 'M. et Mme...'),
                const SizedBox(height: 12),

                const FieldLabel('Téléphone'),
                _inputField(_telCtrl, '06 XX XX XX XX', keyboard: TextInputType.phone,
                    prefix: const Icon(Icons.phone_outlined, size: 16, color: kGreen)),
                const SizedBox(height: 12),

                const FieldLabel('Email'),
                _inputField(_emailCtrl, 'email@exemple.com', keyboard: TextInputType.emailAddress,
                    prefix: const Icon(Icons.email_outlined, size: 16, color: kGreen)),
              ])),

              // Conseiller
              SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CardTitleRow(icon: Icons.badge_outlined, label: 'Conseiller'),
                const FieldLabel('Nom'),
                _lockedField('Jérémy Moraga'),
                const SizedBox(height: 12),
                const FieldLabel('Agence'),
                _lockedField('Faucigny Immobilier by Efficity'),
              ])),

              const SizedBox(height: 16),
            ]),
          ),
        ),
        SectionBottomBar(onNext: () { _save(); widget.onNext(); }),
      ],
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint,
      {TextInputType keyboard = TextInputType.text, Widget? prefix}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: (_) => _save(),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: kLightGrey, fontSize: 14),
          prefixIcon: prefix, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
        ),
        style: const TextStyle(fontSize: 14, color: kCharcoal),
      );

  Widget _lockedField(String value) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D))),
          const Icon(Icons.lock_outline, size: 14, color: kLightGrey),
        ]),
      );

  String _fmtDate(DateTime d) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
