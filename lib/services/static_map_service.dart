import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Un point à afficher sur la carte statique.
class MapPoint {
  final double lat;
  final double lon;

  /// Couleur du marqueur (ARGB).
  final int color;

  /// Étiquette affichée dans le marqueur (ex: "1", "2"…). Vide pour le bien.
  final String label;

  /// Marqueur principal (le bien estimé) — dessiné plus gros, en pin.
  final bool isCenter;

  const MapPoint({
    required this.lat,
    required this.lon,
    required this.color,
    this.label = '',
    this.isCenter = false,
  });
}

/// Génère une image PNG d'une carte OpenStreetMap statique avec marqueurs,
/// destinée à être intégrée dans le rapport PDF.
///
/// Assemble les tuiles OSM (256 px) couvrant tous les points puis dessine
/// les marqueurs par-dessus avec `dart:ui` (pas de dépendance image externe).
/// Retourne `null` si aucun point géolocalisé ou si trop de tuiles échouent.
class StaticMapService {
  static const _tileSize = 256;
  static const _userAgent = 'estimpro/1.0 (com.faucigny.estimpro)';

  /// Largeur / hauteur de l'image générée (px). 2x pour un rendu net en PDF.
  final int width;
  final int height;

  const StaticMapService({this.width = 1000, this.height = 560});

  double _lonToTileX(double lon, int z) => (lon + 180.0) / 360.0 * (1 << z);

  double _latToTileY(double lat, int z) {
    final latRad = lat * pi / 180.0;
    return (1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * (1 << z);
  }

  /// Choisit le zoom le plus grand où tous les points tiennent dans le cadre.
  int _chooseZoom(List<MapPoint> pts) {
    if (pts.length == 1) return 15;
    const padFrac = 0.18;
    final usableW = width * (1 - 2 * padFrac);
    final usableH = height * (1 - 2 * padFrac);
    for (int z = 18; z >= 3; z--) {
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      for (final p in pts) {
        final x = _lonToTileX(p.lon, z) * _tileSize;
        final y = _latToTileY(p.lat, z) * _tileSize;
        minX = min(minX, x);
        maxX = max(maxX, x);
        minY = min(minY, y);
        maxY = max(maxY, y);
      }
      if ((maxX - minX) <= usableW && (maxY - minY) <= usableH) return z;
    }
    return 11;
  }

  Future<ui.Image?> _fetchTile(int z, int x, int y) async {
    final maxIndex = (1 << z) - 1;
    if (x < 0 || y < 0 || x > maxIndex || y > maxIndex) return null;
    try {
      final resp = await http.get(
        Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png'),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(resp.bodyBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (e) {
      debugPrint('[StaticMap] tile $z/$x/$y failed: $e');
      return null;
    }
  }

  /// Génère la carte. [points] doit contenir au moins un point géolocalisé.
  Future<Uint8List?> generate(List<MapPoint> points) async {
    final pts = points.where((p) => p.lat != 0 && p.lon != 0).toList();
    if (pts.isEmpty) return null;

    final z = _chooseZoom(pts);

    // Centre (pixels globaux) = milieu de la bbox des points.
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      final x = _lonToTileX(p.lon, z) * _tileSize;
      final y = _latToTileY(p.lat, z) * _tileSize;
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    // Coin supérieur gauche du cadre, en pixels globaux.
    final originX = centerX - width / 2;
    final originY = centerY - height / 2;

    // Plage de tuiles à récupérer.
    final firstTileX = (originX / _tileSize).floor();
    final firstTileY = (originY / _tileSize).floor();
    final lastTileX = ((originX + width) / _tileSize).ceil();
    final lastTileY = ((originY + height) / _tileSize).ceil();

    // Récupération concurrente des tuiles.
    final futures = <Future<_TileResult>>[];
    for (int tx = firstTileX; tx < lastTileX; tx++) {
      for (int ty = firstTileY; ty < lastTileY; ty++) {
        futures.add(_fetchTile(z, tx, ty).then((img) => _TileResult(tx, ty, img)));
      }
    }
    final tiles = await Future.wait(futures);

    final total = tiles.length;
    final ok = tiles.where((t) => t.image != null).length;
    if (total == 0 || ok < total * 0.5) {
      // Trop de tuiles manquantes (ex: pas de réseau) → on abandonne la carte.
      for (final t in tiles) {
        t.image?.dispose();
      }
      return null;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Fond clair (visible si tuile manquante).
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFE8ECE8),
    );

    // Dessin des tuiles.
    for (final t in tiles) {
      if (t.image == null) continue;
      final dx = t.x * _tileSize - originX;
      final dy = t.y * _tileSize - originY;
      canvas.drawImage(t.image!, ui.Offset(dx, dy), ui.Paint());
    }

    // Dessin des marqueurs (le bien en dernier pour qu'il soit au-dessus).
    pts.sort((a, b) => (a.isCenter ? 1 : 0).compareTo(b.isCenter ? 1 : 0));
    for (final p in pts) {
      final px = _lonToTileX(p.lon, z) * _tileSize - originX;
      final py = _latToTileY(p.lat, z) * _tileSize - originY;
      _drawMarker(canvas, px, py, p);
    }

    // Attribution OSM (obligatoire).
    _drawAttribution(canvas);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    for (final t in tiles) {
      t.image?.dispose();
    }
    return data?.buffer.asUint8List();
  }

  void _drawMarker(ui.Canvas canvas, double cx, double cy, MapPoint p) {
    final color = ui.Color(p.color);
    final radius = p.isCenter ? 22.0 : 17.0;

    // Ombre portée.
    canvas.drawCircle(
      ui.Offset(cx, cy + 2),
      radius + 1,
      ui.Paint()
        ..color = const ui.Color(0x44000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
    // Anneau blanc.
    canvas.drawCircle(ui.Offset(cx, cy), radius, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    // Disque coloré.
    canvas.drawCircle(ui.Offset(cx, cy), radius - 3, ui.Paint()..color = color);

    // Étiquette / icône.
    final text = p.isCenter ? '\u2605' : p.label; // étoile pour le bien
    if (text.isNotEmpty) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: p.isCenter ? 22 : 18,
        fontWeight: ui.FontWeight.bold,
      ))
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
        ..addText(text);
      final para = builder.build()
        ..layout(ui.ParagraphConstraints(width: radius * 2.4));
      canvas.drawParagraph(
        para,
        ui.Offset(cx - radius * 1.2, cy - para.height / 2),
      );
    }
  }

  void _drawAttribution(ui.Canvas canvas) {
    const label = '\u00A9 OpenStreetMap';
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.right,
      fontSize: 14,
    ))
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xCC333333)))
      ..addText(label);
    final para = builder.build()..layout(ui.ParagraphConstraints(width: 220));
    // Fond semi-transparent.
    canvas.drawRect(
      ui.Rect.fromLTWH(width - 232, height - 26.0, 232, 26),
      ui.Paint()..color = const ui.Color(0x99FFFFFF),
    );
    canvas.drawParagraph(para, ui.Offset(width - 228.0, height - 22.0));
  }
}

class _TileResult {
  final int x;
  final int y;
  final ui.Image? image;
  _TileResult(this.x, this.y, this.image);
}
