import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/notification_service.dart';
import 'core/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry (best-effort — doesn't block app start)
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',
      );
      options.tracesSampleRate = 0.2;
      options.enableAppHangTracking = true;
    },
    appRunner: () => _runApp(),
  );
}

Future<void> _runApp() async {
  try {
    await NotificationService.instance.init();

    final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      // In release builds show an error screen; in debug builds still throw
      // so the developer sees the problem immediately.
      if (const bool.fromEnvironment('FLUTTER_TEST')) {
        throw StateError(
          'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via '
          '--dart-define.\n'
          'Example: flutter run --dart-define=SUPABASE_URL='
          'https://your-project.supabase.co '
          '--dart-define=SUPABASE_ANON_KEY=your-anon-key',
        );
      }
      runApp(const _InitErrorApp(
        message: 'Supabase credentials not configured.\n\n'
            'The app was built without SUPABASE_URL and SUPABASE_ANON_KEY.\n'
            'Add these secrets to your GitHub repository:\n'
            '  Settings \u2192 Secrets and variables \u2192 Actions\n'
            '  \u2022 SUPABASE_URL\n'
            '  \u2022 SUPABASE_ANON_KEY\n'
            '  \u2022 SUPABASE_STORAGE_URL\n'
            '  \u2022 BACKEND_URL\n\n'
            'Then push to master to rebuild.',
      ));
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e, st) {
    Log.e('App initialization failed', e, st);
    if (const bool.fromEnvironment('FLUTTER_TEST')) rethrow;
    runApp(_InitErrorApp(
      message: 'Failed to initialize the app.\n\n$e',
      details: st.toString(),
    ));
    return;
  }

  runApp(const ProviderScope(child: CricketUltimateManager()));
}

/// Error screen shown when initialization fails in release builds.
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.message, this.details});

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      title: 'Cricket Ultimate Manager',
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 72, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  'Oops! Something went wrong',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                if (details != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      details!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => runApp(
                    const ProviderScope(child: CricketUltimateManager()),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CricketUltimateManager extends ConsumerWidget {
  const CricketUltimateManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Cricket Ultimate Manager',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
