import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/dvf_service.dart';

class MarcheScreen extends StatefulWidget {
  const MarcheScreen({super.key});

  @override
  State<MarcheScreen> createState() => _MarcheScreenState();
}

class _MarcheScreenState extends State<MarcheScreen> {
  final _searchCtrl = TextEditingController();
  List<DvfCommuneStats> _results = [];
  DvfCommuneStats? _selected;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() { _results = []; _selected = null; _error = null; });
      return;
    }
    setState(() { _searching = true; _error = null; });
    final res = await DvfCommuneStatsService.searchByName(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _searching = false;
      if (res.isEmpty) _error = 'Aucune commune trouvée pour "$q"';
    });
  }

  void _select(DvfCommuneStats s) {
    setState(() {
      _selected = s;
      _results = [];
      _searchCtrl.text = s.libelleGeo;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Marché DVF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // ── Barre de recherche ───────────────────────────────────
          Container(
            decoration: kCardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.search_rounded, color: kGreen, size: 18),
                const SizedBox(width: 8),
                const Text('Prix au m² en temps réel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal)),
              ]),
              const SizedBox(height: 4),
              const Text('Données DVF officielles — notaires / DGFIP',
                  style: TextStyle(fontSize: 11, color: kGrey)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14, color: kCharcoal),
                decoration: InputDecoration(
                  hintText: 'Nom de commune (ex: Saint-Pierre-en-Faucigny)',
                  hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
                  prefixIcon: const Icon(Icons.location_city_rounded, color: kGreen, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: kGrey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() { _results = []; _selected = null; _error = null; });
                          })
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 2)),
                ),
                onChanged: _search,
              ),
            ]),
          ),

          // ── Liste de suggestions ─────────────────────────────────
          if (_searching) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: kGreen, strokeWidth: 2)),
          ],
          if (!_searching && _results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: kCardDecoration(),
              child: Column(
                children: _results.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  return InkWell(
                    onTap: () => _select(s),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(12))
                        : i == _results.length - 1
                            ? const BorderRadius.vertical(bottom: Radius.circular(12))
                            : BorderRadius.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i < _results.length - 1
                            ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
                            : null,
                      ),
                      child: Row(children: [
                        const Icon(Icons.place_outlined, color: kGreen, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.libelleGeo,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kCharcoal)),
                            Text(s.codeGeo, style: const TextStyle(fontSize: 11, color: kGrey)),
                          ]),
                        ),
                        if (s.hasData)
                          Text(
                            s.hasMaison
                                ? '${_fmt(s.medPrixM2Maison)} €/m²'
                                : '${_fmt(s.medPrixM2Appartement)} €/m²',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen),
                          ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (!_searching && _error != null && _selected == null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 12, color: kGrey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
          ],

          // ── Fiche commune sélectionnée ───────────────────────────
          if (_selected != null) ...[
            const SizedBox(height: 16),
            _CommuneStatsCard(stats: _selected!),
          ],

          // ── Info source ──────────────────────────────────────────
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: kCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline, color: kGreen, size: 18),
                const SizedBox(width: 8),
                const Text('À propos des données',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
              ]),
              const SizedBox(height: 10),
              const Text(
                'Les statistiques affichées proviennent des Demandes de Valeurs Foncières (DVF), '
                'issues des actes notariés publiés par la DGFIP. '
                'Elles couvrent l\'ensemble des transactions enregistrées depuis 2018.\n\n'
                'Données : Statistiques DVF — data.gouv.fr (licence OGL v2)',
                style: TextStyle(fontSize: 12, color: kGrey, height: 1.6),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('SOURCE OFFICIELLE · DGFIP',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.8)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _fmt(int? v) {
    if (v == null || v == 0) return '—';
    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1).replaceAll('.', ',')} k';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CommuneStatsCard extends StatelessWidget {
  final DvfCommuneStats stats;
  const _CommuneStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Titre
        Row(children: [
          const Icon(Icons.bar_chart_rounded, color: kGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stats.libelleGeo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kCharcoal)),
              Text('Code INSEE : ${stats.codeGeo}',
                  style: const TextStyle(fontSize: 11, color: kGrey)),
            ]),
          ),
        ]),

        if (!stats.hasData) ...[
          const SizedBox(height: 14),
          const Text(
            'Données insuffisantes pour cette commune\n(moins de 5 transactions enregistrées).',
            style: TextStyle(fontSize: 12, color: kGrey, fontStyle: FontStyle.italic),
          ),
        ] else ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),

          // Maisons
          if (stats.hasMaison) ...[
            _TypeBlock(
              icon: Icons.house_rounded,
              label: 'Maisons',
              nb: stats.nbVentesMaison,
              moy: stats.moyPrixM2Maison,
              med: stats.medPrixM2Maison,
            ),
          ],

          if (stats.hasMaison && stats.hasAppartement) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
          ],

          // Appartements
          if (stats.hasAppartement) ...[
            _TypeBlock(
              icon: Icons.apartment_rounded,
              label: 'Appartements',
              nb: stats.nbVentesAppartement,
              moy: stats.moyPrixM2Appartement,
              med: stats.medPrixM2Appartement,
            ),
          ],

          // Total si les deux types présents
          if (stats.hasMaison && stats.hasAppartement && stats.medPrixM2Total != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
            _TypeBlock(
              icon: Icons.home_work_rounded,
              label: 'Tous types',
              nb: stats.nbVentesTotal,
              moy: stats.moyPrixM2Total,
              med: stats.medPrixM2Total,
              highlight: true,
            ),
          ],
        ],
      ]),
    );
  }
}

class _TypeBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? nb;
  final int? moy;
  final int? med;
  final bool highlight;

  const _TypeBlock({
    required this.icon,
    required this.label,
    this.nb,
    this.moy,
    this.med,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: kGrey, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? kGreen : kCharcoal)),
        if (nb != null && nb! > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$nb ventes',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kGreen)),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _StatBox(label: 'Médiane', value: med, suffix: '€/m²', primary: true)),
        const SizedBox(width: 10),
        Expanded(child: _StatBox(label: 'Moyenne', value: moy, suffix: '€/m²')),
      ]),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int? value;
  final String suffix;
  final bool primary;
  const _StatBox({required this.label, this.value, required this.suffix, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final v = value != null && value! > 0
        ? '${_fmtNum(value!)} $suffix'
        : '—';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary ? kGreen.withValues(alpha: 0.07) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: primary ? Border.all(color: kGreen.withValues(alpha: 0.2)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: primary ? kGreen : kGrey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary ? kGreen : kCharcoal)),
      ]),
    );
  }

  static String _fmtNum(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
