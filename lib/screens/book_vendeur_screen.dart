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

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await rootBundle.load('assets/docs/book_vendeur.pdf');
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/Book_Vendeur_Faucigny.pdf');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Book Vendeur — Faucigny Immobilier',
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13)),
              ),
            ),
          IconButton(
            icon: _sharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.share_rounded),
            tooltip: 'Partager le book',
            onPressed: _share,
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
    );
  }
}
