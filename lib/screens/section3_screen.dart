import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/estimation.dart';
import '../widgets/shared.dart';
import '../widgets/app_header.dart';

class Section3Screen extends StatefulWidget {
  final Estimation estimation;
  final ValueChanged<Estimation> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const Section3Screen({super.key, required this.estimation, required this.onChanged, required this.onNext, required this.onPrev});

  @override
  State<Section3Screen> createState() => _Section3ScreenState();
}

const _annexeDefs = [
  {'id': 'garage',   'label': 'Garage',   'emoji': '🚗'},
  {'id': 'terrasse', 'label': 'Terrasse', 'emoji': '🌿'},
  {'id': 'balcon',   'label': 'Balcon',   'emoji': '🏠'},
  {'id': 'cave',     'label': 'Cave',     'emoji': '📦'},
  {'id': 'jardin',   'label': 'Jardin',   'emoji': '🌳'},
  {'id': 'piscine',  'label': 'Piscine',  'emoji': '💧'},
  {'id': 'parking',  'label': 'Parking',  'emoji': '🅿️'},
];

class _Section3ScreenState extends State<Section3Screen> {
  late Estimation _e;

  @override
  void initState() { super.initState(); _e = widget.estimation; }

  void _update(Estimation e) { setState(() => _e = e); widget.onChanged(e); }

  void _toggleAnnexe(String id) {
    final map = Map<String, bool>.from(_e.annexesActives);
    map[id] = !(map[id] ?? false);
    _update(_e.copyWith(annexesActives: map));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppHeader(title: 'Annexes & dépendances', reference: _e.reference, step: 3, totalSteps: 7, onBack: widget.onPrev),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Activez les dépendances présentes',
                style: TextStyle(fontSize: 12, color: Color(0xFF95A5A6), fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),

            // 2-column toggle grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
              ),
              itemCount: _annexeDefs.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _annexeDefs.length) return _addCard();
                final def = _annexeDefs[i];
                final id = def['id']!;
                final on = _e.annexesActives[id] ?? false;
                return GestureDetector(
                  onTap: () => _toggleAnnexe(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: on ? kGreen.withOpacity(0.3) : Colors.transparent, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 2))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(def['emoji']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(def['label']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kCharcoal), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: AppToggle(value: on, onChanged: (_) => _toggleAnnexe(id))),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Expanded: Garage
            if (_e.annexesActives['garage'] == true) ...[
              _ExpandedCard(
                emoji: '🚗', label: 'Garage',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StepperField(label: 'Nombre de places', value: _e.garagePlaces, onChange: (v) => _update(_e.copyWith(garagePlaces: v))),
                  const SizedBox(height: 12),
                  const FieldLabel('Type'),
                  const SizedBox(height: 6),
                  ChipGroup(options: const ['Intégré', 'Séparé', 'Box fermé'], selected: _e.garageType, onToggle: (v) {
                    final list = List<String>.from(_e.garageType);
                    list.contains(v) ? list.remove(v) : list.add(v);
                    _update(_e.copyWith(garageType: list));
                  }),
                  const SizedBox(height: 14),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            // Expanded: Jardin
            if (_e.annexesActives['jardin'] == true) ...[
              _ExpandedCard(
                emoji: '🌳', label: 'Jardin',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StepperField(label: 'Surface approximative', value: _e.jardinSurface, unit: ' m²', step: 25,
                      onChange: (v) => _update(_e.copyWith(jardinSurface: v))),
                  const SizedBox(height: 12),
                  const FieldLabel('État'),
                  const SizedBox(height: 6),
                  ChipGroup(options: const ['Entretenu', 'À entretenir', 'En friche'], selected: _e.jardinEtat, onToggle: (v) {
                    final list = List<String>.from(_e.jardinEtat);
                    list.contains(v) ? list.remove(v) : list.add(v);
                    _update(_e.copyWith(jardinEtat: list));
                  }),
                  const SizedBox(height: 14),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 16),
          ]),
        ),
      ),
      SectionBottomBar(onPrev: widget.onPrev, onNext: widget.onNext),
    ]);
  }

  Widget _addCard() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCCCCCC), width: 2, style: BorderStyle.solid),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLightGrey, width: 2, style: BorderStyle.solid)),
            child: const Icon(Icons.add, size: 16, color: kLightGrey),
          ),
          const SizedBox(height: 8),
          const Text('Autre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kLightGrey)),
        ]),
      );
}

class _ExpandedCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Widget child;
  const _ExpandedCard({required this.emoji, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: kGreen, width: 4)),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$emoji $label', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
              const Icon(Icons.keyboard_arrow_up, color: kLightGrey, size: 18),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 0), child: child),
        ]),
      );
}
