import 'package:flutter/material.dart';

import 'user_localization.dart';

/// Shared presentation for the dashboard's reward and insight sections.
class RewardPanel extends StatelessWidget {
  const RewardPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.accent = const Color(0xff7046c4),
  });
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, accent.withValues(alpha: .08)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: accent.withValues(alpha: .16)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: .07),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: accent, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff29213f),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xff756d82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class RewardStat extends StatelessWidget {
  const RewardStat({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe9e2f4)),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xff514568),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Future<void> showCoinCreditSuccess(BuildContext context, Object amount) async {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: reducedMotion ? 1 : .6, end: 1),
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xffffdb78), Color(0xffffa82f)],
                ),
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '+$amount',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xff7046c4),
              ),
            ),
            Text(
              userText(context, 'Coins credited!', 'Coins ലഭിച്ചു!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(userText(context, 'Done', 'ശരി')),
        ),
      ],
    ),
  );
}
