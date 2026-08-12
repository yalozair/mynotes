import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static bool _initialized = false;
  static AppOpenAd? _appOpenAd;
  static InterstitialAd? _exitAd;
  static bool _isShowingAppOpen = false;
  static bool _isShowingExit = false;

  static const appId = 'ca-app-pub-3626713124203403~2364705772';
  static const _appOpenId = 'ca-app-pub-3626713124203403/9860052414';
  static const _interstitialId = 'ca-app-pub-3626713124203403/8874273804';

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadAppOpenAd();
    _loadExitAd();
  }

  static void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: _appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  static void _loadExitAd() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _exitAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('ExitAd failed: $error');
          _exitAd = null;
        },
      ),
    );
  }

  static Future<void> showAppOpenAd() async {
    if (!_initialized || _appOpenAd == null || _isShowingAppOpen) return;
    _isShowingAppOpen = true;
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpen = false;
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpen = false;
        _loadAppOpenAd();
      },
    );
    await _appOpenAd!.show();
  }

  /// يعرض إعلان الإغلاق وينتظر حتى يُغلق أو يفشل.
  static Future<void> showExitAd() async {
    if (!_initialized || _exitAd == null || _isShowingExit) return;
    _isShowingExit = true;
    final completer = Completer<void>();

    void finish() {
      if (!completer.isCompleted) completer.complete();
      _isShowingExit = false;
    }

    _exitAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _exitAd = null;
        _loadExitAd();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('ExitAd show failed: $error');
        ad.dispose();
        _exitAd = null;
        _loadExitAd();
        finish();
      },
    );

    await _exitAd!.show();
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: finish,
    );
  }

  static void dispose() {
    _appOpenAd?.dispose();
    _exitAd?.dispose();
  }
}
