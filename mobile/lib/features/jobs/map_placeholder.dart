import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    // Explicit double.infinity, not just a bare Container: CustomPaint
    // sizes itself to match its own child whenever one is given (its `size`
    // param is only honored when `child` is null) — so as soon as a marker
    // widget is passed in here, the whole placeholder (including this
    // Container) was silently collapsing down to that marker's own small
    // size instead of filling the Stack behind it, leaving everything
    // above/around it blank. Sizing the Container itself removes any
    // dependency on how CustomPaint's child happens to size itself.
    return SizedBox.expand(
      child: Container(
        color: AppColors.mapGround,
        child: CustomPaint(
          painter: _MapGridPainter(),
          child: child == null ? null : Center(child: child),
        ),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
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

/// A fleet-map position marker — a colored truck glyph (Tracksolid Pro's
/// own fleet map uses the same convention: the truck body itself carries
/// the status color, with a plate/driver label floating above it, not a
/// badge circle around a generic icon). Green (`AppColors.statusLive`)
/// means the GPS is actively reporting right now; red
/// (`AppColors.statusError`) means it's gone quiet — see FleetMapScreen's
/// own call site for the exact threshold. The white outline around the
/// truck body is drawn by layering a slightly-larger all-white copy of
/// the same glyph behind the colored one — flutter_svg's colorFilter
/// recolors an entire asset uniformly, so a single-file stroke would tint
/// along with the fill instead of staying white.
class TruckFleetMarker extends StatelessWidget {
  const TruckFleetMarker({
    super.key,
    this.color = AppColors.statusLive,
    this.label,
  });

  final Color color;

  /// Plate number (+ GPS-reported driver name, when known) shown in a
  /// small pill above the truck glyph, matching Tracksolid Pro's own map
  /// labels. Null or empty hides the pill entirely.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/truck_marker.svg',
                width: 27,
                height: 27,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              SvgPicture.asset(
                'assets/icons/truck_marker.svg',
                width: 21,
                height: 21,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ],
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1D2D3D),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
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
      ..color = AppColors.mapGridLine
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
