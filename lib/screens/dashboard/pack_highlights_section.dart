import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/logger.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';
import 'pack_tile.dart';

/// Pack highlights horizontal scroll section.
class PackHighlightsSection extends ConsumerStatefulWidget {
  const PackHighlightsSection({super.key});

  @override
  ConsumerState<PackHighlightsSection> createState() => _PackHighlightsSectionState();
}

class _PackHighlightsSectionState extends ConsumerState<PackHighlightsSection> {
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    try {
      final rows = await SupabaseService.client
          .from('pack_types')
          .select()
          .eq('is_available', true)
          .order('coin_cost', ascending: true)
          .limit(3);
      if (mounted) {
        setState(() {
          _packs = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (e) {
      Log.e('Dashboard: failed to load pack highlights', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _packs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦 PACK STORE',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(AppConstants.packsRoute),
                child: const Text('See all', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _packs.map((p) => PackTile(pack: p)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}