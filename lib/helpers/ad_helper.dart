import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعلانات مع موافقة UMP وتقييد التكرار وفق سياسات AdMob.
class AdHelper {
  static bool _initialized = false;
  static AppOpenAd? _appOpenAd;
  static InterstitialAd? _exitAd;
  static bool _isShowingAppOpen = false;
  static bool _isShowingExit = false;
  static bool _consentReady = false;
  static DateTime? _lastAppOpenAt;
  static DateTime? _lastExitAdAt;

  /// حد أدنى بين إعلانات فتح التطبيق (سياسة تجربة المستخدم / AdMob).
  static const _appOpenMinInterval = Duration(hours: 4);
  static const _exitAdMinInterval = Duration(minutes: 10);

  static const appId = 'ca-app-pub-3626713124203403~2364705772';
  static const _appOpenId = 'ca-app-pub-3626713124203403/9860052414';
  static const _interstitialId = 'ca-app-pub-3626713124203403/8874273804';

  /// يجمع موافقة UMP ثم يهيئ SDK الإعلانات.
  static Future<void> initWithConsent() async {
    if (kIsWeb) return;
    try {
      final params = ConsentRequestParameters();
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          } catch (e) {
            debugPrint('Consent form: $e');
          }
          if (!completer.isCompleted) completer.complete();
        },
        (error) {
          debugPrint('Consent update failed: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('UMP error: $e');
    }
    _consentReady = true;
    await init();
  }

  static Future<void> init() async {
    if (_initialized) return;
    final canRequest = await _canRequestAds();
    if (!canRequest) {
      debugPrint('Ads skipped: cannot request ads yet');
      return;
    }
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadAppOpenAd();
    _loadExitAd();
  }

  static Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // Outside EEA / SDK unavailable — allow non-personalized path.
      return true;
    }
  }

  static Future<void> showPrivacyOptionsIfRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      if (status == PrivacyOptionsRequirementStatus.required) {
        await ConsentForm.showPrivacyOptionsForm((_) {});
      }
    } catch (e) {
      debugPrint('Privacy options: $e');
    }
  }

  static void _loadAppOpenAd() {
    if (!_initialized) return;
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
    if (!_initialized) return;
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

  /// [fromResume]: عند العودة للتطبيق — يُقيَّد بالفاصل الزمني ولا يُعرض أثناء القفل.
  static Future<void> showAppOpenAd({bool fromResume = false}) async {
    if (!_consentReady && !_initialized) return;
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('lock') == true && fromResume) {
      // لا تعرض إعلاناً فوق شاشة قفل التطبيق.
      return;
    }

    final now = DateTime.now();
    if (_lastAppOpenAt != null &&
        now.difference(_lastAppOpenAt!) < _appOpenMinInterval) {
      return;
    }
    // عند الاستئناف فقط بعد فاصل أطول؛ الإقلاع البارد يمر إذا لم يُعرض مؤخراً.
    if (fromResume &&
        _lastAppOpenAt != null &&
        now.difference(_lastAppOpenAt!) < const Duration(hours: 8)) {
      return;
    }

    if (_appOpenAd == null || _isShowingAppOpen) return;
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
    _lastAppOpenAt = now;
    await _appOpenAd!.show();
  }

  /// إعلان بيني عند خروج صريح فقط (ليس عند كل Back) مع تبريد زمني.
  static Future<void> showExitAd() async {
    if (!_initialized || _exitAd == null || _isShowingExit) return;
    final now = DateTime.now();
    if (_lastExitAdAt != null &&
        now.difference(_lastExitAdAt!) < _exitAdMinInterval) {
      return;
    }

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

    _lastExitAdAt = now;
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
