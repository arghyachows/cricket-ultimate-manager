import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cricket_ultimate_manager/main.dart';

void main() {
  setUpAll(() async {
    // Mock the SharedPreferences MethodChannel calls to prevent MissingPluginException
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Ignore the deprecation warning for setMockMethodCallHandler in test files
    // ignore: deprecated_member_use
    const MethodChannel('plugins.flutter.io/shared_preferences')
        // ignore: deprecated_member_use
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });

    // Initialize Supabase with dummy credentials for tests
    // Tests don't hit the real backend — these are only to satisfy SDK init
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-signature',
    );
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CricketUltimateManager()));
    expect(find.byType(CricketUltimateManager), findsOneWidget);
  });
}
