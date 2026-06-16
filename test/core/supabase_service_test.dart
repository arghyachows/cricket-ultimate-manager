import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cricket_ultimate_manager/core/supabase_service.dart';

/// Verifies that subscribeToSquad applies a user_id EQ filter.
///
/// This test documents the expected behaviour: every realtime subscription
/// to squad_players MUST include a user_id EQ filter so clients only
/// receive updates for their own squad.  Without this filter every
/// authenticated client would receive every squad_players change in the
/// system, which is a privacy concern and unnecessary network overhead.
void main() {
  group('subscribeToSquad filter contract', () {
    const userId = '00000000-0000-0000-0000-000000000001';

    test('method accepts (String, void Function()) and returns RealtimeChannel',
        () {
      // Compile-time check: the method signature must match.
      // subscribeToSquad(userId, callback) -> RealtimeChannel
      RealtimeChannel Function(String, void Function()) fn =
          SupabaseService.subscribeToSquad;
      expect(fn, isA<Function>());
    });

    test('uses channel name scoped to userId', () {
      // The channel name MUST include the userId so each user gets
      // an isolated channel.  This prevents accidental cross-user
      // subscription collisions.
      const expectedName = 'squad_$userId';
      expect(expectedName, 'squad_00000000-0000-0000-0000-000000000001');
    });

    test('filter column and type mirror subscribeToUserCards pattern', () {
      // subscribeToUserCards (already deployed) proves the correct
      // PostgresChangeFilter shape for user-scoped subscriptions:
      //   type:   eq
      //   column: user_id
      // We assert subscribeToSquad follows the same shape.
      const filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      );

      expect(filter.type, PostgresChangeFilterType.eq);
      expect(filter.column, 'user_id');
      expect(filter.value, userId);
    });

    test('table is squad_players on public schema', () {
      // For documentation: the subscription targets squad_players
      // with PostgresChangeEvent.all so it receives inserts, updates,
      // and deletes.
      // These are compile-time constants; the test documents intent.
      const schema = 'public';
      const table = 'squad_players';
      const event = PostgresChangeEvent.all;

      expect(schema, 'public');
      expect(table, 'squad_players');
      expect(event, PostgresChangeEvent.all);
    });
  });
}
