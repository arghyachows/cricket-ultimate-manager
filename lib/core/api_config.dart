import 'app_config.dart';

export 'app_config.dart';

/// Current backend base URL (resolved from AppConfig)
String get apiBaseUrl => AppConfig.backendUrl;

/// Whether debug logging is enabled
bool get apiDebugLogging => AppConfig.debugLogging;

/// Current environment name for logging/display
String get apiEnvironment {
  switch (AppConfig.environment) {
    case Environment.production:
      return 'production';
    case Environment.local:
      return 'development';
    case Environment.oracleCloud:
      return 'staging';
  }
}