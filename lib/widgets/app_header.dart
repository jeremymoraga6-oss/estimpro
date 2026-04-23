import 'package:flutter/material.dart';
import '../theme.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String reference;
  final int step;
  final int totalSteps;
  final VoidCallback onBack;
  const AppHeader({
    super.key,
    required this.title,
    required this.reference,
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: kCharcoal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            const SizedBox(height: 12),
            Row(
              children: List.generate(totalSteps, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: i < step ? kGreen : const Color(0xFF4A5568),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('Étape $step sur $totalSteps',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA0AEC0))),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
}
