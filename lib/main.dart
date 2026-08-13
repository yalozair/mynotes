import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:firebase_core/firebase_core.dart';
import './providers/note_provider.dart';
import './providers/settings_provider.dart';
import './screens/home_screen.dart';
import './screens/onboarding_screen.dart';
import './screens/note_editor_screen.dart';
import './helpers/sticky_note_helper.dart';
import './helpers/encryption_helper.dart';
import './helpers/ad_helper.dart';
import './helpers/reminder_helper.dart';
import './helpers/analytics_helper.dart';
import './helpers/drive_backup_helper.dart';
import './services/app_firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyASiUOGj10Iwv8KHm-kHflWVJFZgoooz78",
          authDomain: "mysmartnotes-8459e.firebaseapp.com",
          projectId: "mysmartnotes-8459e",
          storageBucket: "mysmartnotes-8459e.firebasestorage.app",
          messagingSenderId: "52977356509",
          appId: "1:52977356509:web:28886317985c2983cfd534",
          measurementId: "G-PP3SNGMS3T",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    await AppFirebaseService.init();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await EncryptionHelper.init();
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  await StickyNoteHelper.init(onTap: (payload) {
    if (payload == 'quick_note') {
      AnalyticsHelper.quickNoteOpened();
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
      );
    }
  });
  await ReminderHelper.init();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await AdHelper.init();
  }

  runApp(const MyApp());
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _onboardingDone = prefs.getBool('onboarding_done') ?? false);
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    AnalyticsHelper.onboardingCompleted();
    if (mounted) setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingDone!) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }
    return const HomeScreen();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdHelper.showAppOpenAd();
      DriveBackupHelper.runWeeklyIfDue().catchError((e) {
        debugPrint('Weekly Drive backup skipped: $e');
        return null;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdHelper.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdHelper.showAppOpenAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      builder: (context, _) {
        final settings = Provider.of<SettingsProvider>(context);

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'مفكرتي',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.themeColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.getTextTheme(settings.globalFont),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.themeColor,
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1C1E),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.getTextTheme(settings.globalFont).apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F1112),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F1112),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: settings.themeColor,
              foregroundColor: Colors.white,
            ),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          locale: const Locale('ar'),
          home: const AppShell(),
        );
      },
    );
  }
}
