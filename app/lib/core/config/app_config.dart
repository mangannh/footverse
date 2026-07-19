/// Application configuration resolved at build/run time.
///
/// The API base URL is supplied per run via `--dart-define=API_BASE_URL=...`
/// (flutter-guidelines §Configuration); no URL is hardcoded in the app.
class AppConfig {
  const AppConfig._();

  /// Base URL of the FootVerse backend API, injected via `--dart-define`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Prefix of the VNPay sandbox return URL (Sprint 13 Task 10), injected via
  /// `--dart-define=VNPAY_RETURN_URL_PREFIX=...` and matched against every
  /// URL the payment WebView navigates to. It must match the backend's own
  /// configured `footverse.vnpay.return-url`; no URL is hardcoded in a widget.
  static const String vnpayReturnUrlPrefix = String.fromEnvironment(
    'VNPAY_RETURN_URL_PREFIX',
  );
}
