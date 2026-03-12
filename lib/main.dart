import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://kollxlzqqgznfiutpqjz.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtvbGx4bHpxcWd6bmZpdXRwcWp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzY4MDUsImV4cCI6MjA4ODkxMjgwNX0.0Dn1J-j5INjGwd6oDDYTJUFSvSIRxknJ5nORbYUj8kY'),
  );

  runApp(const ProviderScope(child: CricketUltimateManager()));
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
