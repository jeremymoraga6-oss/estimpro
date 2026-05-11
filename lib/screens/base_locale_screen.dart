import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/reference_locale.dart';
import '../models/estimation.dart';
import '../services/base_locale_service.dart';
import '../services/database_service.dart';
import '../widgets/shared.dart';

class BaseLocaleScreen extends StatefulWidget {
  const BaseLocaleScreen({super.key});

  @override
  State<BaseLocaleScreen> createState() => _BaseLocaleScreenState();
}

class _BaseLocaleScreenState extends State<BaseLocaleScreen> {
  List<ReferenceLocale> _refs = [];
  bool _loading = true;
  String? _filterCommune;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await BaseLocaleService().loadAll();
    setState(() { _refs = all; _loading = false; });
  }

  List<ReferenceLocale> get _filtered {
    if (_filterCommune == null) return _refs;
    return _refs.where((r) => r.commune == _filterCommune).toList();
  }

  List<String> get _communes =>
      _refs.map((r) => r.commune).where((c) => c.isNotEmpty).toSet().toList()..sort();

  double get _prixM2Moyen {
    final l = _filtered.map((r) => r.prixM2).where((p) => p > 0).toList();
    if (l.isEmpty) return 0;
    return l.reduce((a, b) => a + b) / l.length;
  }

  int get _withEstimeCount =>
      _filtered.where((r) => r.hasEstime).length;

  double get _ecartMoyen {
    final l = _filtered.where((r) => r.hasEstime).map((r) => r.ecartPct).toList();
    if (l.isEmpty) return 0;
    return l.reduce((a, b) => a + b) / l.length;
  }

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  String _fmtDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // Header
        Container(
          color: kCharcoal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ma base locale', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                Text('Ventes validées & calibration', style: TextStyle(fontSize: 12, color: Color(0xFFB2BEC3))),
              ]),
              GestureDetector(
                onTap: () => _showAddForm(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ]),
            if (!_loading && _refs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                _StatPill(value: '${_filtered.length}', label: 'ventes'),
                const SizedBox(width: 8),
                if (_prixM2Moyen > 0)
                  _StatPill(value: '${_prixM2Moyen.round()} €/m²', label: 'prix moyen'),
                const SizedBox(width: 8),
                if (_withEstimeCount > 0) ...[
                  _StatPill(
                    value: '${_ecartMoyen >= 0 ? '+' : ''}${_ecartMoyen.toStringAsFixed(1)}%',
                    label: 'écart moyen',
                    color: _ecartMoyen.abs() < 3 ? kGreen : kAmber,
                  ),
                ],
              ]),
            ],
          ]),
        ),

        // Commune filter chips
        if (_communes.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'Toutes', selected: _filterCommune == null,
                    onTap: () => setState(() => _filterCommune = null)),
                ..._communes.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChip(
                    label: c,
                    selected: _filterCommune == c,
                    onTap: () => setState(() => _filterCommune = _filterCommune == c ? null : c),
                  ),
                )),
              ]),
            ),
          ),

        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : _refs.isEmpty
                  ? _EmptyState(onAdd: () => _showAddForm(context))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final r = _filtered[i];
                          return _RefCard(
                            ref: r,
                            onTap: () => _showEditForm(context, r),
                            onDelete: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Supprimer cette référence ?'),
                                  content: Text('${r.adresse} — ${_fmt(r.prixVente.toDouble())}'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: kRed))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await BaseLocaleService().delete(r.id);
                                _load();
                              }
                            },
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Future<void> _showAddForm(BuildContext context) async {
    final estimations = await DatabaseService().loadAll();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RefForm(
        estimations: estimations,
        onSave: (r) async {
          await BaseLocaleService().save(r);
          _load();
        },
      ),
    );
  }

  Future<void> _showEditForm(BuildContext context, ReferenceLocale ref) async {
    final estimations = await DatabaseService().loadAll();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RefForm(
        initial: ref,
        estimations: estimations,
        onSave: (r) async {
          await BaseLocaleService().save(r);
          _load();
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatPill({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (color ?? Colors.white).withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? Colors.white)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFB2BEC3))),
        ]),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kGreen : kBorderColor, width: 1.5),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : kGrey)),
        ),
      );
}

class _RefCard extends StatelessWidget {
  final ReferenceLocale ref;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RefCard({required this.ref, required this.onTap, required this.onDelete});

  String _fmt(double n) {
    final s = n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  String _fmtDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  IconData _icon(String type) {
    switch (type) {
      case 'appartement': return Icons.apartment_rounded;
      case 'chalet': return Icons.cabin_rounded;
      case 'terrain': return Icons.landscape_rounded;
      default: return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecartColor = ref.ecartPct > 3
        ? kRed
        : ref.ecartPct < -3
            ? kGreen
            : kAmber;

    return Dismissible(
      key: Key(ref.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: kGreen, width: 4)),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(_icon(ref.typeId), color: kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ref.adresse.isEmpty ? 'Adresse non renseignée' : ref.adresse,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
                    overflow: TextOverflow.ellipsis),
                Text('${ref.commune.isNotEmpty ? ref.commune : 'Commune ?'} · ${ref.surface} m² · DPE ${ref.dpeClasse}',
                    style: const TextStyle(fontSize: 11, color: kGrey)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(ref.prixVente.toDouble()),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kGreen)),
                Text('${ref.prixM2.round()} €/m²',
                    style: const TextStyle(fontSize: 11, color: kGrey)),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: kLightGrey),
                const SizedBox(width: 4),
                Text('Vendu ${_fmtDate(ref.dateVente)}',
                    style: const TextStyle(fontSize: 11, color: kLightGrey)),
              ]),
              if (ref.hasEstime) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ecartColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ecartColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'Écart estimé/vendu : ${ref.ecartPct >= 0 ? '+' : ''}${ref.ecartPct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ecartColor),
                  ),
                ]),
              ) else Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
                child: const Text('Sans estimation liée', style: TextStyle(fontSize: 10, color: kLightGrey)),
              ),
            ]),
            if (ref.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ref.notes, style: const TextStyle(fontSize: 11, color: kGrey, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.bookmark_add_outlined, size: 32, color: kGreen),
            ),
            const SizedBox(height: 16),
            const Text('Ma base locale est vide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kCharcoal)),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez vos ventes validées pour calibrer les estimations futures et bâtir votre expertise locale.',
              style: TextStyle(fontSize: 13, color: kGrey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter ma première vente', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );
}

// ── Formulaire ajout/édition ─────────────────────────────────────
class _RefForm extends StatefulWidget {
  final ReferenceLocale? initial;
  final List<Estimation> estimations;
  final ValueChanged<ReferenceLocale> onSave;
  const _RefForm({this.initial, required this.estimations, required this.onSave});

  @override
  State<_RefForm> createState() => _RefFormState();
}

class _RefFormState extends State<_RefForm> {
  late TextEditingController _adresseCtrl;
  late TextEditingController _communeCtrl;
  late TextEditingController _codeInseeCtrl;
  late TextEditingController _surfaceCtrl;
  late TextEditingController _prixVenteCtrl;
  late TextEditingController _prixEstimeCtrl;
  late TextEditingController _notesCtrl;
  late String _typeId;
  late String _dpeClasse;
  late DateTime _dateVente;
  String _linkedEstimationId = '';

  final _types = ['maison', 'appartement', 'chalet', 'terrain'];
  final _dpes = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'NC'];

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _adresseCtrl = TextEditingController(text: r?.adresse ?? '');
    _communeCtrl = TextEditingController(text: r?.commune ?? '');
    _codeInseeCtrl = TextEditingController(text: r?.codeInsee ?? '');
    _surfaceCtrl = TextEditingController(text: r != null && r.surface > 0 ? r.surface.toString() : '');
    _prixVenteCtrl = TextEditingController(text: r != null && r.prixVente > 0 ? r.prixVente.toString() : '');
    _prixEstimeCtrl = TextEditingController(text: r != null && r.prixEstime > 0 ? r.prixEstime.toString() : '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _typeId = r?.typeId ?? 'maison';
    _dpeClasse = r?.dpeClasse ?? 'D';
    _dateVente = r?.dateVente ?? DateTime.now();
    _linkedEstimationId = r?.estimationId ?? '';
  }

  @override
  void dispose() {
    for (final c in [_adresseCtrl, _communeCtrl, _codeInseeCtrl, _surfaceCtrl,
        _prixVenteCtrl, _prixEstimeCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _importFromEstimation(Estimation e) {
    setState(() {
      _adresseCtrl.text = e.adresseComplete.isNotEmpty ? e.adresseComplete : e.proprietaireNom;
      _communeCtrl.text = e.commune;
      _codeInseeCtrl.text = e.codeInsee;
      _surfaceCtrl.text = e.surfaceHabitable.toString();
      _prixEstimeCtrl.text = e.prixCalcule > 0 ? e.prixCalcule.round().toString() : '';
      _typeId = e.typeId;
      _dpeClasse = e.dpeClasse;
      _linkedEstimationId = e.id;
    });
  }

  void _save() {
    final prixVente = int.tryParse(_prixVenteCtrl.text.replaceAll(' ', '')) ?? 0;
    if (prixVente <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prix de vente requis')));
      return;
    }
    final ref = ReferenceLocale(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      adresse: _adresseCtrl.text.trim(),
      commune: _communeCtrl.text.trim(),
      codeInsee: _codeInseeCtrl.text.trim(),
      typeId: _typeId,
      surface: int.tryParse(_surfaceCtrl.text) ?? 100,
      dpeClasse: _dpeClasse,
      prixVente: prixVente,
      dateVente: _dateVente,
      prixEstime: int.tryParse(_prixEstimeCtrl.text.replaceAll(' ', '')) ?? 0,
      notes: _notesCtrl.text.trim(),
      estimationId: _linkedEstimationId,
    );
    widget.onSave(ref);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              widget.initial == null ? 'Nouvelle référence' : 'Modifier la référence',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCharcoal),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kGrey)),
          ]),

          // Importer depuis une estimation
          if (widget.estimations.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showEstimationPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.link_rounded, size: 16, color: kGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _linkedEstimationId.isEmpty
                        ? 'Importer depuis une estimation existante'
                        : 'Lié à une estimation — appuyer pour changer',
                    style: const TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600),
                  )),
                  const Icon(Icons.chevron_right, size: 16, color: kGreen),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Type
          const FieldLabel('Type de bien'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: _types.map((t) {
            final sel = _typeId == t;
            return GestureDetector(
              onTap: () => setState(() => _typeId = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? kGreen : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? kGreen : kBorderColor, width: 1.5),
                ),
                child: Text(t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : kGrey)),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),

          _field(_adresseCtrl, 'Adresse'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_communeCtrl, 'Commune')),
            const SizedBox(width: 10),
            Expanded(child: _field(_codeInseeCtrl, 'Code INSEE')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_surfaceCtrl, 'Surface (m²)', num: true)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('DPE'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _dpeClasse,
                items: _dpes.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _dpeClasse = v ?? 'D'),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 10),

          // Prix
          const FieldLabel('Prix de vente réel (€)'),
          const SizedBox(height: 6),
          TextField(
            controller: _prixVenteCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kGreen),
            decoration: InputDecoration(
              prefixText: '€  ',
              hintText: '250 000',
              hintStyle: const TextStyle(color: kLightGrey, fontWeight: FontWeight.w400, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
            ),
          ),
          const SizedBox(height: 10),

          const FieldLabel('Prix estimé avant vente (€) — optionnel'),
          const SizedBox(height: 4),
          const Text('Laissez vide si vous n\'aviez pas fait d\'estimation',
              style: TextStyle(fontSize: 10, color: kLightGrey, fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          _field(_prixEstimeCtrl, 'ex: 265 000', num: true),
          const SizedBox(height: 10),

          // Date de vente
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dateVente,
                firstDate: DateTime(2018),
                lastDate: DateTime.now(),
                locale: const Locale('fr', 'FR'),
              );
              if (d != null) setState(() => _dateVente = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Date de vente', style: TextStyle(fontSize: 10, color: kGrey)),
                  const SizedBox(height: 2),
                  Text(_fmtDate(_dateVente), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                ]),
                const Icon(Icons.calendar_today_outlined, color: kGreen, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 10),

          _field(_notesCtrl, 'Notes (optionnel)'),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(widget.initial == null ? 'Enregistrer' : 'Mettre à jour',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _field(TextEditingController ctrl, String hint, {bool num = false}) =>
      TextField(
        controller: ctrl,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
        ),
        style: const TextStyle(fontSize: 14, color: kCharcoal),
      );

  void _showEstimationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        children: [
          const Text('Choisir une estimation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
          const SizedBox(height: 12),
          ...widget.estimations.map((e) => ListTile(
            leading: const Icon(Icons.home_outlined, color: kGreen),
            title: Text(e.proprietaireNom.isNotEmpty ? e.proprietaireNom : e.reference,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${e.commune} · ${e.surfaceHabitable} m² · ${e.prixCalcule > 0 ? '${(e.prixCalcule / 1000).round()}k€' : '—'}'),
            onTap: () {
              _importFromEstimation(e);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }
}
