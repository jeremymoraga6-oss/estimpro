import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Écran principal — liste des 6 simulateurs
// ─────────────────────────────────────────────────────────────────────────────

class SimulateursScreen extends StatelessWidget {
  const SimulateursScreen({super.key});

  static const _tools = [
    _Tool(
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF00897B),
      label: 'Net vendeur',
      sub: 'Prix net perçu après agence et crédit',
      screen: _NetVendeurScreen(),
    ),
    _Tool(
      icon: Icons.percent_rounded,
      color: Color(0xFF1976D2),
      label: 'Frais de notaire',
      sub: 'Ancien / neuf, toutes tranches',
      screen: _FraisNotaireScreen(),
    ),
    _Tool(
      icon: Icons.savings_rounded,
      color: Color(0xFF7B1FA2),
      label: 'Capacité d\'emprunt',
      sub: 'Mensualités, durée, taux, apport',
      screen: _CapaciteEmpruntScreen(),
    ),
    _Tool(
      icon: Icons.trending_up_rounded,
      color: Color(0xFFF57F17),
      label: 'Plus-value immobilière',
      sub: 'Impôt + PS selon durée de détention',
      screen: _PlusValueScreen(),
    ),
    _Tool(
      icon: Icons.apartment_rounded,
      color: Color(0xFFE53935),
      label: 'Rendement locatif',
      sub: 'Brut, net, cash-flow mensuel',
      screen: _RendementLocatifScreen(),
    ),
    _Tool(
      icon: Icons.handshake_rounded,
      color: Color(0xFF546E7A),
      label: 'Frais d\'agence',
      sub: 'Barème progressif · honoraires TTC',
      screen: _FreAgenceScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Simulateurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tools.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = _tools[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => t.screen)),
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
                  decoration: BoxDecoration(
                    color: t.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(t.icon, color: t.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal)),
                  const SizedBox(height: 2),
                  Text(t.sub, style: const TextStyle(fontSize: 12, color: kGrey)),
                ])),
                Icon(Icons.chevron_right_rounded, color: t.color, size: 22),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final Widget screen;
  const _Tool({required this.icon, required this.color, required this.label, required this.sub, required this.screen});
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets communs
// ─────────────────────────────────────────────────────────────────────────────

class _CalcScaffold extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget body;
  const _CalcScaffold({required this.title, required this.accent, required this.body});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          backgroundColor: kCharcoal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: body,
      );
}

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

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.text, {required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _InputRow extends StatelessWidget {
  final String label;
  final String hint;
  final String? suffix;
  final TextEditingController ctrl;
  final bool decimal;
  const _InputRow({required this.label, required this.hint, this.suffix, required this.ctrl, this.decimal = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(flex: 5, child: Text(label, style: const TextStyle(fontSize: 13, color: kCharcoal))),
          Expanded(
            flex: 4,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kLightGrey, fontSize: 12),
                suffixText: suffix,
                suffixStyle: const TextStyle(fontSize: 11, color: kGrey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen, width: 2)),
              ),
            ),
          ),
        ]),
      );
}

class _ResultBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool big;
  const _ResultBox({required this.label, required this.value, this.color, this.big = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: big ? 13 : 12, color: kGrey, fontWeight: big ? FontWeight.w600 : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: big ? 16 : 13, fontWeight: FontWeight.w800, color: color ?? kCharcoal)),
        ]),
      );
}

String _fmtE(double v) {
  if (v == 0) return '—';
  final s = v.round().abs().toString();
  final buf = StringBuffer(v < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202f');
    buf.write(s[i]);
  }
  buf.write(' €');
  return buf.toString();
}

String _fmtPct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} %';

double _parse(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
int _parseInt(TextEditingController c) =>
    int.tryParse(c.text.trim().replaceAll(' ', '')) ?? 0;

// ─────────────────────────────────────────────────────────────────────────────
// 1. NET VENDEUR
// ─────────────────────────────────────────────────────────────────────────────

class _NetVendeurScreen extends StatefulWidget {
  const _NetVendeurScreen();
  @override
  State<_NetVendeurScreen> createState() => _NetVendeurScreenState();
}

class _NetVendeurScreenState extends State<_NetVendeurScreen> {
  static const _accent = Color(0xFF00897B);
  final _prixCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  final _mainleveeCtrl = TextEditingController(text: '800');
  final _autresCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _prixCtrl.dispose(); _creditCtrl.dispose(); _mainleveeCtrl.dispose(); _autresCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prix = _parse(_prixCtrl);
    final fraisAgence = _calcFreAgence(prix);
    final credit = _parse(_creditCtrl);
    final mainlevee = _parse(_mainleveeCtrl);
    final autres = _parse(_autresCtrl);
    final net = prix - fraisAgence - credit - mainlevee - autres;
    final hasPrix = prix > 0;

    return _CalcScaffold(
      title: 'Net vendeur',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Prix de vente', icon: Icons.home_rounded, color: _accent),
              _InputRow(label: 'Prix net vendeur FAI', hint: '350000', suffix: '€', ctrl: _prixCtrl),
              if (hasPrix) ...[
                const Divider(height: 16),
                _ResultBox(label: 'Frais d\'agence estimés', value: _fmtE(fraisAgence),
                    color: const Color(0xFFE67E22)),
                _ResultBox(label: 'Taux effectif', value: _fmtPct(prix > 0 ? fraisAgence / prix * 100 : 0)),
              ],
            ])),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Déductions', icon: Icons.remove_circle_outline_rounded, color: Colors.red.shade700),
              _InputRow(label: 'Capital restant dû', hint: '0', suffix: '€', ctrl: _creditCtrl),
              _InputRow(label: 'Mainlevée hypothèque', hint: '800', suffix: '€', ctrl: _mainleveeCtrl),
              _InputRow(label: 'Autres frais', hint: '0', suffix: '€', ctrl: _autresCtrl),
            ])),
            if (hasPrix)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Résultat', icon: Icons.account_balance_wallet_rounded, color: _accent),
                _ResultBox(label: 'Prix de vente FAI', value: _fmtE(prix)),
                _ResultBox(label: '− Frais d\'agence', value: _fmtE(-fraisAgence), color: Colors.red.shade600),
                if (credit > 0) _ResultBox(label: '− Capital restant dû', value: _fmtE(-credit), color: Colors.red.shade600),
                if (mainlevee > 0) _ResultBox(label: '− Mainlevée', value: _fmtE(-mainlevee), color: Colors.red.shade600),
                if (autres > 0) _ResultBox(label: '− Autres frais', value: _fmtE(-autres), color: Colors.red.shade600),
                const Divider(height: 16),
                _ResultBox(label: '= Net perçu par le vendeur', value: _fmtE(net),
                    color: net >= 0 ? _accent : Colors.red.shade700, big: true),
              ])),
            const _BaremeInfo(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FRAIS D'AGENCE
// ─────────────────────────────────────────────────────────────────────────────

/// Calcule les frais d'agence selon un barème progressif
double _calcFreAgence(double prix) {
  if (prix <= 0) return 0;
  double frais = 0;
  // Barème progressif par tranche :
  // ≤ 100 000 € : 5 %
  // 100 001 – 300 000 € : 4 %
  // > 300 000 € : 3 %
  const t1 = 100000.0;
  const t2 = 300000.0;
  if (prix <= t1) {
    frais = prix * 0.05;
  } else if (prix <= t2) {
    frais = t1 * 0.05 + (prix - t1) * 0.04;
  } else {
    frais = t1 * 0.05 + (t2 - t1) * 0.04 + (prix - t2) * 0.03;
  }
  return max(frais, 5000); // minimum 5 000 €
}

class _FreAgenceScreen extends StatefulWidget {
  const _FreAgenceScreen();
  @override
  State<_FreAgenceScreen> createState() => _FreAgenceScreenState();
}

class _FreAgenceScreenState extends State<_FreAgenceScreen> {
  static const _accent = Color(0xFF546E7A);
  final _prixCtrl = TextEditingController();

  @override
  void dispose() { _prixCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prix = _parse(_prixCtrl);
    final frais = _calcFreAgence(prix);
    final taux = prix > 0 ? frais / prix * 100 : 0.0;
    final prixFai = prix + frais;

    return _CalcScaffold(
      title: 'Frais d\'agence',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Prix de vente net vendeur', icon: Icons.home_rounded, color: _accent),
              _InputRow(label: 'Prix net vendeur', hint: '280000', suffix: '€', ctrl: _prixCtrl),
            ])),
            if (prix > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Résultat', icon: Icons.percent_rounded, color: _accent),
                _ResultBox(label: 'Frais d\'agence TTC', value: _fmtE(frais), color: _accent, big: true),
                _ResultBox(label: 'Taux effectif', value: _fmtPct(taux)),
                const Divider(height: 16),
                _ResultBox(label: 'Prix affiché FAI', value: _fmtE(prixFai), big: true),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Barème progressif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal)),
          const SizedBox(height: 6),
          const Text('≤ 100 000 € : 5 %', style: TextStyle(fontSize: 11, color: kGrey)),
          const Text('100 001 – 300 000 € : 4 %', style: TextStyle(fontSize: 11, color: kGrey)),
          const Text('> 300 000 € : 3 %', style: TextStyle(fontSize: 11, color: kGrey)),
          const Text('Minimum 5 000 €', style: TextStyle(fontSize: 11, color: kGrey)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. FRAIS DE NOTAIRE
// ─────────────────────────────────────────────────────────────────────────────

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
  void dispose() { _prixCtrl.dispose(); super.dispose(); }

  static double _emoluments(double prix) {
    // Barème réglementé dégressif (TVA 20% incluse dans les taux ci-dessous)
    // Tranche 1 : 0 – 6 500 € → 3.945% HT → ×1.2 TTC
    // Tranche 2 : 6 500 – 17 000 € → 1.627% HT
    // Tranche 3 : 17 000 – 60 000 € → 1.085% HT
    // Tranche 4 : > 60 000 € → 0.814% HT
    const tranches = [
      (0.0, 6500.0, 0.03945),
      (6500.0, 17000.0, 0.01627),
      (17000.0, 60000.0, 0.01085),
      (60000.0, double.infinity, 0.00814),
    ];
    double emo = 0;
    for (final (min, max, taux) in tranches) {
      if (prix > min) {
        emo += (prix.clamp(min, max) - min) * taux;
      }
    }
    // +TVA 20%
    emo *= 1.20;
    return max(emo, 90); // minimum légal
  }

  ({double total, double droits, double emoluments, double debours, double csi}) _calc(double prix) {
    final emo = _emoluments(prix);
    // CSI (Contribution de Sécurité Immobilière) = 0.10% min 15 €
    final csi = max(prix * 0.001, 15.0);
    if (_neuf) {
      // Neuf : droits réduits ≈ 0.715%
      final droits = prix * 0.00715;
      const debours = 900.0;
      return (
        total: droits + emo + csi + debours,
        droits: droits,
        emoluments: emo,
        debours: debours,
        csi: csi,
      );
    } else {
      // Ancien : droits de mutation ≈ 5.80% (département 74 + commune + frais d'assiette)
      final droits = prix * 0.0580;
      const debours = 1300.0;
      return (
        total: droits + emo + csi + debours,
        droits: droits,
        emoluments: emo,
        debours: debours,
        csi: csi,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prix = _parse(_prixCtrl);
    final r = prix > 0 ? _calc(prix) : null;

    return _CalcScaffold(
      title: 'Frais de notaire',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Paramètres', icon: Icons.gavel_rounded, color: _accent),
              _InputRow(label: 'Prix d\'acquisition', hint: '320000', suffix: '€', ctrl: _prixCtrl),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Type de bien', style: TextStyle(fontSize: 13, color: kCharcoal)),
                Row(children: [
                  GestureDetector(
                    onTap: () => setState(() => _neuf = false),
                    child: _TypePill(label: 'Ancien', selected: !_neuf, color: _accent),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _neuf = true),
                    child: _TypePill(label: 'Neuf', selected: _neuf, color: _accent),
                  ),
                ]),
              ]),
            ])),
            if (r != null)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Détail des frais', icon: Icons.receipt_long_rounded, color: _accent),
                _ResultBox(label: _neuf ? 'Droits (TVA réduite)' : 'Droits de mutation', value: _fmtE(r.droits)),
                _ResultBox(label: 'Émoluments notaire TTC', value: _fmtE(r.emoluments)),
                _ResultBox(label: 'CSI (sécurité immobilière)', value: _fmtE(r.csi)),
                _ResultBox(label: 'Débours (forfait)', value: _fmtE(r.debours)),
                const Divider(height: 16),
                _ResultBox(label: 'Total frais de notaire', value: _fmtE(r.total), color: _accent, big: true),
                _ResultBox(label: 'Taux effectif', value: _fmtPct(r.total / prix * 100)),
                const Divider(height: 16),
                _ResultBox(label: 'Budget total (achat + notaire)', value: _fmtE(prix + r.total), big: true),
              ])),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Calcul estimatif basé sur les taux en vigueur (Haute-Savoie, dép. 74). '
                'Débours = forfait indicatif. Les frais réels peuvent varier légèrement selon le dossier.',
                style: TextStyle(fontSize: 10, color: kGrey, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  const _TypePill({required this.label, required this.selected, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kGrey)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CAPACITÉ D'EMPRUNT
// ─────────────────────────────────────────────────────────────────────────────

class _CapaciteEmpruntScreen extends StatefulWidget {
  const _CapaciteEmpruntScreen();
  @override
  State<_CapaciteEmpruntScreen> createState() => _CapaciteEmpruntScreenState();
}

class _CapaciteEmpruntScreenState extends State<_CapaciteEmpruntScreen> {
  static const _accent = Color(0xFF7B1FA2);
  final _revenus1Ctrl = TextEditingController();
  final _revenus2Ctrl = TextEditingController();
  final _chargesCtrl = TextEditingController(text: '0');
  final _apportCtrl = TextEditingController(text: '0');
  final _tauxCtrl = TextEditingController(text: '3.5');
  final _dureeCtrl = TextEditingController(text: '20');

  @override
  void dispose() {
    _revenus1Ctrl.dispose(); _revenus2Ctrl.dispose(); _chargesCtrl.dispose();
    _apportCtrl.dispose(); _tauxCtrl.dispose(); _dureeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rev1 = _parse(_revenus1Ctrl);
    final rev2 = _parse(_revenus2Ctrl);
    final revenus = rev1 + rev2;
    final charges = _parse(_chargesCtrl);
    final apport = _parse(_apportCtrl);
    final taux = _parse(_tauxCtrl) / 100;
    final duree = _parseInt(_dureeCtrl);

    final mensualiteMax = revenus * 0.35 - charges;
    final n = duree * 12;
    final tauxM = taux / 12;
    final capaciteCredit = (n > 0 && tauxM > 0 && mensualiteMax > 0)
        ? mensualiteMax * (1 - pow(1 + tauxM, -n)) / tauxM
        : 0.0;
    final budgetTotal = capaciteCredit + apport;
    final fraisNotaire = _FraisNotaireScreenState()._calc(budgetTotal).total;
    final budgetNet = budgetTotal - fraisNotaire;

    return _CalcScaffold(
      title: 'Capacité d\'emprunt',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Revenus', icon: Icons.euro_rounded, color: _accent),
              _InputRow(label: 'Revenus nets empr. 1', hint: '3500', suffix: '€/mois', ctrl: _revenus1Ctrl),
              _InputRow(label: 'Revenus nets empr. 2', hint: '0', suffix: '€/mois', ctrl: _revenus2Ctrl),
              _InputRow(label: 'Charges existantes', hint: '0', suffix: '€/mois', ctrl: _chargesCtrl),
            ])),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Crédit', icon: Icons.account_balance_rounded, color: _accent),
              _InputRow(label: 'Taux d\'intérêt', hint: '3.5', suffix: '%', ctrl: _tauxCtrl, decimal: true),
              _InputRow(label: 'Durée', hint: '20', suffix: 'ans', ctrl: _dureeCtrl),
              _InputRow(label: 'Apport personnel', hint: '0', suffix: '€', ctrl: _apportCtrl),
            ])),
            if (revenus > 0 && capaciteCredit > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Résultat', icon: Icons.savings_rounded, color: _accent),
                _ResultBox(label: 'Mensualité max (35% endettement)', value: _fmtE(mensualiteMax)),
                _ResultBox(label: 'Capacité d\'emprunt', value: _fmtE(capaciteCredit), color: _accent, big: true),
                _ResultBox(label: '+ Apport', value: _fmtE(apport)),
                const Divider(height: 16),
                _ResultBox(label: 'Budget d\'achat total', value: _fmtE(budgetTotal), big: true),
                _ResultBox(label: '− Frais de notaire estimés', value: _fmtE(-fraisNotaire), color: Colors.red.shade600),
                _ResultBox(label: '= Budget net pour le bien', value: _fmtE(budgetNet), color: _accent, big: true),
              ])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PLUS-VALUE IMMOBILIÈRE
// ─────────────────────────────────────────────────────────────────────────────

class _PlusValueScreen extends StatefulWidget {
  const _PlusValueScreen();
  @override
  State<_PlusValueScreen> createState() => _PlusValueScreenState();
}

class _PlusValueScreenState extends State<_PlusValueScreen> {
  static const _accent = Color(0xFFF57F17);
  final _prixVenteCtrl = TextEditingController();
  final _prixAchatCtrl = TextEditingController();
  final _dureeCtrl = TextEditingController();
  final _travauxCtrl = TextEditingController(text: '0');
  // 0 = résidence principale, 1 = secondaire, 2 = locatif
  int _regime = 1;

  @override
  void dispose() {
    _prixVenteCtrl.dispose(); _prixAchatCtrl.dispose();
    _dureeCtrl.dispose(); _travauxCtrl.dispose();
    super.dispose();
  }

  static double _abattIR(int ans) {
    if (ans >= 22) return 1.0;
    if (ans < 6) return 0.0;
    return (ans - 5) * 0.06;
  }

  static double _abattPS(int ans) {
    if (ans >= 30) return 1.0;
    if (ans < 6) return 0.0;
    if (ans <= 21) return (ans - 5) * 0.0165;
    if (ans == 22) return 16 * 0.0165 + 0.016;
    return (16 * 0.0165 + 0.016) + (ans - 22) * 0.09;
  }

  static double _surtaxe(double pv) {
    if (pv <= 50000) return 0;
    double s = 0;
    final tranches = [
      (50000.0, 100000.0, 0.02),
      (100000.0, 150000.0, 0.03),
      (150000.0, 200000.0, 0.04),
      (200000.0, 250000.0, 0.05),
    ];
    for (final (min, max, t) in tranches) {
      if (pv > min) s += (pv.clamp(min, max) - min) * t;
    }
    if (pv > 250000) s += (pv - 250000) * 0.06;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final prixVente = _parse(_prixVenteCtrl);
    final prixAchat = _parse(_prixAchatCtrl);
    final duree = _parseInt(_dureeCtrl);
    final travauxSaisis = _parse(_travauxCtrl);

    // Forfait frais d'acquisition : 7.5% du prix d'achat
    final fraisAcqForft = prixAchat * 0.075;
    // Travaux : réels si > forfait 15% (si > 5 ans)
    final travauxForft = duree >= 5 ? prixAchat * 0.15 : 0.0;
    final travaux = travauxSaisis > 0 ? max(travauxSaisis, travauxForft) : travauxForft;

    final pvBrute = prixVente - prixAchat;
    final pvNette = max(0.0, pvBrute - fraisAcqForft - travaux);

    // Résidence principale → exonérée
    if (_regime == 0) {
      return _buildExonere();
    }

    final abIR = _abattIR(duree);
    final abPS = _abattPS(duree);
    final pvImposableIR = pvNette * (1 - abIR);
    final pvImposablePS = pvNette * (1 - abPS);
    final impotIR = pvImposableIR * 0.19;
    final impotPS = pvImposablePS * 0.172;
    final surtaxe = _surtaxe(pvImposableIR);
    final totalImpot = impotIR + impotPS + surtaxe;
    final netApresImpot = prixVente - totalImpot;

    return _CalcScaffold(
      title: 'Plus-value immobilière',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Régime fiscal', icon: Icons.gavel_rounded, color: _accent),
              ...['Résidence principale', 'Résidence secondaire', 'Locatif / investissement']
                  .asMap().entries.map((e) => RadioListTile<int>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: Text(e.value, style: const TextStyle(fontSize: 13, color: kCharcoal)),
                    value: e.key,
                    groupValue: _regime,
                    activeColor: _accent,
                    onChanged: (v) => setState(() => _regime = v!),
                  )),
            ])),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Données du bien', icon: Icons.home_rounded, color: _accent),
              _InputRow(label: 'Prix de cession', hint: '400000', suffix: '€', ctrl: _prixVenteCtrl),
              _InputRow(label: 'Prix d\'acquisition', hint: '250000', suffix: '€', ctrl: _prixAchatCtrl),
              _InputRow(label: 'Durée de détention', hint: '8', suffix: 'ans', ctrl: _dureeCtrl),
              _InputRow(label: 'Travaux réels', hint: '0', suffix: '€', ctrl: _travauxCtrl),
              if (duree >= 5 && travauxSaisis < travauxForft)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Forfait travaux 15% appliqué : ${_fmtE(travauxForft)}',
                      style: TextStyle(fontSize: 10, color: _accent, fontStyle: FontStyle.italic)),
                ),
            ])),
            if (prixVente > 0 && prixAchat > 0 && pvBrute > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Calcul de la plus-value', icon: Icons.calculate_rounded, color: _accent),
                _ResultBox(label: 'PV brute', value: _fmtE(pvBrute)),
                _ResultBox(label: '− Frais acq. forfait 7.5%', value: _fmtE(-fraisAcqForft), color: Colors.red.shade600),
                _ResultBox(label: '− Travaux', value: _fmtE(-travaux), color: Colors.red.shade600),
                _ResultBox(label: '= PV nette imposable', value: _fmtE(pvNette), big: true),
                const Divider(height: 16),
                _ResultBox(label: 'Abattement IR ($duree ans)', value: _fmtPct(abIR * 100)),
                _ResultBox(label: 'Abattement PS ($duree ans)', value: _fmtPct(abPS * 100)),
                const Divider(height: 16),
                _ResultBox(label: 'Impôt 19% sur ${_fmtE(pvImposableIR)}', value: _fmtE(impotIR)),
                _ResultBox(label: 'Prélèv. sociaux 17.2% sur ${_fmtE(pvImposablePS)}', value: _fmtE(impotPS)),
                if (surtaxe > 0) _ResultBox(label: 'Surtaxe PV élevée', value: _fmtE(surtaxe)),
                const Divider(height: 16),
                _ResultBox(label: 'Total impôt + PS', value: _fmtE(totalImpot), color: Colors.red.shade700, big: true),
                _ResultBox(label: 'Net vendeur après impôt', value: _fmtE(netApresImpot), color: _accent, big: true),
              ])),
            if (prixVente > 0 && prixAchat > 0 && pvBrute <= 0)
              _Card(child: Column(children: [
                const Icon(Icons.check_circle_rounded, color: kGreen, size: 36),
                const SizedBox(height: 8),
                const Text('Moins-value : aucun impôt dû', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
              ])),
          ],
        ),
      ),
    );
  }

  Widget _buildExonere() => _CalcScaffold(
        title: 'Plus-value immobilière',
        accent: _accent,
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Régime fiscal', icon: Icons.gavel_rounded, color: _accent),
            ...['Résidence principale', 'Résidence secondaire', 'Locatif / investissement']
                .asMap().entries.map((e) => RadioListTile<int>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(e.value, style: const TextStyle(fontSize: 13, color: kCharcoal)),
                  value: e.key,
                  groupValue: _regime,
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _regime = v!),
                )),
          ])),
          Container(
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
              Text('La résidence principale est exonérée à 100% de la plus-value immobilière, sans condition de durée de détention.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kGrey, height: 1.5)),
            ]),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. RENDEMENT LOCATIF
// ─────────────────────────────────────────────────────────────────────────────

class _RendementLocatifScreen extends StatefulWidget {
  const _RendementLocatifScreen();
  @override
  State<_RendementLocatifScreen> createState() => _RendementLocatifScreenState();
}

class _RendementLocatifScreenState extends State<_RendementLocatifScreen> {
  static const _accent = Color(0xFFE53935);
  final _prixCtrl = TextEditingController();
  final _travauxCtrl = TextEditingController(text: '0');
  final _loyerCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController(text: '0');
  final _taxeFonciereCtrl = TextEditingController(text: '0');
  final _gestionCtrl = TextEditingController(text: '0');
  final _vacanceCtrl = TextEditingController(text: '1');
  final _mensualiteCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _prixCtrl.dispose(); _travauxCtrl.dispose(); _loyerCtrl.dispose();
    _chargesCtrl.dispose(); _taxeFonciereCtrl.dispose(); _gestionCtrl.dispose();
    _vacanceCtrl.dispose(); _mensualiteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prix = _parse(_prixCtrl);
    final travaux = _parse(_travauxCtrl);
    // Frais notaire calculés automatiquement (ancien)
    final fraisNotaire = prix > 0 ? _FraisNotaireScreenState()._calc(prix).total : 0.0;
    final investTotal = prix + travaux + fraisNotaire;

    final loyerMensuel = _parse(_loyerCtrl);
    final vacanceMois = _parseInt(_vacanceCtrl);
    final loyerEffectif = loyerMensuel * (12 - vacanceMois);
    final gestionPct = _parse(_gestionCtrl) / 100;
    final fraisGestion = loyerEffectif * gestionPct;
    final chargesAnnuelles = _parse(_chargesCtrl) * 12
        + _parse(_taxeFonciereCtrl)
        + fraisGestion;
    final revenuNet = loyerEffectif - chargesAnnuelles;

    final mensualiteCredit = _parse(_mensualiteCtrl);
    final cashFlow = loyerMensuel * (12 - vacanceMois) / 12 - chargesAnnuelles / 12 - mensualiteCredit;

    final rentBrute = investTotal > 0 ? loyerEffectif / investTotal * 100 : 0.0;
    final rentNette = investTotal > 0 ? revenuNet / investTotal * 100 : 0.0;

    return _CalcScaffold(
      title: 'Rendement locatif',
      accent: _accent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Investissement', icon: Icons.real_estate_agent_rounded, color: _accent),
              _InputRow(label: 'Prix d\'achat FAI', hint: '180000', suffix: '€', ctrl: _prixCtrl),
              _InputRow(label: 'Travaux', hint: '0', suffix: '€', ctrl: _travauxCtrl),
              if (prix > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text('Frais de notaire estimés : ${_fmtE(fraisNotaire)}',
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                ),
              if (investTotal > 0)
                _ResultBox(label: 'Investissement total', value: _fmtE(investTotal), color: _accent),
            ])),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle('Loyer & charges', icon: Icons.home_work_rounded, color: _accent),
              _InputRow(label: 'Loyer mensuel HC', hint: '850', suffix: '€/mois', ctrl: _loyerCtrl),
              _InputRow(label: 'Vacance locative', hint: '1', suffix: 'mois/an', ctrl: _vacanceCtrl),
              _InputRow(label: 'Charges propriétaire', hint: '0', suffix: '€/mois', ctrl: _chargesCtrl),
              _InputRow(label: 'Taxe foncière', hint: '0', suffix: '€/an', ctrl: _taxeFonciereCtrl),
              _InputRow(label: 'Frais de gestion', hint: '0', suffix: '%', ctrl: _gestionCtrl, decimal: true),
              _InputRow(label: 'Mensualité crédit', hint: '0', suffix: '€/mois', ctrl: _mensualiteCtrl),
            ])),
            if (investTotal > 0 && loyerMensuel > 0)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Résultat', icon: Icons.bar_chart_rounded, color: _accent),
                _ResultBox(label: 'Loyer annuel effectif', value: _fmtE(loyerEffectif)),
                _ResultBox(label: '− Charges annuelles', value: _fmtE(-chargesAnnuelles), color: Colors.red.shade600),
                const Divider(height: 16),
                _ResultBox(label: 'Rendement brut', value: _fmtPct(rentBrute), color: _accent, big: true),
                _ResultBox(label: 'Rendement net', value: _fmtPct(rentNette), color: _accent, big: true),
                const Divider(height: 16),
                _ResultBox(
                  label: 'Cash-flow mensuel',
                  value: _fmtE(cashFlow),
                  color: cashFlow >= 0 ? kGreen : Colors.red.shade700,
                  big: true,
                ),
                if (cashFlow < 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Effort mensuel de ${_fmtE(cashFlow.abs())} à prévoir.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontStyle: FontStyle.italic)),
                  ),
              ])),
          ],
        ),
      ),
    );
  }
}
