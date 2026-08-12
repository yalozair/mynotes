import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

enum AppTheme { blue, green, purple, orange, red, black }

class SettingsProvider with ChangeNotifier {
  bool _showLines = true;
  bool _showLineNumbers = true;
  int _trashInterval = 0; // 0: 30 days, 1: 7 days, 2: Never
  int _gridColumns = Platform.isWindows ? 5 : 2;
  int _gridRows = Platform.isWindows ? 4 : 3;
  String _viewMode = 'cards'; // 'cards', 'list', 'table'
  String _customDbPath = '';
  String _pdfPath = '';
  
  // New features
  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _appTheme = AppTheme.blue;
  String _globalFont = 'Cairo';
  bool _isSyncEnabled = false;
  String _syncProvider = 'Google'; // 'Google' or 'Microsoft'

  bool get showLines => _showLines;
  bool get showLineNumbers => _showLineNumbers;
  int get trashInterval => _trashInterval;
  int get gridColumns => _gridColumns;
  int get gridRows => _gridRows;
  String get viewMode => _viewMode;
  String get customDbPath => _customDbPath;
  String get pdfPath => _pdfPath;
  
  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  String get globalFont => _globalFont;
  bool get isSyncEnabled => _isSyncEnabled;
  String get syncProvider => _syncProvider;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showLines = prefs.getBool('show_lines') ?? true;
    _showLineNumbers = prefs.getBool('show_line_numbers') ?? true;
    _trashInterval = prefs.getInt('trash_interval') ?? 0;
    _gridColumns = prefs.getInt('grid_columns') ?? (Platform.isWindows ? 5 : 2);
    _gridRows = prefs.getInt('grid_rows') ?? (Platform.isWindows ? 4 : 3);
    _viewMode = prefs.getString('view_mode') ?? 'cards';
    _customDbPath = prefs.getString('custom_db_path') ?? '';
    _pdfPath = prefs.getString('pdf_path') ?? '';
    
    _themeMode = ThemeMode.values[prefs.getInt('theme_mode') ?? 0];
    _appTheme = AppTheme.values[prefs.getInt('app_theme') ?? 0];
    _globalFont = prefs.getString('global_font') ?? 'Cairo';
    _isSyncEnabled = prefs.getBool('sync_enabled') ?? false;
    _syncProvider = prefs.getString('sync_provider') ?? 'Google';
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', theme.index);
    notifyListeners();
  }

  Future<void> setGlobalFont(String font) async {
    _globalFont = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_font', font);
    notifyListeners();
  }

  Future<void> setSyncEnabled(bool value) async {
    _isSyncEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled', value);
    notifyListeners();
  }

  Future<void> setSyncProvider(String provider) async {
    _syncProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_provider', provider);
    notifyListeners();
  }

  Color get themeColor {
    switch (_appTheme) {
      case AppTheme.blue: return Colors.blue;
      case AppTheme.green: return Colors.green;
      case AppTheme.purple: return Colors.purple;
      case AppTheme.orange: return Colors.orange;
      case AppTheme.red: return Colors.red;
      case AppTheme.black: return Colors.black;
    }
  }

  Future<void> setShowLines(bool value) async {
    _showLines = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_lines', value);
    notifyListeners();
  }

  Future<void> setShowLineNumbers(bool value) async {
    _showLineNumbers = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_line_numbers', value);
    notifyListeners();
  }

  Future<void> setTrashInterval(int value) async {
    _trashInterval = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trash_interval', value);
    notifyListeners();
  }

  Future<void> setGridColumns(int value) async {
    _gridColumns = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grid_columns', value);
    notifyListeners();
  }

  Future<void> setGridRows(int value) async {
    _gridRows = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grid_rows', value);
    notifyListeners();
  }

  Future<void> setViewMode(String value) async {
    _viewMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('view_mode', value);
    notifyListeners();
  }

  Future<void> setCustomDbPath(String value) async {
    _customDbPath = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_db_path', value);
    notifyListeners();
  }

  Future<void> setPdfPath(String value) async {
    _pdfPath = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pdf_path', value);
    notifyListeners();
  }
}
