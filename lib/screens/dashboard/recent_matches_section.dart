import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';
import 'recent_match_tile.dart';

/// Recent matches section with data fetched from Supabase.
class RecentMatchesSection extends ConsumerStatefulWidget {
  const RecentMatchesSection({super.key});

  @override
  ConsumerState<RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends ConsumerState<RecentMatchesSection> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final rows = await SupabaseService.client
          .from('matches')
          .select()
          .or('home_user_id.eq.$userId,away_user_id.eq.$userId')
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(3);
      if (mounted) setState(() { _matches = List<Map<String, dynamic>>.from(rows as List); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏏 RECENT MATCHES',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(AppConstants.matchHistoryRoute),
                child: const Text('See all', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_matches.take(2).map((m) => RecentMatchTile(match: m))),
        ],
      ),
    );
  }
}