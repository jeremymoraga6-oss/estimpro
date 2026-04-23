import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../services/database_service.dart';
import 'estimation_flow.dart';
import 'estimations_list_screen.dart';
import 'marche_screen.dart';
import 'profil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Estimation> _estimations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService().loadAll();
    setState(() { _estimations = list; _loading = false; });
  }

  void _newEstimation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EstimationFlow()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(
        estimations: _estimations,
        loading: _loading,
        onNew: _newEstimation,
        onRefresh: _load,
        onTap: (e) async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EstimationFlow(existing: e)),
          );
          _load();
        },
      ),
      EstimationsListScreen(estimations: _estimations, onTap: (e) async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => EstimationFlow(existing: e)));
        _load();
      }),
      const MarcheScreen(),
      const ProfilScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: screens[_tab],
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: kGreen,
            unselectedItemColor: kGrey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Estimations'),
              BottomNavigationBarItem(icon: Icon(Icons.trending_up_rounded), label: 'Marché'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final List<Estimation> estimations;
  final bool loading;
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  final ValueChanged<Estimation> onTap;
  const _HomeTab({required this.estimations, required this.loading, required this.onNew, required this.onRefresh, required this.onTap});

  int get _thisMonth {
    final now = DateTime.now();
    return estimations.where((e) => e.createdAt.month == now.month && e.createdAt.year == now.year).length;
  }

  int get _pdfCount => estimations.where((e) => e.prixFinal > 0).length;
  int get _pending => estimations.where((e) => e.prixFinal == 0 && e.proprietaireNom.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final recent = estimations.take(3).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: kCharcoal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('J', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Bienvenue,', style: TextStyle(color: Color(0xFFB2BEC3), fontSize: 12)),
                        Row(children: [
                          const Text('Bonjour Jérémy ', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ]),
                      ]),
                    ),
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.business, color: kGreen, size: 28)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                color: kBackground,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Stats row
                  Row(children: [
                    _StatCard(value: '${estimations.length}', label: 'Estimations'),
                    const SizedBox(width: 10),
                    _StatCard(value: '$_thisMonth', label: 'Ce mois'),
                    const SizedBox(width: 10),
                    _StatCard(value: '$_pdfCount', label: 'PDF envoyés'),
                  ]),
                  const SizedBox(height: 16),

                  // New estimation CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: onNew,
                      icon: const Icon(Icons.home_rounded, size: 20),
                      label: const Text('Nouvelle estimation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section header
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Estimations récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal)),
                    ]),
                    GestureDetector(
                      onTap: () {},
                      child: const Text('Voir tout', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Recent list
                  if (loading)
                    const Center(child: CircularProgressIndicator(color: kGreen))
                  else if (recent.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          const Icon(Icons.home_work_outlined, size: 48, color: kLightGrey),
                          const SizedBox(height: 12),
                          Text('Aucune estimation', style: TextStyle(color: kGrey.withOpacity(0.6), fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Commencez par créer votre première estimation', style: TextStyle(color: kLightGrey, fontSize: 12), textAlign: TextAlign.center),
                        ]),
                      ),
                    )
                  else
                    ...recent.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EstimationCard(estimation: e, onTap: () => onTap(e)),
                        )),

                  if (_pending > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Text('●', style: TextStyle(color: Color(0xFFF9A825), fontSize: 10)),
                        const SizedBox(width: 10),
                        Text('$_pending estimation${_pending > 1 ? 's' : ''} en attente de validation',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF7A5800), fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: kCardDecoration(),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: kGrey)),
          ]),
        ),
      );
}

class _EstimationCard extends StatelessWidget {
  final Estimation estimation;
  final VoidCallback onTap;
  const _EstimationCard({required this.estimation, required this.onTap});

  IconData _iconFor(String type) {
    switch (type) {
      case 'appartement': return Icons.apartment_rounded;
      case 'chalet': return Icons.cabin_rounded;
      case 'terrain': return Icons.landscape_rounded;
      default: return Icons.home_rounded;
    }
  }

  String _formatPrice(double low, double high) {
    if (low == 0 && high == 0) return '— €';
    String fmt(double v) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M€';
      return '${(v / 1000).round()}k€';
    }
    return '${fmt(low)}–${fmt(high)}';
  }

  String _formatDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final addr = estimation.proprietaireNom.isEmpty ? 'Estimation sans adresse' : estimation.proprietaireNom;
    final type = estimation.typeId[0].toUpperCase() + estimation.typeId.substring(1);
    final low = estimation.fourchetteBasse > 0 ? estimation.fourchetteBasse : estimation.prixCalcule * 0.95;
    final high = estimation.fourchetteHaute > 0 ? estimation.fourchetteHaute : estimation.prixCalcule * 1.05;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: kCardDecoration(),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(estimation.typeId), color: kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(addr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
              const SizedBox(height: 2),
              Text('$type · ${estimation.surfaceHabitable} m²', style: const TextStyle(fontSize: 12, color: kGrey)),
              const SizedBox(height: 2),
              Text(_formatDate(estimation.updatedAt), style: const TextStyle(fontSize: 11, color: kLightGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_formatPrice(low, high),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreen)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, color: kLightGrey, size: 18),
          ]),
        ]),
      ),
    );
  }
}
