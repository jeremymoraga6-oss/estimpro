import 'dart:async';
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
  // Viewer normal (mode lecture)
  late final PdfViewerController _pdfController;

  // PageController pour le mode présentation (swipe natif)
  PageController? _pageController;

  int _currentPage = 1;
  int _totalPages = 0;
  bool _sharing = false;

  // Mode présentation
  bool _presentation = false;
  bool _uiVisible = false;
  Timer? _hideTimer;

  // Orientation forcée (landscape manuel)
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
    if (_presentation) _exitPresentation();
    super.dispose();
  }

  // ── Mode présentation ────────────────────────────────────────

  void _enterPresentation() {
    _pageController?.dispose();
    _pageController = PageController(initialPage: _currentPage - 1);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() {
      _presentation = true;
      _uiVisible = true;
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
    if (mounted) {
      setState(() {
        _presentation = false;
        _uiVisible = false;
        _forceLandscape = false;
      });
    }
  }

  void _toggleOrientation() {
    setState(() => _forceLandscape = !_forceLandscape);
    SystemChrome.setPreferredOrientations(_forceLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
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

  // Navigation via le PageController (swipe natif du PageView)
  void _goNext() {
    if (_currentPage < _totalPages) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _goPrev() {
    if (_currentPage > 1) {
      _pageController?.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Partage ──────────────────────────────────────────────────

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

Bien cordialement,
Jérémy MORAGA — Faucigny Immobilier by Efficity''';
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Faucigny Immobilier — Votre dossier vendeur',
        text: body,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_presentation) return _buildPresentation();
    return _buildNormal();
  }

  // ── Mode normal : lecteur PDF scrollable ─────────────────────

  Widget _buildNormal() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Book Vendeur',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.screen_rotation_rounded),
            tooltip: 'Passer en paysage',
            onPressed: () {
              _enterPresentation();
              Future.microtask(_toggleOrientation);
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
                  label: const Text(
                    'Envoyer par email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.share_rounded, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Mode présentation : PageView avec swipe natif ────────────
  //
  // PdfDocumentViewBuilder charge le document une seule fois.
  // PageView.builder gère le swipe horizontal nativement — plus besoin de
  // AbsorbPointer ni de layout custom ni de goToPage().

  Widget _buildPresentation() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── PDF : un PdfPageView par page, swipeable nativement ──
        PdfDocumentViewBuilder.asset(
          'assets/docs/book_vendeur.pdf',
          builder: (context, document) {
            if (document == null) {
              return const Center(
                child: CircularProgressIndicator(color: kGreen),
              );
            }
            // Sync total pages (une seule fois)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _totalPages != document.pages.length) {
                setState(() => _totalPages = document.pages.length);
              }
            });
            return PageView.builder(
              controller: _pageController,
              itemCount: document.pages.length,
              // onPageChanged reçoit l'index 0-based → page 1-based
              onPageChanged: (index) {
                if (mounted) {
                  setState(() => _currentPage = index + 1);
                  _scheduleHide();
                }
              },
              itemBuilder: (context, index) => PdfPageView(
                document: document,
                pageNumber: index + 1,
              ),
            );
          },
        ),

        // ── Couche tap transparente (afficher/cacher l'UI) ──────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleUi,
            child: const SizedBox.expand(),
          ),
        ),

        // ── Flèche gauche (tappable) ─────────────────────────────
        if (_currentPage > 1)
          Positioned(
            left: 0, top: 0, bottom: 0, width: 64,
            child: GestureDetector(
              onTap: _goPrev,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _uiVisible ? 0.80 : 0.20,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Flèche droite (tappable) ─────────────────────────────
        if (_currentPage < _totalPages)
          Positioned(
            right: 0, top: 0, bottom: 0, width: 64,
            child: GestureDetector(
              onTap: _goNext,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _uiVisible ? 0.80 : 0.20,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Barre supérieure ─────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          top: _uiVisible ? 0 : -80,
          left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(children: [
              const Expanded(
                child: Text(
                  'Book Vendeur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_totalPages > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleOrientation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _forceLandscape
                        ? kGreen.withOpacity(0.6)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _forceLandscape
                        ? Icons.stay_current_landscape_rounded
                        : Icons.screen_rotation_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _exitPresentation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Barre inférieure : progression ───────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          bottom: _uiVisible ? 0 : -60,
          left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
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
              const Text(
                '← Précédent  ·  Suivant →',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
