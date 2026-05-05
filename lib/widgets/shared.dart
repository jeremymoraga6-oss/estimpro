import 'package:flutter/material.dart';
import '../theme.dart';

// ── Section card wrapper ─────────────────────────────────────
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const SectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: padding ?? const EdgeInsets.all(14),
        decoration: kCardDecoration(),
        child: child,
      );
}

// ── Card title row ────────────────────────────────────────────
class CardTitleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const CardTitleRow({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kGreen),
            const SizedBox(width: 8),
            Text(label, style: kCardTitle),
          ],
        ),
      );
}

// ── Field label ───────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: kLabel),
      );
}

// ── Divider ────────────────────────────────────────────────────
class CardDivider extends StatelessWidget {
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: const Color(0xFFF0F0F0),
        margin: const EdgeInsets.only(bottom: 12, top: 4),
      );
}

// ── Pill selector ──────────────────────────────────────────────
class PillSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  const PillSelector({super.key, required this.options, required this.selected, required this.onSelect});

  Color _colorFor(String opt) {
    final s = opt.toLowerCase();
    if (s.contains('bon') || s.contains('normes') || s.contains('bonne') || s.contains('neuf')) return kGreen;
    if (s.contains('moyen') || s.contains('partiel') || s.contains('travaux')) return kAmber;
    if (s.contains('refaire') || s.contains('mauvaise') || s.contains('vétuste') || s.contains('rénover')) return kRed;
    return kGreen;
  }

  @override
  Widget build(BuildContext context) => Row(
        children: options.map((opt) {
          final isSel = selected == opt;
          final col = _colorFor(opt);
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                height: 36,
                decoration: BoxDecoration(
                  color: isSel ? col : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSel ? col : kBorderColor,
                    width: isSel ? 0 : 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isSel ? Colors.white : kGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── Multi-chip selector ────────────────────────────────────────
class ChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final bool wrap;
  const ChipGroup({super.key, required this.options, required this.selected, required this.onToggle, this.wrap = true});

  @override
  Widget build(BuildContext context) {
    final chips = options.map((opt) {
      final isSel = selected.contains(opt);
      return GestureDetector(
        onTap: () => onToggle(opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSel ? kGreen : kBorderColor, width: 1.5),
          ),
          child: Text(opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                color: isSel ? Colors.white : kGrey,
              )),
        ),
      );
    }).toList();

    return wrap
        ? Wrap(spacing: 7, runSpacing: 7, children: chips)
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 7), child: c)).toList()),
          );
  }
}

// ── Stepper widget ─────────────────────────────────────────────
class StepperField extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int step;
  final ValueChanged<int> onChange;
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.step = 1,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) FieldLabel(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EDE8), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _btn(Icons.remove, () => onChange(value > 0 ? value - step : 0), filled: false),
                Text(
                  '$value$unit',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kCharcoal, letterSpacing: -0.5),
                ),
                _btn(Icons.add, () => onChange(value + step), filled: true),
              ],
            ),
          ),
        ],
      );

  Widget _btn(IconData icon, VoidCallback onTap, {required bool filled}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: filled ? kGreen : Colors.white,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: kLightGrey, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: filled ? Colors.white : kGrey),
        ),
      );
}

// ── DPE selector ───────────────────────────────────────────────
class DpeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool showLabel;
  const DpeSelector({super.key, required this.selected, required this.onSelect, this.showLabel = true});

  static const classes = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'NC'];
  static const ranges = {'A': '<50', 'B': '51–90', 'C': '91–150', 'D': '151–230', 'E': '231–330', 'F': '331–450', 'G': '>450', 'NC': 'Non communiqué'};

  static const _mainClasses = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  Widget _dpeBtn(String l, bool isSel) {
    final color = kDpeColors[l]!;
    return GestureDetector(
      onTap: () => onSelect(l),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 3),
        height: isSel ? 44 : 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(isSel ? 6 : 4),
          border: isSel ? Border.all(color: kCharcoal, width: 2.5) : null,
          boxShadow: isSel ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(l, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: isSel ? 15 : 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _mainClasses.map((l) => Expanded(child: _dpeBtn(l, selected == l))).toList(),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => onSelect('NC'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected == 'NC' ? kDpeColors['NC']! : kDpeColors['NC']!.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: selected == 'NC' ? Border.all(color: kCharcoal, width: 2) : null,
              ),
              child: Text(
                'NC — DPE non communiqué',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected == 'NC' ? Colors.white : kGrey,
                ),
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            Text(
              selected == 'NC'
                  ? '⚠️ DPE inconnu — à exiger avant estimation définitive'
                  : 'Classe $selected · ${ranges[selected]} kWh/m².an',
              style: TextStyle(fontSize: 11, color: selected == 'NC' ? kAmber : kGrey),
            ),
          ],
        ],
      );
}

// ── État général selector (colored dots) ──────────────────────
class EtatSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const EtatSelector({super.key, required this.selected, required this.onSelect});

  static const labels = ['À rénover', 'Travaux', 'Bon état', 'Très bon', 'Neuf'];
  static const colors = [kRed, kAmber, Color(0xFFFDD835), Color(0xFF8BC34A), Color(0xFF43A047)];

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(5, (i) {
          final isSel = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: isSel ? 28 : 18,
                    height: isSel ? 28 : 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i],
                      border: isSel ? Border.all(color: kCharcoal, width: 2.5) : null,
                      boxShadow: isSel ? [BoxShadow(color: colors[i].withOpacity(0.3), blurRadius: 8)] : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: isSel ? kCharcoal : kLightGrey,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }),
      );
}

// ── iOS-style toggle ───────────────────────────────────────────
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: value ? kGreen : const Color(0xFFCCCCCC),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: value ? 18 : 2,
                top: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Dropdown field ─────────────────────────────────────────────
class DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const DropdownField({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: kLightGrey, size: 18),
                style: const TextStyle(fontSize: 14, color: kCharcoal, fontFamily: 'DMSans'),
                items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
              ),
            ),
          ),
        ],
      );
}

// ── Bottom nav bar ──────────────────────────────────────────────
class SectionBottomBar extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String nextLabel;
  const SectionBottomBar({super.key, this.onPrev, required this.onNext, this.nextLabel = 'Suivant'});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            if (onPrev != null) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onPrev,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Précédent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kGrey,
                    side: const BorderSide(color: kBorderColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: onNext,
                icon: Text(nextLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                label: const Icon(Icons.arrow_forward, size: 16),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
}
