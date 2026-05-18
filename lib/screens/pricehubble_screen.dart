import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../theme.dart';
import '../services/pricehubble_folder_service.dart';

class PriceHubbleScreen extends StatefulWidget {
  const PriceHubbleScreen({super.key});

  @override
  State<PriceHubbleScreen> createState() => _PriceHubbleScreenState();
}

class _PriceHubbleScreenState extends State<PriceHubbleScreen> {
  final _service = PriceHubbleFolderService();
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _service.listPdfs();
    if (mounted) setState(() { _files = files; _loading = false; });
  }

  Future<void> _importPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      if (f.path == null) continue;
      String name = f.name;
      // Evite les doublons de nom
      final existing = _files.map((e) => e.path.split('/').last).toList();
      if (existing.contains(name)) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        name = '${name.replaceAll('.pdf', '')}_$ts.pdf';
      }
      await _service.savePdf(f.path!, name);
    }
    await _load();
  }

  Future<void> _delete(File file) async {
    final name = file.path.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "$name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deletePdf(file);
      await _load();
    }
  }

  String _formatDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Estimations PriceHubble', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _importPdf,
            tooltip: 'Importer un PDF',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _files.isEmpty
              ? _EmptyState(onImport: _importPdf)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final file = _files[i];
                      final name = file.path.split('/').last.replaceAll('.pdf', '');
                      final date = _formatDate(file.statSync().modified);
                      final size = (file.lengthSync() / 1024).round();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: Key(file.path),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _delete(file);
                            return false;
                          },
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _PdfViewerScreen(file: file, title: name),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: kCardDecoration(),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1976D2), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCharcoal),
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 3),
                                    Text('$date · $size Ko',
                                        style: const TextStyle(fontSize: 11, color: kLightGrey)),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: kLightGrey, size: 20),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _files.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importPdf,
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Importer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1976D2), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Aucune estimation PriceHubble',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Importez vos rapports PDF PriceHubble\npour les présenter aux vendeurs',
                style: TextStyle(fontSize: 13, color: kGrey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Importer un PDF', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );
}

class _PdfViewerScreen extends StatefulWidget {
  final File file;
  final String title;
  const _PdfViewerScreen({required this.file, required this.title});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  late final PdfViewerController _controller;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
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
      body: PdfViewer.file(
        widget.file.path,
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
