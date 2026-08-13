import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Provider.of<NoteProvider>(context, listen: false).fetchTrashNotes();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المحذوفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_page, color: Colors.green),
            onPressed: () => _showRestoreAllDialog(context),
            tooltip: 'استعادة الكل',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: () => _showEmptyTrashDialog(context),
            tooltip: 'إفراغ السلة',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<NoteProvider>(
              builder: (ctx, noteProvider, child) {
                if (noteProvider.trashNotes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('السلة فارغة', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: noteProvider.trashNotes.length,
                  itemBuilder: (ctx, i) {
                    Note note = noteProvider.trashNotes[i];
                    final deletedAt = note.deletedAt > 0 ? note.deletedAt : note.timestamp;
                    return ListTile(
                      title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'حُذفت في: ${DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(deletedAt))}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.green),
                            onPressed: () => noteProvider.restoreNote(note.id!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('حذف نهائي'),
                                  content: Text('حذف «${note.title}» نهائياً؟ لا يمكن التراجع.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await noteProvider.permanentlyDeleteNote(note.id!);
                              }
                            },
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

  void _showRestoreAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة الكل'),
        content: const Text('هل تريد استعادة كافة الملاحظات من سلة المحذوفات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(context, listen: false).restoreAll();
              Navigator.pop(ctx);
            },
            child: const Text('استعادة', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showEmptyTrashDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه'),
        content: const Text('هل أنت متأكد من إفراغ سلة المحذوفات نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(context, listen: false).clearTrash();
              Navigator.pop(ctx);
            },
            child: const Text('إفراغ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
