import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../providers/multiplayer_provider.dart';
import '../core/supabase_service.dart';

class MultiplayerDebugScreen extends ConsumerStatefulWidget {
  const MultiplayerDebugScreen({super.key});

  @override
  ConsumerState<MultiplayerDebugScreen> createState() => _MultiplayerDebugScreenState();
}

class _MultiplayerDebugScreenState extends ConsumerState<MultiplayerDebugScreen> {
  String _debugLog = '';
  bool _isTestingConnection = false;

  void _addLog(String message) {
    setState(() {
      _debugLog += '${DateTime.now().toIso8601String().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _testDatabaseConnection() async {
    setState(() {
      _isTestingConnection = true;
      _debugLog = '';
    });

    try {
      _addLog('Testing database connection...');
      
      // Test 1: Check if tables exist
      _addLog('Checking multiplayer_rooms table...');
      final rooms = await SupabaseService.client
          .from('multiplayer_rooms')
          .select()
          .limit(1);
      _addLog('✓ multiplayer_rooms table exists (${rooms.length} rooms)');

      // Test 2: Check room_presence table
      _addLog('Checking room_presence table...');
      final presence = await SupabaseService.client
          .from('room_presence')
          .select()
          .limit(1);
      _addLog('✓ room_presence table exists (${presence.length} users)');

      // Test 3: Check match_challenges table
      _addLog('Checking match_challenges table...');
      final challenges = await SupabaseService.client
          .from('match_challenges')
          .select()
          .limit(1);
      _addLog('✓ match_challenges table exists (${challenges.length} challenges)');

      // Test 4: Check current user
      final userId = SupabaseService.currentUserId;
      _addLog('Current user ID: $userId');

      // Test 5: Try to insert and delete a test presence
      if (userId != null) {
        _addLog('Testing insert into room_presence...');
        final testPresence = await SupabaseService.client
            .from('room_presence')
            .insert({
              'room_id': 'test-room-id',
              'user_id': userId,
              'team_id': 'test-team-id',
              'team_name': 'Test Team',
              'user_level': 1,
            })
            .select()
            .single();
        _addLog('✓ Insert successful: ${testPresence['id']}');

        _addLog('Cleaning up test data...');
        await SupabaseService.client
            .from('room_presence')
            .delete()
            .eq('id', testPresence['id']);
        _addLog('✓ Cleanup successful');
      }

      _addLog('\n✅ All tests passed!');
    } catch (e) {
      _addLog('\n❌ Error: $e');
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _testRealtimeConnection() async {
    setState(() {
      _debugLog = '';
    });

    try {
      _addLog('Testing Realtime connection...');
      
      final channel = SupabaseService.client
          .channel('test_channel_${DateTime.now().millisecondsSinceEpoch}');

      _addLog('Subscribing to channel...');
      
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_presence',
        callback: (payload) {
          _addLog('Received event: ${payload.eventType}');
        },
      );

      await channel.subscribe();
      _addLog('✓ Channel subscribed successfully');

      await Future.delayed(const Duration(seconds: 2));
      
      await channel.unsubscribe();
      _addLog('✓ Channel unsubscribed');
      
      _addLog('\n✅ Realtime test passed!');
    } catch (e) {
      _addLog('\n❌ Realtime error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MULTIPLAYER DEBUG'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Status
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONNECTION STATUS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow('Connected', state.isConnected),
                  _buildStatusRow('In Room', state.currentRoom != null),
                  _buildStatusRow('Users in Room', state.usersInRoom.length.toString()),
                  _buildStatusRow('Pending Challenges', state.pendingChallenges.length.toString()),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Error: ${state.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test Buttons
          ElevatedButton.icon(
            onPressed: _isTestingConnection ? null : _testDatabaseConnection,
            icon: _isTestingConnection
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.storage),
            label: const Text('TEST DATABASE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _testRealtimeConnection,
            icon: const Icon(Icons.wifi),
            label: const Text('TEST REALTIME'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => ref.read(multiplayerProvider.notifier).loadRooms(),
            icon: const Icon(Icons.refresh),
            label: const Text('RELOAD ROOMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Debug Log
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DEBUG LOG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                      if (_debugLog.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _debugLog = ''),
                          child: const Text('CLEAR'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _debugLog.isEmpty ? 'No logs yet. Run a test to see output.' : _debugLog,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    final isBoolean = value is bool;
    final displayValue = isBoolean ? (value ? '✓' : '✗') : value.toString();
    final color = isBoolean ? (value ? Colors.green : Colors.red) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            displayValue,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
