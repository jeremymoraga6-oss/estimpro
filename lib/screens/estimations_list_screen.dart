import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../services/database_service.dart';

class EstimationsListScreen extends StatelessWidget {
  final List<Estimation> estimations;
  final ValueChanged<Estimation> onTap;
  const EstimationsListScreen({super.key, required this.estimations, required this.onTap});

  String _formatDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'appartement': return Icons.apartment_rounded;
      case 'chalet': return Icons.cabin_rounded;
      case 'terrain': return Icons.landscape_rounded;
      default: return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Toutes les estimations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: kCharcoal,
        automaticallyImplyLeading: false,
      ),
      body: estimations.isEmpty
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.home_work_outlined, size: 56, color: kLightGrey),
                SizedBox(height: 12),
                Text('Aucune estimation', style: TextStyle(color: kGrey, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Revenez à l\'accueil pour créer une estimation', style: TextStyle(color: kLightGrey, fontSize: 13)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: estimations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = estimations[i];
                final addr = e.proprietaireNom.isEmpty ? 'Estimation sans adresse' : e.proprietaireNom;
                final type = e.typeId[0].toUpperCase() + e.typeId.substring(1);
                final prix = e.prixCalcule;
                return GestureDetector(
                  onTap: () => onTap(e),
                  onLongPress: () => _confirmDelete(context, e),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: kCardDecoration(),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(_iconFor(e.typeId), color: kGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(addr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal)),
                          Text('$type · ${e.surfaceHabitable} m²', style: const TextStyle(fontSize: 12, color: kGrey)),
                          Text(_formatDate(e.updatedAt), style: const TextStyle(fontSize: 11, color: kLightGrey)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(prix > 0 ? '${(prix / 1000).round()}k€' : '—',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
                        const SizedBox(height: 2),
                        Text(e.reference, style: const TextStyle(fontSize: 10, color: kLightGrey, fontFamily: 'monospace')),
                        const Icon(Icons.chevron_right, color: kLightGrey, size: 18),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, Estimation e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer l\'estimation ${e.reference} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              await DatabaseService().delete(e.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
  }
}
