import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS top-level
// ══════════════════════════════════════════════════════════════════════════════

double _calcFreAgence(double prix) {
  if (prix <= 0) return 0;
  const t1 = 100000.0, t2 = 300000.0;
  double f;
  if (prix <= t1)      f = prix * 0.05;
  else if (prix <= t2) f = t1 * 0.05 + (prix - t1) * 0.04;
  else                 f = t1 * 0.05 + (t2 - t1) * 0.04 + (prix - t2) * 0.03;
  return max(f, 5000);
}

// Total frais de notaire (utilisé par capacité d'emprunt & rendement locatif)
double _calcFraisNotaire(double prix, {bool neuf = false}) {
  if (prix <= 0) return 0;
  const tranches = [
    (0.0, 6500.0, 0.03945), (6500.0, 17000.0, 0.01627),
    (17000.0, 60000.0, 0.01085), (60000.0, double.infinity, 0.00814),
  ];
  double emo = 0;
  for (final (mn, mx, t) in tranches) {
    if (prix > mn) emo += (prix.clamp(mn, mx) - mn) * t;
  }
  emo = max(emo * 1.20, 90.0);
  final csi = max(prix * 0.001, 15.0);
  return neuf ? prix * 0.00715 + emo + csi + 900 : prix * 0.0580 + emo + csi + 1300;
}

String _fmtE(double v) {
  if (v == 0) return '—';
  final s = v.round().abs().toString();
  final buf = StringBuffer(v < 0 ? '−\u202f' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202f');
    buf.write(s[i]);
  }
  buf.write('\u202f€');
  return buf.toString();
}

String _fmtPct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} %';

double _parse(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll('\u202f', '').replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

int _parseInt(TextEditingController c) =>
    int.tryParse(c.text.trim().replaceAll(' ', '')) ?? 0;

// ══════════════════════════════════════════════════════════════════════════════
// ÉCRAN LISTE
// ══════════════════════════════════════════════════════════════════════════════

class SimulateursScreen extends StatelessWidget {
  const SimulateursScreen({super.key});

  static const _items = [
    _SimDef(Icons.account_balance_wallet_rounded, Color(0xFF00897B), 'Net vendeur',
        'Montant net perçu après frais d\'agence et crédit'),
    _SimDef(Icons.handshake_rounded, Color(0xFF546E7A), 'Frais d\'agence',
        'Honoraires TTC · barème progressif'),
    _SimDef(Icons.percent_rounded, Color(0xFF1976D2), 'Frais de notaire',
        'Ancien ou neuf · toutes tranches'),
    _SimDef(Icons.savings_rounded, Color(0xFF7B1FA2), 'Capacité d\'emprunt',
        'Mensualités, durée, taux, apport'),
    _SimDef(Icons.trending_up_rounded, Color(0xFFF57F17), 'Plus-value immobilière',
        'Impôt 19 % + PS 17,2 % selon durée de détention'),
    _SimDef(Icons.apartment_rounded, Color(0xFFE53935), 'Rendement locatif',
        'Brut, net de charges, cash-flow mensuel'),
  ];

  static const _screens = [
    _NetVendeurScreen(), _FreAgenceScreen(), _FraisNotaireScreen(),
    _CapaciteEmpruntScreen(), _PlusValueScreen(), _RendementLocatifScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Simulateurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final d = _items[i];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _screens[i])),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: d.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(d.icon, color: d.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal)),
                  const SizedBox(height: 2),
                  Text(d.sub, style: const TextStyle(fontSize: 12, color: kGrey)),
                ])),
                Icon(Icons.chevron_right_rounded, color: d.color, size: 22),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SimDef {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  const _SimDef(this.icon, this.color, this.label, this.sub);
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════════════════

// Scaffold avec bouton retour (automatique) et bouton reset
class _CalcScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onReset;
  const _CalcScaffold({required this.title, required this.body, this.onReset});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBackground,
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      backgroundColor: kCharcoal,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (onReset != null)
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: onReset, tooltip: 'Réinitialiser'),
      ],
    ),
    body: body,
  );
}

// Carte blanche (section)
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );
}

// Titre de section
class _SecTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SecTitle(this.text, {required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// Champ : label au-dessus, pleine largeur
// Corrige le layout 5:4 cramped de l'ancienne _InputRow
class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final String? suffix;
  final TextEditingController ctrl;
  final bool decimal;
  const _Field({required this.label, required this.hint, this.suffix,
      required this.ctrl, this.decimal = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGrey)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 12, color: kGrey, fontWeight: FontWeight.w500),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
        ),
      ),
    ]),
  );
}

// 2 champs côte à côte
class _Fields2 extends StatelessWidget {
  final _Field left;
  final _Field right;
  const _Fields2(this.left, this.right);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: left),
    const SizedBox(width: 10),
    Expanded(child: right),
  ]);
}

// Gros résultat coloré (résultat principal affiché en haut)
class _BigResult extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? note;
  final bool compact; // pour affichage côte à côte
  const _BigResult({required this.label, required this.value, required this.color,
      this.note, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 14 : 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.14), color.withOpacity(0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(fontSize: compact ? 22 : 28, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
      if (note != null) ...[
        const SizedBox(height: 3),
        Text(note!, style: TextStyle(fontSize: 11, color: color.withOpacity(0.75))),
      ],
    ]),
  );
}

// Ligne de détail (label → valeur)
class _Ligne extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  final bool sep;
  const _Ligne({required this.label, required this.value,
      this.color, this.bold = false, this.sep = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    if (sep) const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Divider(height: 1)),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(
          fontSize: 12, color: bold ? kCharcoal : kGrey,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(
          fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? kCharcoal)),
      ]),
    ),
  ]);
}

// Bouton pill sélection (neuf/ancien, régime…)
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: selected ? Colors.white : kGrey)),
    ),
  );
}

// Note d'information grise en bas
class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(fontSize: 10, color: kGrey, height: 1.5)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 1 · NET VENDEUR
// ══════════════════════════════════════════════════════════════════════════════

class _NetVendeurScreen extends StatefulWidget {
  const _NetVendeurScreen();
  @override
  State<_NetVendeurScreen> createState() => _NetVendeurScreenState();
}

class _NetVendeurScreenState extends State<_NetVendeurScreen> {
  static const _accent = Color(0xFF00897B);
  final _prixCtrl      = TextEditingController();
  final _creditCtrl    = TextEditingController();
  final _mainleveeCtrl = TextEditingController(text: '800');
  final _autresCtrl    = TextEditingController(text: '0');

  late final _ctrls = [_prixCtrl, _creditCtrl, _mainleveeCtrl, _autresCtrl];

  @override
  void initState() {
    super.initState();
    for (final c in _ctrls) c.addListener(_u);
  }

  void _u() => setState(() {});

  void _reset() {
    _prixCtrl.clear(); _creditCtrl.clear();
    _mainleveeCtrl.text = '800'; _autresCtrl.text = '0';
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.removeListener(_u); c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prix    = _parse(_prixCtrl);
    final agence  = _calcFreAgence(prix);
    final credit  = _parse(_creditCtrl);
    final mainlev = _parse(_mainleveeCtrl);
    final autres  = _parse(_autresCtrl);
    final net     = prix - agence - credit - mainlev - autres;

    return _CalcScaffold(
      title: 'Net vendeur',
      onReset: _reset,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Résultat principal (live) ──────────────────────────
            if (prix > 0)
              _BigResult(
                label: 'Net vendeur',
                value: _fmtE(net),
                color: net >= 0 ? _accent : Colors.red.shade700,
                note: net >= 0 ? 'Montant perçu après toutes déductions' : 'Attention : solde négatif',
              ),
            // ── Prix de vente ──────────────────────────────────────
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Prix de vente', icon: Icons.home_rounded, color: _accent),
              _Field(label: 'Prix de vente FAI (affiché)', hint: '350 000', suffix: '€', ctrl: _prixCtrl),
              if (prix > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE0B2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Frais d\'agence estimés', style: TextStyle(fontSize: 12, color: kGrey)),
                    Text(_fmtE(agence), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE67E22))),
                  ]),
                ),
            ])),
            // ── Déductions ─────────────────────────────────────────
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Déductions', icon: Icons.remove_circle_outline_rounded, color: Colors.red.shade700),
              _Fields2(
                _Field(label: 'Capital restant dû', hint: '0', suffix: '€', ctrl: _creditCtrl),
                _Field(label: 'Mainlevée hypothèque', hint: '800', suffix: '€', ctrl: _mainleveeCtrl),
              ),
              _Field(label: 'Autres frais', hint: '0', suffix: '€', ctrl: _autresCtrl),
            ])),
            // ── Détail ─────────────────────────────────────────────
            if (prix > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Détail', icon: Icons.receipt_long_rounded, color: _accent),
                _Ligne(label: 'Prix de vente FAI', value: _fmtE(prix)),
                _Ligne(label: '− Frais d\'agence', value: _fmtE(-agence), color: Colors.red.shade600),
                if (credit > 0)  _Ligne(label: '− Capital restant dû', value: _fmtE(-credit), color: Colors.red.shade600),
                if (mainlev > 0) _Ligne(label: '− Mainlevée', value: _fmtE(-mainlev), color: Colors.red.shade600),
                if (autres > 0)  _Ligne(label: '− Autres frais', value: _fmtE(-autres), color: Colors.red.shade600),
                _Ligne(label: '= Net vendeur', value: _fmtE(net),
                    color: net >= 0 ? _accent : Colors.red.shade700, bold: true, sep: true),
              ])),
            const _BaremeInfo(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2 · FRAIS D'AGENCE
// ══════════════════════════════════════════════════════════════════════════════

class _FreAgenceScreen extends StatefulWidget {
  const _FreAgenceScreen();
  @override
  State<_FreAgenceScreen> createState() => _FreAgenceScreenState();
}

class _FreAgenceScreenState extends State<_FreAgenceScreen> {
  static const _accent = Color(0xFF546E7A);
  final _prixCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _prixCtrl.addListener(_u); }
  void _u() => setState(() {});
  @override
  void dispose() { _prixCtrl.removeListener(_u); _prixCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prix  = _parse(_prixCtrl);
    final frais = _calcFreAgence(prix);
    final taux  = prix > 0 ? frais / prix * 100 : 0.0;
    final fai   = prix + frais;

    return _CalcScaffold(
      title: 'Frais d\'agence',
      onReset: () => _prixCtrl.clear(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (prix > 0)
              _BigResult(
                label: 'Frais d\'agence TTC',
                value: _fmtE(frais),
                color: _accent,
                note: 'Taux effectif ${_fmtPct(taux)} · Prix FAI : ${_fmtE(fai)}',
              ),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Prix net vendeur', icon: Icons.home_rounded, color: _accent),
              _Field(label: 'Prix net vendeur (sans frais d\'agence)', hint: '280 000', suffix: '€', ctrl: _prixCtrl),
            ])),
            if (prix > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Résultat', icon: Icons.percent_rounded, color: _accent),
                _Ligne(label: 'Prix net vendeur', value: _fmtE(prix)),
                _Ligne(label: '+ Frais d\'agence TTC', value: _fmtE(frais), color: _accent),
                _Ligne(label: 'Taux effectif', value: _fmtPct(taux)),
                _Ligne(label: '= Prix FAI affiché', value: _fmtE(fai), bold: true, sep: true),
              ])),
            const _BaremeInfo(),
          ],
        ),
      ),
    );
  }
}

class _BaremeInfo extends StatelessWidget {
  const _BaremeInfo();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('Barème progressif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
      SizedBox(height: 6),
      Text('≤ 100 000 € : 5 %',           style: TextStyle(fontSize: 11, color: kGrey)),
      Text('100 001 – 300 000 € : 4 %',   style: TextStyle(fontSize: 11, color: kGrey)),
      Text('> 300 000 € : 3 %',           style: TextStyle(fontSize: 11, color: kGrey)),
      Text('Minimum 5 000 €',             style: TextStyle(fontSize: 11, color: kGrey)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 3 · FRAIS DE NOTAIRE
// ══════════════════════════════════════════════════════════════════════════════

class _FraisNotaireScreen extends StatefulWidget {
  const _FraisNotaireScreen();
  @override
  State<_FraisNotaireScreen> createState() => _FraisNotaireScreenState();
}

class _FraisNotaireScreenState extends State<_FraisNotaireScreen> {
  static const _accent = Color(0xFF1976D2);
  final _prixCtrl = TextEditingController();
  bool _neuf = false;

  @override
  void initState() { super.initState(); _prixCtrl.addListener(_u); }
  void _u() => setState(() {});
  @override
  void dispose() { _prixCtrl.removeListener(_u); _prixCtrl.dispose(); super.dispose(); }

  ({double droits, double emo, double csi, double debours, double total}) _calc(double prix) {
    const tranches = [
      (0.0, 6500.0, 0.03945), (6500.0, 17000.0, 0.01627),
      (17000.0, 60000.0, 0.01085), (60000.0, double.infinity, 0.00814),
    ];
    double emo = 0;
    for (final (mn, mx, t) in tranches) {
      if (prix > mn) emo += (prix.clamp(mn, mx) - mn) * t;
    }
    emo = max(emo * 1.20, 90.0);
    final csi     = max(prix * 0.001, 15.0);
    final droits  = _neuf ? prix * 0.00715 : prix * 0.0580;
    final debours = _neuf ? 900.0 : 1300.0;
    final total   = droits + emo + csi + debours;
    return (droits: droits, emo: emo, csi: csi, debours: debours, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final prix = _parse(_prixCtrl);
    final r    = prix > 0 ? _calc(prix) : null;

    return _CalcScaffold(
      title: 'Frais de notaire',
      onReset: () { _prixCtrl.clear(); setState(() => _neuf = false); },
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (r != null)
              _BigResult(
                label: 'Frais de notaire',
                value: _fmtE(r.total),
                color: _accent,
                note: 'Budget total : ${_fmtE(prix + r.total)} · Taux : ${_fmtPct(r.total / prix * 100)}',
              ),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Paramètres', icon: Icons.gavel_rounded, color: _accent),
              _Field(label: 'Prix d\'acquisition', hint: '320 000', suffix: '€', ctrl: _prixCtrl),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Type de bien', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
                Row(children: [
                  _Pill(label: 'Ancien', selected: !_neuf, color: _accent, onTap: () => setState(() => _neuf = false)),
                  const SizedBox(width: 8),
                  _Pill(label: 'Neuf', selected: _neuf, color: _accent, onTap: () => setState(() => _neuf = true)),
                ]),
              ]),
            ])),
            if (r != null)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Détail', icon: Icons.receipt_long_rounded, color: _accent),
                _Ligne(label: _neuf ? 'Droits (TVA réduite)' : 'Droits de mutation (5,80 %)', value: _fmtE(r.droits)),
                _Ligne(label: 'Émoluments notaire TTC', value: _fmtE(r.emo)),
                _Ligne(label: 'CSI – sécurité immobilière', value: _fmtE(r.csi)),
                _Ligne(label: 'Débours (forfait indicatif)', value: _fmtE(r.debours)),
                _Ligne(label: '= Total frais notaire', value: _fmtE(r.total), color: _accent, bold: true, sep: true),
                _Ligne(label: '= Budget total (achat + frais)', value: _fmtE(prix + r.total), bold: true),
              ])),
            const _InfoNote('Calcul estimatif — Haute-Savoie (dép. 74). Droits ancien = 5,80 %. Débours = forfait indicatif. Les frais réels peuvent légèrement varier selon le dossier.'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4 · CAPACITÉ D'EMPRUNT
// ══════════════════════════════════════════════════════════════════════════════

class _CapaciteEmpruntScreen extends StatefulWidget {
  const _CapaciteEmpruntScreen();
  @override
  State<_CapaciteEmpruntScreen> createState() => _CapaciteEmpruntScreenState();
}

class _CapaciteEmpruntScreenState extends State<_CapaciteEmpruntScreen> {
  static const _accent = Color(0xFF7B1FA2);
  final _rev1Ctrl    = TextEditingController();
  final _rev2Ctrl    = TextEditingController();
  final _chargesCtrl = TextEditingController(text: '0');
  final _apportCtrl  = TextEditingController(text: '0');
  final _tauxCtrl    = TextEditingController(text: '3.5');
  final _dureeCtrl   = TextEditingController(text: '20');

  late final _ctrls = [_rev1Ctrl, _rev2Ctrl, _chargesCtrl, _apportCtrl, _tauxCtrl, _dureeCtrl];

  @override
  void initState() { super.initState(); for (final c in _ctrls) c.addListener(_u); }
  void _u() => setState(() {});
  void _reset() {
    _rev1Ctrl.clear(); _rev2Ctrl.clear(); _chargesCtrl.text = '0';
    _apportCtrl.text = '0'; _tauxCtrl.text = '3.5'; _dureeCtrl.text = '20';
  }
  @override
  void dispose() {
    for (final c in _ctrls) { c.removeListener(_u); c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rev1    = _parse(_rev1Ctrl);
    final rev2    = _parse(_rev2Ctrl);
    final revenus = rev1 + rev2;
    final charges = _parse(_chargesCtrl);
    final apport  = _parse(_apportCtrl);
    final taux    = _parse(_tauxCtrl) / 100;
    final duree   = _parseInt(_dureeCtrl);

    final mensMax = max(0.0, revenus * 0.35 - charges);
    final n       = duree * 12;
    final tauxM   = taux / 12;
    final credit  = (n > 0 && tauxM > 0 && mensMax > 0)
        ? mensMax * (1 - pow(1 + tauxM, -n)) / tauxM
        : 0.0;
    final budgetTotal  = credit + apport;
    final fraisNotaire = _calcFraisNotaire(budgetTotal);
    final budgetBien   = budgetTotal - fraisNotaire;

    return _CalcScaffold(
      title: 'Capacité d\'emprunt',
      onReset: _reset,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (revenus > 0 && credit > 0) ...[
              _BigResult(
                label: 'Capacité d\'emprunt',
                value: _fmtE(credit),
                color: _accent,
                note: 'Budget net pour le bien : ${_fmtE(budgetBien)}',
              ),
              Row(children: [
                Expanded(child: _BigResult(label: 'Mensualité max', value: _fmtE(mensMax), color: const Color(0xFF5E35B1), compact: true)),
                const SizedBox(width: 10),
                Expanded(child: _BigResult(label: 'Budget total', value: _fmtE(budgetTotal), color: const Color(0xFF4527A0), compact: true)),
              ]),
            ],
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Revenus', icon: Icons.euro_rounded, color: _accent),
              _Fields2(
                _Field(label: 'Revenus nets empr. 1', hint: '3 500', suffix: '€/mois', ctrl: _rev1Ctrl),
                _Field(label: 'Revenus nets empr. 2', hint: '0', suffix: '€/mois', ctrl: _rev2Ctrl),
              ),
              _Field(label: 'Charges existantes (crédits en cours)', hint: '0', suffix: '€/mois', ctrl: _chargesCtrl),
            ])),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Financement', icon: Icons.account_balance_rounded, color: _accent),
              _Fields2(
                _Field(label: 'Taux d\'intérêt', hint: '3.5', suffix: '%', ctrl: _tauxCtrl, decimal: true),
                _Field(label: 'Durée', hint: '20', suffix: 'ans', ctrl: _dureeCtrl),
              ),
              _Field(label: 'Apport personnel', hint: '0', suffix: '€', ctrl: _apportCtrl),
            ])),
            if (revenus > 0 && credit > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Détail', icon: Icons.savings_rounded, color: _accent),
                _Ligne(label: 'Revenus totaux', value: _fmtE(revenus)),
                _Ligne(label: 'Mensualité max (35 % endettement)', value: _fmtE(mensMax), bold: true),
                _Ligne(label: 'Capacité d\'emprunt', value: _fmtE(credit), color: _accent, bold: true, sep: true),
                _Ligne(label: '+ Apport', value: _fmtE(apport)),
                _Ligne(label: '= Budget total', value: _fmtE(budgetTotal), bold: true, sep: true),
                _Ligne(label: '− Frais de notaire estimés', value: _fmtE(-fraisNotaire), color: Colors.red.shade600),
                _Ligne(label: '= Budget net pour le bien', value: _fmtE(budgetBien), color: _accent, bold: true, sep: true),
              ])),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 5 · PLUS-VALUE IMMOBILIÈRE
// ══════════════════════════════════════════════════════════════════════════════

class _PlusValueScreen extends StatefulWidget {
  const _PlusValueScreen();
  @override
  State<_PlusValueScreen> createState() => _PlusValueScreenState();
}

class _PlusValueScreenState extends State<_PlusValueScreen> {
  static const _accent = Color(0xFFF57F17);
  final _venteCtrl   = TextEditingController();
  final _achatCtrl   = TextEditingController();
  final _dureeCtrl   = TextEditingController();
  final _travauxCtrl = TextEditingController(text: '0');
  int _regime = 1; // 0=RP, 1=secondaire, 2=locatif

  late final _ctrls = [_venteCtrl, _achatCtrl, _dureeCtrl, _travauxCtrl];

  @override
  void initState() { super.initState(); for (final c in _ctrls) c.addListener(_u); }
  void _u() => setState(() {});
  void _reset() {
    _venteCtrl.clear(); _achatCtrl.clear();
    _dureeCtrl.clear(); _travauxCtrl.text = '0';
    setState(() => _regime = 1);
  }
  @override
  void dispose() {
    for (final c in _ctrls) { c.removeListener(_u); c.dispose(); }
    super.dispose();
  }

  static double _abIR(int ans) {
    if (ans >= 22) return 1.0;
    if (ans < 6) return 0.0;
    return (ans - 5) * 0.06;
  }

  static double _abPS(int ans) {
    if (ans >= 30) return 1.0;
    if (ans < 6) return 0.0;
    if (ans <= 21) return (ans - 5) * 0.0165;
    if (ans == 22) return 16 * 0.0165 + 0.016;
    return 16 * 0.0165 + 0.016 + (ans - 22) * 0.09;
  }

  static double _surtaxe(double pv) {
    if (pv <= 50000) return 0;
    double s = 0;
    const t = [
      (50000.0, 100000.0, 0.02), (100000.0, 150000.0, 0.03),
      (150000.0, 200000.0, 0.04), (200000.0, 250000.0, 0.05),
    ];
    for (final (mn, mx, r) in t) {
      if (pv > mn) s += (pv.clamp(mn, mx) - mn) * r;
    }
    if (pv > 250000) s += (pv - 250000) * 0.06;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final prixVente   = _parse(_venteCtrl);
    final prixAchat   = _parse(_achatCtrl);
    final duree       = _parseInt(_dureeCtrl);
    final travauxReel = _parse(_travauxCtrl);

    final fraisAcq    = prixAchat * 0.075;
    final travauxForf = duree >= 5 ? prixAchat * 0.15 : 0.0;
    final travaux     = travauxReel > 0 ? max(travauxReel, travauxForf) : travauxForf;
    final pvBrute     = prixVente - prixAchat;
    final pvNette     = max(0.0, pvBrute - fraisAcq - travaux);

    final abIR = _abIR(duree);
    final abPS = _abPS(duree);
    final pvIR = pvNette * (1 - abIR);
    final pvPS = pvNette * (1 - abPS);
    final impIR  = pvIR * 0.19;
    final impPS  = pvPS * 0.172;
    final surt   = _regime != 0 ? _surtaxe(pvIR) : 0.0;
    final totalImpot = _regime == 0 ? 0.0 : impIR + impPS + surt;

    final hasData = prixVente > 0 && prixAchat > 0;
    final plusValue = pvBrute > 0;

    return _CalcScaffold(
      title: 'Plus-value immobilière',
      onReset: _reset,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Régime fiscal ──────────────────────────────────────
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Régime fiscal', icon: Icons.gavel_rounded, color: _accent),
              ...{0: 'Résidence principale', 1: 'Résidence secondaire', 2: 'Locatif / investissement'}
                  .entries.map((e) => GestureDetector(
                onTap: () => setState(() => _regime = e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _regime == e.key ? _accent : kLightGrey, width: 2),
                        color: _regime == e.key ? _accent : Colors.transparent,
                      ),
                      child: _regime == e.key
                          ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                    ),
                    const SizedBox(width: 10),
                    Text(e.value, style: TextStyle(
                      fontSize: 13,
                      color: _regime == e.key ? kCharcoal : kGrey,
                      fontWeight: _regime == e.key ? FontWeight.w600 : FontWeight.normal,
                    )),
                  ]),
                ),
              )),
            ])),

            // ── Résidence principale : exonération ────────────────
            if (_regime == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: const Column(children: [
                  Icon(Icons.check_circle_rounded, color: kGreen, size: 44),
                  SizedBox(height: 10),
                  Text('Exonération totale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kGreen)),
                  SizedBox(height: 6),
                  Text('La résidence principale est exonérée à 100 % de la plus-value, sans condition de durée de détention.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kGrey, height: 1.5)),
                ]),
              ),

            if (_regime != 0) ...[
              // ── Résultat principal ─────────────────────────────
              if (hasData && plusValue)
                _BigResult(
                  label: 'Total impôt + prélèvements',
                  value: _fmtE(totalImpot),
                  color: Colors.red.shade700,
                  note: 'Net vendeur après impôt : ${_fmtE(prixVente - totalImpot)}',
                ),
              if (hasData && !plusValue)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, color: kGreen, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Moins-value : aucun impôt dû',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen))),
                  ]),
                ),

              // ── Saisie ─────────────────────────────────────────
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Données du bien', icon: Icons.home_rounded, color: _accent),
                _Fields2(
                  _Field(label: 'Prix de cession', hint: '400 000', suffix: '€', ctrl: _venteCtrl),
                  _Field(label: 'Prix d\'acquisition', hint: '250 000', suffix: '€', ctrl: _achatCtrl),
                ),
                _Fields2(
                  _Field(label: 'Durée de détention', hint: '8', suffix: 'ans', ctrl: _dureeCtrl),
                  _Field(label: 'Travaux réels', hint: '0', suffix: '€', ctrl: _travauxCtrl),
                ),
                if (duree >= 5 && travauxReel < travauxForf && travauxForf > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('✓ Forfait travaux 15 % appliqué : ${_fmtE(travauxForf)}',
                        style: TextStyle(fontSize: 11, color: _accent, fontStyle: FontStyle.italic)),
                  ),
              ])),

              // ── Détail calcul ──────────────────────────────────
              if (hasData && plusValue)
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SecTitle('Calcul de la plus-value', icon: Icons.calculate_rounded, color: _accent),
                  _Ligne(label: 'PV brute', value: _fmtE(pvBrute)),
                  _Ligne(label: '− Frais acq. forfait 7,5 %', value: _fmtE(-fraisAcq), color: Colors.red.shade600),
                  _Ligne(label: '− Travaux', value: _fmtE(-travaux), color: Colors.red.shade600),
                  _Ligne(label: '= PV nette imposable', value: _fmtE(pvNette), bold: true, sep: true),
                  _Ligne(label: 'Abattement IR ($duree ans)', value: _fmtPct(abIR * 100)),
                  _Ligne(label: 'Abattement PS ($duree ans)', value: _fmtPct(abPS * 100)),
                  _Ligne(label: 'Impôt IR 19 %', value: _fmtE(impIR), sep: true),
                  _Ligne(label: 'Prélèvements sociaux 17,2 %', value: _fmtE(impPS)),
                  if (surt > 0) _Ligne(label: 'Surtaxe PV élevée', value: _fmtE(surt)),
                  _Ligne(label: '= Total impôt + PS', value: _fmtE(totalImpot),
                      color: Colors.red.shade700, bold: true, sep: true),
                  _Ligne(label: '= Net vendeur après impôt', value: _fmtE(prixVente - totalImpot),
                      color: _accent, bold: true),
                ])),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 6 · RENDEMENT LOCATIF
// ══════════════════════════════════════════════════════════════════════════════

class _RendementLocatifScreen extends StatefulWidget {
  const _RendementLocatifScreen();
  @override
  State<_RendementLocatifScreen> createState() => _RendementLocatifScreenState();
}

class _RendementLocatifScreenState extends State<_RendementLocatifScreen> {
  static const _accent = Color(0xFFE53935);
  final _prixCtrl       = TextEditingController();
  final _travauxCtrl    = TextEditingController(text: '0');
  final _loyerCtrl      = TextEditingController();
  final _chargesCtrl    = TextEditingController(text: '0');
  final _taxeCtrl       = TextEditingController(text: '0');
  final _gestionCtrl    = TextEditingController(text: '0');
  final _vacanceCtrl    = TextEditingController(text: '1');
  final _mensualiteCtrl = TextEditingController(text: '0');

  late final _ctrls = [_prixCtrl, _travauxCtrl, _loyerCtrl, _chargesCtrl,
                        _taxeCtrl, _gestionCtrl, _vacanceCtrl, _mensualiteCtrl];

  @override
  void initState() { super.initState(); for (final c in _ctrls) c.addListener(_u); }
  void _u() => setState(() {});
  void _reset() {
    _prixCtrl.clear(); _travauxCtrl.text = '0'; _loyerCtrl.clear();
    _chargesCtrl.text = '0'; _taxeCtrl.text = '0'; _gestionCtrl.text = '0';
    _vacanceCtrl.text = '1'; _mensualiteCtrl.text = '0';
  }
  @override
  void dispose() {
    for (final c in _ctrls) { c.removeListener(_u); c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prix         = _parse(_prixCtrl);
    final travaux      = _parse(_travauxCtrl);
    final fraisNot     = _calcFraisNotaire(prix);
    final investTotal  = prix + travaux + fraisNot;

    final loyer        = _parse(_loyerCtrl);
    final vacanceMois  = _parseInt(_vacanceCtrl);
    final loyerAnnuel  = loyer * (12 - vacanceMois);
    final gestionPct   = _parse(_gestionCtrl) / 100;
    final chargesTotal = _parse(_chargesCtrl) * 12 + _parse(_taxeCtrl) + loyerAnnuel * gestionPct;
    final revenuNet    = loyerAnnuel - chargesTotal;
    final mensCredit   = _parse(_mensualiteCtrl);
    final cashflow     = loyerAnnuel / 12 - chargesTotal / 12 - mensCredit;

    final rentBrute = investTotal > 0 && loyerAnnuel > 0 ? loyerAnnuel / investTotal * 100 : 0.0;
    final rentNette = investTotal > 0 && loyer > 0       ? revenuNet   / investTotal * 100 : 0.0;
    final cashflowPos = cashflow >= 0;

    return _CalcScaffold(
      title: 'Rendement locatif',
      onReset: _reset,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (investTotal > 0 && loyer > 0) ...[
              Row(children: [
                Expanded(child: _BigResult(label: 'Rendement brut', value: _fmtPct(rentBrute), color: _accent, compact: true)),
                const SizedBox(width: 10),
                Expanded(child: _BigResult(label: 'Rendement net', value: _fmtPct(rentNette), color: const Color(0xFFB71C1C), compact: true)),
              ]),
              _BigResult(
                label: 'Cash-flow mensuel',
                value: _fmtE(cashflow),
                color: cashflowPos ? kGreen : Colors.red.shade700,
                note: cashflowPos
                    ? 'Investissement autofinancé — excédent de ${_fmtE(cashflow)}/mois'
                    : 'Effort mensuel de ${_fmtE(cashflow.abs())} à prévoir',
              ),
            ],
            // ── Investissement ─────────────────────────────────────
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Investissement', icon: Icons.real_estate_agent_rounded, color: _accent),
              _Fields2(
                _Field(label: 'Prix d\'achat FAI', hint: '180 000', suffix: '€', ctrl: _prixCtrl),
                _Field(label: 'Travaux', hint: '0', suffix: '€', ctrl: _travauxCtrl),
              ),
              if (prix > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Frais de notaire estimés : ${_fmtE(fraisNot)} · Investi total : ${_fmtE(investTotal)}',
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                ),
            ])),
            // ── Loyer & charges ────────────────────────────────────
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SecTitle('Loyer & charges', icon: Icons.home_work_rounded, color: _accent),
              _Fields2(
                _Field(label: 'Loyer mensuel HC', hint: '850', suffix: '€/mois', ctrl: _loyerCtrl),
                _Field(label: 'Vacance locative', hint: '1', suffix: 'mois/an', ctrl: _vacanceCtrl),
              ),
              _Fields2(
                _Field(label: 'Charges propriétaire', hint: '0', suffix: '€/mois', ctrl: _chargesCtrl),
                _Field(label: 'Taxe foncière', hint: '0', suffix: '€/an', ctrl: _taxeCtrl),
              ),
              _Fields2(
                _Field(label: 'Frais de gestion', hint: '0', suffix: '%', ctrl: _gestionCtrl, decimal: true),
                _Field(label: 'Mensualité crédit', hint: '0', suffix: '€/mois', ctrl: _mensualiteCtrl),
              ),
            ])),
            // ── Détail annuel ──────────────────────────────────────
            if (investTotal > 0 && loyer > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SecTitle('Détail annuel', icon: Icons.bar_chart_rounded, color: _accent),
                _Ligne(label: 'Loyer annuel effectif', value: _fmtE(loyerAnnuel)),
                _Ligne(label: '− Charges totales annuelles', value: _fmtE(-chargesTotal), color: Colors.red.shade600),
                _Ligne(label: '= Revenu net annuel', value: _fmtE(revenuNet), bold: true, sep: true),
                _Ligne(label: 'Cash-flow mensuel (après crédit)', value: _fmtE(cashflow),
                    color: cashflowPos ? kGreen : Colors.red.shade700, bold: true, sep: true),
              ])),
          ],
        ),
      ),
    );
  }
}
