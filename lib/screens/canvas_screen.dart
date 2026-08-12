import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePen({Color? color, double? width}) {
    // Re-create controller because properties are final in this version
    final points = _controller.points;
    final newController = SignatureController(
      penStrokeWidth: width ?? _controller.penStrokeWidth,
      penColor: color ?? _controller.penColor,
      exportBackgroundColor: _controller.exportBackgroundColor,
      points: points,
    );
    _controller.dispose();
    setState(() {
      _controller = newController;
    });
  }

  Future<void> _saveDrawing() async {
    if (_controller.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final Uint8List? data = await _controller.toPngBytes();
    if (data != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File(path);
      await file.writeAsBytes(data);
      if (mounted) Navigator.pop(context, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1112) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('لوحة الرسم / الكتابة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => _controller.clear(),
            tooltip: 'مسح اللوحة',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveDrawing,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          _buildToolbar(isDark),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _colorPicker(Colors.black),
          _colorPicker(Colors.red),
          _colorPicker(Colors.blue),
          _colorPicker(Colors.green),
          _colorPicker(Colors.orange),
          const VerticalDivider(),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.line_weight, color: Theme.of(context).primaryColor),
              onPressed: () {
                _updatePen(width: _controller.penStrokeWidth == 5 ? 10 : 5);
              },
              tooltip: 'سمك الخط',
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPicker(Color color) {
    return GestureDetector(
      onTap: () => _updatePen(color: color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _controller.penColor == color ? Colors.grey : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
