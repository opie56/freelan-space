import 'package:flutter/material.dart';

import 'design.dart';
import 'user_tokens.dart';

/// Shared visual elements for referral destinations.
class ReferralSurface extends StatelessWidget {
  const ReferralSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe9e6f2)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff302251).withValues(alpha: .05),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class ReferralHeader extends StatelessWidget {
  const ReferralHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    this.dark = false,
  });
  final String eyebrow, title, description;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: dark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff29105f), Color(0xff5e25c9), Color(0xff8a56ec)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffeff8f5), Color(0xffe4f3f0), Color(0xfff2edff)],
            ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: .16) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: dark ? Colors.white : userTeal),
        ),
        const SizedBox(height: 20),
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: dark ? const Color(0xffe3d6ff) : userTeal,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: dark ? Colors.white : growthInk,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: dark ? const Color(0xffeee5ff) : const Color(0xff4c665f),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class ReferralActionTile extends StatelessWidget {
  const ReferralActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ReferralSurface(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: growthInk,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: userMuted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xff8a829f),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
