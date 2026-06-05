import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../core/constants.dart';
import '../models/models.dart';

// Auth state
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Current user
final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>((ref) {
  return CurrentUserNotifier(ref);
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final Ref ref;
  RealtimeChannel? _channel;

  /// Pending rewards that failed to persist, stored for retry.
  ({int coins, int xp, bool? homeWon})? _pendingRewards;

  /// Error message from the last persistence failure, if any.
  String? _persistenceError;

  /// Returns the pending rewards tuple if a persistence failure occurred.
  ({int coins, int xp, bool? homeWon})? get pendingRewards => _pendingRewards;

  /// Returns the last persistence error message, or null if none.
  String? get persistenceError => _persistenceError;

  CurrentUserNotifier(this.ref) : super(const AsyncValue.loading()) {
    // Listen to auth state changes
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((authState) {
        if (authState.session == null) {
          _channel?.unsubscribe();
          _channel = null;
          state = const AsyncValue.data(null);
        } else {
          loadUser();
          _subscribeToUpdates();
        }
      });
    });
    // Only load/subscribe if already authenticated
    if (SupabaseService.isAuthenticated) {
      loadUser();
      _subscribeToUpdates();
    }
  }

  void _subscribeToUpdates() {
    final userId = SupabaseService.currentUserId;
    if (userId == null || _channel != null) return;
    _channel = SupabaseService.subscribeToUser(userId, () {
      silentRefresh();
    });
  }

  Future<void> loadUser() async {
    try {
      state = const AsyncValue.loading();
      final data = await SupabaseService.getCurrentUser();
      if (data != null) {
        state = AsyncValue.data(UserModel.fromJson(data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => loadUser();

  /// Refresh user data without setting loading state (avoids UI flicker/rebuild cascades)
  Future<void> silentRefresh() async {
    try {
      final data = await SupabaseService.getCurrentUser();
      if (data != null) {
        state = AsyncValue.data(UserModel.fromJson(data));
      }
    } catch (_) {}
  }

  /// Set a persistence error with pending rewards for retry.
  void setPersistenceError(String message, {required int pendingCoins, required int pendingXp, required bool pendingHomeWon}) {
    _persistenceError = message;
    _pendingRewards = (coins: pendingCoins, xp: pendingXp, homeWon: pendingHomeWon);
  }

  /// Clear the persistence error and pending rewards (e.g. after successful retry).
  void clearPersistenceError() {
    _persistenceError = null;
    _pendingRewards = null;
  }

  void updateCoins(int delta) {
    final user = state.valueOrNull;
    if (user != null) {
      state = AsyncValue.data(user.copyWith(coins: user.coins + delta));
    }
  }

  void updateXpAndLevel(int xpDelta) {
    final user = state.valueOrNull;
    if (user != null) {
      final newXp = user.xp + xpDelta;
      final newLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
      state = AsyncValue.data(user.copyWith(
        xp: newXp,
        level: newLevel > AppConstants.maxLevel ? AppConstants.maxLevel : newLevel,
      ));
    }
  }

  void updateMatchStats({required bool won}) {
    final user = state.valueOrNull;
    if (user != null) {
      state = AsyncValue.data(user.copyWith(
        matchesPlayed: user.matchesPlayed + 1,
        matchesWon: won ? user.matchesWon + 1 : user.matchesWon,
      ));
    }
  }

  void updatePremium(int delta) {
    final user = state.valueOrNull;
    if (user != null) {
      state = AsyncValue.data(
          user.copyWith(premiumTokens: user.premiumTokens + delta));
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    super.dispose();
  }
}

// Auth controller
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  AuthController(this.ref) : super(const AsyncValue.data(null));

  Future<bool> signUp(String email, String password, String username) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.signUp(email, password, username);
      await ref.read(currentUserProvider.notifier).loadUser();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.signIn(email, password);
      ref.read(currentUserProvider.notifier).loadUser();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    // Reset the current user state
    ref.read(currentUserProvider.notifier).state = const AsyncValue.data(null);
    state = const AsyncValue.data(null);
  }
}
