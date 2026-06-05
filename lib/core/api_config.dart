import 'app_config.dart';

export 'app_config.dart';

/// Current backend base URL (resolved from AppConfig)
String get apiBaseUrl => AppConfig.backendUrl;

/// Whether debug logging is enabled
bool get apiDebugLogging => AppConfig.debugLogging;