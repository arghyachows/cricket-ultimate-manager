/// Central configuration for backend URLs and feature flags.
/// ─────────────────────────────────────────────────────────
/// To switch environments, pass --dart-define=BACKEND_URL at build time.
///   Production:  --dart-define=BACKEND_URL=https://cricketmanager.duckdns.org
///   Local:       --dart-define=BACKEND_URL=http://localhost:3000
///
/// If BACKEND_URL is not provided, falls back to production URL for safety.
class AppConfig {
  AppConfig._();

  // ── Backend URL from build-time environment ────────────────────────────────
  static const String _backendUrlFromEnv =
      String.fromEnvironment('BACKEND_URL');

  // ── Fallback default (used only when --dart-define=BACKEND_URL is omitted) ─
  static const String _defaultBackendUrl = 'https://cricketmanager.duckdns.org';

  // ────────────────────────────────────────────────────────────────────────

  /// The base URL for the Node.js backend (REST + Socket.IO).
  /// Reads from --dart-define=BACKEND_URL at build time.
  static String get backendUrl =>
      _backendUrlFromEnv.isNotEmpty ? _backendUrlFromEnv : _defaultBackendUrl;

  /// Whether verbose debug logging is enabled.
  /// Set --dart-define=DEBUG_LOGGING=true to enable.
  static bool get debugLogging =>
      const String.fromEnvironment('DEBUG_LOGGING') == 'true';
}
