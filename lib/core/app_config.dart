/// Central configuration for backend URLs and feature flags.
/// ─────────────────────────────────────────────────────────
/// To switch environments, change [_env] below:
///   Environment.production  → IBM Cloud Kubernetes backend
///   Environment.local       → local Docker / dev server
class AppConfig {
  AppConfig._();

  // ── Change this to switch environments ──────────────────────────────────
  static const _env = Environment.local;
  // ────────────────────────────────────────────────────────────────────────

  // IBM Cloud Kubernetes Ingress URL
  static const String _ibmCloudUrl =
      'https://cricket-cluster-5e896152da3455c837a30996c4d7aabb-0000.us-south.containers.appdomain.cloud';

  static const String _localUrl = 'http://localhost:3000'; // Android emulator
  // For physical device on same LAN, replace with your machine's LAN IP:
  // static const String _localUrl = 'http://192.168.x.x:3000';

  /// The base URL for the Node.js backend (REST + Socket.IO).
  static String get backendUrl {
    switch (_env) {
      case Environment.production:
        return _ibmCloudUrl;
      case Environment.local:
        return _localUrl;
    }
  }

  /// Whether verbose debug logging is enabled.
  static bool get debugLogging => _env == Environment.local;
}

enum Environment { production, local }
