import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

class AdresseSuggestion {
  final String label;
  final String codeInsee;
  final String codePostal;
  final double latitude;
  final double longitude;
  final String commune;

  const AdresseSuggestion({
    required this.label,
    required this.codeInsee,
    required this.codePostal,
    required this.latitude,
    required this.longitude,
    required this.commune,
  });

  factory AdresseSuggestion.fromFeature(Map<String, dynamic> f) {
    final props = f['properties'] as Map<String, dynamic>;
    final coords = (f['geometry']?['coordinates'] as List?) ?? [0.0, 0.0];
    return AdresseSuggestion(
      label: props['label'] as String? ?? '',
      codeInsee: props['citycode'] as String? ?? '',
      codePostal: props['postcode'] as String? ?? '',
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
      commune: props['city'] as String? ?? '',
    );
  }
}

class AdresseField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<AdresseSuggestion> onSelected;

  const AdresseField({
    super.key,
    required this.initialValue,
    required this.onSelected,
  });

  @override
  State<AdresseField> createState() => _AdresseFieldState();
}

class _AdresseFieldState extends State<AdresseField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<AdresseSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialValue;
    _focus.addListener(() {
      if (!_focus.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://api-adresse.data.gouv.fr/search/')
          .replace(queryParameters: {'q': q, 'limit': '5'});
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = (json['features'] as List?) ?? [];
      _suggestions = features
          .map((f) => AdresseSuggestion.fromFeature(f as Map<String, dynamic>))
          .where((s) => s.codeInsee.isNotEmpty)
          .toList();
      _showOverlay();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty) return;
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: _fieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _select(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: kGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style: const TextStyle(
                                        fontSize: 13, color: kCharcoal)),
                                Text('INSEE ${s.codeInsee} · ${s.commune}',
                                    style: const TextStyle(
                                        fontSize: 10, color: kGrey)),
                              ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _select(AdresseSuggestion s) {
    _ctrl.text = s.label;
    _removeOverlay();
    _focus.unfocus();
    widget.onSelected(s);
  }

  double _fieldWidth() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? 300;
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Ex : 14 Chemin des Granges, Ayse',
            hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
            prefixIcon: const Icon(Icons.location_on_outlined,
                size: 18, color: kGreen),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: kGreen)))
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: kBorderColor, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: kBorderColor, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kGreen, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 14, color: kCharcoal),
        ),
      );
}
