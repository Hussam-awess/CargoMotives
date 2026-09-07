import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small looping "truck driving along a road" illustration for the
/// pre-login screens (Welcome, Customer sign up/log in) — purely
/// decorative, not backed by any real GPS/map data (see GpsStatusCard
/// elsewhere in the app for that). Built to make the first thing a new
/// user sees feel alive, per the product's "make the app interactive"
/// request, without needing a maps API key or any real device data.
class TruckRoadAnimation extends StatefulWidget {
  const TruckRoadAnimation({super.key, this.height = 96});

  final double height;

  @override
  State<TruckRoadAnimation> createState() => _TruckRoadAnimationState();
}

class _TruckRoadAnimationState extends State<TruckRoadAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const truckSize = 42.0;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = (constraints.maxWidth - truckSize).clamp(
            0.0,
            double.infinity,
          );

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Ease in/out rather than a linear crawl, then snap back to
              // the start — reads more like a vehicle actually
              // accelerating/decelerating than a mechanical loop.
              final t = Curves.easeInOut.transform(_controller.value);

              return CustomPaint(
                painter: _RoadPainter(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: t * travel,
                      bottom: widget.height * 0.30,
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: truckSize,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height * 0.58;

    final roadPaint = Paint()
      ..color = const Color(0xFFD8DEE4)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(0, roadY), Offset(size.width, roadY), roadPaint);

    final dashPaint = Paint()
      ..color = const Color(0xFFAFB8C1)
      ..strokeWidth = 3;

    const dashWidth = 14.0;
    const gapWidth = 12.0;
    for (double x = 0; x < size.width; x += dashWidth + gapWidth) {
      canvas.drawLine(
        Offset(x, roadY + 10),
        Offset(x + dashWidth, roadY + 10),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => false;
}
