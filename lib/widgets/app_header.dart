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

  @override
  Widget build(BuildContext context) => Container(
        color: kCharcoal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(20)),
                  child: Text(reference, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalSteps, (i) {
                final isCurrent = i == step - 1;
                final isDone = i < step - 1;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: !isCurrent && onStepTap != null ? () => onStepTap!(i + 1) : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? kGreen
                          : isDone
                              ? kGreen.withValues(alpha: 0.25)
                              : const Color(0xFF4A5568),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: kGreen, size: 16)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isCurrent ? Colors.white : const Color(0xFF90A4AE),
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
}
