import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';
import '../services/fiches_acquereurs_service.dart';

class FichesAcquereursScreen extends StatefulWidget {
  const FichesAcquereursScreen({super.key});

  @override
  State<FichesAcquereursScreen> createState() => _FichesAcquereursScreenState();
}

class _FichesAcquereursScreenState extends State<FichesAcquereursScreen> {
  final _service = FichesAcquereursService();
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _service.listFiches();
    if (mounted) setState(() { _files = files; _loading = false; });
  }

  Future<void> _import() async {
    try {
      // withData: true → bytes toujours disponibles même via content URI Android.
      // FileType.any → sélecteur système affiche tous les fichiers.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      int imported = 0;
      final errors = <String>[];

      for (final f in result.files) {
        // f.extension est plus fiable que f.name.endsWith() sur Android
        // (certains providers ne mettent pas l'extension dans le nom).
        final ext = (f.extension ?? '').toLowerCase();
        final nameExt = f.name.contains('.')
            ? f.name.split('.').last.toLowerCase()
            : '';
        final isHtml = ext == 'html' || ext == 'htm' ||
            nameExt == 'html' || nameExt == 'htm';
        if (!isHtml) continue;

        // Normalise le nom en .html
        String name = f.name.isNotEmpty ? f.name : 'fiche_${DateTime.now().millisecondsSinceEpoch}.html';
        if (!name.toLowerCase().endsWith('.html')) {
          name = '${name.replaceAll(RegExp(r'\.[^.]+$'), '')}.html';
        }

        // Évite les doublons de nom
        final existing = _files.map((e) => e.path.split('/').last).toList();
        if (existing.contains(name)) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final base = name.replaceAll(RegExp(r'\.html$'), '');
          name = '${base}_$ts.html';
        }

        try {
          if (f.bytes != null && f.bytes!.isNotEmpty) {
            await _service.saveFicheBytes(f.bytes!, name);
            imported++;
          } else if (f.path != null) {
            await _service.saveFiche(f.path!, name);
            imported++;
          } else {
            errors.add('${f.name}: fichier inaccessible');
          }
        } catch (e) {
          errors.add('${f.name}: $e');
        }
      }

      if (!mounted) return;

      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${errors.first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (imported == 0 && result.files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sélectionnez un fichier .html'),
            backgroundColor: Color(0xFFE65100),
          ),
        );
        return;
      }

      if (imported > 0) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur import : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _delete(File file) async {
    final name = file.path.split('/').last.replaceAll('.html', '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer la fiche "$name" ?'),
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
      await _service.deleteFiche(file);
      await _load();
    }
  }

  String _formatDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _displayName(File file) =>
      file.path.split('/').last.replaceAll('.html', '').replaceAll('.htm', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Fiches Acquéreurs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _import,
            tooltip: 'Importer une fiche',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _files.isEmpty
              ? _EmptyState(onImport: _import)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final file = _files[i];
                      final name = _displayName(file);
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
                                builder: (_) => _HtmlViewerScreen(file: file, title: name),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: kCardDecoration(),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_search_rounded, color: Color(0xFFE65100), size: 24),
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
              onPressed: _import,
              backgroundColor: const Color(0xFFE65100),
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
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_search_rounded, color: Color(0xFFE65100), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Aucune fiche acquéreur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoal),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Importez vos fiches HTML générées par Claude\npour les présenter en rendez-vous acquéreur',
                style: TextStyle(fontSize: 13, color: kGrey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Importer une fiche', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );
}

// ─── Viewer HTML ──────────────────────────────────────────────────────────────

class _HtmlViewerScreen extends StatefulWidget {
  final File file;
  final String title;
  const _HtmlViewerScreen({required this.file, required this.title});

  @override
  State<_HtmlViewerScreen> createState() => _HtmlViewerScreenState();
}

class _HtmlViewerScreenState extends State<_HtmlViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await widget.file.readAsString();
    await _controller.loadHtmlString(html, baseUrl: 'about:blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: kGreen)),
      ]),
    );
  }
}
