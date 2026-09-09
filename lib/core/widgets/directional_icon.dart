import 'package:flutter/material.dart';

/// Helper widget to automatically mirror directional icons (arrows, chevrons)
/// in Right-To-Left (Arabic) locale layouts.
class DirectionalIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const DirectionalIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (isRtl) {
      return Transform.scale(
        scaleX: -1,
        child: Icon(icon, size: size, color: color),
      );
    }
    return Icon(icon, size: size, color: color);
  }
}
