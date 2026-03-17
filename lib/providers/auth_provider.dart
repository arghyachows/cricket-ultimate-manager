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

  CurrentUserNotifier(this.ref) : super(const AsyncValue.loading()) {
    // Listen to auth state changes
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((authState) {
        if (authState.session == null) {
          // User logged out, clear the state
          state = const AsyncValue.data(null);
        } else {
          // User logged in, load user data
          loadUser();
        }
      });
    });
    loadUser();
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

  void updatePremium(int delta) {
    final user = state.valueOrNull;
    if (user != null) {
      state = AsyncValue.data(
          user.copyWith(premiumTokens: user.premiumTokens + delta));
    }
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
