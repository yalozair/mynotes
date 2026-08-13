import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import '../providers/note_provider.dart';
import '../models/note.dart';
import '../helpers/encryption_helper.dart';
import '../helpers/media_helper.dart';
import '../helpers/pdf_helper.dart';
import '../helpers/sticky_note_helper.dart';
import '../helpers/arabic_font_catalog.dart';
import '../helpers/export_helper.dart';
import '../helpers/analytics_helper.dart';
import '../helpers/share_link_helper.dart';
import './canvas_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/settings_provider.dart';
import '../helpers/ruled_paper_painter.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _fontSizeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  final _storageService = StorageService();
  
  Note? _currentNote;
  bool _isDirty = false;
  bool _isEncrypted = false;
  bool _isProgrammaticUpdate = false;
  int _cardColor = 0;
  String _category = 'عام';
  String _fontName = 'Cairo';
  double _fontSizeBase = 18.0;
  bool _focusMode = false;
  bool _readOnlyMode = false;
  bool _isListening = false;
  bool _isRtl = true;
  bool _isPinned = false;
  String _folder = 'الافتراضي';
  bool _findReplaceVisible = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  int _reminderTime = 0;
  int _reminderRepeat = 0;
  
  List<int> _customColors = [];

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _loadCustomColors();
    
    if (_currentNote != null) {
      _titleController.text = _currentNote!.title;
      _isEncrypted = _currentNote!.isEncrypted;
      _cardColor = _currentNote!.cardColor;
      _category = _currentNote!.category;
      _fontName = _currentNote!.fontName;
      _fontSizeBase = _currentNote!.fontSize.toDouble();
      _fontSizeController.text = _fontSizeBase.toInt().toString();
      _isRtl = _currentNote!.isRtl;
      _reminderTime = _currentNote!.reminderTime;
      _reminderRepeat = _currentNote!.reminderRepeat;
      _isPinned = _currentNote!.isPinned;
      _folder = _currentNote!.folder;

      String content = _currentNote!.contentHtml ?? '';
      if (_isEncrypted && content.isNotEmpty) {
        content = EncryptionHelper.decryptText(content);
      }

      if (content.isNotEmpty) {
        try {
          final doc = Document.fromJson(jsonDecode(content));
          _controller = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (e) {
          _controller = QuillController(
            document: Document()..insert(0, _currentNote!.content),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
      _fontSizeController.text = _fontSizeBase.toInt().toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }

    _controller.addListener(() {
      if (_isProgrammaticUpdate) return;
      if (!_isDirty && mounted) {
        setState(() => _isDirty = true);
      }
      if (mounted) setState(() {});
    });

    _titleController.addListener(() {
      if (_isProgrammaticUpdate) return;
      if (!_isDirty && mounted) {
        setState(() => _isDirty = true);
      }
    });

    _fontSizeController.text = _fontSizeBase.toInt().toString();
  }

  Future<void> _loadCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    final colors = prefs.getStringList('custom_colors') ?? [];
    if (mounted) {
      setState(() {
        _customColors = colors.map((c) => int.parse(c)).toList();
      });
    }
  }

  Future<void> _persistCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_colors',
      _customColors.map((c) => c.toString()).toList(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _fontSizeController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _focusNode.dispose();
    MediaHelper.stopListening();
    super.dispose();
  }

  void _toggleFindReplace() {
    setState(() => _findReplaceVisible = !_findReplaceVisible);
  }

  void _findNext() {
    final q = _findController.text;
    if (q.isEmpty || _controller.document.length <= 1) return;
    final plain = _controller.document.toPlainText();
    final from = (_controller.selection.baseOffset + 1).clamp(0, plain.length);
    var idx = plain.indexOf(q, from);
    if (idx < 0) idx = plain.indexOf(q);
    if (idx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نتائج')),
      );
      return;
    }
    _controller.updateSelection(
      TextSelection(baseOffset: idx, extentOffset: idx + q.length),
      ChangeSource.local,
    );
    _focusNode.requestFocus();
  }

  void _replaceOne() {
    final q = _findController.text;
    final r = _replaceController.text;
    if (q.isEmpty) return;
    final sel = _controller.selection;
    final plain = _controller.document.toPlainText();
    if (sel.isValid &&
        !sel.isCollapsed &&
        sel.start >= 0 &&
        sel.end <= plain.length &&
        plain.substring(sel.start, sel.end) == q) {
      _controller.replaceText(sel.start, q.length, r, null);
      _controller.updateSelection(
        TextSelection.collapsed(offset: sel.start + r.length),
        ChangeSource.local,
      );
      setState(() => _isDirty = true);
      return;
    }
    _findNext();
  }

  void _replaceAll() {
    final q = _findController.text;
    final r = _replaceController.text;
    if (q.isEmpty) return;
    var plain = _controller.document.toPlainText();
    if (!plain.contains(q)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نتائج')),
      );
      return;
    }
    var count = 0;
    var idx = plain.indexOf(q);
    while (idx >= 0) {
      _controller.replaceText(idx, q.length, r, null);
      count++;
      plain = _controller.document.toPlainText();
      idx = plain.indexOf(q, idx + r.length);
    }
    setState(() => _isDirty = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استبدال $count موضع')),
    );
  }

  Future<void> _showRevisions() async {
    if (_currentNote?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('احفظ المذكرة أولاً لعرض السجل')),
      );
      return;
    }
    final revisions =
        await context.read<NoteProvider>().revisionsFor(_currentNote!.id!);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (revisions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد نسخ سابقة بعد')),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: revisions.length,
          itemBuilder: (_, i) {
            final rev = revisions[i];
            final when = DateFormat('yyyy/MM/dd HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(rev.savedAt));
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(rev.title.isEmpty ? 'بدون عنوان' : rev.title),
              subtitle: Text(when),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('استعادة نسخة؟'),
                    content: Text('سيتم استبدال المحتوى الحالي بنسخة $when'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('استعادة'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !mounted) return;
                try {
                  final raw = rev.contentHtml ?? rev.content;
                  Document doc;
                  try {
                    doc = Document.fromJson(jsonDecode(raw) as List<dynamic>);
                  } catch (_) {
                    doc = Document()..insert(0, rev.content);
                  }
                  setState(() {
                    _controller.dispose();
                    _controller = QuillController(
                      document: doc,
                      selection: const TextSelection.collapsed(offset: 0),
                    );
                    _controller.addListener(() {
                      if (_isProgrammaticUpdate) return;
                      if (!_isDirty && mounted) {
                        setState(() => _isDirty = true);
                      }
                      if (mounted) setState(() {});
                    });
                    _titleController.text = rev.title;
                    _isDirty = true;
                  });
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر استعادة النسخة')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _shareProtectedLink() async {
    if (_isEncrypted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن مشاركة رابط لمذكرة مشفّرة')),
      );
      return;
    }
    if (_currentNote == null) {
      await _saveNote(showSnackbar: false);
    }
    if (_currentNote == null || !mounted) return;
    try {
      final link = await ShareLinkHelper.createProtectedLink(_currentNote!);
      if (!mounted) return;
      if (link == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إنشاء رابط المشاركة')),
        );
      }
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء الرابط: $e')),
      );
    }
  }

  Widget _buildFindReplaceBar() {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _findController,
                    decoration: const InputDecoration(
                      hintText: 'بحث...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _findNext(),
                  ),
                ),
                IconButton(
                  tooltip: 'التالي',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: _findNext,
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _findReplaceVisible = false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    decoration: const InputDecoration(
                      hintText: 'استبدال بـ...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                TextButton(onPressed: _replaceOne, child: const Text('استبدال')),
                TextButton(onPressed: _replaceAll, child: const Text('الكل')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isColorDark(int color) {
    if (color == 0) return Theme.of(context).brightness == Brightness.dark;
    final c = Color(color);
    double darkness = 1 - (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    return darkness >= 0.5;
  }

  Future<void> _saveNote({bool showSnackbar = true}) async {
    try {
      final plainTextContent = _controller.document.toPlainText().trim();
      final titleFromField = _titleController.text.trim();

      if (titleFromField.isEmpty && plainTextContent.isEmpty) {
        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن حفظ ملاحظة فارغة')),
          );
        }
        return;
      }

      final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
      var storageContent = deltaJson;
      if (_isEncrypted) {
        storageContent = EncryptionHelper.encryptText(deltaJson);
      }

      String resolvedTitle = titleFromField;
      final provider = Provider.of<NoteProvider>(context, listen: false);

      if (resolvedTitle.isEmpty) {
        int count = 1;
        while (provider.notes.any((n) => n.title == 'مذكرة $count')) {
          count++;
        }
        resolvedTitle = 'مذكرة $count';
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      if (_currentNote == null) {
        final newNote = Note(
          title: resolvedTitle,
          content: _isEncrypted ? '••••••••' : plainTextContent,
          contentHtml: storageContent,
          timestamp: now,
          isEncrypted: _isEncrypted,
          cardColor: _cardColor,
          category: _category,
          fontName: _fontName,
          fontSize: _fontSizeBase.toInt(),
          isRtl: _isRtl,
          reminderTime: _reminderTime,
          reminderRepeat: _reminderRepeat,
          isPinned: _isPinned,
          folder: _folder,
        );
        _currentNote = await provider.addNote(newNote);
      } else {
        _currentNote!.title = resolvedTitle;
        _currentNote!.content = _isEncrypted ? '••••••••' : plainTextContent;
        _currentNote!.contentHtml = storageContent;
        _currentNote!.timestamp = now;
        _currentNote!.isEncrypted = _isEncrypted;
        _currentNote!.cardColor = _cardColor;
        _currentNote!.category = _category;
        _currentNote!.fontName = _fontName;
        _currentNote!.fontSize = _fontSizeBase.toInt();
        _currentNote!.isRtl = _isRtl;
        _currentNote!.reminderTime = _reminderTime;
        _currentNote!.reminderRepeat = _reminderRepeat;
        _currentNote!.isPinned = _isPinned;
        _currentNote!.folder = _folder;
        await provider.updateNote(_currentNote!);
      }

      if (mounted) {
        setState(() {
          _isProgrammaticUpdate = true;
          _isDirty = false;
          _titleController.text = resolvedTitle;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isProgrammaticUpdate = false);
        });
        if (showSnackbar) {
          final err = provider.lastError;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err ?? 'تم الحفظ بنجاح')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Save error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleOCR() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                final text = await MediaHelper.pickImageAndRecognizeText(ImageSource.camera);
                if (text != null) _insertTextAtCursor(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () async {
                Navigator.pop(context);
                final text = await MediaHelper.pickImageAndRecognizeText(ImageSource.gallery);
                if (text != null) _insertTextAtCursor(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _insertTextAtCursor(String text) {
    final index = _controller.selection.baseOffset;
    final length = _controller.selection.extentOffset - index;
    _controller.replaceText(index, length, text, null);
  }

  void _insertImageAtCursor(String path) async {
    // If user is logged in, upload to cloud first
    String imagePath = path;
    if (Firebase.apps.isNotEmpty && AuthService().currentUser != null) {
      // Show uploading indicator if possible, or just wait
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري رفع الصورة للسحابة...'), duration: Duration(seconds: 1)),
      );
      final cloudUrl = await _storageService.uploadNoteImage(path);
      if (cloudUrl != null) {
        imagePath = cloudUrl;
      }
    }

    final index = _controller.selection.baseOffset;
    // Insert a newline before if not at the beginning
    if (index > 0) {
      _controller.document.insert(index, '\n');
    }
    _controller.document.insert(index + (index > 0 ? 1 : 0), BlockEmbed.image(imagePath));
    _controller.document.insert(index + (index > 0 ? 2 : 1), '\n');
    
    // Move selection after the inserted image
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + (index > 0 ? 3 : 2)),
      ChangeSource.local,
    );
  }

  void _openCanvas() async {
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CanvasScreen()),
    );
    
    if (!mounted) return;

    if (result is String && result.isNotEmpty) {
      // Use a small delay or post-frame callback to avoid lifecycle assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _insertImageAtCursor(result);
        }
      });
    }
  }

  void _showFontPicker() {
    ArabicFontCatalog.showPicker(
      context: context,
      selectedFontId: _fontName,
      onSelected: (fontId) {
        setState(() {
          _fontName = fontId;
          _isDirty = true;
        });
      },
    );
  }

  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر خلفية المفكرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _colorCircle(0, Icons.not_interested), // Default
                _colorCircle(0xFFF5F5F5, null),
                _colorCircle(0xFFFFFDE7, null),
                _colorCircle(0xFFE8F5E9, null),
                _colorCircle(0xFFE3F2FD, null),
                _colorCircle(0xFFFCE4EC, null),
                _colorCircle(0xFF263238, null), // Dark grey
                _colorCircle(0xFF212121, null), // Black
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.colorize),
              label: const Text('لون مخصص'),
              onPressed: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _colorCircle(int color, IconData? icon) {
    final isDefault = color == 0;
    final displayColor = isDefault 
        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white)
        : Color(color);

    return GestureDetector(
      onTap: () {
        setState(() {
          _cardColor = color;
          _isDirty = true;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: _cardColor == color ? Theme.of(context).primaryColor : Colors.grey.shade400, 
            width: _cardColor == color ? 2 : 1
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
      ),
    );
  }

  void _showColorPicker() {
    Color pickerColor = _cardColor != 0 ? Color(_cardColor) : Colors.white;
        
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر اللون'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) => pickerColor = color,
              ),
              TextField(
                decoration: const InputDecoration(hintText: 'أو أدخل كود اللون (Hex)'),
                onSubmitted: (value) {
                  try {
                    final colorStr = value.startsWith('#') ? value.replaceFirst('#', '0xFF') : '0xFF$value';
                    final color = Color(int.parse(colorStr));
                    if (mounted) {
                      setState(() {
                        _cardColor = color.toARGB32();
                        _isDirty = true;
                      });
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود لون غير صحيح')));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('حفظ'),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _cardColor = pickerColor.toARGB32();
                  _isDirty = true;
                  if (!_customColors.contains(_cardColor)) {
                    _customColors.add(_cardColor);
                  }
                });
                _persistCustomColors();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _setFontSize(double size) {
    final clamped = size.clamp(8.0, 96.0);
    setState(() {
      _fontSizeBase = clamped;
      _fontSizeController.text = clamped.toInt().toString();
      _isDirty = true;
    });
  }

  void _handleZoom(double delta) => _setFontSize(_fontSizeBase + delta);

  void _copySelection() => _controller.clipboardSelection(true);

  void _cutSelection() => _controller.clipboardSelection(false);

  Future<void> _pasteSelection() async {
    await _controller.clipboardPaste(updateEditor: () {
      if (mounted) setState(() => _isDirty = true);
    });
  }

  void _selectAllText() {
    final length = _controller.document.length - 1;
    if (length <= 0) return;
    _controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
      ChangeSource.local,
    );
  }

  Widget _buildSelectionActions() {
    if (_controller.selection.isCollapsed) return const SizedBox.shrink();
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.content_copy, size: 20),
              tooltip: 'نسخ',
              onPressed: _copySelection,
            ),
            IconButton(
              icon: const Icon(Icons.content_cut, size: 20),
              tooltip: 'قص',
              onPressed: _cutSelection,
            ),
            IconButton(
              icon: const Icon(Icons.content_paste, size: 20),
              tooltip: 'لصق',
              onPressed: _pasteSelection,
            ),
            IconButton(
              icon: const Icon(Icons.select_all, size: 20),
              tooltip: 'تحديد الكل',
              onPressed: _selectAllText,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSpeech() async {
    if (_isListening) {
      MediaHelper.stopListening();
      setState(() => _isListening = false);
      return;
    }
    final ok = await MediaHelper.initSpeech();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التعرف على الصوت غير متاح')));
      return;
    }
    final continuous =
        context.read<SettingsProvider>().continuousSpeech;
    setState(() => _isListening = true);
    MediaHelper.startListening(
      (text) {
        if (text.trim().isNotEmpty) _insertTextAtCursor(text);
      },
      continuous: continuous,
    );
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderTime > 0 ? DateTime.fromMillisecondsSinceEpoch(_reminderTime) : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderTime > 0 ? DateTime.fromMillisecondsSinceEpoch(_reminderTime) : now),
    );
    if (time == null || !mounted) return;

    final repeat = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('تكرار التذكير'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 0), child: const Text('مرة واحدة')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 1), child: const Text('يومياً')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 2), child: const Text('أسبوعياً')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 3), child: const Text('شهرياً')),
        ],
      ),
    );
    if (repeat == null) return;

    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _reminderTime = scheduled.millisecondsSinceEpoch;
      _reminderRepeat = repeat;
      _isDirty = true;
    });
    AnalyticsHelper.reminderSet();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم ضبط التذكير: ${DateFormat('yyyy/MM/dd HH:mm').format(scheduled)}')),
      );
    }
  }

  void _clearReminder() {
    setState(() {
      _reminderTime = 0;
      _reminderRepeat = 0;
      _isDirty = true;
    });
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : null),
              title: Text(_isListening ? 'إيقاف التعرف على الصوت' : 'تحويل الصوت إلى نص'),
              onTap: () {
                Navigator.pop(context);
                _toggleSpeech();
              },
            ),
            ListTile(
              leading: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(_isPinned ? 'إلغاء التثبيت' : 'تثبيت في الأعلى'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isPinned = !_isPinned;
                  _isDirty = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.find_replace),
              title: const Text('بحث واستبدال'),
              onTap: () {
                Navigator.pop(context);
                _toggleFindReplace();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('سجل التعديلات'),
              onTap: () {
                Navigator.pop(context);
                _showRevisions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('مشاركة رابط محمي'),
              onTap: () {
                Navigator.pop(context);
                _shareProtectedLink();
              },
            ),
            ListTile(
              leading: Icon(_readOnlyMode ? Icons.edit : Icons.menu_book_outlined),
              title: Text(_readOnlyMode ? 'وضع التحرير' : 'وضع القراءة'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _readOnlyMode = !_readOnlyMode;
                  _controller.readOnly = _readOnlyMode;
                });
              },
            ),
            ListTile(
              leading: Icon(_isRtl ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r),
              title: const Text('اتجاه النص'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isRtl = !_isRtl;
                  _isDirty = true;
                });
              },
            ),
            ListTile(
              leading: Icon(_isEncrypted ? Icons.lock : Icons.lock_open),
              title: const Text('تشفير المذكرة'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isEncrypted = !_isEncrypted;
                  _isDirty = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.font_download_outlined),
              title: const Text('تغيير الخط'),
              onTap: () {
                Navigator.pop(context);
                _showFontPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('خلفية المفكرة'),
              onTap: () {
                Navigator.pop(context);
                _showBackgroundPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('لون البطاقة'),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('حذف المذكرة', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _deleteNote();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('ضبط تذكير'),
              subtitle: _reminderTime > 0
                  ? Text(DateFormat('yyyy/MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_reminderTime)))
                  : null,
              onTap: () {
                Navigator.pop(context);
                _pickReminder();
              },
            ),
            if (_reminderTime > 0)
              ListTile(
                leading: const Icon(Icons.notifications_off, color: Colors.red),
                title: const Text('إلغاء التذكير'),
                onTap: () {
                  Navigator.pop(context);
                  _clearReminder();
                },
              ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('تصدير Markdown'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await ExportHelper.exportMarkdown(_titleController.text, _controller.document.toPlainText());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'تم تصدير Markdown' : 'تعذر التصدير')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.center_focus_strong),
              title: const Text('وضع التركيز'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _focusMode = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: const Text('تثبيت في الإشعارات'),
              onTap: () async {
                Navigator.pop(context);
                await StickyNoteHelper.showStickyNotification(
                  _currentNote?.id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
                  _titleController.text,
                  _isEncrypted ? 'ملاحظة مشفرة' : _controller.document.toPlainText(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.draw),
              title: const Text('لوحة الرسم / الكتابة'),
              onTap: () {
                Navigator.pop(context);
                _openCanvas();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('تصدير كملف PDF'),
              onTap: () async {
                Navigator.pop(context);
                await PDFHelper.exportToPDF(_titleController.text, _controller.document.toPlainText());
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('قارئ النصوص (OCR)'),
              onTap: () {
                Navigator.pop(context);
                _handleOCR();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNote() async {
    if (_currentNote == null) {
      Navigator.of(context).pop();
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملاحظة'),
        content: const Text('هل أنت متأكد من نقل هذه الملاحظة إلى سلة المحذوفات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      await Provider.of<NoteProvider>(context, listen: false).deleteNote(_currentNote!.id!);
      
      messenger.showSnackBar(
        const SnackBar(content: Text('تم نقل الملاحظة إلى السلة')),
      );
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final plainText = _controller.document.toPlainText().trim();
        final title = _titleController.text.trim();

        // If note is empty, just pop without asking
        if (title.isEmpty && plainText.isEmpty) {
          if (mounted) Navigator.of(context).pop();
          return;
        }

        if (_isDirty) {
          final save = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('حفظ التغييرات'),
              content: const Text('هل تريد حفظ الملاحظة قبل الخروج؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تجاهل')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            ),
          );

          if (!mounted) return;

          if (save == true) {
            await _saveNote(showSnackbar: false);
            if (mounted) {
              Navigator.of(context).pop();
            }
          } else if (save == false) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _saveNote(),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFindReplace,
          const SingleActivator(LogicalKeyboardKey.keyH, control: true): _toggleFindReplace,
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
            _controller.formatSelection(Attribute.bold);
          },
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
            _controller.formatSelection(Attribute.italic);
          },
          const SingleActivator(LogicalKeyboardKey.keyU, control: true): () {
            _controller.formatSelection(Attribute.underline);
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
            if (_controller.hasUndo) _controller.undo();
          },
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
            if (_controller.hasRedo) _controller.redo();
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
            if (_controller.hasRedo) _controller.redo();
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(_focusMode ? Icons.close_fullscreen : Icons.arrow_back),
            onPressed: () {
              if (_focusMode) {
                setState(() => _focusMode = false);
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: _focusMode
              ? const Text('وضع التركيز')
              : SizedBox(
            width: MediaQuery.of(context).size.width - 120,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.1) 
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: TextField(
              controller: _titleController,
              readOnly: _readOnlyMode,
              decoration: const InputDecoration(
                hintText: 'عنوان الملاحظة',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 16),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ),
          actions: [
            if (!_focusMode)
              IconButton(
                icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: _isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                onPressed: () => setState(() {
                  _isPinned = !_isPinned;
                  _isDirty = true;
                }),
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveNote(),
              tooltip: 'حفظ',
            ),
            if (!_focusMode)
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showMoreOptions,
                tooltip: 'المزيد',
              ),
          ],
        ),
        body: Column(
          children: [
            if (_findReplaceVisible && !_focusMode) _buildFindReplaceBar(),
            Expanded(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
                    _handleZoom(pointerSignal.scrollDelta.dy > 0 ? -1 : 1);
                  }
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width >= 900 ? 48 : 12,
                    vertical: 12,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width >= 1200 ? 900 : double.infinity,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor != 0 ? Color(_cardColor) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (settings.showLines)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: RuledPaperPainter(
                                lineHeight: _fontSizeBase + 12,
                                showLineNumbers: settings.showLineNumbers,
                                textured: settings.paperTexture,
                                showHolePunches: settings.paperHoles,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(left: settings.showLineNumbers ? 50 : 16, right: 16, top: 16, bottom: 16),
                          child: Directionality(
                            textDirection: _isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                            child: QuillEditor.basic(
                            controller: _controller,
                            focusNode: _focusNode,
                            config: QuillEditorConfig(
                              placeholder: 'ابدأ الكتابة هنا...',
                              padding: EdgeInsets.zero,
                              expands: true,
                              autoFocus: false,
                              enableSelectionToolbar: false,
                              textSelectionThemeData: TextSelectionThemeData(
                                selectionColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              ),
                              embedBuilders: [
                              LocalImageEmbedBuilder(),
                            ],
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  GoogleFonts.getFont(_fontName).copyWith(
                                    fontSize: _fontSizeBase,
                                    color: _isColorDark(_cardColor) ? Colors.white : Colors.black87,
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
            if (!_focusMode && !_readOnlyMode) _buildSelectionActions(),
            if (!_focusMode && !_readOnlyMode)
            QuillSimpleToolbar(
              controller: _controller,
              config: const QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showFontSize: false,
                showFontFamily: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showAlignmentButtons: true,
                showDirection: true,
                showListNumbers: true,
                showListBullets: true,
              ),
            ),
            if (!_focusMode) _buildBottomBar(),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isDark = _isColorDark(_cardColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('الفئة: ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
          DropdownButton<String>(
            value: _category,
            underline: const SizedBox(),
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            items: ['عام', 'خاص', 'شخصي'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) => setState(() { _category = val!; _isDirty = true; }),
          ),
          const Spacer(),
          const Icon(Icons.format_size, size: 18),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _setFontSize(_fontSizeBase - 1),
          ),
          SizedBox(
            width: 44,
            height: 34,
            child: TextField(
              controller: _fontSizeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) {
                  _setFontSize(parsed.toDouble());
                } else {
                  _fontSizeController.text = _fontSizeBase.toInt().toString();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _setFontSize(_fontSizeBase + 1),
          ),
          if (_customColors.isNotEmpty)
            ..._customColors.reversed.take(3).map((c) => GestureDetector(
              onTap: () => setState(() { _cardColor = c; _isDirty = true; }),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: Colors.grey, width: 0.5)),
              ),
            )),
        ],
      ),
    );
  }
}

class LocalImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    try {
      final imageUrl = embedContext.node.value.data;
      if (imageUrl is String && imageUrl.isNotEmpty) {
        if (imageUrl.startsWith('http')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text('فشل تحميل الصورة من السحابة: $imageUrl', style: const TextStyle(color: Colors.red, fontSize: 10))),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
        
        final file = File(imageUrl);
        if (!file.existsSync()) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('الملف المحلي غير موجود (ربما تم حذفه): $imageUrl', style: const TextStyle(color: Colors.orange, fontSize: 10)),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Text('خطأ في عرض الصورة المحلية: $imageUrl', style: const TextStyle(color: Colors.red));
              },
            ),
          ),
        );
      }
    } catch (e) {
      return const Text('خطأ في معالجة عنصر الصورة', style: TextStyle(color: Colors.red));
    }
    return const SizedBox.shrink();
  }
}
