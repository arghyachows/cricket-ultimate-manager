/// Central configuration for backend URLs and feature flags.
/// ─────────────────────────────────────────────────────────
/// To switch environments, change [_env] below:
///   Environment.production  → Render cloud backend
///   Environment.local       → local Docker / dev server
class AppConfig {
  AppConfig._();

  // ── Change this to switch environments ──────────────────────────────────
  static const _env = Environment.production;
  // ────────────────────────────────────────────────────────────────────────

  static const String _renderUrl =
      'https://cricket-ultimate-backend.onrender.com';

  static const String _localUrl = 'http://10.0.2.2:3000'; // Android emulator
  // For physical device on same LAN, replace with your machine's LAN IP:
  // static const String _localUrl = 'http://192.168.x.x:3000';

  /// The base URL for the Node.js backend (REST + Socket.IO).
  static String get backendUrl {
    switch (_env) {
      case Environment.production:
        return _renderUrl;
      case Environment.local:
        return _localUrl;
    }
  }

  /// Whether verbose debug logging is enabled.
  static bool get debugLogging => _env == Environment.local;
}

enum Environment { production, local }
