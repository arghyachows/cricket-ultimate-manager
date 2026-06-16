import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'cards_provider.dart';

// Contract Types Provider
final contractTypesProvider = FutureProvider<List<ContractType>>((ref) async {
  final data = await SupabaseService.getContractTypes();
  return data.map((json) => ContractType.fromJson(json)).toList();
});

// User Contracts Provider (inventory)
final userContractsProvider =
    StateNotifierProvider<UserContractsNotifier, AsyncValue<List<UserContract>>>((ref) {
  return UserContractsNotifier(ref);
});

class UserContractsNotifier extends StateNotifier<AsyncValue<List<UserContract>>> {
  final Ref ref;
  RealtimeChannel? _channel;
  bool _isMutating = false; // guards against subscription race during mutations

  UserContractsNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadContracts();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    _channel = SupabaseService.subscribeToContracts(userId, () {
      // Skip refresh if we're in the middle of a mutation — the mutation
      // handler will call loadContracts() explicitly after the RPC completes.
      if (!_isMutating) {
        loadContracts();
      }
    });
  }

  Future<void> loadContracts() async {
    if (_isMutating) return; // don't overwrite optimistic state mid-mutation
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final data = await SupabaseService.getUserContracts();
      final contracts = data.map((json) => UserContract.fromJson(json)).toList();
      state = AsyncValue.data(contracts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => loadContracts();

  /// Get total quantity for a specific contract type
  int getContractCount(String contractTypeId) {
    final contracts = state.valueOrNull ?? [];
    return contracts
        .where((c) => c.contractTypeId == contractTypeId)
        .fold(0, (sum, c) => sum + c.quantity);
  }

  /// Get applicable contracts for a user card (contracts that can be applied)
  List<UserContract> getApplicableContracts(UserCard userCard) {
    final contracts = state.valueOrNull ?? [];
    final currentContracts = userCard.contractsRemaining ?? 7;
    final maxContracts = userCard.contractsMax ?? 7;
    
    // Only show contracts that would actually increase the card's contracts
    return contracts.where((c) {
      if (c.quantity <= 0) return false;
      if (currentContracts >= maxContracts) return false; // Already at max
      return true;
    }).toList();
  }

  /// Open a contract pack - generates random contracts based on probabilities
  Future<List<String>> openContractPack(String packId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Not logged in');

      // Fetch the pack
      final packData = await SupabaseService.client
          .from('user_contract_packs')
          .select()
          .eq('id', packId)
          .eq('user_id', userId)
          .maybeSingle();

      if (packData == null) throw Exception('Pack not found');
      if (packData['opened'] == true) throw Exception('Pack already opened');

      final pack = UserContractPack.fromJson(packData);
      final awardedTypeIds = <String>[];

      // Get available contract types
      final typesData = await SupabaseService.getContractTypes();
      final typesByTier = <String, List<ContractType>>{};
      for (final t in typesData) {
        final ct = ContractType.fromJson(t);
        if (ct.isAvailable) {
          typesByTier.putIfAbsent(ct.tier.value, () => []).add(ct);
        }
      }

      // Generate contracts based on pack probabilities
      for (int i = 0; i < pack.contractCount; i++) {
        final rarity = pack.pickRarity();
        final availableTypes = typesByTier[rarity] ?? typesByTier['bronze'] ?? [];
        if (availableTypes.isEmpty) continue;

        final randomType = availableTypes[Random().nextInt(availableTypes.length)];
        awardedTypeIds.add(randomType.id);

        // Upsert into user_contracts (increment quantity if exists)
        await SupabaseService.client.rpc('upsert_user_contract', params: {
          'p_user_id': userId,
          'p_contract_type_id': randomType.id,
          'p_quantity': 1,
          'p_source': 'pack',
        });
      }

      // Mark pack as opened
      await SupabaseService.client
          .from('user_contract_packs')
          .update({'opened': true})
          .eq('id', packId);

      // Refresh contracts
      await loadContracts();

      return awardedTypeIds;
    } catch (e) {
      rethrow;
    }
  }

  /// Apply a contract to a user card
  Future<bool> applyContract(String userCardId, String contractTypeId) async {
    _isMutating = true;
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Not logged in');

      // Call atomic RPC
      await SupabaseService.client.rpc('apply_contract_to_card', params: {
        'p_user_id': userId,
        'p_user_card_id': userCardId,
        'p_contract_type_id': contractTypeId,
      });

      // Optimistic update: decrement local quantity
      final contracts = state.valueOrNull ?? [];
      final index = contracts.indexWhere((c) => c.contractTypeId == contractTypeId);
      if (index != -1) {
        final updated = contracts[index].copyWith(quantity: contracts[index].quantity - 1);
        final newList = [...contracts];
        if (updated.quantity <= 0) {
          newList.removeAt(index);
        } else {
          newList[index] = updated;
        }
        state = AsyncValue.data(newList);
      }

      // Refresh user cards to get updated contracts_remaining
      ref.read(userCardsProvider.notifier).refresh();

      return true;
    } catch (e) {
      rethrow;
    } finally {
      _isMutating = false;
      // Sync from DB after mutation to ensure consistency
      loadContracts();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// User Contract Packs Provider
final userContractPacksProvider =
    StateNotifierProvider<UserContractPacksNotifier, AsyncValue<List<UserContractPack>>>((ref) {
  return UserContractPacksNotifier();
});

class UserContractPacksNotifier extends StateNotifier<AsyncValue<List<UserContractPack>>> {
  RealtimeChannel? _channel;

  UserContractPacksNotifier() : super(const AsyncValue.loading()) {
    loadPacks();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    _channel = SupabaseService.subscribeToContractPacks(userId, () {
      loadPacks();
    });
  }

  Future<void> loadPacks() async {
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final data = await SupabaseService.getUserContractPacks();
      final packs = data.map((json) => UserContractPack.fromJson(json)).toList();
      state = AsyncValue.data(packs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => loadPacks();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// Provider for unopened contract packs only
final unopenedContractPacksProvider = Provider<List<UserContractPack>>((ref) {
  final packs = ref.watch(userContractPacksProvider).valueOrNull ?? [];
  return packs.where((p) => !p.opened).toList();
});