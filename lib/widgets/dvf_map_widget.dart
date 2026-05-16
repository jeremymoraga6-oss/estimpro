import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/dvf_service.dart';

/// Carte interactive des comparables DVF — visuel pour présentation vendeur.
/// Affiche le bien estimé (marker vert) et les transactions DVF (markers
/// colorés selon prix/m² : rouge = cher, jaune = moyen, vert = abordable).
class DvfMapWidget extends StatefulWidget {
  final List<DvfTransaction> transactions;
  final double centerLat;
  final double centerLon;
  final String adresseCentre;
  final double prixMoyen; // prix m² médian pour calibrer les couleurs

  const DvfMapWidget({
    super.key,
    required this.transactions,
    required this.centerLat,
    required this.centerLon,
    required this.adresseCentre,
    required this.prixMoyen,
  });

  @override
  State<DvfMapWidget> createState() => _DvfMapWidgetState();
}

class _DvfMapWidgetState extends State<DvfMapWidget> {
  DvfTransaction? _selected;
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  Color _colorForPrice(double prixM2) {
    if (widget.prixMoyen <= 0) return kGreen;
    final ratio = prixM2 / widget.prixMoyen;
    if (ratio < 0.85) return const Color(0xFF27AE60); // vert — moins cher
    if (ratio < 1.0) return const Color(0xFFF39C12);  // orange — proche moyenne
    if (ratio < 1.15) return const Color(0xFFE67E22); // orange foncé
    return const Color(0xFFC0392B);                    // rouge — plus cher
  }

  String _fmtPrice(double v) {
    if (v <= 0) return '—';
    final s = v.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s €';
  }

  @override
  Widget build(BuildContext context) {
    final hasCenter = widget.centerLat != 0 && widget.centerLon != 0;
    if (!hasCenter) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Géolocalisation indisponible — sélectionnez une adresse complète en étape 1 pour afficher la carte.',
            style: TextStyle(fontSize: 12, color: kGrey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final center = LatLng(widget.centerLat, widget.centerLon);
    final txWithCoords = widget.transactions
        .where((t) => t.latitude != 0 && t.longitude != 0)
        .toList();

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 320,
          child: Stack(children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 9,
                maxZoom: 18,
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.faucigny.estimpro',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    // Marker du bien estimé
                    Marker(
                      point: center,
                      width: 44,
                      height: 54,
                      alignment: Alignment.topCenter,
                      child: const _CenterMarker(),
                    ),
                    // Markers des transactions DVF
                    ...txWithCoords.map((tx) => Marker(
                          point: LatLng(tx.latitude, tx.longitude),
                          width: 30,
                          height: 30,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = tx),
                            child: _DvfMarker(
                              color: _colorForPrice(tx.prixM2),
                              selected: _selected == tx,
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
            // Légende couleurs
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorderColor.withOpacity(0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _legendDot(const Color(0xFF27AE60)),
                  const SizedBox(width: 3),
                  const Text('< marché', style: TextStyle(fontSize: 9, color: kCharcoal)),
                  const SizedBox(width: 8),
                  _legendDot(const Color(0xFFF39C12)),
                  const SizedBox(width: 3),
                  const Text('marché', style: TextStyle(fontSize: 9, color: kCharcoal)),
                  const SizedBox(width: 8),
                  _legendDot(const Color(0xFFC0392B)),
                  const SizedBox(width: 3),
                  const Text('> marché', style: TextStyle(fontSize: 9, color: kCharcoal)),
                ]),
              ),
            ),
            // Boutons zoom
            Positioned(
              right: 8,
              top: 8,
              child: Column(children: [
                _zoomBtn(Icons.add, () => _controller.move(_controller.camera.center, _controller.camera.zoom + 1)),
                const SizedBox(height: 6),
                _zoomBtn(Icons.remove, () => _controller.move(_controller.camera.center, _controller.camera.zoom - 1)),
                const SizedBox(height: 6),
                _zoomBtn(Icons.my_location, () => _controller.move(center, 14)),
              ]),
            ),
          ]),
        ),
      ),
      // Détails transaction sélectionnée
      if (_selected != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colorForPrice(_selected!.prixM2).withOpacity(0.4), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: _colorForPrice(_selected!.prixM2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selected!.typeLocal.isNotEmpty ? _selected!.typeLocal : 'Bien',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal)),
                Text('${_selected!.surfaceReelleBati.round()} m² · ${_selected!.dateMutation}',
                    style: const TextStyle(fontSize: 11, color: kGrey)),
                if (_selected!.distanceKm != null)
                  Text('À ${_selected!.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 10, color: kLightGrey)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtPrice(_selected!.valeurFonciere),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kCharcoal)),
              Text('${_fmtPrice(_selected!.prixM2)}/m²',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _colorForPrice(_selected!.prixM2))),
            ]),
          ]),
        ),
      ],
      const SizedBox(height: 6),
      // Attribution OSM
      GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 9, color: kLightGrey, decoration: TextDecoration.underline),
        ),
      ),
    ]);
  }

  Widget _legendDot(Color c) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kBorderColor.withOpacity(0.6)),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Icon(icon, size: 18, color: kCharcoal),
        ),
      );
}

class _CenterMarker extends StatelessWidget {
  const _CenterMarker();
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: kGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
        ),
        Container(
          width: 2, height: 12, color: kGreen,
        ),
      ]);
}

class _DvfMarker extends StatelessWidget {
  final Color color;
  final bool selected;
  const _DvfMarker({required this.color, required this.selected});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 26 : 20, height: selected ? 26 : 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: selected ? 3 : 2),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
      );
}
