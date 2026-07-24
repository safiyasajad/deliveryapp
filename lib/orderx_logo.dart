import 'package:flutter/material.dart';

class OrderXLogo extends StatelessWidget {
  const OrderXLogo({super.key, this.size = 145, this.borderRadius = 26});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    // The logo is drawn in Flutter instead of loaded as an image asset.
    // The container creates the blue rounded square background.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0D427C),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      // CustomPaint draws the white mark inside the square.
      child: CustomPaint(painter: _OrderMarkPainter()),
    );
  }
}

class _OrderMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Canvas uses the current logo size, so these calculations keep the mark
    // proportional if the logo dimensions change later.
    final center = Offset(size.width / 2, size.height / 2);

    // Paint used for the two diagonal strokes that create the X shape.
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * .1
      ..strokeCap = StrokeCap.round;

    // Paint used for the small center ring.
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .06;

    // Start and end points are percentages of the box width, keeping the mark
    // padded inside the rounded square.
    final spokeStart = size.width * .29;
    final spokeEnd = size.width * .71;

    // Draw the two diagonal strokes first, then draw the ring on top.
    canvas
      ..drawLine(
        Offset(spokeStart, spokeStart),
        Offset(spokeEnd, spokeEnd),
        spokePaint,
      )
      ..drawLine(
        Offset(spokeEnd, spokeStart),
        Offset(spokeStart, spokeEnd),
        spokePaint,
      )
      ..drawCircle(center, size.width * .19, ringPaint);
  }

  @override
  // The logo geometry and colors are fixed, so Flutter does not need to repaint
  // this custom painter unless the painter object itself changes.
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
