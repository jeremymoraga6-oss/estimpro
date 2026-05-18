import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  PdfDocument? _document;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _sharing = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDocument();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _document?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    final doc = await PdfDocument.openAsset('assets/docs/book_vendeur.pdf');
    if (mounted) {
      setState(() {
        _document = doc;
        _totalPages = doc.pages.length;
      });
    }
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
                child: Text('${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _document == null
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (p) => setState(() => _currentPage = p),
              itemBuilder: (context, index) => _PdfPageWidget(
                page: _document!.pages[index],
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

class _PdfPageWidget extends StatefulWidget {
  final PdfPage page;
  const _PdfPageWidget({required this.page});

  @override
  State<_PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<_PdfPageWidget> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final screenWidth = ui.window.physicalSize.width;
    final dpr = ui.window.devicePixelRatio;
    final targetW = screenWidth > 0 ? screenWidth.toInt() : (375 * dpr).toInt();
    final targetH = (targetW * widget.page.height / widget.page.width).toInt();

    final pdfImage = await widget.page.render(
      width: targetW,
      height: targetH,
      backgroundColor: const Color(0xFFFFFFFF),
    );
    if (pdfImage == null || !mounted) return;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.fromList(pdfImage.pixels),
      pdfImage.width,
      pdfImage.height,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    final image = await completer.future;
    if (mounted) setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: RawImage(image: _image, fit: BoxFit.contain),
      ),
    );
  }
}
