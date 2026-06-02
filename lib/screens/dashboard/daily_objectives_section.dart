import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/daily_objectives_card.dart';

/// Daily objectives section fetched from Supabase.
class DailyObjectivesSection extends ConsumerStatefulWidget {
  const DailyObjectivesSection({super.key});

  @override
  ConsumerState<DailyObjectivesSection> createState() => _DailyObjectivesSectionState();
}

class _DailyObjectivesSectionState extends ConsumerState<DailyObjectivesSection> {
  List<DailyObjective> _objectives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final rows = await SupabaseService.client
          .from('daily_objectives')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          _objectives = (rows as List).map((r) => DailyObjective.fromJson(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_objectives.isEmpty) return const SizedBox.shrink();
    return DailyObjectivesCard(objectives: _objectives);
  }
}