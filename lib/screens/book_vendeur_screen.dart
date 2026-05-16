import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';

class BookVendeurScreen extends StatefulWidget {
  const BookVendeurScreen({super.key});

  @override
  State<BookVendeurScreen> createState() => _BookVendeurScreenState();
}

class _BookVendeurScreenState extends State<BookVendeurScreen> {
  late final PdfViewerController _controller;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<File> _writeTempPdf() async {
    final bytes = await rootBundle.load('assets/docs/book_vendeur.pdf');
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/Book_Vendeur_Faucigny.pdf');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _writeTempPdf();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Book Vendeur — Faucigny Immobilier',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sendByEmail() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _writeTempPdf();
      const body = '''Bonjour,

Suite à notre échange, je vous transmets notre book de présentation Faucigny Immobilier.

Vous y trouverez :
• Notre approche personnalisée et notre ancrage local à Saint-Pierre-en-Faucigny
• La force du réseau Efficity à l'échelle nationale
• Nos engagements et nos services pour réussir la vente de votre bien

Je reste à votre entière disposition pour échanger sur votre projet et planifier une estimation gratuite et sans engagement.

Bien cordialement,

Jérémy MORAGA
Conseiller immobilier
Faucigny Immobilier by Efficity
Saint-Pierre-en-Faucigny — Haute-Savoie
''';
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Faucigny Immobilier — Votre dossier vendeur',
        text: body,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Book Vendeur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13)),
              ),
            ),
        ],
      ),
      body: PdfViewer.asset(
        'assets/docs/book_vendeur.pdf',
        controller: _controller,
        params: PdfViewerParams(
          backgroundColor: const Color(0xFF1A1A2E),
          margin: 8,
          onPageChanged: (page) {
            if (mounted) setState(() => _currentPage = page ?? 1);
          },
          onViewerReady: (document, controller) {
            if (mounted) setState(() => _totalPages = document.pages.length);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            color: kCharcoal,
            border: Border(top: BorderSide(color: Color(0xFF2D3436), width: 1)),
          ),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _sendByEmail,
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: const Text('Envoyer par email',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              width: 46,
              child: ElevatedButton(
                onPressed: _sharing ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3436),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.share_rounded, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
