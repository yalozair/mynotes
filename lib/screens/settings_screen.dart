import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/auth_helper.dart';
import '../providers/settings_provider.dart';
import '../providers/note_provider.dart';
import '../helpers/arabic_font_catalog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../helpers/update_helper.dart';
import '../helpers/backup_helper.dart';
import '../helpers/native_helper.dart';
import '../helpers/sticky_note_helper.dart';
import '../helpers/analytics_helper.dart';
import '../helpers/permission_helper.dart';
import './login_screen.dart';
import './onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLockEnabled = false;
  bool _quickNoteEnabled = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadAuthSettings();
    _loadQuickNotePref();
  }

  Future<void> _loadQuickNotePref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _quickNoteEnabled = prefs.getBool('quick_note_shortcut') ?? true);
  }

  Future<void> _loadAuthSettings() async {
    final enabled = await AuthHelper.isLockEnabled();
    setState(() => _isLockEnabled = enabled);
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final canUse = await AuthHelper.isDeviceLockAvailable();
      if (!canUse && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فعّل قفل الشاشة في إعدادات الجهاز (نمط، PIN، بصمة، أو وجه)'),
          ),
        );
        return;
      }
      final result = await AuthHelper.authenticateWithMessage();
      if (!mounted) return;
      if (result.success) {
        await AuthHelper.setLockEnabled(true);
        setState(() => _isLockEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل قفل التطبيق')),
        );
      } else if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    } else {
      final result = await AuthHelper.authenticateWithMessage();
      if (!mounted) return;
      if (result.success) {
        await AuthHelper.setLockEnabled(false);
        setState(() => _isLockEnabled = false);
      } else if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    }
  }

  void _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    await _auth.signOut();
    if (mounted) {
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          _sectionTitle('الحساب والمزامنة السحابية'),
          if (user == null)
            ListTile(
              title: const Text('تسجيل الدخول للمزامنة'),
              subtitle: const Text('اربط مذكراتك بسحابة Firebase للوصول إليها من أي مكان'),
              leading: const Icon(Icons.cloud_off, color: Colors.grey),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const LoginScreen())).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                child: const Text('دخول'),
              ),
            )
          else
            ListTile(
              title: Text('مسجل كـ: ${user.email}'),
              subtitle: const Text('المزامنة السحابية نشطة'),
              leading: const Icon(Icons.cloud_done, color: Colors.green),
              trailing: TextButton(
                onPressed: _signOut,
                child: const Text('خروج', style: TextStyle(color: Colors.red)),
              ),
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                final provider = Provider.of<NoteProvider>(context, listen: false);
                provider.syncFromCloud().then((_) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(provider.lastError ?? 'تم جلب المذكرات من السحابة'),
                  ));
                });
              },
            ),

          _sectionTitle('المظهر والسمات'),
          ListTile(
            title: const Text('وضع السمات'),
            subtitle: Text(_getThemeModeText(settings.themeMode)),
            trailing: const Icon(Icons.brightness_medium),
            onTap: () => _showThemeModeDialog(context, settings),
          ),
          ListTile(
            title: const Text('لون التطبيق'),
            subtitle: Text(_getAppThemeText(settings.appTheme)),
            trailing: CircleAvatar(backgroundColor: settings.themeColor, radius: 12),
            onTap: () => _showAppThemeDialog(context, settings),
          ),
          ListTile(
            title: const Text('الخط العالمي'),
            subtitle: Text(settings.globalFont, style: GoogleFonts.getFont(settings.globalFont)),
            trailing: const Icon(Icons.font_download),
            onTap: () => _showFontPickerDialog(context, settings),
          ),

          _sectionTitle('الأمان'),
          SwitchListTile(
            title: const Text('قفل التطبيق بقفل الجهاز'),
            subtitle: const Text('بصمة، وجه، نمط، PIN، أو كلمة مرور الجهاز'),
            value: _isLockEnabled,
            onChanged: _toggleLock,
          ),
          
          _sectionTitle('المحرر والتخطيط'),
          ListTile(
            title: const Text('تنظيف سلة المحذوفات تلقائياً'),
            subtitle: Text(_getTrashIntervalText(settings.trashInterval)),
            trailing: const Icon(Icons.delete_sweep_outlined),
            onTap: () => _showTrashIntervalDialog(context, settings),
          ),
          SwitchListTile(
            title: const Text('إظهار أسطر الورق'),
            value: settings.showLines,
            onChanged: (val) => settings.setShowLines(val),
          ),
          SwitchListTile(
            title: const Text('إظهار أرقام الأسطر'),
            value: settings.showLineNumbers,
            onChanged: (val) => settings.setShowLineNumbers(val),
          ),
          ListTile(
            title: const Text('أعمدة الشاشة الرئيسية'),
            subtitle: Slider(
              value: settings.gridColumns.toDouble(),
              min: 1, max: 8, divisions: 7,
              label: settings.gridColumns.toString(),
              onChanged: (val) => settings.setGridColumns(val.toInt()),
            ),
          ),
          ListTile(
            title: const Text('صفوف الشاشة الرئيسية المتوقعة'),
            subtitle: Slider(
              value: settings.gridRows.toDouble(),
              min: 1, max: 8, divisions: 7,
              label: settings.gridRows.toString(),
              onChanged: (val) => settings.setGridRows(val.toInt()),
            ),
          ),
          _sectionTitle('النسخ الاحتياطي والاختصارات'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('تصدير نسخة احتياطية مشفّرة'),
            subtitle: const Text('ملف .mynotes محلي ومشفّر'),
            onTap: () async {
              final result = await BackupHelper.exportEncryptedBackup();
              if (!mounted) return;
              final message = switch (result.status) {
                BackupExportStatus.success => 'تم الحفظ في:\n${result.path}',
                BackupExportStatus.cancelled => 'تم إلغاء التصدير',
                BackupExportStatus.failed => 'تعذر التصدير — حاول مجدداً',
              };
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
              if (result.status == BackupExportStatus.success) AnalyticsHelper.backupExported();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('استيراد نسخة احتياطية'),
            onTap: () async {
              try {
                final count = await BackupHelper.importEncryptedBackup();
                if (!mounted) return;
                await Provider.of<NoteProvider>(context, listen: false).fetchNotes();
                AnalyticsHelper.backupImported(count);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم استيراد $count مذكرة')),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل الاستيراد — تأكد من الملف')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bubble_chart),
            title: const Text('المذكرة العائمة'),
            subtitle: const Text('تظهر فوق التطبيقات الأخرى'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final granted = await PermissionHelper.requestOverlayPermission(context);
              if (!granted || !mounted) return;
              await NativeHelper.toggleFloatingNote();
            },
          ),
          SwitchListTile(
            title: const Text('اختصار مذكرة سريعة في الإشعارات'),
            subtitle: const Text('إشعار دائم لإنشاء مذكرة جديدة'),
            value: _quickNoteEnabled,
            onChanged: (v) async {
              setState(() => _quickNoteEnabled = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('quick_note_shortcut', v);
              if (v) {
                await StickyNoteHelper.showQuickNoteShortcut();
              } else {
                await StickyNoteHelper.removeQuickNoteShortcut();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('إعادة عرض دليل البداية'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => OnboardingScreen(onComplete: () => Navigator.pop(context))));
            },
          ),

          _sectionTitle('عن التطبيق'),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final version = snap.data?.version ?? '1.0.2';
              return ListTile(
                title: const Text('رقم الإصدار'),
                subtitle: Text('v$version'),
                trailing: IconButton(
                  icon: const Icon(Icons.system_update),
                  onPressed: () => UpdateHelper.checkForUpdate(context),
                  tooltip: 'التحقق من التحديث',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('طريقة العرض'),
            subtitle: Text(_getViewModeText(settings.viewMode)),
            trailing: const Icon(Icons.view_module),
            onTap: () => _showViewModeDialog(context, settings),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'نظام الجهاز';
      case ThemeMode.light: return 'فاتح';
      case ThemeMode.dark: return 'داكن';
    }
  }

  String _getTrashIntervalText(int interval) {
    switch (interval) {
      case 0: return 'بعد 30 يوم';
      case 1: return 'بعد 7 أيام';
      case 2: return 'أبداً (يدوي فقط)';
      default: return 'بعد 30 يوم';
    }
  }

  void _showTrashIntervalDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مدة الاحتفاظ بالمحذوفات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _trashIntervalOption(context, settings, 'بعد 30 يوم', 0),
            _trashIntervalOption(context, settings, 'بعد 7 أيام', 1),
            _trashIntervalOption(context, settings, 'أبداً (يدوي فقط)', 2),
          ],
        ),
      ),
    );
  }

  Widget _trashIntervalOption(BuildContext context, SettingsProvider settings, String title, int value) {
    return RadioListTile<int>(
      title: Text(title),
      value: value,
      groupValue: settings.trashInterval,
      onChanged: (val) {
        settings.setTrashInterval(val!);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('وضع السمات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(
            title: Text(_getThemeModeText(mode)),
            value: mode,
            groupValue: settings.themeMode,
            onChanged: (val) { 
              settings.setThemeMode(val!); 
              Navigator.of(ctx).pop(); 
            },
          )).toList(),
        ),
      ),
    );
  }

  String _getAppThemeText(AppTheme theme) {
    return theme.name[0].toUpperCase() + theme.name.substring(1);
  }

  void _showAppThemeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('لون التطبيق'),
        content: Wrap(
          children: AppTheme.values.map((theme) {
            Color color;
            switch (theme) {
              case AppTheme.blue: color = Colors.blue; break;
              case AppTheme.green: color = Colors.green; break;
              case AppTheme.purple: color = Colors.purple; break;
              case AppTheme.orange: color = Colors.orange; break;
              case AppTheme.red: color = Colors.red; break;
              case AppTheme.black: color = Colors.black; break;
            }
            return GestureDetector(
              onTap: () { settings.setAppTheme(theme); Navigator.pop(ctx); },
              child: Container(
                margin: const EdgeInsets.all(8),
                width: 40, height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: settings.appTheme == theme ? Colors.grey : Colors.transparent, width: 2)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getViewModeText(String mode) {
    switch (mode) {
      case 'list':
        return 'قائمة';
      case 'table':
        return 'جدول';
      default:
        return 'بطاقات';
    }
  }

  void _showViewModeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طريقة العرض'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('بطاقات'),
              value: 'cards',
              groupValue: settings.viewMode,
              onChanged: (val) {
                settings.setViewMode(val!);
                Navigator.of(ctx).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('قائمة'),
              value: 'list',
              groupValue: settings.viewMode,
              onChanged: (val) {
                settings.setViewMode(val!);
                Navigator.of(ctx).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('جدول'),
              value: 'table',
              groupValue: settings.viewMode,
              onChanged: (val) {
                settings.setViewMode(val!);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontPickerDialog(BuildContext context, SettingsProvider settings) {
    ArabicFontCatalog.showPicker(
      context: context,
      selectedFontId: settings.globalFont,
      onSelected: settings.setGlobalFont,
    );
  }
}
