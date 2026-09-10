import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A styled stand-in for a real map (no Google Maps API key provisioned
/// yet, the same documented scope gap since Phase 6) — a grid ("streets")
/// over a flat ground tone, sized to fill exactly the space a real
/// `GoogleMap` widget will occupy later, so swapping it in only ever
/// touches whichever screen embeds this. Shared by Live GPS Tracking and
/// the Fleet Map.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEFEA),
      child: CustomPaint(
        painter: _MapGridPainter(),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

/// A single pulsing position marker, matching the mockup's live-truck dot.
class PulsingMarker extends StatelessWidget {
  const PulsingMarker({super.key, this.color = AppColors.ctaBlue});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
          ),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small square icon button floating over the map, matching the
/// mockup's back/zoom/recenter controls.
class MapFloatingButton extends StatelessWidget {
  const MapFloatingButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [BoxShadow(color: Color(0x1F1D2D3D), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E2DC)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
