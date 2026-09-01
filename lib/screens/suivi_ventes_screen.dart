import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../models/estimation_passee.dart';
import '../models/reference_locale.dart';
import '../services/base_locale_service.dart';
import '../services/database_service.dart';
import '../services/estimation_passee_service.dart';
import '../services/suivi_ventes_service.dart';
import '../widgets/adresse_field.dart';

class SuiviVentesScreen extends StatefulWidget {
  const SuiviVentesScreen({super.key});

  @override
  State<SuiviVentesScreen> createState() => _SuiviVentesScreenState();
}

class _SuiviVentesScreenState extends State<SuiviVentesScreen> {
  List<Estimation> _estimations = [];
  List<EstimationPassee> _passees = [];
  List<ReferenceLocale> _allRefs = [];
  bool _loading = true;
  bool _scanning = false;
  bool _bannerExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseService().loadAll(),
      EstimationPasseeService().loadAll(),
      BaseLocaleService().loadAll(),
    ]);
    setState(() {
      _estimations = results[0] as List<Estimation>;
      _passees = results[1] as List<EstimationPassee>;
      _allRefs = results[2] as List<ReferenceLocale>;
      _loading = false;
    });
  }

  List<ReferenceLocale> get _confirmees =>
      _allRefs.where((r) => r.hasEstime).toList();

  double _medianEcart(List<ReferenceLocale> refs) {
    final ecarts = refs.map((r) => r.ecartPct).toList()..sort();
    if (ecarts.isEmpty) return 0;
    final n = ecarts.length;
    return n.isOdd ? ecarts[n ~/ 2] : (ecarts[n ~/ 2 - 1] + ecarts[n ~/ 2]) / 2;
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final result = await SuiviVentesService().scanAll();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result.totalCandidats == 0
                ? 'Aucun candidat trouvé pour l\'instant'
                : '${result.totalCandidats} candidat(s) trouvé(s) pour ${result.nbMisAJour} estimation(s)',
          ),
          backgroundColor: result.totalCandidats > 0 ? kGreen : kGrey,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors du scan : $e'),
          backgroundColor: kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showCandidatsSheet({Estimation? est, EstimationPassee? passee}) async {
    setState(() => _scanning = true);
    List<CandidatVente> candidats = [];
    try {
      if (est != null) {
        candidats = await SuiviVentesService().chercherCandidats(
          lat: est.latitude,
          lon: est.longitude,
          codeInsee: est.codeInsee,
          typeId: est.typeId,
          surface: est.surfaceHabitable,
          dateEstimation: est.createdAt,
          exclureIds: est.mutationsEcartees,
        );
      } else if (passee != null) {
        candidats = await SuiviVentesService().chercherCandidats(
          lat: passee.latitude,
          lon: passee.longitude,
          codeInsee: passee.codeInsee,
          typeId: passee.typeId,
          surface: passee.surface,
          dateEstimation: passee.dateEstimationDt,
          exclureIds: passee.mutationsEcartees,
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }

    if (!mounted) return;
    if (candidats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun candidat trouvé pour cette estimation')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CandidatsSheet(
        candidats: candidats,
        estimation: est,
        passee: passee,
        onConfirm: (c) async {
          final addr = est?.adresseComplete ?? passee?.adresse ?? '';
          final commune = est?.commune ?? passee?.commune ?? '';
          final insee = est?.codeInsee ?? passee?.codeInsee ?? '';
          final typeId = est?.typeId ?? passee?.typeId ?? 'maison';
          final prix = (est?.prixFinal.round() ?? passee?.prixEstime) ?? 0;
          await SuiviVentesService().confirmerVente(
            estimationId: est?.id ?? '',
            adresse: addr,
            commune: commune,
            codeInsee: insee,
            typeId: typeId,
            prixEstime: prix,
            candidat: c,
          );
          if (est != null) {
            await DatabaseService()
                .saveEstimation(est.copyWith(suiviVenteStatut: 'confirmee'));
          } else if (passee != null) {
            passee.statut = 'confirmee';
            await EstimationPasseeService().save(passee);
          }
          if (ctx.mounted) Navigator.pop(ctx);
          await _load();
        },
        onEcarter: (c) async {
          final id = SuiviVentesService.txId(c.mutation);
          if (est != null) {
            final updated = est.copyWith(
                mutationsEcartees: [...est.mutationsEcartees, id]);
            await DatabaseService().saveEstimation(updated);
          } else if (passee != null) {
            passee.mutationsEcartees = [...passee.mutationsEcartees, id];
            await EstimationPasseeService().save(passee);
          }
          if (ctx.mounted) Navigator.pop(ctx);
          await _load();
        },
      ),
    );
  }

  Future<void> _showAddPasseeForm() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddPasseeForm(
        onSave: (ep) async {
          await EstimationPasseeService().save(ep);
          await _load();
        },
      ),
    );
  }

  String _fmtPrix(double n) {
    final s = n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  String _fmtDate(DateTime d) {
    const months = [
      'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Suivi des ventes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPasseeForm,
        backgroundColor: kGreen,
        tooltip: 'Ajouter une estimation passée',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final confirmed = _estimations.where((e) => e.suiviVenteStatut == 'confirmee').toList();
    final withCandidates = _estimations.where((e) => e.suiviVenteStatut == 'candidats').toList();
    final aucune = _estimations.where((e) => e.suiviVenteStatut == 'aucune').toList();
    final unscanned = _estimations
        .where((e) => e.suiviVenteStatut == '' && e.prixFinal > 0 && e.latitude != 0)
        .toList();

    final passeeConfirmed = _passees.where((p) => p.statut == 'confirmee').toList();
    final passeeCandidats = _passees.where((p) => p.statut == 'candidats').toList();
    final passeeAucune = _passees.where((p) => p.statut == 'aucune').toList();

    return SafeArea(
      child: Column(
        children: [
          _buildStatsHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                children: [
                  // DVF delay banner
                  _buildDelayBanner(),
                  const SizedBox(height: 12),

                  // Scan button
                  _buildScanButton(),
                  const SizedBox(height: 20),

                  // Confirmées
                  if (confirmed.isNotEmpty || passeeConfirmed.isNotEmpty) ...[
                    _GroupHeader(emoji: '🟢', label: 'Confirmées', count: confirmed.length + passeeConfirmed.length),
                    const SizedBox(height: 8),
                    ...confirmed.map((e) => _ConfirmeeCard(estimation: e, allRefs: _allRefs, fmtPrix: _fmtPrix, fmtDate: _fmtDate)),
                    ...passeeConfirmed.map((p) => _PasseeConfirmeeCard(passee: p, allRefs: _allRefs, fmtPrix: _fmtPrix)),
                    const SizedBox(height: 16),
                  ],

                  // Candidats
                  if (withCandidates.isNotEmpty || passeeCandidats.isNotEmpty) ...[
                    _GroupHeader(emoji: '🟠', label: 'Candidats à examiner', count: withCandidates.length + passeeCandidats.length),
                    const SizedBox(height: 8),
                    ...withCandidates.map((e) => _CandidatCard(
                      label: e.adresseComplete.isNotEmpty ? e.adresseComplete : e.commune,
                      subtitle: '${e.typeId} · ${e.surfaceHabitable} m² · ${_fmtDate(e.createdAt)}',
                      prix: _fmtPrix(e.prixFinal),
                      onTap: () => _showCandidatsSheet(est: e),
                    )),
                    ...passeeCandidats.map((p) => _CandidatCard(
                      label: p.adresse.isNotEmpty ? p.adresse : p.commune,
                      subtitle: '${p.typeId} · ${p.surface} m² · ${p.dateEstimation}',
                      prix: _fmtPrix(p.prixEstime.toDouble()),
                      onTap: () => _showCandidatsSheet(passee: p),
                    )),
                    const SizedBox(height: 16),
                  ],

                  // Sans correspondance / non scannées
                  if (aucune.isNotEmpty || passeeAucune.isNotEmpty || unscanned.isNotEmpty) ...[
                    _GroupHeader(emoji: '⚪', label: 'Sans correspondance pour l\'instant',
                        count: aucune.length + passeeAucune.length + unscanned.length),
                    const SizedBox(height: 8),
                    ...[...aucune, ...unscanned].map((e) => _AucuneCard(
                      label: e.adresseComplete.isNotEmpty ? e.adresseComplete : e.commune,
                      subtitle: '${e.typeId} · ${e.surfaceHabitable} m²',
                    )),
                    ...passeeAucune.map((p) => _AucuneCard(
                      label: p.adresse.isNotEmpty ? p.adresse : p.commune,
                      subtitle: '${p.typeId} · ${p.surface} m²',
                    )),
                  ],

                  // Estimations passées sans localisation
                  ..._passees.where((p) => p.statut == '' && p.latitude == 0).map((p) => _AucuneCard(
                    label: p.adresse.isNotEmpty ? p.adresse : '${p.commune} (sans coords)',
                    subtitle: '${p.typeId} · ${p.surface} m² · coordonnées manquantes',
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final withEstime = _confirmees;
    final n = withEstime.length;
    final median = _medianEcart(withEstime);
    final color = median.abs() < 5 ? kGreen : median.abs() < 10 ? kAmber : kRed;

    return Container(
      color: kCharcoal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calibration mesurée',
              style: TextStyle(fontSize: 11, color: Color(0xFFB2BEC3), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(
              value: '$n',
              label: 'vente${n != 1 ? 's' : ''} confirmée${n != 1 ? 's' : ''}',
            ),
            if (n > 0) ...[
              const SizedBox(width: 8),
              _StatPill(
                value: '${median >= 0 ? '+' : ''}${median.toStringAsFixed(1)} %',
                label: 'écart médian signé',
                color: color,
              ),
            ],
            const SizedBox(width: 8),
            _StatPill(
              value: '${_passees.length}',
              label: 'estimation${_passees.length != 1 ? 's' : ''} passée${_passees.length != 1 ? 's' : ''}',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDelayBanner() {
    return GestureDetector(
      onTap: () => setState(() => _bannerExpanded = !_bannerExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAmber.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: kAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedCrossFade(
              firstChild: const Text(
                'Délai DVF : les ventes notariées remontent sous 6 à 12 mois.',
                style: TextStyle(fontSize: 12, color: kAmber),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: const Text(
                'Les ventes notariées remontent dans DVF sous 6 à 12 mois après signature. '
                'Si ta vente récente n\'apparaît pas, c\'est normal — relance la recherche dans quelques mois.',
                style: TextStyle(fontSize: 12, color: kAmber, height: 1.4),
              ),
              crossFadeState: _bannerExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ),
          const SizedBox(width: 8),
          Icon(_bannerExpanded ? Icons.expand_less : Icons.expand_more,
              color: kAmber, size: 18),
        ]),
      ),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _scanning ? null : _scan,
        icon: _scanning
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search_rounded, size: 20),
        label: Text(_scanning ? 'Recherche en cours…' : 'Rechercher les ventes',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

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
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color ?? Colors.white)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFFB2BEC3))),
        ]),
      );
}

class _GroupHeader extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  const _GroupHeader({required this.emoji, required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: 0.2)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: kGrey.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGrey)),
        ),
      ]);
}

class _CandidatCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String prix;
  final VoidCallback onTap;
  const _CandidatCard(
      {required this.label, required this.subtitle, required this.prix, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: kCardDecoration(borderColor: kAmber.withValues(alpha: 0.4)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: kAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.search_rounded, color: kAmber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: kCharcoal),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(prix,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: kAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('À examiner',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: kAmber)),
                ),
              ]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: kLightGrey, size: 20),
            ]),
          ),
        ),
      );
}

class _ConfirmeeCard extends StatelessWidget {
  final Estimation estimation;
  final List<ReferenceLocale> allRefs;
  final String Function(double) fmtPrix;
  final String Function(DateTime) fmtDate;
  const _ConfirmeeCard(
      {required this.estimation, required this.allRefs, required this.fmtPrix, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final ref = allRefs.where((r) => r.estimationId == estimation.id).firstOrNull;
    final ecart = ref?.ecartPct ?? 0;
    final ecartColor = ecart.abs() <= 5 ? kGreen : ecart.abs() <= 10 ? kAmber : kRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: kCardDecoration(borderColor: kGreen.withValues(alpha: 0.25)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline_rounded, color: kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                estimation.adresseComplete.isNotEmpty
                    ? estimation.adresseComplete
                    : estimation.commune,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kCharcoal),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${estimation.typeId} · ${estimation.surfaceHabitable} m²',
                style: const TextStyle(fontSize: 11, color: kGrey),
              ),
            ]),
          ),
          if (ref != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtPrix(ref.prixVente.toDouble()),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              const SizedBox(height: 2),
              Text(
                '${ecart >= 0 ? '+' : ''}${ecart.toStringAsFixed(1)} %',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: ecartColor),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _PasseeConfirmeeCard extends StatelessWidget {
  final EstimationPassee passee;
  final List<ReferenceLocale> allRefs;
  final String Function(double) fmtPrix;
  const _PasseeConfirmeeCard(
      {required this.passee, required this.allRefs, required this.fmtPrix});

  @override
  Widget build(BuildContext context) {
    final ref = allRefs.where((r) => r.estimationId == passee.id).firstOrNull;
    final ecart = ref?.ecartPct ?? 0;
    final ecartColor = ecart.abs() <= 5 ? kGreen : ecart.abs() <= 10 ? kAmber : kRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: kCardDecoration(borderColor: kGreen.withValues(alpha: 0.25)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline_rounded, color: kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(passee.adresse.isNotEmpty ? passee.adresse : passee.commune,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: kCharcoal),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${passee.typeId} · ${passee.surface} m² · ${passee.source}',
                  style: const TextStyle(fontSize: 11, color: kGrey)),
            ]),
          ),
          if (ref != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtPrix(ref.prixVente.toDouble()),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
              const SizedBox(height: 2),
              Text(
                '${ecart >= 0 ? '+' : ''}${ecart.toStringAsFixed(1)} %',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: ecartColor),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _AucuneCard extends StatelessWidget {
  final String label;
  final String subtitle;
  const _AucuneCard({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: kCardDecoration(),
        child: Row(children: [
          const Icon(Icons.hourglass_empty_rounded, color: kLightGrey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCharcoal),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: kGrey)),
            ]),
          ),
        ]),
      );
}

// ── Candidats bottom sheet ──────────────────────────────────────────────────

class _CandidatsSheet extends StatefulWidget {
  final List<CandidatVente> candidats;
  final Estimation? estimation;
  final EstimationPassee? passee;
  final Future<void> Function(CandidatVente) onConfirm;
  final Future<void> Function(CandidatVente) onEcarter;
  const _CandidatsSheet({
    required this.candidats,
    required this.estimation,
    required this.passee,
    required this.onConfirm,
    required this.onEcarter,
  });

  @override
  State<_CandidatsSheet> createState() => _CandidatsSheetState();
}

class _CandidatsSheetState extends State<_CandidatsSheet> {
  int _page = 0;
  bool _processing = false;

  List<CandidatVente> get _remaining => widget.candidats;
  CandidatVente get _current => _remaining[_page];

  String _fmtPrix(double n) {
    final s = n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  Color _scoreColor(double s) =>
      s >= 70 ? kGreen : s >= 50 ? kAmber : const Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    final c = _current;
    final tx = c.mutation;
    final est = widget.estimation;
    final passee = widget.passee;
    final scoreColor = _scoreColor(c.scorePct);

    final myAdresse = est?.adresseComplete ?? passee?.adresse ?? '—';
    final myType = est?.typeId ?? passee?.typeId ?? '—';
    final mySurface = est?.surfaceHabitable ?? passee?.surface ?? 0;
    final myPrix = est?.prixFinal ?? passee?.prixEstime?.toDouble() ?? 0;
    final myDate = est != null ? _fmtDate(est.createdAt) : passee?.dateEstimation ?? '—';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: kLightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // Title + pagination
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Text('Candidat ${_page + 1} / ${_remaining.length}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
              ),
              if (_remaining.length > 1) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  color: kGrey,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _page < _remaining.length - 1 ? () => setState(() => _page++) : null,
                  color: kGrey,
                ),
              ],
            ]),
          ),

          // Score badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Text('Score ${c.scorePct.round()} %',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: kLightGrey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${c.distanceM.round()} m',
                    style: const TextStyle(fontSize: 11, color: kGrey, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(spacing: 4, children: c.criteres.map((cr) => Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                  child: Text(cr, style: const TextStyle(fontSize: 9, color: kGrey)),
                )).toList()),
              ),
            ]),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 14),

          // Comparison columns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Mon estimation
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MON ESTIMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _InfoRow('Date', myDate),
                _InfoRow('Adresse', myAdresse),
                _InfoRow('Surface', '$mySurface m²'),
                _InfoRow('Type', myType),
                _InfoRow('Prix estimé', _fmtPrix(myPrix)),
              ])),
              Container(width: 1, height: 160, color: kBorderColor),
              const SizedBox(width: 12),
              // Vente DVF
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VENTE DVF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0288D1), letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _InfoRow('Date mutation', tx.formattedDate),
                _InfoRow('Adresse', tx.adresse.isNotEmpty ? tx.adresse : tx.nomCommune),
                _InfoRow('Surface', '${tx.surfaceReelleBati.round()} m²'),
                _InfoRow('Type', tx.typeLocal),
                _InfoRow('Prix vente', _fmtPrix(tx.valeurFonciere)),
              ])),
            ]),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 16),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () async {
                    setState(() => _processing = true);
                    try { await widget.onEcarter(_current); } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Écarter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : () async {
                    setState(() => _processing = true);
                    try { await widget.onConfirm(_current); } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text("C'est cette vente",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: kGrey, letterSpacing: 0.3)),
          Text(value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCharcoal),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ── Add EstimationPassee form ────────────────────────────────────────────────

class _AddPasseeForm extends StatefulWidget {
  final Future<void> Function(EstimationPassee) onSave;
  const _AddPasseeForm({required this.onSave});

  @override
  State<_AddPasseeForm> createState() => _AddPasseeFormState();
}

class _AddPasseeFormState extends State<_AddPasseeForm> {
  final _dateCtrl = TextEditingController();
  final _surfaceCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  String _typeId = 'maison';
  String _source = 'pricehubble';
  String _adresse = '';
  String _codeInsee = '';
  String _commune = '';
  double _lat = 0;
  double _lon = 0;
  bool _saving = false;

  @override
  void dispose() {
    _dateCtrl.dispose();
    _surfaceCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_dateCtrl.text.isEmpty || _adresse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplis la date et l\'adresse')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ep = EstimationPassee(
        id: const Uuid().v4(),
        dateEstimation: _dateCtrl.text.trim(),
        adresse: _adresse,
        codeInsee: _codeInsee,
        commune: _commune,
        latitude: _lat,
        longitude: _lon,
        typeId: _typeId,
        surface: int.tryParse(_surfaceCtrl.text) ?? 0,
        prixEstime: int.tryParse(_prixCtrl.text.replaceAll(' ', '')) ?? 0,
        source: _source,
      );
      await widget.onSave(ep);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(
            child: Text('Ajouter une estimation passée',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
          ),
          const SizedBox(height: 20),

          const Text('Date de l\'estimation (MM/AAAA)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
          const SizedBox(height: 6),
          TextField(
            controller: _dateCtrl,
            decoration: InputDecoration(
              hintText: 'ex: 06/2024',
              hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 14),

          const Text('Adresse du bien',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
          const SizedBox(height: 6),
          AdresseField(
            initialValue: _adresse,
            onSelected: (s) => setState(() {
              _adresse = s.label;
              _codeInsee = s.codeInsee;
              _commune = s.commune;
              _lat = s.latitude;
              _lon = s.longitude;
            }),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _typeId,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'maison', child: Text('Maison')),
                      DropdownMenuItem(value: 'appartement', child: Text('Appartement')),
                      DropdownMenuItem(value: 'chalet', child: Text('Chalet')),
                    ],
                    onChanged: (v) => setState(() => _typeId = v ?? 'maison'),
                    style: const TextStyle(fontSize: 13, color: kCharcoal),
                  ),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Surface (m²)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
              const SizedBox(height: 6),
              TextField(
                controller: _surfaceCtrl,
                decoration: InputDecoration(
                  hintText: '120',
                  hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Prix estimé (€)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
              const SizedBox(height: 6),
              TextField(
                controller: _prixCtrl,
                decoration: InputDecoration(
                  hintText: '350000',
                  hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGrey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _source,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'pricehubble', child: Text('PriceHubble')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (v) => setState(() => _source = v ?? 'pricehubble'),
                    style: const TextStyle(fontSize: 13, color: kCharcoal),
                  ),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
