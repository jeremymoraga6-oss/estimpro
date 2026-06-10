import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme.dart';

class BookVendeurScreen extends StatefulWidget {
  const BookVendeurScreen({super.key});

  @override
  State<BookVendeurScreen> createState() => _BookVendeurScreenState();
}

class _BookVendeurScreenState extends State<BookVendeurScreen> {
  // ── Amélioration 7 : persistance de session (survit aux navigations) ────────
  static int _sessionLastPage = 1;

  // ── Mode normal ─────────────────────────────────────────────────────────────
  late final PdfViewerController _pdfController;

  // ── Mode présentation ────────────────────────────────────────────────────────
  PageController? _pageController;
  PdfDocument?   _pdfDocument;   // chargé une seule fois
  bool _loadingDoc = false;

  int  _currentPage  = 1;
  int  _totalPages   = 0;
  bool _sharing      = false;
  bool _presentation = false;
  bool _uiVisible    = false;
  Timer? _hideTimer;
  bool _forceLandscape = false;
  bool _stretchMode    = false;  // BoxFit.cover — remplit sans déformer

  // ── Amélioration 3 : état du zoom (bloque le swipe PageView) ────────────────
  bool _zoomed = false;

  // ── Amélioration 4 : miniatures ─────────────────────────────────────────────
  List<ui.Image?> _thumbs    = [];
  bool _thumbsVisible        = false;
  final ScrollController _thumbScrollCtrl = ScrollController();

  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _currentPage   = _sessionLastPage; // Amélioration 7
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController?.dispose();
    _pdfDocument?.dispose();
    _thumbScrollCtrl.dispose();
    for (final t in _thumbs) t?.dispose();
    WakelockPlus.disable(); // Amélioration 1 — sécurité si quitté en présentation
    super.dispose();
  }

  // ─── Mode présentation — entrée ──────────────────────────────────────────────

  Future<void> _enterPresentation() async {
    if (_loadingDoc) return;
    _loadingDoc = true;

    // Chargement unique du document PDF
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

    // Paysage immersif — optimal sur S24 Ultra
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final totalPages = _pdfDocument!.pages.length;
    setState(() {
      _totalPages     = totalPages;
      _presentation   = true;
      _uiVisible      = true;
      _forceLandscape = true;
      _stretchMode    = false;
      _zoomed         = false;
      _thumbsVisible  = false;
      _thumbs         = List.filled(totalPages, null); // Amélioration 4
    });

    WakelockPlus.enable(); // Amélioration 1
    _scheduleHide();
    _generateThumbs(_pdfDocument!); // Amélioration 4 — en arrière-plan
  }

  // ─── Mode présentation — sortie ───────────────────────────────────────────────

  void _exitPresentation() {
    _hideTimer?.cancel();
    _pageController?.dispose();
    _pageController = null;
    for (final t in _thumbs) t?.dispose();
    WakelockPlus.disable(); // Amélioration 1
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) {
      setState(() {
        _presentation   = false;
        _uiVisible      = false;
        _forceLandscape = false;
        _stretchMode    = false;
        _zoomed         = false;
        _thumbsVisible  = false;
        _thumbs         = [];
      });
    }
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

  void _goNext() {
    if (_zoomed) setState(() => _zoomed = false);
    _pageController?.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goPrev() {
    if (_zoomed) setState(() => _zoomed = false);
    _pageController?.previousPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ─── Amélioration 4 : génération des miniatures en arrière-plan ────────────

  Future<void> _generateThumbs(PdfDocument doc) async {
    for (int i = 0; i < doc.pages.length; i++) {
      if (!mounted) return;
      final page = doc.pages[i];
      try {
        const targetW = 140;
        final scale   = targetW / page.width;
        final w = targetW;
        final h = (page.height * scale).round().clamp(1, 300);

        final pdfImg = await page.render(
          width: w, height: h,
          backgroundColor: const Color(0xFFFFFFFF),
        );
        if (pdfImg == null || !mounted) return;

        final buf  = await ui.ImmutableBuffer.fromUint8List(pdfImg.pixels);
        final desc = ui.ImageDescriptor.raw(buf,
            width: pdfImg.width, height: pdfImg.height,
            pixelFormat: pdfImg.format);
        final codec = await desc.instantiateCodec();
        final frame = await codec.getNextFrame();
        pdfImg.dispose();

        if (mounted) {
          setState(() {
            if (i < _thumbs.length) _thumbs[i] = frame.image;
          });
        } else {
          frame.image.dispose();
          return;
        }
      } catch (e) {
        debugPrint('[Thumbs] error page $i: $e');
      }
    }
  }

  // ─── Amélioration 4 : ouvrir la bande + centrage automatique ────────────────

  void _openThumbs() {
    setState(() => _thumbsVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_thumbScrollCtrl.hasClients) return;
      const itemW = 78.0 + 6.0; // largeur vignette + séparateur
      final target = (_currentPage - 1) * itemW
          - (MediaQuery.of(context).size.width / 2 - itemW / 2);
      _thumbScrollCtrl.animateTo(
        target.clamp(0.0, _thumbScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ─── Partage ────────────────────────────────────────────────────────────────

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
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ─── Amélioration 5 : prise de rendez-vous via SMS pré-rempli ───────────────

  Future<void> _pickAppointment() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: kGreen,
            surface: kCharcoal,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: kGreen,
            surface: kCharcoal,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}h${time.minute.toString().padLeft(2, '0')}';

    final body = Uri.encodeComponent(
      "Bonjour, je vous confirme notre rendez-vous le $dateStr à $timeStr "
      "pour la présentation de l'avis de valeur de votre bien. "
      "Jérémy MORAGA — Faucigny Immobilier by Efficity",
    );
    final uri = Uri.parse('sms:?body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_presentation) return _buildPresentation();
    return _buildNormal();
  }

  // ─── Mode normal ─────────────────────────────────────────────────────────────
  // Amélioration 6 : fond kCharcoal (cohérence marque)
  // Amélioration 7 : restaure la position de la dernière session

  Widget _buildNormal() {
    return Scaffold(
      backgroundColor: kCharcoal, // Amélioration 6
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Book Vendeur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            onPressed: _enterPresentation, // Fix étape 0.4
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
          backgroundColor: kCharcoal, // Amélioration 6
          margin: 8,
          onPageChanged: (page) {
            if (mounted) {
              final p = page ?? 1;
              setState(() => _currentPage = p);
              _sessionLastPage = p; // Amélioration 7
            }
          },
          onViewerReady: (document, _) {
            if (mounted) {
              setState(() => _totalPages = document.pages.length);
              // Amélioration 7 — restaure la page de la dernière session
              if (_sessionLastPage > 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pdfController.goToPage(pageNumber: _sessionLastPage);
                });
              }
            }
          },
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
                  label: const Text('Envoyer par email',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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

  // ─── Mode présentation ───────────────────────────────────────────────────────
  //
  // • PageView.builder : swipe natif, rendu bitmap par _PdfPageBitmap
  // • _ZoomablePage    : zoom pincement + double-tap (Amélioration 3)
  // • Slide de clôture : dernier index = doc.pages.length (Amélioration 5)
  // • Miniatures       : bande horizontale animée (Amélioration 4)
  // • Wakelock         : activé pendant toute la présentation (Amélioration 1)

  Widget _buildPresentation() {
    final doc = _pdfDocument;
    if (doc == null) {
      return const Material(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    final bool isClosing = _currentPage > _totalPages;

    return Material(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [

        // ── PageView ──────────────────────────────────────────────
        PageView.builder(
          controller: _pageController,
          itemCount: doc.pages.length + 1,           // +1 slide de clôture
          allowImplicitScrolling: true,              // Amélioration 2
          physics: _zoomed
              ? const NeverScrollableScrollPhysics() // Amélioration 3
              : const PageScrollPhysics(),
          onPageChanged: (index) {
            HapticFeedback.selectionClick(); // Amélioration 6
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final page = index + 1;
                setState(() {
                  _currentPage = page;
                  _zoomed      = false; // réinitialise le zoom
                });
                _sessionLastPage = page.clamp(1, _totalPages); // Amélioration 7
                _scheduleHide();
              }
            });
          },
          itemBuilder: (ctx, index) {
            // ── Slide de clôture (Amélioration 5) ────────────────
            if (index >= doc.pages.length) {
              return GestureDetector(
                onTap: _toggleUi,
                child: _buildClosingSlide(),
              );
            }
            // ── Page PDF avec zoom (Amélioration 3) ──────────────
            // La clé inclut l'orientation : détruit/recrée l'état du zoom à
            // chaque rotation, éliminant toute transformation périmée.
            return _ZoomablePage(
              key: ValueKey('$index-${MediaQuery.of(ctx).orientation}'),
              isActive: index + 1 == _currentPage,
              onTap: _toggleUi,
              onLongPress: _openThumbs,
              onZoomChanged: (z) => setState(() => _zoomed = z),
              child: _PdfPageBitmap(
                page: doc.pages[index],
                fit: _stretchMode ? BoxFit.cover : BoxFit.contain,
              ),
            );
          },
        ),

        // ── Flèche gauche ─────────────────────────────────────────
        if (_currentPage > 1 && !_zoomed)
          Positioned(
            left: 0, top: 0, bottom: 0, width: 64,
            child: GestureDetector(
              onTap: _goPrev,
              child: _Arrow(left: true, visible: _uiVisible),
            ),
          ),

        // ── Flèche droite — masquée sur la slide de clôture ───────
        if (_currentPage <= _totalPages && !_zoomed)
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

              // ── Compteur de pages (Amélioration 5 + 6) ───────────
              if (_totalPages > 0) ...[
                isClosing
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: kGreen, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Fin',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.85), // Amélioration 6
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$_currentPage / $_totalPages',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                const SizedBox(width: 8),
              ],

              // ── Bouton miniatures (Amélioration 4) ───────────────
              GestureDetector(
                onTap: () {
                  if (_thumbsVisible) {
                    setState(() => _thumbsVisible = false);
                  } else {
                    _openThumbs();
                  }
                  if (_uiVisible) _scheduleHide();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _thumbsVisible ? kGreen.withOpacity(0.6) : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),

              // ── Bouton stretch (Amélioration 6 : kGreen au lieu d'orange) ─
              GestureDetector(
                onTap: () {
                  setState(() => _stretchMode = !_stretchMode);
                  if (_uiVisible) _scheduleHide();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _stretchMode ? kGreen.withOpacity(0.7) : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fit_screen_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),

              // ── Bouton rotation ───────────────────────────────────
              GestureDetector(
                onTap: _toggleOrientation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _forceLandscape ? kGreen.withOpacity(0.6) : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _forceLandscape
                        ? Icons.stay_current_landscape_rounded
                        : Icons.screen_rotation_rounded,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Bouton fermer ─────────────────────────────────────
              GestureDetector(
                onTap: _exitPresentation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),

        // ── Barre inférieure — masquée quand miniatures visibles ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
          bottom: (_uiVisible && !_thumbsVisible) ? 0 : -60,
          left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                MediaQuery.of(context).padding.bottom + 12),
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
                    // Amélioration 5 : progress saturée sur la slide de clôture
                    value: _currentPage.clamp(1, _totalPages) / _totalPages,
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

        // ── Bande de miniatures (Amélioration 4) ──────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
          bottom: _thumbsVisible ? 0 : -108,
          left: 0, right: 0, height: 108,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xE0000000), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: _totalPages == 0
                ? const SizedBox.shrink()
                : ListView.separated(
                    controller: _thumbScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalPages,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx2, i) {
                      final isActive = (i + 1) == _currentPage;
                      final thumb   = i < _thumbs.length ? _thumbs[i] : null;
                      return GestureDetector(
                        onTap: () {
                          _pageController?.jumpToPage(i);
                          setState(() {
                            _thumbsVisible = false;
                            _zoomed        = false;
                          });
                          _scheduleHide();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 78, height: 78,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isActive ? kGreen : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: thumb != null
                                    ? RawImage(
                                        image: thumb,
                                        fit: BoxFit.cover,
                                        width: 78, height: 78)
                                    : const ColoredBox(color: kCharcoal),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? kGreen : Colors.white54,
                                fontSize: 9,
                                fontWeight:
                                    isActive ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  // ─── Amélioration 5 : slide de clôture native Flutter ─────────────────────

  Widget _buildClosingSlide() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kCharcoal, Color(0xFF16202A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 64,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.home_work_rounded, color: kGreen, size: 64),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Et maintenant\u00a0?',
                    style: TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Passons à l'étape suivante de votre projet de vente.",
                    style: TextStyle(color: Color(0xFFB2BEC3), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _sendByEmail,
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text('Recevoir ce book par email',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen, foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _pickAppointment,
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: const Text('Planifier notre prochain rendez-vous',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Jérémy Moraga · Faucigny Immobilier by Efficity',
                    style: TextStyle(color: Color(0xFF636E72), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Amélioration 3 : widget page zoomable ────────────────────────────────────
//
// GestureDetector (tap, long-press, double-tap)
//   └── InteractiveViewer (pincement ×1–×4, pan quand zoomé)
//         └── _PdfPageBitmap (le rendu bitmap)
//
// Double-tap : zoom ×2,5 centré sur le point tapé → retour identité.
// Notification : onZoomChanged(scale > 1.05) → parent bloque le swipe PageView.

class _ZoomablePage extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onZoomChanged;
  /// Vrai quand cette page est la page courante du PageView.
  /// Permet au State de remettre le zoom à l'identité dès que la page
  /// redevient active (pages voisines conservées par allowImplicitScrolling).
  final bool isActive;

  const _ZoomablePage({
    required this.child,
    required this.onTap,
    required this.onLongPress,
    required this.onZoomChanged,
    this.isActive = false,
    super.key,
  });

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _anim;
  /// Dernière taille connue — pour détecter un changement hors-rotation.
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
      if (_anim != null) _tc.value = _anim!.value;
    });
  }

  /// Remet le zoom à l'identité quand la page redevient la page courante,
  /// afin de ne pas montrer une transformation périmée sur les pages voisines
  /// conservées en vie par allowImplicitScrolling.
  @override
  void didUpdateWidget(_ZoomablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _animCtrl.stop();
      _tc.value = Matrix4.identity();
      // _zoomed est déjà false côté parent (onPageChanged), pas besoin de rappeler onZoomChanged.
    }
  }

  /// Filet de sécurité : remet à zéro si la taille de l'écran change
  /// (split-screen, clavier, rotation sans changement d'orientation exacte).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    if (_lastSize != null && size != _lastSize) {
      _animCtrl.stop();
      _tc.value = Matrix4.identity();
      widget.onZoomChanged(false);
    }
    _lastSize = size;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _animCtrl.stop();
    final scale = _tc.value.getMaxScaleOnAxis();
    if (scale < 1.05) {
      // Zoom ×2,5 centré sur le point tapé
      // Matrice : [sx 0 0 tx] où tx = pos.dx*(1-sx), ty = pos.dy*(1-sy)
      final pos = details.localPosition;
      final target = Matrix4.identity()
        ..setEntry(0, 0, 2.5)
        ..setEntry(1, 1, 2.5)
        ..setEntry(0, 3, pos.dx * (1.0 - 2.5))
        ..setEntry(1, 3, pos.dy * (1.0 - 2.5));
      _anim = Matrix4Tween(begin: _tc.value, end: target)
          .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
      _animCtrl.forward(from: 0);
      widget.onZoomChanged(true);
    } else {
      // Retour à l'identité
      _anim = Matrix4Tween(begin: _tc.value, end: Matrix4.identity())
          .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
      _animCtrl.forward(from: 0);
      widget.onZoomChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: () {}, // requis pour activer onDoubleTapDown
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1.0,
        maxScale: 4.0,
        onInteractionEnd: (details) {
          final s = _tc.value.getMaxScaleOnAxis();
          widget.onZoomChanged(s > 1.05);
        },
        child: widget.child,
      ),
    );
  }
}

// ─── Widget de rendu d'une page PDF en bitmap ──────────────────────────────────
//
// • PdfPage.render() → pixels bruts → ui.ImmutableBuffer → RawImage
// • LayoutBuilder déclenche un re-rendu lors des changements de dimensions
// • _pendingW/_pendingH : mémorise la demande si un rendu est en cours
// • FittedBox(clipBehavior: Clip.hardEdge) : pas de débordement en mode cover

class _PdfPageBitmap extends StatefulWidget {
  final PdfPage page;
  final BoxFit  fit;
  const _PdfPageBitmap({required this.page, this.fit = BoxFit.contain, super.key});

  @override
  State<_PdfPageBitmap> createState() => _PdfPageBitmapState();
}

class _PdfPageBitmapState extends State<_PdfPageBitmap> {
  ui.Image? _image;
  double _renderW   = -1;
  double _renderH   = -1;
  bool   _rendering = false;
  double _pendingW  = -1;  // Fix étape 0.3 : mémorise la demande en attente
  double _pendingH  = -1;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _renderAt(double availW, double availH) async {
    if (_rendering) {
      // Fix étape 0.3 : relancer en post-frame après le rendu en cours
      _pendingW = availW;
      _pendingH = availH;
      return;
    }
    if ((availW - _renderW).abs() < 30 &&
        (availH - _renderH).abs() < 30 &&
        _image != null) return;
    _rendering = true;
    if (!mounted) { _rendering = false; return; }
    try {
      final dpr   = MediaQuery.of(context).devicePixelRatio;
      final scale = math.max(availW / widget.page.width,
                             availH / widget.page.height) * dpr;
      final w = (widget.page.width  * scale).round().clamp(64, 4096);
      final h = (widget.page.height * scale).round().clamp(64, 4096);

      final pdfImage = await widget.page.render(
        width: w, height: h,
        backgroundColor: const Color(0xFF000000),
      );
      if (pdfImage == null || !mounted) { _rendering = false; return; }

      final buffer     = await ui.ImmutableBuffer.fromUint8List(pdfImage.pixels);
      final descriptor = ui.ImageDescriptor.raw(buffer,
          width: pdfImage.width, height: pdfImage.height,
          pixelFormat: pdfImage.format);
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      pdfImage.dispose();

      if (mounted) {
        setState(() {
          _image?.dispose();
          _image   = frame.image;
          _renderW = availW;
          _renderH = availH;
        });
      } else {
        frame.image.dispose();
      }
    } catch (e) {
      debugPrint('[PdfPageBitmap] render error: $e');
    } finally {
      _rendering = false;
      if (_pendingW > 0) {
        final pw = _pendingW;
        final ph = _pendingH;
        _pendingW = _pendingH = -1;
        WidgetsBinding.instance.addPostFrameCallback((_) => _renderAt(pw, ph));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      if ((w - _renderW).abs() > 30 || (h - _renderH).abs() > 30) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _renderAt(w, h));
      }

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
        child: SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge, // Fix étape 0.2 + évite débordement cover
            child: SizedBox(
              width: _image!.width.toDouble(),
              height: _image!.height.toDouble(),
              child: RawImage(image: _image),
            ),
          ),
        ),
      );
    });
  }
}

// ─── Flèche de navigation ──────────────────────────────────────────────────────

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
