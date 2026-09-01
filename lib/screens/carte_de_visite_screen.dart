import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class CarteDeVisiteScreen extends StatefulWidget {
  const CarteDeVisiteScreen({super.key});

  @override
  State<CarteDeVisiteScreen> createState() => _CarteDeVisiteScreenState();
}

class _CarteDeVisiteScreenState extends State<CarteDeVisiteScreen> {
  File? _photo;
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<String> get _photoPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/profil_photo.jpg';
  }

  Future<void> _loadPhoto() async {
    final path = await _photoPath;
    final f = File(path);
    if (await f.exists()) {
      if (mounted) setState(() => _photo = f);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    final dest = await _photoPath;
    await File(picked.path).copy(dest);
    if (mounted) setState(() => _photo = File(dest));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kLightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: kGreen),
            title: const Text('Prendre une photo'),
            onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: kGreen),
            title: const Text('Choisir depuis la galerie'),
            onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/carte_jeremy_moraga.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Carte de visite — Jérémy Moraga',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Carte de visite', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.share_rounded),
            onPressed: _sharing ? null : _shareCard,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            RepaintBoundary(
              key: _cardKey,
              child: _CardWidget(photo: _photo, onPhotoTap: _showPhotoOptions),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareCard,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Partager la carte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Appuyez sur la photo pour la modifier',
                style: TextStyle(fontSize: 12, color: kGrey)),
          ]),
        ),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final File? photo;
  final VoidCallback onPhotoTap;
  const _CardWidget({required this.photo, required this.onPhotoTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header vert avec photo
        SizedBox(
          height: 180,
          child: Stack(children: [
            // Fond blanc
            Container(color: Colors.white),
            // Blob vert en haut à gauche
            Positioned(
              top: -30, left: -30,
              child: Container(
                width: 180, height: 180,
                decoration: const BoxDecoration(
                  color: kGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Photo de profil centrée
            Center(
              child: GestureDetector(
                onTap: onPhotoTap,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photo != null
                      ? Image.file(photo!, fit: BoxFit.cover)
                      : Image.asset('assets/images/profil_jeremy.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
          ]),
        ),

        // Infos
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(children: [
            // Nom
            const Text('Jérémy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF2D3436), height: 1.2)),
            const Text('Moraga', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF2D3436), height: 1.1)),
            const SizedBox(height: 6),
            // Titre
            const Text('Consultant immobilier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kGreen)),
            const SizedBox(height: 20),

            // Téléphone
            _InfoRow(icon: Icons.phone_rounded, text: '06 68 03 64 03', bold: true, url: 'tel:+33668036403'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.email_rounded, text: 'jmoraga@efficity.com', url: 'mailto:jmoraga@efficity.com'),
            const SizedBox(height: 20),

            // Réseaux sociaux
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _SocialBadge(
                color: const Color(0xFF1877F2),
                icon: Icons.facebook_rounded,
                handle: 'Jeremy Moraga',
              ),
              const SizedBox(width: 16),
              _SocialBadge(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE1306C), Color(0xFFF77737), Color(0xFF833AB4)],
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                ),
                icon: Icons.camera_alt_rounded,
                handle: 'faucigny_immobilierbyefficity',
              ),
            ]),
            const SizedBox(height: 20),

            // QR Code vCard
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(children: [
                QrImageView(
                  data: 'BEGIN:VCARD\nVERSION:3.0\nFN:Jérémy Moraga\nN:Moraga;Jérémy;;;\nTITLE:Consultant immobilier\nTEL;TYPE=CELL:0668036403\nEMAIL:jmoraga@efficity.com\nORG:Faucigny Immobilier by Efficity\nURL:https://www.efficity.com/jmoraga/\nEND:VCARD',
                  version: QrVersions.auto,
                  size: 140,
                  backgroundColor: Colors.transparent,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF2D3436)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2D3436)),
                ),
                const SizedBox(height: 6),
                const Text('Scanner pour enregistrer le contact',
                    style: TextStyle(fontSize: 10, color: Color(0xFF636E72))),
              ]),
            ),
            const SizedBox(height: 20),

            // Logo Efficity
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Points efficity
              _EfficityDots(),
              const SizedBox(width: 8),
              const Text('efficity',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2D3436), letterSpacing: -0.5)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;
  final String? url;
  const _InfoRow({required this.icon, required this.text, this.bold = false, this.url});

  @override
  Widget build(BuildContext context) {
    Widget row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const kGreen),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(
          fontSize: bold ? 17 : 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF2D3436),
          decoration: url != null ? TextDecoration.underline : null,
          decorationColor: const kGreen,
        )),
      ],
    );
    if (url != null) {
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(url!)),
        child: row,
      );
    }
    return row;
  }
}

class _SocialBadge extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final IconData icon;
  final String handle;
  const _SocialBadge({this.color, this.gradient, required this.icon, required this.handle});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(handle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF636E72)),
            overflow: TextOverflow.ellipsis),
      ]);
}

class _EfficityDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const color = kGreen;
    const size = 6.0;
    const gap = 3.0;
    return Column(children: [
      Row(children: [
        _Dot(color, size), SizedBox(width: gap),
        _Dot(color, size), SizedBox(width: gap),
        _Dot(color, size),
      ]),
      SizedBox(height: gap),
      Row(children: [
        _Dot(color, size), SizedBox(width: gap),
        _Dot(color.withValues(alpha: 0.5), size), SizedBox(width: gap),
        _Dot(color, size),
      ]),
      SizedBox(height: gap),
      Row(children: [
        _Dot(color, size), SizedBox(width: gap),
        _Dot(color, size), SizedBox(width: gap),
        _Dot(color, size),
      ]),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot(this.color, this.size);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
