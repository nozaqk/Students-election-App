import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Initials from a full name, at most two letters.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return parts.take(2).map((w) => w[0].toUpperCase()).join();
}

/// 52px round candidate photo, falling back to initials when there is no picture or it fails to
/// load (`.cand img`, `.avatar`).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.src, this.size = 52});

  final String name;
  final String? src;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.avatarBg, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: p.green, fontWeight: FontWeight.w800, fontSize: size * 0.34),
      ),
    );
    final url = src;
    if (url == null || url.isEmpty) return ExcludeSemantics(child: fallback);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          semanticLabel: '',
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
        ),
      ),
    );
  }
}
