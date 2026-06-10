import 'package:flutter/material.dart';
import '../theme.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String reference;
  final int step;
  final int totalSteps;
  final VoidCallback onBack;
  final ValueChanged<int>? onStepTap;

  const AppHeader({
    super.key,
    required this.title,
    required this.reference,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    this.onStepTap,
  });

  // Labels courts affichés sous chaque numéro de section
  static const _stepLabels = [
    'Vendeur',
    'Bien',
    'Annexes',
    'État',
    'Marché',
    'Estim.',
    'Photos',
  ];

  @override
  Widget build(BuildContext context) => Container(
        color: kCharcoal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : flèche retour + titre + badge réf ──────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bouton retour — plus grand et plus facile à toucher
                GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Retour', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(20)),
                  child: Text(reference,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Ligne 2 : indicateurs de progression avec labels ─
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(totalSteps, (i) {
                final isCurrent = i == step - 1;
                final isDone    = i < step - 1;
                final label     = i < _stepLabels.length ? _stepLabels[i] : '${i + 1}';

                final circleColor = isCurrent
                    ? kGreen
                    : isDone
                        ? kGreen.withValues(alpha: 0.30)
                        : const Color(0xFF4A5568);
                final textColor = isCurrent
                    ? Colors.white
                    : const Color(0xFF90A4AE);
                final labelColor = isCurrent
                    ? Colors.white
                    : isDone
                        ? kGreen.withValues(alpha: 0.85)
                        : const Color(0xFF607D8B);

                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: !isCurrent && onStepTap != null ? () => onStepTap!(i + 1) : null,
                  child: SizedBox(
                    width: 44,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cercle numéroté
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                            border: isCurrent
                                ? Border.all(color: Colors.white, width: 2)
                                : Border.all(color: Colors.white24, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: isDone
                              ? Icon(Icons.check_rounded, color: kGreen, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11,
                                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        // Label sous le cercle
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: labelColor,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
}
