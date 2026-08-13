import 'package:flutter/material.dart';

class RuledPaperPainter extends CustomPainter {
  final double lineHeight;
  final Color lineColor;
  final Color marginColor;
  final Color paperTint;
  final bool showLineNumbers;
  final bool showHolePunches;
  final bool textured;

  RuledPaperPainter({
    required this.lineHeight,
    this.lineColor = const Color(0x552A5A8C),
    this.marginColor = const Color(0x66E57373),
    this.paperTint = const Color(0xFFFFFDF5),
    this.showLineNumbers = true,
    this.showHolePunches = true,
    this.textured = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft paper background tint
    canvas.drawRect(Offset.zero & size, Paint()..color = paperTint.withValues(alpha: 0.35));

    if (textured) {
      final speck = Paint()..color = const Color(0x14000000);
      for (double y = 0; y < size.height; y += 18) {
        for (double x = 0; x < size.width; x += 22) {
          if (((x + y) % 44).abs() < 2) {
            canvas.drawCircle(Offset(x + 3, y + 4), 0.6, speck);
          }
        }
      }
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 1.6;

    final textStyle = TextStyle(
      color: Colors.blueGrey.withValues(alpha: 0.45),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    double y = lineHeight;
    int lineNumber = 1;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      if (showLineNumbers) {
        final textSpan = TextSpan(text: '$lineNumber', style: textStyle);
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, Offset(8, y - lineHeight + (lineHeight - textPainter.height) / 2));
      }
      y += lineHeight;
      lineNumber++;
    }

    // Red margin + faint double margin for notebook feel
    final marginX = showLineNumbers ? 40.0 : 28.0;
    canvas.drawLine(Offset(marginX, 0), Offset(marginX, size.height), marginPaint);
    canvas.drawLine(
      Offset(marginX + 3, 0),
      Offset(marginX + 3, size.height),
      Paint()..color = marginColor.withValues(alpha: 0.25)..strokeWidth = 1,
    );

    if (showHolePunches) {
      final hole = Paint()..color = const Color(0x22000000);
      final holeInner = Paint()..color = const Color(0x08FFFFFF);
      for (final hy in [size.height * 0.2, size.height * 0.5, size.height * 0.8]) {
        canvas.drawCircle(Offset(14, hy), 5.5, hole);
        canvas.drawCircle(Offset(14, hy), 3.5, holeInner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RuledPaperPainter oldDelegate) {
    return oldDelegate.lineHeight != lineHeight ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor ||
        oldDelegate.paperTint != paperTint ||
        oldDelegate.showLineNumbers != showLineNumbers ||
        oldDelegate.showHolePunches != showHolePunches ||
        oldDelegate.textured != textured;
  }
}
