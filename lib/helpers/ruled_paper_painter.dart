import 'package:flutter/material.dart';

class RuledPaperPainter extends CustomPainter {
  final double lineHeight;
  final Color lineColor;
  final Color marginColor;
  final bool showLineNumbers;

  RuledPaperPainter({
    required this.lineHeight,
    this.lineColor = const Color(0x40000000),
    this.marginColor = Colors.redAccent,
    this.showLineNumbers = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    final marginPaint = Paint()
      ..color = marginColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;

    final textStyle = TextStyle(
      color: Colors.grey.withValues(alpha: 0.5),
      fontSize: 10,
    );

    // Draw horizontal lines and line numbers
    double y = lineHeight; // Start from first line
    int lineNumber = 1;
    
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      
      if (showLineNumbers) {
        final textSpan = TextSpan(
          text: '$lineNumber',
          style: textStyle.copyWith(fontWeight: FontWeight.bold),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        // Position number more accurately
        textPainter.paint(canvas, Offset(8, y - lineHeight + (lineHeight - textPainter.height) / 2));
      }
      
      y += lineHeight;
      lineNumber++;
    }

    // Draw vertical margin line
    if (showLineNumbers) {
      canvas.drawLine(Offset(40, 0), Offset(40, size.height), marginPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RuledPaperPainter oldDelegate) {
    return oldDelegate.lineHeight != lineHeight ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor ||
        oldDelegate.showLineNumbers != showLineNumbers;
  }
}
