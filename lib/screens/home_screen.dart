import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../providers/settings_provider.dart';
import './note_editor_screen.dart';
import './settings_screen.dart';
import './trash_screen.dart';
import './stats_dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/auth_helper.dart';
import '../helpers/update_helper.dart';
import '../helpers/ad_helper.dart';
import '../helpers/permission_helper.dart';
import '../helpers/template_helper.dart';
import '../helpers/native_helper.dart';
import '../helpers/analytics_helper.dart';
import '../helpers/sticky_note_helper.dart';
import '../helpers/tag_helper.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isLockEnabled = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _selectedTag = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isMiniMode = false;
  String _lockHint = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockHint();
    _checkAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateHelper.checkForUpdate(context);
        _handleLaunchAction();
        if (Platform.isAndroid) StickyNoteHelper.showQuickNoteShortcut();
      }
    });
  }

  Future<void> _handleLaunchAction() async {
    final action = await NativeHelper.getLaunchAction();
    if (!mounted || action == null) return;
    if (action == 'quick_note' || action == 'new_note') {
      AnalyticsHelper.quickNoteOpened();
      await _openEditor();
    }
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر قالباً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...TemplateHelper.templates.map((t) => ListTile(
                  leading: Icon(_templateIcon(t.icon)),
                  title: Text(t.title),
                  subtitle: Text(t.category),
                  onTap: () {
                    Navigator.pop(ctx);
                    AnalyticsHelper.templateUsed(t.id);
                    _openEditor(t.toNote());
                  },
                )),
          ],
        ),
      ),
    );
  }

  IconData _templateIcon(String name) {
    switch (name) {
      case 'groups':
        return Icons.groups;
      case 'checklist':
        return Icons.checklist;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'book':
        return Icons.book;
      case 'school':
        return Icons.school;
      default:
        return Icons.description;
    }
  }

  Future<void> _loadLockHint() async {
    final hint = await AuthHelper.deviceLockMethodsHint();
    if (mounted) setState(() => _lockHint = hint);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLockEnabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isAuthenticated && mounted) {
        setState(() => _isAuthenticated = false);
      }
    } else if (state == AppLifecycleState.resumed && !_isAuthenticated) {
      _checkAuth();
    }
  }

  Future<void> _handleExitApp() async {
    await AdHelper.showExitAd();
    SystemNavigator.pop();
  }

  Future<void> _refreshNotes() async {
    if (!mounted) return;
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await noteProvider.fetchNotes();
    await noteProvider.purgeExpiredTrash(settings.trashInterval);
    await noteProvider.syncAll();
    if (!mounted) return;
    if (noteProvider.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(noteProvider.lastError!)),
      );
    }
  }

  double _footerBottomInset(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return isLandscape ? 56 : 72;
  }

  Future<void> _loadNotesAndSync() async {
    if (!mounted) return;
    await PermissionHelper.ensureAllGranted(context);
    if (!mounted) return;
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    noteProvider.bindUser(uid);
    await noteProvider.fetchNotes();
    await noteProvider.purgeExpiredTrash(settings.trashInterval);
    await noteProvider.syncAll();
    if (!mounted) return;
    if (noteProvider.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(noteProvider.lastError!)),
      );
    }
  }

  Future<void> _checkAuth() async {
    _isLockEnabled = await AuthHelper.isLockEnabled();
    if (_isLockEnabled) {
      final success = await AuthHelper.authenticate();
      if (success && mounted) {
        setState(() => _isAuthenticated = true);
        await _loadNotesAndSync();
      }
    } else if (mounted) {
      setState(() => _isAuthenticated = true);
      await _loadNotesAndSync();
    }
  }

  bool _isColorDark(int color) {
    if (color == 0) return Theme.of(context).brightness == Brightness.dark;
    final c = Color(color);
    double darkness = 1 - (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    return darkness >= 0.5;
  }

  Widget _buildNoteTags(Note note, {required bool isDark, int maxTags = 3, bool compact = false}) {
    final tags = TagHelper.parseTags(note.tags);
    if (tags.isEmpty) return const SizedBox.shrink();

    final chipColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white70 : Colors.black54;
    final effectiveMax = compact ? maxTags.clamp(1, 2) : maxTags;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 2 : 4),
      child: SizedBox(
        height: compact ? 20 : null,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: compact ? const NeverScrollableScrollPhysics() : null,
          child: Row(
            children: tags.take(effectiveMax).map((tag) {
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTag = tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$tag',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: textColor),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _launchUrl(String url) async {
    if (url == '#') return;
    if (!await launchUrl(Uri.parse(url))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  void _showProfileDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1112),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF26C6DA), width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundImage: AssetImage('assets/images/profile.png'),
                        backgroundColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'المهندس يوسف العزير',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const Text(
                      '(IT Specialist) أخصائي تقنية معلومات',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const Text(
                      'خبير دعم فني وإدارة شبكات',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'متخصص في تقنية المعلومات يتميز بخبرة واسعة في الدعم الفني، إدارة الشبكات، وأنظمة الحاسب. يمتلك قدرة عالية على تشخيص الأعطال وحل مشاكل الأجهزة والبرمجيات بكفاءة، ويُعرف بسرعة تعلمه ومهاراته التحليلية القوية التي تمكّنه من تقديم حلول تقنية موثوقة وعالية الجودة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        _profileAction(FontAwesomeIcons.phone, 'اتصال', const Color(0xFF1D2733), const Color(0xFF43A047), 'tel:+967773640964'),
                        _profileAction(FontAwesomeIcons.whatsapp, 'واتساب', const Color(0xFF1D2733), const Color(0xFF66BB6A), 'https://wa.me/967773640964'),
                        _profileAction(FontAwesomeIcons.paperPlane, 'تلجرام', const Color(0xFF1D2733), const Color(0xFF29B6F6), 'https://t.me/Eng_yousifalozair'),
                        _profileAction(FontAwesomeIcons.facebook, 'فيسبوك', const Color(0xFF1D2733), const Color(0xFF1565C0), 'https://www.facebook.com/AlOzairForComputer/'),
                        _profileAction(FontAwesomeIcons.youtube, 'يوتيوب', const Color(0xFF1D2733), const Color(0xFFEF5350), 'https://www.youtube.com/channel/UCRD7n62-LCHyr7VtlerLGnA?view_as=subscriber'),
                      ],
                    ),
                    const SizedBox(height: 40), // Spacing at the bottom to avoid edge clipping
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileAction(dynamic icon, String label, Color bgColor, Color iconColor, String url) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => url != '#' ? _launchUrl(url) : null,
          child: Container(
            width: 65, height: 65,
            decoration: BoxDecoration(
              color: bgColor, 
              shape: BoxShape.circle, 
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), 
                  blurRadius: 8, 
                  offset: const Offset(0, 4)
                )
              ]
            ),
            child: Center(child: FaIcon(icon, color: iconColor, size: 28)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => NoteEditorScreen(note: note)),
    );
    if (mounted) {
      await Provider.of<NoteProvider>(context, listen: false).fetchNotes();
    }
  }

  Widget _buildSyncBanner(NoteProvider provider) {
    final color = switch (provider.syncStatus) {
      SyncStatus.syncing => Colors.blue.shade50,
      SyncStatus.pending => Colors.orange.shade50,
      SyncStatus.error => Colors.red.shade50,
      SyncStatus.offline => Colors.grey.shade200,
      SyncStatus.saved => Colors.green.shade50,
    };
    final icon = switch (provider.syncStatus) {
      SyncStatus.syncing => Icons.sync,
      SyncStatus.pending => Icons.cloud_upload,
      SyncStatus.error => Icons.error_outline,
      SyncStatus.offline => Icons.cloud_off,
      SyncStatus.saved => Icons.cloud_done,
    };
    return Material(
      color: color,
      child: InkWell(
        onTap: provider.isLoggedIn && provider.syncStatus != SyncStatus.syncing
            ? () => provider.syncAll()
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(provider.syncStatusLabel, style: const TextStyle(fontSize: 12))),
              if (provider.syncStatus == SyncStatus.syncing)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int noteId) async {
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

    if (!mounted) return;

    if (confirm == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      noteProvider.deleteNote(noteId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نقل الملاحظة إلى السلة')),
      );
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPosition, Note note) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))])),
      ],
    );

    if (!mounted) return;

    if (result == 'edit') {
      if (!mounted) return;
      _openEditor(note);
    } else if (result == 'delete') {
      if (!mounted) return;
      _confirmDelete(context, note.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLockEnabled && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'التطبيق مقفل',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _lockHint.isEmpty
                      ? 'استخدم طريقة قفل جهازك للدخول'
                      : 'استخدم: $_lockHint',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('فتح القفل'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final noteProvider = Provider.of<NoteProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    if (_isMiniMode) {
      return _buildMiniMode(noteProvider);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExitApp();
      },
      child: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [settings.themeColor, settings.themeColor.withValues(alpha: 0.8)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black45,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'بحث...', 
                border: InputBorder.none, 
                hintStyle: TextStyle(color: Colors.white70)
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => setState(() => _searchQuery = val),
            )
          : const Text('مفكرتي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: noteProvider.isSyncing 
          ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
            ) 
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const StatsDashboardScreen())),
            tooltip: 'الإحصائيات',
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.desktop_windows, color: Colors.white),
            onPressed: () => setState(() => _isMiniMode = true),
            tooltip: 'وضع النافذة الصغيرة',
          ),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (val) {
              if (val == 'settings') {
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SettingsScreen()));
              } else if (val == 'trash') {
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => const TrashScreen()));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'trash', child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('سلة المحذوفات')])),
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('الإعدادات')])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          _buildSyncBanner(noteProvider),
          _buildCategoryFilter(noteProvider),
          if (noteProvider.allTags.isNotEmpty) _buildTagFilter(noteProvider),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshNotes,
              child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive values
                int cols = settings.gridColumns;
                double spacing = 10.0;
                double totalSpacing = (cols - 1) * spacing + 16.0; // 16 is padding
                double itemWidth = (constraints.maxWidth - totalSpacing) / cols;
                
                // Adjust height based on rows — enforce minimum card height (landscape fix)
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                final minCardHeight = isLandscape ? 130.0 : 145.0;
                double itemHeight = (constraints.maxHeight - (settings.gridRows - 1) * spacing - 16.0) / settings.gridRows;
                if (itemHeight < minCardHeight) itemHeight = minCardHeight;
                double dynamicAspectRatio = (itemWidth / itemHeight).clamp(0.55, 2.2);

                final filteredNotes = noteProvider.notesFor(
                  query: _searchQuery,
                  category: _selectedCategory,
                  tag: _selectedTag,
                );

                return Builder(
                  builder: (ctx) {
                    if (filteredNotes.isEmpty && noteProvider.notes.isEmpty && noteProvider.isSyncing) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (filteredNotes.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * 0.65,
                            child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_note, size: 100, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isEmpty ? 'لا توجد ملاحظات حالياً' : 'لم يتم العثور على نتائج', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text('اسحب للأسفل للمزامنة', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ],
                        ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (settings.viewMode == 'list') {
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredNotes.length,
                        itemBuilder: (ctx, i) {
                          final note = filteredNotes[i];
                          return GestureDetector(
                            onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, note),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: note.cardColor != 0 ? Color(note.cardColor) : Theme.of(context).cardColor,
                              child: ListTile(
                                isThreeLine: TagHelper.parseTags(note.tags).isNotEmpty,
                                onTap: () => _openEditor(note),
                                title: Text(note.title, style: TextStyle(fontWeight: FontWeight.bold, color: _isColorDark(note.cardColor) ? Colors.white : Colors.black87)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      noteProvider.displayContent(note),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: _isColorDark(note.cardColor) ? Colors.white70 : Colors.black54),
                                    ),
                                    _buildNoteTags(note, isDark: _isColorDark(note.cardColor)),
                                  ],
                                ),
                                trailing: SizedBox(
                                  width: 120,
                                  child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (note.userId != null)
                                      Icon(
                                        note.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                                        size: 16,
                                        color: note.isSynced ? Colors.blue : Colors.grey,
                                      ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        note.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: _isColorDark(note.cardColor) ? Colors.white60 : Colors.black45),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _confirmDelete(context, note.id!),
                                    ),
                                  ],
                                ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (settings.viewMode == 'table') {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              showCheckboxColumn: false,
                              columns: const [
                                DataColumn(label: Text('')), // Sync icon
                                DataColumn(label: Text('العنوان')),
                                DataColumn(label: Text('المحتوى')),
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('الوسوم')),
                                DataColumn(label: Text('الفئة')),
                                DataColumn(label: Text('حذف')),
                              ],
                              rows: filteredNotes.map((note) => DataRow(
                                onSelectChanged: (_) => _openEditor(note),
                                cells: [
                                  DataCell(
                                    note.userId != null 
                                      ? Icon(note.isSynced ? Icons.cloud_done : Icons.cloud_upload, size: 16, color: note.isSynced ? Colors.blue : Colors.grey)
                                      : const SizedBox.shrink()
                                  ),
                                  DataCell(Text(note.title)),
                                  DataCell(Text(
                                    noteProvider.displayContent(note),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  DataCell(Text(DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(note.timestamp)))),
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: _buildNoteTags(note, isDark: Theme.of(context).brightness == Brightness.dark, maxTags: 2),
                                    ),
                                  ),
                                  DataCell(Text(note.category)),
                                  DataCell(IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmDelete(context, note.id!),
                                  )),
                                ],
                              )).toList(),
                            ),
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: settings.gridColumns,
                        childAspectRatio: dynamicAspectRatio,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: filteredNotes.length,
                      itemBuilder: (ctx, i) {
                        final note = filteredNotes[i];
                        final cardColor = note.cardColor != 0 ? Color(note.cardColor) : Theme.of(context).cardColor;
                        final isDark = _isColorDark(note.cardColor);
                        
                        return GestureDetector(
                          onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, note),
                          onTap: () => _openEditor(note),
                          child: Card(
                            color: cardColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          note.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Icon(Icons.delete_outline, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                                          onPressed: () => _confirmDelete(context, note.id!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      noteProvider.displayContent(note),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  _buildNoteTags(note, isDark: isDark, maxTags: 2, compact: true),
                                  const Divider(height: 12),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          DateFormat('MM/dd').format(DateTime.fromMillisecondsSinceEpoch(note.timestamp)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black45),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (note.userId != null)
                                        Icon(
                                          note.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                                          size: 14,
                                          color: note.isSynced 
                                            ? (isDark ? Colors.cyanAccent.withValues(alpha: 0.7) : Colors.blue.withValues(alpha: 0.7))
                                            : Colors.grey,
                                        ),
                                      const Spacer(),
                                      if (note.isEncrypted) Icon(Icons.lock, size: 12, color: isDark ? Colors.white60 : Colors.black45),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
          _buildFooter(),
        ],
      ),
          Positioned.directional(
            textDirection: Directionality.of(context),
            end: 16,
            bottom: _footerBottomInset(context),
            child: GestureDetector(
              onLongPress: _showTemplatePicker,
              child: FloatingActionButton(
                onPressed: () => _openEditor(),
                tooltip: 'مذكرة جديدة (اضغط مطولاً للقوالب)',
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMiniMode(NoteProvider provider) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    const Text('ملاحظات سريعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _isMiniMode = false)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.notes.take(5).length,
                  itemBuilder: (ctx, i) {
                    final note = provider.notes[i];
                    return ListTile(
                      title: Text(note.title, maxLines: 1),
                      onTap: () => _openEditor(note),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () => _openEditor(),
                  child: const Text('إضافة ملاحظة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagFilter(NoteProvider provider) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('كل الوسوم'),
              selected: _selectedTag.isEmpty,
              onSelected: (_) => setState(() => _selectedTag = ''),
            ),
          ),
          ...provider.allTags.map((tag) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text('#$tag'),
                  selected: _selectedTag == tag,
                  onSelected: (_) => setState(() => _selectedTag = tag),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(NoteProvider provider) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['الكل', ...provider.categories].map((cat) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ChoiceChip(
            label: Text(cat),
            selected: _selectedCategory == cat,
            onSelected: (selected) => setState(() => _selectedCategory = cat),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFooter() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showProfileDialog,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isLandscape ? 10 : 14, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14181C), Color(0xFF0F1112)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: const Color(0xFF26C6DA).withValues(alpha: 0.35)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF26C6DA), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'مفكرتي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isLandscape ? 14 : 16,
                          color: const Color(0xFF26C6DA),
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تصميم وتطوير المهندس يوسف العزير',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isLandscape ? 11 : 12,
                          color: Colors.white60,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.35), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
