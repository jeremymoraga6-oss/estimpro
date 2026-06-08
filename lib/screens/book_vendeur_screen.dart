import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
  // Mode normal
  late final PdfViewerController _pdfController;

  // Mode présentation
  PageController? _pageController;
  PdfDocument? _pdfDocument;  // chargé une fois à la demande
  bool _loadingDoc = false;

  int _currentPage = 1;
  int _totalPages  = 0;
  bool _sharing    = false;
  bool _presentation = false;
  bool _uiVisible    = false;
  Timer? _hideTimer;
  bool _forceLandscape = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController?.dispose();
    _pdfDocument?.dispose();
    super.dispose();
  }

  // ─── Mode présentation ────────────────────────────────────────────────────

  Future<void> _enterPresentation() async {
    if (_loadingDoc) return;
    _loadingDoc = true;

    // Chargement unique du document
    if (_pdfDocument == null) {
      try {
        final doc = await PdfDocument.openAsset('assets/docs/book_vendeur.pdf');
        if (!mounted) { doc.dispose(); return; }
        _pdfDocument = doc;
      } catch (e) {
        _loadingDoc = false;
        return;
      }
    }
    _loadingDoc = false;
    if (!mounted) return;

    _pageController?.dispose();
    _pageController = PageController(initialPage: math.max(0, _currentPage - 1));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    setState(() {
      _totalPages    = _pdfDocument!.pages.length;
      _presentation  = true;
      _uiVisible     = true;
      _forceLandscape = false;
    });
    _scheduleHide();
  }

  void _exitPresentation() {
    _hideTimer?.cancel();
    _pageController?.dispose();
    _pageController = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) setState(() { _presentation = false; _uiVisible = false; _forceLandscape = false; });
  }

  void _toggleOrientation() {
    setState(() => _forceLandscape = !_forceLandscape);
    SystemChrome.setPreferredOrientations(_forceLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    if (_uiVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  void _toggleUi() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) _scheduleHide();
  }

  void _goNext() => _pageController?.nextPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  void _goPrev() => _pageController?.previousPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  // ─── Partage ──────────────────────────────────────────────────────────────

  Future<File> _writeTempPdf() async {
    final bytes = await rootBundle.load('assets/docs/book_vendeur.pdf');
    final tmp   = await getTemporaryDirectory();
    final file  = File('${tmp.path}/Book_Vendeur_Faucigny.pdf');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _writeTempPdf();
      await Share.shareXFiles([XFile(file.path)], subject: 'Book Vendeur — Faucigny Immobilier');
    } finally { if (mounted) setState(() => _sharing = false); }
  }

  Future<void> _sendByEmail() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _writeTempPdf();
      const body = 'Bonjour,\n\nSuite à notre échange, je vous transmets notre book de présentation '
          'Faucigny Immobilier.\n\nBien cordialement,\nJérémy MORAGA — Faucigny Immobilier by Efficity';
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Faucigny Immobilier — Votre dossier vendeur', text: body);
    } finally { if (mounted) setState(() => _sharing = false); }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_presentation) return _buildPresentation();
    return _buildNormal();
  }

  // ─── Mode normal ──────────────────────────────────────────────────────────

  Widget _buildNormal() {
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
                padding: const EdgeInsets.only(right: 4),
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.screen_rotation_rounded),
            tooltip: 'Passer en paysage',
            onPressed: () async {
              await _enterPresentation();
              if (mounted) _toggleOrientation();
            },
          ),
          IconButton(
            icon: const Icon(Icons.present_to_all_rounded),
            tooltip: 'Mode présentation',
            onPressed: _enterPresentation,
          ),
        ],
      ),
      body: PdfViewer.asset(
        'assets/docs/book_vendeur.pdf',
        controller: _pdfController,
        params: PdfViewerParams(
          backgroundColor: const Color(0xFF1A1A2E),
          margin: 8,
          onPageChanged: (page) { if (mounted) setState(() => _currentPage = page ?? 1); },
          onViewerReady: (document, _) { if (mounted) setState(() => _totalPages = document.pages.length); },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            color: kCharcoal,
            border: Border(top: BorderSide(color: Color(0xFF2D3436))),
          ),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _sendByEmail,
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: const Text('Envoyer par email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46, width: 46,
              child: ElevatedButton(
                onPressed: _sharing ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3436), foregroundColor: Colors.white,
                  elevation: 0, padding: EdgeInsets.zero,
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

  // ─── Mode présentation ────────────────────────────────────────────────────
  //
  // Utilise PdfDocument.openAsset + PdfPage.render() → RawImage.
  // Pas de PdfPageView (contraintes), pas de PdfDocumentViewBuilder (rebuild).
  // Le PageView gère le swipe nativement.

  Widget _buildPresentation() {
    final doc = _pdfDocument;
    if (doc == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── PageView : swipe natif, chaque page rendue en bitmap ──
        PageView.builder(
          controller: _pageController,
          itemCount: doc.pages.length,
          onPageChanged: (index) {
            // post-frame pour éviter setState pendant l'animation de swipe
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _currentPage = index + 1);
                _scheduleHide();
              }
            });
          },
          itemBuilder: (context, index) => _PdfPageBitmap(
            page: doc.pages[index],
            key: ValueKey(index),
          ),
        ),

        // ── Tap pour afficher/cacher l'UI ────────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleUi,
            child: const SizedBox.expand(),
          ),
        ),

        // ── Flèche gauche ─────────────────────────────────────────
        if (_currentPage > 1)
          Positioned(
            left: 0, top: 0, bottom: 0, width: 64,
            child: GestureDetector(
              onTap: _goPrev,
              child: _Arrow(left: true, visible: _uiVisible),
            ),
          ),

        // ── Flèche droite ─────────────────────────────────────────
        if (_currentPage < _totalPages)
          Positioned(
            right: 0, top: 0, bottom: 0, width: 64,
            child: GestureDetector(
              onTap: _goNext,
              child: _Arrow(left: false, visible: _uiVisible),
            ),
          ),

        // ── Barre supérieure ──────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
          top: _uiVisible ? 0 : -90, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(children: [
              const Expanded(
                child: Text('Book Vendeur',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (_totalPages > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: Text('$_currentPage / $_totalPages',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleOrientation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _forceLandscape ? kGreen.withOpacity(0.6) : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _forceLandscape ? Icons.stay_current_landscape_rounded : Icons.screen_rotation_rounded,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _exitPresentation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),

        // ── Barre inférieure ──────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
          bottom: _uiVisible ? 0 : -60, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_totalPages > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentPage / _totalPages,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
                    minHeight: 4,
                  ),
                ),
              const SizedBox(height: 8),
              const Text('← Précédent  ·  Suivant →',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Widget de rendu d'une page PDF en bitmap ──────────────────────────────
//
// Utilise PdfPage.render() → pixels bruts → ui.ImmutableBuffer → RawImage.
// Complètement indépendant de PdfPageView : aucune contrainte de layout.

class _PdfPageBitmap extends StatefulWidget {
  final PdfPage page;
  const _PdfPageBitmap({required this.page, super.key});

  @override
  State<_PdfPageBitmap> createState() => _PdfPageBitmapState();
}

class _PdfPageBitmapState extends State<_PdfPageBitmap> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    // Post-frame : attend que le widget ait ses dimensions dans le contexte
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    if (!mounted) return;
    try {
      final mq  = MediaQuery.of(context);
      final dpr = mq.devicePixelRatio;
      final sw  = mq.size.width;
      final sh  = mq.size.height;

      final scale = math.min(sw / widget.page.width, sh / widget.page.height) * dpr;
      final w = (widget.page.width  * scale).round().clamp(64, 4096);
      final h = (widget.page.height * scale).round().clamp(64, 4096);

      final pdfImage = await widget.page.render(width: w, height: h);
      if (pdfImage == null || !mounted) return;

      // pixels bruts → ui.Image via ImmutableBuffer
      final buffer     = await ui.ImmutableBuffer.fromUint8List(pdfImage.pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: pdfImage.width,
        height: pdfImage.height,
        pixelFormat: pdfImage.format,  // rgba8888 ou bgra8888 selon plateforme
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      pdfImage.dispose();

      if (mounted) {
        setState(() {
          _image?.dispose();
          _image = frame.image;
        });
      } else {
        frame.image.dispose();
      }
    } catch (e) {
      debugPrint('[PdfPageBitmap] render error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: RawImage(image: _image, fit: BoxFit.contain),
      ),
    );
  }
}

// ─── Flèche de navigation ─────────────────────────────────────────────────

class _Arrow extends StatelessWidget {
  final bool left;
  final bool visible;
  const _Arrow({required this.left, required this.visible});

  @override
  Widget build(BuildContext context) => Center(
        child: AnimatedOpacity(
          opacity: visible ? 0.80 : 0.20,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: Colors.white, size: 32,
            ),
          ),
        ),
      );
}
