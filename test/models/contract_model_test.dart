import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/models/contract_model.dart';

void main() {
  group('UserContractPack copyWith', () {
    final pack = UserContractPack(
      id: 'p1',
      userId: 'u1',
      packName: 'Test Pack',
      contractCount: 5,
      bronzeChance: 50,
      silverChance: 30,
      goldChance: 15,
      eliteChance: 4,
      legendChance: 1,
      source: 'purchase',
      opened: false,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    test('copyWith with no args returns identical pack', () {
      final copy = pack.copyWith();
      expect(copy.id, 'p1');
      expect(copy.userId, 'u1');
      expect(copy.packName, 'Test Pack');
      expect(copy.contractCount, 5);
      expect(copy.bronzeChance, 50);
      expect(copy.silverChance, 30);
      expect(copy.goldChance, 15);
      expect(copy.eliteChance, 4);
      expect(copy.legendChance, 1);
      expect(copy.source, 'purchase');
      expect(copy.opened, false);
    });

    test('copyWith updates only specified fields', () {
      final copy = pack.copyWith(opened: true, contractCount: 10);
      expect(copy.opened, true);
      expect(copy.contractCount, 10);
      // unchanged
      expect(copy.id, 'p1');
      expect(copy.packName, 'Test Pack');
      expect(copy.source, 'purchase');
    });

    test('copyWith can set all fields', () {
      final copy = pack.copyWith(
        id: 'p2',
        userId: 'u2',
        packName: 'New Pack',
        contractCount: 3,
        bronzeChance: 60,
        silverChance: 25,
        goldChance: 10,
        eliteChance: 4,
        legendChance: 1,
        source: 'reward',
        opened: true,
        createdAt: DateTime.parse('2027-06-15T12:00:00Z'),
      );
      expect(copy.id, 'p2');
      expect(copy.userId, 'u2');
      expect(copy.packName, 'New Pack');
      expect(copy.contractCount, 3);
      expect(copy.bronzeChance, 60);
      expect(copy.silverChance, 25);
      expect(copy.goldChance, 10);
      expect(copy.eliteChance, 4);
      expect(copy.legendChance, 1);
      expect(copy.source, 'reward');
      expect(copy.opened, true);
      expect(copy.createdAt, DateTime.parse('2027-06-15T12:00:00Z'));
    });
  });

  group('UserContract.fromJson validations', () {
    test('valid contract parses correctly', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'quantity': 5,
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
        'contract_types': {
          'id': 'ct1',
          'name': 'Gold Contract',
          'tier': 'gold',
          'matches_awarded': 10,
        },
      };
      final contract = UserContract.fromJson(json);
      expect(contract.id, 'c1');
      expect(contract.quantity, 5);
      expect(contract.tier, 'gold');
    });

    test('quantity defaults to 1 when null', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
      };
      final contract = UserContract.fromJson(json);
      expect(contract.quantity, 1);
    });

    test('quantity = 0 throws ArgumentError', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'quantity': 0,
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
      };
      expect(() => UserContract.fromJson(json), throwsA(isA<ArgumentError>()));
    });

    test('negative quantity throws ArgumentError', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'quantity': -3,
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
      };
      expect(() => UserContract.fromJson(json), throwsA(isA<ArgumentError>()));
    });

    test('invalid tier throws ArgumentError', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'quantity': 1,
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
        'contract_types': {
          'id': 'ct1',
          'name': 'Fake Contract',
          'tier': 'platinum',
          'matches_awarded': 10,
        },
      };
      expect(() => UserContract.fromJson(json), throwsA(isA<ArgumentError>()));
    });

    test('valid tiers do not throw', () {
      for (final tier in ['bronze', 'silver', 'gold', 'elite', 'legend']) {
        final json = {
          'id': 'c1',
          'user_id': 'u1',
          'contract_type_id': 'ct1',
          'quantity': 1,
          'source': 'reward',
          'acquired_at': '2026-01-01T00:00:00Z',
          'contract_types': {
            'id': 'ct1',
            'name': 'Test',
            'tier': tier,
            'matches_awarded': 10,
          },
        };
        expect(() => UserContract.fromJson(json), returnsNormally,
            reason: 'tier "$tier" should be valid');
      }
    });

    test('null tier does not throw (no contract_types join)', () {
      final json = {
        'id': 'c1',
        'user_id': 'u1',
        'contract_type_id': 'ct1',
        'quantity': 1,
        'source': 'reward',
        'acquired_at': '2026-01-01T00:00:00Z',
      };
      expect(() => UserContract.fromJson(json), returnsNormally);
    });
  });

  group('No user_card.dart import', () {
    test('ContractType, UserContract, UserContractPack all exist', () {
      // If the unused import was removed, these classes should still be fully functional
      final ct = ContractType(id: 'x', name: 'X', tier: ContractTier.gold.value, matchesAwarded: 5);
      expect(ct.tierColor, 0xFFFFD700);

      final uc = UserContract(
        id: 'c1', userId: 'u1', contractTypeId: 'ct1',
        quantity: 1, source: 'reward', acquiredAt: DateTime.now(),
      );
      expect(uc.copyWith(quantity: 5).quantity, 5);

      final pack = UserContractPack(
        id: 'p1', userId: 'u1', packName: 'Pack', createdAt: DateTime.now(),
      );
      expect(pack.copyWith(opened: true).opened, true);
    });
  });
}
